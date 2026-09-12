import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;

/// Owns the Google Navigation SDK session: licensing checks, the one-time
/// terms-of-service acceptance, destinations, and guidance start/stop.
///
/// This is the structural answer to the problem the floating bubble and the
/// return notification only ever mitigated. Both of those exist because the
/// driver was being handed off to the *separate* Google Maps app and then had
/// to find their way back — and on a large share of real devices the bubble
/// half of that simply doesn't work (see NavOverlayService and
/// OemOverlaySupport). Turn-by-turn rendered inside this app removes the
/// handoff entirely: a driver who never leaves cannot be stranded outside.
///
/// Deliberately fails soft in every direction. The Navigation SDK is a paid,
/// separately-provisioned Google Maps Platform product, so a build whose API
/// key has not had "Navigation SDK for Android" enabled — or whose billing
/// has lapsed, or whose quota is spent — must still ship working navigation.
/// Every failure path here marks the SDK unusable and lets the caller fall
/// back to the existing external-Maps handoff, which is why that code has not
/// been deleted.
class InAppNavigationService {
  InAppNavigationService._();

  /// Shown in the SDK's mandatory terms-of-service dialog. Google requires
  /// this dialog before any navigation session can start, and requires it to
  /// name the company whose app is doing the navigating.
  static const String _termsTitle = 'Nride Navigation';
  static const String _companyName = 'Nride';

  /// Latched once the SDK tells us it cannot be used on this build — a key
  /// without Navigation SDK enabled, exhausted quota, or a failed
  /// initialization.
  ///
  /// Latched rather than re-checked because these are all install-level or
  /// billing-level facts, not transient ones: retrying `setDestinations` on
  /// an unauthorised key costs a round trip and a delay at the exact moment
  /// the driver pressed Start Ride, every single time, and can only ever
  /// produce the same answer. Cleared only by a process restart, which is
  /// also when a newly-provisioned key would first take effect.
  static bool _permanentlyUnavailable = false;

  /// Why the SDK was ruled out, for logs and for the one-line explanation the
  /// ride screen shows when it silently falls back to external Maps.
  static String? _unavailableReason;

  static String? get unavailableReason => _unavailableReason;

  /// Whether the SDK has been ruled out for the rest of this process.
  ///
  /// The distinction this exposes is the one the ride screen needs to make and
  /// previously could not: [isAvailable] returning false covers both "this
  /// build can never navigate in-app" (unprovisioned key, spent quota, iOS)
  /// and "not ready *yet*" (session still being created, terms accepted a
  /// moment from now, SDK without a location fix). Those want opposite
  /// handling — the first must hand off to external Maps, the second must be
  /// retried — and collapsing them is what sent rides to Google Maps for the
  /// rest of a shift after one slow first frame.
  static bool get isPermanentlyUnavailable =>
      !_platformSupported || _permanentlyUnavailable;

  /// Whether the driver has accepted the SDK's mandatory terms.
  ///
  /// Read by the ride screen to tell a *recoverable* miss (terms still
  /// outstanding, so retry) from a permanent one. Never prompts.
  static Future<bool> areTermsAccepted() async {
    if (!_platformSupported || _permanentlyUnavailable) return false;
    try {
      return await nav.GoogleMapsNavigator.areTermsAccepted();
    } catch (e) {
      debugPrint('[InAppNav] areTermsAccepted check failed: $e');
      return false;
    }
  }

  /// Whether in-app guidance is currently running.
  ///
  /// Read by the ride screen to suppress the return-to-app bubble and
  /// notification: both exist to get a driver back from *another app*, and
  /// posting them while the driver is looking at navigation inside this app
  /// is noise at best — a heads-up banner over live turn-by-turn at worst.
  static bool get isNavigating => _isNavigating;
  static bool _isNavigating = false;

  /// True only where the plugin has a real implementation. iOS is excluded
  /// deliberately: it needs its own API key, Swift Package Manager setup and
  /// background-mode entries in Info.plist, none of which this app has done —
  /// so on iOS the external-Maps path stays the whole story rather than
  /// failing at runtime.
  static bool get _platformSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Whether in-app navigation can be used at all right now.
  ///
  /// Cheap after the first call — the expensive part (session creation) is
  /// done once and remembered.
  static Future<bool> isAvailable() async {
    if (!_platformSupported) return false;
    if (_permanentlyUnavailable) return false;
    try {
      // Bounded, because this is the first thing the ride screen awaits and it
      // is awaited unawaited-style from a post-frame callback: an answer that
      // arrives minutes later arrives after the leg it was asked about, and
      // acting on it then is how turn-by-turn ended up starting once the ride
      // was already over. A timeout here reads as "not ready", which the ride
      // screen retries — see its _maybeStartPickupNavigation.
      return await ensureSession().timeout(_startTimeout);
    } on TimeoutException {
      debugPrint(
        '[InAppNav] the navigation session was still not ready after '
        '${_startTimeout.inSeconds}s — reporting in-app navigation as '
        'unavailable for now.',
      );
      return false;
    }
  }

