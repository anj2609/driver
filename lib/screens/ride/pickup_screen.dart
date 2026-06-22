// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:myridedriverapp/config/route.dart';
// import 'package:myridedriverapp/config/utils/colors.dart';
// import 'package:myridedriverapp/config/utils/constants.dart';
// import 'package:myridedriverapp/config/utils/style.dart';
// import 'package:myridedriverapp/controllers/chat_controller.dart';
// import 'package:myridedriverapp/controllers/home_controller.dart';
// import 'package:myridedriverapp/model/newbooking_nearby_model.dart';
// import 'package:myridedriverapp/widgets/canclerideconfirmations.dart';
// import 'package:myridedriverapp/widgets/custom_button.dart';
// import 'package:pinput/pinput.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class GoingForPickupScreen extends StatefulWidget {
//   final NewBookingNearByModel? trips;
//   GoingForPickupScreen({super.key, this.trips});

//   @override
//   State<GoingForPickupScreen> createState() => _GoingForPickupScreenState();
// }

// class _GoingForPickupScreenState extends State<GoingForPickupScreen> {
//   GoogleMapController? mapController;

//   LatLng? driverLatLng;
//   LatLng? pickupLatLng;
//   bool isInitialized = false;
//   double? totalDistance;
//   int? totalTime;
//   bool isTimerStarted = false;
//   Timer? _timer;
//   bool isArrived = false;
//   bool isOtpVerified = false;
//   bool isChatLoading = false;

//   StreamSubscription<Position>? positionStream;

//   double? latitudes;
//   double? longitudes;
//   bool showOtp = false;
//   String? driverID;

//   final TextEditingController _otpController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();

//     startTimer();
//   }

//   void startTimer() {
//     _timer = Timer.periodic(const Duration(seconds: 15), (timer) async {
//       final prefs = await SharedPreferences.getInstance();

//       final controller = Get.find<HomeController>();

//       print('⏱ Timer triggered');

//       print("DEBUG => lat: $latitudes, lng: $longitudes");
//       String? bookingId = prefs.getString("booking_id");
// print("DEBUG => lat: $latitudes, lng: $bookingId");
//       controller.getRouteCoordinates(
//         startLat: driverLatitude!,
//         startLng: driverLongitude!,
//         endLat: widget.trips!.pickupLat!,
//         endLng: widget.trips!.pickupLng!,
//       );
//     });
//   }

//   @override
//   void dispose() {
//     positionStream?.cancel();
//     _timer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final defaultPinTheme = PinTheme(
//       width: 60,
//       height: 60,
//       textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade200,
//         borderRadius: BorderRadius.circular(12),
//       ),
//     );
//     return Scaffold(
//       body: GetBuilder<HomeController>(
//         builder: (controller) {
//           final data = controller.trackRideModel;

//           if (data == null) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           if (!isInitialized && data.data != null) {
//             isInitialized = true;

//             pickupLatLng = LatLng(data.data!.lat ?? 0, data.data!.lng ?? 0);

//             driverLatLng = LatLng(
//               pickupLatLng!.latitude - 0.01,
//               pickupLatLng!.longitude - 0.01,
//             );
//           }
//           final track = controller.trackRideModel;

//           controller.calculateETA(
//             driverLat: driverLatitude,
//             driverLng: driverLongitude,
//             userLat: widget.trips!.pickupLat,
//             userLng: widget.trips!.pickupLng,
//           );

//           return Stack(
//             children: [
//               GoogleMap(
//                 initialCameraPosition: CameraPosition(
//                   target: pickupLatLng ?? LatLng(28.6139, 77.2090),
//                   zoom: 14,
//                 ),

//                 onMapCreated: (controllerMap) {
//                   mapController = controllerMap;

//                   mapController!.animateCamera(
//                     CameraUpdate.newLatLngBounds(
//                       LatLngBounds(
//                         southwest: LatLng(
//                           min(driverLatitude!, widget.trips!.pickupLat!),
//                           min(driverLongitude!, widget.trips!.pickupLng!),
//                         ),
//                         northeast: LatLng(
//                           max(driverLatitude!, widget.trips!.pickupLat!),
//                           max(driverLongitude!, widget.trips!.pickupLng!),
//                         ),
//                       ),
//                       100,
//                     ),
//                   );
//                 },
//                 myLocationEnabled: true,
//                 myLocationButtonEnabled: true,
//                 markers: controller.markers,
//                 polylines: controller.polylines,
//               ),

