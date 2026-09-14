import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/fcm_debug_log.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/helper/get_di.dart' as di;
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/app_constants.dart';
import 'package:myridedriverapp/model/newbooking_nearby_model.dart';
import 'package:myridedriverapp/services/nav_overlay_service.dart';
import 'package:myridedriverapp/widgets/incoming_ride_overlay.dart';
import 'package:myridedriverapp/widgets/nav_return_bubble.dart';

/// Fires when a data-only FCM push arrives while this app is not in the
/// foreground — backgrounded or fully killed; Android hands both cases to
/// this same handler rather than `NotificationController`'s foreground
/// listener, which only ever fires while the app is the one on screen.
///
/// Must be a top-level function, not a method: Android runs this in a
/// separate, short-lived background isolate it spins up specifically for
/// the purpose, sharing no state with the running app (if there even is
/// one) — hence re-initializing Firebase here instead of assuming it is
/// already done.
///
/// Requires the backend to send new-ride-request pushes as data-only
/// messages (no "notification" block) — a "notification"-type push is
/// display-and-forget in Android's own hands before any app code, this
/// handler included, ever sees it, which is what "new rides show as a
/// plain system notification with no custom card" was.
/// Trims whitespace off every key and string value of an FCM data payload.
///
/// FCM delivers data keys byte-for-byte as the sender wrote them, and a key
/// with a stray space or tab is a DIFFERENT key — "type	" is not "type", so
/// the lookup returns null and the ride request is dropped with no error
/// anywhere. That is not hypothetical: it happened repeatedly while testing
/// from the Firebase console, where pasting key names carries invisible tab
/// characters in with them, and every push was silently ignored.
///
/// A real backend sending JSON will not do this, but the cost of being
/// tolerant is two lines and the cost of not being tolerant is a ride request
/// that vanishes without trace.
Map<String, dynamic> _normalisePushData(Map<String, dynamic> raw) {
  final Map<String, dynamic> cleaned = <String, dynamic>{};
  raw.forEach((String key, dynamic value) {
    cleaned[key.trim()] = value is String ? value.trim() : value;
  });
  return cleaned;
}

/// Entry point for Accept/Decline tapped on the ride-request notification
/// while this app is not running.
///
/// Must be a top-level function annotated for the VM: flutter_local_
/// notifications spins up a fresh background isolate to call it, and anything
/// the tree-shaker cannot see a reference to is removed from the release build.
@pragma('vm:entry-point')
void rideNotificationBackgroundHandler(NotificationResponse response) {
  handleRideNotificationResponse(response);
}

/// Records what the driver chose on the ride-request notification.
///
/// Deliberately does NOT accept the ride here. Accepting needs the booking
/// fetched and HomeController.acceptRidesTrip run against a real
/// BuildContext, none of which exists in a background isolate — so this writes
/// the same SharedPreferences record the overlay card's Accept writes, and the
/// app finishes the job on startup or resume (see
/// HomeController._consumePendingOverlayAccept). One accept implementation,
/// reached from three places.
///
/// Decline is local by design: there is no decline endpoint (see
/// HomeController.rejectTrip), so dismissing the notification IS the decline.
Future<void> handleRideNotificationResponse(NotificationResponse response) async {
  final String? bookingId = response.payload;
  final String? action = response.actionId;
  debugPrint(
    '[RideNotification] action=$action booking=$bookingId',
  );
  if (action != NavOverlayService.rideNotificationAcceptActionId) return;
  if (bookingId == null || bookingId.trim().isEmpty) return;

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ApiConstants.pendingOverlayAccept,
      '${bookingId.trim()}|${DateTime.now().millisecondsSinceEpoch}',
    );
    debugPrint('[RideNotification] accept recorded for booking $bookingId');
  } catch (e) {
    debugPrint('[RideNotification] could not record accept: $e');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  logFcmMessage('BACKGROUND / KILLED (firebaseMessagingBackgroundHandler)', message);

  final Map<String, dynamic> data = _normalisePushData(message.data);
  final String type = (data['type'] ?? '').toString();

  if (isRideOfferClosedPush(type)) {
    debugPrint('[FCM-bg] $type: closing the offer — $data');
    await NavOverlayService.closeRideRequest(
      bookingId: rideIdFromPush(data),
    );
    return;
  }

  if (type != 'new_ride_request') {
    debugPrint(
      '[FCM-bg] ignored: type is "$type", '
      'the overlay only reacts to "new_ride_request"',
    );
    return;
  }

  debugPrint('[FCM-bg] new_ride_request: $data');
  await NavOverlayService.showIncomingRideRequest(data);
}

