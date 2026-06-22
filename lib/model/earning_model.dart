// class EarningModels {
//   int? code;

class EarningModels {
  int? code;
  String? message;
  EarningDetailsModel? data;

  EarningModels({this.code, this.message, this.data});

  EarningModels.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null
        ? new EarningDetailsModel.fromJson(json['data'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['code'] = this.code;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class EarningDetailsModel {
  List<String>? labels;
  List<int>? values;
  RideDetails? rideDetails;

  EarningDetailsModel({this.labels, this.values, this.rideDetails});

  EarningDetailsModel.fromJson(Map<String, dynamic> json) {
    labels = json['labels'].cast<String>();
    values = json['values'].cast<int>();
    rideDetails = json['rideDetails'] != null
        ? new RideDetails.fromJson(json['rideDetails'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['labels'] = this.labels;
    data['values'] = this.values;
    if (this.rideDetails != null) {
      data['rideDetails'] = this.rideDetails!.toJson();
    }
    return data;
  }
}

class RideDetails {
  int? totalTrip;
  int? totalDistance;
  int? netFare;
  int? tipAmount;
  int? totalEarning;

  RideDetails({
    this.totalTrip,
    this.totalDistance,
    this.netFare,
    this.tipAmount,
    this.totalEarning,
  });

  RideDetails.fromJson(Map<String, dynamic> json) {
    totalTrip = json['total_trip'];
    totalDistance = json['total_distance'];
    netFare = json['net_fare'];
    tipAmount = json['tip_amount'];
    totalEarning = json['total_earning'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['total_trip'] = this.totalTrip;
    data['total_distance'] = this.totalDistance;
    data['net_fare'] = this.netFare;
    data['tip_amount'] = this.tipAmount;
    data['total_earning'] = this.totalEarning;
    return data;
  }
}