//               /// 🔹 TOP ADDRESS BOX
//               Positioned(
//                 top: 40,
//                 left: 16,
//                 right: 16,
//                 child: Container(
//                   /// height: MediaQuery.of(context).size.height * 0.12,
//                   padding: EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: ColorResources.appColor,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           const Icon(Icons.arrow_upward, color: Colors.white),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               widget.trips!.dropAddress ?? "",
//                               style: PoppinsSemiBold.copyWith(
//                                 color: ColorResources.whiteColor,
//                                 fontSize: 12,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       // const SizedBox(height: 5),
//                       // Text(
//                       //   "toward ${widget.trips!.dropAddress ?? ""}",
//                       //   style: const TextStyle(color: Colors.white70),
//                       // ),
//                       const Divider(color: Colors.white30),
//                       Text(
//                         widget.trips!.pickupAddress ?? "",
//                         style: PoppinsReguler.copyWith(
//                           color: ColorResources.whiteColor,
//                           fontSize: 12,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         "${(widget.trips!.distance! * 1000).toStringAsFixed(0) ?? "0"} km away",
//                         style: PoppinsSemiBold.copyWith(
//                           color: ColorResources.whiteColor,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               Positioned(
//                 bottom: 0,
//                 left: 0,
//                 right: 0,
//                 child: Container(
//                   constraints: BoxConstraints(
//                     maxHeight: MediaQuery.of(context).size.height * 0.4,
//                   ),
//                   child: Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: const BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.vertical(
//                         top: Radius.circular(25),
//                       ),
//                     ),
//                     child: SingleChildScrollView(
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Center(
//                             child: Container(
//                               height: 5,
//                               width: 50,
//                               decoration: BoxDecoration(
//                                 color: Colors.grey,
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                             ),
//                           ),

//                           const SizedBox(height: 5),

//                           Builder(
//                             builder: (context) {
//                               double distanceInMeters =
//                                   Geolocator.distanceBetween(
//                                     driverLatitude!,
//                                     driverLongitude!,
//                                     widget.trips!.pickupLat!,
//                                     widget.trips!.pickupLng!,
//                                   );

//                               return Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   if (!isOtpVerified) ...[
//                                     Row(
//                                       mainAxisAlignment:
//                                           MainAxisAlignment.spaceAround,
//                                       children: [
//                                         Text(
//                                           "Going For Picking Up",
//                                           style: PoppinsSemiBold.copyWith(
//                                             color: ColorResources.blackcolor11,
//                                             fontSize: 12,
//                                           ),
//                                         ),
//                                         Spacer(),
//                                         GestureDetector(
//                                           onTap: () {
//                                             Get.toNamed(
//                                               RouteHelper.getbookingTripDetailsScreen(),
//                                               arguments: {
//                                                 "trips": widget.trips,
//                                                 "acceptData": data,
//                                               },
//                                             );
//                                           },
//                                           child: Text(
//                                             "Ride Details",
//                                             style: PoppinsSemiBold.copyWith(
//                                               color:
//                                                   ColorResources.blackcolor11,
//                                               fontSize: 12,
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ],

//                                   const SizedBox(height: 5),

//                                   if (!isOtpVerified) ...[
//                                     Row(
//                                       children: [
//                                         Text(
//                                           "Estimated time of Arrival: ",
//                                           style: PoppinsReguler.copyWith(
//                                             color: ColorResources.blackcolor11,
//                                             fontSize: 12,
//                                           ),
//                                         ),
//                                         // const SizedBox(width: 5),
//                                         Spacer(),
//                                         Chip(
//                                           padding: EdgeInsets.zero,
//                                           materialTapTargetSize:
//                                               MaterialTapTargetSize.shrinkWrap,
//                                           label: controller.totaltime.isEmpty
//                                               ? Text('0 Min')
//                                               : Text(
//                                                   '${controller.totaltime} min',
//                                                 ),
//                                         ),
//                                       ],
//                                     ),
//                                   ],

//                                   if (!isOtpVerified) ...[
//                                     Text(
//                                       'Distance: ${controller.totaldestance} km',
//                                       style: PoppinsReguler.copyWith(
//                                         color: ColorResources.blackcolor11,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ],
//                                   const SizedBox(height: 5),
//                                   if (!isOtpVerified) ...[
//                                     Text(
//                                       'Total Fare: ${data.data?.totalFare} ' ??
//                                           '',

