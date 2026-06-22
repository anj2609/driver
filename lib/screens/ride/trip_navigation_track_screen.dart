// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:myridedriverapp/config/route.dart';
// import 'package:myridedriverapp/config/utils/style.dart';
// import 'package:myridedriverapp/controllers/otp_controller.dart';

// class TripNavigationTrackScreen extends StatefulWidget {
//   const TripNavigationTrackScreen({super.key});

//   @override
//   State<TripNavigationTrackScreen> createState() =>
//       _TripNavigationTrackScreenState();
// }

// class _TripNavigationTrackScreenState extends State<TripNavigationTrackScreen> {
//   GoogleMapController? _mapController;
//   StreamSubscription<Position>? _positionStream;
//   final otpController = Get.put(OtpController());
//   final List<TextEditingController> _otpControllers = List.generate(
//     4,
//     (index) => TextEditingController(),
//   );
//   bool showOtp = false;

//   final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

//   LatLng _driverLatLng = const LatLng(28.6139, 77.2090);
//   final LatLng _pickupLatLng = const LatLng(28.6200, 77.2100);

//   Set<Marker> _markers = {};
//   Set<Polyline> _polylines = {};

//   double _speed = 23;

//   @override
//   void initState() {
//     super.initState();
//     _initLocation();
    
//   }

//   Future<void> _initLocation() async {
//     await Geolocator.requestPermission();

//     _positionStream =
//         Geolocator.getPositionStream(
//           locationSettings: const LocationSettings(
//             accuracy: LocationAccuracy.high,
//             distanceFilter: 5,
//           ),
//         ).listen((Position position) {
//           _driverLatLng = LatLng(position.latitude, position.longitude);

//           _speed = position.speed * 2.23694;

//           _updateMap();
//         });
//   }

//   void _updateMap() {
//     setState(() {
//       _markers = {
//         Marker(
//           markerId: const MarkerId("driver"),
//           position: _driverLatLng,
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueAzure,
//           ),
//         ),
//         Marker(markerId: const MarkerId("pickup"), position: _pickupLatLng),
//       };

//       _polylines = {
//         Polyline(
//           polylineId: const PolylineId("route"),
//           points: [_driverLatLng, _pickupLatLng],
//           width: 5,
//           color: Colors.blue,
//         ),
//       };

//       _mapController?.animateCamera(CameraUpdate.newLatLng(_driverLatLng));
//     });
//   }

//   @override
//   void dispose() {
//     _positionStream?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           /// MAP
//           GoogleMap(
//             initialCameraPosition: CameraPosition(
//               target: _driverLatLng,
//               zoom: 15,
//             ),
//             myLocationEnabled: true,
//             myLocationButtonEnabled: false,
//             markers: _markers,
//             polylines: _polylines,
//             onMapCreated: (controller) => _mapController = controller,
//           ),

//           /// TOP NAV CARD
//           Positioned(
//             top: 55,
//             left: 16,
//             right: 16,
//             child: Container(
//               padding: const EdgeInsets.all(18),
//               decoration: BoxDecoration(
//                 color: const Color(0xff0C3B2E),
//                 borderRadius: BorderRadius.circular(22),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: const [
//                   Row(
//                     children: [
//                       Icon(Icons.arrow_upward, color: Colors.white),
//                       SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           "Kishori Mohon School",
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Text("150 ft.", style: TextStyle(color: Colors.white)),
//                     ],
//                   ),

//                   SizedBox(height: 4),

//                   Text(
//                     "toward Nayasharak rd",
//                     style: TextStyle(color: Colors.white70),
//                   ),

//                   Divider(color: Colors.white30),

//                   Row(
//                     children: [
//                       Icon(Icons.location_on, size: 16, color: Colors.white),
//                       SizedBox(width: 6),
//                       Text(
//                         "Pickup at Gate No.3 Point",
//                         style: TextStyle(color: Colors.white),
//                       ),
//                     ],
//                   ),

//                   SizedBox(height: 4),

//                   Text(
//                     "1 mins (400 meters) away",
//                     style: TextStyle(color: Colors.white70),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           /// SPEED BADGE
//           Positioned(
//             bottom: 370,
//             left: MediaQuery.of(context).size.width / 2 - 55,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
//               decoration: BoxDecoration(
//                 color: const Color(0xff2BA4D8),
//                 borderRadius: BorderRadius.circular(40),
//               ),
//               child: Text(
//                 "${_speed.toStringAsFixed(0)} mph",
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ),

//           /// RIGHT BUTTONS
//           Positioned(
//             right: 15,
//             bottom: 380,
//             child: Column(
//               children: [
//                 _circleBtn(Icons.flag),
//                 const SizedBox(height: 12),
//                 _circleBtn(Icons.explore),
//               ],
//             ),
//           ),

