import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/model/newbooking_nearby_model.dart';
import 'package:myridedriverapp/services/ride_alert_memory.dart';
import 'package:myridedriverapp/services/ride_offer_watch.dart';

/// The half-screen "new ride request" card shown as a system overlay — over
/// whatever app the driver is currently using, without needing this app
/// itself open. This is what actually runs inside the overlay's own
/// separate Flutter engine (see overlayMain() in main.dart's OverlayRouter),
/// not the main app's widget tree.
///
/// Same isolation as NavReturnBubble (see that file's own doc comment): no
/// GetX controllers, no Navigator, no HomeController.acceptRidesTrip(). Its
/// two buttons do not attempt to duplicate that method's session/navigation
/// handling here — they hand off instead:
///
///  - Accept sends a ride_request_action/accept message back to the main
///    app (picked up automatically if it is already alive — see main.dart's
///    overlay-action listener) and brings the app to the foreground via the
///    same native channel NavReturnBubble already uses, so the existing,
///    already-correct in-app accept flow finishes the job. If the app was
///    fully killed, opening it lands the driver on the home screen, where
///    the normal 3s poll re-shows this same request within moments for a
///    manual tap — not silently lost, just one extra tap in that specific
///    case.
///  - Decline is genuinely local: there is no decline endpoint today (see
///    HomeController.rejectTrip's own note), so declining here is exactly
///    as final as declining from inside the app already is.
class IncomingRideOverlay extends StatefulWidget {
  final NewBookingNearByModel ride;

  /// Whether the overlay window has been CONFIRMED to be on the driver's
  /// screen — see NavOverlayService.showIncomingRideRequest, which only
  /// broadcasts the confirmation after `isActive()` says a window genuinely
  /// attached.
  ///
  /// This gates the ringtone, and nothing else. The card is built before the
  /// window is raised (deliberately — see _broadcastRoutingHint, which sends
  /// the content first so the window attaches with the right thing already
  /// rendered), so a raise that Android or an OEM gate silently refuses still
  /// produced a fully live card in this engine: countdown running, ringtone
  /// playing, and no window anywhere to explain the noise or let the driver
  /// stop it. That is the "sometimes the overlay never appears but the
  /// ringtone rings anyway" report, and it is also the case that falls back to
  /// a full-screen notification, which plays a sound of its own — so the
  /// driver got two alerts for a card they could not see.
  ///
  /// Ringing only on confirmation costs nothing when the overlay does work and
  /// removes the phantom ringtone entirely when it doesn't.
  final bool windowConfirmed;

  const IncomingRideOverlay({
    super.key,
    required this.ride,
    this.windowConfirmed = false,
  });

  @override
  State<IncomingRideOverlay> createState() => _IncomingRideOverlayState();
}

class _IncomingRideOverlayState extends State<IncomingRideOverlay> {
  // Same channel + method NavReturnBubble uses to reopen the app —
  // registered natively in MainActivity.kt on this same overlay engine.
  static const MethodChannel _returnChannel = MethodChannel(
    'online.nride.driver/overlay_return',
  );

  // How long the card stays up before treating it as a decline. Mirrors
  // Uber/Ola's own request timeout — a request the driver has not answered
  // should not sit indefinitely over whatever app they are using.
  static const int _autoDeclineSeconds = 20;

  /// How long the alert tone sounds for. A ride request is announced, not
  /// alarmed: two seconds is enough to pull the driver's eyes to the screen,
  /// and the card's own 20s countdown is what actually holds the offer open.
  ///
  /// It used to loop for the card's entire life with a 25s hard backstop
  /// behind it, which meant every single way this could go slightly wrong —
  /// a card re-raised by a backend retry, a dismiss that raced a late routing
  /// hint, a window that never attached — ended in a phone ringing for half a
  /// minute with nothing on screen.
  static const Duration _ringtoneDuration = Duration(seconds: 2);

  /// Bookings whose tone has already been played, for the life of this engine.
  ///
  /// The overlay engine is long-lived and this State is not: the router builds
  /// a NEW card for every raise (keyed on the raise id, so the same booking
  /// offered twice is genuinely two cards — see _OverlayRouter). Without a
  /// memory that outlives the card, every repeat raise of the same ride rang
  /// again, which is what "the ringtone just keeps going" was on a backend
  /// that retries a push, or on the 3s poll re-offering a ride the driver had
  /// not answered yet.
  ///
  /// Static, so it survives the card. RideAlertMemory carries the same
  /// question across isolates and across a rebuilt engine; this is the
  /// synchronous first line of defence, since two raises seconds apart can
  /// both reach the async claim before either has finished writing.
  static final Set<String> _rungThisEngine = <String>{};

