import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/controllers/driver_controller.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';

import 'package:myridedriverapp/model/trip_model.dart';
import 'package:myridedriverapp/screens/ride/trip_request_screen.dart';
import 'package:myridedriverapp/services/in_app_navigation_service.dart';
import 'package:myridedriverapp/services/nav_overlay_service.dart';
import 'package:myridedriverapp/services/oem_overlay_support.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    // Pre-warm the Navigation SDK here rather than only at the tail of
    // _maybeAskOverlayPermission(), which is where it used to live exclusively.
    //
    // That placement is what made in-app navigation look like it had been
    // reverted: the SDK's terms dialog is mandatory before any session can
    // start, ride-time callers deliberately refuse to show it (see
    // InAppNavigationService.ensureSession), and the *only* thing that ever
    // showed it sat behind a ten-second location wait, an overlay-permission
    // dialog, an optional trip out to system Settings and a battery-
    // optimisation dialog — each with its own `if (!mounted) return`. A driver
    // who took a ride during that window, or backed out of any of those
    // screens, never accepted the terms; and with terms unaccepted every
    // single ride falls through to the external Google Maps handoff, on every
    // launch, forever. That is the reported "it goes to Google Maps again".
    //
    // Called unconditionally and first instead. It is a no-op once the driver
    // has accepted (acceptance persists in the SDK), and it cannot block the
    // permission chain above because it does not await it.
    unawaited(InAppNavigationService.prepareAheadOfFirstRide());

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

  /// Asks, on every app start, for "display over other apps" — until it is
  /// actually granted.
  ///
  /// This used to be a "once per install" ask: decline it a single time and
  /// it was never offered again, on the reasoning that it only gated the
  /// floating return-to-app bubble — a convenience, not something rides or
  /// navigation depended on. That reasoning no longer holds: this same
  /// permission is now what the incoming-ride-request overlay needs to show
  /// a new ride at all while this app is not the one in the foreground (see
  /// NavOverlayService.showIncomingRideRequest). A driver who declined it
  /// once, back when it only meant "no floating button," would otherwise
  /// have silently opted out of ever seeing a new ride pop up outside the
  /// app too — with nothing telling them that is what "Not Now" actually
  /// cost them. Re-asking every launch until it is granted is deliberate:
  /// this is close enough to a real requirement now that it deserves to
  /// keep coming back, not fade into a permanently-declined flag no one
  /// remembers setting.
  ///
  /// Presented as a normal explain-then-ask dialog, like the location one
  /// below it. It used to be requested from the pickup screen at the moment
  /// the driver pressed Start Ride, which dropped an unexplained system
  /// Settings screen on them mid-OTP — the worst possible moment, while
  /// they're reading a code off the rider's phone.
  /// Gated on the *probe*, not on Android's app-op. On MIUI/ColorOS/Funtouch
  /// the app-op reads as granted while the vendor's own gate still refuses
  /// the window, so the old `hasOverlayPermission()` check here meant a
  /// driver who had granted the AOSP toggle and nothing else was never asked
  /// again — and never told that the toggle they'd flipped wasn't the one
  /// blocking them. See NavOverlayService.canActuallyShowOverlay.
  Future<void> _maybeAskOverlayPermission() async {
    if (await NavOverlayService.canActuallyShowOverlay()) {
      // Overlay is genuinely working. Still worth asking about battery
      // optimisation — an OEM battery manager that kills the overlay's
      // foreground service takes the bubble down mid-ride.
      await _maybeAskBatteryOptimisation();
      // Reached on the happy path too, so a driver whose overlay works still
      // gets the navigation terms out of the way before their first ride
      // rather than during it.
      if (mounted) {
        unawaited(InAppNavigationService.prepareAheadOfFirstRide());
      }
      return;
    }

    await OemOverlaySupport.logOverlayDiagnosis();
    final guidance = await OemOverlaySupport.guidance_();
    // True in the case worth calling out explicitly: Android says granted,
    // the window was still refused. Telling this driver to "allow display
    // over other apps" would be telling them to do what they already did.
    final vendorGateIsTheBlocker =
        await NavOverlayService.hasOverlayPermission();

    if (!mounted) return;
    final wantsIt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            vendorGateIsTheBlocker
                ? "One More Setting Needed"
                : "Show Ride Requests Over Other Apps",
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vendorGateIsTheBlocker
                      ? "Your ${guidance.brandLabel} phone needs a second "
                            "permission that \"Display over other apps\" "
                            "doesn't cover. Without it we can't show a new "
                            "ride while you're in another app, and the "
                            "floating return button won't appear."
                      : "Allow Nride driver to display over other apps. This "
                            "is what shows you a new ride request even while "
                            "you're using another app, and gives you a "
                            "floating button to jump straight back here "
                            "while navigating.",
                  textAlign: TextAlign.left,
                ),
                // Written out as well as deep-linked. The deep link lands on
                // the right screen on the skins whose component names are
                // known, but those names change between skin versions — and
                // a driver who arrives on an unexpected screen with no idea
                // what they were looking for is stuck. The steps cost
                // nothing and are the difference between "buried" and
                // "impossible".
                if (guidance.hasExtraSteps) ...[
                  const SizedBox(height: 14),
                  Text(
                    "On ${guidance.brandLabel}:",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ...guidance.steps.map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text("•  $step"),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  "You'll still get a notification for every ride either "
                  "way — this only adds the on-screen popup.",
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Not Now"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Open Settings"),
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

      // Autostart is a second, separate trip, and only on skins that have
      // such a screen. Not bundled into the one above because two Settings
      // screens opened back to back means the second replaces the first
      // before the driver has touched anything — so this waits for them to
      // come back to the app, which is what mounted-after-await detects.
      if (guidance.needsAutoStart && mounted) {
        await _maybeOpenAutoStartSettings(guidance);
      }
    }

    if (mounted) await _maybeAskBatteryOptimisation();

    // Last, and off the ride path on purpose. The Navigation SDK's terms
    // dialog is mandatory before any guidance can start, and collecting it
    // here is what stops it being collected mid-ride — where it blocked
    // navigation from appearing for five minutes on a reported trip. See
    // InAppNavigationService.prepareAheadOfFirstRide.
    if (mounted) unawaited(InAppNavigationService.prepareAheadOfFirstRide());

    // No flag latched on decline, on either branch above — see this
    // method's own doc comment on why this is now asked every launch until
    // actually granted, rather than remembered as a permanent "no". A
    // driver who taps Allow, lands on the system Settings page (buried
    // under every installed app) and backs out without finding the toggle
    // is not meaningfully different from a driver who tapped "Not Now" —
    // both still lack the permission, and both get asked again next time,
    // which self-corrects the "granted it but the toggle didn't stick"
    // case for free.
  }

  /// Offers the skin's autostart / background-launch manager, which is what
  /// keeps the overlay's foreground service alive once this app is
  /// backgrounded — which it always is while the bubble matters, since
  /// launching Google Maps is what backgrounds it.
  Future<void> _maybeOpenAutoStartSettings(
    OemOverlayGuidance guidance,
  ) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Allow Nride To Run In Background",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "${guidance.brandLabel} phones stop apps from running once you "
          "switch away. Enable Nride driver in the autostart list so ride "
          "requests still reach you while you're navigating.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Skip"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Open"),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    final opened = await OemOverlaySupport.openAutoStartSettings();
    if (opened == null) {
      debugPrint(
        '[HomeScreen] no autostart screen on this device — nothing to open',
      );
    }
  }

  /// Asks to be exempted from battery optimisation, via the system's own
  /// one-tap dialog.
  ///
  /// Separate from the overlay ask and reached from both of its branches,
  /// because this matters even where the overlay works perfectly: the bubble
  /// is hosted by a foreground service, and a battery manager that kills
  /// that service removes a bubble the driver was already looking at. It also
  /// protects the location pipeline for the same reason.
  ///
  /// No dialog of our own in front of it — ACTION_REQUEST_IGNORE_BATTERY_
  /// OPTIMIZATIONS *is* a system dialog with its own explanation and its own
  /// Deny button, so wrapping it in a second confirmation just adds a tap.
  /// SharedPreferences flag recording that this driver has been shown the
  /// battery-optimisation dialog once. Version-suffixed so a future change of
  /// mind about the policy can re-ask everyone deliberately.
  static const String _batteryAskedKey = 'batteryOptimisationAskedKey_v1';

  Future<void> _maybeAskBatteryOptimisation() async {
    // Already exempt — nothing to ask for. Checked before the latch so a
    // driver who grants it never burns the one ask.
    if (await OemOverlaySupport.isIgnoringBatteryOptimizations()) return;

    // Asked at most ONCE per install, and this latch is the whole point.
    //
    // The obvious implementation — re-ask whenever the app isn't exempt, the
    // way the overlay permission above deliberately does — turned into a
    // dialog on every single launch that drivers could not get rid of, and
    // that is what it was reported as. Two independent reasons, and both are
    // permanent states rather than transient ones:
    //
    //  - On the OEM skins this matters most for, the driver granting
    //    "allow background activity" in the vendor's own battery settings
    //    does NOT set the AOSP whitelist that
    //    PowerManager.isIgnoringBatteryOptimizations reads. So a driver who
    //    has genuinely done what we asked still reads as un-exempt forever,
    //    and got re-asked forever, with no action available that would
    //    silence it. Measured on the Vivo test device.
    //  - A driver who taps Deny has made a decision. The system dialog
    //    itself tells them they can change it later in Settings, so nagging
    //    adds nothing they weren't already told.
    //
    // The exemption is an optimisation, not a requirement: the foreground
    // service and the notification fallback both work without it. That is
    // what makes one ask the right trade — unlike the overlay permission,
    // where re-asking buys a feature that is otherwise entirely absent.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_batteryAskedKey) ?? false) {
      debugPrint(
        '[HomeScreen] battery-optimisation exemption still not granted, but '
        'the driver has already been asked once — not re-prompting.',
      );
      return;
    }
    // Latched BEFORE showing it, not after. The dialog hands control to the
    // system and this method does not survive to see the outcome reliably —
    // latching afterwards left a window where a driver who backgrounded the
    // app from the dialog was never recorded as asked, and got it again.
    await prefs.setBool(_batteryAskedKey, true);

    await OemOverlaySupport.requestIgnoreBatteryOptimizations();
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
