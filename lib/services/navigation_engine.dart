import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:myridedriverapp/config/utils/constants.dart';

/// One maneuver/instruction step of a Directions API route leg — the real
/// per-turn data (as opposed to just an overview polyline) that drives the
/// turn-by-turn instruction banner and arrow.
class NavStep {
  /// Google's maneuver code (e.g. "turn-left", "roundabout-right"), or ''
  /// when Google omits it — that means "continue straight".
  final String maneuver;

  /// Plain-text instruction (Directions API returns this as HTML).
  final String instruction;

  final double distanceMeters;
  final int durationSeconds;
  final LatLng start;
  final LatLng end;

  /// This step's own polyline segment, decoded — concatenating every
  /// step's points (rather than using the route's single lossy
  /// "overview_polyline") is what makes off-route detection and step
  /// advancement accurate.
  final List<LatLng> points;

  NavStep({
    required this.maneuver,
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.start,
    required this.end,
    required this.points,
  });
}

/// Immutable snapshot of navigation state at one point in time — everything
/// a nav UI needs to render a single frame.
@immutable
class NavSnapshot {
  final List<LatLng> routePoints;
  final NavStep? currentStep;
  final NavStep? nextStep;
  final double distanceToTurnMeters;
  final double remainingDistanceMeters;
  final int remainingDurationSeconds;

  /// 0..1 — how far along the total route the driver has progressed.
  final double progress;
  final bool isOffRoute;
  final bool isRerouting;
  final bool hasArrived;
  final LatLng driverPosition;

  /// Degrees, 0-360, direction of travel — used to rotate the driver
  /// marker and (in follow mode) the camera.
  final double bearing;

  const NavSnapshot({
    required this.routePoints,
    required this.currentStep,
    required this.nextStep,
    required this.distanceToTurnMeters,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.progress,
    required this.isOffRoute,
    required this.isRerouting,
    required this.hasArrived,
    required this.driverPosition,
    required this.bearing,
  });

  factory NavSnapshot.empty(LatLng driverPosition, {double bearing = 0}) {
    return NavSnapshot(
      routePoints: const [],
      currentStep: null,
      nextStep: null,
      distanceToTurnMeters: 0,
      remainingDistanceMeters: 0,
      remainingDurationSeconds: 0,
      progress: 0,
      isOffRoute: false,
      isRerouting: false,
      hasArrived: false,
      driverPosition: driverPosition,
      bearing: bearing,
    );
  }
}

/// Turn-by-turn navigation logic: fetches a real route (Directions API,
/// step-level maneuver data — not just a polyline), tracks the driver's
/// live position against it, and derives everything a nav UI needs —
/// current instruction, distance to next turn, remaining distance/ETA,
/// progress, off-route detection with automatic rerouting, and arrival.
///
/// Deliberately has no location-fetching of its own — [onLocationUpdate]
/// is fed positions from whatever GPS stream already exists in the app
/// (HomeController's), so this never becomes a second, competing GPS
/// subscription.
class NavigationEngine {
  final LatLng destination;

  NavigationEngine({required this.destination});

  List<NavStep> _steps = [];
  List<LatLng> _routePoints = [];
  List<int> _stepPointStart = [];
  int _currentStepIndex = 0;
  int _offRouteStrikes = 0;
  bool _isRerouting = false;
  DateTime? _lastRerouteAt;
  bool _hasArrived = false;
  LatLng? _lastPosition;
  double _lastBearing = 0;

  // How far the driver can be from the route before it counts as
  // off-route. Wide enough to tolerate normal GPS drift/multi-lane roads,
  // tight enough to catch a genuine wrong turn.
  static const double offRouteThresholdMeters = 45;

  // How close to the final destination counts as "arrived".
  static const double arrivalThresholdMeters = 30;

  // How close to a step's end point counts as "that maneuver is done,
  // advance to the next one".
  static const double stepAdvanceThresholdMeters = 25;

