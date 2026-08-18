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
    // The backend sends this response nested — pickup/drop/payment objects and
    // ride_details.trip — the same shape the rider app's trip_detail_model
    // already parses. This model was written for an older flat shape, so every
    // field below read a top-level key that no longer exists and came back
    // null: no pickup/drop coordinates (navigation had nothing to target), no
    // distance or duration (the "0.0 km / —" on the pickup sheet), no OTP.
    // Each field now reads the nested location first and falls back to the old
    // flat key, so both formats work.
    Map<String, dynamic>? obj(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    double? toDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());

    final pickup = obj(json['pickup']);
    final drop = obj(json['drop']);
    final payment = obj(json['payment']);
    final trip = obj(obj(json['ride_details'])?['trip']);
    // The other party on the card: the customer for the driver app, the driver
    // for the rider app — whichever the response actually carries.
    final party = obj(json['customer_info']) ??
        obj(json['customer']) ??
        obj(json['driver']);

    bookingId = json['booking_id'];
    status = json['status'];
    otp = (json['pickup_otp'] ?? json['otp'])?.toString();

    lat = toDouble(pickup?['lat'] ?? json['lat']);
    lng = toDouble(pickup?['lng'] ?? json['lng']);
    dropLat = toDouble(drop?['lat'] ?? json['drop_lat']);
    dropLng = toDouble(drop?['lng'] ?? json['drop_lng']);
    pickupaddress = (pickup?['address'] ?? json['pickup_address'])?.toString();
    dropaddress = (drop?['address'] ?? json['drop_address'])?.toString();

    customerInfo = party != null ? CustomerInfo.fromJson(party) : null;

    baseFare = json['base_fare']?.toString();
    totalFare = (payment?['total_fare'] ?? json['total_fare'])?.toString();
    // ride_details.trip.distance / .duration — the values the user pointed at.
    distance = (trip?['distance'] ?? json['distance'])?.toString();
    time = (trip?['duration'] ?? json['time'])?.toString();
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
    // This object arrives labelled customer_info, customer or driver depending
    // on the endpoint, and its id/image keys vary with it — read whichever
    // form is present rather than one fixed spelling.
    customer = json['customer_id'] ?? json['customer'] ?? json['id'];
    profileImage = (json['profile_image'] ?? json['image'])?.toString();
    name = json['name']?.toString();
    phone = json['phone']?.toString();

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
