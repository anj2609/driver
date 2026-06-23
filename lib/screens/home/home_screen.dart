import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/controllers/driver_controller.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/model/acceptride_details_model.dart';
import 'package:myridedriverapp/model/newbooking_nearby_model.dart';

import 'package:myridedriverapp/model/trip_model.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

import 'package:myridedriverapp/widgets/custum_header.dart';
import 'package:myridedriverapp/widgets/onlineoffline_custombutton.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  GoogleMapController? mapController;
  List<TripModel> tripList = [];
  final HomeController controller = Get.put(
    HomeController(homeRepo: Get.find()),
  );
  final DriveController controllerdriver = Get.put(DriveController());
  StreamSubscription<Position>? _positionStream;

  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 14,
  );
  bool isOnline = false;
  bool isLoading = false;
  Timer? activeRideTimer;

  @override
  void initState() {
    super.initState();
    startBookingPolling();
    checkLocationPermission();
    activeRideTimer = Timer(const Duration(seconds: 10), () async {
      if (!mounted) return;

      try {
      await Get.find<HomeController>().driverBookingActives();
      } catch (e) {
        debugPrint("TIMER ERROR => $e");
      }
    });
  }

  Timer? bookingTimer;
  bool isPollingStarted = false;
  bool isApiCalling = false;

  Future<void> startBookingPolling() async {
    if (isPollingStarted) return;

    final prefs = await SharedPreferences.getInstance();

    String? tripJson = prefs.getString(ApiConstants.tripKey);
    String? acceptJson = prefs.getString(ApiConstants.acceptRideKey);

    if (tripJson != null && acceptJson != null) {
      NewBookingNearByModel tripData = NewBookingNearByModel.fromJson(
        jsonDecode(tripJson),
      );

      AcceptRideModel acceptData = AcceptRideModel.fromJson(
        jsonDecode(acceptJson),
      );

      debugPrint("Trip Id: ${tripData.id}");
      debugPrint("Accept Ride Id: ${acceptData.data!.otp}");
    } else {
      debugPrint("No ride data found");
    }

    isPollingStarted = true;

    bookingTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      // Prevent multiple API calls at same time
      if (isApiCalling) return;

      try {
        isApiCalling = true;

        final prefs = await SharedPreferences.getInstance();
        String? userId = prefs.getString(ApiConstants.profileid);

        if (userId == null || userId.isEmpty) {
          return;
        }

        final homeController = Get.find<HomeController>();
        final profileController = Get.find<ProfileController>();

        // Profile API refresh

        //await homeController.driverBookingActives();
        await homeController.cancleRideReason();

        // Profile API
        profileController.fetchProfile();
      } catch (e) {
        debugPrint("Polling Error: $e");
      } finally {
        isApiCalling = false;
      }
    });
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Allow Location Access",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Allow Veyo Driving app your location access for using this App!",
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Don’t Allow"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await checkLocationPermission();
              },
              child: const Text("Allow"),
            ),
          ],
        );
      },
    );
  }

  Future<void> startLocationStream() async {
    try {
      await _positionStream?.cancel();

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        Get.snackbar("Location Disabled", "Please enable location service");

        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          Get.snackbar("Permission Denied", "Location permission is required");
          return;
        }
      }

      /// Permanently denied
      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          "Permission Denied Forever",
          "Enable permission from app settings",
        );

        await Geolocator.openAppSettings();
        return;
      }

      /// Start stream
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            (Position position) {
              driverLatitude = position.latitude;
              driverLongitude = position.longitude;

              // print("📍 Live: ${position.latitude}, ${position.longitude}");
            },

            onError: (error) async {
              if (error.toString().contains("denied")) {
                await _positionStream?.cancel();
              }
            },
          );
    } catch (e) {
      // print("❌ Location Exception: $e");
    }
  }

  Future<void> initLocationFlow() async {
    try {
      Position position = await Geolocator.getCurrentPosition();

      driverLatitude = position.latitude;
      driverLongitude = position.longitude;
      //driverLatitude driverLongitude
      debugPrint("📍 Current: ${position.latitude}, ${position.longitude}");
      debugPrint("📍suchi  Current: $driverLatitude, $driverLongitude");
    } catch (e) {
      debugPrint("❌ Error: $e");
    }
  }

  Future<void> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      debugPrint("❌ Location services are OFF");
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      debugPrint("❌ Permission denied");
      _showLocationDialog();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("❌ Permission permanently denied");
      await Geolocator.openAppSettings();
      return;
    }

    debugPrint("✅ Permission granted");

    await initLocationFlow();
    startLocationStream();
  }

  void stopBookingPolling() {
    bookingTimer?.cancel();
    bookingTimer = null;
    isPollingStarted = false;
  }

  // @override
  // void dispose() {
  //   stopBookingPolling();
  //   super.dispose();
  // }

  @override
  void dispose() {
    stopBookingPolling();
    _positionStream?.cancel();
    bookingTimer?.cancel();
    activeRideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const CustomDrawer(),
      body: Stack(
        children: [
          /// 🔹 Google Map
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) {
              mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      _scaffoldKey.currentState!.openDrawer();
                    },
                    child: circleButton(Icons.menu),
                  ),
                  // Container(
                  //   padding: const EdgeInsets.symmetric(
                  //     horizontal: 18,
                  //     vertical: 8,
                  //   ),
                  //   decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     borderRadius: BorderRadius.circular(20),
                  //   ),
                  //   child: const Text(
                  //     "Tap to see Balance",
                  //     style: TextStyle(fontWeight: FontWeight.w500),
                  //   ),
                  // ),
                  // circleButton(Icons.search),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 120,
            left: 0,
            right: 0,
            child: GetBuilder<HomeController>(
              builder: (controller) {
                return OnlineToggleButton(
                  isOnline: controller.isOnline,
                  onTap: () {
                    controller.toggleOnline(controller.isOnline, context);
                  },
                );
              },
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GetBuilder<HomeController>(
              builder: (controller) {
                return Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    18 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 4,
                        width: 40,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 10,
                                color: controller.isOnline
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                controller.isOnline
                                    ? "You're Online"
                                    : "You're Offline",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Container(
                        height: 4,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          /// 🔥 FULL SCREEN LOADER
          GetBuilder<HomeController>(
            builder: (controller) {
              if (controller.isLoading) {
                return Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child:  Center(
                    child: PremiumBlurLoader()
                    /// CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }
              return  SizedBox();
            },
          ),
        //  PremiumBlurLoader()
        ],
      ),
    );
  }


  Widget circleButton(IconData icon) {
    return Container(
      height: 45,
      width: 45,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.black87),
    );
  }
}
