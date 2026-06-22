class TripDetailsModel {
  String? code;
  String? message;
  Data? data;

  TripDetailsModel({this.code, this.message, this.data});

  TripDetailsModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
  }

 
}

class Data {
  int? bookingId;
  String? status;
  double? pickupLat;
  double? pickupLng;
  double? dropLat;
  double? dropLng;
  String? baseFare;
  String? discountFare;
  String? totalFare;
  int? distance;

  Data(
      {this.bookingId,
      this.status,
      this.pickupLat,
      this.pickupLng,
      this.dropLat,
      this.dropLng,
      this.baseFare,
      this.discountFare,
      this.totalFare,
      this.distance});

  Data.fromJson(Map<String, dynamic> json) {
    bookingId = json['booking_id'];
    status = json['status'];
    pickupLat = json['pickup_lat'];
    pickupLng = json['pickup_lng'];
    dropLat = json['drop_lat'];
    dropLng = json['drop_lng'];
    baseFare = json['base_fare'];
    discountFare = json['discount_fare'];
    totalFare = json['total_fare'];
    distance = json['distance'] == null
    ? null
    : int.tryParse(json['distance'].toString());
    //distance = json['distance'];
  }


}
