import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';



class ApiChecker {
  static void checkApi(Response response) {
    if (response.statusCode == 401) {
      if (Get.currentRoute != RouteHelper.login) {
        // showCustomSnackBar(
        //   response.body['result'] ?? 'unauthorized'.tr,
        //   isIcon: true,
        // );
      }
    } else if (response.statusCode == 429) {
      //  showCustomSnackBar('to_money_login_attempts'.tr);
    } else if (response.statusCode == -1) {
      // showCustomSnackBar(
      //   'you are using vpn',
      //   isVpn: true,
      //   duration: Duration(minutes: 10),
      // );
    } else {
      EasyLoading.dismiss();
      // response.body['result'] != null
      //     ? showCustomSnackBar(response.body['result'], isError: true)
      //     : showCustomSnackBar(
      //         response.body['result'].toString(),
      //         isError: true,
      //       );
    }
  }

  static void forgotcheckApi(Response response) {
    if (response.statusCode == 401) {
      if (Get.currentRoute != RouteHelper.login) {
        // showCustomSnackBar(
        //   response.body['response'][0]['Error'] ?? 'unauthorized'.tr,
        //   isIcon: true,
        // );
      }
    } else if (response.statusCode == 429) {
      // showCustomSnackBar('to_money_login_attempts'.tr);
    } else if (response.statusCode == -1) {
      // showCustomSnackBar(
      //   'you are using vpn',
      //   isVpn: true,
      //   duration: const Duration(minutes: 10),
      // );
    } else {
      EasyLoading.dismiss();
      // showCustomSnackBar(
      //   response.body['response'][0]['Error'].toString(),
      //   isError: true,
      // );
    }
  }

  static void checkloginApi(Response response) {
    if (response.statusCode == 401) {
      // showCustomSnackBar(response.body['result'].toString(), isIcon: true);
    } else if (response.statusCode == 429) {
      //   showCustomSnackBar('to_money_login_attempts'.tr);
    } else if (response.statusCode == -1) {
      // showCustomSnackBar(
      //   'you are using vpn',
      //   isVpn: true,
      //   duration: Duration(minutes: 10),
      // );
    } else {
      EasyLoading.dismiss();
      // showCustomSnackBar(response.body['result'].toString(), isError: true);
    }
  }

  // Interface-name based VPN detection was disabled: Google Play's review
  // and pre-launch test devices expose tun-style interfaces even without a
  // real VPN, which caused every API call (including OTP send) to be
  // blocked with a false positive during app review.
  static Future<bool> isVpnActive() async {
    return false;
  }


}



