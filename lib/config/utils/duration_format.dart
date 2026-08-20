/// Formats a duration given in minutes into a short, human-readable label —
/// "45 min" under an hour, "2h 30m" at or above one. Without this, a long
/// trip (an outstation booking, or any duration over ~60 minutes) rendered
/// as a bare, hard-to-parse number like "2000 min" wherever a raw minute
/// count was shown directly.
///
/// [raw] may be a bare numeric string ("125") or a backend-formatted one
/// with a trailing unit word ("2804 mins", as estimate-ride-list sends it) —
/// the suffix is stripped before parsing, so either shape works without the
/// caller pre-processing it. Returns null when there's no usable number,
/// leaving the caller's own fallback (an em dash, a raw passthrough) in
/// control of what "no data" looks like on that particular screen.
String? formatMinutesLabel(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final numericPart =
      trimmed.replaceAll(RegExp(r'\s*mins?\.?\s*$', caseSensitive: false), '').trim();
  final minutes = double.tryParse(numericPart)?.round();
  if (minutes == null) return null;

  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rem = minutes % 60;
  return '${hours}h ${rem}m';
}

/// Same formatting, for a duration already in seconds (the live in-app
/// navigation ETA).
String formatSecondsLabel(int seconds) {
  final minutes = (seconds / 60).ceil();
  return formatMinutesLabel(minutes.toString()) ?? '$minutes min';
}