//                                       style: PoppinsSemiBold.copyWith(
//                                         color: ColorResources.blackcolor11,
//                                       ),
//                                     ),
//                                   ],

//                                   const SizedBox(height: 5),
//                                   if (!isOtpVerified) ...[
//                                     Container(
//                                       padding: const EdgeInsets.all(5),

//                                       decoration: BoxDecoration(
//                                         color: const Color(0xffE6F2F8),
//                                         borderRadius: BorderRadius.circular(15),
//                                       ),
//                                       child: Row(
//                                         //mainAxisAlignment: MainAxisAlignment.center,
//                                         children: [
//                                           CircleAvatar(
//                                             backgroundImage:
//                                                 (data
//                                                             .data
//                                                             ?.customerInfo
//                                                             ?.profileImage !=
//                                                         null &&
//                                                     data
//                                                         .data!
//                                                         .customerInfo!
//                                                         .profileImage!
//                                                         .isNotEmpty)
//                                                 ? NetworkImage(
//                                                     ApiConstants.imageurl +
//                                                         data
//                                                             .data!
//                                                             .customerInfo!
//                                                             .profileImage!,
//                                                   )
//                                                 : const AssetImage(
//                                                         "assets/images/profile.png",
//                                                       )
//                                                       as ImageProvider,
//                                           ),

//                                           const SizedBox(width: 9),
//                                           Expanded(
//                                             child: Column(
//                                               crossAxisAlignment:
//                                                   CrossAxisAlignment.start,
//                                               children: [
//                                                 Text(
//                                                   data
//                                                           .data
//                                                           ?.customerInfo
//                                                           ?.name ??
//                                                       "",
//                                                   style:
//                                                       PoppinsSemiBold.copyWith(
//                                                         color: ColorResources
//                                                             .blackcolor11,
//                                                       ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                           GestureDetector(
//                                             onTap: () async {
//                                               if (isChatLoading) return;

//                                               isChatLoading = true;

//                                               try {
//                                                 final prefs =
//                                                     await SharedPreferences.getInstance();

//                                                 final response =
//                                                     await Get.find<
//                                                           ChatController
//                                                         >()
//                                                         .startChats(
//                                                           context: context,
//                                                           bookingId: data
//                                                               .data!
//                                                               .bookingId
//                                                               .toString(),
//                                                           driverId:
//                                                               prefs.getString(
//                                                                 ApiConstants
//                                                                     .profileid,
//                                                               ) ??
//                                                               '',
//                                                           customerId: data
//                                                               .data!
//                                                               .customerInfo!
//                                                               .customer
//                                                               .toString(),
//                                                         );

//                                                 print(
//                                                   'testing on tab ${data.data!.customerInfo!.customer}',
//                                                 );

//                                                 if (response.statusCode ==
//                                                     200) {
//                                                   Get.toNamed(
//                                                     RouteHelper.getchatDriverChatScreen(),
//                                                     arguments: {
//                                                       "isDriverScreen": true,
//                                                       "acceptData": data,
//                                                       "bookingId":
//                                                           widget.trips!.id,
//                                                       "trips": widget.trips,
//                                                     },
//                                                   );
//                                                 }
//                                               } catch (e) {
//                                                 print("Tap Error: $e");
//                                               } finally {
//                                                 isChatLoading = false;
//                                               }
//                                             },
//                                             child: Icon(
//                                               Icons.chat_bubble_outline,
//                                             ),
//                                           ),
//                                           SizedBox(width: 12),
//                                           GestureDetector(
//                                             onTap: () {
//                                               Get.find<HomeController>()
//                                                   .callNumber(
//                                                     phoneNumber: track!
//                                                         .data!
//                                                         .customerInfo
//                                                         ?.phone
//                                                         .toString(),
//                                                   );
//                                             },
//                                             child: Icon(Icons.call),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],

//                                   const SizedBox(height: 5),

//                                   if (!isArrived && distanceInMeters < 100)
//                                     CustomButton(
//                                       text: "Arrived",
//                                       onPressed: () {
//                                         setState(() {
//                                           isArrived = true;
//                                           Get.find<HomeController>()
//                                               .driverArrived(
//                                                 context: context,
//                                                 bookingId: data.data!.bookingId
//                                                     .toString(),
//                                               );
//                                         });
//                                       },
//                                     ),

