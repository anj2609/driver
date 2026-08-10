import 'package:flutter_test/flutter_test.dart';
import 'package:myridedriverapp/services/driver_visibility.dart';

// Fixed reference points so tests are deterministic:
// Driver sits in central Delhi; "inside radius" rider is ~2km away,
// "outside radius" rider is ~40km away (Gurugram), both well clear of any
// floating-point edge cases at the boundary.
const _driverLat = 28.6139;
const _driverLng = 77.2090;
const _riderNearbyLat = 28.6304; // ~2km from driver
const _riderNearbyLng = 77.2177;
const _riderFarLat = 28.4595; // ~35-40km from driver (Gurugram)
const _riderFarLng = 77.0266;

const _radiusKm = 10.0;
const _staleThreshold = Duration(seconds: 40);

void main() {
  group('evaluateDriverVisibility', () {
    final referenceNow = DateTime(2026, 1, 1, 12, 0, 0);

    test('driver goes offline mid-update: never visible regardless of location freshness/radius', () {
      final decision = evaluateDriverVisibility(
        isOnline: false,
        // Even a perfectly fresh, perfectly in-range location must not
        // matter once the driver is offline — covers the case where a
        // location update was in flight at the exact moment the driver
        // toggled offline.
        lastLocationUpdateAt: referenceNow,
        driverLat: _driverLat,
        driverLng: _driverLng,
        riderLat: _riderNearbyLat,
        riderLng: _riderNearbyLng,
        radiusKm: _radiusKm,
        staleThreshold: _staleThreshold,
        now: referenceNow,
      );

      expect(decision.visible, isFalse);
      expect(decision.reason, contains('offline'));
    });

    test('driver location is stale: not visible even though online and in range', () {
      final staleUpdateTime = referenceNow.subtract(const Duration(minutes: 5));

      final decision = evaluateDriverVisibility(
        isOnline: true,
        lastLocationUpdateAt: staleUpdateTime,
        driverLat: _driverLat,
        driverLng: _driverLng,
        riderLat: _riderNearbyLat,
        riderLng: _riderNearbyLng,
        radiusKm: _radiusKm,
        staleThreshold: _staleThreshold,
        now: referenceNow,
      );

      expect(decision.visible, isFalse);
      expect(decision.reason, contains('stale'));
    });

    test('no location on file yet: not visible', () {
      final decision = evaluateDriverVisibility(
        isOnline: true,
        lastLocationUpdateAt: null,
        driverLat: _driverLat,
        driverLng: _driverLng,
        riderLat: _riderNearbyLat,
        riderLng: _riderNearbyLng,
        radiusKm: _radiusKm,
        staleThreshold: _staleThreshold,
        now: referenceNow,
      );

      expect(decision.visible, isFalse);
      expect(decision.reason, contains('no confirmed location'));
    });

    test('driver location is valid (fresh, online) but outside radius: not visible', () {
      final decision = evaluateDriverVisibility(
        isOnline: true,
        lastLocationUpdateAt: referenceNow.subtract(const Duration(seconds: 5)),
        driverLat: _driverLat,
        driverLng: _driverLng,
        riderLat: _riderFarLat,
        riderLng: _riderFarLng,
        radiusKm: _radiusKm,
        staleThreshold: _staleThreshold,
        now: referenceNow,
      );

      expect(decision.visible, isFalse);
      expect(decision.reason, contains('outside radius'));
    });

    test('driver location is valid (fresh, online) and inside radius: visible', () {
      final decision = evaluateDriverVisibility(
        isOnline: true,
        lastLocationUpdateAt: referenceNow.subtract(const Duration(seconds: 5)),
        driverLat: _driverLat,
        driverLng: _driverLng,
        riderLat: _riderNearbyLat,
        riderLng: _riderNearbyLng,
        radiusKm: _radiusKm,
        staleThreshold: _staleThreshold,
        now: referenceNow,
      );

      expect(decision.visible, isTrue);
      expect(decision.reason, 'visible');
    });

    test('right at the staleness boundary counts as stale (>=, not >)', () {
      final decision = evaluateDriverVisibility(
        isOnline: true,
        lastLocationUpdateAt: referenceNow.subtract(_staleThreshold),
        driverLat: _driverLat,
        driverLng: _driverLng,
        riderLat: _riderNearbyLat,
        riderLng: _riderNearbyLng,
        radiusKm: _radiusKm,
        staleThreshold: _staleThreshold,
        now: referenceNow,
      );

      expect(decision.visible, isFalse);
      expect(decision.reason, contains('stale'));
    });
  });
}
