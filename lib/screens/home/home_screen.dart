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
import 'package:myridedriverapp/services/nav_overlay_service.dart';
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
    // Was checkLocationPermission() — this screen's own full copy of a
    // permission-check → request → getCurrentPosition() → getPositionStream()
    // pipeline, entirely separate from HomeController.startLocationUpdates(),
    // which is already running by this point (HomeController is fetched via
    // Get.find() in this State's field initializers, which runs its onInit()
    // — and with it startLocationUpdates() — before initState() ever fires).
    //
    // Both pipelines called Geolocator.requestPermission() independently.
    // On a genuinely first-ever launch (no permission decision made yet),
    // that meant two concurrent requests for the same native Android
    // permission dialog — a request already in flight when a second one
    // arrives typically fails outright for the second caller instead of
    // queuing behind it. Whichever of the two lost that race got "denied"
    // back, even though the driver had just tapped Allow. Restarting the
    // app "fixed" it for exactly the reason a race does: by then the
    // permission decision was already persisted, so both pipelines' checks
    // agreed immediately and neither needed to call requestPermission() at
    // all.
    //
    // This pipeline also wrote its results into a State-local
    // driverLatitude/driverLongitude of its own without ever calling
    // controller.update() — so even on a run where it won the race and
    // succeeded, it couldn't be what actually put the driver on the map:
    // the marker below reads controller.latitude/longitude, which only
    // HomeController's own pipeline (already the sole writer used
    // everywhere else — pickup_screen, startride_screen) ever updates.
    // Removing the duplicate here doesn't lose anything the app depends on;
    // it removes the only thing that could race it.
    _awaitLocationThenAskOverlayPermission();
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

  /// Asks — once, and only ever from here — for "display over other apps",
  /// which is what lets the floating return-to-app bubble sit over Google
  /// Maps during a ride.
  ///
  /// Presented as a normal explain-then-ask dialog, like the location one
  /// below it. It used to be requested from the pickup screen at the moment
  /// the driver pressed Start Ride, which dropped an unexplained system
  /// Settings screen on them mid-OTP — the worst possible moment, while
  /// they're reading a code off the rider's phone.
  ///
  /// Asked at most once per install: this is a convenience, not a
  /// requirement (rides and Google Maps navigation work identically without
  /// it), so a driver who says no should not be asked again on every launch.
  Future<void> _maybeAskOverlayPermission() async {
    if (await NavOverlayService.hasOverlayPermission()) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(ApiConstants.overlayPermissionAsked) ?? false) return;
    await prefs.setBool(ApiConstants.overlayPermissionAsked, true);

    if (!mounted) return;
    final wantsIt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Show Floating Return Button",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Allow Nride driver to display over other apps, so you get a "
            "floating button to jump straight back here while navigating "
            "in Google Maps.",
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Not Now"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Allow"),
            ),
          ],
        );
      },
    );

    // Only now does the driver get sent to Settings, and only because they
    // asked to be — there is no runtime dialog for this permission, so a
    // Settings trip is the only way to grant it.
    if (wantsIt == true) {
      await NavOverlayService.requestOverlayPermission();
    }
  }

  /// Waits for HomeController's own location pipeline to report a first fix
  /// (or gives up after a bound wait) before offering the overlay opt-in —
  /// preserves the original "location gets the driver's attention first and
  /// alone" ordering without this screen running a second location pipeline
  /// of its own to get there. Polling rather than a real listener/Future
  /// because GetxController doesn't expose "notify me once" for a single
  /// field change — only its blanket update() stream, which this doesn't
  /// need to subscribe to for what is a one-time wait.
  ///
  /// If the wait times out, checks (read-only — never calls
  /// requestPermission() itself) whether the driver is in one of the two
  /// states HomeController's own retry loop can never climb out of on its
  /// own — permission permanently denied, or location services switched
  /// off entirely — and if so, offers a way to Settings. Those states used
  /// to be surfaced by this screen's own now-removed location pipeline;
  /// losing that pipeline (see initState()'s note on why) must not also
  /// lose the driver's only path to noticing and fixing either one.
  Future<void> _awaitLocationThenAskOverlayPermission() async {
    const maxWait = Duration(seconds: 10);
    const pollEvery = Duration(milliseconds: 300);
    final deadline = DateTime.now().add(maxWait);

    while (mounted &&
        controller.latitude == null &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(pollEvery);
    }
    if (!mounted) return;

    if (controller.latitude == null) {
      await _checkForStuckLocationState();
      if (!mounted) return;
    }

    await _maybeAskOverlayPermission();
  }

  Future<void> _checkForStuckLocationState() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      Get.snackbar("Location Disabled", "Please enable location services");
      await Geolocator.openLocationSettings();
      return;
    }

    // Read-only — deliberately not requestPermission(). HomeController's
    // own pipeline (already running) owns every actual permission request;
    // this only ever reads the outcome to decide whether to point the
    // driver at Settings for a state it can't recover from by retrying.
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      Get.snackbar(
        "Permission Denied Forever",
        "Enable location permission from app settings",
      );
      await Geolocator.openAppSettings();
    }
  }

  @override
  void dispose() {
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
