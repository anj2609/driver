/// Tracks the health of the driver's location-update pipeline: when the
/// last successful transmission to the backend was confirmed, how many
/// consecutive attempts have failed since, and whether the location the
/// backend has on file should now be considered stale.
///
/// This exists because the driver app has no way to know whether the
/// *backend's* copy of its location is fresh — GPS can keep reporting a
/// perfectly good fix locally while every attempt to actually send it
/// fails silently (expired token, dropped connection, OS suspending the
/// app in the background, etc.). Tracking transmission health — not GPS
/// acquisition — is what lets the app detect "riders can no longer find
/// me" and react, instead of silently looking online while invisible.
///
/// Deliberately has zero Flutter/platform dependencies (no Geolocator, no
/// GetX, no http) so it's trivially unit-testable in isolation.
class LocationHealthTracker {
  DateTime? _lastSuccessAt;
  int _consecutiveFailures = 0;

  /// Call whenever a location update is confirmed stored by the backend
  /// (i.e. the API call succeeded), not merely whenever GPS produces a fix.
  void recordSuccess({DateTime? at}) {
    _lastSuccessAt = at ?? DateTime.now();
    _consecutiveFailures = 0;
  }

  /// Call whenever a location update attempt fails (network error, non-200
  /// response, timeout, exception, etc.). Deliberately does not touch
  /// [lastSuccessAt] — a failed attempt doesn't change when the backend's
  /// last-known-good location actually was.
  void recordFailure() {
    _consecutiveFailures++;
  }

  /// Resets all tracked state. Call this whenever the driver deliberately
  /// starts a new "online" session, so a stale reading left over from a
  /// previous session doesn't immediately trip staleness detection again
  /// before the first update of the new session has even had a chance to
  /// land.
  void reset() {
    _lastSuccessAt = null;
    _consecutiveFailures = 0;
  }

  DateTime? get lastSuccessAt => _lastSuccessAt;
  int get consecutiveFailures => _consecutiveFailures;

  /// Time since the last confirmed-stored update, or null if none has ever
  /// succeeded (e.g. right after going online, before the first heartbeat
  /// lands).
  Duration? timeSinceLastSuccess({DateTime? now}) {
    if (_lastSuccessAt == null) return null;
    return (now ?? DateTime.now()).difference(_lastSuccessAt!);
  }

  /// True once no update has been confirmed stored for at least
  /// [threshold] — including the case where no update has *ever* succeeded,
  /// since the backend has nothing fresh on file either way.
  bool isStale({required Duration threshold, DateTime? now}) {
    final since = timeSinceLastSuccess(now: now);
    if (since == null) return true;
    return since >= threshold;
  }
}