//                                   if (isArrived && !isOtpVerified) ...[
//                                     const Text(
//                                       "Enter 4 Digit OTP",
//                                       style: TextStyle(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),

//                                     const SizedBox(height: 15),

//                                     Center(
//                                       child: Pinput(
//                                         controller: _otpController,
//                                         length: 4,
//                                         autofocus: true,
//                                         keyboardType: TextInputType.number,
//                                         defaultPinTheme: defaultPinTheme,
//                                         onCompleted: (pin) async {},
//                                       ),
//                                     ),
//                                     const SizedBox(height: 9),

//                                     CustomButton(
//                                       text: "Start Ride",
//                                       onPressed: () async {
//                                         String otp = _otpController.text.trim();

//                                         if (otp.length != 4) {
//                                           Get.snackbar(
//                                             "Error",
//                                             "Please enter 4 digit OTP",
//                                           );
//                                           return;
//                                         }

//                                         if (otp == data.data!.otp.toString()) {
//                                           // var response =
//                                           await Get.find<HomeController>()
//                                               .verifyPickUpOtps(
//                                                 context: context,
//                                                 bookingId: data.data!.bookingId
//                                                     .toString(),
//                                                 otpNumber: otp,
//                                                 acceptData: data,
//                                                 trips: widget.trips,
//                                               );

//                                           // isOtpVerified = true;
//                                         } else {
//                                           Get.snackbar("Error", "Invalid OTP");
//                                         }
//                                         // String otp = _otpController.text.trim();
//                                       },
//                                     ),
//                                   ],

//                                   const SizedBox(height: 10),

//                                   CustomCancleButton(
//                                     text: "Cancel Ride",
//                                     onTap: () {
//                                       _showCancelBottomSheet(
//                                         data.data!.bookingId.toString(),
//                                       );
//                                     },
//                                   ),

//                                   const SizedBox(height: 25),
//                                 ],
//                               );
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _infoCard(IconData icon, String title, String subtitle) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.grey[100],
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
//                   style: const TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   subtitle,
//                   style: const TextStyle(fontSize: 12, color: Colors.grey),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showCancelBottomSheet(String bookingid) {
//     Get.bottomSheet(
//       CancelRideBottomSheet(bookingId: bookingid),
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       enterBottomSheetDuration: const Duration(milliseconds: 400),
//       exitBottomSheetDuration: const Duration(milliseconds: 300),
//     );
//   }
// }

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/chat_controller.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/model/newbooking_nearby_model.dart';
import 'package:myridedriverapp/widgets/canclerideconfirmations.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoingForPickupScreen extends StatefulWidget {
  ///  final NewBookingNearByModel? trips;

  const GoingForPickupScreen({
    super.key,
    ////this.trips
  });

  @override
  State<GoingForPickupScreen> createState() => _GoingForPickupScreenState();
}

class _GoingForPickupScreenState extends State<GoingForPickupScreen> {
  GoogleMapController? mapController;

  LatLng? driverLatLng;
  LatLng? pickupLatLng;

  bool isInitialized = false;
  bool isArrived = false;
  bool isOtpVerified = false;
  bool isChatLoading = false;

  Timer? _timer;
  StreamSubscription<Position>? positionStream;

  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();

    startTimer();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      String? bookingId = prefs.getString("booking_id");
      final controller = Get.find<HomeController>();
      Get.find<ProfileController>().tripRideDetailsApi(
        context: context,
        bookingid: bookingId,
      );

      await controller.trackbookingRide(context: context, bookingId: bookingId);
      final track = controller.trackRideModel;

      if (track == null || track.data == null) return;
      if (driverLatitude == null || driverLongitude == null) return;

