import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/controllers/erningmain_activity_controller.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

class EarningActivityScreen extends StatefulWidget {
  EarningActivityScreen({super.key});

  @override
  State<EarningActivityScreen> createState() => _EarningActivityScreenState();
}

class _EarningActivityScreenState extends State<EarningActivityScreen> {
 //// final controller = Get.put(EarningActivityController());

  final filters = ["All", "Type", "Featured", "From Lowest"];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Get.find<ProfileController>().getEarningActivityDetailList(
        context: context,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: InkWell(
          onTap: () {
            Get.back();
          },

          child: Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text(
          "Earning Activity",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
         

          /// LIST
          Expanded(
            child: GetBuilder<ProfileController>(
              builder: (controller) {
                if (controller.isEarningActivityLoading) {
                  return  Center(child: PremiumBlurLoader());
                }

                if (controller.earningActivityList.isEmpty) {
                  return const Center(child: Text("No Activity Found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: controller.earningActivityList.length,
                  itemBuilder: (context, index) {
                    final data = controller.earningActivityList[index];

                    final pickupLat = data.pickupLat ?? 28.6139;
                    final pickupLng = data.pickupLng ?? 77.2090;
                    final dropLat = data.dropLat ?? 28.7041;
                    final dropLng = data.dropLng ?? 77.1025;

                    final tipAmount =
                        double.tryParse(data.tip.toString()) ?? 0.0;

                    final fare =
                        double.tryParse(data.baseFare.toString()) ?? 0.0;

                    return InkWell(
                      onTap: () {
                        print('testing mode ||||| ${data.id}');
                        Get.toNamed(
                          RouteHelper.getmainActivityTripDetailsScreen(),
                          arguments: {"bookingid": data.id},
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// TOP
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.grey.shade300,
                                        child: const Icon(
                                          Icons.directions_car,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "₹${fare.toStringAsFixed(2)}",
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),

                                            Text(
                                              "Ride Completed",
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Text(
                                  data.createdAt ?? "",
                                  style:  TextStyle(fontSize: 12),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            /// STATUS
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "Completed",
                                style: TextStyle(color: Colors.green),
                              ),
                            ),

                            const SizedBox(height: 12),

                            /// MAP
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: SizedBox(
                                height: 160,
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(pickupLat, pickupLng),
                                    zoom: 12,
                                  ),

                                  markers: {
                                    Marker(
                                      markerId: const MarkerId("pickup"),
                                      position: LatLng(pickupLat, pickupLng),
                                    ),
                                    Marker(
                                      markerId: const MarkerId("drop"),
                                      position: LatLng(dropLat, dropLng),
                                    ),
                                  },

                                  polylines: {
                                    Polyline(
                                      polylineId: const PolylineId("route"),
                                      points: [
                                        LatLng(pickupLat, pickupLng),
                                        LatLng(dropLat, dropLng),
                                      ],
                                      color: const Color(0xff00AEEF),
                                      width: 4,
                                    ),
                                  },

                                  zoomControlsEnabled: false,
                                  myLocationButtonEnabled: false,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            /// PICKUP
                            Row(
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: Color(0xff00AEEF),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data.pickupAddress ?? "",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            /// DROP
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Color(0xff00AEEF),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data.dropAddress ?? "",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            if (tipAmount > 0)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.payments,
                                    color: Color(0xff00AEEF),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "₹${tipAmount.toStringAsFixed(2)} tip included",
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Expanded(
          //   child: Obx(
          //     () => ListView.builder(
          //       padding: const EdgeInsets.only(bottom: 20),
          //       itemCount: controller.earningList.length,
          //       itemBuilder: (context, index) {
          //         final data = controller.earningList[index];

          //         return InkWell(
          //           onTap: () {
          //             Get.toNamed(
          //               RouteHelper.getmainActivityTripDetailsScreen(data),
          //             );
          //           },
          //           child: Container(
          //             margin: const EdgeInsets.symmetric(
          //               horizontal: 16,
          //               vertical: 10,
          //             ),
          //             padding: const EdgeInsets.all(16),
          //             decoration: BoxDecoration(
          //               color: Colors.white,
          //               borderRadius: BorderRadius.circular(20),
          //             ),
          //             child: Column(
          //               crossAxisAlignment: CrossAxisAlignment.start,
          //               children: [
          //                 /// 🔥 FIXED TOP ROW
          //                 Row(
          //                   crossAxisAlignment: CrossAxisAlignment.start,
          //                   children: [
          //                     /// LEFT SIDE
          //                     Expanded(
          //                       child: Row(
          //                         crossAxisAlignment: CrossAxisAlignment.start,
          //                         children: [
          //                           CircleAvatar(
          //                             radius: 22,
          //                             backgroundColor: Colors.grey.shade300,
          //                           ),
          //                           const SizedBox(width: 10),

          //                           /// TEXT AREA
          //                           Expanded(
          //                             child: Column(
          //                               crossAxisAlignment:
          //                                   CrossAxisAlignment.start,
          //                               children: [
          //                                 Text(
          //                                   "₹${data.amount.toStringAsFixed(2)}",
          //                                   style: const TextStyle(
          //                                     fontSize: 18,
          //                                     fontWeight: FontWeight.bold,
          //                                   ),
          //                                 ),
          //                                 const SizedBox(height: 2),
          //                                 Text(
          //                                   data.carDetails,
          //                                   maxLines: 1,
          //                                   overflow: TextOverflow.ellipsis,
          //                                   style: const TextStyle(
          //                                     color: Colors.grey,
          //                                     fontSize: 13,
          //                                   ),
          //                                 ),
          //                               ],
          //                             ),
          //                           ),
          //                         ],
          //                       ),
          //                     ),

          //                     const SizedBox(width: 8),

          //                     /// TIME
          //                     Text(
          //                       data.time,
          //                       style: const TextStyle(fontSize: 13),
          //                     ),
          //                   ],
          //                 ),

          //                 const SizedBox(height: 8),

          //                 /// STATUS BADGE
          //                 Container(
          //                   padding: const EdgeInsets.symmetric(
          //                     horizontal: 12,
          //                     vertical: 5,
          //                   ),
          //                   decoration: BoxDecoration(
          //                     color: data.isIncreased
          //                         ? Colors.green.shade50
          //                         : Colors.orange.shade50,
          //                     borderRadius: BorderRadius.circular(20),
          //                   ),
          //                   child: Text(
          //                     data.isIncreased ? "↑ Increased" : "↓ Decreased",
          //                     style: TextStyle(
          //                       color: data.isIncreased
          //                           ? Colors.green
          //                           : Colors.orange,
          //                     ),
          //                   ),
          //                 ),

          //                 const SizedBox(height: 12),

          //                 /// GOOGLE MAP
          //                 ClipRRect(
          //                   borderRadius: BorderRadius.circular(15),
          //                   child: SizedBox(
          //                     height: 160,
          //                     width: double.infinity,
          //                     child: GoogleMap(
          //                       initialCameraPosition: CameraPosition(
          //                         target: data.pickupLatLng,
          //                         zoom: 12,
          //                       ),
          //                       markers: {
          //                         Marker(
          //                           markerId: const MarkerId("pickup"),
          //                           position: data.pickupLatLng,
          //                         ),
          //                         Marker(
          //                           markerId: const MarkerId("drop"),
          //                           position: data.dropLatLng,
          //                         ),
          //                       },
          //                       polylines: {
          //                         Polyline(
          //                           polylineId: const PolylineId("route"),
          //                           points: [
          //                             data.pickupLatLng,
          //                             data.dropLatLng,
          //                           ],
          //                           color: const Color(0xff00AEEF),
          //                           width: 4,
          //                         ),
          //                       },
          //                       zoomControlsEnabled: false,
          //                       myLocationButtonEnabled: false,
          //                     ),
          //                   ),
          //                 ),

          //                 const SizedBox(height: 12),

          //                 /// PICKUP
          //                 Row(
          //                   children: [
          //                     const Icon(
          //                       Icons.circle,
          //                       size: 10,
          //                       color: Color(0xff00AEEF),
          //                     ),
          //                     const SizedBox(width: 8),
          //                     Expanded(
          //                       child: Text(
          //                         data.pickup,
          //                         maxLines: 1,
          //                         overflow: TextOverflow.ellipsis,
          //                         style: const TextStyle(
          //                           fontWeight: FontWeight.w600,
          //                         ),
          //                       ),
          //                     ),
          //                   ],
          //                 ),

          //                 const SizedBox(height: 8),

          //                 /// DROP
          //                 Row(
          //                   children: [
          //                     const Icon(
          //                       Icons.location_on,
          //                       size: 16,
          //                       color: Color(0xff00AEEF),
          //                     ),
          //                     const SizedBox(width: 8),
          //                     Expanded(
          //                       child: Text(
          //                         data.drop,
          //                         maxLines: 1,
          //                         overflow: TextOverflow.ellipsis,
          //                         style: const TextStyle(
          //                           fontWeight: FontWeight.w600,
          //                         ),
          //                       ),
          //                     ),
          //                   ],
          //                 ),

          //                 const SizedBox(height: 10),

          //                 if (data.tip > 0)
          //                   Row(
          //                     children: [
          //                       const Icon(
          //                         Icons.access_time,
          //                         color: Color(0xff00AEEF),
          //                       ),
          //                       const SizedBox(width: 8),
          //                       Expanded(
          //                         child: Text(
          //                           "₹${data.tip.toStringAsFixed(2)} tip included",
          //                           maxLines: 1,
          //                           overflow: TextOverflow.ellipsis,
          //                           style: const TextStyle(
          //                             fontWeight: FontWeight.w600,
          //                           ),
          //                         ),
          //                       ),
          //                     ],
          //                   ),
          //               ],
          //             ),
          //           ),
          //         );
          //       },
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
