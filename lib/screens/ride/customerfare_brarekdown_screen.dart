// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:myridedriverapp/controllers/customer_controller.dart';
// import 'package:myridedriverapp/widgets/custom_button.dart';

// class CustomerFareScreen extends StatelessWidget {
//   CustomerFareScreen({super.key});

//  ///final controller = Get.put(CustomerFareController());

//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;

//     return Scaffold(
//       backgroundColor: Colors.grey.shade100,
//       body: SafeArea(
//         child: Obx(
//           () => SingleChildScrollView(
//             padding: EdgeInsets.symmetric(horizontal: width * 0.05),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SizedBox(height: height * 0.02),

//                 /// Back + Title
//                 Row(
//                   children: [
//                     CircleAvatar(
//                       backgroundColor: Colors.white,
//                       child: Icon(Icons.arrow_back, color: Colors.black),
//                     ),
//                     SizedBox(width: width * 0.04),
//                     Text(
//                       "Customer Fare Breakdown",
//                       style: TextStyle(
//                         fontSize: width * 0.05,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),

//                 SizedBox(height: height * 0.02),

//                 Text(
//                   controller.weekRange.value,
//                   style: TextStyle(
//                     fontSize: width * 0.035,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),

//                 SizedBox(height: height * 0.03),

//                 /// Car Image
//                 Center(
//                   child: Image.asset(
//                     "assets/images/ridecar.png",
//                     // "https://i.imgur.com/6GfgeBs.png",
//                     height: height * 0.18,
//                     fit: BoxFit.contain,
//                   ),
//                 ),

//                 SizedBox(height: height * 0.02),

//                 /// Total
//                 Center(
//                   child: Column(
//                     children: [
//                       Text(
//                         "Total : ₹${controller.totalAmount.value.toStringAsFixed(2)}",
//                         style: TextStyle(
//                           fontSize: width * 0.06,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       SizedBox(height: height * 0.01),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           _dot(Colors.blue),
//                           SizedBox(width: 5),
//                           Text("You : ${controller.youPercent}%"),
//                           SizedBox(width: 15),
//                           _dot(Colors.amber),
//                           SizedBox(width: 5),
//                           Text("My Ride App : ${controller.appPercent}%"),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),

//                 SizedBox(height: height * 0.03),

//                 /// Breakdown Card
//                 Container(
//                   padding: EdgeInsets.all(width * 0.04),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Column(
//                     children: [
//                       _fareRow(
//                         "Your Earnings",
//                         controller.earnings.value,
//                         "Includes tips of ₹${controller.tips}",
//                         Colors.blue,
//                       ),

//                       _divider(),

//                       _fareRow(
//                         "Government Tax",
//                         controller.governmentTax.value,
//                         "3.33%",
//                         Colors.purple,
//                       ),

//                       _divider(),

//                       _fareRow(
//                         "Operational Expenses, Insurance",
//                         controller.operationalExpenses.value,
//                         "3.33%",
//                         Colors.red,
//                       ),

//                       _divider(),

//                       _fareRow(
//                         "Customer Promotion",
//                         controller.customerPromotion.value,
//                         "3.33%",
//                         Colors.blueAccent,
//                       ),

//                       _divider(),

//                       _fareRow(
//                         "My Ride Service Fee",
//                         controller.serviceFee.value,
//                         "3.33%",
//                         Colors.amber,
//                       ),

//                       Divider(thickness: 1.5),

//                       _fareRow(
//                         "Total Customer Fare",
//                         controller.totalCustomerFare,
//                         "100.00%",
//                         Colors.black,
//                         isBold: true,
//                       ),
//                     ],
//                   ),
//                 ),

//                 SizedBox(height: height * 0.03),

//                 /// Bottom Tips Box
//                 Container(
//                   padding: EdgeInsets.all(width * 0.04),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.shade50,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(
//                         Icons.account_balance_wallet_outlined,
//                         color: Colors.blue,
//                       ),
//                       SizedBox(width: 10),
//                      //// CustomPrimaryButton(text: "You Made ₹50.00 with tips!", onTap: () {}),
//                       // Expanded(
//                       //   child: Text(
//                       //     "You Made ₹50.00 with tips!",
//                       //     style: TextStyle(
//                       //         fontWeight: FontWeight.w500),
//                       //   ),
//                       // )
//                     ],
//                   ),
//                 ),

//                 SizedBox(height: height * 0.05),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _fareRow(
//     String title,
//     double amount,
//     String subtitle,
//     Color color, {
//     bool isBold = false,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 10),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _dot(color),
//           SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: TextStyle(
//                     fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   subtitle,
//                   style: TextStyle(fontSize: 12, color: Colors.grey),
//                 ),
//               ],
//             ),
//           ),
//           Text(
//             "₹${amount.toStringAsFixed(2)}",
//             style: TextStyle(
//               fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _divider() {
//     return Divider(height: 20, thickness: 1);
//   }

//   Widget _dot(Color color) {
//     return Container(
//       width: 10,
//       height: 10,
//       decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//     );
//   }
// }
