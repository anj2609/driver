// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:myridedriverapp/controllers/insurance_controller.dart';


// class InsuranceScreen extends StatelessWidget {
//   InsuranceScreen({super.key});

//   final controller = Get.put(InsuranceController());

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final width = size.width;
//     final height = size.height;

//     return Scaffold(
//       backgroundColor: const Color(0xffF2F2F2),
//       body: SafeArea(
//         child: Column(
//           children: [

//             /// 🔵 HEADER
//             Container(
//               width: double.infinity,
//               padding: EdgeInsets.symmetric(
//                 horizontal: width * 0.04,
//                 vertical: height * 0.02,
//               ),
//               decoration: const BoxDecoration(
//                 color: Color(0xff2EA3C6),
//                 borderRadius: BorderRadius.only(
//                   bottomLeft: Radius.circular(18),
//                   bottomRight: Radius.circular(18),
//                 ),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [

//                   /// Back
//                   GestureDetector(
//                     onTap: () => Get.back(),
//                     child: Container(
//                       height: 42,
//                       width: 42,
//                       decoration: const BoxDecoration(
//                         color: Colors.white,
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(Icons.arrow_back),
//                     ),
//                   ),

//                   const Text(
//                     "Insurance",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),

//                   /// Help
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 12, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: const Row(
//                       children: [
//                         Text("Help",
//                             style: TextStyle(fontWeight: FontWeight.w500)),
//                         SizedBox(width: 4),
//                         Icon(Icons.keyboard_arrow_down, size: 18),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             SizedBox(height: height * 0.02),

//             /// BODY
//             Expanded(
//               child: Padding(
//                 padding: EdgeInsets.symmetric(horizontal: width * 0.05),
//                 child: Column(
//                   children: [

//                     /// Rides
//                     Obx(() => _expandableTile(
//                           title: "Rides",
//                           isExpanded: controller.ridesExpanded.value,
//                           onTap: controller.toggleRides,
//                         )),

//                     /// Additional Opportunities
//                     Obx(() => _expandableTile(
//                           title: "Additional Opportunities",
//                           isExpanded: controller.additionalExpanded.value,
//                           onTap: controller.toggleAdditional,
//                         )),

//                     /// Vehicle
//                     Obx(() => _vehicleSection(
//                           controller,
//                           width,
//                           height,
//                         )),

//                     const Spacer(),

//                     /// Bottom Button
//                     Container(
//                       width: double.infinity,
//                       height: 55,
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(30),
//                       ),
//                       alignment: Alignment.center,
//                       child: const Text(
//                         "Manage Vehicle",
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),

//                     SizedBox(height: height * 0.02),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   /// Expandable Tile
//   Widget _expandableTile({
//     required String title,
//     required bool isExpanded,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 18),
//         decoration: const BoxDecoration(
//           border: Border(
//             bottom: BorderSide(color: Colors.grey),
//           ),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(title,
//                 style: const TextStyle(
//                     fontSize: 16, fontWeight: FontWeight.w600)),
//             Icon(isExpanded ? Icons.remove : Icons.add),
//           ],
//         ),
//       ),
//     );
//   }

//   /// Vehicle Section
//   Widget _vehicleSection(
//       InsuranceController controller, double width, double height) {
//     return Column(
//       children: [

//         GestureDetector(
//           onTap: controller.toggleVehicle,
//           child: Container(
//             padding: const EdgeInsets.symmetric(vertical: 18),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text("Vehicle",
//                     style:
//                         TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//                 Container(
//                   height: 34,
//                   width: 34,
//                   decoration: const BoxDecoration(
//                     color: Color(0xffE5E5E5),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(
//                     controller.vehicleExpanded.value
//                         ? Icons.remove
//                         : Icons.add,
//                     size: 18,
//                   ),
//                 )
//               ],
//             ),
//           ),
//         ),

//         if (controller.vehicleExpanded.value) ...[
//           _vehicleItem("Vehicle Insurance"),
//           _vehicleItem("Vehicle Registration"),
//           _vehicleItem("Vehicle Inspection"),
//         ]
//       ],
//     );
//   }

//   Widget _vehicleItem(String title) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 14),
//       decoration: const BoxDecoration(
//         border: Border(
//           top: BorderSide(color: Color(0xffDDDDDD)),
//         ),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(title,
//                     style: const TextStyle(
//                         fontWeight: FontWeight.w500, fontSize: 15)),
//                 const SizedBox(height: 4),
//                 const Text(
//                   "Completed",
//                   style: TextStyle(
//                     color: Colors.blue,
//                     fontSize: 13,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const Icon(Icons.chevron_right)
//         ],
//       ),
//     );
//   }
// }