class NewBookingNearByListModel {
  String? status;
  String? message;
  List<NewBookingNearByModel>? data;

  NewBookingNearByListModel({this.status, this.message, this.data});

  NewBookingNearByListModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    if (json['data'] != null) {
      data = <NewBookingNearByModel>[];
      json['data'].forEach((v) {
        data!.add(new NewBookingNearByModel.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class NewBookingNearByModel {
  int? id;
  double? pickupLat;
  double? pickupLng;
  String? pickupAddress;
  double? dropLat;
  double? dropLng;
  String? dropAddress;
  double? distance;

  NewBookingNearByModel(
      {this.id,
      this.pickupLat,
      this.pickupLng,
      this.pickupAddress,
      this.dropLat,
      this.dropLng,
      this.dropAddress,
      this.distance});

  NewBookingNearByModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    pickupLat = json['pickup_lat'] != null ? double.tryParse(json['pickup_lat'].toString()) : null;
    pickupLng = json['pickup_lng'] != null ? double.tryParse(json['pickup_lng'].toString()) : null;
    pickupAddress = json['pickup_address'];
    dropLat = json['drop_lat'] != null ? double.tryParse(json['drop_lat'].toString()) : null;
    dropLng = json['drop_lng'] != null ? double.tryParse(json['drop_lng'].toString()) : null;
    dropAddress = json['drop_address'];
    distance = json['distance'] != null ? double.tryParse(json['distance'].toString()) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['pickup_lat'] = this.pickupLat;
    data['pickup_lng'] = this.pickupLng;
    data['pickup_address'] = this.pickupAddress;
    data['drop_lat'] = this.dropLat;
    data['drop_lng'] = this.dropLng;
    data['drop_address'] = this.dropAddress;
    data['distance'] = this.distance;
    return data;
  }
}
