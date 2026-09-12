import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Prints everything about an incoming push, from every entry point it can
/// arrive through, so the exact `type` value and payload shape the backend
/// sends can be read straight off the console.
///
/// [source] says WHICH handler caught it. That matters as much as the payload:
/// the same push reaches different code depending on whether the app was in
/// front, in the background, or killed, and "the overlay didn't show" usually
/// means it arrived somewhere other than where you assumed.
///
/// The notification-block line is the one to watch for the ride-request push.
/// The incoming-ride overlay only works from a data-only message: if Android
/// sees a `notification` block it draws its own plain notification and no app
/// code runs at all, so a PRESENT here explains a missing card on its own.
void logFcmMessage(String source, RemoteMessage message) {
  final RemoteNotification? notification = message.notification;
  final Map<String, dynamic> data = message.data;

  debugPrint('╔══════ [FCM] $source ══════');
  debugPrint('║ messageId   : ${message.messageId}');
  debugPrint('║ from        : ${message.from}');
  debugPrint('║ sentTime    : ${message.sentTime}');
  debugPrint('║ collapseKey : ${message.collapseKey}');
  debugPrint(
    '║ notification: ${notification == null ? 'NONE  <-- data-only, correct for the overlay' : 'PRESENT  <-- WRONG for ride requests on Android: '
              'title="${notification.title}" body="${notification.body}"'}',
  );

  if (data.isEmpty) {
    debugPrint('║ data        : (empty)');
  } else {
    debugPrint('║ data.type   : ${data['type'] ?? '(no "type" key!)'}');
    debugPrint('║ data        : ${data.length} keys');
    data.forEach((String key, dynamic value) {
      debugPrint('║    $key = $value');
    });
  }
  debugPrint('╚═══════════════════════════');
}
