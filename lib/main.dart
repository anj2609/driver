
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/helper/get_di.dart' as di;
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/app_constants.dart';
import 'package:myridedriverapp/widgets/nav_return_bubble.dart';

/// Entry point for the floating "return to app" bubble shown over Google
/// Maps once a ride starts (see NavOverlayService.startNavigation()).
/// `flutter_overlay_window` runs this in its own separate Flutter engine —
/// a completely different isolate/widget tree than the one `main()` starts
/// — which is why it can't be a normal widget reached through GetMaterialApp
/// below; the plugin looks this exact top-level function up by name via the
/// `vm:entry-point` pragma; renaming it without updating the native side
/// (see OverlayService in AndroidManifest.xml) would silently break it.
@pragma("vm:entry-point")
void overlayMain() {
  runApp(const NavReturnBubble());
}

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
// Public (not the original leading-underscore `_initializeCore`) so
// splash_screen.dart can call it again to retry Firebase/DI setup if the
// first attempt fails — see the try/catch around `await appInitialization`
// there. A failed Firebase.initializeApp() (e.g. a device with broken/
// outdated Google Play Services) used to leave di.init() never having run
// at all, so every screen's first Get.find() call — none of which are
// guarded — threw immediately: an uncaught exception during app startup,
// which is exactly what an Android "keeps stopping" crash looks like.
Future<void> initializeAppCore() async {
  await Firebase.initializeApp();
  await di.init();
}

void main() {
  // Was just `runApp(MyApp())` — this app had zero global error handling
  // anywhere (no runZonedGuarded, no FlutterError.onError, no Crashlytics),
  // so an uncaught exception on a specific device (e.g. the reported
  // Galaxy M11 "Nride driver keeps stopping" crash) left nothing to look
  // at beyond a bare "keeps stopping" system dialog — no way to tell which
  // of several plausible causes it actually was. This doesn't stop a fatal
  // error from taking the app down, but it does mean any error routed
  // through the zone (framework errors always are; platform/isolate-level
  // native crashes are not) gets logged before that happens, instead of
  // vanishing. `flutter logs` / `adb logcat` on a reproducing device is
  // now the fastest way to actually see what's failing, instead of
  // guessing blind.
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('[FATAL] FlutterError: ${details.exceptionAsString()}');
        debugPrint('${details.stack}');
        originalOnError?.call(details);
      };

      // Kicked off without awaiting so Flutter can paint its first frame
      // (and dismiss Android's mandatory native splash) immediately,
      // instead of sitting on the OS splash for as long as Firebase/DI
      // setup takes.
      appInitialization = initializeAppCore();

      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );

      runApp(MyApp());
      //configLoading();
    },
    (error, stack) {
      debugPrint('[FATAL] Uncaught zone error: $error');
      debugPrint('$stack');
    },
  );
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = Colors.yellow
    ..backgroundColor = ColorResources.appColor
    ..indicatorColor = Colors.white
    ..textColor = Colors.white
    ..maskColor = ColorResources.appColor
    ..userInteractions = true
    ..dismissOnTap = false;
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();

    // Firebase isn't ready until appInitialization resolves, so FCM setup
    // has to wait for it rather than assuming it already completed. Was
    // missing a catchError — if appInitialization rejects (e.g. Firebase
    // init failing on a device with broken Google Play Services), this
    // .then() callback simply never runs, silently, rather than crashing
    // here; splash_screen.dart's own try/catch around the same Future is
    // what actually surfaces and retries the failure to the user.
    appInitialization
        ?.then((_) => _setupMessaging())
        .catchError((e) => debugPrint('[FCM] appInitialization failed: $e'));
  }

  void _setupMessaging() {
    // App killed → user taps notification → app launches
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleFcmMessage(message);
    });

    // App in background → user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmMessage);

    // App in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      _showNotification(message);
      _handleFcmMessage(message);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    });

    FirebaseMessaging.instance.requestPermission();
    _initializeFlutterLocalNotifications();
  }

  /// Returns true when [message] indicates the driver's docs have been approved.
  bool _isApprovalMessage(RemoteMessage message) {
    final data = message.data;
    // Check explicit data-payload fields (most reliable).
    if (data['verification_status'] == 'approved' ||
        data['doc_status'] == 'approved' ||
        data['type'] == 'document_approved' ||
        data['type'] == 'doc_approved' ||
        data['type'] == 'approved') {
      return true;
    }
    // Fallback: check notification title / body text.
    final title = message.notification?.title?.toLowerCase() ?? '';
    final body = message.notification?.body?.toLowerCase() ?? '';
    if ((title.contains('approved') || body.contains('approved')) &&
        (title.contains('document') ||
            body.contains('document') ||
            title.contains('profile') ||
            body.contains('profile') ||
            title.contains('account') ||
            body.contains('account'))) {
      return true;
    }
    return false;
  }

  Future<void> _handleFcmMessage(RemoteMessage message) async {
    try {
      if (!_isApprovalMessage(message)) return;
      final prefs = await SharedPreferences.getInstance();

      // A notification is not proof of a session: without this guard, a
      // stale/test push landing on a fresh install (e.g. tapped while the
      // app was killed, which is effectively a first open) would shove the
      // user straight to Home with no login ever having happened. Only act
      // on the message if this device actually holds a logged-in session.
      final token = prefs.getString(ApiConstants.token);
      if (token == null || token.isEmpty) return;

      await prefs.setString(ApiConstants.verificationStatus, 'approved');
      final home = RouteHelper.gethomescreen();
      if (Get.currentRoute != home) {
        Get.offAllNamed(home);
      }
    } catch (e) {
      debugPrint('[FCM] _handleFcmMessage error: $e');
    }
  }

  void _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    String? title = message.notification?.title;
    String? body = message.notification?.body;

    // Never expose OTP values in notification tray
    final hasOtpInData = message.data.containsKey('otp');
    final bodyHasOtp = body != null &&
        RegExp(r'\b\d{4,8}\b').hasMatch(body) &&
        body.toLowerCase().contains('otp');
    if (hasOtpInData || bodyHasOtp) {
      title = 'Nride driver Verification';
      body = 'Tap to open the app and enter your verification code.';
    }

    await flutterLocalNotificationsPlugin.show(
      id: message.notification.hashCode,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  void _initializeFlutterLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print("Payload: ${response.payload}");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: Get.key,
      
      title: AppConstants.appName,
      initialRoute: RouteHelper.getSplashRoute(),
      getPages: RouteHelper.routes,
      defaultTransition: Transition.topLevel,
      transitionDuration: const Duration(milliseconds: 500),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: EasyLoading.init()(context, child),
        );
      },
    );
  }
}




