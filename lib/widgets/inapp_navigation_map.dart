import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/services/navigation_engine.dart';

/// Real, in-app turn-by-turn navigation — road-following route, live
/// rotating driver marker, next-turn instruction + arrow, distance/ETA,
/// route progress, off-route detection with automatic rerouting, and
/// arrival detection. No external Maps app is ever opened.
///
/// This is purely the map + nav-chrome layer. It's meant to be dropped in
/// as the first (full-bleed) child of a ride screen's Stack, with the
/// screen's own existing overlays (address card, Arrived/OTP/End
/// Ride/payment controls) layered on top exactly as before — none of that
/// business logic moves or changes.
///
/// Drives itself entirely off HomeController's existing GPS stream (via
/// GetBuilder — HomeController.update() already fires on every fix) so
/// this never starts a second, competing location subscription.
class InAppNavigationMap extends StatefulWidget {
  final double? destLat;
  final double? destLng;
  final String destLabel;

  /// The *other* end of the trip — whichever of pickup/drop isn't the
  /// current navigation target. Optional: when known, the camera keeps
  /// both this and [destLat]/[destLng] in frame together with the car
  /// (see [_fitCameraToRideBounds]) rather than tracking the car alone,
  /// so neither pin can end up pushed off-screen at any stage of the ride.
  final double? secondaryLat;
  final double? secondaryLng;
  final String secondaryLabel;

  /// Called once, the first time the driver is detected to have arrived
  /// at the destination. Deliberately just a signal — this widget never
  /// calls any ride-progression API itself; the screen decides what
  /// "arrived" should actually do (it already has its own Arrived/End
  /// Ride buttons for that).
  final VoidCallback? onArrived;

  /// Vertical space (in logical pixels) to leave clear above the
  /// instruction banner — set this to whatever height the screen's own
  /// top overlay (address/distance card, etc.) takes up, so the two don't
  /// draw on top of each other.
  final double topOffset;

  /// Vertical space (in logical pixels) to leave clear at the bottom of
  /// the map — set this to the screen's own bottom sheet/details-panel
  /// height. This map is always drawn full-bleed (Positioned.fill) behind
  /// whatever overlay the screen draws on top of it, and the camera
  /// otherwise centres the driver/destination markers on the *whole* view
  /// including the area that panel covers — on a booked/ongoing ride,
  /// where that panel can run to half the screen, the markers end up
  /// sitting behind it instead of in the visible area above it. Passed
  /// straight to GoogleMap's own `padding`, which shifts what the SDK
  /// treats as the visible/interactive map area accordingly.
  final double bottomOffset;

  /// Called on every navigation update — remaining distance, ETA,
  /// progress, current instruction, etc. Optional; screens that want to
  /// show their own "Estimated Arrival Time"/distance fields using this
  /// widget's real, route-aware numbers (rather than a separate estimate
  /// flow) can read them from here.
  final ValueChanged<NavSnapshot>? onUpdate;

  /// Whether to draw the turn-by-turn instruction banner ("159 m, Turn
  /// right onto...") over the map. Defaults on, but the driver's actual
  /// turn-by-turn guidance now comes from real Google Maps once a ride
  /// starts (see NavOverlayService) — this app's own map keeps running
  /// underneath purely for the driver marker, route line, and arrival
  /// detection the rest of this screen relies on, so a second,
  /// independent set of turn instructions the driver isn't even looking
  /// at (they're in Google Maps) is just clutter at that point. Screens
  /// pass false once the ride is actually in progress.
  final bool showInstructionBanner;

  const InAppNavigationMap({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.destLabel,
    this.secondaryLat,
    this.secondaryLng,
    this.secondaryLabel = '',
    this.onArrived,
    this.topOffset = 12,
    this.bottomOffset = 0,
    this.onUpdate,
    this.showInstructionBanner = true,
  });

  @override
  State<InAppNavigationMap> createState() => _InAppNavigationMapState();
}

