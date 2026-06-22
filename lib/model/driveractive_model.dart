class DriverBookingActives {
  String? code;
  String? message;
  DriverBookingActive? data;

  DriverBookingActives({this.code, this.message, this.data});

  DriverBookingActives.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? new DriverBookingActive.fromJson(json['data']) : null;
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

class DriverBookingActive {
  int? bookingId;
  String? status;
  String? otp;
  double? lat;
  double? lng;
  CustomerInfo? customerInfo;

  DriverBookingActive(
      {this.bookingId,
      this.status,
      this.otp,
      this.lat,
      this.lng,
      this.customerInfo});

  DriverBookingActive.fromJson(Map<String, dynamic> json) {
    bookingId = json['booking_id'];
    status = json['status'];
    otp = json['otp'];
    lat = json['lat'] != null ? double.tryParse(json['lat'].toString()) : null;
    lng = json['lng'] != null ? double.tryParse(json['lng'].toString()) : null;
    customerInfo = json['customer_info'] != null
        ? new CustomerInfo.fromJson(json['customer_info'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['booking_id'] = this.bookingId;
    data['status'] = this.status;
    data['otp'] = this.otp;
    data['lat'] = this.lat;
    data['lng'] = this.lng;
    if (this.customerInfo != null) {
      data['customer_info'] = this.customerInfo!.toJson();
    }
    return data;
  }
}

class CustomerInfo {
  String? profileImage;
  String? name;
  String? phone;

  CustomerInfo({this.profileImage, this.name, this.phone});

  CustomerInfo.fromJson(Map<String, dynamic> json) {
    profileImage = json['profile_image'];
    name = json['name'];
    phone = json['phone'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['profile_image'] = this.profileImage;
    data['name'] = this.name;
    data['phone'] = this.phone;
    return data;
  }
}
