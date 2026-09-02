import 'package:flutter/foundation.dart';
// Prefixed: both this and flutter_overlay_window export a
// NotificationVisibility, and this file legitimately needs symbols from each.
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
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
      // Was `if (await FlutterOverlayWindow.isActive()) return;` — a guard
      // against creating a second overlay on top of one already showing.
      // The bubble closes *itself*, though (see NavReturnBubble._returnToApp,
      // which calls FlutterOverlayWindow.closeOverlay() from the overlay's
      // own separate Flutter engine/isolate, not this one) — and after that,
      // isActive() queried from here would sometimes still report true. The
      // driver's first Google Maps trip would then show the bubble fine, but
      // the *next* one — after they'd tapped the bubble to come back once —
      // would hit this now-stale `true` and skip showOverlay() entirely,
      // leaving no bubble at all. Closing first unconditionally (a no-op if
      // nothing is showing — see hideReturnBubble) sidesteps trusting that
      // cross-isolate state and guarantees a fresh overlay every time.
      await FlutterOverlayWindow.closeOverlay();
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

  /// Notification id for the "tap to return" notification. Fixed, so
  /// re-posting it updates the existing one rather than stacking duplicates
  /// every time navigation is launched.
  static const int _returnNotificationId = 90210;

  /// Version-suffixed deliberately, and bumped whenever the channel's
  /// importance changes.
  ///
  /// A notification channel's importance is immutable once Android has
  /// created it: later code changes are ignored for the life of the install,
  /// and only the user can alter it from system settings. v1 was created at
  /// IMPORTANCE_LOW, and a device dump confirmed Android filing it into
  /// `Aggregate_SilentSection` — the collapsed "Silent" tray section, hidden
  /// behind an extra tap on Android 14+ and OEM skins, i.e. invisible in
  /// practice. Re-pitching it on installs that already created v1 is only
  /// possible under a new id, hence this.
  static const String _returnChannelId = 'ride_navigation_return_v3';

  /// A persistent "tap to get back to Nride" notification, posted whenever
  /// the driver is handed off to an external maps app.
  ///
  /// This exists because the floating bubble cannot be relied on. The bubble
  /// needs SYSTEM_ALERT_WINDOW, and on a large slice of real devices that is
  /// not sufficient on its own: Vivo/Funtouch, Xiaomi/MIUI, Oppo and Realme
  /// all gate overlays behind an *additional* vendor-specific permission
  /// ("floating window", "display pop-up while running in background") that
  /// granting the standard Android one does not cover, and several of them
  /// kill the overlay's service under battery optimisation anyway. Drivers on
  /// those phones reported no bubble even after enabling "display over other
  /// apps", which is exactly that.
  ///
  /// A notification has none of those problems — it needs no overlay
  /// permission, no vendor allowance, and survives the app being backgrounded.
  /// So this is the dependable path back, and the bubble is now the nicer
  /// bonus on devices that permit it rather than the only way home.
  ///
  /// High importance, with sound — the driver has to actually notice this
  /// one.
  ///
  /// It was originally silent/low on the reasoning that it must not interrupt
  /// live navigation. That was the wrong trade: LOW pins it to the collapsed
  /// "Silent" tray section for the life of the install, which made it
  /// indistinguishable from not existing at all. A way back into the app that
  /// the driver never finds is worth nothing, so this now announces itself
  /// once, properly — heads-up banner, sound and vibration.
  ///
  /// `onlyAlertOnce` is what keeps that from becoming obnoxious: it alerts on
  /// the first post and then stays quiet for every subsequent update of the
  /// same notification, so a driver mid-navigation isn't re-interrupted.
  static Future<void> showReturnNotification() async {
    try {
      const androidDetails = fln.AndroidNotificationDetails(
        _returnChannelId,
        'Return to ride',
        channelDescription:
            'Lets you tap back into Nride driver while navigating in a maps app.',
        importance: fln.Importance.high,
        priority: fln.Priority.high,
        // Not swipe-dismissible: losing it mid-ride would strand the driver
        // in the maps app with no obvious way back, which is the whole
        // problem this is here to solve.
        ongoing: true,
        autoCancel: false,
        playSound: true,
        enableVibration: true,
        // Alerts once, then silent on re-posts — see the note above.
        onlyAlertOnce: true,
        showWhen: false,
        // Explicitly kept out of any auto-grouped summary, so it can't be
        // folded away into a collapsed bundle with other app notifications.
        ticker: 'Tap to return to Nride driver',
      );

      final plugin = fln.FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin>();

      // Superseded channels, removed so they don't linger. Because
      // importance is immutable, fixing it means publishing a new channel id
      // (see [_returnChannelId]) — and without this, every driver's
      // notification settings would slowly accumulate a stack of identically
      // named "Return to ride" entries, all dead but all still toggleable.
      // Someone disabling the wrong one and concluding the feature is broken
      // is a very easy mistake to leave lying around.
      for (final stale in const [
        'ride_navigation_return',
        'ride_navigation_return_v2',
      ]) {
        await android?.deleteNotificationChannel(channelId: stale);
      }

      // Created explicitly rather than relying on show()'s implicit
      // creation, so the channel definitely exists with these exact
      // settings before anything is posted to it.
      await android?.createNotificationChannel(
        const fln.AndroidNotificationChannel(
          _returnChannelId,
          'Return to ride',
          description:
              'Lets you tap back into Nride driver while navigating in a maps app.',
          // Must match the AndroidNotificationDetails above — the channel is
          // what Android actually enforces; the per-notification values are
          // only honoured within what the channel already permits.
          importance: fln.Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // The single most likely reason this notification "doesn't appear":
      // notifications are switched off for the app entirely (Android 13+
      // POST_NOTIFICATIONS denied, or the driver muted the app in system
      // settings). show() below then does nothing, silently and without
      // throwing, which is impossible to tell apart from a bug in this code
      // unless it's stated outright — hence this log.
      final enabled = await android?.areNotificationsEnabled();
      debugPrint('[NavOverlay] return notification: notificationsEnabled=$enabled');

      await plugin.show(
        id: _returnNotificationId,
        title: 'Ride in progress',
        body: 'Tap to return to Nride driver',
        notificationDetails: const fln.NotificationDetails(
          android: androidDetails,
        ),
      );
      debugPrint('[NavOverlay] return notification posted');
    } catch (e) {
      // Same rule as the bubble: a missing way-back-in is bad, but it must
      // never take the ride itself down with it.
      debugPrint('[NavOverlay] return notification failed: $e');
    }
  }

  /// Clears the notification above. Safe to call when none is showing.
  static Future<void> hideReturnNotification() async {
    try {
      await fln.FlutterLocalNotificationsPlugin().cancel(
        id: _returnNotificationId,
      );
    } catch (e) {
      debugPrint('[NavOverlay] return notification cancel failed: $e');
    }
  }
}
