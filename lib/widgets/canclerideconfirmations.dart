import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';

class CancelRideBottomSheet extends StatefulWidget {
  final String? bookingId;
  CancelRideBottomSheet({super.key, this.bookingId});

  @override
  State<CancelRideBottomSheet> createState() => _CancelRideBottomSheetState();
}

class _CancelRideBottomSheetState extends State<CancelRideBottomSheet> {
  int selectedIndex = -0;
  String cancleId = "";

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Top Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Cancel Ride",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                const Text(
                  "Something wrong? Choose an issue:",
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 15),
                controller.isLoading == true
                    ? Center(
                        child: CircularProgressIndicator(
                          color: ColorResources.appColor,
                        ),
                      )
                    : controller.cancleReasonModelList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              "assets/images/notdatafound.png",
                              height: 150,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "No Data Found",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: controller.cancleReasonModelList.length,
                        itemBuilder: (context, index) {
                          bool isSelected = selectedIndex == index;
                          final reason =
                              controller.cancleReasonModelList[index];

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedIndex = index;
                                cancleId = controller
                                    .cancleReasonModelList[index]
                                    .id
                                    .toString();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? ColorResources.whiteColor
                                    : ColorResources.backgroundColor,
                                borderRadius: BorderRadius.circular(30),
                                border: isSelected
                                    ? Border.all(color: Colors.black)
                                    : null,
                              ),
                              child: Text(
                                reason.name ?? "",
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                        },
                      ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: CustomCancleButton(
                    text: 'Confirm',
                    onTap: () {
                      if (selectedIndex == -1) {
                        Get.snackbar(
                          "Error",
                          "Please select a cancellation reason",
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }

                      final selectedReason =
                          controller.cancleReasonModelList[selectedIndex];
                      print("Selected Reason: ${selectedIndex}");

                      print("Selected Reason: ${selectedReason.name}");
                      Get.find<HomeController>().cancleRideByDriver(
                        context: context,
                        bookingId: widget.bookingId!,
                        cancellationid: cancleId,
                      );
                      ////selectedIndex
                      //
                    },
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}