  /// Accepts the SDK's terms and builds the session ahead of time, from the
  /// home screen, so the first ride does not have to.
  ///
  /// This exists because of a measured five-minute stall. The terms dialog is
  /// mandatory before any session can start, and [ensureSession] used to show
  /// it wherever it was first called — which was the ride screen, at the
  /// instant the driver pressed Start Ride or verified the OTP. The dialog
  /// then sat there waiting for a tap the driver had no reason to expect,
  /// `startNavigation` stayed parked on that await, and navigation appeared
  /// only whenever somebody finally noticed the dialog. On the reported ride
  /// that was about five minutes after the trip had gone `ongoing`.
  ///
  /// This is the same mistake, and the same fix, as the overlay permission:
  /// this codebase already learned once that a consent step belonging to a
  /// feature must not be collected at the moment the feature is needed —
  /// see _maybeAskOverlayPermission, which was moved off the pickup screen
  /// for exactly this reason.
  ///
  /// Safe to call on every launch. Terms acceptance persists in the SDK, so
  /// this is a no-op once the driver has accepted, and a session that already
  /// exists short-circuits on the isInitialized() check.
  static Future<bool> prepareAheadOfFirstRide() async {
    if (!_platformSupported) return false;
    if (_permanentlyUnavailable) return false;
    debugPrint('[InAppNav] pre-warming the navigation session');
    return ensureSession(allowTermsPrompt: true);
  }

  /// Accepts terms (once, ever) and creates the navigation session.
  ///
  /// Order is mandated by the SDK: the terms dialog must be accepted before
  /// `initializeNavigationSession`, and a session that is initialized without
  /// it throws. [nav.GoogleMapsNavigator.areTermsAccepted] persists across
  /// launches, so the driver sees the dialog on their first ride and never
  /// again.
  /// [allowTermsPrompt] must be true for the terms dialog to be shown, and
  /// only [prepareAheadOfFirstRide] passes it.
  ///
  /// Every ride-time caller leaves it false, which is what guarantees the
  /// ride path can never block on a dialog. If terms are somehow still
  /// unaccepted when a ride starts (pre-warming failed, or the driver
  /// declined during onboarding), this returns false immediately and the
  /// caller falls back to the external Maps handoff — the driver gets
  /// navigation now and the in-app version next launch, instead of a ride
  /// that stalls behind a modal.
  static Future<bool> ensureSession({bool allowTermsPrompt = false}) {
    if (!_platformSupported) return Future<bool>.value(false);
    if (_permanentlyUnavailable) return Future<bool>.value(false);

    // One setup at a time, shared by every concurrent caller.
    //
    // Setup is now kicked off from the home screen the moment it mounts, and
    // the ride path calls isAvailable() on top of that — so two calls being in
    // flight together is the normal case, not an edge one. Without this, the
    // second caller would run the whole sequence again while the first was
    // still parked on `showTermsAndConditionsDialog`, since acceptance has not
    // been recorded yet at that point: two terms dialogs stacked on the driver,
    // and two initializeNavigationSession calls behind them.
    //
    // A ride-time caller must not inherit a prompting setup's wait, though —
    // that is precisely the five-minute stall this class exists to avoid — so
    // it only joins an in-flight setup that is already non-prompting.
    final inFlight = _sessionSetup;
    if (inFlight != null && (allowTermsPrompt || !_setupIsPrompting)) {
      return inFlight;
    }
    if (inFlight != null) {
      // A prompting setup is up and this is a ride. Don't wait on the dialog.
      debugPrint(
        '[InAppNav] the terms dialog is still open — this ride will use the '
        'external Maps handoff rather than wait on it.',
      );
      return Future<bool>.value(false);
    }

    _setupIsPrompting = allowTermsPrompt;
    final setup = _runSessionSetup(allowTermsPrompt: allowTermsPrompt);
    _sessionSetup = setup;
    return setup.whenComplete(() {
      _sessionSetup = null;
      _setupIsPrompting = false;
    });
  }

  /// The setup currently in flight, if any. See [ensureSession].
  static Future<bool>? _sessionSetup;

