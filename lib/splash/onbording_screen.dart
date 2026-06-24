

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _timer;

  final List<Map<String, String>> onboardingData = [
    {
      "image": "assets/images/driver-pana.json",
      "title": "Drive & Earn Easily",
      "subtitle":
          "Start earning on your schedule. Accept rides, track your income, and enjoy flexible working hours with complete control.",
    },
    {
      "image": "assets/images/frame.json",
      "title": "Smart Ride Requests",
      "subtitle":
          "Get real-time ride requests near you. Accept trips instantly and optimize your time on the road with smart matching.",
    },
    {
      "image": "assets/images/mobile-landing.json",
      "title": "Grow With My Ride",
      "subtitle":
          "Unlock rewards, bonuses, and higher earnings as you complete more trips and maintain great ratings.",
    },
  ];

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        if (_currentIndex < onboardingData.length - 1) {
          _currentIndex++;
        } else {
          _currentIndex = 0;
        }
      });

      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;

    return Scaffold(
      backgroundColor: ColorResources.appgroundcolor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.06,
            vertical: height * 0.02,
          ),
          child: Column(
            children: [
              /// TOP BAR
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     Text(
              //       "My Ride",
              //       style: PoppinsBold.copyWith(
              //         fontSize: width * 0.055,
              //         color: ColorResources.appColor,
              //       ),
              //     ),
              //   ],
              // ),

              SizedBox(height: height * 0.04),

              /// PAGE VIEW
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: onboardingData.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Column(
                      children: [
                        /// IMAGE — expands to fill available space, shrinks on small screens
                        Expanded(
                          child: Lottie.asset(
                            onboardingData[index]["image"]!,
                            fit: BoxFit.contain,
                          ),
                        ),

                        SizedBox(height: height * 0.03),

                        /// TITLE
                        Text(
                          onboardingData[index]["title"]!,
                          textAlign: TextAlign.center,
                          style: PoppinsBold.copyWith(
                            fontSize: width * 0.06,
                            color: ColorResources.blackcolor,
                          ),
                        ),

                        SizedBox(height: height * 0.015),

                        /// SUBTITLE
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: width * 0.04,
                          ),
                          child: Text(
                            onboardingData[index]["subtitle"]!,
                            textAlign: TextAlign.center,
                            style: PoppinsReguler.copyWith(
                              fontSize: width * 0.038,
                              color: ColorResources.TextColorForGrey,
                              height: 1.5,
                            ),
                          ),
                        ),

                        SizedBox(height: height * 0.02),
                      ],
                    );
                  },
                ),
              ),

              /// DOT INDICATOR
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  onboardingData.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: width * 0.01),
                    height: width * 0.02,
                    width: _currentIndex == index ? width * 0.06 : width * 0.02,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? ColorResources.appColor
                          : ColorResources.greycolorborder,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              SizedBox(height: height * 0.04),

              /// NEXT / GET STARTED BUTTON
              CustomPrimaryButton(
                text: "Get Started",
                onTap: () async {
                  _timer?.cancel();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('has_seen_onboarding', true);
                  Get.toNamed(RouteHelper.getmyRideLoginScreen());
                },
              ),

              SizedBox(height: height * 0.02),
            ],
          ),
        ),
      ),
    );
  }
}