/// Push types that mean "this ride offer is over — stop showing it".
///
/// BACKEND CONTRACT. The app can already do everything else it needs to for a
/// ride another driver has taken; what it cannot do is find out quickly. The
/// backend must send a data-only push (no `notification` block, exactly like
/// `new_ride_request` — see firebaseMessagingBackgroundHandler's own note on
/// why) to every *other* driver the booking was offered to, the moment one of
/// them accepts, and likewise when the rider cancels or the offer expires:
///
///     { "type": "ride_request_closed", "booking_id": "<id>" }
///
/// Several spellings are accepted rather than one, because this is being
/// specified from the app side and the exact name the backend settles on
/// should not be able to break it. A push carrying no booking id closes
/// whatever offer is currently on screen, which is the honest reading of a
/// message that does not say which one it means.
///
/// Until such a push exists, the overlay closes itself off RideOfferWatch's
/// own 3s polling. That works, but it is strictly slower and it costs a
/// request every three seconds on every driver's phone for the life of every
/// offer — which is exactly the cost a push removes.
bool isRideOfferClosedPush(String type) {
  switch (type) {
    case 'ride_request_closed':
    case 'ride_request_cancelled':
    case 'ride_unavailable':
    case 'ride_taken':
    case 'booking_taken':
    case 'ride_already_accepted':
      return true;
    default:
      return false;
  }
}

/// The booking a ride push refers to.
///
/// `id` first, matching NewBookingNearByModel.fromJson and the shape the
/// backend already sends for `new_ride_request`; `booking_id` is the spelling
/// the REST endpoints use and is kept as a fallback so either works.
String? rideIdFromPush(Map<String, dynamic> data) {
  final String id = (data['id'] ?? data['booking_id'] ?? '').toString().trim();
  return id.isEmpty ? null : id;
}

/// Entry point for this app's overlay engine — shared by two different
/// overlays now: the "return to app" bubble shown over Google Maps once a
/// ride starts, and the incoming-ride-request card shown over whatever app
/// the driver is using when a new ride push arrives while this app is not
/// in the foreground. `flutter_overlay_window` supports exactly one named
/// entrypoint per app, registered natively (see OverlayService in
/// AndroidManifest.xml) — `_OverlayRouter` below is what picks between the
/// two at runtime, since this function itself has no way to know which
/// caller started it.
///
/// This runs in its own separate Flutter engine — a completely different
/// isolate/widget tree than the one `main()` starts — which is why it
/// cannot be a normal widget reached through GetMaterialApp below.
/// Renaming it without updating the native side would silently break both
/// overlays.
/// TEMP: sends [message] to MainActivity, which Log.d's it.
///
/// The overlay engine's Dart output — print and debugPrint alike — never
/// reaches logcat; only the main isolate's does. That made every failure in
/// this isolate completely invisible, which is why an engine that was
/// throwing on its very first frame looked indistinguishable from one that
/// had rendered an empty window.
///
/// Buffered and retried rather than sent directly, because the single most
/// interesting moment — the first few milliseconds of this isolate — is
/// exactly when the channel is NOT ready: MainActivity registers the handler
/// on the platform thread just after createAndRunEngine() returns, while this
/// isolate is already running. Sent directly, every early line (including the
/// startup crash this was written to catch) was silently dropped.
final List<String> _pendingOverlayLogs = <String>[];
bool _overlayLogPumpRunning = false;
bool _overlayLogFlushInProgress = false;

void _overlayLog(String message) {
  _pendingOverlayLogs.add(message);
  if (_overlayLogPumpRunning) return;
  _overlayLogPumpRunning = true;
  Timer.periodic(const Duration(milliseconds: 200), (Timer timer) async {
    // Guarded against re-entry: the callback is async, so without this a
    // second tick fires while the first is still awaiting its send, and both
    // then removeAt(0) the same one-element list — which is where the
    // "RangeError (length): Valid value range is empty: 0" came from, and
    // why early lines were logged four times over.
    if (_overlayLogFlushInProgress) return;
    _overlayLogFlushInProgress = true;
    try {
      const MethodChannel channel = MethodChannel(
        'online.nride.driver/overlay_return',
      );
      while (_pendingOverlayLogs.isNotEmpty) {
        try {
          await channel.invokeMethod<void>(
            'log',
            '[Overlay] ${_pendingOverlayLogs.first}',
          );
        } catch (_) {
          // Handler not registered yet — keep the backlog, retry next tick.
          return;
        }
        if (_pendingOverlayLogs.isNotEmpty) _pendingOverlayLogs.removeAt(0);
      }
    } finally {
      _overlayLogFlushInProgress = false;
    }
  });
}