  /// Whether [_sessionSetup] is one that may show the terms dialog.
  static bool _setupIsPrompting = false;

  static Future<bool> _runSessionSetup({required bool allowTermsPrompt}) async {
    try {
      if (await nav.GoogleMapsNavigator.isInitialized()) return true;

      if (!await nav.GoogleMapsNavigator.areTermsAccepted()) {
        if (!allowTermsPrompt) {
          // Deliberately NOT prompting here. See the doc above and
          // prepareAheadOfFirstRide: prompting on this path is what produced
          // the five-minute stall between the ride going ongoing and
          // navigation appearing.
          debugPrint(
            '[InAppNav] navigation terms not accepted yet and this is a '
            'ride-time call — falling back to external Maps rather than '
            'blocking the ride on a dialog. The home screen will ask on the '
            'next launch.',
          );
          return false;
        }

        // Bounded, because an unanswered dialog otherwise wedges this service
        // for the rest of the process: _sessionSetup would stay in flight
        // forever, and every ride-time ensureSession() refuses to join a
        // prompting setup — so every leg of every ride would silently take the
        // external Maps handoff with nothing explaining why. The dialog is
        // native and needs a live Activity; when it cannot be shown at all,
        // this is the only thing that notices.
        final accepted = await nav.GoogleMapsNavigator
            .showTermsAndConditionsDialog(_termsTitle, _companyName)
            .timeout(
              const Duration(minutes: 2),
              onTimeout: () {
                debugPrint(
                  '[InAppNav] the navigation terms dialog went unanswered — '
                  'giving up on this attempt. It will be offered again on the '
                  'next launch.',
                );
                return false;
              },
            );
        if (!accepted) {
          // A refusal is the driver's decision, not a fault, and it is not
          // permanent — they are asked again next launch. Not latched into
          // _permanentlyUnavailable for that reason.
          debugPrint(
            '[InAppNav] driver declined the navigation terms — using the '
            'external Google Maps handoff.',
          );
          return false;
        }
      }

      await nav.GoogleMapsNavigator.initializeNavigationSession(
        // continueService keeps guidance alive if the driver swipes the app
        // out of recents mid-ride, which on a driver app is far more likely
        // to be a mis-swipe than an intent to abandon the trip. The SDK runs
        // its own foreground service for this; it is not affected by the
        // overlay service's OEM battery problems.
        taskRemovedBehavior: nav.TaskRemovedBehavior.continueService,
      );

      // Voice guidance on, matching what the driver got from the Google Maps
      // app. Without this the SDK renders the route silently, which is a
      // downgrade the driver would notice immediately and read as a bug.
      await nav.GoogleMapsNavigator.setAudioGuidance(
        nav.NavigationAudioGuidanceSettings(
          guidanceType: nav.NavigationAudioGuidanceType.alertsAndGuidance,
          isBluetoothAudioEnabled: true,
          isVibrationEnabled: true,
        ),
      );

      debugPrint('[InAppNav] navigation session ready');
      return true;
    } catch (e) {
      // The overwhelmingly likely cause on a first run is an API key without
      // "Navigation SDK for Android" enabled on its Cloud project, which the
      // SDK reports by throwing here rather than by a status code.
      _markUnavailable('session initialization failed: $e');
      return false;
    }
  }

  /// Routes to [lat]/[lng] and starts turn-by-turn guidance.
  ///
  /// [title] is what the SDK shows for the destination in its own UI, so it
  /// should be something the driver recognises ("Pickup", "Drop-off") rather
  /// than a coordinate.
  ///
  /// Returns true only when guidance actually started. Every false is a
  /// signal to the caller to fall back to the external Maps handoff, and the
  /// reason is logged rather than surfaced as an exception — a routing
  /// failure must not take down the Start Ride flow that triggered it.
  /// Bumped by [stopNavigation] and [disposeSession].
  ///
  /// Every start captures this on entry and re-checks it after each await. It
  /// is what makes "the trip is over" able to cancel a start that is still in
  /// flight — and a start being in flight for minutes is not hypothetical:
  /// session creation and the SDK's own location acquisition both happen
  /// behind these awaits, and the ride screen fires the pickup handoff
  /// unawaited on its very first frame. Without this, a start begun on the way
  /// to the pickup could resolve after the whole ride had finished and switch
  /// guidance on then — the driver watching turn-by-turn to a completed trip's
  /// destination, which is exactly what was reported.
  static int _generation = 0;

