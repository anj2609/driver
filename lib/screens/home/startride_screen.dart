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
import 'package:myridedriverapp/widgets/online_payment_sheet.dart';
import 'package:myridedriverapp/widgets/onlineoffline_custombutton.dart';
import 'package:myridedriverapp/widgets/toaster_animation.dart';

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
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[StartRide] Location error: $e');
    }
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

      if (Get.isDialogOpen ?? false) Get.back();

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
        // Sheet dismissed — payment flow done; show toggle-only view
        if (mounted) setState(() => _isPaymentDone = true);
      } else if (qrData == null && context.mounted) {
        AnimatedTopToast.show(
          context: context,
          message: 'Could not initiate online payment. Please try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      debugPrint('Online payment error: $e');
      if (context.mounted) {
        AnimatedTopToast.show(
          context: context,
          message: 'Failed to generate QR. Please try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
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

    try {
      Get.dialog(
        const Center(child: PremiumBlurLoader()),
        barrierDismissible: false,
      );

      await controller.rideCompletedMarked(
        context: context,
        bookingId: bookingId,
        source: 'offline',
      );
    } catch (e) {
      debugPrint('Cash payment error: $e');
      if (context.mounted) {
        AnimatedTopToast.show(
          context: context,
          message: 'Failed to complete ride. Please try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
    } finally {
      if (Get.isDialogOpen ?? false) { Get.back(); }
      if (mounted) {
        setState(() {
          _isPaymentProcessing = false;
          _isPaymentDone = true;
        });
      }
    }
  }

  Widget _buildPostPaymentToggle(HomeController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: OnlineToggleButton(
        isOnline: controller.isOnline,
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

          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.calculateETA(
              driverLat: driverLatitude,
              driverLng: driverLongitude,
              userLat: data.data!.lat,
              userLng: data.data!.lng,
            );
          });

          final bookingId = data.data!.bookingId.toString();
          final totalFare = data.data?.totalFare?.toString() ?? '0';

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: pickupLatLng ?? LatLng(28.6139, 77.2090),
                  zoom: 14,
                ),
                onMapCreated: (controllerMap) {
                  mapController = controllerMap;

                  if (driverLatitude != null && driverLongitude != null) {
                    controller.getRouteCoordinates(
                      startLat: driverLatitude!,
                      startLng: driverLongitude!,
                      endLat: data.data!.lat,
                      endLng: data.data!.lng,
                    );

                    mapController!.animateCamera(
                      CameraUpdate.newLatLngBounds(
                        LatLngBounds(
                          southwest: LatLng(
                            min(driverLatitude!, data.data!.lat!),
                            min(driverLongitude!, data.data!.lng!),
                          ),
                          northeast: LatLng(
                            max(driverLatitude!, data.data!.lat!),
                            max(driverLongitude!, data.data!.lng!),
                          ),
                        ),
                        100,
                      ),
                    );
                  }
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
                                        controller.estimateDuration.isNotEmpty
                                            ? controller.estimateDuration
                                            : '—',
                                        style: PoppinsSemiBold.copyWith(
                                          fontSize: 12,
                                          color: Colors.orange.shade800,
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
