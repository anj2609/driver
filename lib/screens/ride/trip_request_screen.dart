import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
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

  // Guards the Accept button against a second tap while one accept is
  // already in flight (belt-and-suspenders alongside the controller-level
  // guard in acceptRidesTrip) — see the onTap handler in _rideCard() for
  // the full story on why this mattered.
  bool _isAcceptingTrip = false;

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

  // The controller's own list is the source of truth — widget.trips is only
  // the snapshot at the moment this screen was first pushed. Reading from
  // the controller here means the "Accept"/"X" buttons and any new booking
  // the poll adds while this screen is open are reflected immediately,
  // instead of the screen staying frozen on its original snapshot.
  List<NewBookingNearByModel> get _trips => controller.incomingTrips;

  int get _safeIndex =>
      _trips.isEmpty ? 0 : currentIndex.clamp(0, _trips.length - 1);

  Future<void> _init() async {
    await getCurrentLocation();
    if (_trips.isNotEmpty) await _updateMap();
  }

  Future<void> getCurrentLocation() async {
    await Geolocator.requestPermission();

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    currentDriverLat = position.latitude;
    currentDriverLng = position.longitude;
  }

  Future<void> _updateMap() async {
    if (_trips.isEmpty) return;
    final trip = _trips[_safeIndex];

    markers.clear();
    polylines.clear();

    /// 🔥 Load Custom Icons
    final pickupIcon = await getCustomIcon(
      "assets/images/Vehiclelocation.png",
      200,
    );
    final dropIcon = await getCustomIcon("assets/images/location.png", 200);
    // Was assets/images/profile.png — a circular headshot-style icon for
    // the *driver's own* marker, which is what showed up looking like a
    // person's photo pinned on the map. Reusing the car icon already used
    // for "this is the driver" everywhere else in the app (home screen
    // toggle map, in-app navigation) instead of a face.
    final driverIcon = controller.carIcon ??
        await getCustomIcon("assets/images/ridecar.png", 100);

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
        color: const Color(0xFF123EBC),
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
    return GetBuilder<HomeController>(
      builder: (_) {
        final trips = _trips;

        if (trips.isEmpty) {
          // The last remaining request was rejected/accepted elsewhere —
          // close this screen instead of rendering with nothing to show.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            controller.stopRingtone();
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final safeIndex = _safeIndex;
        final trip = trips[safeIndex];

        return Scaffold(
          body: Stack(
            children: [
              /// 🔵 GOOGLE MAP
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(trip.pickupLat!, trip.pickupLng!),
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
                bottom: MediaQuery.of(context).padding.bottom,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 300,
                  // Re-keying on the trip list forces the PageView (and its
                  // internal controller/scroll position) to reset cleanly
                  // whenever a request is rejected or a new one arrives,
                  // instead of holding onto a stale page index.
                  child: PageView.builder(
                    key: ValueKey(trips.length),
                    controller: PageController(
                      viewportFraction: 0.92,
                      initialPage: safeIndex,
                    ),
                    itemCount: trips.length,
                    onPageChanged: (index) {
                      currentIndex = index;
                      _updateMap();
                    },
                    itemBuilder: (context, index) {
                      return _rideCard(trips[index]);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
                    // Without this, a second tap while the first accept
                    // was still in flight (e.g. while the driver was
                    // waiting for the stuck dialog below to go away) fired
                    // a second, overlapping acceptRidesTrip() for the same
                    // booking.
                    if (_isAcceptingTrip) return;
                    _isAcceptingTrip = true;

                    // Captures the dialog's own BuildContext so it can be
                    // dismissed unambiguously via Navigator.of(dialogContext)
                    // regardless of what else happens to the navigation
                    // stack in between. The old code showed this dialog
                    // with plain showDialog() but dismissed it via
                    // `if (Get.isDialogOpen ?? false) Get.back();` — GetX's
                    // own dialog-open tracking, which is not guaranteed to
                    // reflect a dialog that was never opened through
                    // Get.dialog() in the first place. On top of that,
                    // acceptRidesTrip() navigates to the pickup screen via
                    // Get.offAndToNamed() on success *without* closing this
                    // dialog first, so it could easily be left floating on
                    // top of the new screen — looking exactly like a loading
                    // popup that never goes away, with the only way out
                    // being to back out and land back here to try again.
                    BuildContext? dialogContext;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dCtx) {
                        dialogContext = dCtx;
                        return const PremiumBlurLoader();
                      },
                    );

                    try {
                      final response = await controller.acceptRidesTrip(
                        context: context,
                        bookingId: trip.id.toString(),
                        trips: trip,
                      );

                      // acceptRidesTrip() itself calls Get.offAndToNamed()
                      // on success — which is Navigator.popAndPushNamed()
                      // under the hood, i.e. it pops whatever is currently
                      // on top (at that point, this loading dialog, not
                      // this screen) and pushes the pickup screen in its
                      // place. So on success the dialog is *already gone*
                      // by the time we get here — popping it again via
                      // dialogContext would pop the pickup screen that
                      // just replaced it instead, since Navigator.of()
                      // resolves to the same navigator either way. Only
                      // the non-success paths (busy/401/rejected/error —
                      // none of which navigate anywhere) still have the
                      // dialog sitting on top and actually need it closed
                      // here.
                      final body = response.body;
                      final code = body is Map ? body['code']?.toString() : null;
                      final alreadyNavigatedAway = code == '200';

                      if (!alreadyNavigatedAway &&
                          dialogContext != null &&
                          Navigator.of(dialogContext!).canPop()) {
                        Navigator.of(dialogContext!).pop();
                      }
                    } catch (e) {
                      debugPrint('acceptRidesTrip Error: $e');
                      if (dialogContext != null &&
                          Navigator.of(dialogContext!).canPop()) {
                        Navigator.of(dialogContext!).pop();
                      }
                    } finally {
                      _isAcceptingTrip = false;
                    }
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

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Was a hardcoded local asset — the model never parsed
                    // a customer image at all, so nothing the backend sent
                    // could ever have shown up here regardless.
                    CircleAvatar(
                      radius: 22,
                      backgroundImage:
                          (trip.customerImage != null && trip.customerImage!.isNotEmpty)
                              ? NetworkImage(ApiConstants.imageurl + trip.customerImage!)
                                  as ImageProvider
                              : const AssetImage("assets/images/profile.png"),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Was a hardcoded "Customer" label for the same
                        // reason — the name was never parsed from the
                        // response.
                        Text(
                          trip.customerName?.isNotEmpty == true
                              ? trip.customerName!
                              : "Customer",
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

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Fare was never shown at all — same root cause, the
                    // model had nowhere to hold it.
                    if (trip.fare != null && trip.fare!.isNotEmpty)
                      Text(
                        "₹${trip.fare}",
                        style: PoppinsBold.copyWith(
                          color: ColorResources.appColor,
                          fontSize: 16,
                        ),
                      ),
                    // Same gap as fare — the model never parsed a time
                    // field either, so there was nothing to show here
                    // regardless of what the backend sent.
                    if (trip.time != null && trip.time!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          trip.time!,
                          style: PoppinsReguler.copyWith(
                            color: ColorResources.textColorForGrey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
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
                          color: ColorResources.textColorForGrey,
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
                          color: ColorResources.textColorForGrey,
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
