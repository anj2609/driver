import 'package:get/get.dart';

import 'package:myridedriverapp/config/utils/apis/api_client.dart';
import 'package:myridedriverapp/config/utils/constants.dart';

class HomeRepo extends GetxService {
  final ApiClient apiClient;

  HomeRepo({required this.apiClient});

  /////========================= NEW BOOKING API =========================
  Future<Response> newBookingApi() async {
    return apiClient.getApi(
      ApiConstants.driverDocument + ApiConstants.vehicaletype,
    );
  }

  Future<Response> driverStatusModeApi() async {
    return apiClient.getDataApi(ApiConstants.driverStatus);
  }

  Future<Response> getDriverProfile() async {
    return apiClient.getDataApi(ApiConstants.getUserProfileUrl);
  }

  Future<Response> newBookingNearByMe() async {
    return apiClient.getDataApi(ApiConstants.newBookingLUrl);
  }

  ///// ======= Driver Location Update  ============================///////////////////
  Future<Response> driverLocationUpdate({double? lat, double? lng}) async {
    return apiClient.postDriverUpdateLocationData(ApiConstants.driverLocationUpdate, {
      "lat": lat.toString(),
      "lng": lng.toString(),
    });
  }

  Future<Response> acceptRide({String? bookingid}) async {
    return apiClient.myridepostData(ApiConstants.acceptRideUrl, {
      "booking_id": bookingid.toString(),
    });
  }

  /////// ============== Driver Arrived =========//////////
  Future<Response> driverArrivedApi({String? bookingid}) async {
    return apiClient.myridepostData(ApiConstants.driverArrived, {
      "booking_id": bookingid.toString(),
    });
  }

////// ======== Complete Ride ======================/////

Future<Response> completeRide({String? bookingid, String source = 'offline'}) async {
    return apiClient.myridepostData(ApiConstants.completeRideUrl, {
      "booking_id": bookingid.toString(),
      "source": source,
    });
  }


////// =================== Verify Pickup Otp ======================/////

  Future<Response> verifyPickupOtp({String? bookingid, String? otpnum}) async {
    return apiClient.myridepostData(ApiConstants.verifyPickupOtpUrl, {
      "booking_id": bookingid.toString(),
      "otp": otpnum.toString()
    });
  }


  
  Future<Response> cancleRidebyDriverSide({
    String? bookingid,
    String? cancellationid,
  }) async {
    return apiClient.myridepostData(ApiConstants.cancelRideByDriverUrl, {
      "booking_id": bookingid.toString(),
      "cancellation_type_id": cancellationid.toString(),
    });
  }

  Future<Response> cancleRide() async {
    return apiClient.getDataalltypeApi(ApiConstants.cancellation);
  }

  Future<Response> trackBookingRide({String? bookingid}) async {
    return apiClient.myridepostData(ApiConstants.trackBookingRide, {
      "booking_id": bookingid.toString(),
    });
  }

///======= Driver Arrived  ===========

  Future<Response> driverBookingActive({String? bookingid}) async {
    return apiClient.getDataalltypeApi  (ApiConstants.driverBookingActive);
  }

///======= Generate QR Code for Online Payment ===========

  Future<Response> generateQrCode({String? bookingId}) async {
    return apiClient.myridepostData(ApiConstants.genrateQrCode, {
      "booking_id": bookingId.toString(),
    });
  }

  Future<Response> verifyQrPayment({String? bookingId, String? qrId}) async {
    return apiClient.myridepostData(ApiConstants.verifyQrPayment, {
      "booking_id": bookingId.toString(),
      "qr_id": qrId.toString(),
    });
  }

  Future<Response> checkPaymentStatus({required String bookingId}) async {
    return apiClient.getDataalltypeApi(
      '${ApiConstants.paymentStatus}/$bookingId',
    );
  }

///======= Estimate Ride List ===========

  Future<Response> estimateRideList({
    required String pickupLat,
    required String pickupLng,
    required String dropLat,
    required String dropLng,
  }) async {
    return apiClient.myridepostData(ApiConstants.estimateUrl, {
      "pickup_lat": pickupLat,
      "pickup_lng": pickupLng,
      "drop_lat": dropLat,
      "drop_lng": dropLng,
    });
  }
}
