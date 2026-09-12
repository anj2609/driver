import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/services/in_app_navigation_service.dart';

/// Full-screen turn-by-turn navigation, rendered by the Google Navigation
/// SDK inside this app.
///
/// The whole point of this screen is that it must not feel like a downgrade
/// from being thrown into the Google Maps app — that was the bar the driver
/// was already used to. So every piece of the SDK's own navigation chrome is
/// switched on explicitly in [_onViewCreated] rather than left to defaults:
/// the manoeuvre header, the ETA/distance footer, the speedometer and speed
/// limit, the trip progress bar, the recenter button and traffic prompts.
/// Voice guidance is configured once at session level (see
/// InAppNavigationService.ensureSession).
///
/// What is added on top of the SDK's UI is deliberately minimal — a single
/// bar giving the driver the one thing external Maps could never give them:
/// a one-tap route back to the ride screen where the OTP, the rider's number
/// and the End Ride button live.
class InAppNavigationScreen extends StatefulWidget {
  const InAppNavigationScreen({
    super.key,
    required this.destinationLabel,
    this.subtitle,
  });

  /// "Pickup" or "Drop-off" — shown in the bar and used as the SDK's own
  /// destination title.
  final String destinationLabel;

  /// The address being navigated to, shown under the label when known.
  final String? subtitle;

  @override
  State<InAppNavigationScreen> createState() => _InAppNavigationScreenState();
}

class _InAppNavigationScreenState extends State<InAppNavigationScreen> {
  nav.GoogleNavigationViewController? _controller;
  StreamSubscription<nav.OnArrivalEvent>? _arrivalSubscription;

  /// Kept so the bar can show live ETA without the driver having to read it
  /// off the SDK's own footer, which sits at the opposite end of the screen.
  String? _etaText;
  StreamSubscription<nav.RemainingTimeOrDistanceChangedEvent>?
  _remainingSubscription;

  @override
  void initState() {
    super.initState();
    _listenForNavigationEvents();
  }

  /// True once the platform view has actually attached and been configured.
  ///
  /// Guards the arrival listener. The Navigation SDK's platform view is
  /// created asynchronously and, measured on device, [_onViewCreated] can fire
  /// a full five seconds after this screen is pushed — so "guidance says we
  /// arrived" and "there is a view on screen to close" are genuinely
  /// independent facts, and acting on the first before the second is what
  /// broke the pickup leg.
  bool _viewReady = false;

  void _listenForNavigationEvents() {
    // Arrival is what ends this screen. Without it the driver would sit on a
    // finished route until they thought to press back, which on the pickup
    // leg delays the OTP step that unblocks the whole ride.
    _arrivalSubscription = nav.GoogleMapsNavigator.setOnArrivalListener((
      nav.OnArrivalEvent event,
    ) {
      debugPrint('[InAppNav] arrived at ${event.waypoint.title}');

      // Ignored until the view exists. When the driver is already standing at
      // the destination — routine on the pickup leg, since they may accept a
      // ride from the rider's doorstep — the SDK reports arrival within a
      // couple of seconds of guidance starting. Popping then tore the screen
      // down while its platform view was still being created, and the
      // now-orphaned _onViewCreated arrived to a dead route: every
      // configuration call came back PlatformException(viewNotFound), and the
      // plugin was left in a state where the NEXT navigation screen's view
      // never attached at all — a black map for the rest of the ride. That is
      // the failure this guard exists for, not a hypothetical race.
      //
      // Not deferred-then-popped once ready, deliberately: that would just
      // reinstate the flash. A driver who is already there keeps the screen
      // and leaves it with the "Back to ride" bar, which is the honest
      // outcome — there was never a route to drive.
      if (!_viewReady) {
        debugPrint(
          '[InAppNav] arrival ignored — the navigation view is not attached '
          'yet, so there is nothing to close. The driver was most likely '
          'already at the destination when guidance started.',
        );
        return;
      }
      if (mounted) Navigator.of(context).maybePop(true);
    });

    _remainingSubscription = nav.GoogleMapsNavigator
        .setOnRemainingTimeOrDistanceChangedListener((
          nav.RemainingTimeOrDistanceChangedEvent event,
        ) {
          if (!mounted) return;
          final minutes = (event.remainingTime / 60).ceil();
          final km = event.remainingDistance / 1000;
          final distance = km >= 1
              ? '${km.toStringAsFixed(1)} km'
              : '${event.remainingDistance.round()} m';
          // Arrival clock as well as remaining time, because the SDK's own
          // footer — which showed it — is switched off in _onViewCreated so
          // this bar can occupy the bottom edge. Losing the wall-clock
          // arrival would be a real downgrade from the Google Maps app the
          // driver is used to, so it is reproduced here rather than dropped.
          final arrival = DateTime.now().add(
            Duration(seconds: event.remainingTime.round()),
          );
          final hour = arrival.hour % 12 == 0 ? 12 : arrival.hour % 12;
          final minute = arrival.minute.toString().padLeft(2, '0');
          final suffix = arrival.hour < 12 ? 'am' : 'pm';
          setState(() {
            _etaText = '$minutes min  ·  $distance  ·  $hour:$minute $suffix';
          });
          // Thresholds left at their 1s/1m defaults: this only drives a text
          // label, and a coarser threshold would make the ETA visibly lag
          // the SDK's own footer sitting right below it.
        });
  }

