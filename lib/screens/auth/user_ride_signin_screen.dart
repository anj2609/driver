import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';

import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/dimensions.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';
import 'package:myridedriverapp/widgets/custom_popup.dart' show CustomPopup;

class DriverSignInpScreen extends StatefulWidget {
  const DriverSignInpScreen({Key? key}) : super(key: key);

  @override
  State<DriverSignInpScreen> createState() => _DriverSignInpScreenState();
}

class _DriverSignInpScreenState extends State<DriverSignInpScreen> {
  bool isChecked = false;
  final TextEditingController mobileController = TextEditingController();
  final TapGestureRecognizer _tcRecognizer = TapGestureRecognizer();

  @override
  void dispose() {
    mobileController.dispose();
    _tcRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorResources.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Get.back();
          },
        ),
        elevation: 0,
        backgroundColor: ColorResources.backgroundColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.only(left: 15, right: 15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Join My Ride Today ✨",
                        style: PoppinsSemiBold.copyWith(
                          fontSize: Dimensions.spacingSize20,
                          color: ColorResources.blackcolor11,
                        ),
                      ),

                      const SizedBox(height: Dimensions.fontSizeSmall),
                      Text(
                        "Let's get started! Enter your phone number to \ncreate your My Ride account.",
                        style: PoppinsMedium.copyWith(
                          color: ColorResources.TextColorForGrey,
                        ),
                      ),

                      const SizedBox(height: Dimensions.spacingSize20),

                      Text(
                        "Phone Number",
                        style: PoppinsMedium.copyWith(
                          fontSize: Dimensions.smallSize,
                          color: ColorResources.blackcolor11,
                        ),
                      ),

                      const SizedBox(height: Dimensions.fontSizeSmall),

                      Container(
                        height: MediaQuery.of(context).size.height * 0.07,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                children: [
                                  Image.network(
                                    "https://flagcdn.com/w40/in.png",
                                    height: 20,
                                    width: 30,
                                    fit: BoxFit.cover,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "+91",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Container(
                              height: 25,
                              width: 1,
                              color: Colors.grey.shade300,
                            ),

                            Expanded(
                              child: TextField(
                                controller: mobileController,
                                keyboardType: TextInputType.number,
                                maxLength: 10,
                                decoration: const InputDecoration(
                                  counterText: "",
                                  hintText: "Enter phone number",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: Dimensions.spacingSize20),

                      Row(
                        children: [
                          Checkbox(
                            checkColor: ColorResources.buttonColors,
                            activeColor: ColorResources.blueeebutton,
                            value: isChecked,
                            onChanged: (value) {
                              setState(() {
                                isChecked = value!;
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                text: "I agree to My Ride ",
                                style: PoppinsMedium.copyWith(
                                  fontSize: Dimensions.spacingSize12,
                                  color: ColorResources.blackcolor11,
                                ),
                                children: [
                                  TextSpan(
                                    text: "Terms & Conditions.",
                                    recognizer: _tcRecognizer
                                      ..onTap = () {
                                        Get.toNamed(
                                          RouteHelper.gettermsAndConditionScreen(),
                                        );
                                      },
                                    style: PoppinsMedium.copyWith(
                                      fontSize: Dimensions.spacingSize12,
                                      color: ColorResources.blueeebutton,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account?",
                              style: PoppinsMedium.copyWith(
                                fontSize: 13,
                                color: ColorResources.blackcolor,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Get.toNamed(RouteHelper.getLoginRoute());
                              },
                              child: Text(
                                " Sign in",
                                style: PoppinsMedium.copyWith(
                                  fontSize: 13,
                                  color: ColorResources.blueeebutton,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              "or",
                              style: PoppinsSemiBold.copyWith(
                                fontSize: 15,
                                color: ColorResources.blackcolor11,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 20),

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

                            final code =
                                response.body?['code']?.toString() ?? '';
                            final verificationStatus =
                                response.body?['verification_status']
                                    ?.toString() ??
                                '';

                            if (code == '200') {
                              // Existing verified user.
                              Get.offAllNamed(RouteHelper.gethomescreen());
                            } else if (code == '401') {
                              // Profile incomplete — navigation handled by socailLogin().
                              // Show popup only for rejected/pending verification.
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
                                response.body?['message'] ??
                                    "Something went wrong",
                                backgroundColor: ColorResources.textColorRed,
                                colorText: ColorResources.whiteColor,
                              );
                            }
                          } catch (e) {
                            if (Get.isDialogOpen ?? false) Get.back();
                          }
                        },
                      ),

                      const SizedBox(height: 30),

                      /// Sign Up Button — smart: tries register, falls back to login
                      CustomPrimaryButton(
                        text: "Sign up",
                        onTap: () async {
                          String mobile = mobileController.text.trim();

                          if (mobile.isEmpty) {
                            Get.snackbar(
                              "Error",
                              "Please enter mobile number",
                              backgroundColor: ColorResources.textColorRed,
                              colorText: ColorResources.whiteColor,
                              duration: const Duration(seconds: 2),
                            );
                            return;
                          }

                          if (mobile.length != 10) {
                            Get.snackbar(
                              "Error",
                              "Please enter valid 10 digit number",
                              colorText: ColorResources.whiteColor,
                              backgroundColor: ColorResources.textColorRed,
                              duration: const Duration(seconds: 2),
                            );
                            return;
                          }

                          if (!isChecked) {
                            Get.snackbar(
                              "Error",
                              "Please accept Terms & Conditions",
                            );
                            return;
                          }

                          try {
                            await Get.find<AuthController>().initDeviceData();

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => PremiumBlurLoader(),
                            );

                            await Get.find<AuthController>()
                                .sendOtpWithTypeDetection(
                                  mobileNumber: mobile,
                                  deviceToken:
                                      Get.find<AuthController>().deviceToken ??
                                      "",
                                  context: context,
                                );
                          } finally {
                            if (Get.isDialogOpen ?? false) {
                              Get.back();
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
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
