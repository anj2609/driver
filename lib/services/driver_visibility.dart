import 'geo_utils.dart';

/// The outcome of a visibility check, plus a human-readable reason —
/// deliberately explicit ("why") rather than a bare bool, since a silent
/// false is exactly the kind of thing that made the original bug hard to
/// diagnose.
class DriverVisibilityDecision {
  final bool visible;
  final String reason;
  const DriverVisibilityDecision(this.visible, this.reason);

  @override
  String toString() => 'DriverVisibilityDecision(visible: $visible, reason: "$reason")';
}

/// Reference implementation of the visibility decision a rider-facing
/// "nearby drivers" query should make for a single driver.
///
/// IMPORTANT: this is NOT the actual backend matching query — that logic
/// lives in the backend service, which this repo has no access to. This
/// exists so the contract described in the location-pipeline diagnosis
/// (stale locations excluded from matching; correct radius) has one
/// concrete, testable definition:
///   1. offline drivers are never visible
///   2. drivers with no location on file yet are never visible
///   3. drivers whose last confirmed location update is older than
///      [staleThreshold] are excluded, regardless of where that stale
///      point was
///   4. drivers outside [radiusKm] of the rider are excluded
///   5. otherwise, visible
///
/// Two uses: (a) documents, in code, exactly what the backend query is
/// expected to do, so it can be verified/mirrored there; (b) gives this
/// repo automated coverage for the rules its own UI (the driver's online
/// status, the staleness watchdog) is built around.
DriverVisibilityDecision evaluateDriverVisibility({
  required bool isOnline,
  required DateTime? lastLocationUpdateAt,
  required double driverLat,
  required double driverLng,
  required double riderLat,
  required double riderLng,
  required double radiusKm,
  Duration staleThreshold = const Duration(seconds: 40),
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();

  if (!isOnline) {
    return const DriverVisibilityDecision(false, 'driver is offline');
  }

  if (lastLocationUpdateAt == null) {
    return const DriverVisibilityDecision(
      false,
      'no confirmed location update on file yet',
    );
  }

  final age = currentTime.difference(lastLocationUpdateAt);
  if (age >= staleThreshold) {
    return DriverVisibilityDecision(
      false,
      'location stale (last update ${age.inSeconds}s ago, '
      'threshold ${staleThreshold.inSeconds}s)',
    );
  }

  final distanceKm = haversineDistanceKm(driverLat, driverLng, riderLat, riderLng);
  if (distanceKm > radiusKm) {
    return DriverVisibilityDecision(
      false,
      'outside radius (${distanceKm.toStringAsFixed(2)}km away, '
      'radius ${radiusKm}km)',
    );
  }

  return const DriverVisibilityDecision(true, 'visible');
}
