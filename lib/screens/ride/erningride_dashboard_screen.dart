import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/dimensions.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

class EarningsScreen extends StatefulWidget {
  EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  //// final controller = Get.put(EarningsController());
  @override
  void initState() {
    super.initState();
    earningActiveData();
  }

  void earningActiveData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<ProfileController>().driverEarningHistory(
        context: context,
        type: 'weekly',
        startDate: '',
        endDate: '',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    Get.back();
                  },

                  child: Icon(Icons.close, color: Colors.black),
                ),

                const Icon(Icons.help_outline, color: Colors.black),
              ],
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 10),
              GetBuilder<ProfileController>(
                builder: (controller) {
                  if (controller.isEarningLoading == true) {
                    return Center(child: PremiumBlurLoader());
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Dimensions.smallSize,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: ColorResources.greycolorborder,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,

                            ///Colors.white,
                          ),

                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: controller.selectedType,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: "weekly",
                                  child: Text("Weekly"),
                                ),

                                DropdownMenuItem(
                                  value: "monthly",
                                  child: Text("Monthly"),
                                ),

                                DropdownMenuItem(
                                  value: "custom_date",
                                  child: Text("Custom Date"),
                                ),
                              ],
                              onChanged: (value) {
                                controller.selectedType = value!;

                                if (value != "custom_date") {
                                  controller.driverEarningHistory(
                                    context: context,
                                    type: value,
                                    startDate: '',
                                    //  controller
                                    //     .startDateController
                                    //     .text
                                    //     .trim(),
                                    endDate: '',
                                    // controller.endDateController.text
                                    //     .trim(),
                                  );
                                }

                                controller.update();
                              },
                            ),
                          ),
                        ),

                        SizedBox(height: 16),

                        if (controller.selectedType == "custom_date")
                          Column(
                            children: [
                              TextFormField(
                                controller: controller.startDateController,
                                readOnly: true,
                                onTap: () {
                                  controller.pickStartDate(context);
                                },
                                decoration: InputDecoration(
                                  labelText: "Start Date",
                                  suffixIcon: Icon(Icons.calendar_month),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),

                              SizedBox(height: 15),

                              TextFormField(
                                controller: controller.endDateController,
                                readOnly: true,
                                onTap: () {
                                  controller.pickEndDate(context);
                                },
                                decoration: InputDecoration(
                                  labelText: "End Date",
                                  suffixIcon: Icon(Icons.calendar_month),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),

                              SizedBox(height: 20),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: CustomButton(
                                  text: 'Apply Filter',
                                  onPressed: () async {
                                    try {
                                       showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) =>  PremiumBlurLoader(),
                            );

                                      await controller.driverEarningHistory(
                                        context: context,
                                        type: "custom_date",
                                        startDate:
                                            controller.startDateController.text,
                                        endDate:
                                            controller.endDateController.text,
                                      );
                                    } catch (e) {
                                      debugPrint(
                                        'driverEarningHistory Error: $e',
                                      );
                                    } finally {
                                      if (Get.isDialogOpen ?? false) {
                                        Get.back();
                                      }
                                    }
                                    // controller.driverEarningHistory(
                                    //   context: context,
                                    //   type: "custom_date",
                                    //   startDate:
                                    //       controller.startDateController.text,
                                    //   endDate:
                                    //       controller.endDateController.text,
                                    // );
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),

              SizedBox(height: 16),

              /// Total Earnings Card
              ///
              GetBuilder<ProfileController>(
                builder: (controller) {
                  if (controller.isEarningLoading == true) {
                    return Center(child: SizedBox());
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Column(
                      children: [
                        /// TOTAL EARNINGS
                        Text(
                          "₹${controller.totalEarnings.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// BAR CHART
                        SizedBox(
                          height: 160,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,

                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                              ),

                              borderData: FlBorderData(show: false),

                              titlesData: FlTitlesData(
                                /// Left Side Values (Amount)
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval:
                                        100, // adjust according to your data
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: TextStyle(fontSize: 11),
                                      );
                                    },
                                  ),
                                ),

                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),

                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),

                                /// Bottom Labels (Months/Days)
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 35,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() >=
                                          (controller
                                                  .earningModel
                                                  ?.data
                                                  ?.labels
                                                  ?.length ??
                                              0)) {
                                        return const SizedBox();
                                      }

                                      String label =
                                          controller
                                              .earningModel
                                              ?.data
                                              ?.labels?[value.toInt()] ??
                                          '';

                                      return SideTitleWidget(
                                        meta: meta,
                                        child: Text(
                                          label,
                                          style: TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              barGroups: controller.barGroups,

                              // maxY:
                              //     controller.barGroups
                              //         .map((e) => e.barRods.first.toY)
                              //         .reduce((a, b) => a > b ? a : b) +
                              //     50,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Container(
              //   margin: const EdgeInsets.symmetric(horizontal: 16),
              //   padding: const EdgeInsets.all(12),
              //   decoration: BoxDecoration(
              //     color: Colors.green.shade50,
              //     borderRadius: BorderRadius.circular(12),
              //   ),
              //   child: Row(
              //     children: [
              //       const Icon(Icons.arrow_upward, color: Colors.green),
              //       const SizedBox(width: 8),
              //       Expanded(
              //         child: Obx(
              //           () => Text(
              //             "Your Earnings increased ${controller.increasePercent.value}%",
              //             style: const TextStyle(fontSize: 12),
              //           ),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              const SizedBox(height: 12),

              /// Stats
              GetBuilder<ProfileController>(
                builder: (controller) {
                  if (controller.isEarningLoading ||
                      controller.earningModel?.data?.rideDetails == null) {
                    return Center(child: SizedBox());
                  }

                  final ride = controller.earningModel!.data!.rideDetails!;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        statColumn(
                          "DISTANCE",
                          (ride.totalDistance ?? 0).toString(),
                        ),

                        divider(),
                        InkWell(
                          onTap: () {
                            Get.toNamed(
                              RouteHelper.getWeaklyErningRideScreen(),
                            );
                          },
                          child: statColumn(
                            "TRIPS TOTAL",
                            (ride.totalTrip ?? 0).toString(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              /// Breakdown
              GetBuilder<ProfileController>(
                builder: (controller) {
                  if (controller.isEarningLoading ||
                      controller.earningModel?.data?.rideDetails == null) {
                    return Center(child: SizedBox());
                  }

                  final ride = controller.earningModel!.data!.rideDetails!;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        row("Net Fare", (ride.netFare ?? 0).toDouble()),

                        row("Tip", (ride.tipAmount ?? 0).toDouble()),

                        const Divider(),

                        row(
                          "Total Earnings",
                          (ride.totalEarning ?? 0).toDouble(),
                          isBold: true,
                        ),

                        // const SizedBox(height: 20),

                        // ErningButions(
                        //   text: "See Customer Fare Breakdown",
                        //   colors: ColorResources.buttoncolor,
                        //   textColor: ColorResources.appColor,
                        //   onTap: () {
                        //     Get.toNamed(
                        //       RouteHelper.getCustomerFareBrarekdownScreen(),
                        //     );
                        //   },
                        //   valuess: false,
                        // ),
                        const SizedBox(height: 15),
                        ErningButions(
                          text: "See Earnings Activity",
                          colors: ColorResources.appColor,
                          textColor: ColorResources.whiteColor,
                          onTap: () {
                            Get.toNamed(
                              RouteHelper.geterningMainactivityScreen(),
                            );
                          },
                          valuess: true,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget divider() {
    return Container(height: 40, width: 1, color: Colors.grey.shade300);
  }

  Widget statColumn(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget row(String title, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "₹${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
