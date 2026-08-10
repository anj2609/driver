import 'package:flutter_test/flutter_test.dart';
import 'package:myridedriverapp/services/location_health_tracker.dart';

void main() {
  group('LocationHealthTracker', () {
    test('is stale before any update has ever succeeded', () {
      final tracker = LocationHealthTracker();

      expect(tracker.lastSuccessAt, isNull);
      expect(
        tracker.isStale(threshold: const Duration(seconds: 40)),
        isTrue,
        reason: 'no confirmed update yet == nothing fresh on the backend',
      );
    });

    test('is not stale immediately after a successful update', () {
      final tracker = LocationHealthTracker();
      final now = DateTime(2026, 1, 1, 12, 0, 0);

      tracker.recordSuccess(at: now);

      expect(
        tracker.isStale(threshold: const Duration(seconds: 40), now: now),
        isFalse,
      );
      expect(
        tracker.isStale(
          threshold: const Duration(seconds: 40),
          now: now.add(const Duration(seconds: 39)),
        ),
        isFalse,
      );
    });

    test('becomes stale once the threshold has elapsed', () {
      final tracker = LocationHealthTracker();
      final now = DateTime(2026, 1, 1, 12, 0, 0);

      tracker.recordSuccess(at: now);

      expect(
        tracker.isStale(
          threshold: const Duration(seconds: 40),
          now: now.add(const Duration(seconds: 40)),
        ),
        isTrue,
      );
      expect(
        tracker.isStale(
          threshold: const Duration(seconds: 40),
          now: now.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );
    });

    test('failed attempts do not refresh the last-success timestamp', () {
      final tracker = LocationHealthTracker();
      final now = DateTime(2026, 1, 1, 12, 0, 0);

      tracker.recordSuccess(at: now);
      tracker.recordFailure();
      tracker.recordFailure();

      // Still measured from the last real success, not from "now" — a
      // failed attempt must never look like a fresh update.
      expect(tracker.lastSuccessAt, now);
      expect(tracker.consecutiveFailures, 2);
    });

    test('a later success resets the consecutive-failure count', () {
      final tracker = LocationHealthTracker();

      tracker.recordFailure();
      tracker.recordFailure();
      tracker.recordFailure();
      expect(tracker.consecutiveFailures, 3);

      tracker.recordSuccess();
      expect(tracker.consecutiveFailures, 0);
    });

    test(
      'driver goes offline mid-update: reset() clears health so a stale '
      'reading from the previous session cannot immediately re-trigger',
      () {
        final tracker = LocationHealthTracker();
        final longAgo = DateTime(2026, 1, 1, 0, 0, 0);

        // Simulate a session that went stale (e.g. app was backgrounded)
        // right before the driver manually went offline.
        tracker.recordSuccess(at: longAgo);
        tracker.recordFailure();
        tracker.recordFailure();
        expect(
          tracker.isStale(
            threshold: const Duration(seconds: 40),
            now: longAgo.add(const Duration(minutes: 10)),
          ),
          isTrue,
        );

        // Driver goes offline (or the update was mid-flight when they did) —
        // toggleOnline() calls reset() in this exact situation.
        tracker.reset();

        expect(tracker.lastSuccessAt, isNull);
        expect(tracker.consecutiveFailures, 0);
        // Immediately after reset, staleness is "unknown/no data" rather
        // than carrying over the old failure streak.
        expect(
          tracker.isStale(threshold: const Duration(seconds: 40)),
          isTrue,
          reason: 'no data yet is correctly treated as not-fresh, not as '
              '"still failing from before"',
        );
        expect(tracker.consecutiveFailures, 0);
      },
    );
  });
}
