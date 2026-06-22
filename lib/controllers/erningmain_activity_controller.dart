// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:myridedriverapp/model/erningmain_model.dart';


// class EarningActivityController extends GetxController {
//   var selectedFilter = 0.obs;
//   var earningList = <EarningModel>[].obs;

//   @override
//   void onInit() {
//     super.onInit();
//     loadDummyData();
//   }

//   void loadDummyData() {
//     earningList.value = [
//       EarningModel(
//         amount: 28.00,
//         isIncreased: true,
//         time: "4:41 PM",
//         carDetails: "My Ride Car • 15 Minutes • 6 miles",
//         pickup: "Zero Point Noida",
//         drop: "Noida International University",
//         tip: 3.00,
//         pickupLatLng: const LatLng(28.6139, 77.2090),
//         dropLatLng: const LatLng(28.5672, 77.3450),
//       ),
//       EarningModel(
//         amount: 31.50,
//         isIncreased: false,
//         time: "5:24 PM",
//         carDetails: "My Ride Car • 18 Minutes • 7 miles",
//         pickup: "Sector 62 Noida",
//         drop: "DLF Mall Noida",
//         tip: 0,
//         pickupLatLng: const LatLng(28.6270, 77.3649),
//         dropLatLng: const LatLng(28.5670, 77.3210),
//       ),
//     ];
//   }
// }