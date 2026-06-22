import 'package:google_maps_flutter/google_maps_flutter.dart';

class EarningModel {
  final double amount;
  final bool isIncreased;
  final String time;
  final String carDetails;
  final String pickup;
  final String drop;
  final double tip;
  final LatLng pickupLatLng;
  final LatLng dropLatLng;

  EarningModel({
    required this.amount,
    required this.isIncreased,
    required this.time,
    required this.carDetails,
    required this.pickup,
    required this.drop,
    required this.tip,
    required this.pickupLatLng,
    required this.dropLatLng,
  });
}