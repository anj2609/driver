import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
// Prefixed: both this and flutter_overlay_window export a
// NotificationVisibility, and this file legitimately needs symbols from each.
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'oem_overlay_support.dart';

/// Sends the driver into the real Google Maps app for turn-by-turn
/// navigation once a ride starts, and — as a bonus, only when the OS
/// permission for it already happens to be granted — leaves a small floating
/// bubble (Uber/Rapido-style) on screen so they can tap back into this app.
///
/// The two halves are deliberately independent. An earlier version treated
/// them as one step: it checked the overlay permission first, sent the driver
/// to the system Settings screen to grant it, and returned early if they
/// hadn't. That meant the actual navigation — the thing the driver pressed
/// Start Ride for — never launched at all on any device where that
/// permission wasn't already on, and the driver instead got an unexplained
/// permission screen at the worst possible moment. Navigation is the feature;
/// the bubble is a convenience, and a convenience must never be able to block
/// the feature.
class NavOverlayService {
  NavOverlayService._();

  /// What Android's own `Settings.canDrawOverlays()` reports — nothing more.
  ///
  /// Kept for the onboarding flow, which legitimately wants this reading: it
  /// is what decides whether there is still a toggle for the driver to find.
  /// It is NOT what decides whether a bubble can be shown — use
  /// [canActuallyShowOverlay] for that, and see its doc for why the two
  /// differ on a large share of this app's fleet.
  static Future<bool> hasOverlayPermission() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      debugPrint('[NavOverlay] permission check failed: $e');
      return false;
    }
  }

  /// Whether an overlay window will actually attach on this device, verified
  /// by attaching one.
  ///
  /// This replaced [hasOverlayPermission] at every site that was about to
  /// *show* something, and that swap is the whole point. MIUI/HyperOS,
  /// ColorOS/Realme UI and Funtouch OS each gate overlays behind a
  /// vendor-private permission that Android's SYSTEM_ALERT_WINDOW app-op
  /// knows nothing about. On those phones a driver who had enabled "Display
  /// over other apps" got `canDrawOverlays() == true`, a `showOverlay()` call
  /// that threw nothing whatsoever, and no bubble — with every signal this
  /// code could see insisting it had worked. That is why drivers reported the
  /// bubble missing *after* granting the permission.
  ///
  /// OemOverlaySupport.overlayActuallyWorks() makes the one call the vendor
  /// gate actually rejects (`WindowManager.addView`) with a 1x1 invisible
  /// window, and reports what Android did. See OverlaySupport.probeOverlay on
  /// the native side for its one honest limitation: MIUI's gate is about
  /// popping up *from the background*, so a probe run in the foreground can
  /// still pass on a device that will refuse the real thing later. Hence the
  /// notification path below is posted unconditionally rather than only when
  /// this returns false — a probe is a better guess, not a guarantee.
  static Future<bool> canActuallyShowOverlay() async {
    // Ordered cheapest-first: the app-op check is a synchronous lookup, the
    // probe adds and removes a real window. No point doing the second when
    // the first already says no.
    if (!await hasOverlayPermission()) return false;

    final bool? probe = await OemOverlaySupport.overlayActuallyWorks();

    // null means the probe could not run — most importantly in the FCM
    // background isolate, which has no native channel and is precisely where
    // an incoming ride push is handled. Treating that as a denial is what
    // stopped the ride-request overlay appearing from a push at all, on every
    // device. Unknown falls back to the permission we have already confirmed
    // is granted: worst case the raise fails and showIncomingRideRequest's
    // catch posts the notification instead, which is a strictly better
    // outcome than never attempting the overlay.
    if (probe == null) {
      debugPrint(
        '[NavOverlay] overlay probe unavailable on this isolate — '
        'proceeding on the granted permission alone.',
      );
      return true;
    }
    return probe;
  }

  /// Sends the driver to the best available "Display over other apps" screen
  /// for this app. There is no in-app runtime dialog for this permission —
  /// Android requires it to be granted from Settings — so any caller has to
  /// re-check afterwards rather than assume consent.
  ///
  /// Routed through OemOverlaySupport rather than
  /// `FlutterOverlayWindow.requestPermission()`, which only ever fires AOSP's
  /// ACTION_MANAGE_OVERLAY_PERMISSION. On a Xiaomi or Oppo device that lands
  /// the driver on a screen whose toggle they may well already have enabled,
  /// while the toggle that is actually blocking them sits in the vendor's own
  /// security centre — so the driver flips nothing, comes back, and still has
  /// no bubble. The vendor screen is tried first for exactly that reason,
  /// with AOSP's kept as the fallback (and on stock Android, AOSP's is
  /// immediately correct — nothing is lost by asking).
  ///
  /// Deliberately NOT called from the ride-start path; see the class doc.
  static Future<void> requestOverlayPermission() async {
    final opened = await OemOverlaySupport.openOverlaySettings();
    if (opened != null) return;

    // Nothing could be opened natively — fall back to the plugin's own
    // request, then leave it to the caller's UI to show the written steps.
    debugPrint(
      '[NavOverlay] no settings screen could be opened natively; falling '
      'back to FlutterOverlayWindow.requestPermission()',
    );
    try {
      await FlutterOverlayWindow.requestPermission();
    } catch (e) {
      debugPrint('[NavOverlay] permission request failed: $e');
    }
  }

  /// True for a coordinate Google Maps can actually route to.
  ///
  /// (0, 0) is the one that matters in practice: it is a real place (open
  /// ocean off West Africa), so nothing downstream rejects it — Maps opens,
  /// tries to route into the Gulf of Guinea, and reports "something went
  /// wrong" with no clue that the coordinates were the problem. It arrives
  /// here whenever a booking is missing drop_lat/drop_lng and the model
  /// defaults them to zero rather than null.
  static bool isNavigableCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN || lat.isInfinite || lng.isInfinite) {
      return false;
    }
    if (lat.abs() > 90 || lng.abs() > 180) return false;
    // Null Island — never a real pickup or drop.
    if (lat == 0 && lng == 0) return false;
    return true;
  }

  /// Opens real Google Maps turn-by-turn navigation to [lat]/[lng].
  ///
  /// [originLat]/[originLng] are the driver's own position. Supplying them
  /// matters more than it looks: the `google.navigation:` intent carries a
  /// destination only, and Google Maps resolves the *origin* itself from its
  /// own location. Google Maps is a separate app with its own permissions,
  /// so on a device where Maps has no location access (or location services
  /// are off, or it simply has no fix yet) it cannot work out where the
  /// route starts and shows "something went wrong" — with this app's own
  /// location permission being entirely irrelevant to that.
  ///
  /// The Maps URLs form below takes an explicit `origin`, which removes that
  /// dependency, and `dir_action=navigate` asks for turn-by-turn rather than
  /// a route preview. It is tried first whenever an origin is known.
  ///
  /// Returns false only if nothing at all could be opened.
  static Future<bool> launchGoogleMapsNavigation({
    required double lat,
    required double lng,
    double? originLat,
    double? originLng,
  }) async {
    // Checked before launching rather than after: handing Maps a garbage
    // destination doesn't fail, it "succeeds" into an error screen, which
    // then looks like a maps problem instead of a missing-coordinates one.
    if (!isNavigableCoordinate(lat, lng)) {
      debugPrint(
        '[NavOverlay] refusing to launch navigation — ($lat, $lng) is not a '
        'navigable coordinate. The booking is most likely missing its '
        'drop_lat/drop_lng.',
      );
      return false;
    }

    // Preferred whenever the driver's own position is known, because it
    // states the origin outright instead of leaving Maps to find one. See
    // the doc comment: an unresolvable origin is the failure that shows up
    // as "something went wrong" on an otherwise perfectly valid route.
    if (isNavigableCoordinate(originLat, originLng)) {
      final originUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=$originLat,$originLng'
        '&destination=$lat,$lng'
        '&travelmode=driving'
        '&dir_action=navigate',
      );
      debugPrint(
        '[NavOverlay] launching navigation (explicit origin): $originUri',
      );
      try {
        if (await launchUrl(originUri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (e) {
        debugPrint('[NavOverlay] explicit-origin navigation failed: $e');
      }
    } else {
      debugPrint(
        '[NavOverlay] no usable driver origin ($originLat, $originLng) — '
        'falling back to google.navigation:, which makes Google Maps resolve '
        'the origin itself.',
      );
    }

    // google.navigation:q=<lat>,<lng>&mode=d drops straight into driving
    // turn-by-turn guidance rather than just showing a pin, which is what a
    // plain maps.google.com link would do.
    final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    debugPrint('[NavOverlay] launching navigation: $navUri');
    // Wrapped in try/catch, not just checked for a false return:
    // launchUrl throws a PlatformException when no activity can handle the
    // URI (Google Maps not installed, or the intent not resolvable), it
    // does not simply return false. Uncaught, that propagated out of the
    // Start Ride handler as an unhandled async error.
    try {
      if (await launchUrl(navUri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (e) {
      debugPrint('[NavOverlay] google.navigation launch failed: $e');
    }

    // Fallback for a device with no Google Maps app: the universal Maps
    // directions URL, which any browser can open. Still lands the driver on
    // a route to the right place rather than nowhere at all.
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[NavOverlay] maps web fallback failed: $e');
      return false;
    }
  }

  /// Closes whatever overlay is currently showing, and — critically —
  /// always returns, whether one was showing or not.
  ///
  /// `FlutterOverlayWindow.closeOverlay()` cannot safely be awaited
  /// directly. flutter_overlay_window 0.5.0's Android handler for it reads:
  ///
  /// ```java
  /// } else if (call.method.equals("closeOverlay")) {
  ///     if (OverlayService.isRunning) { ...; result.success(true); }
  ///     return;   // nothing running -> result is NEVER completed
  /// }
  /// ```
  ///
  /// A MethodChannel result that is never completed leaves the Dart Future
  /// pending forever — it does not throw, resolve to null, or time out on
  /// its own. So on the very first call, with no overlay yet on screen,
  /// `await closeOverlay()` never came back, and every line after it — the
  /// showOverlay() call itself included — simply never ran. That is the
  /// whole "the card never appears, and nothing is logged either" symptom:
  /// the pipeline was not failing, it was parked on its second line.
  ///
  /// Guarded with a timeout rather than by checking isActive() first,
  /// because isActive() is exactly the reading already documented as
  /// unreliable in showReturnBubbleIfPermitted below — a stale `true` would
  /// send us straight back into the same never-completing call. A timeout
  /// holds regardless of what isActive() believes.
  /// Takes down whatever overlay is currently showing.
  ///
  /// Called when this app comes to the foreground. Every overlay this service
  /// raises exists to reach a driver who is looking at something *else* — the
  /// incoming-ride card and the return-to-app bubble both — so once the app
  /// itself is on screen they have nothing left to do, and an overlay the
  /// driver has already answered by opening the app is just a card floating
  /// over the ride screen with a countdown still running.
  static Future<void> dismissOverlay() async {
    // Both halves start together, and the window close is not made to wait.
    //
    // These do two different jobs: closing removes the window (what the driver
    // sees), while the hint tells the overlay engine to drop its content so the
    // card's State disposes and its looping ringtone stops — closing alone
    // leaves that widget tree untouched, see the overlay_dismiss branch in
    // main.dart's _OverlayRouter.
    //
    // Sending the hint first and awaiting it, as this used to, put up to 600ms
    // of round trip in front of the close: the driver opened the app and the
    // card sat over it for half a second before going. The card is already
    // answered by the time this runs, so there is nothing to lose by tearing
    // the window down immediately and letting the engine catch up.
    final Future<void> hint = FlutterOverlayWindow.shareData(
      <String, dynamic>{'type': 'overlay_dismiss'},
    ).timeout(const Duration(milliseconds: 600)).then(
      (_) {},
      onError: (Object e) {
        // Nothing listening, or no overlay engine at all.
        debugPrint('[NavOverlay] dismiss hint not delivered: $e');
      },
    );

    await _closeAnyExistingOverlay();
    await hint;
  }

  static Future<void> _closeAnyExistingOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay().timeout(
        const Duration(milliseconds: 600),
      );
    } on TimeoutException {
      // Expected whenever nothing was showing — see above. Not an error.
    } catch (e) {
      debugPrint('[NavOverlay] closeOverlay failed: $e');
    }
  }

  /// Raises the floating return-to-app bubble, but only if the driver has
  /// already granted the overlay permission. Silent no-op otherwise — it is
  /// never worth interrupting an active ride to ask for this.
  static Future<void> showReturnBubbleIfPermitted() async {
    // Probe, not the app-op — see canActuallyShowOverlay. A driver on MIUI
    // used to get past this guard and then get no bubble, with nothing
    // logged. Now the reason is stated once, here, and the return
    // notification (posted by the caller regardless) is the way home.
    if (!await canActuallyShowOverlay()) {
      unawaited(OemOverlaySupport.logOverlayDiagnosis());
      return;
    }
    try {
      // Was `if (await FlutterOverlayWindow.isActive()) return;` — a guard
      // against creating a second overlay on top of one already showing.
      // The bubble closes *itself*, though (see NavReturnBubble._returnToApp,
      // which calls FlutterOverlayWindow.closeOverlay() from the overlay's
      // own separate Flutter engine/isolate, not this one) — and after that,
      // isActive() queried from here would sometimes still report true. The
      // driver's first Google Maps trip would then show the bubble fine, but
      // the *next* one — after they'd tapped the bubble to come back once —
      // would hit this now-stale `true` and skip showOverlay() entirely,
      // leaving no bubble at all. Closing first unconditionally (a no-op if
      // nothing is showing — see _closeAnyExistingOverlay) sidesteps trusting
      // that cross-isolate state and guarantees a fresh overlay every time.
      await _closeAnyExistingOverlay();
      // Hint first, window second — see _broadcastRoutingHint.
      unawaited(_broadcastRoutingHint({'type': 'nav_return_bubble'}));

      await FlutterOverlayWindow.showOverlay(
        height: 150,
        width: 150,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilityPublic,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Ride in progress',
        overlayContent: 'Tap the bubble to return to Nride driver',
      );
    } catch (e) {
      // A bubble that fails to appear must not take the ride down with it.
      debugPrint('[NavOverlay] showOverlay failed: $e');
    }
  }

  /// Overlay height, in physical pixels, used when this isolate has no view
  /// to measure (see showIncomingRideRequest). Comfortably taller than the
  /// card's own content on a phone, so nothing is clipped, without covering
  /// so much of the screen that the transparent area below the card starts
  /// swallowing taps meant for the app behind it.
  static const int _fallbackOverlayHeightPx = 1000;

  /// Shows the incoming-ride-request card as a bottom-half overlay over
  /// whatever app is currently in front — the driver-app equivalent of
  /// Uber/Ola's request screen, for the moment this app itself isn't the
  /// one in front.
  ///
  /// [rideData] is passed straight through to
  /// `NewBookingNearByModel.fromJson` on the overlay side, so it must use
  /// that same field shape (pickup_lat, pickup_address, final_amount, ...).
  /// Deliberately typed as a raw map rather than the model itself: this is
  /// called from the FCM background handler, whose message.data is already
  /// exactly this shape (a `Map<String, String>` from Android) — accepting
  /// it directly avoids a decode-then-reencode round trip for no benefit.
  ///
  /// Falls back to a full-screen-intent notification when an overlay cannot
  /// be shown, rather than to nothing.
  ///
  /// It used to return false here and leave the driver with the in-app 3s
  /// poll — which only runs while the app is open, i.e. not in the one
  /// situation this method exists for. The practical effect was that every
  /// driver on a phone with a vendor overlay gate (Xiaomi, Oppo, Realme,
  /// Vivo — a large share of this fleet) silently missed every ride offered
  /// while they were in Google Maps, and nothing on their screen ever
  /// mentioned a ride had been offered at all.
  ///
  /// A notification has none of the overlay's prerequisites: no
  /// SYSTEM_ALERT_WINDOW, no vendor allowance, and it survives the app being
  /// backgrounded or killed. See [showIncomingRideNotification].
  static Future<bool> showIncomingRideRequest(
    Map<String, dynamic> rideData,
  ) async {
    // Probed rather than trusting the app-op, same as the bubble. Note this
    // runs in the FCM background isolate, where the native channel is not
    // registered and the probe therefore returns false — which lands on the
    // notification path below. That is the correct outcome for this caller
    // either way: it is the path that works with the app closed.
    if (!await canActuallyShowOverlay()) {
      debugPrint(
        '[NavOverlay] no usable overlay — showing the incoming ride as a '
        'full-screen notification instead.',
      );
      unawaited(OemOverlaySupport.logOverlayDiagnosis());
      return showIncomingRideNotification(rideData);
    }

    try {
      // Same reasoning as the bubble above: never stack a second overlay on
      // a first, and a stale isActive() reading is exactly the failure mode
      // already documented there. Through the helper, never the raw call —
      // see _closeAnyExistingOverlay for why awaiting the raw one hangs.
      await _closeAnyExistingOverlay();

      // A concrete pixel height rather than WindowSize.fullCover: this is a
      // bottom SHEET, not a fullscreen takeover (that's the "unlocked-only,
      // don't build a lock-screen incoming-call experience" scope this was
      // deliberately kept to) — the app the driver was using stays visible
      // above it, same as Uber/Ola's own request card.
      // dart:ui directly, not WidgetsBinding — this can be called from the
      // FCM background handler's isolate, which has no reason to have a
      // widgets binding (or any UI of its own) attached; PlatformDispatcher
      // is the raw engine-level source both ultimately read from.
      // physicalSize directly, NOT divided by devicePixelRatio.
      // flutter_overlay_window passes this straight into
      // WindowManager.LayoutParams, which is measured in PHYSICAL pixels —
      // handing it a logical height made the window roughly half the size
      // intended (467px instead of 935px on this 720x1612 device), which is
      // why the card's Accept/Decline row sat 33px past the bottom edge and
      // was simply not on screen.
      // Guarded on the measurement being USABLE, not on views being empty.
      // A viewless engine — which is what FCM's background isolate is when a
      // ride push arrives with the app closed — still reports exactly one
      // implicit view. It just has a physicalSize of 0x0, because nothing has
      // ever been laid out in it. So an isEmpty check passes straight through,
      // 0 * 0.58 rounds to 0, and Android clamps that to a window ONE PIXEL
      // tall: the service starts, the card builds, and the driver sees
      // nothing at all. Measured on device — the window came back as 720x1.
      final Iterable<ui.FlutterView> views =
          ui.PlatformDispatcher.instance.views;
      final double measuredHeight = views.isEmpty
          ? 0
          : views.first.physicalSize.height;
      final int overlayHeight = measuredHeight > 0
          ? (measuredHeight * 0.58).round()
          : _fallbackOverlayHeightPx;

      // Hint first, window second — see _broadcastRoutingHint on why the
      // reverse order (which this used to do) shows the wrong overlay for a
      // beat before correcting itself.
      // Stamped with a unique id per raise, and the overlay keys its card on
      // it. Without this the router deduplicated on booking id alone, so a
      // SECOND push for a booking it had already shown was treated as a repeat
      // and skipped — while showOverlay still re-raised the window, putting the
      // previous, already-answered card back on screen with its countdown at
      // zero and both buttons dead. That is a real production path (a backend
      // retry, or the same ride re-offered), not just a test artifact.
      // Held rather than inlined: the visibility confirmation sent further
      // down has to name this same raise, or the router cannot tell which card
      // it is confirming.
      final String raiseId = DateTime.now().microsecondsSinceEpoch.toString();
      unawaited(
        _broadcastRoutingHint(<String, dynamic>{
          'type': 'new_ride_request',
          ...rideData,
          '_raise_id': raiseId,
        }),
      );

      // Build marker. The window was repeatedly observed being created with
      // gr=BOTTOM while this line already read topCenter — the giveaway that
      // the APK carried a stale Dart snapshot. If this line is missing from
      // the logs, the running Dart is older than this source.
      debugPrint('[NavOverlay] raising ride card, alignment=topCenter');
      await FlutterOverlayWindow.showOverlay(
        height: overlayHeight,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        // defaultFlag (this class's own default) still receives touch —
        // only key/focus input is withheld — which is what a card with
        // real Accept/Decline buttons needs; clickThrough would make every
        // tap fall straight through to whatever app is behind it instead.
        visibility: NotificationVisibility.visibilityPublic,
        overlayTitle: 'New ride request',
        overlayContent: 'Tap to view the request',
      );

      // Confirmed, not assumed.
      //
      // The catch below was written on the belief that a raise which does not
      // work throws. It does not. With the app killed, showOverlay returned
      // cleanly and no card ever appeared — measured on device, and the reason
      // a driver with the app swiped away silently missed rides. Two things
      // can produce that: Android 14+ refusing to start this overlay's
      // foreground service from the background, and an OEM gate rejecting the
      // window itself. Neither surfaces as an exception here.
      //
      // isActive() asks the plugin whether a window is genuinely attached, so
      // the notification below becomes a real fallback rather than one that
      // only fires on the failure mode that happens to throw.
      //
      // POLLED, not a single reading after a fixed delay. A single check at
      // 1200ms is a guess at how long the service takes to attach, and it is
      // wrong often enough to matter: a cold overlay engine has to be rebuilt
      // from scratch (see OverlayService.onCreate) and the window can land
      // comfortably past that mark. Every "not attached yet" then read as
      // "will never attach" — which cost a notification the driver did not
      // need, and, for as long as this also tore the card down, the card
      // itself.
      //
      // Asking repeatedly answers the question this actually wants to ask —
      // "did it attach at all?" — instead of "had it attached by 1200ms?".
      bool attached = false;
      for (final int waitMs in const [600, 300, 300, 400, 400, 500]) {
        await Future<void>.delayed(Duration(milliseconds: waitMs));
        attached = await FlutterOverlayWindow.isActive();
        if (attached) break;
      }

      if (!attached) {
        debugPrint(
          '[NavOverlay] showOverlay reported no error but no overlay ever '
          'attached — falling back to the full-screen notification so the '
          'ride is not silently missed.',
        );
        // Deliberately NOT tearing the card down here, and that restraint is
        // load-bearing. This branch means "we could not confirm a window", not
        // "there is definitely no window" — isActive() is the same reading
        // already documented as unreliable in showReturnBubbleIfPermitted. A
        // teardown on an unconfirmed negative destroys a card that is on the
        // driver's screen, and because the routing-hint repeats are what
        // normally recover a card lost to a stray dismissal, destroying it
        // here destroyed it permanently.
        //
        // An unconfirmed card costs nothing now: its tone is gated on the
        // confirmation this failed to send (see
        // IncomingRideOverlay.windowConfirmed), so the worst case is a visible
        // card that is silent, alongside the notification below. Both alert
        // the driver; neither can ring on its own in an engine with no window.
        final bool posted = await showIncomingRideNotification(rideData);
        // Awaited, not fired and forgotten. The caller that matters here is
        // the FCM background handler, and the isolate Android spins up for it
        // lives only as long as that handler's Future is pending — so anything
        // left running unawaited is liable to be cut off precisely in the
        // app-killed case this whole path exists for.
        await _confirmALateAttach(raiseId);
        return posted;
      }

      debugPrint('[NavOverlay] incoming-ride overlay is attached');
      // Only now is the card genuinely in front of the driver, and only now
      // may it make a sound — see IncomingRideOverlay.windowConfirmed.
      //
      // Repeated for the same reason the routing hint is: shareData has no
      // delivery acknowledgement, and a dropped confirmation means a silent
      // card. Cheap, and the router ignores the repeats.
      unawaited(
        _broadcastConfirmation(<String, dynamic>{
          'type': 'ride_request_visible',
          '_raise_id': raiseId,
        }),
      );
      return true;
    } catch (e) {
      // The probe said an overlay would attach and it still didn't. This is
      // the residual case the probe cannot catch (see its doc: MIUI's gate
      // is specifically about background pop-ups, so a foreground probe can
      // pass where the real raise is refused). A missed ride is expensive
      // enough that this falls back rather than just logging.
      debugPrint(
        '[NavOverlay] showIncomingRideRequest failed ($e) — falling back to '
        'the full-screen notification.',
      );
      return showIncomingRideNotification(rideData);
    }
  }

  /// Tells the overlay engine which of its two overlays the window about to
  /// be raised is for (see _OverlayRouter in main.dart, which hosts both
  /// behind flutter_overlay_window's single supported entrypoint).
  ///
  /// Called BEFORE showOverlay(), not after. The engine is not started by
  /// showOverlay — MainActivity.kt seeds it at app startup — so its listener
  /// is already up and running by the time any of this happens, and sending
  /// first means the window attaches with the correct content already
  /// rendered. Sending afterwards instead left the freshly-raised window
  /// showing whatever the router had rendered last for a beat before the
  /// hint landed and corrected it: a return bubble flashing inside a
  /// ride-request-sized sheet.
  ///
  /// Still repeated over ~1.5s rather than sent once. shareData has no
  /// listener-side acknowledgement, so a single send that lands in a gap —
  /// the engine restarted by OverlayService after a process death, say —
  /// is simply gone with no way to tell. The repeats are free: the router
  /// keys each decision and ignores the same one arriving twice.
  /// Where a routing hint is left so the overlay engine can come and fetch it
  /// itself, instead of depending on the hint being successfully pushed to it.
  ///
  /// shareData is not a reliable delivery mechanism for this, and the device
  /// logs show exactly how it fails: eight "hint sent" lines, no forwarding
  /// log on the native side, a router that received nothing, and an overlay
  /// window that attached completely empty. A BasicMessageChannel whose
  /// handler has been cleared does not throw — it completes the sender's
  /// Future with a null reply — so a message that reaches nobody is
  /// indistinguishable from one that lands.
  ///
  /// And the handler genuinely does get cleared. flutter_overlay_window keeps
  /// the handler on a single static (WindowSetup.messenger) that every
  /// engine's onAttachedToEngine overwrites and every onDetachedFromEngine
  /// sets to null — with three isolates in play here (the app, the FCM
  /// background handler, and the overlay engine), whether the static still
  /// points at a live handler when a push arrives comes down to the order the
  /// app happened to be backgrounded in. That is the "sometimes the overlay
  /// doesn't appear" report, exactly.
  ///
  /// A stash inverts the dependency: the sender writes where it can, and the
  /// overlay engine reads when it knows a window has opened (see
  /// _OverlayRouterState's own window watcher). Nothing in between has to
  /// work. shareData is still sent, and still wins when it does work, because
  /// it is faster.
  static const String _pendingHintKey = 'pending_overlay_hint';

  static Future<void> _stashRoutingHint(Map<String, dynamic> payload) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingHintKey,
        jsonEncode(<String, dynamic>{
          'stashed_at': DateTime.now().millisecondsSinceEpoch,
          'payload': payload,
        }),
      );
      debugPrint('[NavOverlay] hint stashed: ${payload['type']}');
    } catch (e) {
      // Nothing is lost that was not already at risk — shareData still runs.
      debugPrint('[NavOverlay] could not stash the hint: $e');
    }
  }

  static Future<void> _broadcastRoutingHint(
    Map<String, dynamic> payload,
  ) async {
    // First, and awaited: this is the copy that does not depend on any
    // channel still being wired up, and the window is about to be raised.
    await _stashRoutingHint(payload);

    // Schedule extended past the original 1.5s to cover a COLD overlay engine.
    //
    // The old window assumed the engine was already up, which holds while the
    // app is alive. With the app swiped away it is not: OverlayService now
    // discards the dead cached engine and builds a new one (see its own
    // NRIDE PATCH note), and that new engine has to load the app bundle, run
    // overlayMain and reach the router's listener before any hint can be
    // received. Every send before that point goes nowhere — silently, since
    // shareData has no listener-side acknowledgement. The later sends are what
    // a freshly-booted router actually catches; the repeats stay free because
    // the router keys each decision and ignores a duplicate.
    //
    // These are cumulative gaps, not absolute offsets — the last send lands
    // around 6.1s after the first.
    int elapsedMs = 0;
    for (final delayMs in const [0, 300, 500, 700, 1000, 1200, 1200, 1200]) {
      if (delayMs > 0) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
      elapsedMs += delayMs;
      try {
        await FlutterOverlayWindow.shareData(payload);
        debugPrint(
          '[NavOverlay] hint sent (+${elapsedMs}ms): ${payload['type']}',
        );
      } catch (e) {
        debugPrint('[NavOverlay] shareData attempt failed: $e');
      }
    }
  }

  /// Keeps watching for a window that attaches after the fallback has already
  /// given up on it, and tidies up after itself when one does.
  ///
  /// The attach poll above cannot wait indefinitely — a ride request is
  /// time-critical and the notification is what reaches a driver whose device
  /// refuses overlays at all. But "slower than we were willing to wait" and
  /// "never" are different outcomes, and rebuilding a cold overlay engine from
  /// scratch (which is what happens when the app has been swiped away — see
  /// OverlayService.onCreate) is genuinely slow on some devices.
  ///
  /// When the window does turn up late, the card is real and on screen, so it
  /// is told it may sound and the now-redundant notification is withdrawn. The
  /// driver ends up with exactly one alert either way, which is the point:
  /// leaving both would mean a notification sound and a ringtone for the same
  /// ride.
  static Future<void> _confirmALateAttach(String raiseId) async {
    for (final int waitMs in const [700, 700, 900, 900]) {
      await Future<void>.delayed(Duration(milliseconds: waitMs));
      bool attached = false;
      try {
        attached = await FlutterOverlayWindow.isActive();
      } catch (e) {
        debugPrint('[NavOverlay] late attach check failed: $e');
        return;
      }
      if (!attached) continue;
      debugPrint(
        '[NavOverlay] the overlay attached late — confirming the card and '
        'withdrawing the notification that stood in for it.',
      );
      await hideIncomingRideNotification();
      await _broadcastConfirmation(<String, dynamic>{
        'type': 'ride_request_visible',
        '_raise_id': raiseId,
      });
      return;
    }
  }

  /// Sends a short burst of the same message, for payloads that are not a
  /// routing decision and so must not wait out [_broadcastRoutingHint]'s full
  /// cold-engine schedule.
  ///
  /// By the time either of this method's callers runs, the engine is known to
  /// be up — one has just seen a window attach, the other is closing a card
  /// that is on screen — so the only thing being insured against here is
  /// shareData's lack of a delivery acknowledgement.
  static Future<void> _broadcastConfirmation(
    Map<String, dynamic> payload,
  ) async {
    // Cumulative gaps, so the last lands ~2s after the first. Long enough to
    // cover an overlay engine that finished booting mid-burst — the router
    // keys and bounds what it receives, so repeats cost nothing.
    for (final int delayMs in const [0, 250, 600, 1200]) {
      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      try {
        await FlutterOverlayWindow.shareData(payload);
      } catch (e) {
        debugPrint('[NavOverlay] ${payload['type']} send failed: $e');
      }
    }
  }

  /// Takes down an incoming-ride offer that is no longer available — because
  /// another driver accepted it, the rider cancelled, or it expired.
  ///
  /// This is the piece the "why am I still being shown a ride someone else
  /// already took" problem needs, and it is deliberately three things at once,
  /// because a single offer can be on screen in three different forms:
  ///
  ///  - the overlay card, in its own engine (told to drop the card, then the
  ///    window closed);
  ///  - the full-screen-intent notification, which is what devices that refuse
  ///    overlays get instead;
  ///  - nothing at all, if the driver never saw it — in which case every call
  ///    below is a harmless no-op.
  ///
  /// [bookingId] is matched against the card on screen so a stale close for an
  /// older offer cannot take down a newer one. Pass null to close whatever is
  /// showing.
  ///
  /// BACKEND: this is only as fast as the signal that calls it. See the
  /// `ride_request_closed` branch in main.dart's FCM handlers — the backend
  /// needs to send a data-only push to every *other* candidate driver the
  /// moment a booking is accepted. Until it does, the overlay still closes
  /// itself within ~3s off RideOfferWatch's own polling, which is the fallback
  /// rather than the design.
  static Future<void> closeRideRequest({String? bookingId}) async {
    debugPrint(
      '[NavOverlay] closing ride request ${bookingId ?? "(any)"} — no longer '
      'available',
    );
    await hideIncomingRideNotification();
    // Started together, window closed without waiting on the message — the
    // same ordering, and for the same reason, as dismissOverlay above: the
    // driver should stop seeing a dead offer immediately, and the engine can
    // catch up with dropping the widget afterwards.
    final Future<void> told = _broadcastConfirmation(<String, dynamic>{
      'type': 'ride_request_closed',
      'booking_id': bookingId ?? '',
    });
    await _closeAnyExistingOverlay();
    await told;
  }

  /// Removes the bubble. Safe to call even if none is currently showing.
  static Future<void> hideReturnBubble() => _closeAnyExistingOverlay();

  /// Notification id for the "tap to return" notification. Fixed, so
  /// re-posting it updates the existing one rather than stacking duplicates
  /// every time navigation is launched.
  static const int _returnNotificationId = 90210;

  /// Version-suffixed deliberately, and bumped whenever the channel's
  /// importance changes.
  ///
  /// A notification channel's importance is immutable once Android has
  /// created it: later code changes are ignored for the life of the install,
  /// and only the user can alter it from system settings. v1 was created at
  /// IMPORTANCE_LOW, and a device dump confirmed Android filing it into
  /// `Aggregate_SilentSection` — the collapsed "Silent" tray section, hidden
  /// behind an extra tap on Android 14+ and OEM skins, i.e. invisible in
  /// practice. Re-pitching it on installs that already created v1 is only
  /// possible under a new id, hence this.
  static const String _returnChannelId = 'ride_navigation_return_v3';

  /// A persistent "tap to get back to Nride" notification, posted whenever
  /// the driver is handed off to an external maps app.
  ///
  /// This exists because the floating bubble cannot be relied on. The bubble
  /// needs SYSTEM_ALERT_WINDOW, and on a large slice of real devices that is
  /// not sufficient on its own: Vivo/Funtouch, Xiaomi/MIUI, Oppo and Realme
  /// all gate overlays behind an *additional* vendor-specific permission
  /// ("floating window", "display pop-up while running in background") that
  /// granting the standard Android one does not cover, and several of them
  /// kill the overlay's service under battery optimisation anyway. Drivers on
  /// those phones reported no bubble even after enabling "display over other
  /// apps", which is exactly that.
  ///
  /// A notification has none of those problems — it needs no overlay
  /// permission, no vendor allowance, and survives the app being backgrounded.
  /// So this is the dependable path back, and the bubble is now the nicer
  /// bonus on devices that permit it rather than the only way home.
  ///
  /// High importance, with sound — the driver has to actually notice this
  /// one.
  ///
  /// It was originally silent/low on the reasoning that it must not interrupt
  /// live navigation. That was the wrong trade: LOW pins it to the collapsed
  /// "Silent" tray section for the life of the install, which made it
  /// indistinguishable from not existing at all. A way back into the app that
  /// the driver never finds is worth nothing, so this now announces itself
  /// once, properly — heads-up banner, sound and vibration.
  ///
  /// `onlyAlertOnce` is what keeps that from becoming obnoxious: it alerts on
  /// the first post and then stays quiet for every subsequent update of the
  /// same notification, so a driver mid-navigation isn't re-interrupted.
  /// Which leg the currently-posted notification describes, so a genuinely
  /// new handoff can be told apart from a repeat post of the same one.
  static String? _postedLeg;

  /// [leg] identifies the journey this handoff is for ('pickup', 'drop').
  /// Posting a *different* leg cancels first and re-posts, which is what
  /// makes it alert again.
  ///
  /// Without that, the second handoff was invisible. This notification uses
  /// a fixed id with `onlyAlertOnce: true`, so re-posting it while it is
  /// already showing is a silent in-place update — and because the text was
  /// identical for both legs, nothing about it changed either. The driver
  /// got the banner once, on the way to the rider, and then nothing at all
  /// when they were handed off again for the ride itself. `onlyAlertOnce`
  /// is still right *within* a leg (the 15s poll can re-post freely); it
  /// just must not span two different ones.
  static Future<void> showReturnNotification({
    String leg = 'pickup',
    String title = 'Ride in progress',
    String body = 'Tap to return to Nride driver',
  }) async {
    try {
      final bool isNewLeg = _postedLeg != null && _postedLeg != leg;
      if (isNewLeg) {
        // A fresh post alerts; an update to an existing one does not.
        await fln.FlutterLocalNotificationsPlugin().cancel(
          id: _returnNotificationId,
        );
      }
      _postedLeg = leg;

      final androidDetails = fln.AndroidNotificationDetails(
        _returnChannelId,
        'Return to ride',
        channelDescription:
            'Lets you tap back into Nride driver while navigating in a maps app.',
        importance: fln.Importance.high,
        priority: fln.Priority.high,
        // Not swipe-dismissible: losing it mid-ride would strand the driver
        // in the maps app with no obvious way back, which is the whole
        // problem this is here to solve.
        ongoing: true,
        autoCancel: false,
        playSound: true,
        enableVibration: true,
        // Alerts once, then silent on re-posts — see the note above.
        onlyAlertOnce: true,
        showWhen: false,
        // Explicitly kept out of any auto-grouped summary, so it can't be
        // folded away into a collapsed bundle with other app notifications.
        ticker: body,
      );

      final plugin = fln.FlutterLocalNotificationsPlugin();
      final android = plugin
          .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin
          >();

      // Superseded channels, removed so they don't linger. Because
      // importance is immutable, fixing it means publishing a new channel id
      // (see [_returnChannelId]) — and without this, every driver's
      // notification settings would slowly accumulate a stack of identically
      // named "Return to ride" entries, all dead but all still toggleable.
      // Someone disabling the wrong one and concluding the feature is broken
      // is a very easy mistake to leave lying around.
      for (final stale in const [
        'ride_navigation_return',
        'ride_navigation_return_v2',
      ]) {
        await android?.deleteNotificationChannel(channelId: stale);
      }

      // Created explicitly rather than relying on show()'s implicit
      // creation, so the channel definitely exists with these exact
      // settings before anything is posted to it.
      await android?.createNotificationChannel(
        const fln.AndroidNotificationChannel(
          _returnChannelId,
          'Return to ride',
          description:
              'Lets you tap back into Nride driver while navigating in a maps app.',
          // Must match the AndroidNotificationDetails above — the channel is
          // what Android actually enforces; the per-notification values are
          // only honoured within what the channel already permits.
          importance: fln.Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // The single most likely reason this notification "doesn't appear":
      // notifications are switched off for the app entirely (Android 13+
      // POST_NOTIFICATIONS denied, or the driver muted the app in system
      // settings). show() below then does nothing, silently and without
      // throwing, which is impossible to tell apart from a bug in this code
      // unless it's stated outright — hence this log.
      final enabled = await android?.areNotificationsEnabled();
      debugPrint(
        '[NavOverlay] return notification: notificationsEnabled=$enabled',
      );

      await plugin.show(
        id: _returnNotificationId,
        title: title,
        body: body,
        notificationDetails: fln.NotificationDetails(android: androidDetails),
      );
      debugPrint('[NavOverlay] return notification posted (leg=$leg)');
    } catch (e) {
      // Same rule as the bubble: a missing way-back-in is bad, but it must
      // never take the ride itself down with it.
      debugPrint('[NavOverlay] return notification failed: $e');
    }
  }

  /// Notification id for an incoming ride request. Distinct from
  /// [_returnNotificationId] so a ride offered *during* an active ride
  /// (a back-to-back queued booking) doesn't overwrite the driver's way back
  /// into the app.
  static const int _rideRequestNotificationId = 90211;

  /// Channel for incoming ride requests, kept separate from the
  /// return-to-ride one so a driver can silence one without losing the
  /// other, and because this one wants IMPORTANCE_MAX (the only importance
  /// Android will honour a full-screen intent from) while that one is HIGH.
  static const String _rideRequestChannelId = 'ride_request_fullscreen_v1';

  /// Action ids on the ride-request notification, matched in main.dart's
  /// notification-response handlers. Shared constants rather than literals
  /// repeated at both ends, because a typo between them fails silently — the
  /// button simply does nothing.
  static const String rideNotificationAcceptActionId = 'ride_request_accept';
  static const String rideNotificationDeclineActionId = 'ride_request_decline';

  /// The permission-free fallback for an incoming ride request, used whenever
  /// the overlay card cannot be shown.
  ///
  /// This closes the gap that made the overlay's vendor-permission problem
  /// actually cost money: before this, a driver on a phone that refuses
  /// overlays got *nothing at all* when a ride was offered while they were
  /// outside the app, because the in-app poll it fell back to only runs while
  /// the app is open. See showIncomingRideRequest.
  ///
  /// Why a full-screen intent specifically: it is the only notification form
  /// that can take over the screen the way the overlay card did, so on the
  /// devices where it is granted the driver's experience is close to
  /// unchanged. Where it isn't granted, Android degrades it to a heads-up
  /// banner with sound — still an unmissable, permission-free signal, which
  /// is the actual requirement. Both outcomes are fine; neither is checked
  /// for before posting.
  ///
  /// On Android 14+ USE_FULL_SCREEN_INTENT starts revoked for apps that are
  /// not primarily calling/alarm apps, so the takeover is the exception
  /// rather than the rule on new devices. [OemOverlaySupport
  /// .openFullScreenIntentSettings] can ask for it; the home screen's
  /// onboarding is where that belongs, not here — this is called from the FCM
  /// background isolate, where there is no UI to ask from.
  ///
  /// Returns whether the notification was posted.
  static Future<bool> showIncomingRideNotification(
    Map<String, dynamic> rideData,
  ) async {
    try {
      final plugin = fln.FlutterLocalNotificationsPlugin();
      final android = plugin
          .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin
          >();

      await android?.createNotificationChannel(
        const fln.AndroidNotificationChannel(
          _rideRequestChannelId,
          'New ride requests',
          description:
              'Alerts you to a new ride even when you are using another app.',
          // MAX, not HIGH. Android only honours a full-screen intent from a
          // channel at IMPORTANCE_HIGH or above, and channel importance is
          // immutable after creation — getting this wrong would need a new
          // channel id to fix, exactly as it did for the return notification
          // (see _returnChannelId). MAX also keeps it out of the collapsed
          // "Silent" tray section that made the v1 return notification
          // effectively invisible.
          importance: fln.Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      final String pickup =
          (rideData['pickup_address'] ?? '').toString().trim();
      final String drop = (rideData['drop_address'] ?? '').toString().trim();
      final String fare = (rideData['final_amount'] ?? '').toString().trim();

      // Built from whichever fields the push actually carried rather than a
      // fixed format string: this payload comes straight from FCM (see
      // firebaseMessagingBackgroundHandler), and a missing drop address or
      // fare is normal, not an error. Interpolating them blindly produced
      // "Pickup:  ·  · ₹" on those pushes.
      final parts = <String>[
        if (fare.isNotEmpty) '₹$fare',
        if (pickup.isNotEmpty) 'Pickup: $pickup',
        if (drop.isNotEmpty) 'Drop: $drop',
      ];
      final String body = parts.isEmpty
          ? 'Tap to view the request'
          : parts.join('\n');

      final androidDetails = fln.AndroidNotificationDetails(
        _rideRequestChannelId,
        'New ride requests',
        channelDescription:
            'Alerts you to a new ride even when you are using another app.',
        importance: fln.Importance.max,
        priority: fln.Priority.max,
        // The takeover. Silently ignored where the permission isn't held,
        // which is why nothing above is conditional on it.
        fullScreenIntent: true,
        // Tells Android this is time-critical, which is what lets it through
        // Do Not Disturb's "calls only" mode and keeps it at the top of the
        // shade rather than sorted among ordinary notifications.
        category: fln.AndroidNotificationCategory.call,
        // Dismissible, unlike the return notification: a ride request goes
        // stale, and a driver should be able to swipe away one they've
        // decided against without it sticking around looking live.
        ongoing: false,
        autoCancel: true,
        playSound: true,
        enableVibration: true,
        // Deliberately NOT onlyAlertOnce (which the return notification does
        // use): every ride offer is a distinct event the driver must be
        // alerted to, even if a previous one is still on screen.
        onlyAlertOnce: false,
        // Expires itself rather than lingering after the offer is gone. The
        // window is generous relative to the ~30s the overlay card allows,
        // because this path exists for a driver who is inside another app and
        // may take a moment to notice.
        timeoutAfter: 90000,
        styleInformation: fln.BigTextStyleInformation(body),
        ticker: 'New ride request',
        // Accept and Decline, so this path is a real alternative to the
        // overlay card rather than a strictly worse one.
        //
        // Without these the notification could only be tapped, which drops the
        // driver into the app to find the request and answer it a second time
        // — and on the devices where the overlay cannot attach at all, that
        // was the *only* way to take a ride offered from outside the app.
        //
        // showsUserInterface is true on Accept because accepting genuinely
        // needs the app: the booking has to be fetched and acceptRidesTrip run
        // against a real BuildContext. The action records the tap and brings
        // the app forward, and HomeController picks it up from there — the
        // same handoff the overlay card's own Accept uses, deliberately, so
        // there is one accept implementation and not two.
        actions: <fln.AndroidNotificationAction>[
          // Opens the app too, matching Accept and the overlay card's own
          // Decline: a driver who has answered a request wants to be back in
          // the app ready for the next one, not left in another app with
          // nothing to show the tap registered.
          const fln.AndroidNotificationAction(
            rideNotificationDeclineActionId,
            'Decline',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          const fln.AndroidNotificationAction(
            rideNotificationAcceptActionId,
            'Accept',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );

      final enabled = await android?.areNotificationsEnabled();
      final canTakeOver = await OemOverlaySupport.canUseFullScreenIntent();
      debugPrint(
        '[NavOverlay] ride-request notification: notificationsEnabled='
        '$enabled fullScreenIntentGranted=$canTakeOver '
        '(false just means heads-up instead of takeover)',
      );

      await plugin.show(
        id: _rideRequestNotificationId,
        title: 'New ride request',
        body: body,
        notificationDetails: fln.NotificationDetails(android: androidDetails),
        // Carried so the tap handler can route straight to this booking
        // rather than dropping the driver on the home screen to wait for the
        // next poll.
        //
        // `id` first, and that ordering is the fix: the FCM payload the
        // backend actually sends for a new ride names this field `id` (the
        // same name NewBookingNearByModel.fromJson reads), NOT `booking_id`.
        // Reading only booking_id produced a null payload on every push, so
        // a tapped notification had no booking to route to. booking_id is
        // kept as a fallback because the in-app REST shapes do use it.
        payload:
            (rideData['id'] ?? rideData['booking_id'])?.toString(),
      );
      debugPrint('[NavOverlay] ride-request notification posted');
      return true;
    } catch (e) {
      debugPrint('[NavOverlay] ride-request notification failed: $e');
      return false;
    }
  }

  /// Clears the incoming-ride notification — call once the request has been
  /// accepted, declined, or has expired, so a stale offer isn't left on
  /// screen looking actionable.
  static Future<void> hideIncomingRideNotification() async {
    try {
      await fln.FlutterLocalNotificationsPlugin().cancel(
        id: _rideRequestNotificationId,
      );
    } catch (e) {
      debugPrint('[NavOverlay] ride-request notification cancel failed: $e');
    }
  }

  /// Clears the notification above. Safe to call when none is showing.
  static Future<void> hideReturnNotification() async {
    // Cleared with it, so the next ride's first handoff counts as a new leg
    // and alerts properly instead of being treated as a repeat of the last
    // ride's.
    _postedLeg = null;
    try {
      await fln.FlutterLocalNotificationsPlugin().cancel(
        id: _returnNotificationId,
      );
    } catch (e) {
      debugPrint('[NavOverlay] return notification cancel failed: $e');
    }
  }
}
