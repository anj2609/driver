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

  // Timestamp of the last reset() — i.e. when the current online session
  // actually started. Exists solely to give isStale() a grace period: the
  // very first heartbeat needs up to ~5s (the heartbeat interval) plus a
  // network round trip to land, but the staleness watchdog that consults
  // isStale() is a Timer.periodic that keeps running across the whole
  // controller lifetime and doesn't restart or wait when the driver goes
  // online — its very next already-scheduled tick (up to 10s later, per
  // HomeController's watchdog interval) would otherwise see a just-reset
  // tracker (lastSuccessAt == null) and immediately declare staleness
  // before that first heartbeat had any real chance to succeed. Without
  // this, going online could — and did — auto-flip straight back offline
  // within seconds, with the "you've been set offline" toast firing
  // moments after the driver tapped the toggle.
  DateTime? _sessionStartedAt;

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

  /// Resets all tracked state and marks the start of a fresh online
  /// session. Call this whenever the driver deliberately starts a new
  /// "online" session, so a stale reading left over from a previous
  /// session doesn't immediately trip staleness detection again — and so
  /// isStale() grants a full [threshold] worth of grace, timed from this
  /// call, before the *absence* of a first success can be treated as
  /// staleness at all.
  void reset({DateTime? at}) {
    _lastSuccessAt = null;
    _consecutiveFailures = 0;
    _sessionStartedAt = at ?? DateTime.now();
  }

  DateTime? get lastSuccessAt => _lastSuccessAt;
  int get consecutiveFailures => _consecutiveFailures;

  /// Time since the last confirmed-stored update — measured from the last
  /// real success if there's been one, otherwise from when the current
  /// session started (the last reset()) as the best available anchor, or
  /// null if neither has ever happened (the tracker has never been used
  /// at all, e.g. before the driver has ever gone online this app run).
  Duration? timeSinceLastSuccess({DateTime? now}) {
    final anchor = _lastSuccessAt ?? _sessionStartedAt;
    if (anchor == null) return null;
    return (now ?? DateTime.now()).difference(anchor);
  }

  /// True once no update has been confirmed stored for at least
  /// [threshold] — measured from the last success, or from session start
  /// if there hasn't been one yet, so a brand-new session gets a full
  /// [threshold] to land its first heartbeat before being judged. A
  /// tracker that has never recorded a success *and* never been reset
  /// (reset() always runs when going online) is treated as stale, since
  /// there's genuinely no signal to say otherwise.
  bool isStale({required Duration threshold, DateTime? now}) {
    final since = timeSinceLastSuccess(now: now);
    if (since == null) return true;
    return since >= threshold;
  }
}
