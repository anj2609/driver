// Model for GET driver-booking-list?status=<slug> — the driver-side mirror
// of the rider app's customer-booking-list?status=<slug> (see
// rideruserlestes/lib/data/modal/activity_model.dart), used to feed the
// "Activities" tabs (Ongoing/Scheduled/Completed/Canceled) in the drawer.
//
// CONFIRMED live (see driver_activity_screen.dart's card + a captured
// [DriverActivity] log): each item carries total_fare/final_amount flat at
// the top level, e.g. {..., "total_fare": 1968.08, "final_amount": 2166.48,
// ...} — no "payment" nesting the way /trip-detail has. The payment-object
// fallback below is kept only as defensive tolerance, not because it's ever
// actually been observed on this endpoint. debugPrint('[DriverActivity]
// ...') in the controller still surfaces the raw response for anyone
// re-checking this later.
class DriverActivityModel {
  String? code;
  String? message;
  DriverActivityData? data;

  DriverActivityModel({this.code, this.message, this.data});

  DriverActivityModel.fromJson(Map<String, dynamic> json) {
    code = json['code']?.toString();
    message = json['message']?.toString();

    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      data = DriverActivityData.fromJson(rawData);
    } else if (rawData is List) {
      // Some list endpoints in this backend return a bare array instead of
      // Laravel-style pagination — tolerate both shapes.
      data = DriverActivityData(
        data: rawData
            .whereType<Map>()
            .map((v) => DriverActivityItem.fromJson(Map<String, dynamic>.from(v)))
            .toList(),
      );
    }
  }
}

class DriverActivityData {
  List<DriverActivityItem>? data;

  DriverActivityData({this.data});

  DriverActivityData.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'];
    if (rawList is List) {
      data = rawList
          .whereType<Map>()
          .map((v) => DriverActivityItem.fromJson(Map<String, dynamic>.from(v)))
          .toList();
    }
  }
}

class DriverActivityItem {
  int? id;
  String? status;
  String? createdAt;
  String? pickupAddress;
  String? dropAddress;
  double? pickupLat;
  double? pickupLng;
  double? dropLat;
  double? dropLng;
  String? customerName;
  String? customerPhone;
  String? paymentType;

  /// Same "prefer the final/confirmed figure over the estimate" precedent as
  /// the rider app's ActivityDataMainModel.displayFare. double, not int —
  /// the backend sends these as decimals (e.g. 2166.48); parsing them with
  /// int.tryParse silently returned null for every real booking (Dart's
  /// int.tryParse rejects a string with a decimal point), which is why this
  /// card always showed ₹0 despite the API actually sending a real figure.
  double? totalFare;
  double? finalAmount;

  DriverActivityItem({
    this.id,
    this.status,
    this.createdAt,
    this.pickupAddress,
    this.dropAddress,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.customerName,
    this.customerPhone,
    this.paymentType,
    this.totalFare,
    this.finalAmount,
  });

  DriverActivityItem.fromJson(Map<String, dynamic> json) {
    id = json['id'] is int ? json['id'] : int.tryParse('${json['id']}');
    status = json['status']?.toString();
    createdAt = json['created_at']?.toString();

    pickupAddress = json['pickup_address']?.toString();
    dropAddress = json['drop_address']?.toString();

    pickupLat = double.tryParse('${json['pickup_lat']}');
    pickupLng = double.tryParse('${json['pickup_lng']}');
    dropLat = double.tryParse('${json['drop_lat']}');
    dropLng = double.tryParse('${json['drop_lng']}');

    // Backend field name for "the other party" on a driver-facing list is
    // unconfirmed — accept either a nested customer/user object or flat
    // top-level fields.
    final customer = json['customer'] ?? json['user'] ?? json['rider'];
    if (customer is Map) {
      customerName = customer['name']?.toString();
      customerPhone = customer['phone']?.toString();
    } else {
      customerName = json['customer_name']?.toString();
      customerPhone = json['customer_phone']?.toString();
    }

    paymentType = json['payment_type']?.toString();

    // total_fare/final_amount are read flat first, but /trip-detail's
    // confirmed live shape (see trinpdetails_model.dart) nests these under a
    // "payment" object instead — which is why this card used to always show
    // ₹0: the flat keys this list endpoint may or may not send were the only
    // ones read. Falling back to payment.total_fare/payment.final_amount
    // when the flat key is absent covers both shapes without needing this
    // endpoint's exact response confirmed first.
    final payment = json['payment'];
    totalFare = json['total_fare'] != null
        ? double.tryParse('${json['total_fare']}')
        : (payment is Map ? double.tryParse('${payment['total_fare']}') : null);
    finalAmount = json['final_amount'] != null
        ? double.tryParse('${json['final_amount']}')
        : (payment is Map ? double.tryParse('${payment['final_amount']}') : null);
  }

  double get displayFare => finalAmount ?? totalFare ?? 0;
}
