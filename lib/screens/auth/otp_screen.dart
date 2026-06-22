import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';
import 'package:myridedriverapp/widgets/custom_popup.dart';
import 'package:myridedriverapp/widgets/toaster_animation.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_autofill/sms_autofill.dart';

class OtpScreen extends StatefulWidget {
  String? type;
  String? phoneNumber;
  OtpScreen({super.key, this.type, this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with CodeAutoFill {
  int _secondsRemaining = 28;
  Timer? _timer;
  bool _enableResend = false;
  bool _isResending = false;
  bool _isVerifying = false;
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    listenForCode();
    startTimer();
  }

  void startTimer() {
    setState(() {
      _secondsRemaining = 28;
      _enableResend = false;
    });

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();

        setState(() {
          _enableResend = true;
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void codeUpdated() {
    // Only update the text; onCompleted on the Pinput widget handles verification.
    _otpController.text = code ?? "";
  }

  @override
  void dispose() {
    cancel();
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Scaffold(
      backgroundColor: ColorResources.backgroundColor,
      appBar: AppBar(
        backgroundColor: ColorResources.backgroundColor,
        leading: IconButton(
          onPressed: () {
            Get.back();
            // Navigator.pop(context);
          },

          icon: Icon(Icons.arrow_back, color: ColorResources.blackcolor11),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),

              const SizedBox(height: 10),

              Text(
                "Enter OTP Code 🔐",
                style: PoppinsSemiBold.copyWith(
                  color: ColorResources.blackcolor11,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Check your messages! We’ve sent a one-time ${widget.phoneNumber} . Enter the code \nbelow to verify your account and continue",

                style: PoppinsMedium.copyWith(
                  color: ColorResources.TextColorForGrey,
                ),
              ),

              const SizedBox(height: 30),

              /// Pinput Field
              Center(
                child: Pinput(
                  controller: _otpController,
                  length: 4,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  defaultPinTheme: defaultPinTheme,
                  onCompleted: (pin) async {
                    if (_isVerifying) return;
                    setState(() => _isVerifying = true);

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => PremiumBlurLoader(),
                    );

                    try {
                      var response = await Get.find<AuthController>()
                          .verifyOtpApi(
                            mobileNumber: widget.phoneNumber ?? "",
                            numOfOtp: pin,
                            type: widget.type ?? "",
                            context: context,
                          );

                      // Hide Loader
                      if (Get.isDialogOpen ?? false) {
                        Get.back();
                      }

                      if (response != null && response.body != null) {
                        Map<String, dynamic> body =
                            response.body is Map<String, dynamic>
                            ? response.body
                            : {};

                        String code = body["code"]?.toString() ?? "";
                        String? verificationStatus = body["verification_status"]
                            ?.toString();

                        final prefs = await SharedPreferences.getInstance();

                        await prefs.setString(
                          ApiConstants.verificationStatus,
                          verificationStatus ?? "",
                        );

                        var data = body["data"];
                        String? profileStatus = data?["profile_status"]
                            ?.toString();

                        if (profileStatus == "1") {
                         
                          
                          Get.offAllNamed(
                            RouteHelper.getearnWithMyRideScreen(),
                          );
                          return;
                        }

                        if (profileStatus == "2" || profileStatus == "3") {
                          await prefs.setString(
                            ApiConstants.isPersonalSavedStatus,
                            profileStatus.toString(),
                          );

                          Get.toNamed(
                            RouteHelper.getDriverDetails(),
                            arguments: {"step": 2},
                          );
                          return;
                        }

                        if (profileStatus == "4") {
                          Get.toNamed(
                            RouteHelper.getDriverDetails(),
                            arguments: {"step": 4},
                          );
                          return;
                        }

                        if (profileStatus == "5") {
                          Get.toNamed(
                            RouteHelper.getDriverDetails(),
                            arguments: {"step": 5},
                          );
                          return;
                        }

                        if (verificationStatus == "rejected" ||
                            verificationStatus == "pending") {
                          Get.dialog(
                            CustomPopup(status: verificationStatus!, ),
                            barrierDismissible: false,
                          );
                          return;
                        }

                        if (code == "200") {
                          Get.offAllNamed(RouteHelper.gethomescreen());
                        }
                      }
                    } catch (e) {
                      if (Get.isDialogOpen ?? false) {
                        Get.back();
                      }
                      Get.snackbar("Error", e.toString());
                    } finally {
                      if (mounted) setState(() => _isVerifying = false);
                    }
                    // var response = await Get.find<AuthController>()
                    //     .verifyOtpApi(
                    //       mobileNumber: widget.phoneNumber ?? "",
                    //       numOfOtp: pin,
                    //       type: widget.type ?? "",
                    //       context: context,
                    //     );

                    // if (response != null && response.body != null) {
                    //   Map<String, dynamic> body =
                    //       response.body is Map<String, dynamic>
                    //       ? response.body
                    //       : {};

                    //   String code = body["code"]?.toString() ?? "";
                    //   String? verificationStatus = body["verification_status"]
                    //       ?.toString();

                    //   final prefs = await SharedPreferences.getInstance();
                    //   await prefs.setString(
                    //     ApiConstants.verificationStatus,
                    //     verificationStatus ?? "",
                    //   );
                    //   var data = body["data"];
                    //   String? profileStatus = data?["profile_status"]
                    //       ?.toString();

                    //   if (profileStatus == "1") {
                    //     Get.offAllNamed(RouteHelper.getearnWithMyRideScreen());
                    //     return;
                    //   }
                    //   if (profileStatus == "2" || profileStatus == "3") {
                    //     Get.toNamed(
                    //       RouteHelper.getDriverDetails(),
                    //       arguments: {"step": 2},
                    //     );

                    //     /// final prefs = await SharedPreferences.getInstance();
                    //     prefs.setString(
                    //       ApiConstants.isPersonalSavedStatus,
                    //       profileStatus.toString(),
                    //     );

                    //     return;
                    //   }

                    //   if (profileStatus == "4") {
                    //     Get.toNamed(
                    //       RouteHelper.getDriverDetails(),
                    //       arguments: {"step": 4},
                    //     );
                    //   }

                    //   if (profileStatus == "5") {
                    //     Get.toNamed(
                    //       RouteHelper.getDriverDetails(),
                    //       arguments: {"step": 5},
                    //     );
                    //   }

                    //   if (verificationStatus == "rejected" ||
                    //       verificationStatus == "pending") {
                    //     Get.dialog(
                    //       CustomPopup(status: verificationStatus.toString()),
                    //       barrierDismissible: false,
                    //     );
                    //     return;
                    //   }
                    //   if (code == "200") {
                    //     Get.offAllNamed(RouteHelper.gethomescreen());
                    //     return;
                    //   }
                    // }
                  },
                ),
              ),

              const SizedBox(height: 30),
              Center(
                child: CustomOtpButton(
                  text: _enableResend
                      ? "Resend OTP"
                      : "Resend in $_secondsRemaining sec",
                  isLoading: _isResending,
                  onTap: (_enableResend && !_isResending)
                      ? () async {
                          log('resend otp clicked |||||');

                          setState(() {
                            _isResending = true;
                          });

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => PremiumBlurLoader(),
                          );

                          try {
                            await Get.find<AuthController>().reSendOtp(
                              mobileNumber: widget.phoneNumber.toString(),
                              otpNumber: _otpController.text.trim(),
                              context: context,
                            );

                            _otpController.clear();
                            startTimer();
                          } catch (e) {
                            // Get.snackbar(
                            //   "",
                            //   e.toString(),
                            //   snackPosition: SnackPosition.TOP,
                            // );
                          } finally {
                            if (Navigator.canPop(context)) {
                              Navigator.of(context, rootNavigator: true).pop();
                            }

                            if (mounted) {
                              setState(() {
                                _isResending = false;
                              });
                            }
                          }
                          // setState(() {
                          //   _isResending = true;
                          // });

                          // await Get.find<AuthController>().reSendOtp(
                          //   mobileNumber: widget.phoneNumber.toString(),
                          //   otpNumber: _otpController.text.trim(),
                          //   context: context,
                          // );
                          // _otpController.clear();

                          // setState(() {
                          //   _isResending = false;
                          // });

                          // startTimer();
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NextScreen extends StatelessWidget {
  const NextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "OTP Verified ✅",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