  // Floor between automatic reroute attempts, so a driver stopped just
  // outside the off-route threshold (traffic, a wide intersection) doesn't
  // spam the Directions API every single location update.
  static const Duration minRerouteInterval = Duration(seconds: 12);

  bool get hasRoute => _routePoints.isNotEmpty;
  bool get hasArrived => _hasArrived;
  bool get isRerouting => _isRerouting;
  List<NavStep> get steps => _steps;

  /// Fetches (or re-fetches, for rerouting) the route from [origin] to
  /// [destination] via the Google Directions API, using real per-step
  /// maneuver data. Returns whether it succeeded.
  Future<bool> fetchRoute(LatLng origin) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&key=${ApiConstants.apiKey}',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('[Nav] Directions HTTP ${response.statusCode}');
        return false;
      }

      final data = json.decode(response.body);
      final status = data['status'];
      final routes = data['routes'] as List?;
      if (status != 'OK' || routes == null || routes.isEmpty) {
        debugPrint(
          '[Nav] Directions returned no route — status=$status '
          'error_message=${data['error_message']}',
        );
        return false;
      }

      final legs = routes[0]['legs'] as List;
      final steps = <NavStep>[];
      for (final leg in legs) {
        for (final s in (leg['steps'] as List)) {
          final polyline = s['polyline']?['points']?.toString() ?? '';
          steps.add(
            NavStep(
              maneuver: (s['maneuver'] ?? '').toString(),
              instruction: _stripHtml(s['html_instructions']?.toString() ?? ''),
              distanceMeters: (s['distance']?['value'] as num?)?.toDouble() ?? 0,
              durationSeconds: (s['duration']?['value'] as num?)?.toInt() ?? 0,
              start: LatLng(
                (s['start_location']['lat'] as num).toDouble(),
                (s['start_location']['lng'] as num).toDouble(),
              ),
              end: LatLng(
                (s['end_location']['lat'] as num).toDouble(),
                (s['end_location']['lng'] as num).toDouble(),
              ),
              points: _decodePolyline(polyline),
            ),
          );
        }
      }
      if (steps.isEmpty) return false;

      final routePoints = <LatLng>[];
      final stepStarts = <int>[];
      for (final step in steps) {
        stepStarts.add(routePoints.length);
        if (routePoints.isNotEmpty &&
            step.points.isNotEmpty &&
            _sameLatLng(routePoints.last, step.points.first)) {
          routePoints.addAll(step.points.skip(1));
        } else {
          routePoints.addAll(step.points);
        }
      }

      _steps = steps;
      _routePoints = routePoints;
      _stepPointStart = stepStarts;
      _currentStepIndex = 0;
      _offRouteStrikes = 0;
      _hasArrived = false;
      return true;
    } catch (e) {
      debugPrint('[Nav] fetchRoute error: $e');
      return false;
    }
  }

  /// Feeds a new driver position into the engine and returns the derived
  /// nav state for this instant. Cheap enough to call on every GPS fix —
  /// route point counts for a single ride are small (typically well under
  /// a thousand points).
  NavSnapshot onLocationUpdate(LatLng position, {double? deviceHeading}) {
    if (_lastPosition != null) {
      final movedMeters = _distanceMeters(_lastPosition!, position);
      // Recompute bearing only once the driver has genuinely moved a few
      // meters — over very short gaps GPS noise makes the bearing
      // between two points nearly meaningless and it visibly jitters.
      if (movedMeters > 3) {
        _lastBearing = _bearing(_lastPosition!, position);
      }
    }
    _lastPosition = position;
    final bearing = (deviceHeading != null && deviceHeading > 0)
        ? deviceHeading
        : _lastBearing;

    if (!hasRoute) {
      return NavSnapshot.empty(position, bearing: bearing);
    }

    final nearest = _nearestPointOnRoute(position);

    if (nearest.distanceMeters > offRouteThresholdMeters) {
      _offRouteStrikes++;
    } else {
      _offRouteStrikes = 0;
    }
    // Require a couple of consecutive strikes before declaring off-route —
    // a single noisy fix shouldn't trigger a reroute.
    final isOffRoute = _offRouteStrikes >= 2;

    if (isOffRoute &&
        !_isRerouting &&
        (_lastRerouteAt == null ||
            DateTime.now().difference(_lastRerouteAt!) > minRerouteInterval)) {
      _isRerouting = true;
      _lastRerouteAt = DateTime.now();
      // Fire-and-forget: the next few onLocationUpdate() calls will just
      // keep reporting isOffRoute/isRerouting until this resolves and
      // swaps in the new route.
      fetchRoute(position).then((_) {
        _isRerouting = false;
      });
    }

    // Advance the current step from the nearest-route-point index. Only
    // ever moves forward — GPS noise briefly placing the nearest point a
    // touch earlier on the route shouldn't make the instruction flicker
    // back to a maneuver already completed.
    int stepForIndex = 0;
    for (int i = 0; i < _stepPointStart.length; i++) {
      if (nearest.pointIndex >= _stepPointStart[i]) stepForIndex = i;
    }
    if (stepForIndex > _currentStepIndex) {
      _currentStepIndex = stepForIndex;
    }

    // Belt-and-suspenders: also advance once genuinely close to the
    // current step's endpoint, since a short final step can sit between
    // two GPS fixes and never become the "nearest" one.
    final stepBeforeEndCheck = _steps[_currentStepIndex];
    final distToStepEnd = _distanceMeters(position, stepBeforeEndCheck.end);
    if (distToStepEnd < stepAdvanceThresholdMeters &&
        _currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
    }

    final activeStep = _steps[_currentStepIndex];
    final nextStep =
        _currentStepIndex + 1 < _steps.length ? _steps[_currentStepIndex + 1] : null;
    final distanceToTurn = _distanceMeters(position, activeStep.end);

    double remainingDistance = distanceToTurn;
    int remainingDuration = activeStep.distanceMeters > 0
        ? (activeStep.durationSeconds * (distanceToTurn / activeStep.distanceMeters))
            .round()
        : 0;
    for (int i = _currentStepIndex + 1; i < _steps.length; i++) {
      remainingDistance += _steps[i].distanceMeters;
      remainingDuration += _steps[i].durationSeconds;
    }

    final totalDistance = _steps.fold<double>(0, (a, s) => a + s.distanceMeters);
    final progress = totalDistance > 0
        ? ((totalDistance - remainingDistance) / totalDistance).clamp(0.0, 1.0)
        : 0.0;

    if (_distanceMeters(position, destination) < arrivalThresholdMeters) {
      _hasArrived = true;
    }

    return NavSnapshot(
      routePoints: _routePoints,
      currentStep: activeStep,
      nextStep: nextStep,
      distanceToTurnMeters: distanceToTurn,
      remainingDistanceMeters: remainingDistance,
      remainingDurationSeconds: remainingDuration,
      progress: progress,
      isOffRoute: isOffRoute,
      isRerouting: _isRerouting,
      hasArrived: _hasArrived,
      driverPosition: position,
      bearing: bearing,
    );
  }

  // ==================== geometry helpers ====================

  static bool _sameLatLng(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 1e-6 &&
        (a.longitude - b.longitude).abs() < 1e-6;
  }

  static double _toRad(double deg) => deg * pi / 180.0;

  static double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0; // meters
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(a.latitude)) *
            cos(_toRad(b.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return 2 * R * atan2(sqrt(h), sqrt(1 - h));
  }

  static double _bearing(LatLng a, LatLng b) {
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    final deg = atan2(y, x) * 180 / pi;
    return (deg + 360) % 360;
  }

  /// Nearest point on the whole route polyline to [position] — checked
  /// segment-by-segment (using a local flat-earth projection, accurate
  /// enough at city/route scale) so the result is a true perpendicular
  /// distance to the road, not just "nearest vertex".
  _NearestPointResult _nearestPointOnRoute(LatLng position) {
    double bestDist = double.infinity;
    int bestIndex = 0;

    // Local tangent-plane approximation: treat small lat/lng deltas near
    // the route as flat x/y in meters. Good enough at the scale of a
    // single ride's route.
    final lat0 = _toRad(position.latitude);
    const R = 6371000.0;
    double toX(LatLng p) => _toRad(p.longitude - position.longitude) * cos(lat0) * R;
    double toY(LatLng p) => _toRad(p.latitude - position.latitude) * R;

    final px = 0.0, py = 0.0;

    for (int i = 0; i < _routePoints.length - 1; i++) {
      final ax = toX(_routePoints[i]);
      final ay = toY(_routePoints[i]);
      final bx = toX(_routePoints[i + 1]);
      final by = toY(_routePoints[i + 1]);

      final dx = bx - ax;
      final dy = by - ay;
      final lenSq = dx * dx + dy * dy;

      double t = lenSq > 0 ? (((px - ax) * dx) + ((py - ay) * dy)) / lenSq : 0;
      t = t.clamp(0.0, 1.0);

      final projX = ax + t * dx;
      final projY = ay + t * dy;
      final dist = sqrt((px - projX) * (px - projX) + (py - projY) * (py - projY));

      if (dist < bestDist) {
        bestDist = dist;
        // Attribute the segment to whichever endpoint the projection is
        // closer to, so step-advancement sees a point index that actually
        // reflects progress along the segment.
        bestIndex = t >= 0.5 ? i + 1 : i;
      }
    }

    return _NearestPointResult(distanceMeters: bestDist, pointIndex: bestIndex);
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}

class _NearestPointResult {
  final double distanceMeters;
  final int pointIndex;
  _NearestPointResult({required this.distanceMeters, required this.pointIndex});
}

/// Maps a Google Directions `maneuver` code to a Material icon and a short
/// human label, for the instruction banner/arrow.
class NavManeuverIcon {
  final IconData icon;
  final String label;
  const NavManeuverIcon(this.icon, this.label);

  static NavManeuverIcon forManeuver(String maneuver) {
    switch (maneuver) {
      case 'turn-left':
        return const NavManeuverIcon(Icons.turn_left, 'Turn left');
      case 'turn-right':
        return const NavManeuverIcon(Icons.turn_right, 'Turn right');
      case 'turn-slight-left':
      case 'keep-left':
        return const NavManeuverIcon(Icons.turn_slight_left, 'Bear left');
      case 'turn-slight-right':
      case 'keep-right':
        return const NavManeuverIcon(Icons.turn_slight_right, 'Bear right');
      case 'turn-sharp-left':
        return const NavManeuverIcon(Icons.turn_sharp_left, 'Sharp left');
      case 'turn-sharp-right':
        return const NavManeuverIcon(Icons.turn_sharp_right, 'Sharp right');
      case 'uturn-left':
        return const NavManeuverIcon(Icons.u_turn_left, 'U-turn');
      case 'uturn-right':
        return const NavManeuverIcon(Icons.u_turn_right, 'U-turn');
      case 'roundabout-left':
        return const NavManeuverIcon(Icons.roundabout_left, 'Roundabout');
      case 'roundabout-right':
        return const NavManeuverIcon(Icons.roundabout_right, 'Roundabout');
      case 'fork-left':
      case 'ramp-left':
        return const NavManeuverIcon(Icons.fork_left, 'Take left fork');
      case 'fork-right':
      case 'ramp-right':
        return const NavManeuverIcon(Icons.fork_right, 'Take right fork');
      case 'merge':
        return const NavManeuverIcon(Icons.merge, 'Merge');
      case 'straight':
      default:
        return const NavManeuverIcon(Icons.straight, 'Continue straight');
    }
  }
}
