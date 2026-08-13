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
  double? dropLat;
  double? dropLng;
  String? pickupaddress;
  String? dropaddress;

  ///pickup_address
  CustomerInfo? customerInfo;
  String? baseFare;
  String? totalFare;
  String? distance;
  String? time;
  String? paymentMode;

  AcceptRideData({
    this.bookingId,
    this.status,
    this.otp,
    this.lat,
    this.lng,
    this.dropLat,
    this.dropLng,
    this.pickupaddress,
    this.dropaddress,
    this.customerInfo,
    this.baseFare,
    this.totalFare,
    this.distance,
    this.time,
    this.paymentMode,
  });

  AcceptRideData.fromJson(Map<String, dynamic> json) {
    bookingId = json['booking_id'];
    status = json['status'];
    otp = json['otp'];

    // Was `(json['lat'] as num).toDouble()` — a hard cast that throws
    // (TypeError, not just a bad parse) the moment this backend ever sends
    // lat/lng as a numeric-looking string instead of a raw JSON number,
    // unlike dropLat/dropLng right below (already using the safe
    // tryParse-on-toString pattern used everywhere else in this file/app).
    // Since this whole fromJson() runs inside trackbookingRide()'s
    // catch-all (home_controller.dart), a thrown TypeError here meant
    // trackRideModel never got reassigned at all — silently, every single
    // 15s poll — which is exactly what leaves pickup_screen.dart's
    // InAppNavigationMap stuck on "Finding route…"/a spinner forever: the
    // pickup destination coordinates it needs never arrive.
    lat = json['lat'] != null ? double.tryParse(json['lat'].toString()) : null;
    lng = json['lng'] != null ? double.tryParse(json['lng'].toString()) : null;
    dropLat = json['drop_lat'] != null ? double.tryParse(json['drop_lat'].toString()) : null;
    dropLng = json['drop_lng'] != null ? double.tryParse(json['drop_lng'].toString()) : null;
    pickupaddress = json['pickup_address'];
    dropaddress = json['drop_address'];

    customerInfo = json['customer_info'] != null
        ? CustomerInfo.fromJson(json['customer_info'])
        : null;

    baseFare = json['base_fare']?.toString();
    totalFare = json['total_fare']?.toString();
    distance = json['distance']?.toString();
    time = json['time']?.toString();
    paymentMode = (json['payment_mode'] ?? json['payment_type'] ?? json['payment_method'])?.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'status': status,
      'otp': otp,
      'lat': lat,
      'lng': lng,
      'drop_lat': dropLat,
      'drop_lng': dropLng,
      'pickup_address': pickupaddress,
      'drop_address': dropaddress,
      'customer_info': customerInfo?.toJson(),
      'base_fare': baseFare,
      'total_fare': totalFare,
      'distance': distance,
      'time': time,
      'payment_mode': paymentMode,
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

    // Same hard-cast-throws-on-string fix as AcceptRideData.lat/lng above.
    lat = json['lat'] != null ? double.tryParse(json['lat'].toString()) : null;
    lng = json['lng'] != null ? double.tryParse(json['lng'].toString()) : null;
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
