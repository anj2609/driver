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
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_autofill/sms_autofill.dart';

class OtpScreen extends StatefulWidget {
  final String? type;
  final String? phoneNumber;
  const OtpScreen({super.key, this.type, this.phoneNumber});

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
  final FocusNode _pinFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    listenForCode();
    startTimer();
    // Clear any cached SMS autofill value so the field is always fresh on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpController.clear();

      // Was Pinput's own `autofocus: true`, which requests focus/the
      // keyboard the instant this screen is first laid out — i.e. while
      // this route's push transition is still animating in. The platform
      // can silently drop a show-keyboard request made mid-transition: the
      // field ends up Flutter-focused but with no keyboard actually shown,
      // so the very first tap on a pin box looked like it did nothing (the
      // field was already "focused" as far as Flutter was concerned, so
      // the tap didn't re-trigger a keyboard request) and only a second
      // tap — after the transition had settled — brought it up. Requesting
      // focus explicitly, after the transition's had time to finish, makes
      // the keyboard reliably appear on the very first interaction.
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) FocusScope.of(context).requestFocus(_pinFocusNode);
      });
    });
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
    _pinFocusNode.dispose();
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
                "Enter OTP Code",
                style: PoppinsSemiBold.copyWith(
                  color: ColorResources.blackcolor11,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Check your messages! We’ve sent a one-time ${widget.phoneNumber} . Enter the code \nbelow to verify your account and continue",

                style: PoppinsMedium.copyWith(
                  color: ColorResources.textColorForGrey,
                ),
              ),

              const SizedBox(height: 30),

              /// Pinput Field
              Center(
                child: Pinput(
                  controller: _otpController,
                  focusNode: _pinFocusNode,
                  length: 4,
                  // Focus is requested explicitly in initState() once the
                  // route's push transition has settled instead — see the
                  // comment there for why autofocus (which fires mid
                  // transition) made the first tap look unresponsive.
                  autofocus: false,
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

                      if (response.body != null) {
                        Map<String, dynamic> body =
                            response.body is Map<String, dynamic>
                            ? response.body
                            : {};

                        String code = body["code"]?.toString() ?? "";
                        String? verificationStatus = body["verification_status"]
                            ?.toString();

                        // Clear field on failure; keep it for doc-pending 401 (has token)
                        final hasToken = body["data"]?["token"]?.toString().isNotEmpty == true;
                        final isWrongOtp = code == "401" && !hasToken;
                        if (code != "200" && !(code == "401" && hasToken)) {
                          _otpController.clear();
                        }

                        // A wrong/expired OTP means no session was ever
                        // established for this attempt — stop here.
                        // verifyOtpApi() already showed the "Incorrect OTP"
                        // toast; continuing on to check profileStatus below
                        // is wrong because `data` can still carry a stale
                        // profile (e.g. from an earlier partial registration
                        // attempt on the same phone number), which would
                        // otherwise navigate the user forward as if the OTP
                        // had actually been verified.
                        if (isWrongOtp) {
                          return;
                        }

                        final prefs = await SharedPreferences.getInstance();

                        if (verificationStatus != null &&
                            verificationStatus.isNotEmpty) {
                          // Persist the status returned by the API
                          await prefs.setString(
                            ApiConstants.verificationStatus,
                            verificationStatus,
                          );
                        } else {
                          // API returned no status — fall back to whatever was
                          // previously saved (e.g. "pending" set after upload)
                          verificationStatus = prefs.getString(
                            ApiConstants.verificationStatus,
                          );
                        }

                        var data = body["data"];

                        // Mirrors the rider flow: a brand-new driver is sent to
                        // start registration, carried by the signup_token until
                        // it is complete. An existing driver falls through to
                        // the profile_status routing below unchanged — the
                        // "normal flow like now".
                        final bool isNewUser = data?["is_new_user"] == true;
                        if (isNewUser) {
                          await prefs.setString(
                            ApiConstants.signupToken,
                            data?["signup_token"]?.toString() ?? "",
                          );
                          Get.offAllNamed(
                            RouteHelper.getearnWithMyRideScreen(),
                          );
                          return;
                        }

                        // is_new_user: false means this driver is already
                        // fully registered — no onboarding to resume, straight
                        // into the app, mirroring the rider's own existing-user
                        // path. The profile_status/document-resume routing
                        // below is left in place only for the legacy
                        // code == "401" (verified-but-incomplete) response;
                        // it no longer runs for a normal code == "200" verify.
                        if (code == "200") {
                          Get.offAllNamed(RouteHelper.gethomescreen());
                          return;
                        }

                        String? profileStatus = data?["profile_status"]
                            ?.toString();

                        // An incomplete profile takes priority over
                        // verification_status: the backend can return
                        // verification_status == "pending" as the default
                        // for a brand-new account that hasn't even finished
                        // the earlier onboarding steps yet, not only for a
                        // driver who has actually submitted documents. So a
                        // driver still mid-registration must always be sent
                        // back into the registration flow — showing the
                        // "documents under review" popup here would be a lie
                        // (there are no documents yet), and "Check Status"
                        // would land them on an empty document screen.
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
                          if (profileStatus == "3") {
                            await prefs.setBool(ApiConstants.isPersonalSaved, true);
                          }
                          Get.toNamed(
                            RouteHelper.getDriverDetails(),
                            arguments: {"step": 2},
                          );
                          return;
                        }

                        if (profileStatus == "4") {
                          await prefs.setString(
                            ApiConstants.isPersonalSavedStatus,
                            "4",
                          );
                          await prefs.setBool(ApiConstants.isPersonalSaved, true);
                          Get.toNamed(
                            RouteHelper.getDriverDetails(),
                            arguments: {"step": 4},
                          );
                          return;
                        }

                        if (profileStatus == "5") {
                          await prefs.setString(
                            ApiConstants.isPersonalSavedStatus,
                            "5",
                          );
                          await prefs.setBool(ApiConstants.isPersonalSaved, true);
                          Get.toNamed(
                            RouteHelper.getDriverDetails(),
                            arguments: {"step": 5},
                          );
                          return;
                        }

                        // Only once the profile is fully submitted (no
                        // incomplete-step profileStatus above matched) does a
                        // pending/rejected verification_status genuinely mean
                        // "documents were submitted and are awaiting review".
                        if (verificationStatus == "rejected" ||
                            verificationStatus == "pending") {
                          Get.dialog(
                            CustomPopup(status: verificationStatus!),
                            barrierDismissible: false,
                          );
                          return;
                        }

                        if (code == "200") {
                          Get.offAllNamed(RouteHelper.gethomescreen());
                        }
                      }
                    } catch (e) {
                      if (Get.isDialogOpen ?? false) Get.back();
                      _otpController.clear();
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
                              type: widget.type,
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
          "OTP Verified",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
