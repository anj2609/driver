import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

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
    final ProfileController controllerprofile = Get.find<ProfileController>();
    final HomeController controller = Get.find<HomeController>();
    controllerprofile.tripRideDetailsApi(
      context: context,
      bookingid: bookingIdStore!.isNotEmpty
          ? bookingIdStore
          : widget.bookingId.toString(),
    );

    controller.trackbookingRide(
      context: context,
      bookingId: bookingIdStore!.isNotEmpty
          ? bookingIdStore
          : widget.bookingId.toString(),
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

      body: GetBuilder<ProfileController>(
        init: Get.find<ProfileController>(),
        builder: (profileController) {
          final trips = profileController.tripDetailsModel;

          /// Profile data loading
          if (trips == null || trips.data == null) {
            return  Center(child:  PremiumBlurLoader());
          }

          return GetBuilder<HomeController>(
            init: Get.find<HomeController>(),
            builder: (homeController) {
              final acceptData = homeController.trackRideModel;

              /// Home data loading
              if (acceptData == null || acceptData.data == null) {
                return const Center( child: PremiumBlurLoader());
              }

              /// SAFE LAT LNG
              final double pickupLat =
                  double.tryParse(trips.data?.pickupLat?.toString() ?? '') ??
                  28.6139;

              final double pickupLng =
                  double.tryParse(trips.data?.pickupLng?.toString() ?? '') ??
                  77.2090;

              return SingleChildScrollView(
                padding: EdgeInsets.all(width * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// TOP CARD
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
                            "Trip Details",
                            style: TextStyle(color: Colors.grey),
                          ),

                          SizedBox(height: height * 0.01),

                          Text(
                            "₹ ${acceptData.data?.totalFare ?? "0"}",
                            style: TextStyle(
                              fontSize: width * 0.08,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: height * 0.02),

                          Row(
                            children: [
                              _infoBox(
                                "DURATION",
                                acceptData.data?.time?.toString() ?? "0",
                                width,
                              ),

                              SizedBox(width: width * 0.04),

                              _infoBox(
                                "DISTANCE",
                                acceptData.data?.distance?.toString() ?? "0",
                                width,
                              ),
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

                    SizedBox(height: height * 0.02),

                    const Text(
                      "Your Earnings",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: height * 0.01),

                    /// EARNINGS
                    Container(
                      padding: EdgeInsets.all(width * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _earningRow(
                            "Fare",
                            double.tryParse(
                                  acceptData.data?.baseFare?.toString() ?? "0",
                                ) ??
                                0.0,
                          ),

                          _earningRow(
                            "Your Earnings",
                            double.tryParse(
                                  acceptData.data?.totalFare?.toString() ?? "0",
                                ) ??
                                0.0,
                            isBold: true,
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

  /// EARNING ROW
  Widget _earningRow(String title, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),

          Text(
            "₹${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
