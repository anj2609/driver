import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/screens/auth/driverdetails_screen.dart';
import 'package:myridedriverapp/screens/auth/ernwithmyride_screen.dart';
import 'package:myridedriverapp/screens/auth/sign_up_screen.dart';
import 'package:myridedriverapp/screens/home/home_screen.dart';
import 'package:myridedriverapp/splash/onbording_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false;
  Timer? _frameTimer;
  Timer? _fallbackTimer;

  // Page-wide gradient (the animated icon itself has a transparent
  // background — no video codec Flutter can play supports alpha
  // compositing, so the icon is a PNG frame sequence layered on top of
  // this gradient instead of a video).
  static const Color _gradientStart = Color(0xFF292B84);
  static const Color _gradientEnd = Color(0xFF0004CF);

  // Source clip ("transparent final.mov") exported at 20fps/5s as a
  // transparent PNG sequence — video_player can't decode its ProRes+alpha
  // codec, and Flutter's video widgets don't composite alpha even when a
  // codec can be decoded, so a frame sequence is the reliable option.
  static const int _frameCount = 100;
  static const Duration _frameInterval = Duration(milliseconds: 50); // 20fps

  late final List<String> _framePaths = List.generate(
    _frameCount,
    (i) =>
        'assets/images/splash_frames/frame_${(i + 1).toString().padLeft(3, '0')}.png',
  );

  int _currentFrame = 0;
  bool _framesReady = false;

  bool _hasStartedLoading = false;

  @override
  void initState() {
    super.initState();

    // Safety fallback in case frame precaching stalls entirely — never get
    // stuck on the splash.
    _fallbackTimer = Timer(const Duration(seconds: 10), _navigateAfterDelay);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // precacheImage() needs MediaQuery (via createLocalImageConfiguration),
    // which isn't available yet inside initState() — calling it there threw
    // on every frame and silently killed the animation before it ever
    // started. didChangeDependencies() is the correct place for this.
    if (_hasStartedLoading) return;
    _hasStartedLoading = true;
    _loadFramesAndPlay();
  }

  Future<void> _loadFramesAndPlay() async {
    // Precache every frame before starting playback so the full animation
    // plays smoothly from frame one instead of janking while assets decode
    // mid-playback. Guarded so a single bad/missing frame can't silently
    // strand the splash on just the gradient until the fallback timer.
    try {
      await Future.wait(
        _framePaths.map((path) => precacheImage(AssetImage(path), context)),
      );
    } catch (e) {
      debugPrint('[Splash] frame precache failed: $e');
    }

    if (!mounted) return;

    setState(() => _framesReady = true);

    _frameTimer = Timer.periodic(_frameInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentFrame >= _frameCount - 1) {
        timer.cancel();
        // Hold on the final revealed frame briefly before navigating.
        Future.delayed(const Duration(milliseconds: 400), _navigateAfterDelay);
        return;
      }

      setState(() => _currentFrame++);
    });
  }

  Future<void> _navigateAfterDelay() async {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _frameTimer?.cancel();
    _fallbackTimer?.cancel();

    // Firebase/DI are kicked off in main() without being awaited so the
    // first frame can paint immediately; make sure they're ready before
    // touching Get.find or anything Firebase-backed below.
    await appInitialization;

    final prefs = await SharedPreferences.getInstance();

    String? token = prefs.getString("token");
    String? userId = prefs.getString(ApiConstants.profileid);

    int workStatus = prefs.getInt("work_status") ?? 0;

    driverId = userId;

    if (token != null && token.isNotEmpty) {
      final authController = Get.find<AuthController>();

      // docsSubmittedForReview is set the moment the final vehicle-document
      // upload succeeds. It's a fast local hint, but it can't be trusted
      // alone — it's missing for any account that submitted before this
      // flag existed, or whose in-app step markers never got persisted.
      // So it's only used to short-circuit; the real answer always comes
      // from asking the server what it actually has on file for this driver.
      final bool docsSubmittedLocally =
          prefs.getBool(ApiConstants.docsSubmittedForReview) ?? false;

      final approved = await authController.fetchDocumentStatus(
        navigateOnApproved: false,
      );

      // fetchDocumentStatus() populates these lists whenever the server
      // actually has document records for this driver — that's proof
      // documents were submitted, independent of any local flag.
      final bool hasServerDocs =
          authController.editDriverDocumentList.isNotEmpty ||
          authController.editVehicleDocumentList.isNotEmpty;

      if (approved || docsSubmittedLocally || hasServerDocs) {
        if (hasServerDocs && !docsSubmittedLocally) {
          // Heal the local flag so future cold starts don't need this fallback.
          await prefs.setBool(ApiConstants.docsSubmittedForReview, true);
        }

        // Once registration is submitted, land on the dashboard regardless
        // of approval status — a driver mid-verification should still be
        // able to browse the app. Going online itself stays strictly
        // gated (HomeController.toggleOnline) behind a fresh approval
        // check, which is what actually stops an unverified driver from
        // taking rides.
        final controller = Get.find<HomeController>();
        controller.setWorkStatus(approved ? workStatus : 0);

        Get.offAll(
          () => HomeMapScreen(),
          transition: Transition.noTransition,
          duration: Duration.zero,
        );
        return;
      }

      // Genuinely nothing submitted (locally or per the server) — resume
      // wherever registration was left off.
      final String? personalStatus = prefs.getString(
        ApiConstants.isPersonalSavedStatus,
      );
      final bool personalSaved =
          prefs.getBool(ApiConstants.isPersonalSaved) ?? false;

      if (!personalSaved && (personalStatus == null || personalStatus.isEmpty)) {
        Get.offAll(
          () => EarnWithMyRideScreen(),
          transition: Transition.noTransition,
          duration: Duration.zero,
        );
        return;
      }

      Get.offAll(
        () => DetailsScreen(),
        transition: Transition.noTransition,
        duration: Duration.zero,
      );
      return;
    }

    final bool hasSeenOnboarding =
        prefs.getBool('has_seen_onboarding') ?? false;
    if (hasSeenOnboarding) {
      Get.offAll(
        () => MyRideLoginScreen(),
        transition: Transition.noTransition,
        duration: Duration.zero,
      );
    } else {
      Get.offAll(
        () => OnboardingScreen(),
        transition: Transition.noTransition,
        duration: Duration.zero,
      );
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
        child: _framesReady
            ? Center(
                child: Image.asset(
                  _framePaths[_currentFrame],
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}
