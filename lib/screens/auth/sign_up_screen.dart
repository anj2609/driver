import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';

import 'package:myridedriverapp/config/utils/dimensions.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';
import 'package:myridedriverapp/widgets/custom_popup.dart';

class MyRideLoginScreen extends StatefulWidget {
  const MyRideLoginScreen({Key? key}) : super(key: key);

  @override
  State<MyRideLoginScreen> createState() => _MyRideLoginScreenState();
}

class _MyRideLoginScreenState extends State<MyRideLoginScreen> {
  final TapGestureRecognizer _tcRecognizer = TapGestureRecognizer();
  final TapGestureRecognizer _ppRecognizer = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    _tcRecognizer.onTap = () =>
        Get.toNamed(RouteHelper.gettermsAndConditionScreen());
    _ppRecognizer.onTap = () =>
        Get.toNamed(RouteHelper.getprivacyPolicyScreen());
  }

  @override
  void dispose() {
    _tcRecognizer.dispose();
    _ppRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorResources.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.spacingSize25,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/splashscreen.png',
                height: MediaQuery.of(context).size.height * 0.15,
                width: MediaQuery.of(context).size.width * 0.5,
                color: ColorResources.blueeebutton,
                fit: BoxFit.contain,
              ),

              Text(
                "Let's Get Started!",
                style: PoppinsSemiBold.copyWith(
                  color: ColorResources.blackcolor,
                ),
              ),

              SizedBox(height: Dimensions.spacingSize10),

              Text(
                "Let's dive in into your account",
                style: PoppinsMedium.copyWith(
                  color: ColorResources.TextColorForGrey,
                ),
              ),

              SizedBox(height: Dimensions.spacingSize40),

              CustomSocialButton(
                text: "Continue with Google",
                images: 'assets/images/google.png',
                iconColor: Colors.red,
                onTap: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => PremiumBlurLoader(),
                  );

                  try {
                    final response = await Get.find<AuthController>()
                        .signInWithGoogle(
                          provider: 'google',
                          context: context,
                        );

                    if (Get.isDialogOpen ?? false) Get.back();

                    if (response == null) return;

                    final code = response.body?['code']?.toString() ?? '';
                    final verificationStatus =
                        response.body?['verification_status']?.toString() ?? '';

                    if (code == '200') {
                      Get.offAllNamed(RouteHelper.gethomescreen());
                    } else if (code == '401') {
                      if (verificationStatus == "rejected" ||
                          verificationStatus == "pending") {
                        Get.dialog(
                          CustomPopup(status: verificationStatus),
                          barrierDismissible: false,
                        );
                      }
                    } else {
                      Get.snackbar(
                        "Error",
                        response.body?['message'] ?? "Something went wrong",
                        backgroundColor: ColorResources.textColorRed,
                        colorText: ColorResources.whiteColor,
                      );
                    }
                  } catch (e) {
                    if (Get.isDialogOpen ?? false) Get.back();
                  }
                },
              ),

              SizedBox(height: Dimensions.spacingSize10),

              CustomPrimaryButton(
                text: "Sign up",
                onTap: () {
                  Get.toNamed(RouteHelper.getSignupScreen());
                },
              ),

              SizedBox(height: Dimensions.spacingSize16),

              CustomSecondaryButton(
                text: "Sign in",
                onTap: () {
                  Get.toNamed(RouteHelper.getLoginRoute());
                },
              ),

              const Spacer(),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Privacy Policy",
                      recognizer: _ppRecognizer,
                      style: PoppinsMedium.copyWith(
                        color: ColorResources.blueeebutton,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    TextSpan(
                      text: "  •  ",
                      style: PoppinsMedium.copyWith(
                        color: ColorResources.TextColorForGrey,
                      ),
                    ),
                    TextSpan(
                      text: "Terms & Conditions",
                      recognizer: _tcRecognizer,
                      style: PoppinsMedium.copyWith(
                        color: ColorResources.blueeebutton,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: Dimensions.spacingSize20),
            ],
          ),
        ),
      ),
    );
  }
}
