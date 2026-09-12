import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myridedriverapp/config/utils/constants.dart';

/// Answers one question, from anywhere: is this booking still being offered?
///
/// It exists for the ride-request overlay, which runs in its own Flutter
/// engine with none of the app's machinery available to it — no GetX, no
/// ApiClient, no HomeController and no access to the 3s nearby-bookings poll
/// that keeps the in-app request cards honest. That poll is what takes a card
/// down the moment a booking stops being offered (another driver accepted it,
/// the rider cancelled, it expired); the overlay had no equivalent, which is
/// exactly why a driver whose app was killed went on being shown — and rung at
/// — for a ride somebody else had already taken.
///
/// Deliberately built on `package:http` and SharedPreferences only. `http`
/// resolves to dart:io and so needs no plugin registration at all, and
/// shared_preferences is now explicitly registered onto the overlay engine
/// (see MainActivity.ensureOverlayEngine). Anything heavier — ApiClient, which
/// is a GetxService — cannot exist on that isolate.
///
/// The push-based signal is still the better answer and should be added
/// backend-side (see NavOverlayService.closeRideRequest and the
/// `ride_request_closed` branch in main.dart's FCM handlers). This is the half
/// that works today, with no backend change, and the safety net for when a
/// push is dropped or delayed.
class RideOfferWatch {
  RideOfferWatch._();

  /// How often an open overlay re-checks its booking. Matches the in-app
  /// poll's own cadence, for the same reason: the window between "someone
  /// else accepted" and "this driver stops being asked" is what the driver
  /// experiences as the app wasting their time.
  static const Duration pollInterval = Duration(seconds: 3);

  static const Duration _timeout = Duration(seconds: 8);

  /// Whether [bookingId] is still in this driver's list of open offers.
  ///
  /// Returns null for "could not tell" — no session, no network, a non-200,
  /// an unparseable body. Every caller must treat null as "keep showing the
  /// card". Closing an overlay because a request timed out would silently cost
  /// the driver rides on a bad connection, which is a far worse failure than
  /// leaving a stale card up for the few seconds until its own countdown ends.
  static Future<bool?> isStillOffered(String bookingId) async {
    final String id = bookingId.trim();
    if (id.isEmpty) return null;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString(ApiConstants.token) ?? '';
      final String driverId = prefs.getString(ApiConstants.profileid) ?? '';
      if (token.isEmpty || driverId.isEmpty) return null;

      final response = await http
          .get(
            Uri.parse(ApiConstants.baseUrl + ApiConstants.newBookingLUrl),
            // Exactly the headers ApiClient._mainHeadersMain sends. Spelled
            // out rather than shared because ApiClient is a GetxService and
            // cannot be constructed on the overlay isolate.
            headers: <String, String>{
              'Accept': 'application/json',
              'id': driverId,
              'authorizationToken': token,
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final dynamic body = jsonDecode(response.body);
      if (body is! Map) return null;

      // This endpoint reports success under "status", not the "code" key every
      // other endpoint in this app uses — see the note on the same quirk in
      // HomeController._pollNearbyBookings. Reading the wrong one here would
      // make every response look like a failure, so the card would never close.
      final String status =
          (body['status'] ?? body['code'] ?? '').toString().trim();
      if (status != '200') {
        // A definite "nothing open for you" is an answer, not a failure: some
        // backends report an empty list this way rather than with a 200 and
        // an empty array.
        if (status == '404' || status == '204') return false;
        return null;
      }

      final dynamic data = body['data'];
      if (data is! List) return null;

      for (final dynamic entry in data) {
        if (entry is! Map) continue;
        final String entryId =
            (entry['id'] ?? entry['booking_id'] ?? '').toString().trim();
        if (entryId == id) return true;
      }
      return false;
    } catch (e) {
      debugPrint('[RideOfferWatch] could not check booking $bookingId: $e');
      return null;
    }
  }
}
