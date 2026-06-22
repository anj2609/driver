// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:intl/intl.dart';
// import 'package:myridedriverapp/model/opportunityModel%20_model.dart';

// class OpportunitiesController extends GetxController {

//   /// 🔹 ADD THIS
//   var selectedTab = 0.obs;

//   var selectedDate = DateTime.now().obs;
//   var focusedDay = DateTime.now().obs;

//   GoogleMapController? mapController;

//   var opportunities = <OpportunityModel>[].obs;

//   @override
//   void onInit() {
//     super.onInit();
//     loadDummyData();
//   }

//   void loadDummyData() {
//     opportunities.value = [
//       OpportunityModel(
//         title: "Real Madrid CF vs PSG",
//         location: "Noida Stadium",
//         time: "7:00 PM - 10:00 PM",
//         date: DateTime.now(),
//         position: const LatLng(28.6139, 77.2090),
//       ),
//       OpportunityModel(
//         title: "Warface Concert",
//         location: "Delhi University",
//         time: "10:00 PM - 11:30 PM",
//         date: DateTime.now().add(const Duration(days: 1)),
//         position: const LatLng(28.7041, 77.1025),
//       ),
//     ];
//   }

//   List<OpportunityModel> get filteredList =>
//       opportunities.where((e) =>
//           e.date.year == selectedDate.value.year &&
//           e.date.month == selectedDate.value.month &&
//           e.date.day == selectedDate.value.day
//       ).toList();

//   Set<Marker> get markers =>
//       filteredList.map((e) => Marker(
//         markerId: MarkerId(e.title),
//         position: e.position,
//         infoWindow: InfoWindow(title: e.title),
//       )).toSet();

//   void onDaySelected(DateTime selected, DateTime focused) {
//     selectedDate.value = selected;
//     focusedDay.value = focused;
//   }

//   Map<String, List<OpportunityModel>> get groupedByDate {
//     Map<String, List<OpportunityModel>> map = {};

//     for (var item in filteredList) {
//       String date = DateFormat('EEEE, MMMM dd').format(item.date);

//       if (!map.containsKey(date)) {
//         map[date] = [];
//       }
//       map[date]!.add(item);
//     }

//     return map;
//   }
// }