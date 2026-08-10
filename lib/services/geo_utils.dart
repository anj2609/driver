import 'dart:math' as math;

/// Great-circle distance between two lat/lng points, in kilometers
/// (haversine formula).
///
/// Pure Dart (no Flutter/geolocator dependency) so it's trivially unit
/// testable. Used as a client-side sanity check on "nearby" results
/// returned by the backend — e.g. flagging a lat/lng swap or a
/// degrees/radians unit mismatch on the server, which would otherwise be
/// invisible from the client (a wrong-but-200-OK response looks identical
/// to a correct one until someone actually checks the distance).
double haversineDistanceKm(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);

  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * (math.pi / 180.0);