/// Calls runApp() as soon as this engine actually has a view to render into,
/// and not one moment sooner.
///
/// This is the fix for "the overlay window opens but is completely
/// transparent". Since Flutter 3.10's multi-view work, runApp() resolves
/// `PlatformDispatcher.implicitView` with a null-check operator — and a
/// FlutterEngine that has no FlutterView attached has no implicit view at
/// all. This engine is created at app startup (MainActivity.kt's
/// ensureOverlayEngine) but does not get a view until OverlayService attaches
/// one, which is whenever an overlay is first shown — often minutes later.
/// Calling runApp() straight away therefore threw on the spot, every launch,
/// leaving the engine alive with no widget tree; by the time a window did
/// open there was nothing left to draw into it, and the throw itself was
/// invisible because this isolate's output does not reach logcat.
///
/// Polling rather than a callback: the embedder exposes no "view attached"
/// event to Dart, and this costs one cheap null check every 100ms only until
/// the first overlay is shown.
void _runOverlayAppWhenViewIsReady([int attempt = 0]) {
  if (ui.PlatformDispatcher.instance.implicitView != null) {
    _overlayLog('implicit view ready after $attempt attempts — runApp()');
    runApp(const _OverlayRouter());
    return;
  }
  if (attempt == 0) {
    _overlayLog('no implicit view yet — deferring runApp() until one attaches');
  }
  Timer(
    const Duration(milliseconds: 100),
    () => _runOverlayAppWhenViewIsReady(attempt + 1),
  );
}

@pragma("vm:entry-point")
void overlayMain() {
  // TEMP probe, deliberately the very first statement and deliberately
  // dart:io only: no bindings, no channels, no plugins, nothing that could
  // itself be the thing that is broken. If this file appears, this function
  // body ran; if it does not, the engine never reached Dart at all. Every
  // other diagnostic tried so far (print, debugPrint, a platform channel
  // back to native) depends on machinery that was itself under suspicion.
  runZonedGuarded(
    () {
      // Before any _overlayLog call — the channel needs ServicesBinding.
      WidgetsFlutterBinding.ensureInitialized();
      _overlayLog('overlayMain started');

      FlutterError.onError = (FlutterErrorDetails details) {
        _overlayLog('FlutterError: ${details.exceptionAsString()}');
      };

      _runOverlayAppWhenViewIsReady();
    },
    (Object error, StackTrace stack) {
      _overlayLog('UNCAUGHT: $error');
    },
  );
}

/// Decides which of this engine's two overlays a given showOverlay() is
/// actually for, from the routing hint NavOverlayService sends alongside it,
/// and renders that one.
///
/// Long-lived, not per-overlay. It is tempting to read this as "runs once
/// each time an overlay is raised" — it does not. MainActivity.kt seeds the
/// overlay engine at app startup (ensureOverlayEngine, called from
/// configureFlutterEngine), so overlayMain() and therefore this State are
/// already running from the moment the app launches, long before any
/// overlay is shown, and they stay running between overlays. Every routing
/// decision this class makes has to work on an instance that has been alive
/// for hours.
class _OverlayRouter extends StatefulWidget {
  const _OverlayRouter();

  @override
  State<_OverlayRouter> createState() => _OverlayRouterState();
}

class _OverlayRouterState extends State<_OverlayRouter> {
  StreamSubscription<dynamic>? _subscription;
  Widget _content = const SizedBox.shrink();

  /// Identifies the routing decision currently on screen, so the deliberate
  /// repeats NavOverlayService sends (see _broadcastRoutingHint) are
  /// recognised as the same decision arriving again and don't rebuild the
  /// card — which would restart its ringtone and its countdown from 20 four
  /// times over.
  String? _currentKey;

  /// Whether the overlay window for [_currentKey] has been confirmed on
  /// screen. Handed to the ride card, which uses it to decide whether the
  /// alert tone should sound at all — see IncomingRideOverlay.windowConfirmed.
  bool _windowConfirmed = false;

  /// Raises whose window has been confirmed on screen, whether or not their
  /// card had been built yet when the confirmation landed. Kept so the two
  /// messages can arrive in either order — see the `ride_request_visible`
  /// branch in [_onMessage]. Bounded, since a raise older than the confirm
  /// burst cannot still be in flight.
  final Set<String> _confirmedRaises = <String>{};

