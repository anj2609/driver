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

  // The real, live /trip-detail response (confirmed via the rider app's own
  // model, which this mirrors) nests fare under `payment`, not at the top
  // level: {data: {payment: {total_fare, final_amount, ...}, ...}}. The
  // fields above were reading json['total_fare'] etc. from the top level,
  // which is why they always came back null and the ride-complete screen
  // fell back to a pre-completion snapshot instead. Added rather than
  // replacing the fields above — mainactivity_detail_screen.dart already
  // depends on those for other bookings/response shapes.
  double? finalAmount;
  double? paymentTotalFare;
  double? promoDiscount;
  double? walletUsed;

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
      this.distance,
      this.finalAmount,
      this.paymentTotalFare,
      this.promoDiscount,
      this.walletUsed});

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

    final payment = json['payment'];
    if (payment is Map) {
      finalAmount = _toDouble(payment['final_amount']);
      paymentTotalFare = _toDouble(payment['total_fare']);
      promoDiscount = _toDouble(payment['promo_discount']);
      walletUsed = _toDouble(payment['wallet_used']);
    }
  }

  /// The one figure every fare/amount display for this booking should
  /// show, consistently — final_amount first, falling back through the
  /// less-authoritative fields only when it isn't present. Single accessor
  /// so every screen reading this model shows the same number the same
  /// way, rather than each repeating its own fallback chain (and risking
  /// two different figures on the same screen, as mainactivity_detail_
  /// screen.dart's top amount and its own "Final Amount" row used to).
  String get displayFare =>
      finalAmount?.toStringAsFixed(2) ??
      paymentTotalFare?.toStringAsFixed(2) ??
      totalFare ??
      '0';
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
