import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? bookingIdStore;

class BookingTripDetailsScreen extends StatefulWidget {
  final String? bookingId;

  const BookingTripDetailsScreen({super.key, this.bookingId});

  @override
  State<BookingTripDetailsScreen> createState() =>
      _BookingTripDetailsScreenState();
}

class _BookingTripDetailsScreenState extends State<BookingTripDetailsScreen> {
  GoogleMapController? mapController;

  LatLng? driverLatLng;
  LatLng? pickupLatLng;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await loaddata();
    });
    // loaddata();
  }

  Future<void> loaddata() async {
    final prefs = await SharedPreferences.getInstance();
    final String bookingId = widget.bookingId?.isNotEmpty == true
        ? widget.bookingId!
        : (bookingIdStore?.isNotEmpty == true
            ? bookingIdStore!
            : (prefs.getString("booking_id") ?? ''));

    if (bookingId.isEmpty) return;

    // Only fetch trip details — trackRideModel is already populated
    // by the pickup/startride screen before navigation here.
    Get.find<ProfileController>().tripRideDetailsApi(
      context: Get.context!,
      bookingid: bookingId,
    );
  }

  @override
  void dispose() {
    try {
      mapController?.dispose();
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: InkWell(
          onTap: () {
            Get.back();
          },
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text(
          "Trip Details",
          style: TextStyle(color: Colors.black),
        ),
      ),

      body: GetBuilder<HomeController>(
        init: Get.find<HomeController>(),
        builder: (homeController) {
          final acceptData = homeController.trackRideModel;

          if (acceptData == null || acceptData.data == null) {
            return const Center(child: PremiumBlurLoader());
          }

          final double pickupLat = acceptData.data!.lat ?? 28.6139;
          final double pickupLng = acceptData.data!.lng ?? 77.2090;

          // Reactive inner builder: rebuilds when tripDetailsModel loads
          return GetBuilder<ProfileController>(
            init: Get.find<ProfileController>(),
            builder: (profileController) {
              final tripData = profileController.tripDetailsModel?.data;

              // Fetch estimate ride data if not already fetched
              if (homeController.estimatePrice.isEmpty &&
                  acceptData.data!.dropLat != null &&
                  acceptData.data!.dropLng != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  homeController.fetchEstimateRideData(
                    pickupLat: pickupLat,
                    pickupLng: pickupLng,
                    dropLat: acceptData.data!.dropLat!,
                    dropLng: acceptData.data!.dropLng!,
                  );
                });
              }

              // Price from estimate API
              final String ridePrice = homeController.estimatePrice;

              // Distance: prefer estimate API → Google Directions → track API
              final String distance = _getValidValue(
                homeController.estimateDistance,
                _getValidValue(
                  homeController.computedDistance,
                  _getValidValue(
                    acceptData.data?.distance,
                    tripData?.distance?.toString(),
                  ),
                ),
              );

              // Duration: prefer estimate API → Google Directions → track API
              final String rawDuration = _getValidValue(
                homeController.estimateDuration,
                _getValidValue(
                  homeController.computedDuration,
                  acceptData.data?.time,
                ),
              );

              final String distanceText = (distance.isNotEmpty && distance != '0')
                  ? '$distance km' : 'N/A';
              // estimateDuration already contains "3 mins" format
              final String durationText = (rawDuration.isNotEmpty && rawDuration != '0')
                  ? (rawDuration.contains('min') ? rawDuration : '$rawDuration min')
                  : 'N/A';

              return SingleChildScrollView(
                padding: EdgeInsets.all(width * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// TOP CARD — Ride Charges from estimate API
                    Container(
                      padding: EdgeInsets.all(width * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Ride Charges",
                            style: TextStyle(color: Colors.grey),
                          ),

                          SizedBox(height: height * 0.01),

                          Text(
                            ridePrice.isNotEmpty
                                ? "₹ $ridePrice"
                                : "₹ --",
                            style: TextStyle(
                              fontSize: width * 0.08,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: height * 0.02),

                          Row(
                            children: [
                              _infoBox("DURATION", durationText, width),
                              SizedBox(width: width * 0.04),
                              _infoBox("DISTANCE", distanceText, width),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: height * 0.02),

                    /// MAP
                    Container(
                      height: height * 0.20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(pickupLat, pickupLng),
                            zoom: 14,
                          ),
                          onMapCreated: (controllerMap) {
                            mapController = controllerMap;
                          },
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          markers: homeController.markers,
                          polylines: homeController.polylines,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                        ),
                      ),
                    ),

                    SizedBox(height: height * 0.02),

                    /// PICKUP & DROP
                    Container(
                      padding: EdgeInsets.all(width * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _locationTile(
                            icon: Icons.radio_button_checked,
                            title: acceptData.data?.pickupaddress ?? "",
                            subtitle: acceptData.data?.pickupaddress ?? "",
                            iconColor: Colors.blue,
                          ),
                          const Divider(),
                          _locationTile(
                            icon: Icons.location_on,
                            title: acceptData.data?.dropaddress ?? "",
                            subtitle: acceptData.data?.dropaddress ?? "",
                            iconColor: Colors.red,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: height * 0.04),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Returns the first non-null, non-empty, non-"0" value from two candidates
  String _getValidValue(String? primary, String? fallback) {
    if (primary != null && primary.isNotEmpty && primary != '0' && primary != 'null') {
      return primary;
    }
    if (fallback != null && fallback.isNotEmpty && fallback != '0' && fallback != 'null') {
      return fallback;
    }
    return '';
  }

  /// INFO BOX
  Widget _infoBox(String title, String value, double width) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(width * 0.03),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// LOCATION TILE
  Widget _locationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),

      title: Text(
        title,
        style: PoppinsReguler.copyWith(
          color: ColorResources.blackcolor11,
          fontSize: 12,
        ),
      ),

      subtitle: Text(subtitle),
    );
  }
}