  /// Bookings an explicit "this offer is over" signal has just closed, and
  /// when. Checked before building a ride card so the tail of an in-flight
  /// hint burst cannot put a dead offer straight back on screen.
  ///
  /// Keyed on the BOOKING, not on the raise, and short-lived — both
  /// deliberately. The signal is about a booking, so blocking the raise would
  /// block the wrong thing; and it only has to outlast the hint burst that is
  /// still in the air (~6.1s), so anything longer would start suppressing a
  /// genuine re-offer of the same booking — which happens for real when the
  /// driver who took it cancels.
  ///
  /// This is a deliberately narrower mechanism than the "retired decisions"
  /// set that used to sit above it: this one is only ever populated by an
  /// explicit close, never by the incidental dismissal OverlayService
  /// broadcasts on every teardown. That distinction is the whole reason the
  /// ride card stopped appearing, and why this cannot repeat it.
  final Map<String, DateTime> _closedBookings = <String, DateTime>{};

  static const Duration _closedBookingMemory = Duration(seconds: 15);

  bool _isRecentlyClosed(String bookingId) {
    if (bookingId.isEmpty) return false;
    final DateTime? closedAt = _closedBookings[bookingId];
    if (closedAt == null) return false;
    if (DateTime.now().difference(closedAt) > _closedBookingMemory) {
      _closedBookings.remove(bookingId);
      return false;
    }
    return true;
  }

  // A "retired decisions" set used to live here, refusing to rebuild any card
  // that had been dismissed, to stop the tail of an in-flight hint burst from
  // resurrecting a card the driver had just answered.
  //
  // It is gone because it could not tell that case apart from the one the hint
  // repeats exist to rescue. A dismissal is NOT always the driver finishing
  // with a card: OverlayService.onDestroy broadcasts one on every native
  // teardown it did not initiate itself, and showIncomingRideRequest closes
  // any existing overlay as its first step — so a dismissal for the PREVIOUS
  // card routinely lands after the NEXT card has already been built. Clearing
  // on that is survivable precisely because the repeats rebuild; retiring on
  // it made the miss permanent, and the ride card stopped appearing at all.
  //
  // Nothing is lost by its absence. What it was guarding — a rebuilt card
  // ringing a second time — is now impossible on its own terms: the tone only
  // ever plays for a raise whose window was confirmed, and only for a booking
  // no player in any isolate has already announced (see RideAlertMemory). A
  // rebuilt ghost card is silent.

  /// Polls for a window being attached to this engine, so the router can go
  /// and fetch what it is meant to be showing.
  ///
  /// This is the recovery path for a hint that was sent and never arrived —
  /// which the device logs show is not rare: shareData reported eight
  /// successful sends while this router received nothing and the driver got an
  /// empty transparent window. See NavOverlayService's stash for why that
  /// happens and why it cannot be detected from the sending side.
  ///
  /// A window opening is the one moment this engine can be certain something
  /// is supposed to be on screen, which makes it the right trigger: no idle
  /// cost beyond a null check, and no reliance on anything having been
  /// delivered.
  Timer? _windowWatch;
  bool _viewWasAttached = false;

