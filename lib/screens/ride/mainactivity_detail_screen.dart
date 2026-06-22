// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:myridedriverapp/model/arningactivitylist_model.dart';

// class TripDetailsScreen extends StatelessWidget {


//  TripDetailsScreen({super.key, });
//   //final data = Get.arguments["data"];

//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;

//     return Scaffold(
//       backgroundColor: const Color(0xffF5F6FA),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         centerTitle: true,
//         leading: InkWell(
//           onTap: () {
//             Get.back();
//           },
          
//           child: const Icon(Icons.arrow_back, color: Colors.black)),
//         title: const Text(
//           "Trip Details",
//           style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
//         ),
//         actions: const [
//           Padding(
//             padding: EdgeInsets.only(right: 15),
//             child: CircleAvatar(
//               radius: 16,
//               backgroundColor: Color(0xffF0F0F0),
//               child: Icon(Icons.help_outline, size: 18, color: Colors.black),
//             ),                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           children: [
//             /// TOP CARD
//             Container(
//               margin: const EdgeInsets.all(16),
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: const Color(0xffEFEFEF),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "My Ride Car • Jun 25 • Upfront ₹25.00",
//                     style: TextStyle(fontSize: 13, color: Colors.grey),
//                   ),

//                   const SizedBox(height: 8),

//                   Text(
//                     "₹${data.amount.toStringAsFixed(2)}",
//                     style: const TextStyle(
//                       fontSize: 28,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),

//                   const SizedBox(height: 12),

//                   Row(
//                     children: [
//                       /// Duration Box
//                       Expanded(
//                         child: Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(15),
//                           ),
//                           child: const Column(
//                             children: [
//                               Text(
//                                 "DURATION",
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                               SizedBox(height: 4),
//                               Text(
//                                 "15 min 34 sec",
//                                 style: TextStyle(fontWeight: FontWeight.w600),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),

//                       const SizedBox(width: 10),

//                       /// Distance Box
//                       Expanded(
//                         child: Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(15),
//                           ),
//                           child: const Column(
//                             children: [
//                               Text(
//                                 "DISTANCE",
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                               SizedBox(height: 4),
//                               Text(
//                                 "6.02 miles",
//                                 style: TextStyle(fontWeight: FontWeight.w600),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),

//             /// MAP
//             Container(
//               margin: const EdgeInsets.symmetric(horizontal: 16),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(20),
//                 child: SizedBox(
//                   height: 200,
//                   width: double.infinity,
//                   child: GoogleMap(
//                     initialCameraPosition: CameraPosition(
//                       target: data.pickupLatLng,
//                       zoom: 12,
//                     ),
//                     markers: {
//                       Marker(
//                         markerId: const MarkerId("pickup"),
//                         position: data.pickupLatLng,
//                       ),
//                       Marker(
//                         markerId: const MarkerId("drop"),
//                         position: data.dropLatLng,
//                       ),
//                     },
//                     polylines: {
//                       Polyline(
//                         polylineId: const PolylineId("route"),
//                         points: [data.pickupLatLng, data.dropLatLng],
//                         color: const Color(0xff00AEEF),
//                         width: 4,
//                       ),
//                     },
//                     zoomControlsEnabled: false,
//                     myLocationButtonEnabled: false,
//                   ),
//                 ),
//               ),
//             ),

//             const SizedBox(height: 16),

//             /// LOCATION SECTION
//             _locationTile(Icons.circle, data.pickup),
//             _locationTile(Icons.location_on, data.drop),

//             const SizedBox(height: 10),

