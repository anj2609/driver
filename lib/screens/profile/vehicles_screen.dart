// import 'package:flutter/material.dart';

// class VehiclesScreen extends StatelessWidget {
//   const VehiclesScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final width = size.width;
//     final height = size.height;

//     return Scaffold(
//       backgroundColor: const Color(0xffF5F5F5),

//       /// ✅ Proper AppBar
//       appBar: AppBar(
//         backgroundColor: const Color(0xffF5F5F5),
//         elevation: 0,
//         centerTitle: true,
//         leading: Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: CircleAvatar(
//             backgroundColor: Colors.white,
//             child: IconButton(
//               icon: const Icon(Icons.arrow_back, color: Colors.black),
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//             ),
//           ),
//         ),
//         title: const Text(
//           "Vehicles",
//           style: TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.w600,
//             fontSize: 18,
//           ),
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 10),
//             child: CircleAvatar(
//               backgroundColor: Colors.white,
//               child: IconButton(
//                 icon: const Icon(Icons.more_vert, color: Colors.black),
//                 onPressed: () {},
//               ),
//             ),
//           ),
//         ],
//       ),

//       /// ✅ Body Scrollable (No Overflow)
//       body: SafeArea(
//         child: SingleChildScrollView(
//           child: Padding(
//             padding: EdgeInsets.symmetric(horizontal: width * 0.05),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SizedBox(height: height * 0.03),

//                 /// Vehicle Image
//                 Center(
//                   child: Image.asset(
//                     "assets/images/car.png",
//                     height: height * 0.22,
//                     fit: BoxFit.contain,
//                   ),
//                 ),

//                 SizedBox(height: height * 0.02),

//                 const Text(
//                   "Toyota Innova V25",
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),

//                 const SizedBox(height: 4),

//                 const Text(
//                   "Delivery + Rides",
//                   style: TextStyle(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                 ),

//                 SizedBox(height: height * 0.02),

//                 /// Expiry Warning
//                 Container(
//                   padding: EdgeInsets.symmetric(
//                       horizontal: width * 0.04, vertical: height * 0.015),
//                   decoration: BoxDecoration(
//                     color: const Color(0xffFCE5C5),
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   child: Row(
//                     children: const [
//                       Icon(Icons.warning_amber_rounded,
//                           color: Colors.orange),
//                       SizedBox(width: 10),
//                       Expanded(
//                         child: Text(
//                           "Vehicle Information expires soon",
//                           style: TextStyle(fontWeight: FontWeight.w500),
//                         ),
//                       ),
//                       Icon(Icons.arrow_forward_ios, size: 16),
//                     ],
//                   ),
//                 ),

//                 SizedBox(height: height * 0.015),

//                 /// Manage Vehicle Button
//                 Container(
//                   width: double.infinity,
//                   padding: EdgeInsets.symmetric(vertical: height * 0.018),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   alignment: Alignment.center,
//                   child: const Text(
//                     "Manage Vehicles",
//                     style: TextStyle(
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),

//                 SizedBox(height: height * 0.025),

//                 /// Explore Vehicle Card
//                 Container(
//                   padding: EdgeInsets.all(width * 0.05),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: const [
//                           CircleAvatar(
//                             backgroundColor: Color(0xffFFECEC),
//                             child: Icon(Icons.gps_fixed,
//                                 color: Colors.red),
//                           ),
//                           SizedBox(width: 10),
//                           Expanded(
//                             child: Text(
//                               "Explore Vehicle opportunities",
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: 10),
//                       const Text(
//                         "Browse rental, fleet, or purchase options if you need another vehicle.",
//                         style: TextStyle(color: Colors.grey),
//                       ),
//                       SizedBox(height: 15),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 20, vertical: 10),
//                         decoration: BoxDecoration(
//                           color: Color(0xffF2F2F2),
//                           borderRadius: BorderRadius.circular(25),
//                         ),
//                         child: const Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Text(
//                               "Learn More",
//                               style:
//                                   TextStyle(fontWeight: FontWeight.w600),
//                             ),
//                             SizedBox(width: 8),
//                             Icon(Icons.arrow_forward, size: 16),
//                           ],
//                         ),
//                       )
//                     ],
//                   ),
//                 ),

//                 SizedBox(height: height * 0.02),

