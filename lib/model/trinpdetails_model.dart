import 'package:myridedriverapp/services/geo_utils.dart' as geo;

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

  // Confirmed live via the rider app's own /trip-detail model (see
  // rideruserlestes/lib/data/modal/trip_detail_model.dart, TripLocation):
  // pickup/drop coordinates come nested as pickup:{address,lat,lng} and
  // drop:{...}, not as flat pickup_lat/pickup_lng/drop_lat/drop_lng. Flat
  // keys are still read as a fallback below in case some booking/ride-type
  // response shape sends them that way instead — several live-tracking
  // screens (pickup_screen.dart, home_controller.dart, startride_screen.dart)
  // also read these same fields, so fixing the parse here fixes them too.
  double? pickupLat;
  double? pickupLng;
  double? dropLat;
  double? dropLng;
  String? pickupAddress;
  String? dropAddress;

  String? totalFare;

  // Backend-reported distance (km), tried against the same candidate
  // locations the rider app's TripRideStats does. Kept, but no longer what
  // the UI shows — see distanceKm below for why.
  double? distance;

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
      this.pickupAddress,
      this.dropAddress,
      this.totalFare,
      this.distance,
      this.finalAmount,
      this.paymentTotalFare,
      this.promoDiscount,
      this.walletUsed});

  Data.fromJson(Map<String, dynamic> json) {
    bookingId = json['booking_id'] is int
        ? json['booking_id']
        : int.tryParse('${json['booking_id']}');
    status = json['status'];

    final pickup = json['pickup'];
    final drop = json['drop'];

    pickupLat = _toDouble(pickup is Map ? pickup['lat'] : json['pickup_lat']);
    pickupLng = _toDouble(pickup is Map ? pickup['lng'] : json['pickup_lng']);
    dropLat = _toDouble(drop is Map ? drop['lat'] : json['drop_lat']);
    dropLng = _toDouble(drop is Map ? drop['lng'] : json['drop_lng']);
    pickupAddress =
        (pickup is Map ? pickup['address'] : json['pickup_address'])
            ?.toString();
    dropAddress = (drop is Map ? drop['address'] : json['drop_address'])
        ?.toString();

    totalFare = json['total_fare']?.toString();
    distance = _distanceFromJson(json);

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

  /// Straight-line (haversine) distance between pickup and drop, in
  /// kilometres — computed client-side from the same pickup/drop
  /// coordinates the map plots, rather than shown from the backend's own
  /// `distance`/`final_distance` field. Same fix, same reasoning as the
  /// rider app's haversineDistanceKm (see rideruserlestes/lib/data/modal/
  /// trip_detail_model.dart): a live-captured /trip-detail response
  /// returned a backend distance wildly larger than the real road distance
  /// between two points both in the same city, so that figure can't be
  /// trusted as-is. Pickup/drop coordinates are exactly what was booked and
  /// can't be wrong the same way. Reuses this app's own geo_utils.dart
  /// (already used by home_controller.dart for the same kind of backend
  /// sanity-check) rather than a second copy of the formula.
  double? get distanceKm {
    if (pickupLat == null ||
        pickupLng == null ||
        dropLat == null ||
        dropLng == null) {
      return null;
    }
    return geo.haversineDistanceKm(pickupLat!, pickupLng!, dropLat!, dropLng!);
  }
}

/// Distance (km), tried against the same candidate locations the rider
/// app's TripRideStats does — whichever candidate map actually carries one
/// of the recognised keys wins; null if none do, rather than the parse
/// guessing further.
double? _distanceFromJson(Map<String, dynamic> json) {
  final tripSummary = json['trip_summary'];
  final rideDetails = json['ride_details'];
  final nestedTrip = rideDetails is Map ? rideDetails['trip'] : null;

  bool hasDistance(dynamic m) {
    if (m is! Map) return false;
    return m['final_distance'] != null ||
        m['distance_km'] != null ||
        m['distance'] != null;
  }

  for (final candidate in [tripSummary, nestedTrip, json]) {
    if (hasDistance(candidate)) {
      final m = candidate as Map;
      return _toDouble(m['final_distance'] ?? m['distance_km'] ?? m['distance']);
    }
  }
  return null;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