//           /// BOTTOM SHEET
//           Positioned(
//             bottom: 30,
//             left: 0,
//             right: 0,
//             child:
//              Container(
//               padding: const EdgeInsets.all(18),
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//               ),
//               child: 
            
            
            
//               Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Center(
//                     child: Container(
//                       height: 4,
//                       width: 60,
//                       decoration: BoxDecoration(
//                         color: Colors.grey[300],
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 15),

//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: const [
//                       Text(
//                         "Going For Picking Up",
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Icon(Icons.more_vert),
//                     ],
//                   ),

//                   const SizedBox(height: 6),

//                   Row(
//                     children: [
//                       const Text("Estimated time of Arrival: "),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 8,
//                           vertical: 4,
//                         ),
//                         decoration: BoxDecoration(
//                           color: const Color(0xffF2F2F2),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: const Row(
//                           children: [
//                             Icon(Icons.access_time, size: 14),
//                             SizedBox(width: 4),
//                             Text("3:58"),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),

//                   const SizedBox(height: 15),

//                   /// DRIVER CARD
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: const Color(0xffD7F0FF),
//                       borderRadius: BorderRadius.circular(15),
//                     ),
//                     child: Row(
//                       children: [
//                         const CircleAvatar(
//                           radius: 22,
//                           backgroundImage: NetworkImage(
//                             "https://i.pravatar.cc/150?img=3",
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         const Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 "Vijay Gosh",
//                                 style: TextStyle(fontWeight: FontWeight.bold),
//                               ),
//                               SizedBox(height: 4),
//                               Row(
//                                 children: [
//                                   Icon(
//                                     Icons.star,
//                                     size: 16,
//                                     color: Colors.orange,
//                                   ),
//                                   SizedBox(width: 4),
//                                   Text("4.89"),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                         InkWell(
//                           onTap: () {
//                             Get.toNamed(RouteHelper.getchatDriverChatScreen());
//                           },
//                           child: _smallCircle(Icons.chat_bubble_outline),
//                         ),
//                         const SizedBox(width: 8),
//                         _smallCircle(Icons.call),
//                       ],
//                     ),
//                   ),

//                   const SizedBox(height: 18),

//                   /// 🔐 OTP SECTION
//                   const Text(
//                     "Enter 4 Digit OTP",
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                   ),

//                   const SizedBox(height: 15),

//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: List.generate(4, (index) {
//                       return SizedBox(
//                         width: 75,
//                         height: 75,
//                         child: TextField(
//                           controller: _otpControllers[index],
//                           focusNode: _focusNodes[index],
//                           keyboardType: TextInputType.number,
//                           textAlign: TextAlign.center,
//                           maxLength: 1,
//                           style: const TextStyle(
//                             fontSize: 22,
//                             fontWeight: FontWeight.bold,
//                           ),
//                           decoration: InputDecoration(
//                             counterText: "",
//                             filled: true,
//                             fillColor: const Color(0xffF5F5F5),
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               borderSide: BorderSide.none,
//                             ),
//                           ),
//                           onChanged: (value) {
//                             if (value.isNotEmpty) {
//                               if (index < 3) {
//                                 FocusScope.of(
//                                   context,
//                                 ).requestFocus(_focusNodes[index + 1]);
//                               } else {
//                                 FocusScope.of(context).unfocus();

//                                 // ✅ All OTP digits entered
//                                 String otp = _otpControllers
//                                     .map((controller) => controller.text)
//                                     .join();

//                                 if (otp.length == 4) {
//                                   // 🔥 Navigate here
//                                   Get.toNamed(
//                                     RouteHelper.getstartDriverRideScreen(),
//                                   );
//                                 }
//                               }
//                             } else {
//                               if (index > 0) {
//                                 FocusScope.of(
//                                   context,
//                                 ).requestFocus(_focusNodes[index - 1]);
//                               }
//                             }
//                           },
//                         ),
//                       );
//                     }),
//                   ),
//                   const SizedBox(height: 15),

//                 ],
//               ),
          
          
          
//             ),
         
         
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _circleBtn(IconData icon) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         shape: BoxShape.circle,
//         boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
//       ),
//       child: Icon(icon),
//     );
//   }

//   Widget _smallCircle(IconData icon) {
//     return Container(
//       padding: const EdgeInsets.all(10),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         shape: BoxShape.circle,
//       ),
//       child: Icon(icon, size: 18),
//     );
//   }

//   Widget _infoTile(IconData icon, String title, String sub) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: const Color(0xffF7F7F7),
//         borderRadius: BorderRadius.circular(15),
//       ),
//       child: Row(
//         children: [
//           Icon(icon),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                    style: PoppinsBold.copyWith(
//                                 // color: ColorResources.blackcolor,
//                               ),
//                  // style: const TextStyle(fontWeight: FontWeight.w600),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(sub, style: const TextStyle(color: Colors.grey)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