  /// Applies one navigation-UI toggle, isolating its failure from the rest.
  ///
  /// Each call is guarded individually rather than the whole sequence sharing
  /// one try/catch, which is what the first version did. That version lost
  /// every setting after the first failure — including
  /// [nav.GoogleNavigationViewController.followMyLocation], the call that puts
  /// the camera into the driving perspective — so a single unsupported toggle
  /// silently downgraded the whole screen.
  Future<void> _apply(String name, Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      debugPrint('[InAppNav] $name failed (continuing): $e');
    }
  }

  Future<void> _onViewCreated(
    nav.GoogleNavigationViewController controller,
  ) async {
    // The screen can already be gone by the time this fires — see _viewReady.
    // Configuring a view whose route has been popped produces nothing but a
    // run of PlatformException(viewNotFound) and risks leaving the plugin
    // holding a half-initialised view.
    if (!mounted) {
      debugPrint(
        '[InAppNav] view created after the screen was disposed — skipping '
        'configuration',
      );
      return;
    }
    _controller = controller;

    await _apply(
      'setMyLocationEnabled',
      () => controller.setMyLocationEnabled(true),
    );

    // Switched on one by one rather than trusting
    // NavigationUIEnabledPreference.automatic to imply them. `automatic`
    // only decides whether the navigation UI appears at all once guidance
    // is running; the individual pieces below are separately toggleable and
    // are what make this read as real navigation rather than a moving map.
    await _apply(
      'setNavigationUIEnabled',
      () => controller.setNavigationUIEnabled(true),
    );
    // The manoeuvre card: next turn, street name, distance to it.
    await _apply(
      'setNavigationHeaderEnabled',
      () => controller.setNavigationHeaderEnabled(true),
    );
    // The SDK's own ETA/distance footer, deliberately OFF.
    //
    // It occupies the bottom edge — exactly where this screen's "Back to
    // ride" bar has to live, since the manoeuvre header owns the top and the
    // bar is the driver's only route back to the OTP and End Ride controls.
    // With both on, measured on device, the bar covered the footer's "18 min"
    // and clipped the Report button beside it.
    //
    // setPadding() was tried first, which is the SDK's documented way to
    // declare an obscured region: it did not relocate the footer, and it
    // disturbed the guidance camera. So the footer is switched off and the
    // bar carries its content instead — remaining time, distance and arrival
    // clock, from setOnRemainingTimeOrDistanceChangedListener, which is the
    // same source the footer renders from.
    await _apply(
      'setNavigationFooterEnabled',
      () => controller.setNavigationFooterEnabled(false),
    );

    // setNavigationTripProgressBarEnabled(true) belongs here and is
    // deliberately NOT called. It crashes the app.
    //
    // Measured on device (Vivo V2407, Android 15, Navigation SDK 6.2.2): the
    // call throws a PlatformException out of the SDK's own view layer —
    //   mv.b: u{propertyType=VIEW_STUB_STUB_IF, propertyValue=null}
    //   Cause: ab{propertyType=BACKGROUND, view=FrameLayout, propertyValue=null}
    // — while inflating the progress bar's view stub, and then, one layout
    // pass later, the same failure resurfaces on the Android main thread as a
    // FATAL EXCEPTION that kills the process. That second one cannot be caught
    // from Dart at all: [_apply] above swallows the PlatformException and the
    // app dies anyway, roughly a second later. It presents as the navigation
    // screen going black and the app disappearing.
    //
    // The cause is theme resolution: the stub's layout reads a background
    // attribute this app's theme does not define (LaunchTheme/NormalTheme
    // descend from @android:style/Theme.Light.NoTitleBar, not an AppCompat or
    // Material theme — see MainActivity.kt, which also documents why
    // re-parenting those styles fights flutter_native_splash). Every other
    // toggle on this screen was verified on the same device with the bar
    // removed, and all of them pass.
    //
    // What is lost is the thin vertical route-progress strip. The header,
    // footer, speedometer, speed limit, traffic cards and prompts — the parts
    // a driver actually reads — are unaffected. Re-enabling this needs a
    // Material-derived Activity theme first, and re-verification on device.

    await _apply(
      'setSpeedometerEnabled',
      () => controller.setSpeedometerEnabled(true),
    );
    await _apply(
      'setSpeedLimitIconEnabled',
      () => controller.setSpeedLimitIconEnabled(true),
    );
    await _apply(
      'setTrafficIncidentCardsEnabled',
      () => controller.setTrafficIncidentCardsEnabled(true),
    );
    await _apply(
      'setTrafficPromptsEnabled',
      () => controller.setTrafficPromptsEnabled(true),
    );

    // Tilted is the driving perspective — the camera pitched forward along
    // the heading, which is what the Google Maps app uses during guidance.
    // topDownNorthUp would technically be "following" but reads as a map,
    // not as navigation, which is exactly the downgrade this screen exists
    // to avoid.
    await _apply(
      'followMyLocation',
      () => controller.followMyLocation(nav.CameraPerspective.tilted),
    );

    // Last, and only on a still-mounted screen: this is what arms the arrival
    // listener above. Before this point an arrival event has no view to close.
    if (mounted) {
      _viewReady = true;
      debugPrint('[InAppNav] navigation view configured and ready');
    }
  }

  @override
  void dispose() {
    _arrivalSubscription?.cancel();
    _remainingSubscription?.cancel();
    // Guidance is deliberately NOT stopped here. Leaving this screen means
    // the driver went to the ride screen for the OTP or to call the rider —
    // not that the trip ended. The SDK keeps guiding (with its own
    // foreground-service notification) and re-entering this screen re-attaches
    // to the running session. The ride flow owns the actual stop, on arrival
    // or when the ride ends, via InAppNavigationService.stopNavigation.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Black, not the app background: the SDK renders edge to edge and any
      // gap during view attach reads as a flash of the wrong colour against
      // the dark navigation map.
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: nav.GoogleMapsNavigationView(
              onViewCreated: _onViewCreated,
              // `automatic` shows the navigation UI as soon as guidance is
              // running, which it already is by the time this screen is
              // pushed (see InAppNavigationService.startNavigation). Note
              // this enum has no `enabled` value in 0.7.0 — `automatic` is
              // the on position, and setNavigationUIEnabled(true) above makes
              // it explicit regardless.
              initialNavigationUIEnabledPreference:
                  nav.NavigationUIEnabledPreference.automatic,
            ),
          ),
          _buildReturnBar(context),
        ],
      ),
    );
  }

  /// The one piece of chrome this app adds over the SDK's own.
  ///
  /// Pinned to the bottom rather than the top because the SDK's manoeuvre
  /// header owns the top of the screen — putting anything there either covers
  /// the next turn or pushes it down, and the next turn is the single most
  /// important thing on this screen.
  Widget _buildReturnBar(BuildContext context) {
    // viewPadding, not padding.
    //
    // MediaQueryData.padding is viewPadding minus viewInsets, so it reports
    // the system navigation bar as *zero* whenever something else is already
    // occupying that edge — most immediately the soft keyboard, which on this
    // flow is always up seconds earlier (the driver has just typed the rider's
    // OTP) and is still animating out while this screen builds, with the
    // Activity on adjustResize. The bar then laid itself out 12px from the
    // bottom of the window and stayed there, directly underneath the phone's
    // gesture pill or three-button bar. viewPadding reports where the system
    // bars actually are regardless of any of that, which is the question being
    // asked here: this screen draws edge-to-edge under them on purpose (the
    // map should fill the display) and only its own chrome needs to clear them.
    //
    // Not SafeArea, because that would inset the whole Stack and pull the map
    // in with it, leaving a black band where the navigation view used to run
    // to the edge.
    final double systemNavBar = MediaQuery.viewPaddingOf(context).bottom;
    return Positioned(
      left: 12,
      right: 12,
      bottom: systemNavBar + 12,
      child: Material(
        color: ColorResources.whiteColor,
        borderRadius: BorderRadius.circular(14),
        elevation: 8,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).maybePop(false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  color: ColorResources.appColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Watches the notifier, not widget.destinationLabel:
                      // this screen survives a leg change (the re-route path
                      // in startInAppNavigation keeps it rather than pushing
                      // a replacement), so its constructor argument is only
                      // ever correct for the first leg.
                      ValueListenableBuilder<String>(
                        valueListenable: _navDestinationLabel,
                        builder: (context, label, _) => Text(
                          'Back to ride  ·  '
                          '${label.isEmpty ? widget.destinationLabel : label}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: ColorResources.blackcolor,
                          ),
                        ),
                      ),
                      if (_etaText != null || widget.subtitle != null)
                        Text(
                          _etaText ?? widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorResources.textColorForGrey,
                          ),
                        ),
                    ],
                  ),
                ),
                // Recenter is on the SDK's own UI too, but that button sits
                // wherever the SDK puts it and is easy to miss mid-drive.
                // This is the same action within thumb reach of the bar the
                // driver is already looking at.
                IconButton(
                  tooltip: 'Recenter',
                  onPressed: () => _controller?.followMyLocation(
                    nav.CameraPerspective.tilted,
                  ),
                  icon: Icon(
                    Icons.my_location_rounded,
                    color: ColorResources.appColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Starts in-app guidance and opens [InAppNavigationScreen] over it.
///
/// Returns false when the Navigation SDK could not take the trip — an
/// unprovisioned API key, a declined terms dialog, an unroutable destination
/// — which is the caller's signal to fall back to the external Google Maps
/// handoff. See InAppNavigationService for why every one of those paths fails
/// soft rather than throwing.
/// Whether an [InAppNavigationScreen] is currently on the navigator stack.
///
/// Module-level rather than passed around because the thing it guards against
/// is two *unrelated* callers pushing a screen each — see
/// [startInAppNavigation].
bool _navScreenOpen = false;

/// The destination label currently being navigated to.
///
/// Exists because the re-route path below keeps the *existing* screen rather
/// than pushing a new one, so the label passed to that screen's constructor
/// goes stale the moment a leg changes: the route was to the drop-off while
/// the bar still read "Pickup". Observed on device. The screen watches this
/// instead of its own constructor argument.
final ValueNotifier<String> _navDestinationLabel = ValueNotifier<String>('');

Future<bool> startInAppNavigation({
  required BuildContext context,
  required double lat,
  required double lng,
  required String destinationLabel,
  String? subtitle,
  /// Whether this navigation is still wanted, re-asked after every await.
  ///
  /// Starting guidance is not instant — a cold session, the SDK acquiring its
  /// own location fix and the route request all sit behind awaits here, and
  /// the ride screen fires the pickup handoff unawaited on its first frame. So
  /// by the time this function is ready to show anything, the leg it was asked
  /// about may be long finished. It used to push regardless, which is why
  /// turn-by-turn appeared *after the ride had ended*: not a stray launch, the
  /// pickup leg's own start finally completing.
  ///
  /// Defaults to always-wanted so existing callers are unaffected; the ride
  /// screen passes a real predicate.
  bool Function()? stillWanted,

  /// Called the instant guidance is actually running and the navigation view
  /// is about to be shown — i.e. the moment the driver stops waiting.
  ///
  /// Needed because this function does not return until the navigation screen
  /// is *popped*, which is the end of the leg, not the end of the wait. A
  /// caller showing a "finding the best route" indicator (see the ride
  /// screen's _navProgressPill) and clearing it on the returned Future would
  /// hold that indicator up for the entire trip, and then flash it once more
  /// on the way back out.
  VoidCallback? onGuidanceStarted,
}) async {
  bool wanted() => stillWanted?.call() ?? true;

  if (!wanted()) {
    debugPrint(
      '[InAppNav] not starting navigation to $destinationLabel — the leg that '
      'asked for it is no longer current.',
    );
    return false;
  }

  // Re-route in place rather than stacking a second screen.
  //
  // This is the fix for the black navigation view that appeared mid-ride.
  // Nothing stopped this function being entered twice: the ride screen calls
  // it from the pickup path, from the OTP-verify drop handoff, and from the
  // driver's own "navigate" button, and it rebuilds every few seconds off the
  // track-ride poll. A second call pushed a second InAppNavigationScreen on
  // top of the first, and the plugin supports exactly ONE navigation view at
  // a time — the new view attaches while the old one is still alive, and the
  // loser renders black. Popping back then revealed the black one, which is
  // precisely "before moving to any other screen a black screen was shown".
  //
  // A leg change (pickup -> drop) is a real reason to want a new destination,
  // so this does not just bail: it hands the new destination to the existing,
  // already-attached session and lets that screen keep rendering. One view,
  // new route.
  if (_navScreenOpen) {
    debugPrint(
      '[InAppNav] a navigation screen is already open — re-routing it to '
      '$destinationLabel instead of pushing a second one.',
    );
    final rerouted = await InAppNavigationService.startNavigation(
      lat: lat,
      lng: lng,
      title: destinationLabel,
    );
    if (rerouted && !wanted()) {
      await InAppNavigationService.stopNavigation();
      return false;
    }
    // Only on success: a failed re-route leaves the old route running, so the
    // bar must keep naming the destination the driver is actually heading to.
    if (rerouted) {
      _navDestinationLabel.value = destinationLabel;
      onGuidanceStarted?.call();
    }
    return rerouted;
  }

  final started = await InAppNavigationService.startNavigation(
    lat: lat,
    lng: lng,
    title: destinationLabel,
  );
  if (!started) return false;
  // Both conditions mean the same thing — there is nothing to show this on any
  // more — and both are checked *after* the start, because that is the await
  // the trip can end behind. Guidance is stopped rather than left running, or
  // the SDK's foreground service outlives the flow that started it with
  // nothing able to cancel it.
  if (!context.mounted || !wanted()) {
    debugPrint(
      '[InAppNav] guidance to $destinationLabel started but is no longer '
      'wanted — stopping it instead of opening the navigation screen.',
    );
    await InAppNavigationService.stopNavigation();
    return false;
  }

  // Set around the push and cleared in a finally: the flag has to be false
  // again however this route leaves the stack — arrival pop, driver back
  // gesture, or an exception on the way out — or one stuck `true` would
  // disable in-app navigation for the rest of the process and silently send
  // every later leg to external Maps.
  _navScreenOpen = true;
  _navDestinationLabel.value = destinationLabel;
  onGuidanceStarted?.call();
  try {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => InAppNavigationScreen(
          destinationLabel: destinationLabel,
          subtitle: subtitle,
        ),
      ),
    );
  } finally {
    _navScreenOpen = false;
  }
  return true;
}
