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

  /// Called on every navigation update — remaining distance, ETA,
  /// progress, current instruction, etc. Optional; screens that want to
  /// show their own "Estimated Arrival Time"/distance fields using this
  /// widget's real, route-aware numbers (rather than a separate estimate
  /// flow) can read them from here.
  final ValueChanged<NavSnapshot>? onUpdate;

  const InAppNavigationMap({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.destLabel,
    this.onArrived,
    this.topOffset = 12,
    this.onUpdate,
  });

  @override
  State<InAppNavigationMap> createState() => _InAppNavigationMapState();
}

class _InAppNavigationMapState extends State<InAppNavigationMap> {
  NavigationEngine? _engine;
  LatLng? _destination;
  GoogleMapController? _mapController;
  bool _followMode = true;
  bool _programmaticCameraMove = false;
  bool _arrivedFired = false;
  bool _routeRequested = false;
  bool _cameraInitialized = false;

  LatLng? get _destLatLng =>
      (widget.destLat != null && widget.destLng != null)
          ? LatLng(widget.destLat!, widget.destLng!)
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

  Future<void> _requestInitialRoute(LatLng origin) async {
    if (_routeRequested || _engine == null) return;
    _routeRequested = true;
    final ok = await _engine!.fetchRoute(origin);
    if (mounted && ok) setState(() {});
  }

  void _animateCamera(NavSnapshot snapshot) {
    final map = _mapController;
    if (map == null || !_followMode) return;
    _programmaticCameraMove = true;
    map.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: snapshot.driverPosition,
          zoom: 17,
          bearing: snapshot.bearing,
          tilt: 45,
        ),
      ),
    );
  }

  void _recenter(NavSnapshot? snapshot) {
    setState(() => _followMode = true);
    if (snapshot != null) _animateCamera(snapshot);
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

        if (engine == null || dest == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (lat == null || lng == null) {
          return GoogleMap(
            initialCameraPosition: CameraPosition(target: dest, zoom: 14),
            myLocationEnabled: true,
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

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!_cameraInitialized && _mapController != null) {
            _cameraInitialized = true;
            _animateCamera(snapshot);
          } else {
            _animateCamera(snapshot);
          }
        });

        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('nav_driver'),
            position: snapshot.driverPosition,
            icon: controller.carIcon ?? BitmapDescriptor.defaultMarker,
            rotation: snapshot.bearing,
            anchor: const Offset(0.5, 0.5),
            flat: true,
          ),
          Marker(
            markerId: const MarkerId('nav_destination'),
            position: dest,
            icon: controller.userIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(title: widget.destLabel),
          ),
        };

        final polylines = <Polyline>{
          if (snapshot.routePoints.isNotEmpty)
            Polyline(
              polylineId: const PolylineId('nav_route'),
              points: snapshot.routePoints,
              width: 6,
              color: snapshot.isOffRoute
                  ? Colors.orange
                  : ColorResources.appColor,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
        };

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: driverPos, zoom: 16),
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
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              markers: markers,
              polylines: polylines,
            ),

            // ---- Turn-by-turn instruction banner ----
            Positioned(
              top: widget.topOffset,
              left: 12,
              right: 12,
              child: _InstructionBanner(snapshot: snapshot),
            ),

            // ---- Recenter button ----
            if (!_followMode)
              Positioned(
                right: 16,
                top: widget.topOffset + 173,
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
