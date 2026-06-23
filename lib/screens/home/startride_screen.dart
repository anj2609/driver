import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/driver_controller.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';

import 'package:myridedriverapp/screens/home/ridedetails_screen.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

class StartDriverRideScreen extends StatefulWidget {
  // final NewBookingNearByModel? trips;
  // final AcceptRideModel? acceptData;
  const StartDriverRideScreen({
    super.key,

    /// this.trips, this.acceptData
  });

  @override
  State<StartDriverRideScreen> createState() => _StartDriverRideScreenState();
}

class _StartDriverRideScreenState extends State<StartDriverRideScreen> {


  LatLng driverLocation = const LatLng(28.6139, 77.2090); // Default Delhi
  LatLng pickupLocation = const LatLng(28.6160, 77.2100);
  bool isDriveStarted = false;
  final DriveController controller = Get.put(DriveController());
  LatLng? pickupLatLng;
  bool isInitialized = false;
  GoogleMapController? mapController;
  bool isNavigating = false;

  Set<Marker> markers = {};

  @override
  void initState() {
    super.initState();

    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    driverLocation = LatLng(position.latitude, position.longitude);

    _setMarkers();
    setState(() {});
  }

  void _setMarkers() {
    markers = {
      Marker(
        markerId: const MarkerId("driver"),
        position: driverLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        markerId: const MarkerId("pickup"),
        position: pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  @override
  void dispose() {
    final controller = Get.find<HomeController>();

    controller.stopLiveTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<HomeController>(
        builder: (controller) {
          final data = controller.trackRideModel;

          if (data == null) {
            return Center(child: PremiumBlurLoader());
          }
          //print()
          controller.calculateETA(
            driverLat: driverLatitude,
            driverLng: driverLongitude,
            userLat:
                //widget.trips!.pickupLat ??
                data.data!.lat,
            userLng:
                //widget.trips!.pickupLng ??
                data.data!.lng,
          );

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: pickupLatLng ?? LatLng(28.6139, 77.2090),
                  zoom: 14,
                ),

                onMapCreated: (controllerMap) {
                  mapController = controllerMap;

                  controller.getRouteCoordinates(
                    startLat: driverLatitude!,
                    startLng: driverLongitude!,
                    endLat:
                        //widget.trips!.dropLat ??
                        data.data!.lat,
                    endLng:
                        //widget.trips!.dropLng ??
                        data.data!.lng,
                  );

                  // controller.startLiveTracking(
                  //   widget.trips!.dropLat!,
                  //   widget.trips!.dropLng!,
                  // );

                  mapController!.animateCamera(
                    CameraUpdate.newLatLngBounds(
                      LatLngBounds(
                        southwest: LatLng(
                          min(
                            driverLatitude!,
                            data.data!.lat!,
                            //widget.trips!.dropLat!
                          ),
                          min(
                            driverLongitude!,
                            data.data!.lng!,
                            //widget.trips!.dropLng!
                          ),
                        ),
                        northeast: LatLng(
                          max(
                            driverLatitude!,
                            data.data!.lat!,
                            //widget.trips!.dropLat!
                          ),
                          max(
                            driverLongitude!,
                            data.data!.lng!,
                            // widget.trips!.dropLng!
                          ),
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

              Positioned(
                top: 60,
                left: 16,
                right: 16,

                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ColorResources.appColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data.data!.pickupaddress ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: PoppinsReguler.copyWith(
                                color: ColorResources.whiteColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Row(
                      //   children: [
                      //     Icon(Icons.location_on, color: Colors.white),
                      //     SizedBox(width: 8),
                      //     Text(
                      //       "${widget.trips!.pickupAddress}  Point",
                      //       maxLines: 2,
                      //       overflow: TextOverflow.ellipsis,

                      //       style: PoppinsReguler.copyWith(
                      //         color: ColorResources.whiteColor,
                      //         fontSize: 12,
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      SizedBox(height: 8),
                      Text(
                        '${data.data!.dropaddress}',

                        // ' ${widget.trips!.dropAddress}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,

                        style: PoppinsReguler.copyWith(
                          color: ColorResources.whiteColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                bottom: 15,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Chip(
                                  label: controller.totaltime.isEmpty
                                      ? Text('0 Min')
                                      : Text('${controller.totaltime} min'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 22,
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              '${data.data!.dropaddress}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: PoppinsReguler.copyWith(
                                color: ColorResources.blackcolor11,
                                fontSize: 13,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          GestureDetector(
                            onTap: () async {
                              String? id;
                              setState(() {
                                id = data.data?.bookingId?.toString() ?? "";
                                bookingIdStore = data.data?.bookingId
                                    ?.toString();
                              });
                              if (isNavigating) return;

                              isNavigating = true;

                              try {
                                 showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) =>  PremiumBlurLoader(),
                            );

                                await Get.toNamed(
                                  RouteHelper.getbookingTripDetailsScreen(),
                                  arguments: {"booking_id": id},
                                  preventDuplicates: true,
                                );
                              } finally {
                                if (Get.isDialogOpen ?? false) {
                                  Get.back();
                                }
                                isNavigating = false;
                              }

                              // try {
                              //   await Get.toNamed(
                              //     RouteHelper.getbookingTripDetailsScreen(),
                              //     arguments: {"booking_id": id},
                              //     preventDuplicates: true,
                              //   );
                              // } finally {
                              //   isNavigating = false;
                              // }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ColorResources.blackcolor11,
                                ),
                              ),
                              child: Text(
                                "Ride Details",
                                style: PoppinsSemiBold.copyWith(
                                  color: ColorResources.blackcolor11,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      Row(
                        children: [
                          /// Online Payment Button (Disabled)
                          Expanded(
                            child: Expanded(
                              child: CustomDisabledButton(
                                text: "Online Payment",
                                onTap: () {
                                  debugPrint("Offline Payment");
                                },
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          /// Offline Payment Button
                          Expanded(
                            child: CustomPrimaryButton(
                              text: 'Offline Payment',
                              onTap: () async {
                                debugPrint(
                                  'testing booking id ${data.data!.bookingId}',
                                );

                                // controller.rideCompletedMarked(
                                //   context: context,
                                //   bookingId: data.data!.bookingId
                                //       .toString(),
                                // );
                                try {
                                  Get.dialog(
                                    const Center(child: PremiumBlurLoader()),
                                    barrierDismissible: false,
                                  );

                                  await controller.rideCompletedMarked(
                                    context: context,
                                    bookingId: data.data!.bookingId.toString(),
                                  );
                                } catch (e) {
                                  debugPrint('rideCompletedMarked Error: $e');
                                } finally {
                                  if (Get.isDialogOpen ?? false) {
                                    Get.back();
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      /////// Get.find<HomeController>().rideCompletedMarked(
                      //   context: context,
                      //   bookingId: widget.acceptData!.data!.bookingId.toString(),
                      // );
                      // CustomPrimaryButton(
                      //   text: "Pay Now",

                      //   //text: "Complete My Ride",
                      //   onTap: () {
                      //    //  print(' Start ridetext trip data  ${widget.acceptData!.data!.bookingId}');
                      //    // print('testing mode ||||| ${widget.acceptData}');
                      //     Get.toNamed(RouteHelper.getpaymentScreen(),
                      //     arguments: widget.acceptData!.data

                      //     );
                      //   },
                      // ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
