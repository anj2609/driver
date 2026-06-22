import 'dart:io';

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

  static Future<bool> isVpnActive() async {
    bool isVpnActive;
    List<NetworkInterface> interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.any,
    );
    interfaces.isNotEmpty
        ? isVpnActive = interfaces.any(
            (interface) =>
                interface.name.contains("tun") ||
                interface.name.contains("ppp") ||
                interface.name.contains("pptp") ||
                     interface.name.contains('ipsec'),
       
          )
        : isVpnActive = false;

    return isVpnActive;
  }

//   static Future<bool> isVpnActive() async {
//   try {
//     final interfaces = await NetworkInterface.list(
//       includeLoopback: false,
//       type: InternetAddressType.any,
//     );

//     for (var interface in interfaces) {
//       final name = interface.name.toLowerCase();

//       // Only check strong VPN indicators
//       if (name.contains('tun') ||
//           name.contains('ppp') ||
//           name.contains('ipsec') ||
//           name.contains('utun')) {
//         return true;
//       }
//     }
//   } catch (e) {
//     print("VPN check error: $e");
//   }

//   return false;
// }



}