  void _startWindowWatch() {
    _viewWasAttached = ui.PlatformDispatcher.instance.implicitView != null;
    // Checked straight away as well as on transitions: the engine can be built
    // and this State created while a window is already up.
    if (_viewWasAttached) unawaited(_fetchStashedHint());

    _windowWatch = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final bool attached =
          ui.PlatformDispatcher.instance.implicitView != null;
      final bool justAttached = attached && !_viewWasAttached;
      _viewWasAttached = attached;
      if (!attached) return;

      if (justAttached) {
        _overlayLog('a window attached — checking for a stashed hint');
        unawaited(_fetchStashedHint());
        return;
      }

      // Also retried, slowly, whenever a window is up with nothing rendered in
      // it — because that state is never correct, and the transition above
      // cannot be relied on to fire for it.
      //
      // Detaching the FlutterView is what should make implicitView null again
      // between raises, and if it does, the transition catches every raise on
      // its own. If it does NOT, the transition fires exactly once for the
      // life of the engine and every later raise is back to depending on a
      // delivery that has already been shown to fail. An empty window is the
      // symptom either way, so it is what this watches for.
      //
      // Safe to repeat: [_appliedStashRaises] means a raise is only ever
      // applied once, so this cannot resurrect a card the driver has answered.
      // Runs for as long as this engine has a window with nothing rendered in
      // it, and never latches off — that is the whole point. implicitView
      // staying non-null after a detach means this retry, not the attach
      // transition above, is what actually catches every raise after the
      // first, so anything that can permanently silence it silences the ride
      // card with it.
      //
      // Bounded instead: one small prefs read every two seconds, and only
      // while there is nothing on screen. Re-reading the same stash is free of
      // consequence — [_appliedStashRaises] makes applying it idempotent.
      if (_content is SizedBox) {
        final DateTime now = DateTime.now();
        if (now.difference(_lastStashRead) < const Duration(seconds: 2)) return;
        _lastStashRead = now;
        unawaited(_fetchStashedHint());
      }
    });
  }

  DateTime _lastStashRead = DateTime.fromMillisecondsSinceEpoch(0);

  /// Timestamp of a stash already rejected as too old, so it is only reported
  /// once rather than on every retry.
  int? _staleStashAt;

  // A latch that stopped the retry once the stash came back stale or empty
  // used to live here, to spare a pointless disk read every second. It is gone
  // because it could not be switched back on.
  //
  // It was cleared only when a window attached — and the device log shows that
  // transition fires at most ONCE in this engine's life: implicitView does not
  // return to null when the overlay's FlutterView detaches, so after the first
  // raise "a window attached" never happens again. The latch therefore became
  // permanent the first time the stash aged out, and with shareData already
  // unreliable (the reason the stash exists at all), the ride card stopped
  // appearing from the second raise onward.
  //
  // The retry it was guarding is genuinely cheap — see the interval below —
  // and the thing it was saving is a small prefs read. Losing a ride is not a
  // trade worth making for that.

  /// Raises already recovered from the stash, so re-reading it is idempotent.
  /// Without this the retry above would rebuild a card the moment the driver
  /// answered it and the content went back to empty.
  final Set<String> _appliedStashRaises = <String>{};

  /// Reads whatever the app last asked this engine to show, and routes it
  /// through the ordinary [_onMessage] path so there is exactly one place that
  /// decides what gets rendered.
  ///
  /// Deduplication is already handled there (on the raise id), so a hint that
  /// also arrived over shareData costs nothing but a no-op.
  Future<void> _fetchStashedHint() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // Required: the value was written by a different isolate, and without
      // this the cached copy this isolate loaded at startup is what gets read.
      await prefs.reload();
      final String? raw = prefs.getString('pending_overlay_hint');
      if (raw == null || raw.isEmpty) return;

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final int stashedAt = (decoded['stashed_at'] as num?)?.toInt() ?? 0;
      // Stale stashes are ignored rather than cleared, so that two windows
      // opening in quick succession cannot race each other into blankness.
      // Generous enough to cover a slow cold engine, short enough that an old
      // offer cannot reappear.
      if (DateTime.now().millisecondsSinceEpoch - stashedAt > 45000) {
        // Remembered, so the retry below stops asking about it.
        //
        // Without this the empty-window retry re-read, re-decoded and
        // re-rejected the same dead stash once a second for the entire life of
        // the process — visible in the device log as an endless run of this
        // line — each one a disk-backed SharedPreferences reload in a second
        // isolate, for an answer that cannot change.
        // Logged once per distinct stash, not once per retry: the retry below
        // is deliberately allowed to keep running, and without this the log
        // filled with the same line forever.
        if (_staleStashAt != stashedAt) {
          _staleStashAt = stashedAt;
          _overlayLog('stashed hint is stale — ignoring it');
        }
        return;
      }
      final dynamic payload = decoded['payload'];
      if (payload is! Map) return;

      // One recovery per raise, ever — see [_appliedStashRaises].
      final String raiseId =
          '${payload['type']}:${payload['_raise_id'] ?? payload['id'] ?? stashedAt}';
      if (!_appliedStashRaises.add(raiseId)) return;
      if (_appliedStashRaises.length > 8) {
        _appliedStashRaises.remove(_appliedStashRaises.first);
      }

      _overlayLog('recovered a stashed hint: ${payload['type']}');
      _onMessage(Map<String, dynamic>.from(payload));
    } catch (e) {
      _overlayLog('could not read the stashed hint: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _overlayLog('router initState — listening for routing hints');
    _subscription = FlutterOverlayWindow.overlayListener.listen(_onMessage);
    _startWindowWatch();
    // No fallback timer here any more, and its absence is the fix for "the
    // ride card never appeared, the return bubble did instead".
    //
    // There used to be a 1.5s timer that defaulted _content to
    // NavReturnBubble, paired with a `_content != null` guard in _onMessage
    // that made the first decision permanent. Both were written on the
    // assumption that this State is created fresh for each overlay — but it
    // is created at app startup (see the class doc). So the timer fired
    // ~1.5 seconds into the app's life, latched NavReturnBubble in, and
    // every ride-request hint that arrived afterwards — minutes or hours
    // later — hit the "first message wins" guard and was dropped on the
    // floor. Starting blank and letting each new hint win is what a
    // long-lived router actually needs.
  }

  void _onMessage(dynamic message) {
    // TEMP diagnostic: logs every payload this engine receives, including
    // ones it ignores, so "the hint never arrived" and "the hint arrived
    // and was discarded" stop looking identical from the outside.
    _overlayLog('router received: $message');
    if (!mounted) return;
    if (message is! Map) return;

    final type = message['type'];

    // A dismissal asked for by the main app (see NavOverlayService.
    // dismissOverlay), which it sends just before tearing the window down.
    //
    // Needed because closing the overlay from the *other* engine removes the
    // window without this one ever finding out: OverlayService detaches the
    // FlutterView and stops, while this engine and its widget tree stay alive
    // exactly as they were. The ride card's State therefore never disposes and
    // its looping ringtone never stops — the driver opens the app, the card
    // vanishes, and the alarm keeps going with nothing on screen to silence.
    // Dropping the content here disposes that State properly.
    if (type == 'overlay_dismiss') {
      _currentKey = null;
      _windowConfirmed = false;
      setState(() => _content = const SizedBox.shrink());
      return;
    }

    // The overlay window for a raise is genuinely on screen. Only now may the
    // ride card make a sound — see IncomingRideOverlay.windowConfirmed for why
    // the card is built before this is known.
    if (type == 'ride_request_visible') {
      final String raiseId = (message['_raise_id'] ?? '').toString();
      if (raiseId.isEmpty) return;
      // Recorded before it is applied, and that ordering is the point: this
      // can legitimately arrive BEFORE the hint that builds the card it
      // confirms. A cold overlay engine misses every message sent before its
      // listener exists (shareData has no buffering), so which of the two
      // bursts the router first catches depends purely on when the engine
      // finished booting. Applying it only to a card already on screen meant
      // that on exactly that timing the card built a moment later stayed
      // silent forever.
      _confirmedRaises.add(raiseId);
      if (_confirmedRaises.length > 8) {
        _confirmedRaises.remove(_confirmedRaises.first);
      }

      final String key = 'new_ride_request:$raiseId';
      if (key != _currentKey || _windowConfirmed) return;
      final Widget current = _content;
      if (current is! IncomingRideOverlay) return;
      _windowConfirmed = true;
      setState(() {
        _content = IncomingRideOverlay(
          key: ValueKey<String>(key),
          ride: current.ride,
          windowConfirmed: true,
        );
      });
      return;
    }

    // This booking is no longer on offer — another driver took it, the rider
    // cancelled, or it expired. Sent by NavOverlayService.closeRideRequest,
    // which the FCM handlers call when the backend says so.
    if (type == 'ride_request_closed') {
      final String closedId = (message['booking_id'] ?? '').toString().trim();
      final Widget current = _content;
      if (current is! IncomingRideOverlay) return;
      // An empty id means "whatever is up", which is what a push carrying no
      // booking id can honestly ask for.
      if (closedId.isNotEmpty &&
          closedId != (current.ride.id?.toString() ?? '')) {
        return;
      }
      if (closedId.isNotEmpty) {
        _closedBookings[closedId] = DateTime.now();
      }
      _currentKey = null;
      _windowConfirmed = false;
      setState(() => _content = const SizedBox.shrink());
      return;
    }

    if (type != 'new_ride_request' && type != 'nav_return_bubble') return;

    // Keyed by booking id as well as type so that two different ride
    // requests are two different decisions, while the same one resent is
    // not.
    // Keyed on the raise id (see NavOverlayService), not the booking id, so
    // the same ride offered twice builds a genuinely new card instead of
    // re-showing the spent one. The four deliberate repeats of a single raise
    // all carry the same _raise_id, so they still collapse into one build.
    final String key =
        '$type:${message['_raise_id'] ?? message['id'] ?? ''}';
    if (key == _currentKey) return;

    // A hint for an offer that was explicitly closed moments ago — almost
    // always the tail of the burst that was already in the air when the close
    // landed. Building it would put a dead card back on the driver's screen.
    if (type == 'new_ride_request' &&
        _isRecentlyClosed((message['id'] ?? message['booking_id'] ?? '')
            .toString()
            .trim())) {
      _overlayLog('router ignoring hint for a closed booking ($key)');
      return;
    }

    _currentKey = key;
    // Not simply false: the confirmation for this very raise may already have
    // arrived and be waiting in [_confirmedRaises].
    _windowConfirmed =
        _confirmedRaises.contains((message['_raise_id'] ?? '').toString());

    if (type == 'new_ride_request') {
      try {
        final ride = NewBookingNearByModel.fromJson(
          Map<String, dynamic>.from(message),
        );
        // Keyed by booking id so a second request replacing a first gets a
        // genuinely fresh State — its own countdown and its own ringtone —
        // rather than Flutter reusing the previous card's.
        setState(() {
          _content = IncomingRideOverlay(
            // Keyed on the raise, not the booking: a fresh State means a fresh
            // countdown and a fresh ringtone even when the same ride comes
            // round again.
            key: ValueKey<String>(key),
            ride: ride,
            windowConfirmed: _windowConfirmed,
          );
        });
      } catch (e) {
        // A ride request this engine cannot even parse is not one it can
        // show — falling back to the bubble at least leaves the driver
        // with a working way back into the app, rather than a broken
        // overlay stuck on screen.
        debugPrint('[OverlayRouter] could not parse ride request: $e');
        setState(() => _content = const NavReturnBubble());
      }
      return;
    }

    setState(() => _content = const NavReturnBubble());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _windowWatch?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _content;
}

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
// Public (not the original leading-underscore `_initializeCore`) so
// splash_screen.dart can call it again to retry Firebase/DI setup if the
// first attempt fails — see the try/catch around `await appInitialization`
// there. A failed Firebase.initializeApp() (e.g. a device with broken/
// outdated Google Play Services) used to leave di.init() never having run
// at all, so every screen's first Get.find() call — none of which are
// guarded — threw immediately: an uncaught exception during app startup,
// which is exactly what an Android "keeps stopping" crash looks like.
Future<void> initializeAppCore() async {
  await Firebase.initializeApp();
  await di.init();
}

void main() {
  // Was just `runApp(MyApp())` — this app had zero global error handling
  // anywhere (no runZonedGuarded, no FlutterError.onError, no Crashlytics),
  // so an uncaught exception on a specific device (e.g. the reported
  // Galaxy M11 "Nride driver keeps stopping" crash) left nothing to look
  // at beyond a bare "keeps stopping" system dialog — no way to tell which
  // of several plausible causes it actually was. This doesn't stop a fatal
  // error from taking the app down, but it does mean any error routed
  // through the zone (framework errors always are; platform/isolate-level
  // native crashes are not) gets logged before that happens, instead of
  // vanishing. `flutter logs` / `adb logcat` on a reproducing device is
  // now the fastest way to actually see what's failing, instead of
  // guessing blind.
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // Registered before Firebase.initializeApp() (kicked off just below,
      // unawaited) deliberately — this only tells the FCM SDK which
      // function to call in the background isolate, it never runs on this
      // one, so it does not need this app's own Firebase instance to exist
      // yet. Must happen this early: it is what lets a new-ride-request
      // push reach app code at all while this app is backgrounded or fully
      // killed, instead of Android just displaying it as a plain
      // notification with nothing of ours ever running — see
      // firebaseMessagingBackgroundHandler's own doc comment.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('[FATAL] FlutterError: ${details.exceptionAsString()}');
        debugPrint('${details.stack}');
        originalOnError?.call(details);
      };

      // Kicked off without awaiting so Flutter can paint its first frame
      // (and dismiss Android's mandatory native splash) immediately,
      // instead of sitting on the OS splash for as long as Firebase/DI
      // setup takes.
      appInitialization = initializeAppCore();

      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );

      runApp(MyApp());
      //configLoading();
    },
    (error, stack) {
      debugPrint('[FATAL] Uncaught zone error: $error');
      debugPrint('$stack');
    },
  );
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = Colors.yellow
    ..backgroundColor = ColorResources.appColor
    ..indicatorColor = Colors.white
    ..textColor = Colors.white
    ..maskColor = ColorResources.appColor
    ..userInteractions = true
    ..dismissOnTap = false;
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();

    // Firebase isn't ready until appInitialization resolves, so FCM setup
    // has to wait for it rather than assuming it already completed. Was
    // missing a catchError — if appInitialization rejects (e.g. Firebase
    // init failing on a device with broken Google Play Services), this
    // .then() callback simply never runs, silently, rather than crashing
    // here; splash_screen.dart's own try/catch around the same Future is
    // what actually surfaces and retries the failure to the user.
    appInitialization
        ?.then((_) => _setupMessaging())
        .catchError((e) => debugPrint('[FCM] appInitialization failed: $e'));
  }

  void _setupMessaging() {
    // App killed → user taps notification → app launches
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;
      logFcmMessage('COLD START (app opened by tapping notification)', message);
      _handleFcmMessage(message);
    });

    // App in background → user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      logFcmMessage('OPENED FROM NOTIFICATION (app was in background)', message);
      _handleFcmMessage(message);
    });

    // App in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      logFcmMessage('FOREGROUND (app on screen)', message);
      _showNotification(message);
      _handleFcmMessage(message);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    });

    FirebaseMessaging.instance.requestPermission();
    _initializeFlutterLocalNotifications();
  }

  /// Returns true when [message] indicates the driver's docs have been approved.
  bool _isApprovalMessage(RemoteMessage message) {
    final data = message.data;
    // Check explicit data-payload fields (most reliable).
    if (data['verification_status'] == 'approved' ||
        data['doc_status'] == 'approved' ||
        data['type'] == 'document_approved' ||
        data['type'] == 'doc_approved' ||
        data['type'] == 'approved') {
      return true;
    }
    // Fallback: check notification title / body text.
    final title = message.notification?.title?.toLowerCase() ?? '';
    final body = message.notification?.body?.toLowerCase() ?? '';
    if ((title.contains('approved') || body.contains('approved')) &&
        (title.contains('document') ||
            body.contains('document') ||
            title.contains('profile') ||
            body.contains('profile') ||
            title.contains('account') ||
            body.contains('account'))) {
      return true;
    }
    return false;
  }

  Future<void> _handleFcmMessage(RemoteMessage message) async {
    try {
      // Handled here as well as in the background isolate, because which of
      // the two sees a push is decided by whether this app happens to be on
      // screen — and an offer that is over is over either way. With the app
      // foregrounded the overlay is normally already down, so what this
      // usually clears is the ride-request notification and any card the
      // engine is still holding.
      final Map<String, dynamic> data = _normalisePushData(message.data);
      final String pushType = (data['type'] ?? '').toString();
      if (isRideOfferClosedPush(pushType)) {
        debugPrint('[FCM-fg] $pushType: closing the offer');
        final String? closedId = rideIdFromPush(data);
        await NavOverlayService.closeRideRequest(bookingId: closedId);
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().dropIncomingRequest(closedId);
        }
        return;
      }

      if (!_isApprovalMessage(message)) return;
      final prefs = await SharedPreferences.getInstance();

      // A notification is not proof of a session: without this guard, a
      // stale/test push landing on a fresh install (e.g. tapped while the
      // app was killed, which is effectively a first open) would shove the
      // user straight to Home with no login ever having happened. Only act
      // on the message if this device actually holds a logged-in session.
      final token = prefs.getString(ApiConstants.token);
      if (token == null || token.isEmpty) return;

      await prefs.setString(ApiConstants.verificationStatus, 'approved');
      final home = RouteHelper.gethomescreen();
      if (Get.currentRoute != home) {
        Get.offAllNamed(home);
      }
    } catch (e) {
      debugPrint('[FCM] _handleFcmMessage error: $e');
    }
  }

  void _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    String? title = message.notification?.title;
    String? body = message.notification?.body;

    // Never expose OTP values in notification tray
    final hasOtpInData = message.data.containsKey('otp');
    final bodyHasOtp =
        body != null &&
        RegExp(r'\b\d{4,8}\b').hasMatch(body) &&
        body.toLowerCase().contains('otp');
    if (hasOtpInData || bodyHasOtp) {
      title = 'Nride driver Verification';
      body = 'Tap to open the app and enter your verification code.';
    }

    await flutterLocalNotificationsPlugin.show(
      id: message.notification.hashCode,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  void _initializeFlutterLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: handleRideNotificationResponse,
      // The killed-app half, and the one that matters: the ride-request
      // notification exists precisely because the app is not running, so its
      // buttons are usually pressed with no Dart isolate alive to hear them.
      // Without this, Android launches nothing and the tap is simply lost —
      // which is why Accept and Decline did nothing on that path.
      onDidReceiveBackgroundNotificationResponse:
          rideNotificationBackgroundHandler,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: Get.key,

      title: AppConstants.appName,
      initialRoute: RouteHelper.getSplashRoute(),
      getPages: RouteHelper.routes,
      defaultTransition: Transition.topLevel,
      transitionDuration: const Duration(milliseconds: 500),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: EasyLoading.init()(context, child),
        );
      },
    );
  }
}
