class TripModel {
  final String id;
  final String riderName;
  final double rating;
  final String pickup;
  final String drop;
  final String distance;
  final String time;
  final double fare;

  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;

  TripModel({
    required this.id,
    required this.riderName,
    required this.rating,
    required this.pickup,
    required this.drop,
    required this.distance,
    required this.time,
    required this.fare,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
  });
}