class _InAppNavigationMapState extends State<InAppNavigationMap>
    with TickerProviderStateMixin {
  NavigationEngine? _engine;
  LatLng? _destination;
  GoogleMapController? _mapController;
  bool _followMode = true;
  bool _programmaticCameraMove = false;
  bool _arrivedFired = false;
  bool _routeRequested = false;
  bool _cameraInitialized = false;

  // ==================== Smooth driver-marker animation ====================
  //
  // onLocationUpdate() (and this whole widget, via the GetBuilder it's
  // rebuilt inside) fires on every raw GPS fix from HomeController's
  // stream — roughly every 5s in practice (its own Geolocator settings:
  // distanceFilter 5m, intervalDuration 5s), not the "several times a
  // second" this used to assume — see _updateAnimationTarget's own note
  // on why that assumption mattered. Each fix used to be handed straight
  // to the marker and the camera (_animateCamera, below), which moved in
  // a discrete jump every ~5s rather than gliding, and doesn't correct
  // GPS fixes that land a few metres off the road the driver is actually
  // on. This
  // interpolates between fixes over the time actually elapsed since the
  // last one, snapping each fix onto the current route first.
  AnimationController? _carAnimController;
  LatLng? _displayedPosition;
  double _displayedBearing = 0;
  LatLng? _animFrom;
  LatLng? _animTo;
  double _bearingFrom = 0;
  double _bearingTo = 0;
  DateTime? _lastFixAt;

  @override
  void dispose() {
    _carAnimController?.dispose();
    super.dispose();
  }

  LatLng? get _destLatLng =>
      (widget.destLat != null && widget.destLng != null)
          ? LatLng(widget.destLat!, widget.destLng!)
          : null;

  LatLng? get _secondaryLatLng =>
      (widget.secondaryLat != null && widget.secondaryLng != null)
          ? LatLng(widget.secondaryLat!, widget.secondaryLng!)
          : null;

  void _ensureEngine() {
    final dest = _destLatLng;
    if (dest == null) return;
    if (_destination != null &&
        _destination!.latitude == dest.latitude &&
        _destination!.longitude == dest.longitude &&
        _engine != null) {
      return;
    }
    // Destination changed (or first run) — a fresh engine for a fresh
    // route. This is what lets the very same widget serve both legs of
    // the ride (pickup, then destination) if a screen ever reuses it.
    _destination = dest;
    _engine = NavigationEngine(destination: dest);
    _routeRequested = false;
    _arrivedFired = false;
    _cameraInitialized = false;
  }

  // Cleared on failure so the next build can try again — see below.
  DateTime? _lastRouteAttemptAt;

  Future<void> _requestInitialRoute(LatLng origin) async {
    if (_routeRequested || _engine == null) return;

    // The flag used to latch on the FIRST attempt and never clear, so a
    // single failed fetch — a dropped request, a momentary Directions
    // hiccup, or simply the first GPS fix landing before the network was
    // ready — permanently gave up on routing for the whole screen visit.
    // The engine then had no route for the rest of the ride, and
    // onLocationUpdate() returns NavSnapshot.empty() (every field zero)
    // whenever it has no route. That is the other half of "ETA is 0
    // everywhere": nothing was ever going to fetch a route again.
    //
    // Throttled rather than retried flat-out, because this is driven from
    // build() and build() runs on every HomeController.update() — several
    // times a second while the location stream is live.
    final now = DateTime.now();
    if (_lastRouteAttemptAt != null &&
        now.difference(_lastRouteAttemptAt!) < const Duration(seconds: 5)) {
      return;
    }
    _lastRouteAttemptAt = now;

    _routeRequested = true;
    final ok = await _engine!.fetchRoute(origin);
    if (!mounted) return;
    if (ok) {
      setState(() {});
    } else {
      // Let the next build (≥5s from now) have another go.
      _routeRequested = false;
      debugPrint(
        '[Nav] route fetch failed for origin '
        '${origin.latitude},${origin.longitude} — will retry',
      );
    }
  }

  /// Frames the car together with both ends of the trip — the current nav
  /// target ([InAppNavigationMap.destLat]/destLng) and, when known, the
  /// other one ([InAppNavigationMap.secondaryLat]/secondaryLng) — so
  /// neither pin can end up pushed off-screen the way tightly tracking the
  /// car alone would once it's far from one or the other. Falls back to a
  /// plain centred fly-to on whatever single point is actually known yet.
  ///
  /// This replaces what used to be a tight, tilted (tilt: 45) car-follow —
  /// deliberately: a close driving-style view and "always show both pins"
  /// aren't reconcilable (fitting two potentially city-apart points in
  /// frame means zooming out, which a tilted close-up view can't do), and
  /// this widget already isn't the driver's primary turn-by-turn source
  /// once the ride is under way (see [InAppNavigationMap.showInstructionBanner]'s
  /// own note) — that's real Google Maps at that point, so this map's job
  /// is closer to a live overview than a driving cockpit.
  void _fitCameraToRideBounds(LatLng car, double bearing) {
    final map = _mapController;
    if (map == null || !_followMode) return;

    final points = <LatLng>[
      car,
      if (_destLatLng != null) _destLatLng!,
      if (_secondaryLatLng != null) _secondaryLatLng!,
    ];

    _programmaticCameraMove = true;

    if (points.length == 1) {
      map.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: car, zoom: 16)),
      );
      return;
    }

    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  void _recenter(NavSnapshot? snapshot) {
    setState(() => _followMode = true);
    final position = _displayedPosition ?? snapshot?.driverPosition;
    if (position != null) {
      _fitCameraToRideBounds(position, _displayedBearing);
    }
  }

  /// Interpolates an angle the short way round, so a marker crossing due
  /// north (359° -> 2°) turns 3° forward instead of spinning the long way
  /// back through 180°.
  double _lerpAngle(double from, double to, double t) {
    double diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (from + diff * t) % 360;
  }

  /// Projects [point] onto the nearest segment of [route], so the marker
  /// tracks the road the driver is actually on rather than a raw GPS fix
  /// that can sit a few metres off to either side of it. Lat/lng aren't a
  /// flat plane, but at street scale treating them as one — scaling the
  /// longitude delta by cos(latitude) so a degree of longitude isn't
  /// overweighted away from the equator — is accurate enough for this and
  /// far cheaper than a real geodesic projection. Falls back to the
  /// untouched point when there's no usable route yet, or when the fix
  /// lands nowhere near the route currently drawn (a stale route, or GPS
  /// drift genuinely off the road) — more honest than silently teleporting
  /// onto a road the driver isn't actually on.
  LatLng _snapToRoute(LatLng point, List<LatLng> route) {
    if (route.length < 2) return point;

    final latCos = math.cos(point.latitude * math.pi / 180);
    double bestDistSq = double.infinity;
    LatLng best = point;

    for (var i = 0; i < route.length - 1; i++) {
      final a = route[i];
      final b = route[i + 1];

      final ax = a.longitude * latCos;
      final ay = a.latitude;
      final bx = b.longitude * latCos;
      final by = b.latitude;
      final px = point.longitude * latCos;
      final py = point.latitude;

      final dx = bx - ax;
      final dy = by - ay;
      final lengthSq = dx * dx + dy * dy;

      double t = lengthSq == 0
          ? 0
          : ((px - ax) * dx + (py - ay) * dy) / lengthSq;
      t = t.clamp(0.0, 1.0);

      final projX = ax + t * dx;
      final projY = ay + t * dy;
      final distSq = (px - projX) * (px - projX) + (py - projY) * (py - projY);

      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        best = LatLng(projY, projX / latCos);
      }
    }

    // ~120m — comfortably wider than normal GPS/road-snap error, tight
    // enough to catch a genuinely stale/wrong route.
    const maxSnapDistanceDegrees = 0.0011;
    if (bestDistSq > maxSnapDistanceDegrees * maxSnapDistanceDegrees) {
      return point;
    }
    return best;
  }

  /// Feeds a fresh (raw) snapshot into the smoothing layer. Called once per
  /// genuine new GPS fix — from inside the GetBuilder's builder, alongside
  /// onLocationUpdate() itself — never from inside the animation tick, so
  /// this can't retrigger the engine's own per-fix bookkeeping (bearing
  /// hysteresis, progress, off-route strikes) on every animation frame.
  void _updateAnimationTarget(NavSnapshot snapshot) {
    final target = _snapToRoute(snapshot.driverPosition, snapshot.routePoints);
    final from = _displayedPosition;

    if (from == null) {
      // First fix this widget has ever seen — nothing to animate from.
      _displayedPosition = target;
      _displayedBearing = snapshot.bearing;
      _lastFixAt = DateTime.now();
      return;
    }

    // HomeController.update() can fire without the position genuinely
    // having moved (a heading-only update, or simply a duplicate tick) —
    // restarting the animation from a value to itself would just reset its
    // clock for no visible reason.
    //
    // Compared with a tolerance, NOT for exact equality, and that distinction
    // is the whole reason this screen was usable. [_displayedPosition] is
    // produced by the lerp in [_onAnimTick], and `from + (to - from) * 1.0` is
    // not guaranteed to land exactly on `to` in floating point — it lands a
    // few parts in 1e12 away. Exact equality therefore never held, so every
    // single rebuild saw "the position changed", restarted the animation and,
    // worse, refired [_fitCameraToRideBounds] — an eased Google Maps camera
    // transition — on top of the one already running.
    //
    // Measured on device, parked at the pickup with the ride in `arrived`:
    // hundreds of animation restarts per second, each one logging and each one
    // re-fitting the camera, converging 28.687980000002227 → 28.687980000000024
    // and never arriving. The map never settled, the UI thread never got a
    // quiet frame, and what the driver saw was a white screen.
    //
    // A stationary driver is exactly the case that exposes it: with no real
    // movement, nothing ever washes the residue out.
    //
    // 1e-7 degrees is ~1cm — far below anything GPS can resolve, so no real
    // movement is ever swallowed, and far above the rounding residue.
    const double positionEpsilon = 1e-7;

    // Two degrees, not a hair's breadth.
    //
    // [snapshot.bearing] is the device compass whenever one is reporting (see
    // NavigationEngine.onLocationUpdate), and a compass never returns the same
    // number twice — it wanders by fractions of a degree continuously, even on
    // a phone sitting still. A tolerance tight enough to call that "changed"
    // means every rebuild restarts the position glide for a rotation nobody
    // can see, which is what kept this animation alive indefinitely after the
    // position target had settled.
    //
    // Two degrees of heading is imperceptible on a car marker; a real turn is
    // tens of degrees and still animates normally.
    const double bearingEpsilon = 2.0;

    // Compared against the DESTINATION of the animation already running, not
    // against where the car currently is.
    //
    // "Has the car arrived?" is the wrong question, and asking it is what kept
    // this restarting forever. This method runs from inside the GetBuilder, so
    // it fires on every HomeController.update() — several times a second —
    // while an animation typically spans ~5s. Mid-glide the car legitimately
    // is not at the target yet, so a position-based check always said
    // "changed", and the restart below reset the controller to value = 0 from
    // wherever the car had got to.
    //
    // That is Zeno's paradox in a widget: each restart covers a fraction of
    // the remaining distance and is then itself cut short, so controller.value
    // never reaches 1.0, the exact-assignment in [_onAnimTick] never fires,
    // and the gap shrinks forever without closing. Measured on device: 28.6874398
    // → 28.6873996 over tens of seconds, still going.
    //
    // The right question is whether the DESTINATION moved. If it has not, the
    // animation already in flight is heading to the correct place and must be
    // left alone to finish.
    final LatLng? currentTarget = _animTo;
    if (currentTarget != null &&
        (currentTarget.latitude - target.latitude).abs() < positionEpsilon &&
        (currentTarget.longitude - target.longitude).abs() < positionEpsilon &&
        (_bearingTo - snapshot.bearing).abs() < bearingEpsilon) {
      return;
    }

    // No animation has ever run, and the car is already where it should be.
    if (currentTarget == null &&
        (from.latitude - target.latitude).abs() < positionEpsilon &&
        (from.longitude - target.longitude).abs() < positionEpsilon &&
        (_displayedBearing - snapshot.bearing).abs() < bearingEpsilon) {
      return;
    }

    debugPrint(
      '[Nav] animating car: from=$from to=$target '
      'bearing=${_displayedBearing.toStringAsFixed(1)}'
      '->${snapshot.bearing.toStringAsFixed(1)} '
      '(raw fix was ${snapshot.driverPosition})',
    );

    final now = DateTime.now();
    // Was clamped to a 150-1200ms ceiling on the assumption this GPS
    // stream delivers several fixes a second — it doesn't. HomeController's
    // own Geolocator settings (distanceFilter: 5, intervalDuration: 5s)
    // mean a real fix arrives roughly every 5 seconds. Capping the glide
    // at 1.2s meant the car sat still for the other ~3.8s of every real
    // gap, then dashed through its whole movement in a burst — reported
    // as "the car jumps to a different location" (accurately: for most of
    // each interval, it wasn't animating at all). Widened to actually
    // span a real gap between fixes instead of truncating it.
    final elapsedMs =
        _lastFixAt == null ? 5000 : now.difference(_lastFixAt!).inMilliseconds;
    _lastFixAt = now;
    final durationMs = elapsedMs.clamp(600, 6000);

    _animFrom = from;
    _animTo = target;
    _bearingFrom = _displayedBearing;
    _bearingTo = snapshot.bearing;

    final controller = _carAnimController ??=
        AnimationController(vsync: this)..addListener(_onAnimTick);
    controller
      ..duration = Duration(milliseconds: durationMs)
      ..value = 0
      ..forward();

    // Once per genuine fix, not once per animation frame — see
    // _fitCameraToRideBounds's own note on why a bounds-fit can't run at
    // that frequency the way a plain centre-follow could.
    if (_cameraInitialized) {
      _fitCameraToRideBounds(target, snapshot.bearing);
    }
  }

  void _onAnimTick() {
    if (!mounted) return;
    final from = _animFrom;
    final to = _animTo;
    final controller = _carAnimController;
    if (from == null || to == null || controller == null) return;

    final t = controller.value;
    if (t >= 1.0) {
      // Assigned, not interpolated, and this is the other half of the fix in
      // _updateAnimationTarget's guard. Letting the final frame come out of
      // the lerp leaves the displayed position a rounding error short of the
      // target forever; the tolerance above stops that from restarting the
      // animation, and this stops the error existing in the first place so it
      // cannot accumulate across fixes.
      _displayedPosition = to;
      _displayedBearing = _bearingTo;
    } else {
      _displayedPosition = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
      _displayedBearing = _lerpAngle(_bearingFrom, _bearingTo, t);
    }
    // Camera framing (car + both trip ends) happens once per genuine fix in
    // _updateAnimationTarget, not every animation frame here — a bounds-fit
    // is its own eased camera transition (newLatLngBounds), and
    // re-triggering an eased transition dozens of times a second would
    // just fight itself instead of tracking smoothly.
  }

  @override
  Widget build(BuildContext context) {
    _ensureEngine();
    final engine = _engine;
    final dest = _destination;

    return GetBuilder<HomeController>(
      builder: (controller) {
        final lat = controller.latitude;
        final lng = controller.longitude;

        // No destination means no engine, and neither ever arrives on its own
        // — _ensureEngine() bails out early when destLat/destLng are null, so
        // returning a spinner here left the map area loading forever while the
        // rest of the screen rendered normally. That is a missing-data state,
        // not a loading one: show the driver their own position on a live map
        // (no route overlay) rather than a progress indicator that will never
        // resolve.
        if (engine == null || dest == null) {
          if (lat == null || lng == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(lat, lng),
              zoom: 15,
            ),
            padding: EdgeInsets.only(bottom: widget.bottomOffset),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          );
        }

        if (lat == null || lng == null) {
          return GoogleMap(
            initialCameraPosition: CameraPosition(target: dest, zoom: 14),
            padding: EdgeInsets.only(bottom: widget.bottomOffset),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          );
        }

        final driverPos = LatLng(lat, lng);

        if (!engine.hasRoute) {
          // Kick off the first fetch once we actually have a position to
          // route from — fire-and-forget, this rebuilds itself via
          // setState once it resolves (see _requestInitialRoute).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _requestInitialRoute(driverPos);
          });
        }

        final snapshot = engine.onLocationUpdate(
          driverPos,
          deviceHeading: controller.heading,
        );

        if (snapshot.hasArrived && !_arrivedFired) {
          _arrivedFired = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onArrived?.call();
          });
        }

        if (widget.onUpdate != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onUpdate?.call(snapshot);
          });
        }

        // Feeds the smoothing layer from this genuine new fix — once per
        // real GetBuilder rebuild, never from inside the animation tick
        // itself (see _updateAnimationTarget's own note on why that
        // distinction matters here).
        _updateAnimationTarget(snapshot);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _mapController == null) return;
          if (!_cameraInitialized) {
            // The first framing — every camera move after this is the
            // once-per-fix bounds refit in _updateAnimationTarget (or the
            // Recenter button's own one-shot fly-to).
            _cameraInitialized = true;
            _fitCameraToRideBounds(
              _displayedPosition ?? snapshot.driverPosition,
              _displayedBearing,
            );
          }
        });

        final polylines = <Polyline>{
          if (snapshot.routePoints.isNotEmpty)
            Polyline(
              polylineId: const PolylineId('nav_route'),
              points: snapshot.routePoints,
              width: 6,
              // Off-route stays a distinct warning colour — a real,
              // useful signal, not just decoration — but the normal path
              // is now plain black, matching the reference design.
              color: snapshot.isOffRoute ? Colors.orange : Colors.black,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
        };

        // Rebuilds every animation frame while the marker is gliding
        // between fixes — scoped to just this subtree (map, markers,
        // banner), not the GetBuilder above it, so the engine's own
        // per-fix bookkeeping in onLocationUpdate() only ever runs once
        // per real GPS update rather than once per frame.
        return AnimatedBuilder(
          animation: _carAnimController ?? kAlwaysCompleteAnimation,
          builder: (context, _) {
            final displayPosition = _displayedPosition ?? snapshot.driverPosition;
            final displayBearing = _displayedPosition != null
                ? _displayedBearing
                : snapshot.bearing;

            final markers = <Marker>{
              Marker(
                markerId: const MarkerId('nav_driver'),
                position: displayPosition,
                icon: controller.carIcon ?? BitmapDescriptor.defaultMarker,
                rotation: displayBearing,
                anchor: const Offset(0.5, 0.5),
                flat: true,
                // Explicit, not left to insertion-order tie-breaking — the
                // car is the one thing that must never render underneath
                // the destination/secondary dots.
                zIndexInt: 2,
              ),
              Marker(
                markerId: const MarkerId('nav_destination'),
                position: dest,
                // A plain dot icon needs centring on its coordinate, not
                // anchored at its base the way a pin-shaped icon would be.
                icon: controller.userIcon ?? BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
                infoWindow: InfoWindow(title: widget.destLabel),
                zIndexInt: 1,
              ),
              // The other end of the trip — shown alongside the current
              // nav target so both pickup and drop stay visible together
              // with the car, at every stage of the ride (see
              // _fitCameraToRideBounds's own note).
              if (_secondaryLatLng != null)
                Marker(
                  markerId: const MarkerId('nav_secondary'),
                  position: _secondaryLatLng!,
                  icon: controller.userIcon ?? BitmapDescriptor.defaultMarker,
                  anchor: const Offset(0.5, 0.5),
                  infoWindow: InfoWindow(title: widget.secondaryLabel),
                  zIndexInt: 1,
                ),
            };

            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: driverPos, zoom: 16),
                  onMapCreated: (c) {
                    _mapController = c;
                  },
                  onCameraMoveStarted: () {
                    if (_programmaticCameraMove) {
                      _programmaticCameraMove = false;
                      return;
                    }
                    // A move we didn't trigger — the driver panned/zoomed
                    // manually. Drop out of follow mode until they tap
                    // recenter, instead of yanking the map back under them.
                    if (_followMode) setState(() => _followMode = false);
                  },
                  padding: EdgeInsets.only(bottom: widget.bottomOffset),
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  // None of these three were disabled on this instance —
                  // tapping the driver/destination markers can raise the
                  // native "open in Maps" toolbar button, and tilting or
                  // rotating the map (it's shown tilted, per _animateCamera's
                  // own tilt: 45) reveals a compass button; both are native
                  // chrome positioned by the platform SDK itself, so
                  // neither reliably respects whatever the screen's own
                  // Flutter-drawn overlay (bottom sheet, controls) is
                  // meant to be covering.
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  markers: markers,
                  polylines: polylines,
                ),

                // ---- Turn-by-turn instruction banner ----
                if (widget.showInstructionBanner)
                  Positioned(
                    top: widget.topOffset,
                    left: 12,
                    right: 12,
                    child: _InstructionBanner(snapshot: snapshot),
                  ),

                // ---- Recenter button ----
                // The +173 offset clears the instruction banner's own
                // height — without the banner there's nothing to clear, so
                // the button would otherwise float with a large, pointless
                // gap above it.
                if (!_followMode)
                  Positioned(
                    right: 16,
                    top: widget.topOffset +
                        (widget.showInstructionBanner ? 173 : 0),
                    child: FloatingActionButton(
                      mini: true,
                      heroTag: 'nav_recenter_${widget.destLabel}',
                      backgroundColor: Colors.white,
                      foregroundColor: ColorResources.appColor,
                      onPressed: () => _recenter(snapshot),
                      child: const Icon(Icons.navigation_rounded),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _InstructionBanner extends StatelessWidget {
  final NavSnapshot snapshot;
  const _InstructionBanner({required this.snapshot});

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return '${hours}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    // Once arrived, the turn-by-turn banner has nothing useful left to
    // say — just get out of the way instead of showing a banner over the
    // map (the screen's own "Arrived"/"End Ride" controls are the actual
    // signal at this point).
    if (snapshot.hasArrived) {
      return const SizedBox.shrink();
    }

    if (snapshot.isRerouting) {
      return _Banner(
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text('Rerouting…', style: PoppinsSemiBold.copyWith(color: Colors.white)),
          ],
        ),
      );
    }

    final step = snapshot.currentStep;
    if (step == null) {
      return _Banner(
        child: Text(
          'Finding route…',
          style: PoppinsSemiBold.copyWith(color: Colors.white),
        ),
      );
    }

    final maneuver = NavManeuverIcon.forManeuver(step.maneuver);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Banner(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(maneuver.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDistance(snapshot.distanceToTurnMeters),
                      style: PoppinsBold.copyWith(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      step.instruction.isNotEmpty ? step.instruction : maneuver.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PoppinsReguler.copyWith(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (snapshot.isOffRoute)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Banner(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatDistance(snapshot.remainingDistanceMeters)} • '
                    '${_formatDuration(snapshot.remainingDurationSeconds)}',
                    style: PoppinsSemiBold.copyWith(
                      fontSize: 13,
                      color: ColorResources.blackcolor11,
                    ),
                  ),
                  Text(
                    '${(snapshot.progress * 100).round()}%',
                    style: PoppinsReguler.copyWith(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: snapshot.progress,
                  minHeight: 5,
                  backgroundColor: Colors.grey.shade200,
                  color: ColorResources.appColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;

  const _Banner({
    required this.child,
    this.color = const Color(0xFF123EBC), // matches ColorResources.appColor
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}
