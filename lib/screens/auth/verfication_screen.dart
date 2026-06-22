import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';

import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/dimensions.dart';
import 'package:myridedriverapp/config/utils/style.dart';

class VerificationLoaderScreen extends StatefulWidget {
  const VerificationLoaderScreen({Key? key}) : super(key: key);

  @override
  State<VerificationLoaderScreen> createState() =>
      _VerificationLoaderScreenState();
}

class _VerificationLoaderScreenState
    extends State<VerificationLoaderScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // continuous rotation
    _navigateAfterDelay();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


 Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 4));

    Get.offAllNamed(RouteHelper.getHomeScreen());
  }


  
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorResources.appgroundcolor, // light grey bg
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // Animated Hourglass
                RotationTransition(
                  turns: _controller,
                  child: Icon(
                    Icons.hourglass_empty,
                    size: 80,
                    color: ColorResources.appColor,
                  ),
                ),

                const SizedBox(height: 40),

                // Main Title
                 Text(
                  "We’re verifying your\ndocuments & details",
                  textAlign: TextAlign.center,
                     style: PoppinsExtrabold.copyWith(
                                color: ColorResources.blackcolor11,
                                fontSize: Dimensions.hight15
                              ),
                ),

                const SizedBox(height: 16),

                // Subtitle
                 Text(
                  "Hang tight! This could take a minute or\n two to complete!",
                  textAlign: TextAlign.center,
                   style: PoppinsReguler.copyWith(
                                color: ColorResources.TextColorForGrey,
                                fontSize: Dimensions.hight15
                              ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}