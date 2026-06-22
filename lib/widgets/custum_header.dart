import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/dimensions.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          GetBuilder<ProfileController>(
            builder: (controller) {
              String imageUrl = controller.profileimagee ?? "";

              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                color: ColorResources.appColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: Dimensions.smallSize),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),

                      child: Row(
                        children: [
                          /// 🔥 PROFILE IMAGE
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: imageUrl.isNotEmpty
                                    ? NetworkImage(
                                        ApiConstants.imageurl +
                                            controller.profileimagee!,
                                      )
                                    : const NetworkImage(
                                        "https://cdn-icons-png.flaticon.com/512/9187/9187604.png",
                                      ),
                              ),

                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  height: 12,
                                  width: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 12),

                          /// 🔥 NAME + RATING
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  controller.userName ?? "No Name",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          /// 🔥 EDIT BUTTON
                          GestureDetector(
                            onTap: () {
                              Get.toNamed(RouteHelper.getProfileScreen());
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: Dimensions.spacingSize11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: ColorResources.backgroundColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: ColorResources.blackcolor,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Edit",
                                    style: PoppinsReguler.copyWith(
                                      color: ColorResources.blackcolor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10),

                    Text(
                      controller.emailAddress ?? "No Email",
                      style: PoppinsMedium.copyWith(
                        color: ColorResources.whiteColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          /// Menu Items
          _drawerItem("Home"),
          _drawerItem("Bank Info"),
          _drawerItem("Earnings"),
          _drawerItem("Notification"),
          //_drawerItem("Refer"),
          _drawerItem("Account"),
        ],
      ),
    );
  }

  Widget _drawerItem(String title) {
    return ListTile(
      title: Text(
        title,
        style: PoppinsMedium.copyWith(color: ColorResources.blackcolor),
      ),
      onTap: () {
        if (title == "Home") {
          Get.back();
        } else if (title == "Bank Info") {
          Get.toNamed(RouteHelper.getaddBankDetailsScreen());
        } else if (title == "Earnings") {
          Get.toNamed(RouteHelper.getErningRideScreen());
        } else if (title == "Notification") {
          Get.toNamed(RouteHelper.getNotificationScreen());
        } else {
          Get.toNamed(RouteHelper.getAccountScreen());
        }

        //
      },
    );
  }
}
