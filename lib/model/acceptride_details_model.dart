class AcceptRideModel {
  String? code;
  String? message;
  AcceptRideData? data;

  AcceptRideModel({this.code, this.message, this.data});

  AcceptRideModel.fromJson(Map<String, dynamic> json) {
    code = json['code']?.toString();
    message = json['message'];
    data = json['data'] != null ? AcceptRideData.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    return {'code': code, 'message': message, 'data': data?.toJson()};
  }
}

class AcceptRideData {
  int? bookingId;
  String? status;
  String? otp;
  double? lat;
  double? lng;
  String? pickupaddress;
  String? dropaddress;

  ///pickup_address
  CustomerInfo? customerInfo;
  String? baseFare;
  String? totalFare;
  String? distance;
  String? time;

  AcceptRideData({
    this.bookingId,
    this.status,
    this.otp,
    this.lat,
    this.lng,
    this.pickupaddress,
    this.dropaddress,
    this.customerInfo,
    this.baseFare,
    this.totalFare,
    this.distance,
    this.time,
  });

  AcceptRideData.fromJson(Map<String, dynamic> json) {
    bookingId = json['booking_id'];
    status = json['status'];
    otp = json['otp'];

    lat = json['lat'] != null ? (json['lat'] as num).toDouble() : null;
    lng = json['lng'] != null ? (json['lng'] as num).toDouble() : null;
    pickupaddress = json['pickup_address'];
    dropaddress = json['drop_address'];

    customerInfo = json['customer_info'] != null
        ? CustomerInfo.fromJson(json['customer_info'])
        : null;

    baseFare = json['base_fare']?.toString();
    totalFare = json['total_fare']?.toString();
    distance = json['distance']?.toString();
    time = json['time']?.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'status': status,
      'otp': otp,
      'lat': lat,
      'lng': lng,
      'pickup_address': pickupaddress,
      'drop_address': dropaddress,
      'customer_info': customerInfo?.toJson(),
      'base_fare': baseFare,
      'total_fare': totalFare,
      'distance': distance,
      'time': time,
    };
  }
}

class CustomerInfo {
  int? customer;
  String? profileImage;
  String? name;
  String? phone;
  double? lat;
  double? lng;

  CustomerInfo({
    this.customer,
    this.profileImage,
    this.name,
    this.phone,
    this.lat,
    this.lng,
  });

  CustomerInfo.fromJson(Map<String, dynamic> json) {
    customer = json['customer_id'];
    profileImage = json['profile_image'];
    name = json['name'];
    phone = json['phone'];

    lat = json['lat'] != null ? (json['lat'] as num).toDouble() : null;
    lng = json['lng'] != null ? (json['lng'] as num).toDouble() : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'customer': customer,
      'profile_image': profileImage,
      'name': name,
      'phone': phone,
      'lat': lat,
      'lng': lng,
    };
  }
}
