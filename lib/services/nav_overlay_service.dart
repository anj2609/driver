import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sends the driver into the real Google Maps app for turn-by-turn
/// navigation once a ride starts, with a small floating bubble (Uber/
/// Rapido-style) left on screen so they can tap back into this app without
/// hunting for it in the app switcher.
///
/// This app's own in-app map already has real routing, camera follow, and
/// arrival detection (see InAppNavigationMap) — this is a deliberate,
/// separate path that hands the actual driving guidance to Google's own
/// traffic-aware navigation instead, which is what was asked for. Kept as a
/// static-method service (no state of its own beyond what the OS/plugin
/// already tracks) since it's a one-shot action triggered from a button, not
/// something a widget needs to hold a live subscription to.
class NavOverlayService {
  NavOverlayService._();

  /// True once the driver has granted "Display over other apps" — checked
  /// before every call that needs it rather than cached, since this can be
  /// revoked from system Settings at any time independent of this app.
  static Future<bool> hasOverlayPermission() {
    return FlutterOverlayWindow.isPermissionGranted();
  }

  /// Sends the driver to the system "Display over other apps" screen for
  /// this app. There is no in-app runtime dialog for this permission —
  /// Android requires it to be granted from Settings — so the caller has to
  /// re-check hasOverlayPermission() after this returns rather than assume
  /// consent, since the driver can back out of that screen without granting
  /// anything.
  static Future<void> requestOverlayPermission() {
    return FlutterOverlayWindow.requestPermission();
  }

  /// Launches real Google Maps turn-by-turn navigation to [lat]/[lng] and
  /// raises the return-to-app bubble over it. Does nothing (returns false)
  /// if the overlay permission isn't granted — the caller is expected to
  /// have already sent the driver through requestOverlayPermission() and
  /// confirmed it stuck before reaching here; silently starting navigation
  /// with no way back into the app would be worse than not starting it.
  static Future<bool> startNavigation({
    required double lat,
    required double lng,
  }) async {
    if (!await hasOverlayPermission()) return false;

    // google.navigation:q=<lat>,<lng>&mode=d opens Maps directly into
    // driving turn-by-turn guidance to this exact point — not just a pin on
    // a map, which is what a plain https://maps.google.com/... link would
    // give instead.
    final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final launched = await launchUrl(
      navUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      debugPrint('[NavOverlay] Could not launch Google Maps for $lat,$lng');
      return false;
    }

    // Small, circular, draggable, and deliberately minimal — its only job is
    // being visible and tappable over whatever app currently has focus.
    await FlutterOverlayWindow.showOverlay(
      height: 130,
      width: 130,
      alignment: OverlayAlignment.centerRight,
      visibility: NotificationVisibility.visibilityPublic,
      flag: OverlayFlag.defaultFlag,
      enableDrag: true,
      positionGravity: PositionGravity.auto,
    );
    return true;
  }

  /// Removes the bubble. Safe to call even if none is currently showing.
  static Future<void> stopNavigation() {
    return FlutterOverlayWindow.closeOverlay();
  }
}
