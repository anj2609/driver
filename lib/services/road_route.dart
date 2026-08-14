import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:myridedriverapp/config/utils/constants.dart';

/// A driving route between two points, as actually reported by Google
/// Directions — the road-network path and its true distance/duration, not a
/// straight line between the endpoints.
///
/// Several places in this app used to draw (or measure) a route as a plain
/// two-point line, or compute distance via Haversine — both understate real
/// driving distance on anything but a direct road, and a straight polyline on
/// a map can visibly cut across blocks, water, or terrain that isn't there.
/// This is the one place that calls the Directions API, so every caller gets
/// the same figure and the same drawn path.
class RoadRoute {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;

  RoadRoute({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class RoadRouteService {
  static Future<RoadRoute?> fetch({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$originLat,$originLng&destination=$destLat,$destLng'
        '&mode=driving&key=${ApiConstants.apiKey}',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('[RoadRoute] HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = json.decode(response.body);

      // Directions returns HTTP 200 even when it can't produce a route — the
      // real outcome is in `status` (ZERO_RESULTS, REQUEST_DENIED,
      // OVER_QUERY_LIMIT, ...), with detail in `error_message`.
      final status = data['status'];
      final routes = data['routes'] as List?;
      if (status != 'OK' || routes == null || routes.isEmpty) {
        debugPrint(
          '[RoadRoute] no route — status=$status '
          'error_message=${data['error_message']}',
        );
        return null;
      }

      final leg = routes[0]['legs'][0];
      final double distanceKm =
          ((leg['distance']?['value'] as num?)?.toDouble() ?? 0) / 1000.0;
      final int durationMin =
          (((leg['duration']?['value'] as num?)?.toDouble() ?? 0) / 60).round();

      final String? overview = routes[0]['overview_polyline']?['points'];
      final List<LatLng> points =
          overview != null ? _decodePolyline(overview) : const [];

      return RoadRoute(
        points: points,
        distanceKm: distanceKm,
        durationMinutes: durationMin,
      );
    } catch (e) {
      debugPrint('[RoadRoute] fetch error: $e');
      return null;
    }
  }

  /// Standard Google polyline algorithm decoder.
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
      final int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
