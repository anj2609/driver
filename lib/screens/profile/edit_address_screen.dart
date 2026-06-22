import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/controllers/edit_screen_controller.dart';


class EditAddressScreen extends StatelessWidget {
  EditAddressScreen({super.key});

  final controller = Get.put(EditAddressController());

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xffF2F2F2),
      body: SafeArea(
        child: Column(
          children: [

            /// ================= HEADER =================
            Container(
              width: width,
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.04,
                vertical: height * 0.015,
              ),
              decoration: const BoxDecoration(
                color: Color(0xff2EA7D7),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  /// Back Button
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      height: width * 0.10,
                      width: width * 0.10,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back),
                    ),
                  ),

                  const Text(
                    "Edit Address",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  /// Help Button
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.04,
                      vertical: height * 0.01,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Text("Help"),
                        SizedBox(width: 5),
                        Icon(Icons.keyboard_arrow_down, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: height * 0.02),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// ================= RIDES =================
                      Obx(() => buildSectionHeader(
                            title: "Rides",
                            isExpanded:
                                controller.isRidesExpanded.value,
                            onTap: controller.toggleRides,
                          )),

                      SizedBox(height: height * 0.015),

                      /// ================= ADDITIONAL =================
                      Obx(() => Column(
                            children: [
                              buildSectionHeader(
                                title: "Additional Opportunities",
                                isExpanded: controller
                                    .isAdditionalExpanded.value,
                                onTap:
                                    controller.toggleAdditional,
                              ),

                              if (controller
                                  .isAdditionalExpanded.value) ...[
                                SizedBox(height: height * 0.02),
                                buildAddressItem(
                                  title: "Airport",
                                  subtitle:
                                      "Noida airport",
                                ),
                                buildAddressItem(
                                  title: "Rail Station",
                                  subtitle:
                                      "New Delhi Rail station",
                                ),
                              ]
                            ],
                          )),

                      SizedBox(height: height * 0.015),

                      /// ================= VEHICLE =================
                      Obx(() => buildSectionHeader(
                            title: "Vehicle",
                            isExpanded:
                                controller.isVehicleExpanded.value,
                            onTap: controller.toggleVehicle,
                          )),

                      SizedBox(height: height * 0.06),

                      /// ================= BUTTON =================
                      Center(
                        child: Container(
                          width: width * 0.85,
                          padding: EdgeInsets.symmetric(
                              vertical: height * 0.018),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius:
                                BorderRadius.circular(30),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "Manage Vehicle",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= SECTION HEADER =================
  Widget buildSectionHeader({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpanded ? Icons.remove : Icons.add,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ================= ADDRESS ITEM =================
  Widget buildAddressItem({
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w600)),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey),
                      children: [
                        TextSpan(text: subtitle),
                        const TextSpan(
                            text: " • "),
                        const TextSpan(
                          text: "Completed",
                          style: TextStyle(
                              color:
                                  Color(0xff2EA7D7)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey),
          ],
        ),
        const Divider(height: 25),
      ],
    );
  }
}