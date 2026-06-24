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
import 'package:myridedriverapp/controllers/profile_controller.dart';
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
                                      color: Colors.blue.withValues(alpha: .1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.directions_car,
                                      color: Colors.blue,
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
                            "${vehicle?.brand ?? ''} ${vehicle?.model ?? ''}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          /// Vehicle Number from API
                          Text(
                            "Vehicle No: ${vehicle?.vehicleNumber ?? ''}",
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
                                const Text(
                                  "Vehicle Details",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 15),

                                detailRow("Brand", vehicle?.brand ?? "-"),

                                detailRow("Model", vehicle?.model ?? "-"),

                                detailRow(
                                  "Chassis No",
                                  vehicle?.chassisNumber ?? "-",
                                ),

                                detailRow(
                                  "Engine No",
                                  vehicle?.engineNumber ?? "-",
                                ),

                                detailRow(
                                  "Manufacture Year",
                                  vehicle?.manufactureYear ?? "-",
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
