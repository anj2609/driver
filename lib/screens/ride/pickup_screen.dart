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
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/duration_format.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/chat_controller.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/model/acceptride_details_model.dart';
import 'package:myridedriverapp/screens/home/ridedetails_screen.dart' show bookingIdStore;
import 'package:myridedriverapp/services/nav_overlay_service.dart';
import 'package:myridedriverapp/widgets/canclerideconfirmations.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/inapp_navigation_map.dart';
import 'package:myridedriverapp/widgets/toaster_animation.dart';
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
  bool isMarkingArrived = false;
  bool isOtpVerified = false;
  bool isChatLoading = false;

  // Live, route-aware ETA/distance from InAppNavigationMap's turn-by-turn
  // engine (real road-network data) — preferred over the older
  // estimate/backend-reported fields below once available, since those
  // come from an unreliable secondary flow (or, for this ride's backend
  // data specifically, were nonsensical outright).
  int? _liveEtaSeconds;
  double? _liveDistanceMeters;

  // Booking ids we've already kicked off an estimate/trip-detail fetch for.
  //
  // The fetch below runs from an addPostFrameCallback registered inside
  // build(), and it was gated only on `estimatePrice.isEmpty`. Both calls it
  // makes — tripRideDetailsApi() and fetchEstimateRideData() — end in
  // update(), which rebuilds this GetBuilder, which registers the callback
  // again. That closes the loop the moment the guard fails to clear: if the
  // estimate never lands (backend rejects it, no usable drop coordinates,
  // request fails), estimatePrice stays empty and trip-detail fires
  // continuously — a device log showed dozens of identical
  // `trip-detail {booking_id: 98}` calls back to back, which is what starved
  // the renderer ("Unable to acquire a buffer item") and left the screen
  // spinning forever.
  //
  // Latching on the booking id makes the request fire at most once per ride
  // regardless of whether it succeeds, so a failed estimate degrades to a
  // missing estimate instead of a request storm.
  final Set<String> _estimateRequestedFor = <String>{};

  Timer? _timer;
  StreamSubscription<Position>? positionStream;

  final TextEditingController _otpController = TextEditingController();

  // No loading spinner and no retry UI here on purpose, by explicit request —
  // acceptRidesTrip() now awaits trackbookingRide() (bounded to 3s) before
  // ever pushing this screen, so trackRideModel is already populated for the
  // common case's very first frame. The rare case where that still isn't
  // ready (a genuinely slow/failing fetch past the 3s bound) renders nothing
  // — see the `data == null` branch in build() below — rather than a spinner
  // or a "couldn't load, retry" message; startTimer()'s existing 15s
  // background retry fills it in as soon as it lands, with no interaction
  // needed.
  @override
  void initState() {
    super.initState();
    // This screen is pushed fresh for every accepted ride, so the guard that
    // stops the cancellation popup from firing twice for the same ride needs
    // to be cleared here — otherwise a driver's first cancelled ride would
    // silently disable the popup for every ride after it, for the rest of
    // the app session.
    Get.find<HomeController>().resetCancellationHandledFlag();
    _initLocation();
    startTimer();
  }

  Future<void> _initLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      driverLatitude = position.latitude;
      driverLongitude = position.longitude;
      if (mounted) setState(() {});
      debugPrint('[Pickup] Location obtained: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('[Pickup] Location error: $e');
    }
  }

  void startTimer() {
    // Two cadences, because this timer serves two very different jobs.
    //
    // Once the ride is loaded, 15s is the right refresh rate. But it was also
    // the *first-load* retry — and acceptRidesTrip() only waits 3s for
    // track-booking-ride before pushing this screen anyway. So any fetch
    // slower than 3s (routine on this backend: the accept burst fires
    // alongside get-profile and driver-location-update, on a client with a
    // 60s timeout) dropped the driver onto "Loading ride details..." and then
    // left it spinning for a further 15 seconds with nothing in flight. That
    // dead wait is the reported "takes a lot of time and the loader keeps
    // running" — the request wasn't slow, nothing was asking.
    //
    // Retry fast while there is nothing to show, then settle into the normal
    // refresh rate once it lands.
    _scheduleTick(const Duration(milliseconds: 1500));
  }

  void _scheduleTick(Duration interval) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (timer) async {
      if (!mounted) return;

      final controller = Get.find<HomeController>();
      final bool wasLoaded = controller.trackRideModel?.data != null;

      final prefs = await SharedPreferences.getInstance();
      String? bookingId = prefs.getString("booking_id");
      if (!mounted) return;

      Get.find<ProfileController>().tripRideDetailsApi(
        context: context,
        bookingid: bookingId,
      );

      await controller.trackbookingRide(context: context, bookingId: bookingId);
      if (!mounted) return;
      final track = controller.trackRideModel;

      // First successful load — drop back to the slower refresh cadence.
      if (!wasLoaded && track?.data != null) {
        _scheduleTick(const Duration(seconds: 15));
      }

      if (track == null || track.data == null) return;
      if (driverLatitude == null || driverLongitude == null) return;

      // Check if backend has set status to 'arrived' — show OTP field
      final rideStatus = track.data!.status?.toLowerCase() ?? '';

      // Was never checked at all — this screen only ever watched for
      // "arrived"/"ongoing", so a rider cancelling here (any time before the
      // ride actually starts, including mid-OTP-entry) changed nothing about
      // what the driver saw. They stayed on this screen indefinitely,
      // tracking a booking that no longer existed, with no popup and no way
      // back to searching for a new ride short of force-closing the app.
      if (rideStatus == 'cancelled') {
        controller.handleRideCancelledByRider(context);
        return;
      }

      if (rideStatus == 'arrived' && !isArrived && mounted) {
        setState(() {
          isArrived = true;
        });
        debugPrint('[Pickup] Backend status is arrived — showing OTP');
      }

      // Re-targeted per phase. This used to be hardcoded to the pickup, so
      // once the driver had the passenger aboard it kept re-measuring the
      // journey to a point they were already standing on — every 15 seconds,
      // for the rest of the ride.
      final routeTarget = _navTarget(track.data);
      if (routeTarget != null) {
        controller.getRouteCoordinates(
          startLat: driverLatitude!,
          startLng: driverLongitude!,
          endLat: routeTarget.lat,
          endLng: routeTarget.lng,
        );
      }

      // Move map camera to follow the driver's current position
      if (mapController != null && mounted) {
        try {
          mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(
                  min(driverLatitude!, track.data!.lat!),
                  min(driverLongitude!, track.data!.lng!),
                ),
                northeast: LatLng(
                  max(driverLatitude!, track.data!.lat!),
                  max(driverLongitude!, track.data!.lng!),
                ),
              ),
              100,
            ),
          );
        } catch (e) {
          debugPrint('[Pickup] Camera update error: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    positionStream?.cancel();
    _timer?.cancel();
    // Whatever route this screen is left by — ride completed, cancelled by
    // the rider, or the driver backing out — the floating return bubble
    // (see _startGoogleMapsNavigation) has nothing left to return to once
    // this screen is gone, so it shouldn't outlive it. Safe to call even
    // when navigation to Google Maps was never actually started.
    NavOverlayService.stopNavigation();
    super.dispose();
  }

  /// Picks the best available ETA, preferring the live route-aware figure
  /// from in-app navigation, then the driver→pickup estimate, then the
  /// estimate-ride-list duration. A source that reports zero is treated as
  /// having no answer rather than as an answer of zero.
  /// True only for a string holding a number greater than zero.
  ///
  /// Every distance/time source in this screen reports 0 when it has nothing
  /// rather than reporting nothing, so "is it present" and "is it an answer"
  /// are different questions. Treating the first as the second is what pinned
  /// the readouts at "0.0 km" and blanked the ETA.
  static bool _isRealValue(String? raw) {
    if (raw == null) return false;
    final value = double.tryParse(raw.trim());
    return value != null && value > 0;
  }

  /// The fare shown on this screen while the ride is ongoing, and the fare
  /// resolved for the end-of-ride payment dialog (see
  /// StartDriverRideScreen._promptPaymentWithFinalFare) used to come from two
  /// different places — this one straight off track-booking-ride's
  /// (unreconciled) `total_fare`, that one from /trip-detail's recalculated
  /// `payment.final_amount` — so a driver could watch one number the whole
  /// ride and then get handed a different one the moment it ended. Same
  /// precedence as that dialog now: prefer /trip-detail's figure (already
  /// fetched at OTP-verify time into this same ProfileController), so both
  /// screens agree throughout.
  String _ongoingFareText(HomeController controller, AcceptRideData? rideData) {
    final tripData = Get.find<ProfileController>().tripDetailsModel?.data;
    final fromTripDetail = tripData?.finalAmount ?? tripData?.paymentTotalFare;
    if (fromTripDetail != null && fromTripDetail > 0) {
      return fromTripDetail.toStringAsFixed(2);
    }

    if (rideData?.totalFare != null && rideData!.totalFare!.isNotEmpty) {
      return rideData.totalFare!;
    }
    if (controller.estimatePrice.isNotEmpty) return controller.estimatePrice;
    return '—';
  }

  String _etaText(HomeController controller, AcceptRideData? rideData) {
    // The booking's own trip time (track-booking-ride's `time`) comes first,
    // and deliberately outranks the live figure. Before OTP the only live
    // route is driver→pickup, which collapses to ~0-2 min the instant the
    // driver reaches the pickup — that is what dropped the readout from
    // "54 min" to "3 min" a few seconds in. The backend's trip time is the
    // stable, authoritative answer for the journey the driver is taking on,
    // so it is shown until a live figure for the *same* journey exists (only
    // once the ride is ongoing and a real destination route is running).
    if (_isRealValue(rideData?.time)) {
      return formatMinutesLabel(rideData!.time) ?? '${rideData.time!.trim()} min';
    }

    final live = _liveEtaSeconds;
    if (isOtpVerified && live != null && live > 0) return _formatEta(live);

    if (_isRealValue(controller.etaToDestinationMinutes)) {
      return formatMinutesLabel(controller.etaToDestinationMinutes) ??
          '${controller.etaToDestinationMinutes.trim()} min';
    }

    final estimate = controller.estimateDuration.trim();
    final estimateMinutes = double.tryParse(estimate);
    if (estimate.isNotEmpty && (estimateMinutes == null || estimateMinutes > 0)) {
      // estimateDuration arrives pre-formatted by the backend ("2804 mins")
      // — reformatted here rather than shown as-is, since a raw four-digit
      // minute count is exactly the "2000 min" complaint this whole helper
      // exists to fix.
      return formatMinutesLabel(estimate) ?? estimate;
    }

    return '—';
  }

  /// Distance counterpart to [_etaText], with the same sources in the same
  /// order so the two readouts can never describe different journeys.
  String _distanceText(HomeController controller, AcceptRideData? rideData) {
    // Backend trip distance first, for the same reason as the ETA: the live
    // figure before pickup is driver→pickup (~0.5 km once arrived) and must
    // not overwrite the 38 km the trip actually is.
    if (_isRealValue(rideData?.distance)) return rideData!.distance!.trim();

    final live = _liveDistanceMeters;
    if (isOtpVerified && live != null && live > 0) return _formatKm(live);

    if (_isRealValue(controller.estimateDistance)) {
      return controller.estimateDistance.trim();
    }

    return '—';
  }

  String _formatEta(int seconds) => formatSecondsLabel(seconds);

  String _formatKm(double meters) => (meters / 1000).toStringAsFixed(1);

  /// Where the driver is actually headed right now.
  ///
  /// Before the passenger is aboard that is the pickup point; once the ride is
  /// underway it is the drop-off. This screen stays mounted for the whole
  /// trip, and every distance/ETA on it used to be measured to the pickup
  /// regardless of phase — so the moment the driver reached the passenger the
  /// readout collapsed to "0.0 km / 1 min" and stayed there for the rest of
  /// the journey, reporting progress toward a place already arrived at.
  ///
  /// Falls back to the pickup when the booking carries no drop coordinates,
  /// which is still wrong but no worse than before, and never returns 0,0 —
  /// HomeController's ETA guard treats that as "no fix yet" and bails.
  ({double lat, double lng})? _navTarget(AcceptRideData? ride) {
    if (ride == null) return null;

    // "underway" is the ride actually being in progress — the passenger is
    // aboard — which is `ongoing`, i.e. after the OTP is verified. It is NOT
    // `arrived`: that only means the driver has reached the pickup and is
    // waiting for the rider, and the destination they still need guiding to is
    // the pickup, not the drop. Treating `arrived` as underway pointed
    // navigation at the drop (or, with no drop coords, back at the pickup) the
    // whole time the OTP screen was up, which is what fed the driver→pickup
    // ~0.5 km figure over the map.
    final String phase = ride.status?.toLowerCase() ?? '';
    final bool underway = isOtpVerified || phase == 'ongoing';

    if (underway) {
      // Prefer the backend's own drop coordinates; fall back to the ones we
      // geocoded from drop_address when it doesn't send them (see
      // [_ensureDropCoordinates]).
      final dropLat = ride.dropLat ?? _geocodedDrop?.latitude;
      final dropLng = ride.dropLng ?? _geocodedDrop?.longitude;
      if (dropLat != null && dropLng != null) {
        return (lat: dropLat, lng: dropLng);
      }
    }
    if (ride.lat != null && ride.lng != null) {
      return (lat: ride.lat!, lng: ride.lng!);
    }
    return null;
  }

  /// Hands the driver off to real Google Maps turn-by-turn navigation once
  /// the ride actually starts, leaving the Uber/Rapido-style floating
  /// bubble behind so they can tap back into this screen. Failure at any
  /// step (permission declined, no drop coordinates yet, Maps not
  /// installed) just leaves the driver on this screen with its own in-app
  /// map instead — that's still a fully working ride, so none of these are
  /// treated as fatal.
  Future<void> _startGoogleMapsNavigation(
    ({double lat, double lng})? target,
  ) async {
    if (target == null) return;

    if (!await NavOverlayService.hasOverlayPermission()) {
      await NavOverlayService.requestOverlayPermission();
      // The driver may have backed out of the Settings screen without
      // granting anything — re-check rather than assume the request
      // succeeded just because it returned.
      if (!await NavOverlayService.hasOverlayPermission()) {
        if (mounted) {
          AnimatedTopToast.show(
            context: context,
            message:
                "Enable 'Display over other apps' to get a floating "
                "return button while navigating.",
            backgroundColor: ColorResources.redbuttoncolor,
            icon: Icons.error_rounded,
          );
        }
        return;
      }
    }

    await NavOverlayService.startNavigation(
      lat: target.lat,
      lng: target.lng,
    );
  }

  /// Drop-off resolved from [AcceptRideData.dropaddress] via Google Geocoding,
  /// for the common case where track-booking-ride returns a drop_address
  /// string but no drop_lat/drop_lng — without which destination navigation
  /// has nothing to route toward.
  LatLng? _geocodedDrop;

  /// The booking [_geocodedDrop] belongs to (and a guard against firing the
  /// same lookup repeatedly from build).
  int? _geocodedDropBooking;
  bool _geocodingInFlight = false;

  /// If this booking is missing its drop coordinates but has a drop address,
  /// geocode the address once and cache the result. Safe to call from build:
  /// it no-ops unless there is genuinely new work to do.
  Future<void> _ensureDropCoordinates(AcceptRideData ride) async {
    // Backend already gave coordinates, or there's no address to work from.
    if (ride.dropLat != null && ride.dropLng != null) return;
    final address = ride.dropaddress?.trim();
    if (address == null || address.isEmpty) return;

    // Already resolved (or resolving) for this exact booking.
    if (_geocodedDropBooking == ride.bookingId && _geocodedDrop != null) return;
    if (_geocodingInFlight) return;
    _geocodingInFlight = true;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address)}&key=${ApiConstants.apiKey}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('[Pickup] geocode HTTP ${response.statusCode} for "$address"');
        return;
      }
      final body = jsonDecode(response.body);
      // Directions/Geocoding return 200 even on failure — the real outcome is
      // in `status`, with ZERO_RESULTS / REQUEST_DENIED / OVER_QUERY_LIMIT the
      // usual culprits.
      final status = body['status'];
      final results = body['results'];
      if (status != 'OK' || results is! List || results.isEmpty) {
        debugPrint('[Pickup] geocode "$address" returned $status');
        return;
      }
      final loc = results[0]['geometry']?['location'];
      final lat = (loc?['lat'] as num?)?.toDouble();
      final lng = (loc?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;

      if (!mounted) return;
      setState(() {
        _geocodedDrop = LatLng(lat, lng);
        _geocodedDropBooking = ride.bookingId;
      });
      debugPrint(
        '[Pickup] geocoded drop "$address" -> $lat,$lng for booking '
        '${ride.bookingId} — destination navigation enabled',
      );
    } catch (e) {
      debugPrint('[Pickup] geocode error for "$address": $e');
    } finally {
      _geocodingInFlight = false;
    }
  }

  /// Marks arrival at pickup. Shared by the manual "Arrived" button and
  /// in-app navigation's automatic arrival detection — both just call this
  /// one guarded path, so an auto-detected arrival is exactly as safe
  /// (idempotent, same backend call, same failure handling) as tapping
  /// the button by hand.
  Future<void> _markArrived(String bookingId) async {
    if (isMarkingArrived || isArrived) return;
    if (bookingId.isEmpty) return;

    setState(() => isMarkingArrived = true);
    try {
      final response = await Get.find<HomeController>().driverArrived(
        context: context,
        bookingId: bookingId,
      );
      final succeeded = response.statusCode == 200 &&
          response.body != null &&
          response.body['code']?.toString() == '200';
      if (mounted && succeeded) {
        setState(() => isArrived = true);
      }
    } catch (_) {
      // Keep the Arrived button available so the driver can retry — no toast.
    } finally {
      if (mounted && !isArrived) {
        setState(() => isMarkingArrived = false);
      }
    }
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

          // The screen's own shell (live map + bottom sheet) rather than a
          // blank frame — only the part that actually needs the API
          // response (trip details: address, OTP, fare) shows a loader, in
          // place of the sheet's real content, matching its exact styling so
          // the transition to the loaded state doesn't jump.
          //
          // InAppNavigationMap already renders a plain live map off the
          // driver's own GPS stream when handed no destination (see its own
          // graceful-degradation branch) — reused as-is here rather than
          // duplicating a second map instance. It re-renders itself with the
          // real route the moment this same GetBuilder rebuilds with data
          // populated.
          //
          // In the common case data is already here (acceptRidesTrip awaits
          // trackbookingRide before ever pushing this screen), so this branch
          // is rarely even reached; the rare case where it still isn't ready
          // resolves itself via either that same in-flight call or
          // startTimer()'s existing 15s background retry — no user action.
          if (data == null || data.data == null) {
            return Stack(
              children: [
                const Positioned.fill(
                  child: InAppNavigationMap(
                    destLat: null,
                    destLng: null,
                    destLabel: '',
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      28,
                      16,
                      28 + MediaQuery.of(context).padding.bottom,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        const SizedBox(height: 20),
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Loading ride details...",
                          style: PoppinsReguler.copyWith(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final rideData = data.data!;

          // Resolve the destination from drop_address when the backend sends
          // no drop coordinates, so turn-by-turn to the drop can run. Guarded
          // internally to fire the lookup at most once per booking; scheduled
          // after this frame so it never calls setState mid-build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ensureDropCoordinates(rideData);
          });

          if (!isInitialized) {
            isInitialized = true;

            pickupLatLng = LatLng(rideData.lat ?? 0, rideData.lng ?? 0);

            driverLatLng = LatLng(
              pickupLatLng!.latitude - 0.01,
              pickupLatLng!.longitude - 0.01,
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            // controller.latitude/longitude first, driverLatitude second.
            //
            // driverLatitude is a single Geolocator.getCurrentPosition()
            // taken in initState and never touched again, so feeding it here
            // pinned the ETA to wherever the driver happened to be when this
            // screen opened — it could not count down as they drove. And if
            // that one-shot call failed (permission prompt still up, no fix
            // yet, timeout) it stayed null forever, calculateETA's
            // zero-coordinate guard bailed on every call, and the ETA field
            // was never written at all. controller.latitude/longitude is the
            // live position stream that is already running for this ride.
            // Same re-targeting as the route fetch above — the fallback ETA
            // has to be measuring the same journey the screen claims to be
            // reporting, or the two disagree the moment the ride starts.
            final etaTarget = _navTarget(rideData);
            controller.calculateETA(
              driverLat: controller.latitude ?? driverLatitude,
              driverLng: controller.longitude ?? driverLongitude,
              userLat: etaTarget?.lat ?? rideData.lat,
              userLng: etaTarget?.lng ?? rideData.lng,
            );

            // Fetch estimate ride data (distance, time, price) from API.
            //
            // Latched on the booking id, not just estimatePrice.isEmpty. Both
            // calls below end in update(), which rebuilds this GetBuilder and
            // re-registers this very callback — so gating purely on the
            // estimate being empty meant a fetch that never populated it
            // looped forever. See _estimateRequestedFor.
            final String estimateBookingId =
                rideData.bookingId?.toString() ?? '';
            if (controller.estimatePrice.isEmpty &&
                rideData.lat != null &&
                rideData.lng != null &&
                estimateBookingId.isNotEmpty &&
                !_estimateRequestedFor.contains(estimateBookingId)) {
              _estimateRequestedFor.add(estimateBookingId);
              // Drop coordinates come from trip-detail API (ProfileController), not track-booking-ride
              try {
                final profileCtrl = Get.find<ProfileController>();
                final tripData = profileCtrl.tripDetailsModel?.data;
                if (tripData?.dropLat != null && tripData?.dropLng != null) {
                  controller.fetchEstimateRideData(
                    pickupLat: rideData.lat!,
                    pickupLng: rideData.lng!,
                    dropLat: tripData!.dropLat!,
                    dropLng: tripData.dropLng!,
                  );
                } else {
                  // Trip details not loaded yet — fetch them first, then estimate
                  profileCtrl.tripRideDetailsApi(
                    context: context,
                    bookingid: estimateBookingId,
                  ).then((_) {
                    if (!mounted) return;
                    final td = profileCtrl.tripDetailsModel?.data;
                    if (td?.dropLat != null && td?.dropLng != null) {
                      controller.fetchEstimateRideData(
                        pickupLat: rideData.lat!,
                        pickupLng: rideData.lng!,
                        dropLat: td!.dropLat!,
                        dropLng: td.dropLng!,
                      );
                    } else {
                      debugPrint(
                        '[Estimate] trip-detail for booking '
                        '$estimateBookingId returned no drop coordinates — '
                        'skipping estimate rather than retrying',
                      );
                    }
                  }).catchError((e) {
                    debugPrint('[Estimate] trip-detail failed: $e');
                  });
                }
              } catch (_) {}
            }
          });

          // Sync isArrived from backend status (e.g. admin changed to 'arrived')
          final backendStatus = rideData.status?.toLowerCase() ?? '';
          if (backendStatus == 'arrived' && !isArrived) {
            // Schedule the setState for after this build frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !isArrived) {
                setState(() => isArrived = true);
              }
            });
          }

          // Sync isOtpVerified when ride is already ongoing (e.g. app restarted mid-ride)
          if (backendStatus == 'ongoing' && !isOtpVerified) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !isOtpVerified) {
                setState(() {
                  isArrived = true;
                  isOtpVerified = true;
                });
              }
            });
          }

          return Stack(
            children: [
              // Real turn-by-turn navigation to the pickup point — replaces
              // the old bare GoogleMap (which only ever showed a redrawn
              // overview polyline, no maneuver data, no rerouting, no
              // arrival detection). Reuses HomeController's existing GPS
              // stream; doesn't start a second one.
              Positioned.fill(
                child: InAppNavigationMap(
                  // Turn-by-turn has to lead to where the driver is actually
                  // going, which stops being the pickup the moment the
                  // passenger is aboard.
                  destLat: _navTarget(rideData)?.lat ?? rideData.lat,
                  destLng: _navTarget(rideData)?.lng ?? rideData.lng,
                  destLabel: 'Pickup',
                  // Auto-detected arrival calls the exact same guarded path
                  // as tapping "Arrived" by hand — see _markArrived().
                  onArrived: () =>
                      _markArrived(rideData.bookingId?.toString() ?? ''),
                  // Leaves room for the address/distance box below, which
                  // now sits at the very top like it originally did.
                  topOffset: 155,
                  onUpdate: (snapshot) {
                    if (!mounted) return;

                    // Only trust a snapshot that actually has a route behind
                    // it. NavigationEngine.onLocationUpdate() returns
                    // NavSnapshot.empty() — every field zero — for as long as
                    // it has no route, which is every frame until the
                    // Directions call resolves, and forever if it fails or
                    // the destination is missing. InAppNavigationMap forwards
                    // those to onUpdate unconditionally.
                    //
                    // Storing them made _liveEtaSeconds/_liveDistanceMeters
                    // non-null zeros, and both readers below prefer
                    // "not null" over their fallbacks — so the chip rendered
                    // _formatEta(0) = "0 min" and the card "0.0 km", pinned
                    // there permanently instead of falling through to the
                    // real values that were already loaded. That is the
                    // "ETA is always 0" bug: not a bad calculation, an empty
                    // placeholder outranking good data.
                    if (snapshot.routePoints.isEmpty) return;

                    setState(() {
                      _liveEtaSeconds = snapshot.remainingDurationSeconds;
                      _liveDistanceMeters = snapshot.remainingDistanceMeters;
                    });
                  },
                ),
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
                        // Prefer the live, route-aware distance from
                        // in-app navigation (actual road-network distance)
                        // — rideData.distance is whatever the backend
                        // reported for this booking, which for some rides
                        // has turned out to be nonsensical (e.g. thousands
                        // of km for a local trip); estimateDistance is a
                        // separate, often-empty estimate flow.
                        'Distance: ${_distanceText(controller, rideData)} km',
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
                    maxHeight: MediaQuery.of(context).size.height * 0.50,
                  ),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
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
                                  isOtpVerified ? "Ride In Progress" : "Going For Picking Up",
                                  style: PoppinsSemiBold.copyWith(fontSize: 14),
                                ),
                              ),

                              GestureDetector(
                                onTap: () {
                                  bookingIdStore = rideData.bookingId?.toString();
                                  Get.toNamed(
                                    RouteHelper.getbookingTripDetailsScreen(),
                                    arguments: {
                                      'bookingId': rideData.bookingId?.toString(),
                                    },
                                  );
                                },
                                child: Text(
                                  "Ride Details",
                                  style: PoppinsSemiBold.copyWith(
                                    fontSize: 12,
                                    color: const Color(0xFF123EBC),
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
                                  // Prefer the live, route-aware ETA from
                                  // in-app navigation (real road-network
                                  // data). Now that routeless snapshots are
                                  // ignored (see onUpdate), this is null
                                  // until a route genuinely exists, so the
                                  // fallbacks below actually get used.
                                  //
                                  // etaToDestinationMinutes sits ahead of
                                  // estimateDuration because it is the
                                  // driver→pickup figure calculateETA()
                                  // recomputes from this screen on every
                                  // build — always populated, and it means
                                  // only that. Deliberately NOT
                                  // computedDuration, which three different
                                  // calculations overwrite with three
                                  // different meanings (see HomeController).
                                  // estimateDuration comes from the separate,
                                  // often-empty estimate-ride-list flow,
                                  // which is why this showed "—" even
                                  // mid-ride.
                                  //
                                  // Each source is accepted only if it is
                                  // actually a positive number. "Present"
                                  // cannot mean "not empty" here: a zero is
                                  // exactly what every one of these produces
                                  // when it has nothing — _liveEtaSeconds
                                  // before a route resolves, and
                                  // etaToDestinationMinutes whenever
                                  // calculateETA's inputs collapse to the
                                  // same point. Being non-empty, the string
                                  // "0" then beat every fallback below it and
                                  // the chip sat on "0 min" instead of
                                  // falling through to data that existed.
                                  // ridedetails_screen already guards its own
                                  // ETA this way for the same reason.
                                  _etaText(controller, rideData),
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
                                        // Same preference order as the top
                                        // banner above. rideData.distance is
                                        // checked for a real value, not just
                                        // a non-empty string — the backend
                                        // sends an unpriced booking's
                                        // distance as 0, which the model
                                        // stringifies to "0" and which then
                                        // beat every fallback and rendered a
                                        // confident "0 km".
                                        '${_distanceText(controller, rideData)} km',
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
                                        '₹ ${_ongoingFareText(controller, rideData)}',
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

                          /// ARRIVED BUTTON — shown whenever driver hasn't marked arrived yet
                          if (!isArrived) ...[
                            const SizedBox(height: 18),

                            CustomButton(
                              text: isMarkingArrived
                                  ? "Marking arrival..."
                                  : "Arrived",
                              onPressed: isMarkingArrived
                                  ? () {}
                                  : () => _markArrived(rideData.bookingId?.toString() ?? ''),
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
                                  AnimatedTopToast.show(
                                    context: context,
                                    message: "Please enter the 4-digit OTP.",
                                    backgroundColor: ColorResources.redbuttoncolor,
                                    icon: Icons.error_rounded,
                                  );
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

                                  // Stay on this screen, show End Ride button
                                  if (mounted) {
                                    setState(() {
                                      isOtpVerified = true;
                                    });
                                  }

                                  // Uber/Rapido-style handoff to real Google
                                  // Maps turn-by-turn now that the ride is
                                  // actually underway — isOtpVerified is
                                  // true above, so _navTarget now resolves
                                  // to the drop coordinates, not the pickup.
                                  unawaited(
                                    _startGoogleMapsNavigation(
                                      _navTarget(rideData),
                                    ),
                                  );
                                } else {
                                  // Was silently ignored — tapping Start Ride
                                  // with a wrong code did nothing at all, no
                                  // toast, no field reset, nothing to tell
                                  // the driver why the button appeared to do
                                  // nothing. The OTP is checked entirely
                                  // client-side against rideData.otp (see the
                                  // `if` above), so this is the one place
                                  // that can ever catch a wrong code — there
                                  // is no backend round trip to report it
                                  // from instead.
                                  AnimatedTopToast.show(
                                    context: context,
                                    message: "Incorrect OTP. Please try again.",
                                    backgroundColor: ColorResources.redbuttoncolor,
                                    icon: Icons.error_rounded,
                                  );
                                  _otpController.clear();
                                }
                              },
                            ),
                          ],

                          /// END RIDE BUTTON — shown when ride is ongoing (OTP verified)
                          if (isOtpVerified) ...[
                            const SizedBox(height: 18),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.directions_car, size: 18, color: Colors.green.shade700),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ride is ongoing...',
                                    style: PoppinsSemiBold.copyWith(
                                      fontSize: 13,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            CustomButton(
                              text: "End Ride",
                              onPressed: () {
                                Get.toNamed(
                                  RouteHelper.getstartDriverRideScreen(),
                                  arguments: {"trips": null, "acceptData": data},
                                );
                              },
                            ),
                          ],

                          /// CANCEL RIDE — only shown before OTP is verified
                          if (!isOtpVerified) ...[
                            const SizedBox(height: 10),

                            CustomCancleButton(
                              text: "Cancel Ride",
                              onTap: () {
                                _showCancelBottomSheet(
                                  rideData.bookingId.toString(),
                                );
                              },
                            ),
                          ],
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

  Future<void> _showCancelBottomSheet(String bookingid) async {
    if (bookingid.isEmpty) {
      // No toast — post-accept ride flow is toast-free by design.
      return;
    }

    final controller = Get.find<HomeController>();
    try {
      final response = await controller.cancleRideReason();
      final succeeded =
          response.statusCode == 200 &&
          response.body != null &&
          response.body['code']?.toString() == '200';
      if (!succeeded || controller.cancleReasonModelList.isEmpty) {
        return;
      }
    } catch (_) {
      return;
    }

    Get.bottomSheet(
      CancelRideBottomSheet(bookingId: bookingid),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enterBottomSheetDuration: const Duration(milliseconds: 400),
      exitBottomSheetDuration: const Duration(milliseconds: 300),
    );
  }
}
