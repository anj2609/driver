class EarningActivityModel {
  String? code;
  String? message;
  List<EarningActivityDetailsList>? data;

  EarningActivityModel({this.code, this.message, this.data});

  EarningActivityModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    if (json['data'] != null) {
      data = <EarningActivityDetailsList>[];
      json['data'].forEach((v) {
        data!.add(EarningActivityDetailsList.fromJson(v));
      });
    }
  }
}

class EarningActivityDetailsList {
  int? id;
  String? baseFare;
  String? createdAt;
  dynamic estimatedTime;
  dynamic distanceKm;
  double? pickupLat;
  double? pickupLng;
  String? pickupAddress;
  double? dropLat;
  double? dropLng;
  String? dropAddress;
  dynamic tip;

  EarningActivityDetailsList({
    this.id,
    this.baseFare,
    this.createdAt,
    this.estimatedTime,
    this.distanceKm,
    this.pickupLat,
    this.pickupLng,
    this.pickupAddress,
    this.dropLat,
    this.dropLng,
    this.dropAddress,
    this.tip,
  });

  EarningActivityDetailsList.fromJson(Map<String, dynamic> json) {

    id= json['id'];
    baseFare = json['base_fare'];
    createdAt = json['created_at'];
    estimatedTime = json['estimated_time'];
    distanceKm = json['distance_km'];
    pickupLat = json['pickup_lat'];
    pickupLng = json['pickup_lng'];
    pickupAddress = json['pickup_address'];
    dropLat = json['drop_lat'];
    dropLng = json['drop_lng'];
    dropAddress = json['drop_address'];
    tip = json['tip'];
  }
}
