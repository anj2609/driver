class RideAcceptedModel {
  int? code;
  String? message;
  RideData? data;

  RideAcceptedModel({this.code, this.message, this.data});

  RideAcceptedModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? RideData.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> dataMap = {};
    dataMap['code'] = code;
    dataMap['message'] = message;
    if (data != null) {
      dataMap['data'] = data!.toJson();
    }
    return dataMap;
  }
}

class RideData {
  int? id;
  String? bookingId;
  int? customerId;
  int? driverId;
  dynamic vehicleId;
  int? vehicleTypeId;
  double? pickupLat;
  double? pickupLng;
  String? pickupAddress;
  double? dropLat;
  double? dropLng;
  String? dropAddress;
  int? pickupOtp;
  dynamic driverArrivedAt;
  dynamic otpVerifiedAt;
  dynamic driverLat;
  dynamic driverLng;
  dynamic distanceKm;
  dynamic estimatedTime;
  String? baseFare;
  String? discountFare;
  String? distanceFare;
  String? timeFare;
  String? surgeMultiplier;
  String? totalFare;
  dynamic promoCode;
  int? promoDiscount;
  int? walletUsed;
  String? finalAmount;
  int? isPaid;
  String? status;
  int? isSchedule;
  dynamic scheduleDateTime;
  dynamic rideStartTime;
  dynamic rideEndTime;
  dynamic invoicePath;
  String? createdAt;
  String? updatedAt;
  int? driverNotified;
  dynamic cancelledBy;

  RideData({
    this.id,
    this.bookingId,
    this.customerId,
    this.driverId,
    this.vehicleId,
    this.vehicleTypeId,
    this.pickupLat,
    this.pickupLng,
    this.pickupAddress,
    this.dropLat,
    this.dropLng,
    this.dropAddress,
    this.pickupOtp,
    this.driverArrivedAt,
    this.otpVerifiedAt,
    this.driverLat,
    this.driverLng,
    this.distanceKm,
    this.estimatedTime,
    this.baseFare,
    this.discountFare,
    this.distanceFare,
    this.timeFare,
    this.surgeMultiplier,
    this.totalFare,
    this.promoCode,
    this.promoDiscount,
    this.walletUsed,
    this.finalAmount,
    this.isPaid,
    this.status,
    this.isSchedule,
    this.scheduleDateTime,
    this.rideStartTime,
    this.rideEndTime,
    this.invoicePath,
    this.createdAt,
    this.updatedAt,
    this.driverNotified,
    this.cancelledBy,
  });

  RideData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    bookingId = json['booking_id'];
    customerId = json['customer_id'];
    driverId = json['driver_id'];
    vehicleId = json['vehicle_id'];
    vehicleTypeId = json['vehicle_type_id'];
    pickupLat = json['pickup_lat']?.toDouble();
    pickupLng = json['pickup_lng']?.toDouble();
    pickupAddress = json['pickup_address'];
    dropLat = json['drop_lat']?.toDouble();
    dropLng = json['drop_lng']?.toDouble();
    dropAddress = json['drop_address'];
    pickupOtp = json['pickup_otp'];
    driverArrivedAt = json['driver_arrived_at'];
    otpVerifiedAt = json['otp_verified_at'];
    driverLat = json['driver_lat'];
    driverLng = json['driver_lng'];
    distanceKm = json['distance_km'];
    estimatedTime = json['estimated_time'];
    baseFare = json['base_fare'];
    discountFare = json['discount_fare'];
    distanceFare = json['distance_fare'];
    timeFare = json['time_fare'];
    surgeMultiplier = json['surge_multiplier'];
    totalFare = json['total_fare'];
    promoCode = json['promo_code'];
    promoDiscount = json['promo_discount'];
    walletUsed = json['wallet_used'];
    finalAmount = json['final_amount'];
    isPaid = json['is_paid'];
    status = json['status'];
    isSchedule = json['is_schedule'];
    scheduleDateTime = json['schedule_date_time'];
    rideStartTime = json['ride_start_time'];
    rideEndTime = json['ride_end_time'];
    invoicePath = json['invoice_path'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    driverNotified = json['driver_notified'];
    cancelledBy = json['cancelled_by'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> dataMap = {};
    dataMap['id'] = id;
    dataMap['booking_id'] = bookingId;
    dataMap['customer_id'] = customerId;
    dataMap['driver_id'] = driverId;
    dataMap['vehicle_id'] = vehicleId;
    dataMap['vehicle_type_id'] = vehicleTypeId;
    dataMap['pickup_lat'] = pickupLat;
    dataMap['pickup_lng'] = pickupLng;
    dataMap['pickup_address'] = pickupAddress;
    dataMap['drop_lat'] = dropLat;
    dataMap['drop_lng'] = dropLng;
    dataMap['drop_address'] = dropAddress;
    dataMap['pickup_otp'] = pickupOtp;
    dataMap['driver_arrived_at'] = driverArrivedAt;
    dataMap['otp_verified_at'] = otpVerifiedAt;
    dataMap['driver_lat'] = driverLat;
    dataMap['driver_lng'] = driverLng;
    dataMap['distance_km'] = distanceKm;
    dataMap['estimated_time'] = estimatedTime;
    dataMap['base_fare'] = baseFare;
    dataMap['discount_fare'] = discountFare;
    dataMap['distance_fare'] = distanceFare;
    dataMap['time_fare'] = timeFare;
    dataMap['surge_multiplier'] = surgeMultiplier;
    dataMap['total_fare'] = totalFare;
    dataMap['promo_code'] = promoCode;
    dataMap['promo_discount'] = promoDiscount;
    dataMap['wallet_used'] = walletUsed;
    dataMap['final_amount'] = finalAmount;
    dataMap['is_paid'] = isPaid;
    dataMap['status'] = status;
    dataMap['is_schedule'] = isSchedule;
    dataMap['schedule_date_time'] = scheduleDateTime;
    dataMap['ride_start_time'] = rideStartTime;
    dataMap['ride_end_time'] = rideEndTime;
    dataMap['invoice_path'] = invoicePath;
    dataMap['created_at'] = createdAt;
    dataMap['updated_at'] = updatedAt;
    dataMap['driver_notified'] = driverNotified;
    dataMap['cancelled_by'] = cancelledBy;
    return dataMap;
  }
}