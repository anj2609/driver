import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
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
  Timer? _timer;
  Timer? _fallbackTimer;

  // Sampled directly from the video's own background (top/bottom corner
  // pixels of its frames) so the letterboxed area above/below the video
  // (its aspect ratio is wider than any portrait screen) blends into it
  // seamlessly instead of showing a mismatched or default color.
  static const Color _videoTopColor = Color(0xFF161C91);
  static const Color _videoBottomColor = Color(0xFF0B0FAB);

  late final VideoPlayerController _videoController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();

    _videoController =
        VideoPlayerController.asset('assets/images/nride_gif_cropped.mp4')
          ..setLooping(true)
          ..setVolume(0)
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() => _videoReady = true);
            _videoController.play();

            // Start the navigation countdown only once the video is
            // actually playing, timed to its real duration — a fixed
            // delay from initState() was firing before initialization
            // (which can take a noticeable moment, especially on a cold
            // start alongside Firebase/DI setup) finished, cutting the
            // video off partway through instead of letting it finish.
            _fallbackTimer?.cancel();
            final playDuration =
                _videoController.value.duration + const Duration(milliseconds: 300);
            _timer = Timer(playDuration, _navigateAfterDelay);
          });

    // Safety fallback in case video initialization stalls entirely
    // (e.g. a corrupt/missing asset) — never get stuck on the splash.
    _fallbackTimer = Timer(const Duration(seconds: 10), _navigateAfterDelay);
  }

  Future<void> _navigateAfterDelay() async {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _timer?.cancel();
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
    _timer?.cancel();
    _fallbackTimer?.cancel();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_videoTopColor, _videoBottomColor],
          ),
        ),
        child: _videoReady
            ? Center(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}
