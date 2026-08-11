import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import 'package:myridedriverapp/controllers/auth_controller.dart';
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
import 'package:myridedriverapp/services/geo_utils.dart';
import 'package:myridedriverapp/services/location_health_tracker.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_popup.dart';
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

  // IDs of nearby trips that have already triggered the ringtone this
  // online session. A single "has it rung yet" boolean (the old approach)
  // only fires on the empty→non-empty transition — a second rider's
  // request arriving while the first is still sitting on screen silently
  // joins the list with no alert at all. Tracking per-id means a genuinely
  // new request always rings, even while others are already pending.
  final Set<int> _ringedTripIds = {};

  // IDs the driver has explicitly declined via rejectTrip(). There is no
  // backend "decline this booking" endpoint — rejection is purely local —
  // and the nearby-booking poll below re-fetches the full "still
  // unassigned" list from the backend every ~3s. Without this filter, a
  // rejected request reappears on the very next poll looking exactly like
  // a brand new one (fresh ringtone, screen pops back open), making the
  // reject button effectively a ~3-second snooze instead of a decline.
  final Set<int> _rejectedTripIds = {};

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

  // ==================== Location pipeline health ====================
  //
  // Tracks whether the location updates we're SENDING are actually landing
  // on the backend — GPS can look perfectly fine locally while every
  // transmission attempt silently fails (dead token, dropped connection,
  // OS suspending the app in the background). Without this, a driver can
  // sit "online" indefinitely while invisible to every rider, with no
  // indication anything is wrong.
  final LocationHealthTracker locationHealth = LocationHealthTracker();
  Timer? _stalenessWatchdog;
  bool _autoOfflineTriggered = false;

  // How long the backend's copy of our location can go without a confirmed
  // refresh before we stop trusting ourselves to be "visible" and take
  // action. The heartbeat fires every ~5s, so this tolerates a handful of
  // missed beats (e.g. a brief network blip) before reacting.
  static const Duration staleLocationThreshold = Duration(seconds: 40);

  // A "nearby" result whose pickup is farther than this from our current
  // position is almost certainly a backend bug (wrong coordinate order,
  // degrees/radians mix-up, wrong table) rather than a legitimately large
  // search radius — logged as a loud warning so it's debuggable without
  // guesswork instead of just quietly rendering a marker in the wrong spot.
  static const double suspiciousMatchDistanceKm = 100;

  bool _isInitialized = false;

  @override
  void onInit() {
    super.onInit();
    if (_isInitialized) return;
    _isInitialized = true;

    startLocationUpdates();
    startAutoUpdate();
    _startStalenessWatchdog();
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
    _locationRetryTimer?.cancel();
    _stalenessWatchdog?.cancel();
    _dummyTimer?.cancel();
    _ringtoneTimer?.cancel();
    positionStreams?.cancel();
    isRingtonePlaying = false;
    try {
      _player.dispose();
    } catch (_) {}
    super.onClose();
  }

  /// Runs independently of the heartbeat itself, checking whether the
  /// backend's copy of our location has gone stale — e.g. because
  /// [driverUpdateLocation] has been failing silently, or the OS suspended
  /// the app in the background and the heartbeat timer simply stopped
  /// firing. If we're still marked "online" when that happens, the driver
  /// is invisible to riders without knowing it — so we take ourselves
  /// offline and say why, instead of leaving that state undetected.
  void _startStalenessWatchdog() {
    _stalenessWatchdog?.cancel();
    _stalenessWatchdog = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!isOnline) return;

      if (locationHealth.isStale(threshold: staleLocationThreshold)) {
        _handleLocationStale();
      }
    });
  }

  /// Takes the driver offline (locally immediately, and best-effort on the
  /// backend) when their location hasn't been confirmed-stored recently
  /// enough to trust that riders can actually find them. Only fires once
  /// per stale episode — [toggleOnline] resets the flag the next time the
  /// driver deliberately goes online again.
  Future<void> _handleLocationStale() async {
    if (_autoOfflineTriggered) return;
    _autoOfflineTriggered = true;

    final staleFor = locationHealth.timeSinceLastSuccess();
    debugPrint(
      '[LocationPipeline] STALE — no confirmed location update in '
      '${staleFor?.inSeconds ?? "∞"}s while online. Taking driver offline '
      'so stale-location matching can\'t happen silently.',
    );

    // Reflect reality in this app immediately — don't wait on the network
    // call below, since the driver's own UI showing "online" while we
    // already know the backend copy is stale would itself be misleading.
    isOnline = false;
    stopListeningBookings();
    _ringedTripIds.clear();
    _rejectedTripIds.clear();
    await saveOnlineStatus(false);
    update();

    if (Get.context != null) {
      AnimatedTopToast.show(
        context: Get.context!,
        message:
            "You've been set offline — your location hasn't reached us "
            "recently, so nearby riders couldn't find you. Check your "
            "connection/GPS and go online again when ready.",
        backgroundColor: Colors.orange,
        icon: Icons.location_off_rounded,
      );
    }

    // Best-effort: also tell the backend, so its own record reflects
    // offline rather than relying solely on it independently detecting
    // staleness (which we can't verify from the client).
    try {
      final response = await homeRepo.driverStatusModeApi();
      debugPrint(
        '[LocationPipeline] auto-offline server sync: '
        '${response.statusCode} ${response.body}',
      );
    } catch (e) {
      debugPrint('[LocationPipeline] auto-offline server sync failed: $e');
    }
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
    _autoUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (latitude == null || longitude == null) return;

      // Previously fire-and-forget: driverUpdateLocation() was called
      // without awaiting or catching, so persistent failures (expired
      // token, timeout, etc.) became unhandled Future errors — logged by
      // the zone handler at best, otherwise invisible — with no retry
      // strategy beyond "hope the next blind tick works." Awaiting +
      // catching here means every attempt's outcome is now observed and
      // recorded via driverUpdateLocation() itself.
      try {
        await driverUpdateLocation(lat: latitude!, lng: longitude!);
      } catch (e) {
        debugPrint('[LocationPipeline] heartbeat update failed: $e');
      }
    });
  }

  bool isOnline = false;
  bool isLoading = false;

  // Dedicated to the online/offline toggle specifically — NOT the same as
  // `isLoading` above, which is a general-purpose flag shared by several
  // unrelated calls elsewhere in this controller (e.g. nweBookingNearByMeApi).
  // Sharing one flag meant those other calls could reset it out from under
  // an in-flight toggle request (or vice versa), un-disabling the toggle
  // button — and re-opening the tap guard — before the toggle's own
  // request had actually finished. That's what caused the toggle to look
  // idle/tappable again mid-request and let a second real tap slip through,
  // producing a toast/button state that looked one step out of sync.
  bool isTogglingOnline = false;
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
    if (isTogglingOnline) return;

    // Locked in synchronously, before any `await` below, so a second tap
    // that lands while the document-approval check (or the status API
    // call) is still in flight can't slip past the guard above and fire an
    // overlapping toggle request — that race was why the toggle used to
    // need several taps to reliably register. Uses its own dedicated flag
    // rather than the general-purpose `isLoading` (which other, unrelated
    // calls elsewhere in this controller also set/clear) — sharing one
    // flag meant those other calls could reset it mid-toggle-request,
    // un-disabling the button and re-opening this guard before the
    // toggle's own request had actually finished.
    isTogglingOnline = true;
    update();

    try {
      // Going offline is always allowed. Going online is strictly gated on
      // document approval — a driver whose documents aren't approved must
      // never be able to take a ride.
      if (!isOnline) {
        final authController = Get.find<AuthController>();
        // navigateOnApproved: false — we're already on the Home screen
        // (that's where the toggle lives). The default `true` fires
        // Get.offAllNamed(home) as a side effect of a plain approval
        // check, which tears down and remounts this very screen (and,
        // being fenix-managed, the HomeController itself) mid-tap. The
        // rest of this function then keeps running against the disposed
        // controller instance — its update()s land on nobody, so the
        // toggle stops visually reflecting isOnline, while the toast
        // (an Overlay call, independent of GetBuilder) still fires and
        // reports whatever that orphaned instance computed. That's what
        // made the toggle and toast look one tap out of sync.
        final bool isApproved = await authController.fetchDocumentStatus(
          navigateOnApproved: false,
        );
        if (!isApproved) {
          final status =
              (authController.isAnyDriverRejected ||
                  authController.isAnyVehicleRejected)
              ? "rejected"
              : "pending";

          Get.dialog(
            CustomPopup(
              status: status,
              buttonLabel: "Edit Documents",
              showCloseButton: true,
            ),
            barrierDismissible: true,
          );
          return;
        }
      }

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

        // Push this out immediately, as its own explicit rebuild request,
        // rather than leaving the toggle button to pick it up whenever the
        // isLoading-driven update() at the bottom of this function happens
        // to land.
        update();

        // update() only *schedules* GetBuilder's rebuild for the next
        // frame — it doesn't force one to happen synchronously. The toast
        // below shows via Overlay.insert(), which the compositor can paint
        // almost immediately, so without waiting here the toast could
        // render a full frame (or more) before the toggle button's own
        // scheduled rebuild has actually been painted — making the toast
        // and the button look out of sync for a moment right on the very
        // first tap of a session. Waiting for the next actual frame here
        // guarantees the button has repainted before the toast appears.
        await SchedulerBinding.instance.endOfFrame;

        await saveOnlineStatus(isOnline);

        // Fresh online session: don't let a staleness reading (or trigger)
        // from a previous session immediately fire again before the new
        // session's first heartbeat has even had a chance to land.
        locationHealth.reset();
        _autoOfflineTriggered = false;

        // Use Get.context (GetX's always-current root context) rather than
        // the context passed into this function — this call spans several
        // `await`s and `update()`s (from location updates/booking polls
        // firing concurrently), so by the time execution gets here the
        // originally-captured context can already be deactivated, which
        // throws "Looking up a deactivated widget's ancestor is unsafe" and
        // gets caught below as a spurious "Failed to change availability"
        // even though the toggle itself already succeeded.
        if (isOnline) {
          startListeningBookings();
          if (Get.context != null) {
            AnimatedTopToast.show(
              context: Get.context!,
              message: "You're Online — sharing your location with nearby riders.",
              backgroundColor: Colors.green,
              icon: Icons.wifi_tethering_rounded,
            );
          }
        } else {
          stopListeningBookings();
          // A new shift (next time they go online) should start with a
          // clean slate rather than carrying forward ids rung/declined
          // during this now-ended one.
          _ringedTripIds.clear();
          _rejectedTripIds.clear();
          if (Get.context != null) {
            AnimatedTopToast.show(
              context: Get.context!,
              message: "You're Offline — location sharing stopped.",
              backgroundColor: Colors.grey.shade700,
              icon: Icons.location_off_rounded,
            );
          }
        }
      } else {
        Get.snackbar("Error", "Could not update availability status. Please try again.");
      }
    } catch (e, st) {
      debugPrint('[ToggleOnline] ERROR: $e\n$st');
      Get.snackbar("Error", "Failed to change availability. Please check your connection.");
    } finally {
      isTogglingOnline = false;
      update();
    }
  }

  Timer? _locationRetryTimer;

  void startLocationUpdates() async {
    positionStream?.cancel();
    _locationRetryTimer?.cancel();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are OFF — retrying shortly');
        _scheduleLocationRetry();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission not granted — retrying shortly');
        _scheduleLocationRetry();
        return;
      }

      final LocationSettings locationSettings = _buildLocationSettings();

      // Get an immediate fix so the first update isn't stuck waiting on the
      // device to physically move by distanceFilter meters.
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
        );
        latitude = position.latitude;
        longitude = position.longitude;
        driverLatitude = position.latitude;
        driverLongitude = position.longitude;
        debugPrint(
          '[LocationPipeline] location received (initial fix) '
          'lat=$latitude lng=$longitude',
        );
        update();
      } catch (e) {
        debugPrint('❌ Could not get initial position: $e');
      }

      positionStream =
          Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) {
              latitude = position.latitude;
              longitude = position.longitude;
              driverLatitude = position.latitude;
              driverLongitude = position.longitude;

              debugPrint(
                '[LocationPipeline] location received lat=$latitude '
                'lng=$longitude accuracy=${position.accuracy}m',
              );

              update();
            },
            onError: (e) {
              debugPrint('❌ Location stream error: $e — retrying shortly');
              _scheduleLocationRetry();
            },
          );
    } catch (e) {
      debugPrint('❌ startLocationUpdates error: $e — retrying shortly');
      _scheduleLocationRetry();
    }
  }

  /// On Android, runs location updates as a foreground service (persistent
  /// notification) so the OS treats the app as actively in use and is far
  /// less likely to suspend it when the driver briefly switches to another
  /// app (e.g. external navigation) — the single biggest cause of drivers
  /// silently going invisible mid-shift.
  ///
  /// This is a real improvement but not a guarantee: per geolocator's own
  /// docs, a foreground notification raises priority, it does not prevent
  /// the OS from killing the process outright (screen off for a long
  /// period, aggressive OEM battery management, app swiped away, etc.).
  /// Surviving *that* would need a separate always-on background-service
  /// architecture (a new Dart isolate/plugin, its own permissions and
  /// Play Store review) — a bigger call intentionally left for a follow-up
  /// rather than bundled in here. [_startStalenessWatchdog] is the safety
  /// net for whenever this still isn't enough: it detects the resulting
  /// staleness and takes the driver visibly offline instead of leaving
  /// them silently unreachable.
  LocationSettings _buildLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Nride driver — Online',
          notificationText: 'Sharing your location so nearby riders can find you',
          notificationChannelName: 'Driver location sharing',
          setOngoing: true,
        ),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  /// Retries silently (no user-facing error) so location uploads — and
  /// therefore ride matching — resume automatically the moment GPS/
  /// permission becomes available, without requiring an app restart.
  void _scheduleLocationRetry() {
    _locationRetryTimer?.cancel();
    _locationRetryTimer = Timer(const Duration(seconds: 15), startLocationUpdates);
  }

  void startListeningBookings() {
    stopListeningBookings();
    // Fire immediately so the driver sees nearby rides the moment they go online
    _pollNearbyBookings();
    _dummyTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollNearbyBookings());
  }

  // A poll cycle occasionally takes longer than the 3s timer interval (slow
  // network on the profile/nearby-list calls). Timer.periodic doesn't wait
  // for the previous tick to finish, so without this guard a slow cycle
  // and the next scheduled one can run concurrently — both independently
  // reading isIncomingScreenOpen as false at the same instant and each
  // calling Get.to(), pushing the incoming-booking screen twice. That's
  // exactly the kind of overlap a genuine multiple-simultaneous-riders
  // moment is most likely to expose, since a bigger response and a
  // screen that's mid-render are what make a cycle run long in the first
  // place.
  bool _isPollingNearbyBookings = false;

  Future<void> _pollNearbyBookings() async {
    if (!isOnline) return;
    if (_isPollingNearbyBookings) return;
    _isPollingNearbyBookings = true;

    try {
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
        debugPrint(
          '[LocationPipeline] match query run (new-booking-list) '
          'driverLat=$latitude driverLng=$longitude',
        );
        Response response = await homeRepo.newBookingNearByMe();

        if (response.statusCode == 200 && response.body['code'] == "200") {
          List data = response.body['data'] ?? [];

          List<NewBookingNearByModel> apiTrips = data
              .map((trip) => NewBookingNearByModel.fromJson(trip))
              // Drop anything this driver already declined this session —
              // the backend has no decline endpoint to exclude it for us,
              // so without this it would resurface on the very next poll.
              .where((trip) => trip.id == null || !_rejectedTripIds.contains(trip.id))
              .toList();

          debugPrint(
            '[LocationPipeline] match query returned ${apiTrips.length} '
            'nearby trip(s)',
          );
          _logSuspiciouslyDistantMatches(apiTrips);

          incomingTrips.clear();
          incomingTrips.addAll(apiTrips);

          if (incomingTrips.isNotEmpty) {
            // Ring again whenever a request with an id we haven't already
            // rung for shows up — covers a second/third rider's request
            // landing while an earlier one is still pending on screen, not
            // just the first-ever arrival.
            final newTripIds = incomingTrips
                .map((t) => t.id)
                .whereType<int>()
                .where((id) => !_ringedTripIds.contains(id))
                .toSet();
            if (newTripIds.isNotEmpty) {
              _ringedTripIds.addAll(newTripIds);
              playRingtone();
            }
          } else {
            _ringedTripIds.clear();
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
    } finally {
      _isPollingNearbyBookings = false;
    }
  }

  /// Client-side sanity check on what the backend calls "nearby" — this
  /// repo has no visibility into the actual matching query (radius,
  /// coordinate order, units), so a wrong-but-200-OK response would
  /// otherwise be indistinguishable from a correct one. A "nearby" pickup
  /// that's absurdly far from the driver's own current position is a
  /// strong signal of a server-side bug (lat/lng swapped, degrees/radians
  /// mixed up, wrong table queried) — logged loudly so it's debuggable
  /// without guesswork instead of just quietly misplacing a marker.
  void _logSuspiciouslyDistantMatches(List<NewBookingNearByModel> trips) {
    if (latitude == null || longitude == null) return;

    for (final trip in trips) {
      if (trip.pickupLat == null || trip.pickupLng == null) continue;

      final distanceKm = haversineDistanceKm(
        latitude!,
        longitude!,
        trip.pickupLat!,
        trip.pickupLng!,
      );

      if (distanceKm > suspiciousMatchDistanceKm) {
        debugPrint(
          '[LocationPipeline] ⚠️ SUSPICIOUS MATCH: trip ${trip.id} pickup '
          'is ${distanceKm.toStringAsFixed(1)}km from driver '
          '(driver=$latitude,$longitude pickup=${trip.pickupLat},'
          '${trip.pickupLng}) — check backend coordinate order/units/radius',
        );
      }
    }
  }

  ////////acceptRideUrl

  void resetRideState() {
    _ringedTripIds.clear();
    _rejectedTripIds.clear();
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
    _ringedTripIds.clear();
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
    if (trip.id != null) _rejectedTripIds.add(trip.id!);

    if (incomingTrips.isEmpty) {
      _ringedTripIds.clear();
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
      // Was a 60s timeout against a 5s heartbeat — a single hung request
      // could sit in flight through a dozen more ticks before ever failing.
      // 15s still comfortably covers a slow network without blocking that
      // many cycles behind it.
      Response response = await homeRepo
          .driverLocationUpdate(lat: lat, lng: lng)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'] == '200') {
        locationHealth.recordSuccess();
        debugPrint(
          '[LocationPipeline] location stored lat=$lat lng=$lng '
          '(confirmed by backend)',
        );
        update();
        return response;
      } else {
        locationHealth.recordFailure();
        debugPrint(
          '[LocationPipeline] location update REJECTED status='
          '${response.statusCode} body=${response.body} '
          '(consecutiveFailures=${locationHealth.consecutiveFailures})',
        );
        return response;
      }
    } catch (e) {
      locationHealth.recordFailure();
      debugPrint(
        '[LocationPipeline] location update FAILED: $e '
        '(consecutiveFailures=${locationHealth.consecutiveFailures})',
      );
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
        // So the next request — after this ride finishes and listening
        // resumes — is guaranteed to ring, instead of possibly inheriting
        // a stale "already rung" id from before this ride.
        _ringedTripIds.clear();

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
      // computedDistance is this trip's tracked distance (Google Directions
      // pickup→drop, refreshed throughout the ride by trackbookingRide/
      // calculateETA, with a Haversine fallback) — the closest thing this
      // app has to an "actual distance driven" figure. Falls back to
      // totaldestance, then '0', so the request never omits/empties a
      // field the backend requires.
      final String actualDistance = computedDistance.isNotEmpty
          ? computedDistance
          : (totaldestance?.isNotEmpty == true ? totaldestance! : '0');

      Response response = await homeRepo.completeRide(
        bookingid: bookingId,
        source: source,
        actualDistance: actualDistance,
      );
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
