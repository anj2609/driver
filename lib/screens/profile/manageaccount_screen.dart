// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:myridedriverapp/controllers/manageaccount_model.dart';

// class ManageAccountScreen extends StatelessWidget {
//   ManageAccountScreen({super.key});

//   final controller = Get.put(ManageAccountController());

//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;

//     return Scaffold(
//       backgroundColor: const Color(0xffF2F2F2),
//       body: SafeArea(
//         child: Column(
//           children: [
//             /// ================= HEADER =================
//             Container(
//               width: width,
//               padding: EdgeInsets.symmetric(
//                 horizontal: width * 0.04,
//                 vertical: height * 0.015,
//               ),
//               decoration: const BoxDecoration(
//                 color: Color(0xff2EA7D7),
//                 borderRadius: BorderRadius.only(
//                   bottomLeft: Radius.circular(25),
//                   bottomRight: Radius.circular(25),
//                 ),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   /// Back
//                   GestureDetector(
//                     onTap: () => Get.back(),
//                     child: Container(
//                       height: width * 0.10,
//                       width: width * 0.10,
//                       decoration: const BoxDecoration(
//                         color: Colors.white,
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(Icons.arrow_back),
//                     ),
//                   ),

//                   const Text(
//                     "Manage Account",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),

//                   Container(
//                     padding: EdgeInsets.symmetric(
//                       horizontal: width * 0.04,
//                       vertical: height * 0.01,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Row(
//                       children: const [
//                         Text("Help"),
//                         SizedBox(width: 5),
//                         Icon(Icons.keyboard_arrow_down, size: 18),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             SizedBox(height: height * 0.02),

//             Expanded(
//               child: SingleChildScrollView(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(horizontal: width * 0.05),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       /// ================= RIDES =================
//                       Obx(
//                         () => Column(
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 const Text(
//                                   "Rides",
//                                   style: TextStyle(
//                                     fontSize: 18,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 GestureDetector(
//                                   onTap: controller.toggleRides,
//                                   child: Container(
//                                     height: 30,
//                                     width: 30,
//                                     decoration: BoxDecoration(
//                                       color: Colors.grey.shade300,
//                                       shape: BoxShape.circle,
//                                     ),
//                                     child: Icon(
//                                       controller.isRidesExpanded.value
//                                           ? Icons.remove
//                                           : Icons.add,
//                                       size: 18,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),

//                             if (controller.isRidesExpanded.value) ...[
//                               SizedBox(height: height * 0.02),
//                               buildRideItem("Background Check"),
//                               buildRideItem("Driver", showArrow: true),
//                               buildRideItem(
//                                 "City Knowledge Survey",
//                                 showArrow: true,
//                               ),
//                               buildRideItem("Profile Photo"),
//                               buildRideItem("Terms & Condition"),
//                             ],
//                           ],
//                         ),
//                       ),

//                       SizedBox(height: height * 0.02),

//                       /// ================= ADDITIONAL =================
//                       Obx(
//                         () => buildExpandableTile(
//                           title: "Additional Opportunities",
//                           isExpanded: controller.isAdditionalExpanded.value,
//                           onTap: controller.toggleAdditional,
//                         ),
//                       ),

//                       SizedBox(height: height * 0.015),

//                       /// ================= VEHICLE =================
//                       Obx(
//                         () => buildExpandableTile(
//                           title: "Vehicle",
//                           isExpanded: controller.isVehicleExpanded.value,
//                           onTap: controller.toggleVehicle,
//                         ),
//                       ),

//                       SizedBox(height: height * 0.04),

//                       /// ================= BUTTON =================
//                       Center(
//                         child: Container(
//                           width: width * 0.8,
//                           padding: EdgeInsets.symmetric(
//                             vertical: height * 0.018,
//                           ),
//                           decoration: BoxDecoration(
//                             color: Colors.grey.shade300,
//                             borderRadius: BorderRadius.circular(30),
//                           ),
//                           alignment: Alignment.center,
//                           child: const Text(
//                             "Manage Vehicle",
//                             style: TextStyle(
//                               fontWeight: FontWeight.w600,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ),
//                       ),

//                       SizedBox(height: height * 0.03),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   /// ================= RIDE ITEM =================
//   Widget buildRideItem(String title, {bool showArrow = false}) {
//     return Column(
//       children: [
//         Row(
//           children: [
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     style: const TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(height: 3),
//                   const Text(
//                     "Completed",
//                     style: TextStyle(fontSize: 13, color: Color(0xff2EA7D7)),
//                   ),
//                 ],
//               ),
//             ),
//             if (showArrow)
//               const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
//           ],
//         ),
//         const Divider(height: 25),
//       ],
//     );
//   }

//   /// ================= EXPAND TILE =================
//   Widget buildExpandableTile({
//     required String title,
//     required bool isExpanded,
//     required VoidCallback onTap,
//   }) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade200,
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//           ),
//           GestureDetector(
//             onTap: onTap,
//             child: Icon(isExpanded ? Icons.remove : Icons.add),
//           ),
//         ],
//       ),
//     );
//   }
// }
