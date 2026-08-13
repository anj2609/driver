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
import 'package:myridedriverapp/widgets/inapp_navigation_map.dart';
import 'package:myridedriverapp/widgets/online_payment_sheet.dart';
import 'package:myridedriverapp/widgets/onlineoffline_custombutton.dart';

class StartDriverRideScreen extends StatefulWidget {
  const StartDriverRideScreen({super.key});

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
  bool _isPaymentProcessing = false;
  bool _isPaymentDone = false;

  // Live, route-aware ETA/distance from InAppNavigationMap's turn-by-turn
  // engine — preferred over controller.estimateDuration/estimateDistance
  // (a separate, often-empty estimate flow) once available.
  int? _liveEtaSeconds;
  double? _liveDistanceMeters;

  // Guards the one-off controller.getRouteCoordinates() call below — that
  // call exists purely to keep the separate "Ride Details" screen (which
  // reads controller.markers/polylines passively, with no fetch of its
  // own) fed with a route. It used to be fired from a widget that
  // re-triggered on every rebuild — and since getRouteCoordinates() itself
  // calls update(), that was an infinite rebuild loop (rebuild -> fetch ->
  // update() -> rebuild -> ...) pegging this screen the moment it opened,
  // which is what made it appear to hang on a blank screen. One real fetch
  // per screen visit is all "Ride Details" actually needs.
  bool _didFetchRouteForDetails = false;

  Set<Marker> markers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      driverLatitude = position.latitude;
      driverLongitude = position.longitude;
      driverLocation = LatLng(position.latitude, position.longitude);

