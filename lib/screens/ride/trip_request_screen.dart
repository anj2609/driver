import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/model/newbooking_nearby_model.dart';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

class IncomingBookingScreen extends StatefulWidget {
  final List<NewBookingNearByModel> trips;

  const IncomingBookingScreen({super.key, required this.trips});

  @override
  State<IncomingBookingScreen> createState() => _IncomingBookingScreenState();
}

class _IncomingBookingScreenState extends State<IncomingBookingScreen> {
  final HomeController controller = Get.find();
  GoogleMapController? mapController;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  int currentIndex = 0;
  double? currentDriverLat;
  double? currentDriverLng;

  // @override
  // void initState() {
  //   super.initState();
  //   _updateMap();
  // }
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await getCurrentLocation();
    await _updateMap();
  }

  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    currentDriverLat = position.latitude;
    currentDriverLng = position.longitude;
  }

  Future<void> _updateMap() async {
    final trip = widget.trips[currentIndex];

    markers.clear();
    polylines.clear();

    /// 🔥 Load Custom Icons
    final pickupIcon = await getCustomIcon(
      "assets/images/Vehiclelocation.png",
      200,
    );
    final dropIcon = await getCustomIcon("assets/images/location.png", 200);
    final driverIcon = await getCustomIcon("assets/images/profile.png", 100);

    markers.add(
      Marker(
        markerId: const MarkerId("pickup"),
        position: LatLng(trip.pickupLat!, trip.pickupLng!),
        icon: pickupIcon,
      ),
    );

    /// 🔴 Drop Marker
    markers.add(
      Marker(
        markerId: const MarkerId("drop"),
        position: LatLng(trip.dropLat!, trip.dropLng!),
        icon: dropIcon,
      ),
    );

    /// 👤 Driver Marker (Null Safe)
    if (currentDriverLat != null && currentDriverLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("driver"),
          position: LatLng(currentDriverLat!, currentDriverLng!),
          icon: driverIcon,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    PolylinePoints polylinePoints = PolylinePoints(
      apiKey: "AIzaSyBNHiJLxFa2qcs079P5TaYrB770_CVMldU",
    );

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(trip.pickupLat!, trip.pickupLng!),
        destination: PointLatLng(trip.dropLat!, trip.dropLng!),
        mode: TravelMode.driving,
      ),
    );

    List<LatLng> routePoints = [];

    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        routePoints.add(LatLng(point.latitude, point.longitude));
      }
    }

    /// 🔵 Curved Polyline
    polylines.add(
      Polyline(
        polylineId: const PolylineId("route"),
        color: Colors.blue,
        width: 6,
        points: routePoints,
      ),
    );

    /// 🎯 Auto Fit Camera (Driver + Pickup + Drop)
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        [
          trip.pickupLat!,
          trip.dropLat!,
          currentDriverLat ?? trip.pickupLat!,
        ].reduce((a, b) => a < b ? a : b),
        [
          trip.pickupLng!,
          trip.dropLng!,
          currentDriverLng ?? trip.pickupLng!,
        ].reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        [
          trip.pickupLat!,
          trip.dropLat!,
          currentDriverLat ?? trip.pickupLat!,
        ].reduce((a, b) => a > b ? a : b),
        [
          trip.pickupLng!,
          trip.dropLng!,
          currentDriverLng ?? trip.pickupLng!,
        ].reduce((a, b) => a > b ? a : b),
      ),
    );

    mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trips[currentIndex];

    return Scaffold(
      body: Stack(
        children: [
          /// 🔵 GOOGLE MAP
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.trips[currentIndex].pickupLat!,
                widget.trips[currentIndex].pickupLng!,
              ),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              mapController = controller;
              _updateMap();
            },
            markers: markers,
            polylines: polylines,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),

          Positioned(
            top: 50,
            right: 20,
            child: CircleAvatar(
              backgroundColor: ColorResources.whiteColor,
              child: IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  controller.rejectTrip(trip);
                },
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 300,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.92),
                itemCount: widget.trips.length,
                onPageChanged: (index) {
                  currentIndex = index;
                  _updateMap();
                },
                itemBuilder: (context, index) {
                  return _rideCard(widget.trips[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideCard(NewBookingNearByModel trip) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColorResources.whiteColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: ColorResources.blackcolor, blurRadius: 12),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffF4C430),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 16),
                      SizedBox(width: 6),
                      Text("New Booking", style: PoppinsReguler),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    try {
                       showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) =>  PremiumBlurLoader(),
                            );

                      await controller.acceptRidesTrip(
                        context: context,
                        bookingId: trip.id.toString(),
                        trips: trip,
                      );
                    } catch (e) {
                      debugPrint('acceptRidesTrip Error: $e');
                    } finally {
                      if (Get.isDialogOpen ?? false) {
                        Get.back();
                      }
                    }
                    // controller.acceptRidesTrip(
                    //   context: context,
                    //   bookingId: trip.id.toString(),
                    //   trips: trip,
                    // );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ColorResources.appColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          color: ColorResources.whiteColor,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Accept",
                          style: PoppinsReguler.copyWith(
                            color: ColorResources.whiteColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            /// ✅ Accept Button
            // CustomPrimaryButton(
            //   text: "Accept",
            //   onTap: () {
            //     controller.acceptRidesTrip(
            //       context: context,
            //       bookingId: trip.id.toString(),
            //       trips: trip,
            //     );

            //   },
            // ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundImage: AssetImage("assets/images/profile.png"),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Customer",
                          style: PoppinsBold.copyWith(
                            color: ColorResources.blackcolor,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14),
                            Text(
                              "${trip.distance?.toStringAsFixed(2) ?? 0} km",
                              style: PoppinsReguler,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                Text(
                  "₹ --",
                  style: PoppinsExtrabold.copyWith(
                    color: ColorResources.blackcolor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ColorResources.appColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 30,
                      color: Colors.blue.shade200,
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ColorResources.appColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pickup",
                        style: PoppinsReguler.copyWith(
                          color: ColorResources.TextColorForGrey,
                        ),
                      ),
                      Text(trip.pickupAddress ?? "N/A", style: PoppinsReguler),

                      const SizedBox(height: 15),

                      Text(
                        "Drop",
                        style: PoppinsReguler.copyWith(
                          color: ColorResources.blackcolor,
                        ),
                      ),
                      Text(
                        trip.dropAddress ?? "N/A",
                        style: PoppinsReguler.copyWith(
                          color: ColorResources.TextColorForGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
