import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Get.find<ProfileController>().getNotificationsDetails(context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ProfileController>();

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),

      body: SafeArea(
        child: Column(
          children: [
            /// Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: InkWell(
                      onTap: () => Get.back(),
                      child: const Icon(Icons.close),
                    ),
                  ),

                  const SizedBox(width: 20),

                  Text(
                    "Notification",
                    style: PoppinsExtrabold.copyWith(
                      color: ColorResources.blackcolor,
                    ),
                  ),

                  const Spacer(),

                  TextButton(
                    onPressed: () {
                      controller.deleteAllNotifications(context: context);
                    },
                    child: Text(
                      "Delete All",
                      style: PoppinsExtrabold.copyWith(
                        color: ColorResources.textColorRed,
                      ),
                      // style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: GetBuilder<ProfileController>(
                builder: (controller) {
                  if (controller.isNotificationLoading) {
                    return Center(child: PremiumBlurLoader());
                  }

                  if (controller.notificationList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            "assets/images/datanotcomming.png",
                            height: 150,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Data Not Found",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: controller.notificationList.length,

                    itemBuilder: (context, index) {
                      var item = controller.notificationList[index];

                      return Dismissible(
                        key: ValueKey(item.id),

                        direction: DismissDirection.endToStart,

                        background: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 25),
                          decoration: BoxDecoration(
                            color: ColorResources.textColorRed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),

                        onDismissed: (_) {
                          String deletedId = item.id ?? "";

                          /// REMOVE FROM UI IMMEDIATELY
                          controller.notificationList.removeAt(index);
                          controller.update();

                          /// THEN CALL API
                          controller.deleteNotifications(
                            context: context,
                            id: deletedId,
                            indexxx: index,
                          );
                        },

                        child: InkWell(
                          onTap: () {
                            if (item.isRead == "0") {
                              controller.readNotifications(
                                context: context,
                                id: item.id ?? "",
                              );
                            }
                          },

                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),

                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),

                            child: Row(
                              children: [
                                Icon(
                                  item.isRead == "0"
                                      ? Icons.notifications_active
                                      : Icons.notifications,
                                  color: item.isRead == "0"
                                      ? Colors.blue
                                      : Colors.grey,
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.message ?? "",
                                        style: PoppinsReguler.copyWith(
                                          color: ColorResources.blackcolor,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        item.date ?? "",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