  /// Longest a single start may take before it is abandoned as not-ready.
  ///
  /// The SDK calls behind this have no timeout of their own, so a wedged one
  /// simply never returns. That is survivable when the caller can retry (the
  /// ride screen does), and unsurvivable when it cannot — so it is bounded
  /// here rather than at each call site. Generous enough to cover a genuine
  /// cold session plus the location retry budget below.
  static const Duration _startTimeout = Duration(seconds: 20);

  static Future<bool> startNavigation({
    required double lat,
    required double lng,
    required String title,
  }) async {
    final int gen = _generation;

    // "Superseded" covers both a stop and a newer start. Checked after every
    // await below, since each is a place the trip can end while this waits.
    bool superseded() {
      if (gen == _generation) return false;
      debugPrint(
        '[InAppNav] abandoning the start toward $title — navigation was '
        'stopped or restarted while it was still being set up.',
      );
      return true;
    }

    try {
      if (!await ensureSession().timeout(_startTimeout)) return false;
      if (superseded()) return false;

      final status = await _setDestinationWithLocationRetry(
        lat: lat,
        lng: lng,
        title: title,
      ).timeout(_startTimeout);
      if (superseded()) return false;

      if (status != nav.NavigationRouteStatus.statusOk) {
        _handleRouteFailure(status);
        return false;
      }

      await nav.GoogleMapsNavigator.startGuidance().timeout(_startTimeout);

      // Last check, and the one that matters most: guidance is now actually
      // running, so a stop that landed while startGuidance was in flight has
      // already come and gone and would leave it running forever.
      if (superseded()) {
        await _forceStopGuidance();
        return false;
      }

      _isNavigating = true;
      debugPrint('[InAppNav] guidance started toward $title ($lat, $lng)');
      return true;
    } on TimeoutException {
      // Not latched as permanently unavailable: a slow session is a timing
      // fault, and the caller's retry is the right response.
      debugPrint(
        '[InAppNav] start toward $title timed out after '
        '${_startTimeout.inSeconds}s — treating in-app navigation as not '
        'ready rather than failed.',
      );
      return false;
    } catch (e) {
      debugPrint('[InAppNav] startNavigation failed: $e');
      return false;
    }
  }

  /// Stops guidance without touching [_generation] — for unwinding a start
  /// that has just been superseded, where bumping it again would cancel the
  /// newer start that superseded it.
  static Future<void> _forceStopGuidance() async {
    try {
      if (await nav.GoogleMapsNavigator.isGuidanceRunning()) {
        await nav.GoogleMapsNavigator.stopGuidance();
      }
      await nav.GoogleMapsNavigator.clearDestinations();
    } catch (e) {
      debugPrint('[InAppNav] could not unwind a superseded start: $e');
    }
  }

  /// Sets the destination, retrying while the SDK has no location fix yet.
  ///
  /// `setDestinations` returns [nav.NavigationRouteStatus.locationUnavailable]
  /// rather than throwing when the SDK's own location engine hasn't produced
  /// a fix — which is normal for the first second or two after a session is
  /// created, and is exactly when Start Ride fires. Treating that first
  /// reading as a routing failure would send a driver to external Maps on
  /// almost every ride, so it is retried on a short budget instead.
  ///
  /// The SDK's location engine is separate from this app's Geolocator
  /// pipeline, so a fix already held by HomeController does not count here.
  static Future<nav.NavigationRouteStatus> _setDestinationWithLocationRetry({
    required double lat,
    required double lng,
    required String title,
  }) async {
    // Ramped rather than a flat 500ms × 8, and the total budget is
    // deliberately about the same (~4s) — this is purely about when the FIRST
    // fix is noticed.
    //
    // The SDK's location engine typically produces a fix a few hundred
    // milliseconds in. On a flat 500ms poll, a fix ready at 120ms was not
    // acted on until 500ms and one ready at 520ms not until 1000ms — a delay
    // entirely of this loop's own making, paid on every single ride, at the
    // exact moment the driver is waiting for navigation to appear. Checking
    // hard early and backing off after costs nothing and removes it.
    const List<int> gapsMs = <int>[120, 150, 200, 250, 350, 450, 500, 500, 500,
        500, 500];

    nav.NavigationRouteStatus status = nav.NavigationRouteStatus.unknown;

    for (int attempt = 0; attempt < gapsMs.length; attempt++) {
      status = await nav.GoogleMapsNavigator.setDestinations(
        nav.Destinations(
          waypoints: <nav.NavigationWaypoint>[
            nav.NavigationWaypoint.withLatLngTarget(
              title: title,
              target: nav.LatLng(latitude: lat, longitude: lng),
            ),
          ],
          displayOptions: nav.NavigationDisplayOptions(
            showDestinationMarkers: true,
            showStopSigns: true,
            showTrafficLights: true,
          ),
          routingOptions: nav.RoutingOptions(
            travelMode: nav.NavigationTravelMode.driving,
            // Left at the SDK's defaults deliberately: a driver's tolls and
            // highways preference is a real setting, but guessing one on
            // their behalf silently changes the fare-relevant route. If this
            // is ever exposed, it belongs in driver settings, not here.
          ),
        ),
      );

      if (status != nav.NavigationRouteStatus.locationUnavailable) {
        return status;
      }

      debugPrint(
        '[InAppNav] no SDK location fix yet (attempt ${attempt + 1}/'
        '${gapsMs.length}) — retrying',
      );
      await Future<void>.delayed(Duration(milliseconds: gapsMs[attempt]));
    }

    return status;
  }

