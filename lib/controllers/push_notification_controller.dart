import 'dart:io';
import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationController extends GetxController {

  String? fcmToken;
  String deviceType = Platform.isAndroid ? "android" : "ios";

  @override
  void onInit() {
    super.onInit();
    initFCM();
  }

  Future<void> initFCM() async {
    await requestPermission();
    await getToken();
    listenTokenRefresh();
    listenForegroundMessages();
  }

 
  Future<void> requestPermission() async {
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("✅ Notification Permission Granted");
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print("⚠ Provisional Permission Granted");
    } else {
      print("❌ Notification Permission Denied");
    }
  }

  /// 📲 Get FCM Token
  Future<void> getToken() async {
    fcmToken = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $fcmToken");

    // 👉 Send to API here if needed
  }

  /// 🔄 Auto Update When Token Changes
  void listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      fcmToken = newToken;
      print("Updated Token: $newToken");

      // 👉 Update token in backend
    });
  }

  /// 📩 Foreground Message Listener
  void listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Title: ${message.notification?.title}");
      print("Body: ${message.notification?.body}");
    });
  }
}