      _setMarkers();
      _fetchRouteForDetailsScreenOnce();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[StartRide] Location error: $e');
    }
  }

  void _fetchRouteForDetailsScreenOnce() {
    if (_didFetchRouteForDetails) return;
    if (driverLatitude == null || driverLongitude == null) return;
    final dropLat = Get.find<HomeController>().trackRideModel?.data?.dropLat;
    final dropLng = Get.find<HomeController>().trackRideModel?.data?.dropLng;
    if (dropLat == null || dropLng == null) return;
    _didFetchRouteForDetails = true;
    Get.find<HomeController>().getRouteCoordinates(
      startLat: driverLatitude!,
      startLng: driverLongitude!,
      endLat: dropLat,
      endLng: dropLng,
    );
  }

  String _formatEta(int seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return '${hours}h ${rem}m';
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

  /// Opens the online payment bottom sheet with QR code
  Future<void> _openOnlinePayment(HomeController controller, String bookingId) async {
    if (_isPaymentProcessing) return;
    setState(() => _isPaymentProcessing = true);

    try {
      Get.dialog(
        const Center(child: PremiumBlurLoader()),
        barrierDismissible: false,
      );

      final qrData = await controller.generateOnlineQr(
        context: context,
        bookingId: bookingId,
      );

      if (mounted && (Get.isDialogOpen ?? false)) Get.back();

      if (qrData != null && context.mounted) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: false,
          builder: (_) => OnlinePaymentSheet(
            bookingId: bookingId,
            qrData: qrData,
            homeController: controller,
          ),
        );
        // On a genuinely confirmed payment, OnlinePaymentSheet itself already
        // navigates to Home (Get.offAllNamed) before this await resolves —
        // this screen is unmounted by then, so there's nothing to do here.
        // If we get here still mounted, the sheet was dismissed WITHOUT a
        // confirmed payment (closed/backed out) — stay on this same ride
        // screen so the driver can retry, rather than flipping to a
        // "payment done" toggle view for a payment that never happened.
      }
    } catch (e) {
      if (mounted && (Get.isDialogOpen ?? false)) Get.back();
      debugPrint('Online payment error: $e');
    } finally {
      if (mounted) setState(() => _isPaymentProcessing = false);
    }
  }

  /// Handles cash payment with confirmation dialog
  Future<void> _completeCashRide(HomeController controller, String bookingId, String totalFare) async {
    if (_isPaymentProcessing) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Confirm Cash Payment',
          style: PoppinsSemiBold.copyWith(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.payments_outlined, size: 48, color: Colors.green.shade600),
            ),
            const SizedBox(height: 14),
            Text(
              'Collect ₹$totalFare in cash from the passenger.',
              textAlign: TextAlign.center,
              style: PoppinsReguler.copyWith(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Have you received the cash?',
              textAlign: TextAlign.center,
              style: PoppinsSemiBold.copyWith(fontSize: 15, color: Colors.black),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: PoppinsSemiBold.copyWith(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Yes, Cash Received',
                style: PoppinsSemiBold.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPaymentProcessing = true);

    // Tracks whether the ride actually completed successfully, so the
    // `finally` below can't blindly flip the UI to a "ride is done" state
    // on a failure — that mismatch (a "couldn't end ride" failure toast
    // together with the screen switching to the post-payment toggle view
    // as if it had succeeded) was exactly the reported bug. On success,
    // rideCompletedMarked() already shows its own toast and navigates to
    // Home itself (Get.offAllNamed), so there's nothing further to do here.
    bool completed = false;

    try {
      Get.dialog(
        const Center(child: PremiumBlurLoader()),
        barrierDismissible: false,
      );

      final response = await controller.rideCompletedMarked(
        context: context,
        bookingId: bookingId,
        source: 'offline',
      );
      final body = response.body;
      completed = response.statusCode == 200 &&
          body != null &&
          (body['code']?.toString() == '200' ||
              body['status'] == true ||
              body['status']?.toString() == 'true' ||
              body['status']?.toString().toLowerCase() == 'success');
    } catch (e) {
      debugPrint('Cash payment error: $e');
    } finally {
      // On success, rideCompletedMarked() already called Get.offAllNamed()
      // above, which unmounts this screen — guarding on `mounted` here
      // means we never fire a stray Get.back() against the Home screen
      // that just replaced this one (GetX's isDialogOpen flag doesn't get
      // cleared by that kind of stack replacement, only by a normal pop).
      if (mounted && (Get.isDialogOpen ?? false)) {
        Get.back();
      }
      if (mounted) {
        setState(() {
          _isPaymentProcessing = false;
          if (completed) _isPaymentDone = true;
        });
      }
    }
  }

  Widget _buildPostPaymentToggle(HomeController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: OnlineToggleButton(
        isOnline: controller.isOnline,
        isLoading: controller.isTogglingOnline,
        onTap: () => controller.toggleOnline(controller.isOnline, context),
      ),
    );
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

          // This screen is the "ride ongoing, heading to drop-off" leg —
          // was routing/computing ETA against data.data!.lat/lng, which is
          // the *pickup* coordinate (already reached by this point in the
          // flow, per acceptride_details_model.dart). Fixed to the actual
          // destination: dropLat/dropLng.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.calculateETA(
              driverLat: driverLatitude,
              driverLng: driverLongitude,
              userLat: data.data!.dropLat,
              userLng: data.data!.dropLng,
            );
          });

          final bookingId = data.data!.bookingId.toString();
          final totalFare = data.data?.totalFare?.toString() ?? '0';

          return Stack(
            children: [
              // Real turn-by-turn navigation to the drop-off point —
              // replaces the old bare GoogleMap. Reuses HomeController's
              // existing GPS stream; doesn't start a second one.
              Positioned.fill(
                child: InAppNavigationMap(
                  destLat: data.data!.dropLat,
                  destLng: data.data!.dropLng,
                  destLabel: 'Drop-off',
                  onArrived: () => debugPrint('[Nav] Arrived at drop-off'),
                  // Leaves room for the address card below, which sits at
                  // the very top like it originally did.
                  topOffset: 130,
                  onUpdate: (snapshot) {
                    if (!mounted) return;
                    setState(() {
                      _liveEtaSeconds = snapshot.remainingDurationSeconds;
                      _liveDistanceMeters = snapshot.remainingDistanceMeters;
                    });
                  },
                ),
              ),

              Positioned(
                top: 45,
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
                      SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.flag, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${data.data!.dropaddress}',
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
                    ],
                  ),
                ),
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(context).padding.bottom),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -3),
                      ),
                    ],
                  ),
                  child: _isPaymentDone
                      ? _buildPostPaymentToggle(controller)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// Ride info row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _liveEtaSeconds != null
                                            ? _formatEta(_liveEtaSeconds!)
                                            : (controller.estimateDuration.isNotEmpty
                                                ? controller.estimateDuration
                                                : '—'),
                                        style: PoppinsSemiBold.copyWith(
                                          fontSize: 12,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_liveDistanceMeters != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.route_outlined,
                                          size: 14,
                                          color: Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${(_liveDistanceMeters! / 1000).toStringAsFixed(1)} km',
                                          style: PoppinsSemiBold.copyWith(
                                            fontSize: 12,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ColorResources.appColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '₹$totalFare',
                                    style: PoppinsBold.copyWith(
                                      fontSize: 16,
                                      color: ColorResources.appColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

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
                                      bookingIdStore = data.data?.bookingId?.toString();
                                    });
                                    if (isNavigating) return;
                                    isNavigating = true;
                                    try {
                                      await Get.toNamed(
                                        RouteHelper.getbookingTripDetailsScreen(),
                                        arguments: {"bookingId": id},
                                      );
                                    } finally {
                                      isNavigating = false;
                                    }
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

                            const SizedBox(height: 12),

                            /// Payment buttons
                            if (_isPaymentProcessing)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomPrimaryButton(
                                      text: 'Online Payment',
                                      onTap: () => _openOnlinePayment(controller, bookingId),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: CustomPrimaryButton(
                                      text: 'Cash Payment',
                                      onTap: () => _completeCashRide(controller, bookingId, totalFare),
                                    ),
                                  ),
                                ],
                              ),

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
