import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/controllers/driver_controller.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';

import 'package:myridedriverapp/model/trip_model.dart';
import 'package:myridedriverapp/screens/ride/trip_request_screen.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

import 'package:myridedriverapp/widgets/custum_header.dart';
import 'package:myridedriverapp/widgets/onlineoffline_custombutton.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  GoogleMapController? mapController;
  List<TripModel> tripList = [];
  // Was `Get.put(HomeController(homeRepo: Get.find()))` — every other
  // screen in the app (payment_screen, startride_screen, pickup_screen,
  // ridedetails_screen, ...) reaches HomeController via Get.find(),
  // relying on the fenix-managed registration from get_di.dart's
  // init() (called once at app startup) to recreate it on demand if it's
  // ever disposed. Get.put() here re-registered it tied to *this specific
  // screen's* lifecycle instead — GetX disposes a Get.put()'d instance
  // once nothing still on screen references it, and once the driver
  // accepts a ride and navigates away to the pickup screen, nothing left
  // on screen was still bound to this one. pickup_screen.dart's own
  // periodic Get.find<HomeController>() calls (e.g. its status-polling
  // timer, and the Cancel Ride action) would then throw "HomeController
  // not found" the next time they fired, since the fenix registration
  // that should have recreated it had been silently overridden the whole
  // time this screen was ever shown.
  final HomeController controller = Get.find<HomeController>();
  final DriveController controllerdriver = Get.put(DriveController());
  StreamSubscription<Position>? _positionStream;

  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 14,
  );
  // Ensures the one-time auto-center on the driver's real location (see
  // the GoogleMap builder below) only happens once, so it doesn't fight a
  // driver who has since panned/zoomed the map themselves.
  bool _hasCenteredOnDriver = false;
  bool isOnline = false;
  bool isLoading = false;
  Timer? activeRideTimer;

  @override
  void initState() {
    super.initState();
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

  // (startBookingPolling/bookingTimer/stopBookingPolling used to live here —
  // a 60s Timer.periodic that read tripJson/acceptJson from prefs purely to
  // debugPrint them, then called cancleRideReason() and fetchProfile() on
  // every tick, for as long as this screen — the driver's home screen — was
  // open, online or not.
  //
  // Both calls were pure waste. cancleRideReason() fetches
  // cancellation-type-list, static reference data (the list of cancel
  // reasons) that's already fetched once at HomeController init and again
  // on-demand right before every cancel dialog — a 60s poll of it forever in
  // the background added nothing. fetchProfile() hits the same get-profile
  // endpoint HomeController._pollNearbyBookings() already calls every 3s
  // while online (see home_controller.dart) — a completely redundant call
  // to the same data on a slower clock, and one that kept running even while
  // offline, when nothing needed it at all.)

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

  @override
  void dispose() {
    _positionStream?.cancel();
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
          // Was a bare, non-reactive GoogleMap: no marker at all for the
          // driver's own position (myLocationEnabled only draws the native
          // blue dot, which is easy to miss and isn't there at all until
          // the OS/plugin has resolved a fix) and the camera stayed
          // parked at a hardcoded Delhi coordinate forever — a driver
          // anywhere else would open the app to a map of a city they
          // aren't in, with nothing pointing at where they actually are.
          // Wrapping in GetBuilder<HomeController> lets it react to the
          // controller's already-tracked latitude/longitude (updated by
          // the same location stream that drives the heartbeat) and draw
          // a car marker there, using the same carIcon loaded for the
          // trip-tracking screens.
          GetBuilder<HomeController>(
            builder: (controller) {
              Set<Marker> markers = {};
              if (controller.latitude != null && controller.longitude != null) {
                final driverLatLng = LatLng(
                  controller.latitude!,
                  controller.longitude!,
                );
                markers.add(
                  Marker(
                    markerId: const MarkerId('driver_current_location'),
                    position: driverLatLng,
                    icon: controller.carIcon ?? BitmapDescriptor.defaultMarker,
                    anchor: const Offset(0.5, 0.5),
                    infoWindow: const InfoWindow(title: 'You'),
                  ),
                );

                // Center on the driver's real position the first time it's
                // available, instead of leaving the camera sitting on the
                // hardcoded default — but only once, so it doesn't fight a
                // driver who has since panned/zoomed the map themselves.
                if (!_hasCenteredOnDriver && mapController != null) {
                  _hasCenteredOnDriver = true;
                  mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(driverLatLng, 16),
                  );
                }
              }

              return GoogleMap(
                initialCameraPosition: _initialPosition,
                onMapCreated: (gmController) {
                  mapController = gmController;
                  if (!_hasCenteredOnDriver &&
                      controller.latitude != null &&
                      controller.longitude != null) {
                    _hasCenteredOnDriver = true;
                    gmController.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(controller.latitude!, controller.longitude!),
                        16,
                      ),
                    );
                  }
                },
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
              );
            },
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
                  isLoading: controller.isTogglingOnline,
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
                    color: Color(0xFFF5F7FA),
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
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: controller.isOnline
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    controller.isOnline
                                        ? "You're Online"
                                        : "You're Offline, please press the toggle button to go online",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

          /// 🔔 INCOMING RIDE REQUEST — a card painted over the live map.
          ///
          /// Mounted here as a sibling rather than pushed as a route on
          /// purpose. The map above is an Android platform view, and platform
          /// views don't composite underneath a non-opaque route — pushing the
          /// request transparently left the driver looking at a blank space
          /// where the map should be. Sitting in this Stack, it just paints on
          /// top of the map that's already there.
          ///
          /// Renders nothing at all when there's no pending request, and its
          /// visibility follows HomeController.incomingTrips directly, so
          /// there's no route lifecycle or open/closed flag to drift.
          const Positioned.fill(child: IncomingBookingScreen()),

          /// 🔥 FULL SCREEN LOADER
          GetBuilder<HomeController>(
            builder: (controller) {
              if (controller.isLoading) {
                return Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Center(
                    child: PremiumBlurLoader(),

                    /// CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }
              return SizedBox();
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
