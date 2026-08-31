/// Maps a vehicle type's name (as sent by the vehicle-type list / a
/// vehicle's own record) to the local map-marker asset for that category.
/// Matched by keyword rather than an exact string — the precise labels the
/// backend uses for each category aren't guaranteed (e.g. "E-Auto" vs
/// "Electric Auto" vs "Electric Rickshaw"), so this tolerates any of them
/// the same way the rest of this app's defensive JSON parsing does. Falls
/// back to the car marker — the icon every screen showed unconditionally
/// before this existed — when the name is missing or doesn't match a known
/// category, rather than showing nothing.
String vehicleMarkerAssetForName(String? name) {
  final n = (name ?? '').toLowerCase();

  if (n.contains('electric') || n.contains('e-auto') || n.contains('eauto')) {
    return 'assets/images/electric_auto_marker.png';
  }
  if (n.contains('auto') || n.contains('rickshaw') || n.contains('tuk')) {
    return 'assets/images/auto_marker.png';
  }
  if (n.contains('bike') ||
      n.contains('motor') ||
      n.contains('scooter') ||
      n.contains('two wheel')) {
    return 'assets/images/bike_marker.png';
  }
  return 'assets/images/car_nride_marker.png';
}

/// Marker resize width (passed to resizeMarker's targetWidth) for a given
/// vehicle type. car_nride_marker.png and bike_marker.png are both
/// portrait (the vehicle's length runs top-to-bottom), so scaling either
/// to the same width keeps a similar on-map footprint. auto_marker.png and
/// electric_auto_marker.png are landscape (the vehicle's length runs
/// side-to-side) — at that same width their short edge is what shows, so
/// they read as noticeably smaller than the car/bike icons even though all
/// four are cropped equally tight to their own vehicle. Sized up here so
/// their long edge lands close to the car's, instead of their short edge.
int vehicleMarkerWidthForName(String? name) {
  final n = (name ?? '').toLowerCase();

  if (n.contains('electric') || n.contains('e-auto') || n.contains('eauto')) {
    return 34;
  }
  if (n.contains('auto') || n.contains('rickshaw') || n.contains('tuk')) {
    return 34;
  }
  return 20;
}
