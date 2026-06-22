// import 'package:flutter/material.dart';

// class RidesScreen extends StatelessWidget {
//   const RidesScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final width = size.width;
//     final height = size.height;

//     return Scaffold(
//       backgroundColor: const Color(0xffF5F5F5),

//       /// 🔹 AppBar
//       appBar: AppBar(
//         backgroundColor: const Color(0xffF5F5F5),
//         elevation: 0,
//         centerTitle: true,
//         title: Text(
//           "Rides",
//           style: TextStyle(
//             color: Colors.black,
//             fontSize: width * 0.05,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         leading: Padding(
//           padding: EdgeInsets.all(width * 0.02),
//           child: Container(
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               shape: BoxShape.circle,
//             ),
//             child: IconButton(
//               icon: const Icon(Icons.arrow_back, color: Colors.black),
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//             ),
//           ),
//         ),
//       ),

//       /// 🔹 Body
//       body: Column(
//         children: [
//           SizedBox(height: height * 0.02),

//           /// 🔹 Car Image
//           Image.asset("assets/images/ridecar.png", height: height * 0.18),

//           SizedBox(height: height * 0.02),

//           /// 🔹 Description
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: width * 0.08),
//             child: Text(
//               "Paying attention to these stats helps you earn\nwith Uber and be eligible for rewards.",
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: width * 0.035,
//                 color: Colors.grey[600],
//               ),
//             ),
//           ),

//           SizedBox(height: height * 0.03),

//           /// 🔹 Stats Grid
//           Expanded(
//             child: Padding(
//               padding: EdgeInsets.symmetric(horizontal: width * 0.05),
//               child: GridView.count(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: width * 0.04,
//                 mainAxisSpacing: height * 0.02,
//                 childAspectRatio: 1.2,
//                 physics: const NeverScrollableScrollPhysics(),
//                 children: const [
//                   StatsCard(
//                     title: "73%",
//                     subtitle: "Acceptance Rate",
//                     badgeText: "My Ride Pro",
//                     badgeColor: Colors.red,
//                     icon: Icons.warning_amber_rounded,
//                   ),
//                   StatsCard(
//                     title: "4.89",
//                     subtitle: "Acceptance Rate",
//                     badgeText: "My Ride Pro",
//                     badgeColor: Colors.blue,
//                     icon: Icons.star,
//                   ),
//                   StatsCard(
//                     title: "1%",
//                     subtitle: "Cancellation rate",
//                     badgeText: "My Ride Pro",
//                     badgeColor: Colors.blue,
//                     icon: Icons.check_circle,
//                   ),
//                   StatsCard(title: "98", subtitle: "Driving Score"),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class StatsCard extends StatelessWidget {
//   final String title;
//   final String subtitle;
//   final String? badgeText;
//   final Color? badgeColor;
//   final IconData? icon;

//   const StatsCard({
//     super.key,
//     required this.title,
//     required this.subtitle,
//     this.badgeText,
//     this.badgeColor,
//     this.icon,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;

//     return Container(
//       padding: EdgeInsets.all(width * 0.04),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Text(
//                 title,
//                 style: TextStyle(
//                   fontSize: width * 0.06,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               if (icon != null) ...[
//                 SizedBox(width: width * 0.01),
//                 Icon(icon, size: width * 0.05, color: badgeColor),
//               ],
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(
//             subtitle,
//             style: TextStyle(fontSize: width * 0.035, color: Colors.grey[600]),
//           ),
//           const Spacer(),
//           if (badgeText != null)
//             Container(
//               padding: EdgeInsets.symmetric(
//                 horizontal: width * 0.03,
//                 vertical: width * 0.015,
//               ),
//               decoration: BoxDecoration(
//                 color: badgeColor!.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(icon, size: width * 0.035, color: badgeColor),
//                   SizedBox(width: width * 0.01),
//                   Text(
//                     badgeText!,
//                     style: TextStyle(
//                       fontSize: width * 0.03,
//                       color: badgeColor,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
