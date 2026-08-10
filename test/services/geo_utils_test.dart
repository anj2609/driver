import 'package:flutter_test/flutter_test.dart';
import 'package:myridedriverapp/services/geo_utils.dart';

void main() {
  group('haversineDistanceKm', () {
    test('same point is zero distance', () {
      expect(haversineDistanceKm(28.6139, 77.2090, 28.6139, 77.2090), 0);
    });

    test('known distance: New Delhi to Agra (~178km straight-line)', () {
      // New Delhi (28.6139, 77.2090) -> Agra (27.1767, 78.0081).
      // Straight-line/great-circle distance, not road distance (~230km).
      final km = haversineDistanceKm(28.6139, 77.2090, 27.1767, 78.0081);
      expect(km, closeTo(178, 5));
    });

    test('known distance: New Delhi to Mumbai (~1150km)', () {
      final km = haversineDistanceKm(28.6139, 77.2090, 19.0760, 72.8777);
      expect(km, closeTo(1150, 30));
    });

    test('a lat/lng swap produces a materially different distance', () {
      // Two points a few km apart in central Delhi.
      const lat1 = 28.6139, lng1 = 77.2090;
      const lat2 = 28.6304, lng2 = 77.2177;

      final correct = haversineDistanceKm(lat1, lng1, lat2, lng2);
      // Simulating the exact bug this check exists to catch: lat/lng
      // accidentally swapped on one side.
      final swapped = haversineDistanceKm(lng1, lat1, lat2, lng2);

      expect(correct, lessThan(10));
      expect(swapped, greaterThan(1000));
      expect(
        (correct - swapped).abs(),
        greaterThan(500),
        reason: 'a coordinate-order bug should be obviously detectable by '
            'comparing against the correct calculation',
      );
    });

    test('is symmetric', () {
      final a = haversineDistanceKm(28.6139, 77.2090, 27.1767, 78.0081);
      final b = haversineDistanceKm(27.1767, 78.0081, 28.6139, 77.2090);
      expect(a, closeTo(b, 0.0001));
    });
  });
}