//             /// TIP ROW
//             if (data.tip > 0)
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       "₹${data.tip.toStringAsFixed(2)} tip Included",
//                       style: const TextStyle(fontWeight: FontWeight.w600),
//                     ),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 14,
//                         vertical: 6,
//                       ),
//                       decoration: BoxDecoration(
//                         color: const Color(0xff00AEEF).withOpacity(0.15),
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: const Text(
//                         "Send Thanks",
//                         style: TextStyle(
//                           color: Color(0xff00AEEF),
//                           fontSize: 12,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//             const SizedBox(height: 20),

//             /// Earnings Breakdown
//             _earningsRow("Fare", "₹25.00"),
//             _earningsRow("Tip", "₹${data.tip.toStringAsFixed(2)}"),
//             _earningsRow(
//               "Your Earnings",
//               "₹${data.amount.toStringAsFixed(2)}",
//               isBold: true,
//             ),

//             const SizedBox(height: 20),

//             /// Info Box
//             Container(
//               margin: const EdgeInsets.all(16),
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: const Color(0xffFFF8E1),
//                 borderRadius: BorderRadius.circular(15),
//                 border: Border.all(color: Colors.orange),
//               ),
//               child: const Text(
//                 "My Ride total service fee for your trips from March 16 – April 13 was 18.0% of the total customer price (excluding tips).",
//                 style: TextStyle(fontSize: 12),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   static Widget _locationTile(IconData icon, String text) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//       child: Row(
//         children: [
//           Icon(icon, size: 16, color: const Color(0xff00AEEF)),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               text,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(fontWeight: FontWeight.w600),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   static Widget _earningsRow(
//     String title,
//     String value, {
//     bool isBold = false,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(title),
//           Text(
//             value,
//             style: TextStyle(
//               fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';


class TripDetailsScreen extends StatefulWidget {
 final dynamic bookingId;

  const TripDetailsScreen({
    super.key,
    required this.bookingId
  });

  @override
  State<TripDetailsScreen> createState() =>
      _TripDetailsScreenState();
}

class _TripDetailsScreenState
    extends State<TripDetailsScreen> {

 

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
       Get.find<ProfileController>().tripRideDetailsApi(
        context: context,
        bookingid: widget.bookingId.toString()
      );
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Details"),
      ),

      body: GetBuilder<ProfileController>(
        builder: (controller) {

          if(controller.isTripDetailsLoading){
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if(controller.tripDetailsModel == null){
            return const Center(
              child: Text("No Data Found"),
            );
          }

          var data = controller.tripDetailsModel!.data!;

          LatLng pickup = LatLng(
            data.pickupLat ?? 0,
            data.pickupLng ?? 0,
          );

          LatLng drop = LatLng(
            data.dropLat ?? 0,
            data.dropLng ?? 0,
          );

          return SingleChildScrollView(
            child: Column(
              children: [

                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius:
                       BorderRadius.circular(20),
                  ),

                  child: Column(
                    children: [

                      Text(
                        "Booking ID : ${data.bookingId}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height:20),

                      Text(
                        "₹${data.totalFare ?? "0"}",
                        style: TextStyle(
                          fontSize:30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height:20),

                      Row(
                        children: [

                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(15),
                              color: Colors.white,
                              child: Column(
                                children: [
                                  Text("Distance"),
                                  Text(
                                   "${data.distance ?? 0} km"
                                  )
                                ],
                              ),
                            ),
                          ),

                          SizedBox(width:10),

                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(15),
                              color: Colors.white,
                              child: Column(
                                children: [
                                  Text("Status"),
                                  Text(
                                   data.status ?? ""
                                  )
                                ],
                              ),
                            ),
                          )

                        ],
                      )

                    ],
                  ),
                ),

                Container(
                  margin: EdgeInsets.all(16),
                  height: 220,
                  child: GoogleMap(
                    initialCameraPosition:
                     CameraPosition(
                       target: pickup,
                       zoom: 12,
                     ),

                    markers: {
                      Marker(
                        markerId:
                          MarkerId("pickup"),
                        position: pickup,
                      ),

                      Marker(
                        markerId:
                           MarkerId("drop"),
                        position: drop,
                      ),
                    },

                    polylines: {
                      Polyline(
                        polylineId:
                          PolylineId("route"),
                        points: [
                          pickup,
                          drop
                        ],
                        width: 5,
                      )
                    },
                  ),
                ),

                _row(
                  "Base Fare",
                  "₹${data.baseFare}"
                ),

                _row(
                  "Discount Fare",
                  "₹${data.discountFare}"
                ),

                _row(
                  "Total Fare",
                  "₹${data.totalFare}",
                  true
                ),

                SizedBox(height:30)

              ],
            ),
          );
        },
      ),
    );
  }


  Widget _row(
    String title,
    String value,
    [bool bold=false]
  ){
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal:20,
        vertical:10,
      ),
      child: Row(
        mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold
                ? FontWeight.bold
                : FontWeight.normal,
            ),
          )
        ],
      ),
    );
  }
}