  /// Turns a non-OK routing status into either a permanent opt-out or a
  /// one-off failure.
  ///
  /// The distinction matters: an unauthorised key or an exhausted quota will
  /// fail identically on every subsequent ride, so latching it means the
  /// driver pays the delay once instead of at every Start Ride. A network
  /// blip or a genuinely unroutable destination is per-ride and must not
  /// disable the feature for the rest of the session.
  static void _handleRouteFailure(nav.NavigationRouteStatus status) {
    switch (status) {
      case nav.NavigationRouteStatus.apiKeyNotAuthorized:
        _markUnavailable(
          'the API key is not authorised for the Navigation SDK. Enable '
          '"Navigation SDK for Android" on the Google Cloud project behind '
          'this build\'s Maps key, and make sure billing is active.',
        );
      case nav.NavigationRouteStatus.quotaExceeded:
      case nav.NavigationRouteStatus.quotaCheckFailed:
        _markUnavailable('Navigation SDK quota exceeded or uncheckable.');
      case nav.NavigationRouteStatus.networkError:
        debugPrint(
          '[InAppNav] route failed: network error. Falling back to external '
          'Maps for this ride only.',
        );
      case nav.NavigationRouteStatus.routeNotFound:
      case nav.NavigationRouteStatus.waypointError:
      case nav.NavigationRouteStatus.duplicateWaypointsError:
      case nav.NavigationRouteStatus.noWaypointsError:
        debugPrint(
          '[InAppNav] route failed: $status — the destination is most likely '
          'not routable. Falling back to external Maps.',
        );
      case nav.NavigationRouteStatus.locationUnavailable:
        debugPrint(
          '[InAppNav] route failed: the SDK never got a location fix. '
          'Falling back to external Maps.',
        );
      default:
        debugPrint('[InAppNav] route failed: $status');
    }
  }

  static void _markUnavailable(String reason) {
    _permanentlyUnavailable = true;
    _unavailableReason = reason;
    debugPrint(
      '[InAppNav] IN-APP NAVIGATION DISABLED for this run — $reason '
      'The external Google Maps handoff will be used instead.',
    );
  }

  /// Stops guidance and clears the route.
  ///
  /// Called when the ride ends and when the driver leaves the navigation
  /// screen. Not `cleanup()` — that tears the whole session down, and the
  /// next leg of the same ride (pickup then drop-off) would then have to pay
  /// session creation again.
  static Future<void> stopNavigation() async {
    _isNavigating = false;
    // Before the early returns below, and before any await: this is what
    // cancels a start still being set up. The ride screen's dispose() is the
    // caller that matters — "this screen is going away" is the app's only
    // signal that the trip is over, and a pickup-leg start fired on its first
    // frame can still be parked on session creation at that point.
    _generation++;
    if (!_platformSupported || _permanentlyUnavailable) return;
    try {
      if (await nav.GoogleMapsNavigator.isGuidanceRunning()) {
        await nav.GoogleMapsNavigator.stopGuidance();
      }
      await nav.GoogleMapsNavigator.clearDestinations();
      debugPrint('[InAppNav] guidance stopped and route cleared');
    } catch (e) {
      debugPrint('[InAppNav] stopNavigation failed: $e');
    }
  }

  /// Tears the session down completely, releasing the SDK's foreground
  /// service. For sign-out and end-of-shift, not between legs of a ride.
  static Future<void> disposeSession() async {
    _isNavigating = false;
    _generation++;
    if (!_platformSupported) return;
    try {
      await nav.GoogleMapsNavigator.cleanup();
      debugPrint('[InAppNav] navigation session cleaned up');
    } catch (e) {
      debugPrint('[InAppNav] cleanup failed: $e');
    }
  }
}
