
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OpportunityModel {
  final String title;
  final String location;
  final String time;
  final DateTime date;
  final LatLng position;

  OpportunityModel({
    required this.title,
    required this.location,
    required this.time,
    required this.date,
    required this.position,
  });
}