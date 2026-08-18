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
  /// Whole-trip length, pickup to drop, in km. Pairs with [time].
  double? distance;
  /// How far this driver is from the pickup point, in km. Not shown on the
  /// card yet — see the note in fromJson.
  double? driverToPickupDistance;
  // Were never parsed at all — the incoming-booking card showed a
  // hardcoded "Customer" label, a bundled placeholder image, and no fare,
  // regardless of what the backend actually sent, because this model
  // simply had nowhere to put that data.
  String? customerName;
  String? customerImage;
  String? fare;
  // Same gap as customerName/customerImage/fare above: never parsed, so
  // the card had no pickup/request time to show regardless of what the
  // backend sent. "time" is the confirmed key for this on AcceptRideModel
  // (the accept-ride response, whose customer_info shape this model's
  // fallback parsing above already mirrors) — new-booking-list isn't
  // confirmed to use the exact same key, so a couple of other plausible
  // ones are checked too, whichever the backend actually sends here.
  String? time;

  NewBookingNearByModel(
      {this.id,
      this.pickupLat,
      this.pickupLng,
      this.pickupAddress,
      this.dropLat,
      this.dropLng,
      this.dropAddress,
      this.distance,
      this.driverToPickupDistance,
      this.customerName,
      this.customerImage,
      this.fare,
      this.time});

  NewBookingNearByModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    pickupLat = json['pickup_lat'] != null ? double.tryParse(json['pickup_lat'].toString()) : null;
    pickupLng = json['pickup_lng'] != null ? double.tryParse(json['pickup_lng'].toString()) : null;
    pickupAddress = json['pickup_address'];
    dropLat = json['drop_lat'] != null ? double.tryParse(json['drop_lat'].toString()) : null;
    dropLng = json['drop_lng'] != null ? double.tryParse(json['drop_lng'].toString()) : null;
    dropAddress = json['drop_address'];
    // This endpoint sends *two* distance figures: "distance" — the whole
    // trip's pickup-to-drop length (2396.71 for Ghaziabad → Agartala) — and
    // "driver_to_pickup_distance", how far this driver is from the pickup
    // point (e.g. 0.01).
    //
    // [distance] is the trip length, deliberately, so that it pairs with
    // [time], which is the trip's duration. The card shows the two together;
    // having one describe the journey and the other the driver's approach
    // made the pair unreadable ("0.9 km · 46h 21m"). This previously read
    // driver_to_pickup_distance for that slot — do not switch it back
    // without also moving [time] to match.
    distance = json['distance'] != null
        ? double.tryParse(json['distance'].toString())
        : null;

    // Kept separate and still parsed: "how far away is this rider" is
    // genuinely useful to a driver deciding whether to accept, it just
    // belongs next to the customer's name rather than next to the trip
    // duration.
    driverToPickupDistance = json['driver_to_pickup_distance'] != null
        ? double.tryParse(json['driver_to_pickup_distance'].toString())
        : null;

    // The confirmed accept-ride response (AcceptRideData) nests this
    // under a "customer_info" object ({customer_id, profile_image, name,
    // phone, lat, lng}) — this endpoint isn't confirmed to use the exact
    // same shape, so both the nested and several plausible flat key names
    // are checked, whichever the backend actually sends here.
    final customerInfo = json['customer_info'];
    if (customerInfo is Map) {
      customerName = customerInfo['name']?.toString();
      customerImage = customerInfo['profile_image']?.toString();
    }
    customerName ??= (json['customer_name'] ?? json['user_name'] ?? json['name'])
        ?.toString();
    customerImage ??= (json['customer_image'] ??
            json['profile_image'] ??
            json['user_image'])
        ?.toString();

    // CONFIRMED from a real device log: this endpoint sends the fare as
    // "final_amount" — none of the previously-guessed keys below actually
    // matched, so fare was always null and the card never showed a price
    // at all. Checked first; the older guesses stay as a fallback.
    fare = (json['final_amount'] ??
            json['total_fare'] ??
            json['fare'] ??
            json['price'] ??
            json['estimated_fare'] ??
            json['base_fare'])
        ?.toString();

    // There's no request/booking timestamp field on this endpoint — what it
    // sends is "duration", the trip's estimated driving time in MINUTES.
    //
    // This was previously read as seconds and divided by 60. Verified
    // against the live API on a Ghaziabad → Agartala booking: for one route
    // estimate-ride-list reports "estimated_time":"2780 mins" while
    // outstation/estimate and trip-detail both report "duration":2781 —
    // the same number, so the unit is minutes. Dividing by 60 rendered that
    // 46-hour trip as "47 min" on the card.
    //
    // Parsed as a double before rounding because the field is not
    // guaranteed to be an integer (trip-detail returns 2781, but the
    // estimate's own distance/duration pair carries decimals).
    final rawDuration = json['duration'];
    if (rawDuration != null) {
      final minutes = double.tryParse(rawDuration.toString())?.round();
      if (minutes != null) {
        time = minutes < 60
            ? '$minutes min'
            : '${minutes ~/ 60}h ${minutes % 60}m';
      }
    }
    time ??= (json['time'] ??
            json['request_time'] ??
            json['booking_time'] ??
            json['created_at'])
        ?.toString();
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
    data['customer_name'] = this.customerName;
    data['customer_image'] = this.customerImage;
    data['fare'] = this.fare;
    data['time'] = this.time;
    return data;
  }
}
