import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/week_erning_controller.dart';
import 'package:myridedriverapp/model/weekerning_model.dart';

class WeeklyEarningScreen extends StatelessWidget {
  WeeklyEarningScreen({super.key});

  final controller = Get.put(WeeklyEarningController());

  final List<String> weekDays = ["M", "T", "W", "T", "F", "S", "S"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorResources.buttoncolor,
      appBar: AppBar(
        backgroundColor: ColorResources.whiteColor,
        elevation: 0,
        leading: CircleAvatar(
          backgroundColor: ColorResources.buttoncolor,

          child: InkWell(
            onTap: () {
              Get.back();
            },
            child: Icon(Icons.arrow_back, color: ColorResources.blackcolor),
          ),
        ),
        centerTitle: true,
        title: Text(
          "Select Week",
          style: PoppinsBold.copyWith(color: ColorResources.appColor),
          
        ),
      ),
      body: Column(
        children: [
          /// HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[300],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Weekly Earnings",
                  style: PoppinsSemiBold.copyWith(
                    color: ColorResources.appColor,
                  ),
                ),
                Row(
                  children: weekDays
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            e,
                            style: PoppinsReguler.copyWith(
                              color: ColorResources.appColor,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),

          /// LIST
          Expanded(
            child: Obx(
              () => ListView.builder(
                itemCount: controller.weekList.length,
                itemBuilder: (context, index) {
                  final data = controller.weekList[index];
                  return weekItem(data);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 WEEK ITEM
  Widget weekItem(WeekEarningModel data) {
    double maxValue = data.dailyEarning.reduce((a, b) => a > b ? a : b);

    return Container(
      padding:  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration:  BoxDecoration(
        color: ColorResources.whiteColor,
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        children: [
          /// LEFT
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: PoppinsBold.copyWith(
                    color: ColorResources.textColorBaclColor,
                  ),
                  // style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  "₹${data.totalAmount.toStringAsFixed(2)}",
                  style: PoppinsBold.copyWith(color: ColorResources.appColor),
                  // style: const TextStyle(
                  //   fontSize: 18,
                  //   fontWeight: FontWeight.bold,
                  // ),
                ),
              ],
            ),
          ),

          /// RIGHT
          Expanded(
            flex: 3,
            child: Column(
              children: [
                /// CHART
                SizedBox(
                  height: 50,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceBetween,
                      maxY: maxValue + 50,
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(show: false),
                      gridData: FlGridData(show: false),
                      barGroups: List.generate(7, (index) {
                        final value = data.dailyEarning[index];

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: value,
                              width: 6,
                              borderRadius: BorderRadius.circular(4),
                              color: value == 0
                                  ? Colors.grey.shade300
                                  : value == maxValue
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                /// DATES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    7,
                    (index) => Text(
                      data.dates[index].toString(),
                      style: PoppinsBold.copyWith(
                        color: data.dailyEarning[index] == 0
                            ? ColorResources.textColorBaclColor
                            : ColorResources.whiteColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
