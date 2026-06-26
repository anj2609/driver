import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 5),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    Future.delayed(Duration(seconds: 5), () {
      _navigateAfterDelay();
    });
  }

  Future<void> _navigateAfterDelay() async {
    // await Future.delayed(const Duration(seconds: 5));

    final prefs = await SharedPreferences.getInstance();

    String? token = prefs.getString("token");
    String? userId = prefs.getString(ApiConstants.profileid);

    String? verificationStatus = prefs.getString(ApiConstants.verificationStatus);

    int workStatus = prefs.getInt("work_status") ?? 0;

    driverId = userId;

    if (token != null && token.isNotEmpty) {
      if (verificationStatus == "rejected" || verificationStatus == "pending") {
        // Navigate directly to the document status screen instead of showing
        // a floating dialog. The dialog approach left no proper route underneath,
        // causing crashes when "Check Status" was tapped.
        Get.offAllNamed(
          RouteHelper.getEditVehicleDocumentScreen(),
          arguments: {"status": verificationStatus.toString()},
        );

        return;
      }

      // Approved case
      //  if (verificationStatus == "approved") {
      final controller = Get.find<HomeController>();

      controller.setWorkStatus(workStatus);

      Get.offAllNamed(RouteHelper.gethomescreen());

      return;
      // }
    }

    final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    if (hasSeenOnboarding) {
      Get.offAllNamed(RouteHelper.getmyRideLoginScreen());
    } else {
      Get.offAllNamed(RouteHelper.getOnboardingRoute());
    }
  }

  //   Future<void> _navigateAfterDelay() async {
  //     //  await Future.delayed(const Duration(seconds: 5));

  //     final prefs = await SharedPreferences.getInstance();***********************************
  //     String? token = prefs.getString("token");
  //     String? userId = prefs.g*************etString(ApiConstants.profileid);
  //     int workStatus = prefs.getInt("work_status") ?? 0;

  //     driverId = userId;
  // ///ApiConstants.verificationStatus,
  //     // if (driverprofileStatus == "1" ||
  //     //     driverprofileStatus == "2" ||
  //     //     driverprofileStatus == "3" ||
  //     //     driverprofileStatus == "4" ||
  //     //     driverprofileStatus == "5") {
  //     //   Get.toNamed(RouteHelper.getmyRideLoginScreen());
  //     // } else {
  //     if (token != null && token.isNotEmpty) {
  //       final controller = Get.find<HomeController>();

  //       controller.setWorkStatus(workStatus);

  //       controller.driverStatusOnlineOffline(context: Get.context!);

  //       Get.offAllNamed(RouteHelper.gethomescreen());
  //     } else {
  //       Get.offAllNamed(RouteHelper.getOnboardingRoute());
  //     }
  //     // }
  //   }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2DA6C4),
      body: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: Lottie.asset(
            'assets/images/Animation - 1774346600606.json',
            height: 250,
            width: 250,
            repeat: false,
            animate: true,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