//                 /// Electric Vehicle Card
//                 Container(
//                   padding: EdgeInsets.all(width * 0.05),
//                   decoration: BoxDecoration(
//                     color: const Color(0xffE8F4F3),
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: Colors.teal.shade100),
//                   ),
//                   child: Row(
//                     children: const [
//                       Icon(Icons.bolt,
//                           color: Colors.teal, size: 28),
//                       SizedBox(width: 15),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment:
//                               CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               "Interested in an electric vehicle?",
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             SizedBox(height: 4),
//                             Text(
//                               "Save money and unlock more opportunities to earn",
//                               style: TextStyle(color: Colors.grey),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Icon(Icons.arrow_forward_ios, size: 16),
//                     ],
//                   ),
//                 ),

//                 SizedBox(height: 20),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/dimensions.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/model/vehicledetails_model.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';
import 'package:myridedriverapp/widgets/vehicle_zoom_custom.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      Get.find<ProfileController>().getVehicleDetailsApi(context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return GetBuilder<ProfileController>(
      builder: (controller) {
        final vehicle = controller.vehicleData;

        return Scaffold(
          backgroundColor: const Color(0xffF5F5F5),

          appBar: AppBar(
            backgroundColor: const Color(0xffF5F5F5),
            elevation: 0,
            centerTitle: true,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            title: const Text(
              "Vehicles",
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          body: controller.isVehicleLoading
              ? Center(child:  PremiumBlurLoader())
              : vehicle == null
                  // A clean API failure (non-200, or a body that parsed but
                  // came back empty) previously fell through to the normal
                  // layout below with every field defaulting to "-" and an
                  // empty image grid — looking like "no vehicle on file"
                  // rather than "couldn't load it", with no way to retry.
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            "Could not load vehicle details.",
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Get.find<ProfileController>()
                                .getVehicleDetailsApi(context: context),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    )
                  : SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: width * .05),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: height * .03),

                          /// Vehicle Image from API
                          ///
                          ///
                          ///
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.only(
                                      left: Dimensions.smallSpace,
                                      right: Dimensions.smallSpace,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF123EBC).withValues(alpha: .1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.directions_car,
                                      color: Color(0xFF123EBC),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "Vehicle Images",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: controller.vehicleImages.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                      childAspectRatio: 1.08,
                                    ),
                                itemBuilder: (context, index) {
                                  String imageUrl =
                                      "${ApiConstants.fileUrl}${controller.vehicleImages[index]}";

                                  return GestureDetector(
                                    onTap: () {
                                      Get.to(
                                        () => FullImageViewer(
                                          images: controller.vehicleImages,
                                          initialIndex: index,
                                        ),
                                      );
                                    },

                                    child: Hero(
                                      tag: imageUrl,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.shade300,
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),

                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              child: Image.network(
                                                imageUrl,
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                      color:
                                                          Colors.grey.shade200,
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          size: 45,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                              ),
                                            ),

                                            // Zoom icon
                                            Positioned(
                                              top: 10,
                                              right: 10,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black45,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: const Icon(
                                                  Icons.zoom_in,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          // Padding(
                          //   padding: const EdgeInsets.symmetric(horizontal: 16),
                          //   child: GridView.builder(
                          //     shrinkWrap: true,
                          //     physics: const NeverScrollableScrollPhysics(),
                          //     itemCount: controller.vehicleImages.length,
                          //     gridDelegate:
                          //         const SliverGridDelegateWithFixedCrossAxisCount(
                          //           crossAxisCount: 2, // 2 images in one line
                          //           crossAxisSpacing: 14,
                          //           mainAxisSpacing: 14,
                          //           childAspectRatio: 1.15,
                          //         ),
                          //     itemBuilder: (context, index) {
                          //       String imageUrl =
                          //           "${ApiConstants.fileUrl}${controller.vehicleImages[index]}";

                          //       return GestureDetector(
                          //         onTap: () {
                          //           Get.to(
                          //             () => FullImageViewer(
                          //               images: controller.vehicleImages,
                          //               initialIndex: index,
                          //             ),
                          //           );
                          //         },
                          //         child: Hero(
                          //           tag: imageUrl,
                          //           child: Container(
                          //             decoration: BoxDecoration(
                          //               borderRadius: BorderRadius.circular(22),
                          //               boxShadow: [
                          //                 BoxShadow(
                          //                   color: Colors.grey.shade300,
                          //                   blurRadius: 8,
                          //                   offset: const Offset(0, 4),
                          //                 ),
                          //               ],
                          //             ),
                          //             child: Stack(
                          //               children: [
                          //                 ClipRRect(
                          //                   borderRadius: BorderRadius.circular(
                          //                     22,
                          //                   ),
                          //                   child: Image.network(
                          //                     imageUrl,
                          //                     width: double.infinity,
                          //                     height: double.infinity,
                          //                     fit: BoxFit.cover,
                          //                     errorBuilder: (_, __, ___) =>
                          //                         Container(
                          //                           color: Colors.grey.shade200,
                          //                           child: const Center(
                          //                             child: Icon(
                          //                               Icons
                          //                                   .image_not_supported,
                          //                               size: 40,
                          //                               color: Colors.grey,
                          //                             ),
                          //                           ),
                          //                         ),
                          //                   ),
                          //                 ),

                          //                 // Zoom icon
                          //                 Positioned(
                          //                   top: 10,
                          //                   right: 10,
                          //                   child: Container(
                          //                     padding: const EdgeInsets.all(6),
                          //                     decoration: BoxDecoration(
                          //                       color: Colors.black45,
                          //                       borderRadius:
                          //                           BorderRadius.circular(12),
                          //                     ),
                          //                     child: const Icon(
                          //                       Icons.zoom_in,
                          //                       color: Colors.white,
                          //                       size: 18,
                          //                     ),
                          //                   ),
                          //                 ),
                          //               ],
                          //             ),
                          //           ),
                          //         ),
                          //       );
                          //     },
                          //   ),
                          // ),

                          //          SizedBox(
                          //   height: 120,
                          //   child:
                          //   ListView.builder(
                          //     scrollDirection: Axis.horizontal,
                          //     itemCount: controller.vehicleImages.length,
                          //     itemBuilder: (context, index) {
                          //       String imageUrl =
                          //           "${ApiConstants.fileUrl}${controller.vehicleImages[index]}";

                          //       return GestureDetector(
                          //         onTap: () {
                          //           Get.to(
                          //             () => FullImageViewer(
                          //               images: controller.vehicleImages,
                          //               initialIndex: index,
                          //             ),
                          //           );
                          //         },
                          //         child: Container(
                          //           width: 120,
                          //           margin: const EdgeInsets.only(right: 12),
                          //           decoration: BoxDecoration(
                          //             borderRadius: BorderRadius.circular(15),
                          //             border: Border.all(color: Colors.grey.shade300),
                          //           ),
                          //           child: ClipRRect(
                          //             borderRadius: BorderRadius.circular(15),
                          //             child: Image.network(
                          //               imageUrl,
                          //               fit: BoxFit.cover,
                          //               errorBuilder: (_, __, ___) =>
                          //                   const Icon(Icons.image_not_supported),
                          //             ),
                          //           ),
                          //         ),
                          //       );
                          //     },
                          //   ),
                          // ),
                          SizedBox(height: height * .02),

                          /// Brand + Model from API
                          Text(
                            "${vehicle.brand ?? ''} ${vehicle.model ?? ''}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          /// Vehicle Number from API
                          Text(
                            "Vehicle No: ${vehicle.vehicleNumber ?? ''}",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                            ),
                          ),

                          SizedBox(height: height * .02),

                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: width * .04,
                              vertical: height * .015,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffFCE5C5),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Vehicle Information expires soon",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                          ),

                          SizedBox(height: height * .015),

                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              vertical: height * .018,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              "Manage Vehicles",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),

                          SizedBox(height: height * .025),

                          /// Extra Info Card
                          Container(
                            padding: EdgeInsets.all(width * .05),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Vehicle Details",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          _showEditVehicleSheet(context, vehicle),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Color(0xFF123EBC),
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 15),

                                detailRow("Brand", vehicle.brand ?? "-"),

                                detailRow("Model", vehicle.model ?? "-"),

                                detailRow(
                                  "Chassis No",
                                  vehicle.chassisNumber?.toString() ?? "-",
                                ),

                                detailRow(
                                  "Engine No",
                                  vehicle.engineNumber?.toString() ?? "-",
                                ),

                                detailRow(
                                  "Manufacture Year",
                                  vehicle.manufactureYear?.toString() ?? "-",
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _showEditVehicleSheet(
    BuildContext context,
    VehicleDetailsData? vehicle,
  ) async {
    final authController = Get.find<AuthController>();

    // The update goes through the same vehical-info endpoint used at
    // signup, which requires a vehicle_type_id — make sure the type list
    // is loaded so the driver can confirm/select it here too.
    if (authController.vehicleTypeList.isEmpty) {
      await authController.vehicleType(context: context);
    }

    final brandController = TextEditingController(text: vehicle?.brand ?? '');
    final modelController = TextEditingController(text: vehicle?.model ?? '');
    // Was hardcoded to "" on save regardless of what (if anything) was
    // ever on file — the same vehical-info endpoint used at registration
    // rejects an empty color if the backend requires one, so every edit
    // here could silently fail with a generic error and never actually
    // save, while the driver never has anywhere to enter or correct it.
    final colorController = TextEditingController(text: vehicle?.color ?? '');
    final vehicleNumberController =
        TextEditingController(text: vehicle?.vehicleNumber ?? '');
    final chassisController =
        TextEditingController(text: vehicle?.chassisNumber?.toString() ?? '');
    final engineController =
        TextEditingController(text: vehicle?.engineNumber?.toString() ?? '');
    final yearController = TextEditingController(
      text: vehicle?.manufactureYear?.toString() ?? '',
    );

    int? selectedVehicleTypeId = int.tryParse(
      vehicle?.vehicleTypeId?.toString() ?? '',
    );
    if (authController.vehicleTypeList.isNotEmpty &&
        !authController.vehicleTypeList
            .any((v) => v.id == selectedVehicleTypeId)) {
      selectedVehicleTypeId = null;
    }

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                // Keyboard inset when a field is focused, plus the device's
                // own bottom safe area so Save Changes never sits under the
                // gesture bar / on-screen nav buttons.
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                    MediaQuery.of(sheetContext).padding.bottom +
                    20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Edit Vehicle Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: selectedVehicleTypeId,
                        decoration: InputDecoration(
                          labelText: "Vehicle Type",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: authController.vehicleTypeList
                            .map(
                              (v) => DropdownMenuItem<int>(
                                value: v.id,
                                child: Text(v.name ?? "-"),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setSheetState(() => selectedVehicleTypeId = val),
                        validator: (v) =>
                            v == null ? "Select a vehicle type" : null,
                      ),
                      const SizedBox(height: 14),
                      _editField("Brand", brandController),
                      _editField("Model", modelController),
                      _editField("Color", colorController),
                      // Now editable — the backend's vehical-info endpoint
                      // accepts a vehicle_id identifying the record being
                      // updated, so it no longer confuses an edit for a
                      // new-vehicle creation and rejecting the driver's own
                      // number as "already taken".
                      _editField("Vehicle Number", vehicleNumberController),
                      _editField("Chassis No", chassisController),
                      _editField("Engine No", engineController),
                      _editField(
                        "Manufacture Year",
                        yearController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF123EBC),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  setSheetState(() => isSaving = true);

                                  final response =
                                      await Get.find<AuthController>()
                                          .vehicaleInfoApi(
                                    context: sheetContext,
                                    vehicalid:
                                        selectedVehicleTypeId?.toString(),
                                    vehicleId: vehicle?.vehicleId?.toString(),
                                    vehicalnumber:
                                        vehicleNumberController.text.trim(),
                                    brand: brandController.text.trim(),
                                    model: modelController.text.trim(),
                                    color: colorController.text.trim(),
                                    chassisnumber:
                                        chassisController.text.trim(),
                                    enginenumber:
                                        engineController.text.trim(),
                                    manufactureyear:
                                        yearController.text.trim(),
                                  );

                                  setSheetState(() => isSaving = false);

                                  // Was a bare `== '200'` — likely tied
                                  // directly to chassis/engine/manufacture
                                  // year "not showing" reports: if this
                                  // backend ever sends this endpoint's
                                  // "code" as a JSON number, this save
                                  // silently does nothing from the driver's
                                  // point of view (no error, sheet doesn't
                                  // close) AND getVehicleDetailsApi() below
                                  // — the only thing that refreshes the
                                  // Vehicle screen with what was just saved
                                  // — never runs. The driver has no way to
                                  // tell their edit didn't take.
                                  final saveCode = response.body is Map
                                      ? response.body['code']?.toString()
                                      : null;
                                  if (response.statusCode == 200 &&
                                      saveCode == '200') {
                                  if (sheetContext.mounted &&
                                      Navigator.of(sheetContext).canPop()) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                  if (mounted) {
                                    Get.find<ProfileController>()
                                        .getVehicleDetailsApi(
                                            context: context);
                                  }
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Save Changes",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: readOnly ? const TextStyle(color: Colors.grey) : null,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? "$label is required" : null,
        decoration: InputDecoration(
          labelText: label,
          filled: readOnly,
          fillColor: readOnly ? Colors.grey.shade100 : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
