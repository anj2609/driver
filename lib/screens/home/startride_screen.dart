import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/driver_controller.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';

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

  // (_liveEtaSeconds/_liveDistanceMeters lived here to receive turn-by-turn
  // updates from InAppNavigationMap. This screen no longer renders a map, so
  // there is nothing feeding or reading them. pickup_screen still uses that
  // widget for the leg to the passenger.)

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

    // No Get.dialog() barrier loader — _isPaymentProcessing already swaps the
    // payment buttons for a CircularProgressIndicator in build(), so this was
    // a second, redundant loader whose only real contribution was getting
    // stuck.
    //
    // Dismissing it depended on `Get.isDialogOpen`, GetX's own bookkeeping,
    // which is not reliable here: it isn't cleared by a stack replacement
    // (rideCompletedMarked -> Get.offAllNamed), and it can still read false in
    // the window before the dialog route has actually been pushed. Whenever it
    // read false the Get.back() was skipped, leaving a non-dismissible barrier
    // over the screen with no way out but restarting the app — the infinite
    // loading reported on "Online Payment".
    try {
      final qrData = await controller.generateOnlineQr(
        context: context,
        bookingId: bookingId,
      );

      if (qrData == null) {
        // generateOnlineQr() shows nothing itself, so without this the driver
        // tapped the button, watched a spinner, and got nothing back. Show the
        // reason it recorded rather than assuming the network was at fault —
        // a rejection from the gateway and a dropped connection need different
        // responses from the driver.
        if (context.mounted) {
          AnimatedTopToast.show(
            context: context,
            message: controller.lastQrError ??
                "Couldn't create the payment QR. Please try again.",
            backgroundColor: ColorResources.redbuttoncolor,
            icon: Icons.error_rounded,
          );
        }
        return;
      }

      if (context.mounted) {
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
      debugPrint('Online payment error: $e');
      if (context.mounted) {
        AnimatedTopToast.show(
          context: context,
          message: "Couldn't start the online payment. Please try again.",
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

    // Tracks whether the ride actually completed successfully, so the
    // `finally` below can't blindly flip the UI to a "ride is done" state
    // on a failure — that mismatch (a "couldn't end ride" failure toast
    // together with the screen switching to the post-payment toggle view
    // as if it had succeeded) was exactly the reported bug. On success,
    // rideCompletedMarked() already shows its own toast and navigates to
    // Home itself (Get.offAllNamed), so there's nothing further to do here.
    bool completed = false;

    // Barrier dialog removed here too — same reason as _openOnlinePayment
    // above, and this path is worse for it: rideCompletedMarked() ends in
    // Get.offAllNamed(), which replaces the stack without clearing GetX's
    // isDialogOpen flag, so the guarded Get.back() below was skipped exactly
    // when a loader had been left behind. _isPaymentProcessing covers the
    // loading state on its own.
    try {
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
      if (mounted) {
        setState(() {
          _isPaymentProcessing = false;
          if (completed) _isPaymentDone = true;
        });
      }
    }
  }

  // Ensures the payment prompt is raised once per ride rather than on every
  // rebuild — build() runs on every HomeController.update(), which is several
  // times a second while the location stream is live.
  bool _paymentPromptShown = false;

  /// Fetches a fresh /trip-detail right before the payment prompt goes up, so
  /// the amount shown is the backend's actual recalculated fare
  /// (`payment.final_amount`) rather than track-booking-ride's last poll —
  /// which, for a ride that ran longer or shorter than quoted, is the
  /// original estimate, not what the rider actually owes. Same endpoint and
  /// field the rider app already reads to show this same number.
  ///
  /// Falls back to [fallbackFare] if the fetch fails or genuinely has
  /// nothing better to offer, so a slow/failed request never blocks the
  /// prompt from appearing at all.
  Future<void> _promptPaymentWithFinalFare(
    HomeController controller,
    String bookingId,
    String fallbackFare,
  ) async {
    String resolvedFare = fallbackFare;

    try {
      final profileController = Get.find<ProfileController>();
      await profileController.tripRideDetailsApi(
        context: context,
        bookingid: bookingId,
      );
      final finalAmount = profileController.tripDetailsModel?.data?.finalAmount;
      if (finalAmount != null && finalAmount > 0) {
        resolvedFare = finalAmount.toStringAsFixed(2);
      }
    } catch (e) {
      debugPrint('[StartRide] fetching final fare failed, using fallback: $e');
    }

    if (!mounted) return;
    await _showPaymentPrompt(controller, bookingId, resolvedFare);
  }

  /// Raises the end-of-ride payment prompt.
  ///
  /// This replaces the inline Online/Cash buttons that used to sit in a bottom
  /// sheet over the navigation map. Both are gone from this screen now: the
  /// fare, the closing message and the payment choice all live here instead.
  ///
  /// The dialog closes before either handler runs, so the QR sheet isn't
  /// stacked on top of it and neither handler has to reason about a dialog it
  /// didn't open — that coupling is what produced the stranded barrier loaders
  /// this screen kept getting stuck behind.
  Future<void> _showPaymentPrompt(
    HomeController controller,
    String bookingId,
    String totalFare,
  ) async {
    if (!mounted) return;

    final String? choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 46,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Ride complete',
              style: PoppinsBold.copyWith(fontSize: 19, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'Hope you enjoyed the ride! Collect the fare to finish up.',
              textAlign: TextAlign.center,
              style: PoppinsReguler.copyWith(
                fontSize: 13.5,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: ColorResources.appColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    'Amount to collect',
                    style: PoppinsReguler.copyWith(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹ $totalFare',
                    style: PoppinsBold.copyWith(
                      fontSize: 27,
                      color: ColorResources.appColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
        actions: [
          Row(
            children: [
              Expanded(
                child: CustomPrimaryButton(
                  text: 'Online Payment',
                  fontSize: 13,
                  onTap: () => Navigator.of(dialogCtx).pop('online'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomPrimaryButton(
                  text: 'Cash Payment',
                  fontSize: 13,
                  onTap: () => Navigator.of(dialogCtx).pop('cash'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == 'online') {
      await _openOnlinePayment(controller, bookingId);
    } else {
      await _completeCashRide(controller, bookingId, totalFare);
    }

    // A successful payment navigates away on its own (rideCompletedMarked and
    // OnlinePaymentSheet both call Get.offAllNamed). Still being here means it
    // failed or the driver backed out, so offer the choice again instead of
    // stranding them on a screen with no way to collect.
    if (mounted && !_isPaymentDone) {
      setState(() => _paymentPromptShown = false);
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
            // Live stream position first — driverLatitude here is a single
            // getCurrentPosition() from initState that is never refreshed,
            // so it froze the ETA at the moment the ride started and left it
            // unwritten entirely whenever that one call failed. Same fix as
            // pickup_screen; see the note there.
            controller.calculateETA(
              driverLat: controller.latitude ?? driverLatitude,
              driverLng: controller.longitude ?? driverLongitude,
              userLat: data.data!.dropLat,
              userLng: data.data!.dropLng,
            );
          });

          final bookingId = data.data!.bookingId.toString();
          // track-booking-ride's own total_fare is whatever was last polled
          // (up to ~15s stale) and, per the rider app's own trip-detail
          // model, isn't where the backend actually reports the recalculated
          // fare — /trip-detail's `payment.final_amount` is. Used as the
          // fallback only until that fresher figure is fetched below.
          final fallbackFare = data.data?.totalFare?.toString() ?? '0';

          // The Online/Cash buttons and the bottom sheet that held them are
          // gone from this screen; the fare, the closing message and the
          // payment choice are raised in a dialog instead (see
          // _showPaymentPrompt). Fired from a post-frame callback because
          // build() runs on every HomeController.update() — several times a
          // second while the location stream is live — and _paymentPromptShown
          // keeps that to one prompt per ride.
          if (!_paymentPromptShown && !_isPaymentDone && !_isPaymentProcessing) {
            _paymentPromptShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _promptPaymentWithFinalFare(controller, bookingId, fallbackFare);
            });
          }

          return Stack(
            children: [
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


              // Shown while a payment is in flight. The dialog has already
              // closed by this point, so without something here the driver
              // would be looking at a bare screen with no sign anything is
              // happening.
              if (_isPaymentProcessing)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(child: PremiumBlurLoader()),
                  ),
                ),

              // Payment settled. rideCompletedMarked/OnlinePaymentSheet
              // normally navigate Home themselves, so this is only visible in
              // the brief window before that lands — or if it didn't.
              if (_isPaymentDone)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                        18, 18, 18, 18 + MediaQuery.of(context).padding.bottom),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: _buildPostPaymentToggle(controller),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
