import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sends the driver into the real Google Maps app for turn-by-turn
/// navigation once a ride starts, and — as a bonus, only when the OS
/// permission for it already happens to be granted — leaves a small floating
/// bubble (Uber/Rapido-style) on screen so they can tap back into this app.
///
/// The two halves are deliberately independent. An earlier version treated
/// them as one step: it checked the overlay permission first, sent the driver
/// to the system Settings screen to grant it, and returned early if they
/// hadn't. That meant the actual navigation — the thing the driver pressed
/// Start Ride for — never launched at all on any device where that
/// permission wasn't already on, and the driver instead got an unexplained
/// permission screen at the worst possible moment. Navigation is the feature;
/// the bubble is a convenience, and a convenience must never be able to block
/// the feature.
class NavOverlayService {
  NavOverlayService._();

  /// True once the driver has granted "Display over other apps" — checked
  /// before every call that needs it rather than cached, since this can be
  /// revoked from system Settings at any time independent of this app.
  static Future<bool> hasOverlayPermission() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      debugPrint('[NavOverlay] permission check failed: $e');
      return false;
    }
  }

  /// Sends the driver to the system "Display over other apps" screen for
  /// this app. There is no in-app runtime dialog for this permission —
  /// Android requires it to be granted from Settings — so any caller has to
  /// re-check [hasOverlayPermission] afterwards rather than assume consent.
  ///
  /// Deliberately NOT called from the ride-start path; see the class doc.
  static Future<void> requestOverlayPermission() async {
    try {
      await FlutterOverlayWindow.requestPermission();
    } catch (e) {
      debugPrint('[NavOverlay] permission request failed: $e');
    }
  }

  /// Opens real Google Maps turn-by-turn navigation to [lat]/[lng].
  /// Returns false only if nothing at all could be opened.
  static Future<bool> launchGoogleMapsNavigation({
    required double lat,
    required double lng,
  }) async {
    // google.navigation:q=<lat>,<lng>&mode=d drops straight into driving
    // turn-by-turn guidance rather than just showing a pin, which is what a
    // plain maps.google.com link would do.
    final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    // Wrapped in try/catch, not just checked for a false return:
    // launchUrl throws a PlatformException when no activity can handle the
    // URI (Google Maps not installed, or the intent not resolvable), it
    // does not simply return false. Uncaught, that propagated out of the
    // Start Ride handler as an unhandled async error.
    try {
      if (await launchUrl(navUri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (e) {
      debugPrint('[NavOverlay] google.navigation launch failed: $e');
    }

    // Fallback for a device with no Google Maps app: the universal Maps
    // directions URL, which any browser can open. Still lands the driver on
    // a route to the right place rather than nowhere at all.
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[NavOverlay] maps web fallback failed: $e');
      return false;
    }
  }

  /// Raises the floating return-to-app bubble, but only if the driver has
  /// already granted the overlay permission. Silent no-op otherwise — it is
  /// never worth interrupting an active ride to ask for this.
  static Future<void> showReturnBubbleIfPermitted() async {
    if (!await hasOverlayPermission()) return;
    try {
      if (await FlutterOverlayWindow.isActive()) return;
      await FlutterOverlayWindow.showOverlay(
        height: 150,
        width: 150,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilityPublic,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Ride in progress',
        overlayContent: 'Tap the bubble to return to Nride driver',
      );
    } catch (e) {
      // A bubble that fails to appear must not take the ride down with it.
      debugPrint('[NavOverlay] showOverlay failed: $e');
    }
  }

  /// Removes the bubble. Safe to call even if none is currently showing.
  static Future<void> hideReturnBubble() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('[NavOverlay] closeOverlay failed: $e');
    }
  }
}
