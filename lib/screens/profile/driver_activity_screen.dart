import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/model/driver_activity_model.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

/// Driver-side mirror of the rider app's Activity screen (see
/// rideruserlestes/lib/app/modules/activity/activity.dart) — same four tabs,
/// same status-slug-per-tap pattern, same "always refetch on tab switch"
/// behaviour. Reachable from the drawer's "Activities" item.
class DriverActivityScreen extends StatefulWidget {
  const DriverActivityScreen({super.key});

  @override
  State<DriverActivityScreen> createState() => _DriverActivityScreenState();
}

class _DriverActivityScreenState extends State<DriverActivityScreen> {
  int selectedTab = 0;

  final List<String> tabs = ["Ongoing", "Scheduled", "Completed", "Canceled"];

  // Kept in the exact same vocabulary track-ride/track-booking-ride already
  // use elsewhere in this app (pending/accepted/arrived/ongoing/completed/
  // cancelled/scheduled) rather than inventing a different one here.
  static const List<String> _slugs = [
    "ongoing",
    "scheduled",
    "completed",
    "cancelled",
  ];

  @override
  void initState() {
    super.initState();

    // getDriverActivityData's first line is isDriverActivityLoading = true;
    // update() — and update() synchronously tries to rebuild the
    // GetBuilder<ProfileController> below. Called straight from initState
    // (i.e. during this screen's very first build), that update() lands
    // while the framework is still building this exact widget tree, which
    // Flutter refuses ("setState() or markNeedsBuild() called during
    // build") and throws as an uncaught zone error. Because that throw
    // happens before try/finally even starts, the API call never fires and
    // isDriverActivityLoading never gets reset to false — the Ongoing tab
    // (the only one ever loaded from initState; every other tab only ever
    // runs via _selectTab, well after the first frame) was stuck on the
    // spinner forever until a tab switch (running after the first build)
    // triggered a call that could complete normally. Deferring to a
    // microtask — the same fix already used by TripDetailsScreen's
    // initState in mainactivity_detail_screen.dart — runs this after the
    // first frame instead of during it.
    Future.microtask(() {
      Get.find<ProfileController>().getDriverActivityData(
        context: context,
        statusSlug: _slugs[selectedTab],
      );
    });
  }

  void _selectTab(int index) {
    setState(() => selectedTab = index);
    Get.find<ProfileController>().getDriverActivityData(
      context: context,
      statusSlug: _slugs[index],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorResources.whiteColor,
      appBar: AppBar(
        backgroundColor: ColorResources.whiteColor,
        elevation: 0,
        centerTitle: true,
        leading: InkWell(
          onTap: () => Get.back(),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text(
          "Activities",
          style: PoppinsSemiBold.copyWith(
            fontSize: 16,
            color: ColorResources.blackcolor,
          ),
        ),
      ),
      // Without this the tab row and the ride list's bottom padding both sat
      // right up against y=screen-height, so on a gesture-nav phone (no
      // physical/3-button bar reserving space) the last card and its "view
      // details" tap target ended up under the gesture bar. SafeArea insets
      // the whole body by the system bar/gesture-area padding on every side.
      body: SafeArea(
        child: Column(
        children: [
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final isSelected = selectedTab == index;
                return GestureDetector(
                  onTap: () => _selectTab(index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ColorResources.appColor
                          : ColorResources.whiteColor,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: ColorResources.textColorForGrey),
                    ),
                    child: Text(
                      tabs[index],
                      style: PoppinsReguler.copyWith(
                        color: isSelected
                            ? ColorResources.whiteColor
                            : ColorResources.blackcolor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GetBuilder<ProfileController>(
              builder: (controller) {
                if (controller.isDriverActivityLoading) {
                  return const Center(child: PremiumBlurLoader());
                }

                if (controller.driverActivityList.isEmpty) {
                  return Center(
                    child: Text(
                      "No ${tabs[selectedTab]} Rides",
                      style: PoppinsSemiBold.copyWith(
                        color: ColorResources.blackcolor,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  // Extra bottom padding beyond SafeArea's inset so the last
                  // card clears the gesture bar with breathing room instead
                  // of sitting flush against it.
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: controller.driverActivityList.length,
                  itemBuilder: (context, index) {
                    final item = controller.driverActivityList[index];
                    return _ActivityCard(item: item);
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item});

  final DriverActivityItem item;

  Color _statusColor() {
    switch (item.status?.toLowerCase()) {
      case 'completed':
        return ColorResources.greencolor;
      case 'cancelled':
      case 'canceled':
        return ColorResources.textColorRed;
      case 'scheduled':
        return ColorResources.orangecoor;
      default:
        return ColorResources.appColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (item.id == null) return;
        Get.toNamed(
          RouteHelper.getmainActivityTripDetailsScreen(),
          arguments: {"bookingid": item.id},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ColorResources.whiteColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ColorResources.greycolorborder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    "₹${item.displayFare.toStringAsFixed(2)}",
                    style: PoppinsSemiBold.copyWith(
                      fontSize: 17,
                      color: ColorResources.blackcolor,
                    ),
                  ),
                ),
                Text(
                  item.createdAt ?? "",
                  style: PoppinsReguler.copyWith(
                    fontSize: 12,
                    color: ColorResources.textColorForGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (item.status ?? '').isEmpty
                    ? '-'
                    : item.status![0].toUpperCase() +
                        item.status!.substring(1),
                style: PoppinsMedium.copyWith(color: _statusColor(), fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            if ((item.pickupAddress ?? '').isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.circle, size: 10, color: Color(0xff00AEEF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.pickupAddress!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PoppinsMedium.copyWith(
                        color: ColorResources.blackcolor,
                      ),
                    ),
                  ),
                ],
              ),
            if ((item.dropAddress ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: Color(0xff00AEEF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.dropAddress!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PoppinsMedium.copyWith(
                        color: ColorResources.blackcolor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
