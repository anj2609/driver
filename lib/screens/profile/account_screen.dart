import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),
      body: SafeArea(
        child: Column(
          children: [
            /// 🔹 Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.close, color: Colors.black),
                      ),
                    ),
                  ),
                  const Text(
                    "Account",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            /// 🔹 List Section
            Expanded(
              child: Container(
                decoration: const BoxDecoration(color: Colors.white),
                child: ListView(
                  children: [
                    accountTile(
                      icon: Icons.directions_car,
                      title: "Vehicles",
                      
                    ),

                   
                    accountTile(
                      icon: Icons.lock_outline,
                      title: "Privacy",
                    ),

                    accountTile(
                      icon: Icons.verified_user_outlined,
                      title: "Security",
                    ),
                    accountTile(
                      icon: Icons.info_outline,
                      title: "About",
                    ),

                    const SizedBox(height: 10),

                    /// 🔹 Sign Out
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        "Sign Out",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Get.find<AuthController>().userLogOut(context: context);
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Reusable Tile
  Widget accountTile({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.black87),
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                )
              : null,
          trailing: const Icon(
            Icons.chevron_right,
            size: 20,
            color: Colors.grey,
          ),
          onTap: () {
            if (title == 'Vehicles') {
              Get.toNamed(RouteHelper.getvehiclesScreen());
            } else if (title == 'Documents') {
              Get.toNamed(RouteHelper.getaccountDocumentsScreen());
            } else if (title == 'Manage Account') {
              Get.toNamed(RouteHelper.getmanageAccountScreen());
            } else if (title == 'Edit Addresses') {
              Get.toNamed(RouteHelper.geteditAddressScreen());
            } else if (title == 'Insurance') {
              Get.toNamed(RouteHelper.getinsuranceScreen());
            } else if (title == 'Privacy') {
              Get.toNamed(RouteHelper.getprivacyPolicyScreen());
            } else if (title == 'Security') {
              Get.toNamed(RouteHelper.gettermsAndConditionScreen());
            } else 
            if (title == 'About') {
              Get.toNamed(RouteHelper.getaboutUsScreen());
            } else {


            }
          },
        ),
        const Divider(height: 1),
      ],
    );
  }
}
