// import 'package:get/get.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/material.dart';

// class EarningsController extends GetxController {

//   var selectedFilter = "Weekly".obs;
//   var selectedRange = "22 June - 28 June".obs;

//   var totalEarnings = 850.0.obs;
//   var netFare = 800.0.obs;
//   var tip = 50.0.obs;
//   var increasePercent = 54.obs;

//   var onlineTime = "167 h 34 m".obs;
//   var distance = "121 miles".obs;
//   var tripsTotal = "137".obs;

//   /// Weekly & Monthly Dummy Data
//   final Map<String, Map<String, List<double>>> data = {
//     "Weekly": {
//       "22 June - 28 June": [150, 120, 180, 140],
//       "29 June - 5 July": [200, 160, 190, 210],
//     },
//     "Monthly": {
//       "June": [500, 650, 700, 600],
//       "July": [800, 720, 760, 900],
//     },
//   };

//   /// 🔹 Dynamic ranges according to filter
//   List<String> get ranges =>
//       data[selectedFilter.value]!.keys.toList();

//   /// 🔹 Current selected data
//   List<double> get currentData =>
//       data[selectedFilter.value]![selectedRange.value]!;

//   /// 🔹 Dynamic Bar Groups
//   List<BarChartGroupData> get barGroups =>
//       List.generate(currentData.length, (index) {
//         return BarChartGroupData(
//           x: index,
//           barRods: [
//             BarChartRodData(
//               toY: currentData[index],
//               width: 16,
//               borderRadius: BorderRadius.circular(6),
//               color: Colors.green,
//             ),
//           ],
//         );
//       });

//   @override
//   void onInit() {
//     super.onInit();
//     calculateTotal();
//   }

//   /// 🔹 Filter Change
//   void changeFilter(String filter) {
//     selectedFilter.value = filter;

//     // 👇 Automatically first range select karega
//     selectedRange.value = data[filter]!.keys.first;

//     calculateTotal();
//   }

//   /// 🔹 Range Change
//   void changeRange(String range) {
//     selectedRange.value = range;
//     calculateTotal();
//   }

//   /// 🔹 Total Calculation
//   void calculateTotal() {
//     totalEarnings.value =
//         currentData.fold(0.0, (sum, item) => sum + item);

//     tip.value = 50;
//     netFare.value = totalEarnings.value - tip.value;
//   }
// }