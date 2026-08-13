import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/screens/auth/driverdetails_screen.dart';
import 'package:myridedriverapp/screens/auth/ernwithmyride_screen.dart';
import 'package:myridedriverapp/screens/auth/socialauth_screen.dart';
import 'package:myridedriverapp/screens/auth/sign_up_screen.dart';
import 'package:myridedriverapp/screens/home/home_screen.dart';
import 'package:myridedriverapp/splash/onbording_screen.dart';
import 'package:myridedriverapp/main.dart' show initializeAppCore;

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

  // True once appInitialization (Firebase.initializeApp() + di.init()) has
  // failed twice in a row (first attempt from main(), one retry here).
  // Every screen this app can navigate to assumes DI already succeeded —
  // none of their Get.find() calls are guarded — so silently proceeding
  // past a failed init would just move the crash one screen later instead
  // of fixing it. Surfacing a retry UI here instead is the difference
  // between a recoverable state and an unconditional "keeps stopping".
  bool _initFailed = false;

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
    //
    // Each frame is a 720x1280 RGBA PNG — ~3.5MB once decoded, regardless
    // of its much smaller on-disk (compressed) size. The old code fired
    // all 100 precacheImage() calls at once via Future.wait(), which asks
    // Skia to decode up to ~350MB of bitmap data concurrently, right at
    // cold app launch before anything else has even loaded. That's a
    // plausible OutOfMemoryError on a low-RAM device (reported: Galaxy
    // M11, a 3-4GB-RAM budget phone) even though it's perfectly fine on a
    // higher-RAM device where this may never have been noticed. Decoding
    // in small sequential batches bounds the peak concurrent memory to a
    // few frames' worth instead of all 100, at the cost of a slightly
    // longer (still well under the 10s fallback timer) load — a one-time
    // startup cost either way.
    const batchSize = 8;
    try {
      for (var i = 0; i < _framePaths.length; i += batchSize) {
        if (!mounted) return;
        final batch = _framePaths.skip(i).take(batchSize);
        await Future.wait(
          batch.map((path) => precacheImage(AssetImage(path), context)),
        );
      }
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
    //
    // Was a bare `await appInitialization` with nothing catching a
    // rejection — if Firebase.initializeApp() throws (a real thing on
    // devices with broken/outdated Google Play Services, which low-end
    // phones on old OS builds are especially prone to — reported crash was
    // on a Galaxy M11), that exception propagated straight out of this
    // function uncaught. It's invoked from a Timer callback, so nothing
    // in the widget tree ever gets a chance to catch it either — an
    // unhandled async exception at the very first screen of the app,
    // which is exactly what an Android "keeps stopping" crash looks like.
    // Retrying once handles the common transient case (Play Services not
    // ready yet at boot); a UI to retry manually is offered only if that
    // retry also fails, instead of pretending init succeeded and letting
    // every downstream Get.find() call crash instead.
    try {
      await appInitialization;
    } catch (e, st) {
      debugPrint('[Splash] appInitialization failed: $e\n$st');
      try {
        appInitialization = initializeAppCore();
        await appInitialization;
      } catch (e2, st2) {
        debugPrint('[Splash] appInitialization retry failed: $e2\n$st2');
        if (!mounted) return;
        setState(() => _initFailed = true);
        return;
      }
    }

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
      //
      // Was `||` — but the driver-identity documents (editDriverDocumentList)
      // and the vehicle documents (editVehicleDocumentList) are uploaded in
      // separate steps of registration, with the vehicle-info/vehicle-photo
      // save in between. A driver whose personal documents uploaded fine but
      // whose vehicle-info save then failed (e.g. a server-side "413 Request
      // Entity Too Large" on oversized photos) has editDriverDocumentList
      // non-empty and editVehicleDocumentList still empty — `||` treated
      // that as "documents submitted" and sent them straight to the
      // dashboard on the next app open, silently abandoning an incomplete
      // registration instead of letting them retry the step that actually
      // failed. Requiring both matches the completion check fetchDocumentStatus()
      // itself already uses a few lines down (`allApproved`).
      final bool hasServerDocs =
          authController.editDriverDocumentList.isNotEmpty &&
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

        // Explicit routeName matters here: without it, Get.offAll auto-names
        // this route "/HomeMapScreen" (from the widget's runtime type) —
        // a different string from RouteHelper.getHomeScreen() ('/homeScreen'),
        // which is what every "return to home" call elsewhere in the app
        // (returnToExistingHome(), the various Get.offAllNamed(getHomeScreen())
        // calls after completing/cancelling a ride) checks the stack for.
        // With the mismatch, none of them could ever find *this* — the
        // actual screen shown at app launch — so completing a ride always
        // created a brand-new Home instance instead of returning to it.
        Get.offAll(
          () => HomeMapScreen(),
          transition: Transition.noTransition,
          duration: Duration.zero,
          routeName: RouteHelper.getHomeScreen(),
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

      // Was unconditionally DetailsScreen (the phone-OTP registration UI)
      // regardless of how this driver actually signed up. A driver who
      // registered via Google and closed the app mid-registration would
      // get resumed into the wrong screen — losing the Google name/email/
      // photo pre-fill, and simply the wrong UI for how they started.
      // userIdSocial.isNotEmpty is the same discriminator already used
      // elsewhere (e.g. AuthController.driveraddAddress()) to tell which
      // flow a session belongs to.
      if (ApiConstants.userIdSocial.isNotEmpty) {
        Get.offAll(
          () => const SocialDetailScreen(),
          transition: Transition.noTransition,
          duration: Duration.zero,
        );
      } else {
        Get.offAll(
          () => DetailsScreen(),
          transition: Transition.noTransition,
          duration: Duration.zero,
        );
      }
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
        child: _initFailed
            ? _buildInitFailedUi()
            : _framesReady
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

  Widget _buildInitFailedUi() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            const Text(
              "Couldn't start the app. Please check your connection "
              "and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              onPressed: () {
                setState(() {
                  _initFailed = false;
                  _hasNavigated = false;
                });
                _fallbackTimer = Timer(
                  const Duration(seconds: 10),
                  _navigateAfterDelay,
                );
                _navigateAfterDelay();
              },
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}