      controller.getRouteCoordinates(
        startLat: driverLatitude!,
        startLng: driverLongitude!,
        endLat: track.data!.lat!,
        endLng: track.data!.lng!,
      );
    });
  }

  @override
  void dispose() {
    positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Scaffold(
      body: GetBuilder<HomeController>(
        builder: (controller) {
          final data = controller.trackRideModel;

          if (data == null || data.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final rideData = data.data!;

          if (!isInitialized) {
            isInitialized = true;

            pickupLatLng = LatLng(rideData.lat ?? 0, rideData.lng ?? 0);

            driverLatLng = LatLng(
              pickupLatLng!.latitude - 0.01,
              pickupLatLng!.longitude - 0.01,
            );
          }

          controller.calculateETA(
            driverLat: driverLatitude,
            driverLng: driverLongitude,
            userLat: rideData.lat,
            userLng: rideData.lng,
          );

          double distanceInMeters = Geolocator.distanceBetween(
            driverLatitude!,
            driverLongitude!,
            rideData.lat!,
            rideData.lng!,
          );

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: pickupLatLng ?? const LatLng(28.6139, 77.2090),
                  zoom: 14,
                ),

                onMapCreated: (controllerMap) {
                  mapController = controllerMap;

                  mapController!.animateCamera(
                    CameraUpdate.newLatLngBounds(
                      LatLngBounds(
                        southwest: LatLng(
                          min(driverLatitude!, rideData.lat!),
                          min(driverLongitude!, rideData.lng!),
                        ),
                        northeast: LatLng(
                          max(driverLatitude!, rideData.lat!),
                          max(driverLongitude!, rideData.lng!),
                        ),
                      ),
                      100,
                    ),
                  );
                },

                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                markers: controller.markers,
                polylines: controller.polylines,
              ),

              /// TOP BOX
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ColorResources.appColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward, color: Colors.white),
                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              rideData.dropaddress ?? "",
                              style: PoppinsSemiBold.copyWith(
                                color: ColorResources.whiteColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Divider(color: Colors.white30),

                      Text(
                        rideData.pickupaddress ?? "",
                        style: PoppinsReguler.copyWith(
                          color: ColorResources.whiteColor,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Distance: ${controller.totaldestance} km',
                        style: PoppinsSemiBold.copyWith(
                          color: ColorResources.whiteColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// TOP LINE
                          Center(
                            child: Container(
                              height: 5,
                              width: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          /// HEADER
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Going For Picking Up",
                                  style: PoppinsSemiBold.copyWith(fontSize: 14),
                                ),
                              ),

                              GestureDetector(
                                onTap: () {
                                  Get.toNamed(
                                    RouteHelper.getbookingTripDetailsScreen(),
                                    arguments: {'trips': data},
                                  );
                                },
                                child: Text(
                                  "Ride Details",
                                  style: PoppinsSemiBold.copyWith(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          /// ETA
                          Row(
                            children: [
                              Text(
                                "Estimated Arrival Time",
                                style: PoppinsReguler.copyWith(fontSize: 12),
                              ),

                              const Spacer(),

                              Chip(
                                label: Text(
                                  controller.totaltime.isEmpty
                                      ? '0 Min'
                                      : '${controller.totaltime} Min',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          /// DISTANCE + FARE
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffF5F5F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        "Distance",
                                        style: PoppinsReguler.copyWith(
                                          fontSize: 11,
                                        ),
                                      ),

                                      const SizedBox(height: 5),

                                      Text(
                                        '${controller.totaldestance ?? "0"} km',
                                        style: PoppinsSemiBold.copyWith(
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffF5F5F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        "Total Fare",
                                        style: PoppinsReguler.copyWith(
                                          fontSize: 11,
                                        ),
                                      ),

                                      const SizedBox(height: 5),

                                      Text(
                                        '₹ ${rideData.totalFare ?? "0"}',
                                        style: PoppinsSemiBold.copyWith(
                                          fontSize: 14,
                                          color: ColorResources.blackcolor11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          /// CUSTOMER CARD
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xffE6F2F8),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage:
                                      (rideData.customerInfo?.profileImage !=
                                              null &&
                                          rideData
                                              .customerInfo!
                                              .profileImage!
                                              .isNotEmpty)
                                      ? NetworkImage(
                                          ApiConstants.imageurl +
                                              rideData
                                                  .customerInfo!
                                                  .profileImage!,
                                        )
                                      : const AssetImage(
                                              "assets/images/profile.png",
                                            )
                                            as ImageProvider,
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rideData.customerInfo?.name ?? "",
                                        style: PoppinsSemiBold.copyWith(
                                          fontSize: 14,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        rideData.customerInfo?.phone ?? "",
                                        style: PoppinsReguler.copyWith(
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                /// CHAT
                                GestureDetector(
                                  onTap: () async {
                                    if (isChatLoading) return;

                                    setState(() {
                                      isChatLoading = true;
                                    });

                                    try {
                                      final prefs =
                                          await SharedPreferences.getInstance();

                                      String? bookingId = prefs.getString(
                                        "booking_id",
                                      );

                                      final controllerprofile =
                                          Get.find<ProfileController>();

                                      /// WAIT FOR API
                                      await controllerprofile
                                          .tripRideDetailsApi(
                                            context: context,
                                            bookingid: bookingId,
                                          );

                                      final trips =
                                          controllerprofile.tripDetailsModel;

                                      final response =
                                          await Get.find<ChatController>()
                                              .startChats(
                                                context: context,
                                                bookingId: rideData.bookingId
                                                    .toString(),
                                                driverId:
                                                    prefs.getString(
                                                      ApiConstants.profileid,
                                                    ) ??
                                                    '',
                                                customerId:
                                                    rideData
                                                        .customerInfo
                                                        ?.customer
                                                        ?.toString() ??
                                                    '',
                                              );

                                      if (response.statusCode == 200) {
                                        Get.toNamed(
                                          RouteHelper.getchatDriverChatScreen(),
                                          arguments: {
                                            "isDriverScreen": true,
                                            "acceptData": data,
                                            "bookingId": rideData.bookingId,
                                            "trips": trips,
                                          },
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint("Chat Open Error: $e");
                                    } finally {
                                      setState(() {
                                        isChatLoading = false;
                                      });
                                    }
                                  },

                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 20,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                /// CALL
                                GestureDetector(
                                  onTap: () {
                                    Get.find<HomeController>().callNumber(
                                      phoneNumber: rideData.customerInfo?.phone
                                          .toString(),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.call, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          /// ARRIVED BUTTON
                          if (!isArrived && distanceInMeters < 100) ...[
                            const SizedBox(height: 18),

                            CustomButton(
                              text: "Arrived",
                              onPressed: () {
                                setState(() {
                                  isArrived = true;
                                });

                                Get.find<HomeController>().driverArrived(
                                  context: context,
                                  bookingId: rideData.bookingId.toString(),
                                );
                              },
                            ),
                          ],

                          if (isArrived && !isOtpVerified) ...[
                            const SizedBox(height: 20),

                            Center(
                              child: Text(
                                "Enter 4 Digit OTP",
                                style: PoppinsSemiBold.copyWith(fontSize: 14),
                              ),
                            ),

                            const SizedBox(height: 15),

                            Pinput(
                              controller: _otpController,
                              length: 4,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              defaultPinTheme: defaultPinTheme,
                            ),

                            const SizedBox(height: 10),

                            CustomButton(
                              text: "Start Ride",
                              onPressed: () async {
                                String otp = _otpController.text.trim();

                                if (otp.length != 4) {
                                  Get.snackbar("Error", "Please enter OTP");
                                  return;
                                }

                                if (otp == rideData.otp.toString()) {
                                  final prefs =
                                      await SharedPreferences.getInstance();

                                  String? bookingId = prefs.getString(
                                    "booking_id",
                                  );

                                  final controllerprofile =
                                      Get.find<ProfileController>();

                                  controllerprofile.tripRideDetailsApi(
                                    context: context,
                                    bookingid: bookingId,
                                  );

                                  final trips =
                                      controllerprofile.tripDetailsModel;

                                  await Get.find<HomeController>()
                                      .verifyPickUpOtps(
                                        context: context,
                                        bookingId: rideData.bookingId
                                            .toString(),
                                        otpNumber: otp,
                                        acceptData: data,
                                        trips: trips,
                                      );
                                } else {
                                  Get.snackbar("Error", "Invalid OTP");
                                }
                              },
                            ),
                          ],

                          const SizedBox(height: 10),

                          CustomCancleButton(
                            text: "Cancel Ride",
                            onTap: () {
                              _showCancelBottomSheet(
                                rideData.bookingId.toString(),
                              );
                            },
                          ),
                          const SizedBox(height: 25),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Positioned(
              //   bottom: 0,
              //   left: 0,
              //   right: 0,
              //   child: Container(
              //     constraints: BoxConstraints(
              //       maxHeight: MediaQuery.of(context).size.height * 0.4,
              //     ),
              //     child: Container(
              //       padding: const EdgeInsets.all(16),
              //       decoration: const BoxDecoration(
              //         color: Colors.white,
              //         borderRadius: BorderRadius.vertical(
              //           top: Radius.circular(25),
              //         ),
              //       ),
              //       child: SingleChildScrollView(
              //         child: Column(
              //           children: [
              //             Container(
              //               height: 5,
              //               width: 50,
              //               decoration: BoxDecoration(
              //                 color: Colors.grey,
              //                 borderRadius: BorderRadius.circular(10),
              //               ),
              //             ),

              //             const SizedBox(height: 10),

              //             Row(
              //               children: [
              //                 Text(
              //                   "Going For Picking Up",
              //                   style: PoppinsSemiBold.copyWith(fontSize: 12),
              //                 ),

              //                 const Spacer(),

              //                 GestureDetector(
              //                   onTap: () {
              //                     Get.toNamed(
              //                       RouteHelper.getbookingTripDetailsScreen(),
              //                       // arguments: {
              //                       //   "trips": widget.trips,
              //                       //   "acceptData": data,
              //                       // },
              //                     );
              //                   },
              //                   child: Text(
              //                     "Ride Details",
              //                     style: PoppinsSemiBold.copyWith(fontSize: 12),
              //                   ),
              //                 ),
              //               ],
              //             ),

              //             const SizedBox(height: 10),

              //             Row(
              //               children: [
              //                 Text(
              //                   "Estimated Arrival Time",
              //                   style: PoppinsReguler.copyWith(fontSize: 12),
              //                 ),

              //                 const Spacer(),

              //                 Chip(
              //                   label: Text(
              //                     controller.totaltime.isEmpty
              //                         ? '0 Min'
              //                         : '${controller.totaltime} min',
              //                   ),
              //                 ),
              //               ],
              //             ),

              //             Column(
              //               mainAxisAlignment: MainAxisAlignment.start,
              //               //crossAxisAlignment: CrossAxisAlignment.start,
              //               children: [
              //                 Text('Distance: ${controller.totaldestance} km'),

              //                 const SizedBox(height: 5),

              //                 Text(
              //                   'Total Fare: ${rideData.totalFare}',
              //                   style: PoppinsSemiBold.copyWith(
              //                     color: ColorResources.blackcolor11,
              //                   ),
              //                 ),
              //               ],
              //             ),

              //             // Text('Distance: ${controller.totaldestance} km'),

              //             // const SizedBox(height: 5),

              //             // Text(
              //             //   'Total Fare: ${rideData.totalFare}',
              //             //   style: PoppinsSemiBold.copyWith(
              //             //     color: ColorResources.blackcolor11,
              //             //   ),
              //             // ),
              //             const SizedBox(height: 10),

              //             Container(
              //               padding: const EdgeInsets.all(5),
              //               decoration: BoxDecoration(
              //                 color: const Color(0xffE6F2F8),
              //                 borderRadius: BorderRadius.circular(15),
              //               ),
              //               child: Row(
              //                 children: [
              //                   CircleAvatar(
              //                     backgroundImage:
              //                         (rideData.customerInfo?.profileImage !=
              //                                 null &&
              //                             rideData
              //                                 .customerInfo!
              //                                 .profileImage!
              //                                 .isNotEmpty)
              //                         ? NetworkImage(
              //                             ApiConstants.imageurl +
              //                                 rideData
              //                                     .customerInfo!
              //                                     .profileImage!,
              //                           )
              //                         : const AssetImage(
              //                                 "assets/images/profile.png",
              //                               )
              //                               as ImageProvider,
              //                   ),

              //                   const SizedBox(width: 10),

              //                   Expanded(
              //                     child: Text(
              //                       rideData.customerInfo?.name ?? "",
              //                       style: PoppinsSemiBold,
              //                     ),
              //                   ),

              //                   GestureDetector(
              //                     onTap: () async {
              //                       if (isChatLoading) return;

              //                       isChatLoading = true;

              //                       try {
              //                         final prefs =
              //                             await SharedPreferences.getInstance();
              //                         String? bookingId = prefs.getString(
              //                           "booking_id",
              //                         );
              //                         // final tripdetails =
              //                         //     Get.find<ProfileController>()
              //                         //         .tripRideDetailsApi(
              //                         //           context: context,
              //                         //           bookingid: bookingId,
              //                         //         );

              //                         final controllerprofile =
              //                             Get.find<ProfileController>();

              //                         controllerprofile.tripRideDetailsApi(
              //                           context: context,
              //                           bookingid: bookingId,
              //                         );
              //                         final trips =
              //                             controllerprofile.tripDetailsModel;

              //                         final response =
              //                             await Get.find<ChatController>()
              //                                 .startChats(
              //                                   context: context,
              //                                   bookingId: rideData.bookingId
              //                                       .toString(),
              //                                   driverId:
              //                                       prefs.getString(
              //                                         ApiConstants.profileid,
              //                                       ) ??
              //                                       '',
              //                                   customerId: rideData
              //                                       .customerInfo!
              //                                       .customer
              //                                       .toString(),
              //                                 );

              //                         if (response.statusCode == 200) {
              //                           Get.toNamed(
              //                             RouteHelper.getchatDriverChatScreen(),
              //                             arguments: {
              //                               "isDriverScreen": true,
              //                               "acceptData": data,
              //                               "bookingId": rideData.bookingId,
              //                               "trips": trips,
              //                             },
              //                           );
              //                         }
              //                       } finally {
              //                         isChatLoading = false;
              //                       }
              //                     },
              //                     child: const Icon(Icons.chat_bubble_outline),
              //                   ),

              //                   const SizedBox(width: 12),

              //                   GestureDetector(
              //                     onTap: () {
              //                       Get.find<HomeController>().callNumber(
              //                         phoneNumber: rideData.customerInfo?.phone
              //                             .toString(),
              //                       );
              //                     },
              //                     child: const Icon(Icons.call),
              //                   ),
              //                 ],
              //               ),
              //             ),

              //             const SizedBox(height: 15),

              //             if (!isArrived && distanceInMeters < 100)
              //               CustomButton(
              //                 text: "Arrived",
              //                 onPressed: () {
              //                   setState(() {
              //                     isArrived = true;
              //                   });

              //                   Get.find<HomeController>().driverArrived(
              //                     context: context,
              //                     bookingId: rideData.bookingId.toString(),
              //                   );
              //                 },
              //               ),

              //             if (isArrived && !isOtpVerified) ...[
              //               const SizedBox(height: 10),

              //               const Text("Enter 4 Digit OTP"),

              //               const SizedBox(height: 15),

              //               Pinput(
              //                 controller: _otpController,
              //                 length: 4,
              //                 autofocus: true,
              //                 keyboardType: TextInputType.number,
              //                 defaultPinTheme: defaultPinTheme,
              //               ),

              //               const SizedBox(height: 10),

              //               CustomButton(
              //                 text: "Start Ride",
              //                 onPressed: () async {
              //                   String otp = _otpController.text.trim();

              //                   if (otp.length != 4) {
              //                     Get.snackbar("Error", "Please enter OTP");
              //                     return;
              //                   }

              //                   if (otp == rideData.otp.toString()) {
              //                     final prefs =
              //                         await SharedPreferences.getInstance();
              //                     String? bookingId = prefs.getString(
              //                       "booking_id",
              //                     );

              //                     final controllerprofile =
              //                         Get.find<ProfileController>();

              //                     controllerprofile.tripRideDetailsApi(
              //                       context: context,
              //                       bookingid: bookingId,
              //                     );
              //                     final trips =
              //                         controllerprofile.tripDetailsModel;

              //                     await Get.find<HomeController>()
              //                         .verifyPickUpOtps(
              //                           context: context,
              //                           bookingId: rideData.bookingId
              //                               .toString(),
              //                           otpNumber: otp,
              //                           acceptData: data,
              //                           trips: trips,

              //                           ///widget.trips,
              //                         );
              //                   } else {
              //                     Get.snackbar("Error", "Invalid OTP");
              //                   }
              //                 },
              //               ),
              //             ],

              //             const SizedBox(height: 10),

              //             CustomCancleButton(
              //               text: "Cancel Ride",
              //               onTap: () {
              //                 _showCancelBottomSheet(
              //                   rideData.bookingId.toString(),
              //                 );
              //               },
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
            ],
          );
        },
      ),
    );
  }

  void _showCancelBottomSheet(String bookingid) {
    Get.bottomSheet(
      CancelRideBottomSheet(bookingId: bookingid),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enterBottomSheetDuration: const Duration(milliseconds: 400),
      exitBottomSheetDuration: const Duration(milliseconds: 300),
    );
  }
}
