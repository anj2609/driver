import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/dimensions.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';
import 'package:myridedriverapp/widgets/custom_popup.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController mobileController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Get.back();
                  },
                ),

                const SizedBox(height: Dimensions.spacingSize20),

                Padding(
                  padding: const EdgeInsets.only(
                    left: Dimensions.spacingSize12,
                    right: Dimensions.spacingSize12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome Back",
                        style: PoppinsSemiBold.copyWith(
                          fontSize: Dimensions.spacingSize20,
                          color: ColorResources.blackcolor11,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Please enter your phone number to sign in to your My Ride account.",
                        style: PoppinsMedium.copyWith(
                          color: ColorResources.TextColorForGrey,
                        ),
                      ),

                      const SizedBox(height: 30),

                      Text(
                        "Phone Number",
                        style: PoppinsMedium.copyWith(
                          color: ColorResources.blackcolor11,
                        ),
                      ),

                      const SizedBox(height: 8),

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

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              "or",
                              style: PoppinsSemiBold.copyWith(
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
                              Get.offAllNamed(RouteHelper.gethomescreen());
                            } else if (code == '401') {
                              // Navigation for profile steps handled inside socailLogin().
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

                      CustomPrimaryButton(
                        text: "Sign in",
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

                          try {
                            await Get.find<AuthController>().initDeviceData();

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => PremiumBlurLoader(),
                            );

                            await Get.find<AuthController>().sendOtp(
                              mobileNumber: mobile,
                              type: ApiConstants.UserLogin,
                              deviceToken:
                                  Get.find<AuthController>().deviceToken ?? "",
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
