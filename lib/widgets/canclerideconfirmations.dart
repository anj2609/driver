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
  bool _isLoadingReasons = false;
  bool _loadFailed = false;
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<HomeController>();
    // cancleRideReason() is fired once, fire-and-forget, from
    // HomeController.onInit() — if that single attempt fails for any
    // reason (no network yet at app startup, auth token not ready, a
    // transient blip), cancleReasonModelList stays empty forever with no
    // retry anywhere. This sheet used to just read that list directly and
    // show a spinner whenever it was empty — with nothing to ever
    // populate it, that spinner never went away and cancellation was
    // permanently stuck. Fetching again here (whenever the list is
    // already empty) gives every cancel attempt its own real chance to
    // load reasons, instead of depending entirely on whether the one
    // startup attempt happened to succeed.
    if (_controller.cancleReasonModelList.isEmpty) {
      _fetchReasons();
    }
  }

  Future<void> _fetchReasons() async {
    setState(() {
      _isLoadingReasons = true;
      _loadFailed = false;
    });
    try {
      await _controller.cancleRideReason();
    } catch (_) {
      // handled via _loadFailed below
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReasons = false;
          _loadFailed = _controller.cancleReasonModelList.isEmpty;
        });
      }
    }
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

          if (reasons.isEmpty && _loadFailed)
            Column(
              children: [
                Text(
                  "Couldn't load cancellation reasons.",
                  style: TextStyle(fontSize: 14, color: Colors.red.shade600),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isLoadingReasons ? null : _fetchReasons,
                  child: _isLoadingReasons
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Retry"),
                ),
              ],
            )
          else if (reasons.isEmpty)
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
                      // No toast — post-accept ride flow is toast-free by
                      // design; tapping Confirm simply does nothing until
                      // a reason is actually selected.
                      if (selectedIndex == -1 || cancleId.isEmpty) {
                        return;
                      }

                      if (widget.bookingId == null || widget.bookingId!.isEmpty) {
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
