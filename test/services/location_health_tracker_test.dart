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
        final resetAt = longAgo.add(const Duration(minutes: 10));
        tracker.reset(at: resetAt);

        expect(tracker.lastSuccessAt, isNull);
        expect(tracker.consecutiveFailures, 0);
        // Immediately after reset, staleness is "unknown/no data yet" —
        // not carrying over the old failure streak, and not instantly
        // stale either (see the grace-period test below for why).
        expect(
          tracker.isStale(threshold: const Duration(seconds: 40), now: resetAt),
          isFalse,
          reason: 'a fresh session gets a grace period before "no success '
              'yet" is treated as staleness',
        );
        expect(tracker.consecutiveFailures, 0);
      },
    );

    test(
      'reset() grants a full grace period before "no success yet" counts '
      'as stale — going online must not immediately flip back offline',
      () {
        final tracker = LocationHealthTracker();
        final wentOnlineAt = DateTime(2026, 1, 1, 12, 0, 0);

        tracker.reset(at: wentOnlineAt);

        // The staleness watchdog is a Timer.periodic that keeps running
        // independent of when the driver actually went online — its very
        // next tick (up to ~10s later in HomeController) must not see this
        // as stale just because the first heartbeat (needs up to ~5s plus
        // a network round trip) hasn't landed yet.
        expect(
          tracker.isStale(
            threshold: const Duration(seconds: 40),
            now: wentOnlineAt.add(const Duration(seconds: 10)),
          ),
          isFalse,
        );
        expect(
          tracker.isStale(
            threshold: const Duration(seconds: 40),
            now: wentOnlineAt.add(const Duration(seconds: 39)),
          ),
          isFalse,
        );

        // But if the threshold fully elapses with genuinely no success at
        // all, it must still catch a driver whose location truly never
        // reached the backend the entire session.
        expect(
          tracker.isStale(
            threshold: const Duration(seconds: 40),
            now: wentOnlineAt.add(const Duration(seconds: 40)),
          ),
          isTrue,
        );

        // A success landing inside the grace period clears staleness as
        // normal, measured from the real success from then on.
        final successAt = wentOnlineAt.add(const Duration(seconds: 8));
        tracker.recordSuccess(at: successAt);
        expect(
          tracker.isStale(
            threshold: const Duration(seconds: 40),
            now: successAt.add(const Duration(seconds: 39)),
          ),
          isFalse,
        );
        expect(
          tracker.isStale(
            threshold: const Duration(seconds: 40),
            now: successAt.add(const Duration(seconds: 40)),
          ),
          isTrue,
        );
      },
    );
  });
}