  final AudioPlayer _player = AudioPlayer();
  Timer? _countdownTimer;
  Timer? _ringtoneStopTimer;
  Timer? _offerWatchTimer;
  int _secondsLeft = _autoDeclineSeconds;
  bool _actionTaken = false;
  bool _ringtoneStarted = false;
  bool _offerCheckInFlight = false;

  /// Set the moment anything asks for silence, and checked by [_startRingtone]
  /// around its own awaits.
  ///
  /// Without it the two are a race that ends in a ringtone nothing can stop:
  /// startup is fire-and-forget and has awaits before `play()`, so a stop
  /// arriving in that window called `stop()` on a player that had not started
  /// yet — a no-op — and then `play()` went ahead, with every path that could
  /// have silenced it already spent.
  bool _ringtoneStopped = false;

  String get _bookingKey => widget.ride.id?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startOfferWatch();
    // Only if the window is already confirmed on screen — which it is when a
    // second raise for a still-attached overlay lands. The usual path is the
    // confirmation arriving a moment later, in didUpdateWidget below.
    if (widget.windowConfirmed) _startRingtone();
  }

  @override
  void didUpdateWidget(covariant IncomingRideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.windowConfirmed && !oldWidget.windowConfirmed) {
      _startRingtone();
    }
  }

  /// Plays the alert tone once, for [_ringtoneDuration], if this booking has
  /// not already had its turn.
  Future<void> _startRingtone() async {
    if (_ringtoneStarted || _ringtoneStopped || _actionTaken) return;
    _ringtoneStarted = true;

    if (!await _claimRingSlot(_bookingKey)) {
      debugPrint(
        '[IncomingRideOverlay] booking $_bookingKey has already been '
        'announced — showing the card silently.',
      );
      return;
    }

    try {
      // Not loop. The stop timer below is the primary control, but a one-shot
      // source means that even if this State is somehow orphaned — the exact
      // failure the old backstop timer existed for — the sound ends by itself.
      await _player.setReleaseMode(ReleaseMode.release);
      // Checked on both sides of play(): a stop can land during either await,
      // and after play() has begun only a second stop can undo it.
      if (_ringtoneStopped) return;
      await _player.play(AssetSource('sound/ringtone.mp3'));
      if (_ringtoneStopped) {
        await _player.stop();
        return;
      }
      _ringtoneStopTimer?.cancel();
      _ringtoneStopTimer = Timer(_ringtoneDuration, _stopRingtone);
    } catch (e) {
      // A silent card is still a usable card — the driver can see and act
      // on it without sound. Never let a ringtone failure hide it.
      debugPrint('[IncomingRideOverlay] ringtone failed: $e');
    }
  }

  /// Takes this booking's one and only ring, or reports that something already
  /// has. Returns true if this card may sound.
  Future<bool> _claimRingSlot(String bookingId) async {
    if (bookingId.isEmpty) return true;
    // In-memory first, and it is the guard that actually has to hold within
    // this engine: two raises seconds apart both reach the async claim below
    // before either has finished writing.
    if (!_rungThisEngine.add(bookingId)) return false;
    return RideAlertMemory.claim(bookingId);
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        _decline(auto: true);
      }
    });
  }

  /// Closes this card by itself once the booking stops being offered.
  ///
  /// This is the answer to the driver being shown — and rung for — a ride
  /// another driver already accepted. Nothing else could do it: the in-app 3s
  /// poll that keeps the in-app request cards honest does not run when the app
  /// is killed, which is the only situation this overlay exists for, and there
  /// is no push today that says "this one is gone" (see
  /// NavOverlayService.closeRideRequest for the push half, which the backend
  /// still has to start sending).
  ///
  /// Fails open in every direction: RideOfferWatch returns null for anything
  /// it cannot determine, and the card stays exactly as it is. Only a definite
  /// "not in your open offers any more" closes it.
  void _startOfferWatch() {
    if (_bookingKey.isEmpty) return;
    _offerWatchTimer = Timer.periodic(RideOfferWatch.pollInterval, (_) async {
      if (!mounted || _actionTaken || _offerCheckInFlight) return;
      _offerCheckInFlight = true;
      try {
        final bool? open = await RideOfferWatch.isStillOffered(_bookingKey);
        if (!mounted || _actionTaken) return;
        if (open == false) {
          debugPrint(
            '[IncomingRideOverlay] booking $_bookingKey is no longer being '
            'offered — closing the card.',
          );
          await _closeBecauseTaken();
        }
      } finally {
        _offerCheckInFlight = false;
      }
    });
  }

  /// Ends the card without it counting as the driver's decision.
  ///
  /// Deliberately does not open the app and does not write the pending-accept
  /// record: nothing was answered here, the offer simply stopped existing.
  Future<void> _closeBecauseTaken() async {
    if (_actionTaken) return;
    _actionTaken = true;
    _countdownTimer?.cancel();
    _offerWatchTimer?.cancel();
    await _stopRingtone();
    // Told rather than assumed: if the app IS alive it should drop this
    // request from its own list at the same moment, instead of waiting for its
    // next poll to notice.
    await _notifyApp(<String, dynamic>{
      'type': 'ride_request_action',
      'action': 'unavailable',
      'booking_id': widget.ride.id,
    });
    await _closeOverlay();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ringtoneStopTimer?.cancel();
    _offerWatchTimer?.cancel();
    // Latched before disposing, so a start still parked on one of its awaits
    // cannot resurrect the sound on a player this is about to release.
    _ringtoneStopped = true;
    _player.dispose();
    super.dispose();
  }

  /// Tells the main app what the driver chose, and never blocks the card on
  /// it succeeding.
  ///
  /// Timed out deliberately. shareData resolves only when the native side
  /// replies, and a plugin that forgets to reply leaves this awaiting
  /// forever — which is exactly what used to strand this card on screen with
  /// dead buttons, since both actions notify before they close. The reply is
  /// fixed in our vendored copy of the plugin; this makes sure no future
  /// version of that bug can ever trap the driver behind an overlay again.
  /// Closing the card matters more than the app hearing about it.
  Future<void> _notifyApp(Map<String, dynamic> payload) async {
    try {
      await FlutterOverlayWindow.shareData(payload)
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[IncomingRideOverlay] shareData failed/timed out: ' + e.toString());
    }
  }

  /// Records the tapped Accept where the app will find it on startup.
  ///
  /// Deliberately duplicated with the shareData message in _accept: that one
  /// is the fast path for an app already running, this one is what makes
  /// Accept work at all when the app was killed — which is the whole reason
  /// this overlay exists.
  Future<void> _rememberAcceptForApp() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ApiConstants.pendingOverlayAccept,
        '${widget.ride.id}|${DateTime.now().millisecondsSinceEpoch}',
      );
      // The booking itself, not just its id — see
      // ApiConstants.pendingOverlayAcceptRide. This card is already holding
      // everything the app needs to accept with, so handing it over costs
      // nothing and removes the app's dependency on re-finding the booking
      // through a poll that may not have run yet.
      await prefs.setString(
        ApiConstants.pendingOverlayAcceptRide,
        jsonEncode(widget.ride.toJson()),
      );
    } catch (e) {
      debugPrint('[IncomingRideOverlay] could not record accept: $e');
    }
  }

  /// Silences the request tone.
  ///
  /// Called explicitly on every path that ends this card, and deliberately NOT
  /// left to [dispose]. Closing the overlay removes the *window* — the
  /// OverlayService detaches the FlutterView and stops there — but the overlay
  /// engine and this widget tree stay alive, so dispose() is never called and
  /// a still-playing player would go on sounding with no card left on screen
  /// to explain the noise or any way for the driver to stop it. The two-second
  /// one-shot makes that survivable rather than catastrophic; this keeps it
  /// from happening at all.
  Future<void> _stopRingtone() async {
    // Set before the await, so a start still in flight sees it.
    _ringtoneStopped = true;
    _ringtoneStopTimer?.cancel();
    _ringtoneStopTimer = null;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[IncomingRideOverlay] could not stop ringtone: $e');
    }
  }

  Future<void> _closeOverlay() async {
    // Before the window goes, not after: once closeOverlay() returns there may
    // be no engine turn left in which to run anything else.
    await _stopRingtone();
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('[IncomingRideOverlay] closeOverlay failed: $e');
    }
  }

  Future<void> _accept() async {
    if (_actionTaken) return;
    _actionTaken = true;
    _countdownTimer?.cancel();
    _offerWatchTimer?.cancel();
    // Silenced here rather than only in _closeOverlay below, because three
    // awaits sit between this point and that one — the prefs write, the
    // shareData message and the openApp channel call, each with its own
    // two-second timeout. The ringtone kept playing across all of them, so a
    // driver who tapped Accept went on hearing the request alarm for several
    // seconds while the app was coming up.
    unawaited(_stopRingtone());
    setState(() {});

    // Sent before opening the app: if the app is already alive somewhere
    // (backgrounded, not killed), this message is what lets it auto-accept
    // the instant it is foregrounded, rather than waiting on the next poll.
    // Written BEFORE the live message and before opening the app, because it
    // is the only half of the handoff that survives the app not running yet.
    await _rememberAcceptForApp();

    await _notifyApp(<String, dynamic>{
      'type': 'ride_request_action',
      'action': 'accept',
      'booking_id': widget.ride.id,
      // Carried for the same reason it is written to prefs above: a
      // backgrounded app that receives this can accept straight away instead
      // of waiting for its own poll to rediscover the booking.
      'ride': widget.ride.toJson(),
    });

    await _openApp();

    await _closeOverlay();
  }

  /// Brings the main app to the front.
  ///
  /// Also the belt-and-braces answer to the ringtone: opening the app runs
  /// MainActivity.onResume, which stops OverlayService, whose onDestroy tells
  /// this engine to drop the card — disposing this State and releasing the
  /// player even on a path where the local stop somehow did not take.
  Future<void> _openApp() async {
    try {
      await _returnChannel
          .invokeMethod<bool>('openApp')
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[IncomingRideOverlay] could not reopen app: $e');
    }
  }

  Future<void> _decline({bool auto = false}) async {
    if (_actionTaken) return;
    _actionTaken = true;
    _countdownTimer?.cancel();
    _offerWatchTimer?.cancel();
    unawaited(_stopRingtone());

    // Written down before the app is told, because the app is very often not
    // running to be told — and this is what makes the decline hold. See
    // RideDeclineMemory: there is no decline endpoint, so without it the
    // nearby-bookings poll hands this same booking back within seconds of the
    // driver opening the app.
    //
    // An automatic decline counts too. A request the driver watched time out
    // is one they chose not to take, and re-offering it the moment they open
    // the app is the same interruption again.
    await RideDeclineMemory.remember(widget.ride.id?.toString());

    await _notifyApp(<String, dynamic>{
      'type': 'ride_request_action',
      'action': 'decline',
      'booking_id': widget.ride.id,
      'auto': auto,
    });

    // Declining does NOT open the app, by hand or on the timeout.
    //
    // It used to, on the reasoning that a driver who has answered a request
    // wants to be back in the app ready for the next one. That is the wrong
    // read of what Decline means: the driver is saying "not this ride", and
    // they were in the middle of something else when the card interrupted
    // them. Yanking their phone into this app is a second interruption as a
    // reward for dismissing the first, and there is nothing here for them to
    // do once they arrive.
    //
    // Declining is the card going away, and nothing else. The backend decides
    // what to offer next.
    await _closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      home: Material(
        color: Colors.transparent,
        child: SafeArea(
          // Top-aligned, so the card is only ever as tall as its own content
          // and the rest of the overlay window stays transparent. Without this
          // the Container stretches to fill the whole window (Material hands
          // its child tight constraints), which painted a large blank white
          // slab below the buttons.
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              // Inset from all three edges so this reads as a floating card
              // rather than a sheet welded to the top of the screen.
              //
              // Only a small gap now, not the status bar's height. Clearing
              // the system bar is done where it can actually be measured —
              // OverlayService positions the whole window below it (see its
              // anchoredTop patch). It cannot be done here: the overlay window
              // carries FLAG_LAYOUT_NO_LIMITS, so the system reports no insets
              // to it at all and the SafeArea above, along with every
              // MediaQuery padding value, reads zero.
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              decoration: BoxDecoration(
                color: ColorResources.whiteColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 16,
                    // Downward now the card sits at the top — a shadow cast
                    // upward from a top-anchored card reads as a rendering
                    // fault rather than depth.
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New ride request',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ColorResources.blueeebutton.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_secondsLeft}s',
                          style: TextStyle(
                            color: ColorResources.blueeebutton,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (ride.fare != null)
                    Text(
                      '₹${ride.fare}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (ride.distance != null || ride.time != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 10),
                      child: Text(
                        [
                          if (ride.distance != null)
                            '${ride.distance!.toStringAsFixed(1)} km',
                          if (ride.time != null) ride.time,
                        ].join(' • '),
                        style: TextStyle(color: ColorResources.blackcolor11),
                      ),
                    ),
                  _addressRow(
                    Icons.circle,
                    ColorResources.blueeebutton,
                    ride.pickupAddress ?? 'Pickup location',
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: SizedBox(
                      height: 16,
                      child: VerticalDivider(width: 1, thickness: 1),
                    ),
                  ),
                  _addressRow(
                    Icons.location_on,
                    Colors.redAccent,
                    ride.dropAddress ?? 'Drop location',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _actionTaken ? null : () => _decline(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _actionTaken ? null : _accept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorResources.blueeebutton,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _addressRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
