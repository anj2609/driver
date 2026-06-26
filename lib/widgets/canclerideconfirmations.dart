import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

class CancelRideBottomSheet extends StatefulWidget {
  final String? bookingId;
  const CancelRideBottomSheet({super.key, this.bookingId});

  @override
  State<CancelRideBottomSheet> createState() => _CancelRideBottomSheetState();
}

class _CancelRideBottomSheetState extends State<CancelRideBottomSheet> {
  int selectedIndex = -1;
  String cancleId = "";
  bool isCancelling = false;
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<HomeController>();
  }

  @override
  Widget build(BuildContext context) {
    final reasons = _controller.cancleReasonModelList;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Cancel Ride",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Please select a reason for cancellation",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          if (reasons.isEmpty)
            const Center(child: PremiumBlurLoader())
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reasons.length,
              itemBuilder: (context, index) {
                final reason = reasons[index];
                final isSelected = selectedIndex == index;

                return GestureDetector(
                  onTap: isCancelling
                      ? null
                      : () {
                          setState(() {
                            selectedIndex = index;
                            cancleId = reason.id.toString();
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
                          ? Border.all(color: Colors.black, width: 1.5)
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
            child: isCancelling
                ? const Center(child: PremiumBlurLoader())
                : CustomCancleButton(
                    text: 'Confirm Cancellation',
                    onTap: () async {
                      if (selectedIndex == -1 || cancleId.isEmpty) {
                        Get.snackbar(
                          "Select Reason",
                          "Please select a cancellation reason",
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red.shade50,
                          colorText: Colors.red,
                        );
                        return;
                      }

                      if (widget.bookingId == null || widget.bookingId!.isEmpty) {
                        Get.snackbar(
                          "Error",
                          "Booking ID not found",
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red.shade50,
                          colorText: Colors.red,
                        );
                        return;
                      }

                      setState(() => isCancelling = true);

                      try {
                        await _controller.cancleRideByDriver(
                          context: context,
                          bookingId: widget.bookingId!,
                          cancellationid: cancleId,
                        );
                      } catch (_) {
                        if (mounted) {
                          setState(() => isCancelling = false);
                        }
                      }
                    },
                  ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
