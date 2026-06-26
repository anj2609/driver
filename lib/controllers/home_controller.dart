import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/dimensions.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/driver_controller.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/model/acceptedride_model.dart';
import 'package:myridedriverapp/model/acceptride_details_model.dart';
import 'package:myridedriverapp/model/canclereason_model.dart';
import 'package:myridedriverapp/model/driveractive_model.dart';
import 'package:myridedriverapp/model/newbooking_nearby_model.dart';
import 'package:myridedriverapp/model/trinpdetails_model.dart';
import 'package:myridedriverapp/model/qr_payment_model.dart';
import 'package:myridedriverapp/repository/home_repo.dart';
import 'package:myridedriverapp/screens/ride/trip_request_screen.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:http/http.dart' as http;
import 'package:myridedriverapp/widgets/toaster_animation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeController extends GetxController {
  final HomeRepo homeRepo;
  HomeController({required this.homeRepo});

  bool isActiveLoading = false;
  bool isRingtonePlaying = false;
  bool hasActiveRide = false;
  // true once the ringtone has played for the current ride batch; resets when trips clear
  bool _rideRingtoneHasPlayed = false;

  StreamSubscription<Position>? positionStream;
  NewBookingNearByListModel? newBookingNearByModel;
  List<NewBookingNearByModel> newBookingNearByList = [];
  CancleReasonModel? cancleReasonModel;
  List<CancleReasonListModel> cancleReasonModelList = [];
  double? latitude;
  double? longitude;

  List<NewBookingNearByModel> incomingTrips = [];
  List<NewBookingNearByModel> acceptedTrip = [];
  DriverBookingActives? driverBookingActivesModel;
  final AudioPlayer _player = AudioPlayer();
  NewBookingNearByModel? savedTripData;
  AcceptRideModel? savedAcceptData;

  RideData? tripdata;
  Timer? _dummyTimer;
  Timer? _ringtoneTimer;
  ////driverlatitude driverlongitude
  bool isIncomingScreenOpen = false;
  dynamic workStatus;
  AcceptRideModel? trackRideModel;
  DateTime? lastUpdateTime;
  dynamic totalDistance;
  dynamic totalTime;
  Set<Polyline> polylines = {};
  String? totaldestances = '';
  String totaltimes = '';
  double? pickupLat;
  double? pickupLng;
  Set<Marker> markers = {};
  BitmapDescriptor? carIcon;
  BitmapDescriptor? userIcon;
  String arrivedStatusCode = '';
  String verifyPickupOtpStatusCode = '';
  StreamSubscription<Position>? positionStreams;
  GoogleMapController? mapController;

  bool _isInitialized = false;

  @override
  void onInit() {
    super.onInit();
    if (_isInitialized) return;
    _isInitialized = true;

    startLocationUpdates();
    startAutoUpdate();
    loadCustomMarker();
    loadUserMarker();
    // Online status is restored from SharedPreferences via loadSavedStatus() below
    loadSavedStatus();
    stopLiveTracking();
    loadOnlineStatus();
    cancleRideReason();
  }

  @override
  void onClose() {
    _autoUpdateTimer?.cancel();
    positionStream?.cancel();
    _dummyTimer?.cancel();
    _ringtoneTimer?.cancel();
    positionStreams?.cancel();
    isRingtonePlaying = false;
    try {
      _player.dispose();
    } catch (_) {}
    super.onClose();
  }

  Future<void> loadOnlineStatus() async {
    final prefs = await SharedPreferences.getInstance();
    isOnline = prefs.getBool("isOnline") ?? false;
    driverBookingActives();
    if (isOnline) {
      startListeningBookings();
    }
    update();
    print('sttsuaaaa:::${isOnline}');
  }

  void stopLiveTracking() {
    positionStreams?.cancel();
  }

  Future<void> setWorkStatus(dynamic status) async {
    workStatus = status;

    isOnline = status == 1;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("work_status", status);
    startLocationUpdates();
    update();
  }

  Future<void> userOnLine() async {
    final prefs = await SharedPreferences.getInstance();
    workStatus = prefs.getInt("work_status");
    if (workStatus == 1) {
      startListeningBookings();
    } else {
      stopListeningBookings();
    }
    update();
  }

  Future<void> loadSavedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    workStatus = prefs.getInt("work_status") ?? 0;
    update();
  }

  Timer? _autoUpdateTimer;

  void startAutoUpdate() {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (latitude != null && longitude != null) {
        driverUpdateLocation(lat: latitude!, lng: longitude!);
      }
    });
  }

  bool isOnline = false;
  bool isLoading = false;
  static const String isOnlineKey = "isOnline";
  static const String saveRideStatus = "pending";
  Future<void> saveOnlineStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(isOnlineKey, status);
  }

  Future<void> saveRideBookingStatus(String statusRide) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('booking_id', statusRide);
    print('testing  booking id ${statusRide}');
  }

  Future<void> toggleOnline(bool value, BuildContext context) async {
    if (isLoading) return;

    isLoading = true;
    update();

    try {
      Response res = await driverStatusOnlineOffline(context: context);

      if (res.statusCode == 200 && res.body['code'] == "200") {
        var data = res.body['data'];

        var rawStatus = data['work_status'];

        int workStatus = 0;

        if (rawStatus is int) {
          workStatus = rawStatus;
        } else if (rawStatus is String) {
          workStatus = int.tryParse(rawStatus) ?? 0;
        }

        isOnline = workStatus == 1;

        await saveOnlineStatus(isOnline);

        if (isOnline) {
          startListeningBookings();
        } else {
          stopListeningBookings();
        }
      } else {
        Get.snackbar("Error", "Could not update availability status. Please try again.");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to change availability. Please check your connection.");
    }

    isLoading = false;
    update();
  }

  void startLocationUpdates() {
    positionStream?.cancel();

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            latitude = position.latitude;
            longitude = position.longitude;
            driverLatitude = position.latitude;
            driverLongitude = position.longitude;

            print("Lat: $latitude, Lng: $longitude");

            update();
          },
        );
  }

  void startListeningBookings() {
    stopListeningBookings();
    // Fire immediately so the driver sees nearby rides the moment they go online
    _pollNearbyBookings();
    _dummyTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollNearbyBookings());
  }

  Future<void> _pollNearbyBookings() async {
    if (!isOnline) return;

    // Do not search if the driver is busy with an accepted/ongoing ride
    try {
      final profileRes = await homeRepo.getDriverProfile();
      if (profileRes.statusCode == 200 && profileRes.body != null) {
        final profileData = profileRes.body['data'];
        final isBusy = profileData?['is_busy'];
        if (isBusy == true || isBusy == 1 || isBusy?.toString() == '1') {
          debugPrint('Driver is_busy — skipping new-booking-list poll');
          return;
        }
      }
    } catch (_) {
      // Profile check failed — skip poll to be safe
      return;
    }

    try {
      Response response = await homeRepo.newBookingNearByMe();

      if (response.statusCode == 200 && response.body['code'] == "200") {
        List data = response.body['data'] ?? [];

        List<NewBookingNearByModel> apiTrips = data
            .map((trip) => NewBookingNearByModel.fromJson(trip))
            .toList();

        incomingTrips.clear();
        incomingTrips.addAll(apiTrips);

        if (incomingTrips.isNotEmpty) {
          if (!_rideRingtoneHasPlayed) {
            _rideRingtoneHasPlayed = true;
            playRingtone();
          }
        } else {
          _rideRingtoneHasPlayed = false;
          stopRingtone();
          isIncomingScreenOpen = false;
        }

        if (incomingTrips.isNotEmpty && !isIncomingScreenOpen) {
          isIncomingScreenOpen = true;
          Get.to(
            () => IncomingBookingScreen(trips: incomingTrips),
          )?.then((_) {
            isIncomingScreenOpen = false;
            stopRingtone();
          });
        }

        update();
      }
    } catch (e) {
      debugPrint("Booking fetch error: $e");
    }
  }

  ////////acceptRideUrl

  void resetRideState() {
    _rideRingtoneHasPlayed = false;
    incomingTrips.clear();
    stopRingtone();
  }

  void stopListeningBookings() {
    _dummyTimer?.cancel();
    _dummyTimer = null;
  }

  Future<void> playRingtone() async {
    if (isRingtonePlaying) return;

    isRingtonePlaying = true;

    try {
      // Stop and release any existing player first
      try {
        await _player.stop();
        await _player.release();
      } catch (_) {}

      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(AssetSource('sound/ringtone.mp3'));
    } catch (e) {
      debugPrint('playRingtone error: $e');
      // Reset flag so next attempt can try again
      isRingtonePlaying = false;
      return;
    }

    // Auto-stop after 3 seconds
    _ringtoneTimer?.cancel();
    _ringtoneTimer = Timer(const Duration(seconds: 3), () {
      stopRingtone();
    });
  }

  void stopRingtone() async {
    _ringtoneTimer?.cancel();
    _ringtoneTimer = null;
    isRingtonePlaying = false;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('stopRingtone error: $e');
    }
  }

  void acceptTrip(NewBookingNearByModel trip) async {
    _rideRingtoneHasPlayed = false;
    stopRingtone();
    acceptedTrip.clear();
    acceptedTrip.add(trip);
    Get.offAndToNamed(
      RouteHelper.getgoingForPickupScreen(),
      arguments: {"trips": trip},
    );

    incomingTrips.clear();
    isIncomingScreenOpen = false;

    stopListeningBookings();


  }

  void rejectTrip(NewBookingNearByModel trip) {
    incomingTrips.remove(trip);

    if (incomingTrips.isEmpty) {
      _rideRingtoneHasPlayed = false;
      stopRingtone();
      isIncomingScreenOpen = false;

      if (Get.currentRoute != "/") {
        Get.back();
      }
    }

    update();
  }

  /////==================================== Driver Status Online  Offline  work Status ==============/////

  Future<Response> driverStatusOnlineOffline({
    required BuildContext context,
  }) async {
    //EasyLoading.show(status: "Please wait...");

    try {
      Response response = await homeRepo.driverStatusModeApi();

      //EasyLoading.dismiss();

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'] == '200') {
        var data = response.body['data'];

        print('sttaus::::::${data['work_status']}');

        return response;
      } else {
        // Get.snackbar('', response.body?['message'] ?? "Something went wrong");
        return response;
      }
    } catch (e) {
     // EasyLoading.dismiss();
      rethrow;
    }
  }

  Future<Response> driverUpdateLocation({
    required double lat,
    required double lng,
  }) async {
    update();
    try {
      Response response = await homeRepo
          .driverLocationUpdate(lat: lat, lng: lng)
          .timeout(Duration(seconds: 60));

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'] == '200') {
        print('update location driver ${response.body}');

        //driverlatitude driverlongitude
        update();
        return response;
      } else {
        print('not update location driver Something went wrong');

        return response;
      }
    } catch (e) {
      rethrow;
    }
  }



  /////// ========== Call New Booking Api ==========================
  Future<Response> nweBookingNearByMeApi({
    required BuildContext context,
  }) async {
   // EasyLoading.show(status: "Please wait...");
    isLoading = true;
    update();

    Response response = await homeRepo.newBookingNearByMe();

   // EasyLoading.dismiss();

    print("  Newbooking ${response.body}");

    if (response.statusCode == 200 && response.body['code'] == '200') {
      newBookingNearByModel = NewBookingNearByListModel.fromJson(response.body);
      newBookingNearByList = newBookingNearByModel!.data ?? [];

      isLoading = false;
      update();
    } else {
      // Get.snackbar(
      //   '',
      //   response.body['message'] ?? "Something went wrong",
      //   backgroundColor: ColorResources.textColorRed,
      //   colorText: Colors.white,
      //   snackPosition: SnackPosition.TOP,
      // );

      isLoading = false;
      update();
    }

    return response;
  }

  ///// ================== Call Accept Ride Api =========================
  ///

  Future<Response> acceptRidesTrip({
    required BuildContext context,
    required String bookingId,
    NewBookingNearByModel? trips,
  }) async {
    final prefs = await SharedPreferences.getInstance();

   // EasyLoading.show(status: "Please wait...");
    update();
    saveRideBookingStatus(bookingId);

    try {
      Response response = await homeRepo.acceptRide(bookingid: bookingId);
     // print('testing mode for accept ride ${response.body['code']}');
    //  EasyLoading.dismiss();
      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'] == '200') {
        //  tripdata = response.body['data'];
        stopRingtone();
        trackbookingRide(context: context, bookingId: bookingId);
        Get.offAndToNamed(
          RouteHelper.getgoingForPickupScreen(),
          arguments: {"trips": trips},
        );
        if (trips != null) {
          String tripJson = jsonEncode(trips.toJson());

          await prefs.setString("trip_data", tripJson);

          print("Trip Saved");
        }

        incomingTrips.clear();
        isIncomingScreenOpen = false;

        stopListeningBookings();


      //  Get.snackbar("Success", "Trip Accepted");
        prefs.setString(ApiConstants.acceptedtrip, jsonEncode(trips!.toJson()));
        await prefs.setString(ApiConstants.bookingid, bookingId);
        print("Booking ID: ${prefs.get(ApiConstants.bookingid)}");

        update();
        return response;
      } else if (response.body != null && response.body['code'] == '401') {
        hasActiveRide = true;
        AnimatedTopToast.show(
          context: context,
          message: 'You already have an active ride. Please complete it first.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );

        return response;
      } else {
        AnimatedTopToast.show(
          context: context,
          message: 'Could not accept this trip. Please try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );

        return response;
      }
    } catch (e) {
      EasyLoading.dismiss();
      rethrow;
    }
  }

  ////// ========================== Call Cancle Ride List Api ========================== ////////////////

  Future<Response> cancleRideReason() async {
    // isLoading = true;

    update();

    try {
      Response response = await homeRepo.cancleRide();

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'] == '200') {
        cancleReasonModel = CancleReasonModel.fromJson(response.body);
        cancleReasonModelList.clear();
        cancleReasonModelList.addAll(cancleReasonModel?.data ?? []);

        print('Cancel Ride Reason Data: ${cancleReasonModelList.length}');
        // isLoading = false;
        update();
        return response;
      } else {
        return response;
      }
    } catch (e) {
      //  / isLoading = false;
      update();

      rethrow;
    }
  }

  ///////// ==================== Call Cancle Ride by Driver ====================/////////////////

  Future<Response> cancleRideByDriver({
    required BuildContext context,
    required String bookingId,
    required String cancellationid,
    NewBookingNearByModel? trips,
  }) async {
    update();

    try {
      Response response = await homeRepo.cancleRidebyDriverSide(
        bookingid: bookingId,
        cancellationid: cancellationid,
      );

      debugPrint('Cancel ride response: ${response.body}');

      if (response.statusCode == 200 && response.body != null) {
        final code = response.body['code']?.toString() ??
            response.body['status']?.toString() ??
            '';

        if (code == '200') {
          // Clear all saved ride data
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(ApiConstants.bookingid);
          await prefs.remove(ApiConstants.acceptedtrip);
          await prefs.remove('booking_id');
          await prefs.remove('trip_data');
          await clearRideData();

          // Clear local model state
          savedTripData = null;
          savedAcceptData = null;
          trackRideModel = null;
          driverBookingActivesModel = null;
          hasActiveRide = false;
          isIncomingScreenOpen = false;
          computedDistance = '';
          computedDuration = '';
          estimatePrice = '';
          estimateDistance = '';
          estimateDuration = '';

          // Clear trip details in ProfileController
          try {
            Get.find<ProfileController>().tripDetailsModel = null;
          } catch (_) {}

          // Stop ringtone if playing
          stopRingtone();

          // Navigate to home screen first (clears all routes including bottom sheet)
          Get.offAllNamed(RouteHelper.getHomeScreen());

          // Restart listening for new bookings if driver is still online
          if (isOnline) {
            startListeningBookings();
          }

          update();
          return response;
        } else {
          // API returned a non-200 code
          Get.snackbar(
            'Cancel Failed',
            'Unable to cancel ride right now. Please try again.',
            backgroundColor: ColorResources.redbuttoncolor,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
          );
          return response;
        }
      } else {
        Get.snackbar(
          'Error',
          'Server error. Please try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        return response;
      }
    } catch (e) {
      debugPrint('cancleRideByDriver error: $e');
      Get.snackbar(
        'Error',
        'Something went wrong. Please try again.',
        backgroundColor: ColorResources.redbuttoncolor,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      rethrow;
    }
  }

  /////// ========================= Track Booking Ride ========================/////
  ////trackBookingRide

  Future<Response?> trackbookingRide({
    required BuildContext context,
    String? bookingId,
  }) async {
    // EasyLoading.show(status: "Please wait...");
    update();

    Response? response;

    try {
      response = await homeRepo.trackBookingRide(bookingid: bookingId);

      print('API RESPONSE ===> ${response.body}');

      if (response.statusCode == 200 && response.body != null) {
        trackRideModel = AcceptRideModel.fromJson(response.body);
        update();

        if (trackRideModel?.code == "200") {
          // Fetch accurate distance & duration from Google Directions API
          final rideData = trackRideModel?.data;
          final double? pickupLat = rideData?.lat;
          final double? pickupLng = rideData?.lng;
          double? dLat = rideData?.dropLat;
          double? dLng = rideData?.dropLng;

          // Fallback: try TripDetailsModel for drop coordinates
          if ((dLat == null || dLng == null) || (dLat == 0.0 && dLng == 0.0)) {
            try {
              final tripData = Get.find<ProfileController>().tripDetailsModel?.data;
              dLat = tripData?.dropLat;
              dLng = tripData?.dropLng;
            } catch (_) {}
          }

          if (pickupLat != null && pickupLng != null &&
              dLat != null && dLng != null &&
              !(pickupLat == 0.0 && pickupLng == 0.0) &&
              !(dLat == 0.0 && dLng == 0.0)) {
            fetchRouteDistanceDuration(
              pickupLat: pickupLat,
              pickupLng: pickupLng,
              dropLat: dLat,
              dropLng: dLng,
            );
          }
        } else {
          //  EasyLoading.dismiss();
          print(trackRideModel?.message ?? "Something went wrong");

          // Get.snackbar(
          //   '',
          //   trackRideModel?.message ?? "Something went wrong",
          //   backgroundColor: ColorResources.textColorRed,
          //   colorText: Colors.white,
          //   snackPosition: SnackPosition.TOP,
          // );
        }
      } else {
        //   EasyLoading.dismiss();
        print("ERROR ===> Invalid server response");
        // Get.snackbar(
        //   '',
        //   "Invalid server response",
        //   backgroundColor: ColorResources.textColorRed,
        //   colorText: Colors.white,
        // );
      }
    } catch (e) {
      ///EasyLoading.dismiss();
      print("ERROR ===> $e");

      // Get.snackbar(
      //   '',
      //   "Something went wrong",
      //   backgroundColor: ColorResources.textColorRed,
      //   colorText: Colors.white,
      // );
    }

    update();
    return response;
  }

  //////============= Driver active ride  =========================/////////////
  ///================ ACTIVE RIDE HANDLE + NAVIGATION =================///
  Future<void> driverBookingActives() async {
    isActiveLoading = true;
    update();

    try {
      Response response = await homeRepo.driverBookingActive();

      print("ACTIVE RESPONSE => ${response.body}");

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'].toString() == '200') {
        driverBookingActivesModel = DriverBookingActives.fromJson(
          response.body,
        );

        final data = driverBookingActivesModel?.data;

        final String status = data?.status?.toString() ?? "";
        final String bookingId = data?.bookingId?.toString() ?? "";

        print("ACTIVE STATUS => $status");
        print("BOOKING ID => $bookingId");

        ///=============== TRACK RIDE API CALL =================///
        if (bookingId.isNotEmpty) {
          await trackbookingRide(context: Get.context!, bookingId: bookingId);
        }

        ///=============== NAVIGATION HANDLE =================///
        switch (status) {
          /// DRIVER ACCEPTED RIDE
          case "accepted":
            print("NAVIGATE => GOING FOR PICKUP");

            Get.offNamed(
              RouteHelper.getgoingForPickupScreen(),
              arguments: {
                "trips": savedTripData,
                "acceptData": savedAcceptData,
              },
            );

            break;

          /// RIDE STARTED
          case "ongoing":
            print("NAVIGATE => START DRIVER RIDE");

            Get.offNamed(
              RouteHelper.getstartDriverRideScreen(),
              arguments: {
                "trips": savedTripData,
                "acceptData": savedAcceptData,
              },
            );

            break;

          /// RIDE COMPLETED
          case "completed":
            print("NAVIGATE => HOME");

            /// CLEAR LOCAL MODEL
            savedTripData = null;
            savedAcceptData = null;
            trackRideModel = null;
            hasActiveRide = false;

            // Clear trip details in ProfileController
            try {
              Get.find<ProfileController>().tripDetailsModel = null;
            } catch (_) {}

            // Clear prefs
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(ApiConstants.bookingid);
            await prefs.remove(ApiConstants.acceptedtrip);
            await prefs.remove('booking_id');
            await prefs.remove('trip_data');

            // Restart booking listener if online
            if (isOnline) {
              startListeningBookings();
            }

            update();

            Get.offAllNamed(RouteHelper.gethomescreen());

            break;

          default:
            print("NO ACTIVE RIDE FOUND");
        }
      }
    } catch (e) {
      print("ACTIVE RIDE ERROR => $e");
    } finally {
      isActiveLoading = false;
      update();
    }
  }


  /////////////////// ============================ driver Arrived  ========================/////////////

  Future<Response> driverArrived({
    required BuildContext context,
    required String bookingId,
  }) async {
   /// EasyLoading.show(status: "Please wait...");
    update();

    try {
      Response response = await homeRepo.driverArrivedApi(bookingid: bookingId);
      print('testing mode for driverArrived body=${response.body}');
     // EasyLoading.dismiss();
      if (response.statusCode == 200 &&
          response.body != null &&
          (response.body['code'] == '200' || response.body['code'] == 200)) {
       /// EasyLoading.dismiss();
        arrivedStatusCode = response.body['code'].toString();
        print('status code arrived ||||  ${response.body['code']}');
        print('status code arrived ||||  ${arrivedStatusCode}');
        // Get.snackbar(
        //   '',
        //   response.body['message'],
        //   backgroundColor: ColorResources.appColor,
        //   colorText: Colors.white,
        //   snackPosition: SnackPosition.TOP,
        // );


        update();
        return response;
      } else if (response.body != null && response.body['code'] == '401') {
        hasActiveRide = true;

        AnimatedTopToast.show(
          context: context,
          message: 'You already have an active ride. Please complete it first.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );

        return response;
      } else {
        return response;
      }
    } catch (e) {
    ////  EasyLoading.dismiss();
      rethrow;
    }
  }

  Future<Response> rideCompletedMarked({
    required BuildContext context,
    required String bookingId,
    String source = 'offline',
  }) async {
    update();

    try {
      Response response = await homeRepo.completeRide(bookingid: bookingId, source: source);
      print('testing mode for completeRide ${response.body['code']}');

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code']?.toString() == '200') {



        // Clear saved ride data from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(ApiConstants.bookingid);
        await prefs.remove(ApiConstants.acceptedtrip);
        await prefs.remove('booking_id');
        await prefs.remove('trip_data');
        await clearRideData();

        // Clear local model state
        savedTripData = null;
        savedAcceptData = null;
        trackRideModel = null;
        driverBookingActivesModel = null;
        hasActiveRide = false;
        isIncomingScreenOpen = false;
        computedDistance = '';
        computedDuration = '';
        estimatePrice = '';
        estimateDistance = '';
        estimateDuration = '';

        // Clear trip details in ProfileController
        try {
          Get.find<ProfileController>().tripDetailsModel = null;
        } catch (_) {}

        // Stop ringtone if playing
        stopRingtone();

        // Navigate to home screen directly — no bottom sheet
        Get.offAllNamed(RouteHelper.getHomeScreen());

        // Restart listening for new bookings if driver is still online
        if (isOnline) {
          startListeningBookings();
        }

        update();
        return response;
      } else if (response.body != null && response.body['code'] == '401') {
        hasActiveRide = true;

        AnimatedTopToast.show(
          context: context,
          message: 'You already have an active ride. Please complete it first.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );

        return response;
      } else {
        AnimatedTopToast.show(
          context: context,
          message: 'Unable to complete the ride. Please try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );

        return response;
      }
    } catch (e) {
      rethrow;
    }
  }

  // ======= Online Payment — Generate QR & Verify =======

  Future<QrPaymentData?> generateOnlineQr({
    required BuildContext context,
    required String bookingId,
  }) async {
    try {
      final response = await homeRepo.generateQrCode(bookingId: bookingId);
      final body = response.body;
      final isSuccess = response.statusCode == 200 &&
          body != null &&
          (body['code']?.toString() == '200' ||
              body['status'] == true ||
              body['status']?.toString() == 'true');
      if (isSuccess) {
        final model = QrPaymentModel.fromJson(response.body);
        return model.data;
      } else {
        AnimatedTopToast.show(
          context: context,
          message: response.body?['message'] ?? 'Failed to generate QR code.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
        return null;
      }
    } catch (e) {
      debugPrint('generateOnlineQr error: $e');
      return null;
    }
  }

  Future<bool> verifyOnlinePayment({
    required String bookingId,
    required String qrId,
  }) async {
    try {
      final response = await homeRepo.verifyQrPayment(
        bookingId: bookingId,
        qrId: qrId,
      );
      debugPrint('verify-qr-payment response: ${response.body}');
      if (response.body == null) return false;
      final data = response.body['data'];
      final isPaid = data?['is_paid']?.toString() ?? response.body['is_paid']?.toString();
      return isPaid == '1';
    } catch (e) {
      debugPrint('verifyOnlinePayment error: $e');
      return false;
    }
  }

  Future<bool> checkPaymentStatusById({required String bookingId}) async {
    try {
      final response = await homeRepo.checkPaymentStatus(bookingId: bookingId);
      debugPrint('payment-status response: ${response.body}');
      if (response.body == null) return false;
      final data = response.body['data'];
      if (data == null) return false;
      final isPaid = data['is_paid'];
      return isPaid == true || isPaid == 1 || isPaid?.toString() == '1';
    } catch (e) {
      debugPrint('checkPaymentStatusById error: $e');
      return false;
    }
  }

  Future<Response> verifyPickUpOtps({
    required BuildContext context,
    required String bookingId,
    required String otpNumber,
    TripDetailsModel? trips,
    AcceptRideModel? acceptData,
  }) async {
   /// EasyLoading.show(status: "Please wait...");
    update();

    try {
      Response response = await homeRepo.verifyPickupOtp(
        bookingid: bookingId,
        otpnum: otpNumber,
      );
      print('testing mode for verifyPickupOtp ${response}');
     /// EasyLoading.dismiss();
      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code']?.toString() == '200') {
        verifyPickupOtpStatusCode = response.body['code'].toString();

      // EasyLoading.dismiss();
        AnimatedTopToast.show(
          context: context,
          message: 'OTP verified! Ride has started.',
          backgroundColor: ColorResources.appColor,
          icon: Icons.check_circle_rounded,
        );

        debugPrint('testing data for Accept Data  $trips $acceptData');
        // Navigation is now handled by the pickup screen itself (shows End Ride button)

        update();
        return response;
      } else if (response.body != null && response.body['code'] == '401') {
        hasActiveRide = true;

        AnimatedTopToast.show(
          context: context,
          message: 'This ride is no longer available.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );

        return response;
      } else {
        return response;
      }
    } catch (e) {
     /// EasyLoading.dismiss();
      rethrow;
    }
  }

  static Future<void> clearRideData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(ApiConstants.tripKey);
    await prefs.remove(ApiConstants.acceptRideKey);

    print("Ride data cleared");
  }

  ////// addBankDetails

  ////////// ================ map   =============================////////////
  Future<void> loadCustomMarker() async {
    carIcon = await resizeMarker('assets/images/ridecar.png', 45);
  }

  Future<BitmapDescriptor> resizeMarker(String path, int width) async {
    final ByteData data = await rootBundle.load(path);
    final codec = await instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final frame = await codec.getNextFrame();

    final bytes = await frame.image.toByteData(format: ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> loadUserMarker() async {
    userIcon = await resizeMarker('assets/images/locationpickup.png', 100);
  }

  Future<void> getRouteCoordinates({
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    GoogleMapController? mapController,
  }) async {
    if (startLat == null ||
        startLng == null ||
        endLat == null ||
        endLng == null)
      return;

    print("Start:::::: ($startLat, $startLng) → End: ($endLat, $endLng)");

    String url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=$startLat,$startLng&destination=$endLat,$endLng&key=${ApiConstants.apiKey}";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var data = json.decode(response.body);

      if (data['routes'] == null || data['routes'].isEmpty) return;

      // Extract distance and duration from the route
      try {
        final leg = data['routes'][0]['legs'][0];
        final int distanceMeters = leg['distance']['value'] ?? 0;
        final double distanceKm = distanceMeters / 1000.0;
        final int durationSeconds = leg['duration']['value'] ?? 0;
        final int durationMin = (durationSeconds / 60).round();

        computedDistance = distanceKm.toStringAsFixed(1);
        computedDuration = durationMin.toString();
        totaldestance = computedDistance;
        totaltime = computedDuration;

        debugPrint('Route: Distance=$computedDistance km, Duration=$computedDuration min');
      } catch (e) {
        debugPrint('Error extracting route data: $e');
      }

      String encodedPolyline = data['routes'][0]['overview_polyline']['points'];

      List<LatLng> routePoints = decodePolyline(encodedPolyline);

      polylines.clear();

      polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          points: routePoints,
          width: 6,
          color: ColorResources.appColor,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );

      /// ✅ MARKERS FIX
      markers.removeWhere(
        (m) => m.markerId.value == "pickup" || m.markerId.value == "driver",
      );

      markers.add(
        Marker(
          markerId: const MarkerId("pickup"),
          position: LatLng(endLat, endLng),
          icon: userIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(title: "Pickup"),
        ),
      );

      markers.add(
        Marker(
          markerId: const MarkerId("driver"),
          position: LatLng(startLat, startLng),
          icon: carIcon ?? BitmapDescriptor.defaultMarker,
          rotation: 0,
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: "Driver"),
        ),
      );

      if (mapController != null) {
        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(min(startLat, endLat), min(startLng, endLng)),
          northeast: LatLng(max(startLat, endLat), max(startLng, endLng)),
        );

        mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      }

      update();
    } else {
      throw Exception("Failed to load route");
    }
  }

  void startLiveTracking(double endLat, double endLng) {
    positionStream?.cancel();

    positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          double lat = position.latitude;
          double lng = position.longitude;

          /// ONLY marker update
          _updateDriverMarker(lat, lng);
        });
  }

  void _updateDriverMarker(double lat, double lng) {
    const markerId = MarkerId("driver");

    final updatedMarker = Marker(
      markerId: markerId,
      position: LatLng(lat, lng),
      icon: carIcon ?? BitmapDescriptor.defaultMarker,
      anchor: const Offset(0.5, 0.5),
      infoWindow: const InfoWindow(title: "Driver"),
    );

    markers = markers.map((marker) {
      if (marker.markerId == markerId) {
        return updatedMarker;
      }
      return marker;
    }).toSet();

    /// agar pehli baar hai
    if (!markers.any((m) => m.markerId == markerId)) {
      markers.add(updatedMarker);
    }

    /// smooth camera follow (optional)
    mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));

    update();
  }

  // Future<void> getRouteCoordinatespickup({
  //   double? startLat,
  //   double? startLng,
  //   double? endLat,
  //   double? endLng,
  // }) async {
  //   String url =
  //       "https://maps.googleapis.com/maps/api/directions/json?"
  //       "origin=$startLat,$startLng&destination=$endLat,$endLng&key=${ApiConstants.apiKey}";

  //   final response = await http.get(Uri.parse(url));

  //   if (response.statusCode == 200) {
  //     var data = json.decode(response.body);

  //     if (data['routes'].isEmpty) return;

  //     String encodedPolyline = data['routes'][0]['overview_polyline']['points'];

  //     List<LatLng> routePoints = decodePolyline(encodedPolyline);

  //    polylines.clear();

  //     polylines.add(
  //       Polyline(
  //         polylineId: const PolylineId("route"),
  //         points: routePoints,
  //         width: 5,
  //         color: ColorResources.appColor,
  //       ),
  //     );

  //     /// DROP MARKER (only once)
  //     markers.add(
  //       Marker(
  //         markerId: const MarkerId("drop"),
  //         position: LatLng(endLat!, endLng!),
  //         icon: userIcon ?? BitmapDescriptor.defaultMarker,
  //         infoWindow: const InfoWindow(title: "Drop Location"),
  //       ),
  //     );

  //     update();
  //   }
  // }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polyline;
  }

  void updateDriverLocation(double lat, double lng) {
    latitude = lat;
    longitude = lng;

    print("📍 LOCATION UPDATED: $lat , $lng");

    if (pickupLat != null && pickupLng != null) {
      calculateETA(
        driverLat: latitude,
        driverLng: longitude,
        userLat: pickupLat,
        userLng: pickupLng,
      );
    }

    update();
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;
    if (value is int) return value.toDouble();

    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }

    return 0.0;
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth radius in KM

    double dLat = _toRad(lat2 - lat1);
    double dLon = _toRad(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  double _toRad(double degree) {
    return degree * pi / 180;
  }

  //calculate time and distance using Google Directions API

  String? totaldestance = '';
  String totaltime = '';

  /// Computed values from Google Directions API (accurate route-based)
  String computedDistance = '';
  String computedDuration = '';

  /// Estimate ride data from /api/estimate-ride-list
  String estimatePrice = '';
  String estimateDistance = '';
  String estimateDuration = '';

  /// Fetch ride estimate (price, distance, time) from backend
  Future<void> fetchEstimateRideData({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
  }) async {
    try {
      final response = await homeRepo.estimateRideList(
        pickupLat: pickupLat.toString(),
        pickupLng: pickupLng.toString(),
        dropLat: dropLat.toString(),
        dropLng: dropLng.toString(),
      );

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code']?.toString() == '200') {
        final dataList = response.body['data'] as List?;
        if (dataList != null && dataList.isNotEmpty) {
          final first = dataList[0];
          estimatePrice = first['price']?.toString() ?? '';
          estimateDistance = first['distance_km']?.toString() ?? '';
          estimateDuration = first['estimated_time']?.toString() ?? '';
          debugPrint('Estimate: price=$estimatePrice, dist=$estimateDistance, time=$estimateDuration');
          update();
        }
      }
    } catch (e) {
      debugPrint('fetchEstimateRideData error: $e');
    }
  }

  /// Fetch accurate distance and duration using Google Directions API
  Future<void> fetchRouteDistanceDuration({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
  }) async {
    try {
      String url =
          "https://maps.googleapis.com/maps/api/directions/json?"
          "origin=$pickupLat,$pickupLng&destination=$dropLat,$dropLng&key=${ApiConstants.apiKey}";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final leg = data['routes'][0]['legs'][0];

          // Distance in meters → convert to km
          final int distanceMeters = leg['distance']['value'] ?? 0;
          final double distanceKm = distanceMeters / 1000.0;
          computedDistance = distanceKm.toStringAsFixed(1);

          // Duration in seconds → convert to minutes
          final int durationSeconds = leg['duration']['value'] ?? 0;
          final int durationMin = (durationSeconds / 60).round();
          computedDuration = durationMin.toString();

          // Also update the old fields for backward compatibility
          totaldestance = computedDistance;
          totaltime = computedDuration;

          debugPrint('Google Directions: Distance=$computedDistance km, Duration=$computedDuration min');

          WidgetsBinding.instance.addPostFrameCallback((_) => update());
        }
      }
    } catch (e) {
      debugPrint('fetchRouteDistanceDuration error: $e');
      // Fallback: use Haversine calculation
      _calculateETAFallback(
        driverLat: pickupLat,
        driverLng: pickupLng,
        userLat: dropLat,
        userLng: dropLng,
      );
    }
  }

  /// Fallback calculation using Haversine formula (when Google API fails)
  void _calculateETAFallback({
    dynamic driverLat,
    dynamic driverLng,
    dynamic userLat,
    dynamic userLng,
  }) {
    double dLat = _safeToDouble(driverLat);
    double dLng = _safeToDouble(driverLng);
    double uLat = _safeToDouble(userLat);
    double uLng = _safeToDouble(userLng);

    if ((dLat == 0.0 && dLng == 0.0) || (uLat == 0.0 && uLng == 0.0)) {
      return;
    }

    double distance = calculateDistance(dLat, dLng, uLat, uLng);
    if (distance.isNaN || distance.isInfinite) distance = 0.0;

    double speed = 30.0;
    double timeHours = distance / speed;
    if (timeHours.isNaN || timeHours.isInfinite) timeHours = 0.0;

    double timeMinutes = timeHours * 60;

    totaldestance = distance.toStringAsFixed(1);
    totaltime = timeMinutes.round().toString();
    computedDistance = totaldestance!;
    computedDuration = totaltime;
    WidgetsBinding.instance.addPostFrameCallback((_) => update());
  }

  void calculateETA({
    dynamic driverLat,
    dynamic driverLng,
    dynamic userLat,
    dynamic userLng,
  }) {
    _calculateETAFallback(
      driverLat: driverLat,
      driverLng: driverLng,
      userLat: userLat,
      userLng: userLng,
    );
  }

  Future<void> callNumber({String? phoneNumber}) async {
    final Uri url = Uri.parse("tel:$phoneNumber");

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }



  void showRatingSheet() {
    showModalBottomSheet(
      context: Get.context!,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final DriveController driveController = Get.find();

        List<String> tags = [
          "Respectful",
          "Clean and tidy",
          "Easy pickup",
          "Easy Payment",
          "Communication",
          "Quick response",
        ];

        return Container(
          padding: EdgeInsets.fromLTRB(
            Dimensions.smallSpace,
            Dimensions.smallSpace,
            Dimensions.smallSpace,
            Dimensions.smallSpace + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: ColorResources.whiteColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Dimensions.spacingSize20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Drag Handle
              Container(
                height: 5,
                width: 50,
                margin: EdgeInsets.only(bottom: Dimensions.hight13),
                decoration: BoxDecoration(
                  color: ColorResources.TextColorForGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      driveController.skipRating();
                      Get.back();
                    },
                    child: Text(
                      "Skip",
                      style: PoppinsBold.copyWith(
                        color: ColorResources.blackcolor,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                "How was your Passenger?",
                style: PoppinsReguler.copyWith(
                  color: ColorResources.blackcolor,
                ),
              ),

              SizedBox(height: 5),

              Text(
                trackRideModel?.data?.customerInfo?.name ?? "Passenger",
                style: PoppinsBold.copyWith(color: ColorResources.blackcolor),
              ),

              const SizedBox(height: 5),

              /// ⭐ Stars
              Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () {
                        driveController.updateRating(index + 1);
                      },
                      icon: Icon(
                        Icons.star_rounded,
                        size: 38,
                        color: driveController.rating.value > index
                            ? Colors.amber
                            : Colors.grey.shade300,
                      ),
                    );
                  }),
                ),
              ),

              SizedBox(height: Dimensions.smallSize),

              Text(
                "Anything to praise?",
                style: PoppinsReguler.copyWith(
                  color: ColorResources.blackcolor,
                ),

                //  style: TextStyle(fontSize: 15)
              ),

              SizedBox(height: Dimensions.smallSize),

              /// Praise Chips
              Obx(
                () => Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: tags.map((tag) {
                    bool isSelected = driveController.selectedTags.contains(
                      tag,
                    );

                    return GestureDetector(
                      onTap: () {
                        driveController.toggleTag(tag);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ColorResources.appColor
                              : ColorResources.backgroundColor,
                          borderRadius: BorderRadius.circular(
                            Dimensions.spacingSize16,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: PoppinsReguler.copyWith(
                            color: isSelected
                                ? ColorResources.whiteColor
                                : ColorResources.blackcolor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              SizedBox(height: Dimensions.spacingSize12),

              /// Rate Passenger Button
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CustomPrimaryButton(
                  text: "Rate Passenger",
                  onTap: () {
                    driveController.submitRating();
                  },
                ),
              ),

              SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}
