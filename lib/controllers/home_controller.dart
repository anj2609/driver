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
import 'package:myridedriverapp/services/road_route.dart';
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

  // Booking ids rideCompletedMarked() has succeeded for, kept permanently
  // (not on a timer) and persisted so they survive an app restart. Guards
  // driverBookingActives() below.
  //
  // This used to be a single _lastCompletedBookingId honored only within a
  // 2-minute window, on the theory that a driver-booking-active read landing
  // shortly after completion could still report the just-finished booking as
  // "ongoing" because the backend hadn't caught up yet. That assumption is
  // what broke: `homescreen` is a plain GetPage, so *every* return to Home —
  // not just the one right after completing a ride — creates a fresh
  // HomeMapScreen and re-arms its 10s driverBookingActives() check. Any later
  // revisit past the 2-minute window (or a backend that simply takes longer
  // than 2 minutes to mark a booking completed — which, given everything else
  // found wrong with this backend's responses, is not a safe assumption to
  // make) hit an expired guard and read that stale "ongoing" as real, yanking
  // the driver straight back into the ride screen for a booking they'd
  // already been paid for and left — reported as the payment prompt
  // reappearing "after some time" back on Home.
  //
  // Once this app instance has completed a booking, there is no legitimate
  // reason to ever route back into it again, no matter how long the backend
  // takes to catch up — so remember it for good instead of on a clock.
  static const String _completedBookingIdsPrefsKey = 'completed_booking_ids';
  // Capped so this can't grow without bound over a long-lived install; a
  // driver is never going to need protection against a completion older than
  // its most recent few dozen rides.
  static const int _maxRememberedCompletedBookingIds = 50;
  final Set<String> _completedBookingIds = <String>{};
  bool _completedBookingIdsLoaded = false;

  Future<void> _ensureCompletedBookingIdsLoaded() async {
    if (_completedBookingIdsLoaded) return;
    _completedBookingIdsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_completedBookingIdsPrefsKey);
      if (saved != null) _completedBookingIds.addAll(saved);
    } catch (e) {
      debugPrint('[CompletedRides] failed to load persisted ids: $e');
    }
  }

  Future<void> _rememberCompletedBookingId(String bookingId) async {
    _completedBookingIds.add(bookingId);
    // Oldest-first eviction isn't tracked precisely (a Set has no order
    // guarantee) — approximate is fine here, this is a safety net, not an
    // audit log.
    while (_completedBookingIds.length > _maxRememberedCompletedBookingIds) {
      _completedBookingIds.remove(_completedBookingIds.first);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _completedBookingIdsPrefsKey,
        _completedBookingIds.toList(),
      );
    } catch (e) {
      debugPrint('[CompletedRides] failed to persist ids: $e');
    }
  }

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
  // GPS course, degrees 0-360 — populated by the same position stream as
  // latitude/longitude below. Only meaningful while actually moving; only
  // real live consumer today is in-app turn-by-turn navigation, which
  // falls back to computing bearing from consecutive fixes when this is
  // null/stale (parked, or a device that doesn't report it).
  double? heading;

  List<NewBookingNearByModel> incomingTrips = [];
  List<NewBookingNearByModel> acceptedTrip = [];
  DriverBookingActives? driverBookingActivesModel;
  // Lazily created and recreatable — deliberately not a `final` player built
  // once at construction. onClose() disposes it, but this controller is
  // registered fenix:true and in practice outlives its own onClose (a device
  // log showed the nearby-bookings poll still running for minutes after
  // disposal). An AudioPlayer cannot be revived once disposed, so from that
  // moment every playRingtone()/stopRingtone() threw "Player has not yet been
  // created or has already been disposed" — swallowed by their own catch
  // blocks — and the driver got a completely silent incoming-ride card for the
  // rest of the session. Routing all access through this getter means a
  // disposal is recoverable instead of permanent.
  AudioPlayer? _playerInstance;
  AudioPlayer get _player => _playerInstance ??= AudioPlayer();
  NewBookingNearByModel? savedTripData;
  AcceptRideModel? savedAcceptData;

  RideData? tripdata;
  Timer? _dummyTimer;
  Timer? _ringtoneTimer;
  ////driverlatitude driverlongitude
  // (isIncomingScreenOpen and its route-name constant used to live here. The
  // request card is no longer a route, so there is no open/closed state to
  // track — it renders whenever incomingTrips is non-empty. That flag latching
  // true was what silently suppressed every ride card.)
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

  // Guards driverArrived() against a second call landing while the first
  // is still in flight (fast double-tap) or after arrival was already
  // confirmed — the "Arrived" button hides itself once tapped, but that's
  // a UI-side setState racing the same frame as the tap, not a hard
  // guarantee. Without this, a second call reaches the backend, which
  // rejects it as an invalid/already-arrived ride — surfacing a scary
  // "invalid ride" toast for what the driver already correctly did once.
  bool _isMarkingArrived = false;

  // How long the backend's copy of our location can go without a confirmed
  // refresh before we stop trusting ourselves to be "visible" and take
  // action. The heartbeat fires every ~5s, so this tolerates a handful of
  // missed beats (e.g. a brief network blip) before reacting.
  static const Duration staleLocationThreshold = Duration(seconds: 90);

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
      _playerInstance?.dispose();
    } catch (_) {}
    // Cleared so the getter rebuilds a fresh player if this controller is used
    // again after onClose — disposal must not be a one-way door.
    _playerInstance = null;
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

    // Don't surface this on the active-ride screen — the driver is mid-way
    // to (or with) a rider and this toast reads as alarming/irrelevant noise
    // there; it's still meaningful (and shown) everywhere else, e.g. the
    // home screen, where "online" is the thing the driver is looking at.
    final onRideScreen = Get.currentRoute == RouteHelper.goingForPickupScreen;
    if (Get.context != null && !onRideScreen) {
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
      // This restores "online" on app startup from a previous session,
      // exactly like toggleOnline()'s success path does when the driver
      // taps the switch — and needs the same grace-period reset. Without
      // it, a driver who simply reopens the app while already online got
      // auto-flipped offline by the staleness watchdog within ~10s (its
      // first tick), before the first heartbeat after restart even had a
      // chance to land: the tracker had no prior success recorded *and*
      // no session-start anchor, so isStale() treated that as staleness
      // immediately. That silently killed nearby-rider polling — the
      // toggle looked online for a few seconds, then wasn't, with only a
      // toast (easy to miss) marking the moment.
      locationHealth.reset();
      _autoOfflineTriggered = false;
      startListeningBookings();
    }
    update();
    debugPrint('sttsuaaaa:::$isOnline');
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
    _autoUpdateTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
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
    debugPrint('testing  booking id $statusRide');
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

      if (!context.mounted) return;
      Response res = await driverStatusOnlineOffline(context: context);

      // Same type-tolerance fix as the new-booking-list check below (see
      // _pollNearbyBookings) — a bare `== "200"` here would silently leave
      // the driver unable to go online at all if this endpoint's "code"
      // ever arrives as a JSON number instead of a string.
      final toggleCode =
          res.body is Map ? res.body['code']?.toString() : null;
      if (res.statusCode == 200 && toggleCode == "200") {
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
              message:
                  "You're Online — sharing your location with nearby riders.",
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
        Get.snackbar(
          "Error",
          "Could not update availability status. Please try again.",
        );
      }
    } catch (e, st) {
      debugPrint('[ToggleOnline] ERROR: $e\n$st');
      Get.snackbar(
        "Error",
        "Failed to change availability. Please check your connection.",
      );
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
        heading = position.heading;
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
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              latitude = position.latitude;
              longitude = position.longitude;
              heading = position.heading;
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
          notificationText:
              'Sharing your location so nearby riders can find you',
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
    _locationRetryTimer = Timer(
      const Duration(seconds: 15),
      startLocationUpdates,
    );
  }

  void startListeningBookings() {
    stopListeningBookings();
    // Fire immediately so the driver sees nearby rides the moment they go online
    _pollNearbyBookings();
    _dummyTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollNearbyBookings(),
    );
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

  // Cache for the is_busy pre-check below — see its comment for why this
  // exists. 15s, i.e. one re-check per five poll cycles: long enough to cut
  // the extra get-profile call by 80%, short enough that a driver who just
  // got busy is skipped from new-booking-list within one cancellation-worthy
  // window rather than riding on a minute-old value.
  static const Duration _busyCheckInterval = Duration(seconds: 15);
  DateTime? _lastBusyCheckAt;
  bool _cachedIsBusy = false;

  Future<void> _pollNearbyBookings() async {
    if (!isOnline) return;
    if (_isPollingNearbyBookings) return;
    _isPollingNearbyBookings = true;

    try {
      // Do not search if the driver is busy with an accepted/ongoing ride.
      // This is a secondary, best-effort guard (the backend's own
      // new-booking-list query is what actually has to prevent double
      // assignment) — so a failure to *determine* busy status must not be
      // treated the same as *confirmed* busy. It used to `return` here on
      // any exception (timeout, parse error, dropped connection), which
      // silently skipped the entire poll cycle — including the actual
      // new-booking-list fetch below — every single time this call had a
      // hiccup, with nothing logged to say why. A driver hitting this on
      // most/every cycle would see their incoming-request card simply never
      // appear, indistinguishable from there being no nearby riders at all.
      //
      // Only re-fetched every _busyCheckInterval rather than on every single
      // 3s tick — this alone was doubling the request rate of the whole
      // dispatch loop (a full get-profile call purely to read one field,
      // back-to-back with the new-booking-list call it gates) for as long as
      // any driver was online. It's only a secondary guard, so a slightly
      // stale cached value between real checks costs nothing the backend
      // wasn't already covering.
      final bool needsBusyCheck = _lastBusyCheckAt == null ||
          DateTime.now().difference(_lastBusyCheckAt!) >= _busyCheckInterval;
      if (needsBusyCheck) {
        try {
          final profileRes = await homeRepo.getDriverProfile();
          _lastBusyCheckAt = DateTime.now();
          if (profileRes.statusCode == 200 && profileRes.body != null) {
            final profileData = profileRes.body['data'];
            final isBusy = profileData?['is_busy'];
            _cachedIsBusy =
                isBusy == true || isBusy == 1 || isBusy?.toString() == '1';
          }
        } catch (e) {
          debugPrint(
            '[LocationPipeline] is_busy check failed ($e) — proceeding with '
            'new-booking-list poll using the last known value instead of '
            'silently skipping it',
          );
        }
      }
      if (_cachedIsBusy) {
        debugPrint('Driver is_busy — skipping new-booking-list poll');
        return;
      }

      try {
        debugPrint(
          '[LocationPipeline] match query run (new-booking-list) '
          'driverLat=$latitude driverLng=$longitude',
        );
        Response response = await homeRepo.newBookingNearByMe();

        // CONFIRMED from a real device log: this endpoint's success key is
        // "status" ("status":"200"), not "code" like every other endpoint
        // in this app — {"status":"200","message":"Nearby Booking
        // List","data":[...]}. The original bug here was assumed to be a
        // string-vs-number type mismatch on "code" (the fix that pattern
        // needed everywhere else), but the real cause was simpler: this
        // response has no "code" key at all, so `response.body['code']`
        // was always null and the branch below was always skipped — with
        // real, matching trips sitting right there in `data` every time.
        // "code" is still checked as a fallback in case the backend is
        // ever made consistent later; "status" is what it actually sends
        // today.
        final responseCode = response.body is Map
            ? (response.body['status'] ?? response.body['code'])?.toString()
            : null;
        debugPrint(
          '[LocationPipeline] new-booking-list statusCode=${response.statusCode} '
          'code=$responseCode raw=${response.body}',
        );
        if (response.statusCode == 200 && responseCode == "200") {
          List data = response.body['data'] ?? [];

          // Same permanent guard used in driverBookingActives() — see there
          // for the full story. Reported: after completing and being paid
          // for a ride, the exact same ride's card reappeared as if it were
          // a fresh incoming request, and tapping it (or any other) then got
          // rejected with "You already have an active ride" — the backend's
          // own accept-ride check, which is direct evidence the booking
          // never actually got closed out server-side, even though it was
          // completed from this app's point of view. new-booking-list
          // re-offering it is the same kind of staleness that
          // driverBookingActives() already had to defend against, just on
          // the "new request" side instead of the "resume an active ride"
          // side. Filtering it out here means a booking we know we finished
          // can never come back as a card, regardless of what the backend's
          // own record still says.
          await _ensureCompletedBookingIdsLoaded();

          List<NewBookingNearByModel> apiTrips = data
              .map((trip) => NewBookingNearByModel.fromJson(trip))
              // Drop anything this driver already declined this session —
              // the backend has no decline endpoint to exclude it for us,
              // so without this it would resurface on the very next poll —
              // and anything already completed by this app, ever.
              .where(
                (trip) =>
                    trip.id == null ||
                    (!_rejectedTripIds.contains(trip.id) &&
                        !_completedBookingIds.contains(trip.id.toString())),
              )
              .toList();

          debugPrint(
            '[LocationPipeline] match query returned ${apiTrips.length} '
            'nearby trip(s)',
          );
          _logSuspiciouslyDistantMatches(apiTrips);

          // Assigned as a whole new list rather than clear()+addAll() on the
          // live one. IncomingBookingScreen renders straight off
          // controller.incomingTrips, and its build() has an empty-guard that
          // pops the screen (and calls stopRingtone) the moment it sees an
          // empty list — so mutating the same instance in place gave that
          // guard a window to observe the emptied intermediate state and tear
          // down a card that was about to be refilled with the very same trip.
          incomingTrips = apiTrips;

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
          }

          // No navigation here any more. The request card lives inside the
          // home screen's own Stack and shows itself whenever incomingTrips is
          // non-empty, so this update() *is* the "show the card" step.
          //
          // Pushing it as a route was the source of two separate outages: the
          // isIncomingScreenOpen flag latched true whenever the route was torn
          // down without its pop callback firing (an offAll/offNamedUntil from
          // the ride flow, or Get.to() returning null when the navigator
          // wasn't ready), after which every poll found trips and silently
          // dropped them — and pushing transparently over the map didn't work
          // either, because the map is an Android platform view and those
          // don't composite under a non-opaque route.
          debugPrint(
            '[LocationPipeline] rendering ${incomingTrips.length} request '
            'card(s) over the map',
          );

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
    // So a stale busy=true from just before going offline (e.g. finishing a
    // ride) can't survive into the next online session and silently suppress
    // new-booking-list until the 15s cache would have expired anyway.
    _lastBusyCheckAt = null;
    _cachedIsBusy = false;
  }

  void returnToExistingHome() {
    // Was a manual popUntil(home-or-first-route) with Get.offAllNamed() as
    // a fallback only when home wasn't found. Home is never actually still
    // on the stack by the time a ride finishes (accepting a ride clears
    // down to just that flow), so the popUntil fallback was the branch
    // that always ran in practice — but getting there first walked the
    // navigator all the way down to the stack's very first route (e.g.
    // splash), which could flash briefly before offAllNamed() then
    // replaced it with Home. Skipping straight to offAllNamed() reaches
    // the same end state (clean stack, single Home) in one atomic step
    // instead of two, with no transient wrong screen in between — and
    // still fixes the original "multiple home screens on the back-stack"
    // issue this existed for, since offAllNamed() clears everything
    // either way.
    Get.offAllNamed(RouteHelper.getHomeScreen());
  }

  bool _isSuccessResponse(Response response) {
    final body = response.body;
    if (response.statusCode != 200 || body == null) return false;
    if (body is! Map) return false;

    final code = body['code']?.toString().toLowerCase();
    final status = body['status']?.toString().toLowerCase();
    final success = body['success']?.toString().toLowerCase();

    return code == '200' ||
        code == 'success' ||
        status == 'true' ||
        status == '200' ||
        status == 'success' ||
        success == 'true';
  }

  String _responseMessage(Response response) {
    final body = response.body;
    if (body is Map) {
      return body['message']?.toString() ?? body['error']?.toString() ?? '';
    }
    return '';
  }

  bool _looksAlreadyHandled(String message) {
    final lower = message.toLowerCase();
    // Checking 'invalid' and 'ride'/'booking' independently (not just as
    // one fixed ordered phrase) since the exact wording/order isn't ours to
    // control — "invalid ride", "ride is invalid", "invalid ride status"
    // etc. should all be recognized the same way.
    final mentionsInvalid = lower.contains('invalid');
    final mentionsRideOrBooking =
        lower.contains('ride') || lower.contains('booking');
    // Deliberately NOT matching on a bare 'status' — this feeds
    // rideCompletedMarked()/driverArrived() too, where it's used to decide
    // "treat this as success and navigate away". A genuine failure message
    // ("payment status not confirmed", "booking status mismatch") very
    // plausibly contains that word too; wrongly matching it would silently
    // wave through a real failure as if the ride/payment had completed.
    // 'not active' is specific enough to keep as its own signal.
    return lower.contains('already') ||
        (mentionsInvalid && mentionsRideOrBooking) ||
        lower.contains('not active');
  }

  Future<void> playRingtone() async {
    if (isRingtonePlaying) return;

    isRingtonePlaying = true;

    try {
      await _playRingtoneOnce();
    } catch (e) {
      // A dead player throws on every call and can never recover by itself,
      // so retrying against the same instance is pointless — rebuild it once
      // and try again. Without this, one bad disposal silences every future
      // ride request for the life of the session.
      debugPrint('playRingtone error: $e — rebuilding player and retrying');
      try {
        try {
          _playerInstance?.dispose();
        } catch (_) {}
        _playerInstance = null;
        await _playRingtoneOnce();
      } catch (e2) {
        debugPrint('playRingtone retry failed: $e2');
        // Reset flag so next attempt can try again
        isRingtonePlaying = false;
        return;
      }
    }

    // Auto-stop after 3 seconds
    _ringtoneTimer?.cancel();
    _ringtoneTimer = Timer(const Duration(seconds: 3), () {
      stopRingtone();
    });
  }

  /// One attempt at starting the ringtone. Separated out so [playRingtone] can
  /// run it a second time against a freshly built player without duplicating
  /// the sequence.
  Future<void> _playRingtoneOnce() async {
    // Best-effort cleanup of whatever the player was last doing — a fresh
    // instance has nothing to stop, so failures here are expected and ignored.
    try {
      await _player.stop();
      await _player.release();
    } catch (_) {}

    await _player.setReleaseMode(ReleaseMode.release);
    await _player.play(AssetSource('sound/ringtone.mp3'));
  }

  void stopRingtone() async {
    _ringtoneTimer?.cancel();
    _ringtoneTimer = null;
    isRingtonePlaying = false;
    try {
      // Deliberately the nullable field, not the getter — stopping should
      // never construct a player that didn't already exist.
      await _playerInstance?.stop();
    } catch (e) {
      debugPrint('stopRingtone error: $e');
    }
  }

  void acceptTrip(NewBookingNearByModel trip) async {
    _ringedTripIds.clear();
    stopRingtone();
    acceptedTrip.clear();
    acceptedTrip.add(trip);
    Get.offNamedUntil(
      RouteHelper.getgoingForPickupScreen(),
      (route) => route.settings.name == RouteHelper.getHomeScreen(),
      arguments: {"trips": trip},
    );

    incomingTrips.clear();

    stopListeningBookings();

    // Required now that the card is part of the home screen rather than a
    // route that gets popped. offNamedUntil keeps home mounted underneath the
    // pickup screen, and stopListeningBookings() means no further poll will
    // fire an update() — so without this the accepted request would still be
    // sitting on the home map when the driver returns to it after the ride.
    update();
  }

  void rejectTrip(NewBookingNearByModel trip) {
    incomingTrips.remove(trip);
    if (trip.id != null) _rejectedTripIds.add(trip.id!);

    if (incomingTrips.isEmpty) {
      _ringedTripIds.clear();
      stopRingtone();
      // No Get.back() here any more. The card used to be its own route, so
      // dismissing the last request meant popping it; now that it's a widget
      // inside the home screen, that same pop would tear down the *home
      // screen* instead. Emptying the list is all that's needed — the card
      // renders nothing when there's nothing pending.
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
          response.body['code']?.toString() == '200') {
        var data = response.body['data'];

        debugPrint('sttaus::::::${data['work_status']}');

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

      // Was a bare `== '200'` — the exact same type-tolerance bug already
      // fixed in _pollNearbyBookings and the go-online toggle above, but
      // still present here in the 5s location heartbeat itself. If this
      // endpoint's "code" ever arrives as the JSON number 200 rather than
      // the string "200", every single heartbeat gets recorded as a
      // FAILURE even though the backend actually stored the location —
      // locationHealth never records a real success, and ~90s later the
      // staleness watchdog (_handleLocationStale) auto-takes the driver
      // offline and calls stopListeningBookings(), silently ending the
      // new-booking-list poll entirely. That's a direct, well-evidenced
      // explanation for "driver shows online but no ride card ever
      // appears" — the driver looks online in the UI for a while, then
      // silently isn't anymore, with only an easy-to-miss toast to say so.
      final locationCode = response.body is Map
          ? response.body['code']?.toString()
          : null;
      if (response.statusCode == 200 &&
          response.body != null &&
          locationCode == '200') {
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

    debugPrint("  Newbooking ${response.body}");

    // Same fix as _pollNearbyBookings — this endpoint's real success key is
    // "status", not "code" (see the comment there for the confirmed log).
    final newBookingCode = response.body is Map
        ? (response.body['status'] ?? response.body['code'])?.toString()
        : null;
    if (response.statusCode == 200 && newBookingCode == '200') {
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

  // Guards against a second, overlapping acceptRidesTrip() call for the
  // same or a different booking while one is already in flight — the
  // screen has its own local guard on the Accept button too, this is the
  // controller-level backstop.
  bool _isAcceptingTrip = false;

  Future<Response> acceptRidesTrip({
    required BuildContext context,
    required String bookingId,
    NewBookingNearByModel? trips,
  }) async {
    if (_isAcceptingTrip) {
      return Response(statusCode: 0, body: {'code': 'busy'});
    }
    _isAcceptingTrip = true;

    final prefs = await SharedPreferences.getInstance();

    // EasyLoading.show(status: "Please wait...");
    update();
    saveRideBookingStatus(bookingId);

    try {
      Response response = await homeRepo.acceptRide(bookingid: bookingId);
      // debugPrint('testing mode for accept ride ${response.body['code']}');
      //  EasyLoading.dismiss();
      // Same type-tolerance fix as driverUpdateLocation/_pollNearbyBookings
      // above — a bare `== '200'` here would make tapping "Accept" silently
      // do nothing (no navigation, ringtone left playing) if this endpoint's
      // "code" ever arrives as a number.
      final acceptCode =
          response.body is Map ? response.body['code']?.toString() : null;
      if (response.statusCode == 200 &&
          response.body != null &&
          acceptCode == '200') {
        //  tripdata = response.body['data'];
        stopRingtone();

        // Was fire-and-forget, immediately followed by navigation — so
        // GoingForPickupScreen mounted before trackRideModel had any data,
        // and showed its own bare loading spinner for however long this
        // request actually took. Under real network conditions that's not
        // instant: this fires right alongside get-profile and
        // driver-location-update (both visible in the same burst in device
        // logs), and this app's HTTP client has a 60s timeout — so the
        // driver could watch the accept-loading dialog, then land on a
        // *second*, unexplained spinner for anywhere from a few seconds to
        // uncomfortably long. Awaiting it here — bounded, so a slow response
        // can't hang the accept flow itself — means the destination screen
        // has its data already in hand for its very first frame in the
        // common case. Capped at 3s, tight enough that the accept-loading dialog reads as brief rather than a stall, and deliberately shorter than the pickup
        // screen's own 8s retry-UI reveal (see pickup_screen.dart), so a
        // genuinely slow/failing fetch still falls through to navigate and
        // that screen's own retry affordance takes over, rather than making
        // the driver wait twice for the same failure.
        if (context.mounted) {
          try {
            await trackbookingRide(
              context: context,
              bookingId: bookingId,
            ).timeout(const Duration(seconds: 3));
          } catch (e) {
            debugPrint(
              '[Accept] trackbookingRide did not complete within 3s '
              '($e) — proceeding to the pickup screen anyway; its own '
              'retry UI will take over from here.',
            );
          }
        }

        Get.offNamedUntil(
          RouteHelper.getgoingForPickupScreen(),
          (route) => route.settings.name == RouteHelper.getHomeScreen(),
          arguments: {"trips": trips},
        );
        if (trips != null) {
          String tripJson = jsonEncode(trips.toJson());

          await prefs.setString("trip_data", tripJson);

          debugPrint("Trip Saved");
        }

        incomingTrips.clear();
        // So the next request — after this ride finishes and listening
        // resumes — is guaranteed to ring, instead of possibly inheriting
        // a stale "already rung" id from before this ride.
        _ringedTripIds.clear();

        stopListeningBookings();

        //  Get.snackbar("Success", "Trip Accepted");
        prefs.setString(ApiConstants.acceptedtrip, jsonEncode(trips!.toJson()));
        await prefs.setString(ApiConstants.bookingid, bookingId);
        debugPrint("Booking ID: ${prefs.get(ApiConstants.bookingid)}");

        update();
        return response;
      } else if (response.body != null &&
          response.body['code']?.toString() == '401') {
        hasActiveRide = true;
        if (context.mounted) {
          AnimatedTopToast.show(
            context: context,
            message: 'You already have an active ride. Please complete it first.',
            backgroundColor: ColorResources.redbuttoncolor,
            icon: Icons.error_rounded,
          );
        }

        return response;
      } else {
        // Was a hardcoded generic message regardless of why the backend
        // actually rejected it (e.g. a validation failure specific to this
        // booking — no fare could be computed, outside a service area,
        // already taken by another driver, etc). Surfacing the backend's
        // own message, same as the other accept/save flows fixed earlier
        // this session, turns "just try again" into an actual reason.
        final backendMessage = response.body is Map
            ? response.body['message']?.toString()
            : null;
        debugPrint(
          'acceptRidesTrip rejected: status=${response.statusCode} body=${response.body}',
        );
        if (context.mounted) {
          AnimatedTopToast.show(
            context: context,
            message: (backendMessage != null && backendMessage.isNotEmpty)
                ? backendMessage
                : 'Could not accept this trip. Please try again.',
            backgroundColor: ColorResources.redbuttoncolor,
            icon: Icons.error_rounded,
          );
        }

        return response;
      }
    } catch (e) {
      // Was `rethrow` with no toast — the screen's own catch around this
      // call (trip_request_screen.dart) only debugPrints, so an
      // exception here (network failure, a null response body, etc.)
      // reached the driver as literally nothing: no toast, no error, the
      // Accept button just looked like it did nothing.
      debugPrint('acceptRidesTrip error: $e');
      EasyLoading.dismiss();
      if (Get.context != null) {
        AnimatedTopToast.show(
          context: Get.context!,
          message: 'Could not accept this trip. Please check your connection and try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
      return Response(statusCode: 0, body: {'code': 'error'});
    } finally {
      _isAcceptingTrip = false;
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
          response.body['code']?.toString() == '200') {
        cancleReasonModel = CancleReasonModel.fromJson(response.body);
        cancleReasonModelList.clear();
        cancleReasonModelList.addAll(cancleReasonModel?.data ?? []);

        debugPrint('Cancel Ride Reason Data: ${cancleReasonModelList.length}');
        // isLoading = false;
        update();
        return response;
      } else {
        debugPrint('Cancel reason response: ${response.body}');
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
        final code =
            response.body['code']?.toString() ??
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
          // API returned a non-200 code — no toast (post-accept ride flow
          // is toast-free by design; the UI itself simply doesn't advance).
          return response;
        }
      } else {
        return response;
      }
    } catch (e) {
      debugPrint('cancleRideByDriver error: $e');
      rethrow;
    }
  }

  /////// ========================= Track Booking Ride ========================/////
  ////trackBookingRide

  // Set on a failed/errored trackbookingRide() call, cleared at the start of
  // the next one. Not read by any UI right now — pickup_screen deliberately
  // shows no loading/retry state of its own (see its build()) — but kept as
  // a plain diagnostic signal (visible via debugPrint below and to anything
  // that wants it later) distinguishing "still trying" from "gave up,"
  // rather than deleting it along with the retry UI it used to drive.
  bool trackRideLoadFailed = false;

  Future<Response?> trackbookingRide({
    required BuildContext context,
    String? bookingId,
  }) async {
    // EasyLoading.show(status: "Please wait...");
    trackRideLoadFailed = false;
    update();

    Response? response;

    try {
      response = await homeRepo.trackBookingRide(bookingid: bookingId);

      debugPrint('API RESPONSE ===> ${response.body}');

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
              final tripData =
                  Get.find<ProfileController>().tripDetailsModel?.data;
              dLat = tripData?.dropLat;
              dLng = tripData?.dropLng;
            } catch (_) {}
          }

          if (pickupLat != null &&
              pickupLng != null &&
              dLat != null &&
              dLng != null &&
              !(pickupLat == 0.0 && pickupLng == 0.0) &&
              !(dLat == 0.0 && dLng == 0.0)) {
            fetchRouteDistanceDuration(
              pickupLat: pickupLat,
              pickupLng: pickupLng,
              dropLat: dLat,
              dropLng: dLng,
            );

            // Fire-and-forget, cached by booking id — see
            // _ensureActualTripRoadDistance. Kicked off as early as pickup/drop
            // are known (ride start) so the real road-network figure is
            // already cached by the time the driver reaches payment, rather
            // than making complete-ride/generate-qr-payment wait on a
            // Directions API call.
            final String? bookingIdForRoute = rideData?.bookingId?.toString();
            if (bookingIdForRoute != null) {
              _ensureActualTripRoadDistance(
                bookingIdForRoute,
                pickupLat,
                pickupLng,
                dLat,
                dLng,
              );
            }
          }
        } else {
          //  EasyLoading.dismiss();
          debugPrint(trackRideModel?.message ?? "Something went wrong");
          // Backend responded (HTTP 200) but its own inner code signals a
          // failure — trackRideModel is non-null, but pickup_screen also
          // requires trackRideModel.data, which a response shaped like this
          // won't have populated. Same hang as the two branches below.
          trackRideLoadFailed = true;

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
        debugPrint("ERROR ===> Invalid server response");
        trackRideLoadFailed = true;
        // Get.snackbar(
        //   '',
        //   "Invalid server response",
        //   backgroundColor: ColorResources.textColorRed,
        //   colorText: Colors.white,
        // );
      }
    } catch (e) {
      ///EasyLoading.dismiss();
      debugPrint("ERROR ===> $e");
      trackRideLoadFailed = true;

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

      debugPrint("ACTIVE RESPONSE => ${response.body}");

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'].toString() == '200') {
        driverBookingActivesModel = DriverBookingActives.fromJson(
          response.body,
        );

        final data = driverBookingActivesModel?.data;

        final String status = data?.status?.toString() ?? "";
        final String bookingId = data?.bookingId?.toString() ?? "";

        debugPrint("ACTIVE STATUS => $status");
        debugPrint("BOOKING ID => $bookingId");

        // This same booking was completed (rideCompletedMarked() succeeded)
        // by this app instance at some point — if the backend's own "active
        // ride" record hasn't caught up (or never fully does), this poll can
        // still report it "accepted"/"ongoing" even though the driver has
        // already been paid and sent home. `homescreen` is a plain GetPage,
        // so every return to Home — not just the one right after completing
        // a ride — re-arms the check that calls this, so a stale read taken
        // at face value could yank the driver straight back into the ride
        // screen for a booking they'd already left, at any later point, not
        // just moments after completion. Once we've completed a booking
        // ourselves there's no legitimate reason to ever navigate back into
        // it, so this is checked with no time limit.
        await _ensureCompletedBookingIdsLoaded();
        final bool isCompletedBooking =
            bookingId.isNotEmpty && _completedBookingIds.contains(bookingId);

        if (isCompletedBooking) {
          debugPrint(
            "ACTIVE RIDE IGNORED => booking $bookingId was already "
            "completed by this app; treating this '$status' read as stale "
            "rather than navigating back into it.",
          );
          return;
        }

        ///=============== TRACK RIDE API CALL =================///
        if (bookingId.isNotEmpty) {
          await trackbookingRide(context: Get.context!, bookingId: bookingId);
        }

        ///=============== NAVIGATION HANDLE =================///
        switch (status) {
          /// DRIVER ACCEPTED RIDE
          case "accepted":
            debugPrint("NAVIGATE => GOING FOR PICKUP");

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
            debugPrint("NAVIGATE => START DRIVER RIDE");

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
            debugPrint("NAVIGATE => HOME");

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
            debugPrint("NO ACTIVE RIDE FOUND");
        }
      }
    } catch (e) {
      debugPrint("ACTIVE RIDE ERROR => $e");
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
    // A second call landing while the first is still in flight — a fast
    // double-tap on the button before its own setState hides it — used to
    // reach the backend, which rejects the already-in-progress arrival and
    // surfaces that as a scary "invalid ride" toast. Blocking it here means
    // there's nothing left to reject: the backend only ever sees one call
    // per tap. (Deliberately not also checking arrivedStatusCode — that
    // field is never reset between rides, so treating "== '200'" as
    // "already arrived" would silently block arrival on every ride after
    // the very first one this app instance ever completed.)
    if (_isMarkingArrived) {
      return Response(statusCode: 200, body: {'code': '200'});
    }
    _isMarkingArrived = true;

    /// EasyLoading.show(status: "Please wait...");
    update();

    try {
      Response response = await homeRepo.driverArrivedApi(bookingid: bookingId);
      debugPrint('testing mode for driverArrived body=${response.body}');
      // EasyLoading.dismiss();
      if (_isSuccessResponse(response)) {
        /// EasyLoading.dismiss();
        arrivedStatusCode = response.body['code'].toString();
        debugPrint('status code arrived ||||  ${response.body['code']}');
        debugPrint('status code arrived ||||  $arrivedStatusCode');
        // Get.snackbar(
        //   '',
        //   response.body['message'],
        //   backgroundColor: ColorResources.appColor,
        //   colorText: Colors.white,
        //   snackPosition: SnackPosition.TOP,
        // );

        update();
        return response;
      } else if (response.body != null &&
          response.body['code']?.toString() == '401') {
        hasActiveRide = true;
        // No toast — post-accept ride flow is toast-free by design.
        return response;
      } else {
        final message = _responseMessage(response);
        if (_looksAlreadyHandled(message)) {
          arrivedStatusCode = '200';
          update();
          return Response(
            statusCode: 200,
            body: {'code': '200', 'message': message},
          );
        }
        // No toast — post-accept ride flow is toast-free by design; the
        // Arrived button simply stays available so the driver can retry.
        return response;
      }
    } catch (e) {
      ////  EasyLoading.dismiss();
      rethrow;
    } finally {
      _isMarkingArrived = false;
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
      final String actualDistance = _actualDistanceForBackend();

      Response response = await homeRepo.completeRide(
        bookingid: bookingId,
        source: source,
        actualDistance: actualDistance,
      );
      debugPrint('testing mode for completeRide ${response.body?['code']}');

      if (_isSuccessResponse(response)) {
        // Recorded (and persisted) before anything else clears — see
        // driverBookingActives() for why this booking id needs to stay
        // remembered permanently, even though every other trace of it is
        // about to be wiped below. Not awaited: this only writes to
        // SharedPreferences, and nothing below depends on it having landed.
        _rememberCompletedBookingId(bookingId);

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

        returnToExistingHome();

        // Restart listening for new bookings if driver is still online
        if (isOnline) {
          startListeningBookings();
        }

        update();
        return response;
      } else if (response.body != null &&
          response.body['code']?.toString() == '401') {
        // Was an unconditional "conflict, stay put" — but this code is
        // reused across every ride-flow endpoint for "not in the expected
        // state for this action", and for complete-ride specifically that
        // can just as easily mean "already completed" (e.g. this exact
        // call landing twice — a slow first response plus a retry) as it
        // can mean a genuine different-ride conflict. Silently returning
        // for *both* meant a driver who tapped "Cash Received" on an
        // already-completed booking got left stranded on the payment
        // screen forever, identically to the online-payment "already paid"
        // case fixed in generateOnlineQr() — same root issue, same fix:
        // check what the message actually says before assuming conflict.
        final message = _responseMessage(response);
        if (_looksAlreadyHandled(message)) {
          returnToExistingHome();
          if (isOnline) {
            startListeningBookings();
          }
          update();
          return Response(
            statusCode: 200,
            body: {'code': '200', 'message': message},
          );
        }
        hasActiveRide = true;
        // No toast — post-accept ride flow is toast-free by design.
        return response;
      } else {
        final message = _responseMessage(response);
        if (_looksAlreadyHandled(message)) {
          returnToExistingHome();
          if (isOnline) {
            startListeningBookings();
          }
          update();
          return Response(
            statusCode: 200,
            body: {'code': '200', 'message': message},
          );
        }
        // Was silent ("toast-free by design") — but unlike the 401
        // "already have an active ride" case above (which has its own
        // affordance: the button just stays there to retry), a genuine
        // completion failure (no internet, backend validation reject,
        // timeout, ...) left the driver staring at the exact same screen
        // after tapping "Cash Received"/"Confirm" with zero indication
        // anything went wrong — indistinguishable from the tap having
        // done nothing at all. Same fix already applied to
        // acceptRidesTrip(): surface the backend's own message so there's
        // an actual reason instead of a silent hang.
        debugPrint(
          'rideCompletedMarked rejected: status=${response.statusCode} body=${response.body}',
        );
        if (context.mounted) {
          AnimatedTopToast.show(
            context: context,
            message: message.isNotEmpty
                ? message
                : 'Could not complete the ride. Please check your connection and try again.',
            backgroundColor: ColorResources.redbuttoncolor,
            icon: Icons.error_rounded,
          );
        }
        return response;
      }
    } catch (e) {
      // Was `rethrow` with no toast — homeRepo.completeRide()/apiClient
      // already swallow network exceptions into a Response(statusCode: 1),
      // so this catch is mostly for the rare unexpected throw (e.g. a
      // null-check on a cleared model during the success branch above).
      // Rethrowing bare left the caller's own catch (startride_screen.dart)
      // doing nothing but a debugPrint — same silent-hang symptom as above.
      debugPrint('rideCompletedMarked error: $e');
      if (context.mounted) {
        AnimatedTopToast.show(
          context: context,
          message: 'Could not complete the ride. Please check your connection and try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
      return Response(statusCode: 0, body: {'code': 'error'});
    }
  }

  // ======= Online Payment — Generate QR & Verify =======

  // Road-network pickup->drop distance, cached per booking so
  // _actualDistanceForBackend can return it synchronously. Populated by
  // _ensureActualTripRoadDistance, kicked off as soon as pickup/drop are known
  // (see trackbookingRide) — well before the driver reaches a payment button,
  // so the real fetch happens off the critical path instead of adding a
  // Directions API round trip to complete-ride/generate-qr-payment.
  String? _actualTripDistanceBookingId;
  String? _actualTripRoadDistanceKm;

  Future<void> _ensureActualTripRoadDistance(
    String bookingId,
    double pickupLat,
    double pickupLng,
    double dropLat,
    double dropLng,
  ) async {
    if (_actualTripDistanceBookingId == bookingId &&
        _actualTripRoadDistanceKm != null) {
      return;
    }

    final route = await RoadRouteService.fetch(
      originLat: pickupLat,
      originLng: pickupLng,
      destLat: dropLat,
      destLng: dropLng,
    );

    if (route == null) {
      debugPrint(
        '[Payment] road-network distance fetch failed for booking '
        '$bookingId — actual_distance will fall back to a straight-line '
        'estimate until this succeeds',
      );
      return;
    }

    _actualTripDistanceBookingId = bookingId;
    _actualTripRoadDistanceKm = route.distanceKm.toStringAsFixed(1);
    debugPrint(
      '[Payment] road-network pickup→drop distance cached: '
      '$_actualTripRoadDistanceKm km for booking $bookingId',
    );
  }

  /// This trip's tracked distance, in the form the backend expects.
  ///
  /// Prefers the cached road-network figure from _ensureActualTripRoadDistance
  /// (the real driving distance, matching what the map now draws). Falls back
  /// to a Haversine straight-line estimate between pickup and drop only if
  /// that fetch hasn't completed yet or failed — still specific to this trip's
  /// actual endpoints, just not road-aware.
  ///
  /// Neither of those reads computedDistance/totaldestance any more, despite
  /// those fields' names: both are continuously overwritten with the distance
  /// from the *driver's live position* to the drop point (calculateETA/
  /// fetchRouteDistanceDuration are called with the driver's current lat/lng
  /// as the origin, refreshed throughout the ride for the on-screen ETA). By
  /// the time a ride completes the driver's live position is at the drop
  /// location, so that figure collapses to ~0 — confirmed from a device log
  /// showing actual_distance=0.0 sent to generate-qr-payment on a real,
  /// multi-hundred-km booking. The same value fed complete-ride too, so this
  /// wasn't only a QR-generation bug; every completed ride had been reporting
  /// close to zero distance. They're now only a last-resort fallback, used if
  /// this trip's pickup/drop coordinates are missing entirely.
  String _actualDistanceForBackend() {
    final rideData = trackRideModel?.data;
    final String? bookingId = rideData?.bookingId?.toString();

    if (bookingId != null &&
        _actualTripDistanceBookingId == bookingId &&
        _actualTripRoadDistanceKm != null) {
      return _actualTripRoadDistanceKm!;
    }

    final double? pickupLat = rideData?.lat;
    final double? pickupLng = rideData?.lng;
    final double? dropLat = rideData?.dropLat;
    final double? dropLng = rideData?.dropLng;

    if (pickupLat != null &&
        pickupLng != null &&
        dropLat != null &&
        dropLng != null &&
        !(pickupLat == 0.0 && pickupLng == 0.0) &&
        !(dropLat == 0.0 && dropLng == 0.0)) {
      final double distanceKm =
          calculateDistance(pickupLat, pickupLng, dropLat, dropLng);
      if (!distanceKm.isNaN && !distanceKm.isInfinite) {
        debugPrint(
          '[Payment] road-network distance not cached yet for booking '
          '$bookingId — sending straight-line estimate instead',
        );
        return distanceKm.toStringAsFixed(1);
      }
    }

    debugPrint(
      '[Payment] no usable pickup/drop coordinates for actual_distance — '
      'falling back to computedDistance/totaldestance (driver-to-drop, '
      'likely ~0 near ride end)',
    );
    if (computedDistance.isNotEmpty) return computedDistance;
    if (totaldestance?.isNotEmpty == true) return totaldestance!;
    return '0';
  }

  /// Why the last generateOnlineQr() call produced no QR, in words fit to show
  /// the driver. Null when the last attempt succeeded.
  ///
  /// generateOnlineQr() returns a bare null for every failure, so the caller
  /// could only ever say "couldn't create the QR, check your connection" — a
  /// guess that is wrong whenever the real cause is a backend rejection, and
  /// unhelpful either way. Carrying the reason out means the driver sees what
  /// actually happened without anyone needing a device log.
  String? lastQrError;

  Future<QrPaymentData?> generateOnlineQr({
    required BuildContext context,
    required String bookingId,
  }) async {
    lastQrError = null;
    try {
      final String distance = _actualDistanceForBackend();
      final response = await homeRepo.generateQrCode(
        bookingId: bookingId,
        actualDistance: distance,
      );
      final body = response.body;
      final isSuccess = _isSuccessResponse(response);

      // Every failure path below returns a bare null, and the caller can only
      // tell "no QR" — not why. That made "the QR sheet just doesn't appear"
      // impossible to diagnose from a device log, so log the raw response and
      // say which branch bailed out.
      debugPrint(
        '[Payment] generate-qr-payment bookingId=$bookingId '
        'actual_distance=$distance '
        'statusCode=${response.statusCode} isSuccess=$isSuccess raw=$body',
      );

      if (isSuccess) {
        final model = QrPaymentModel.fromJson(response.body);
        if (model.data != null) return model.data;

        if (body is Map) {
          final directData = QrPaymentData.fromJson(body.cast<String, dynamic>());
          if ((directData.imageUrl ?? '').isNotEmpty ||
              (directData.qrCode ?? '').isNotEmpty ||
              (directData.qrId ?? '').isNotEmpty) {
            return directData;
          }
          debugPrint(
            '[Payment] backend reported success but no QR fields were found — '
            'checked data.*, then top-level image_url/qr_code/qr_id. '
            'Keys present: ${body.keys.toList()}',
          );
        }
        lastQrError =
            'The payment gateway accepted the request but returned no QR '
            'code. Please try again, or collect cash instead.';
        return null;
      } else {
        final String? backendMessage =
            body is Map ? body['message']?.toString() : null;
        debugPrint(
          '[Payment] generate-qr-payment rejected: ${backendMessage ?? body}',
        );

        // "Booking already paid" (and the like) is the gateway telling us
        // this ride is actually *done* — same signal rideCompletedMarked()
        // already treats as success via _looksAlreadyHandled(). This path
        // didn't: it showed the backend's own "already paid" message as a
        // red error toast and then just stopped, leaving the driver
        // stranded on the ride/payment screen with a completed ride that
        // never got cleared or navigated away from — indistinguishable
        // from a real failure. Treat it the same way completion does:
        // clear ride state and go home instead of erroring out.
        if (backendMessage != null && _looksAlreadyHandled(backendMessage)) {
          if (context.mounted) {
            AnimatedTopToast.show(
              context: context,
              message: 'This ride is already paid for.',
              backgroundColor: ColorResources.blueeebutton,
              icon: Icons.check_circle_rounded,
            );
          }
          savedTripData = null;
          savedAcceptData = null;
          trackRideModel = null;
          driverBookingActivesModel = null;
          hasActiveRide = false;
          stopRingtone();
          returnToExistingHome();
          if (isOnline) {
            startListeningBookings();
          }
          update();
          return null;
        }

        // Prefer the backend's own wording — it is the only thing that can say
        // *why* (gateway not configured, a validation failure on a field this
        // app sends, etc). A generic "check your connection" actively
        // misleads when the network was fine.
        lastQrError = (backendMessage != null && backendMessage.isNotEmpty)
            ? backendMessage
            : 'The payment gateway rejected this request.';
        return null;
      }
    } catch (e, st) {
      debugPrint('generateOnlineQr error: $e\n$st');
      lastQrError =
          'Could not reach the payment gateway. Check your connection and '
          'try again.';
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
      final isPaid =
          data?['is_paid']?.toString() ?? response.body['is_paid']?.toString();
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
      debugPrint('testing mode for verifyPickupOtp $response');

      /// EasyLoading.dismiss();
      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code']?.toString() == '200') {
        verifyPickupOtpStatusCode = response.body['code'].toString();

        // No toast — post-accept ride flow is toast-free by design.
        debugPrint('testing data for Accept Data  $trips $acceptData');
        // Navigation is now handled by the pickup screen itself (shows End Ride button)

        update();
        return response;
      } else if (response.body != null &&
          response.body['code']?.toString() == '401') {
        hasActiveRide = true;
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

    debugPrint("Ride data cleared");
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

    // Was BitmapDescriptor.fromBytes() — same reasoning as
    // getCustomIcon() in custom_loader.dart: deprecated, and on newer
    // google_maps_flutter_android builds it can produce a descriptor the
    // native side fails to decode ("Failed to decode image. The provided
    // image must be a Bitmap."), crashing the instant a marker using it
    // is added. width/height keep the rendered size the same as the
    // targetWidth this was already being resized to above.
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: width.toDouble(),
      height: width.toDouble(),
    );
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
        endLng == null) {
      return;
    }

    debugPrint("Start:::::: ($startLat, $startLng) → End: ($endLat, $endLng)");

    // Was: markers only got added once the Directions call below had
    // already succeeded — so if that call ever failed (wrong/restricted API
    // key, Directions API not enabled for it in Google Cloud Console,
    // ZERO_RESULTS, quota, plain network error — none of which the driver's
    // network otherwise affects), the in-app map stayed completely blank:
    // no driver marker, no pickup marker, no route. Adding the markers
    // immediately — independent of whether the polyline call below
    // succeeds — means the map always shows *something* useful even when
    // the route itself can't be drawn, instead of forcing the driver to
    // fall back on external Google Maps for a route entirely.
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
    update();

    if (mapController != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(min(startLat, endLat), min(startLng, endLng)),
        northeast: LatLng(max(startLat, endLat), max(startLng, endLng)),
      );
      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }

    String url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=$startLat,$startLng&destination=$endLat,$endLng&key=${ApiConstants.apiKey}";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        debugPrint(
          '[Route] Directions HTTP ${response.statusCode}: ${response.body}',
        );
        return;
      }

      var data = json.decode(response.body);

      // Google's Directions API returns HTTP 200 even when it can't give a
      // route — the real outcome is in `status` (REQUEST_DENIED,
      // ZERO_RESULTS, OVER_QUERY_LIMIT, ...), with detail in
      // `error_message`. Logging both here is what actually tells us why
      // the polyline never appeared, instead of a silent no-op.
      final status = data['status'];
      if (status != 'OK' || data['routes'] == null || data['routes'].isEmpty) {
        debugPrint(
          '[Route] Directions API returned no route — status=$status '
          'error_message=${data['error_message']}',
        );
        return;
      }

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

        debugPrint(
          'Route: Distance=$computedDistance km, Duration=$computedDuration min',
        );
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

      update();
    } catch (e) {
      // Was an uncaught throw on non-200 — every call site invokes this
      // fire-and-forget (no await), so that exception had nowhere to go
      // but an unhandled Future error. Markers are already on the map by
      // this point regardless, so the driver isn't left with nothing.
      debugPrint('[Route] getRouteCoordinates error: $e');
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

    debugPrint("📍 LOCATION UPDATED: $lat , $lng");

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
  // Guards against piling up identical estimate requests. Like trip-detail,
  // this is called from addPostFrameCallback blocks registered during build(),
  // gated only on `estimatePrice.isEmpty` — so every unrelated rebuild (the 5s
  // location heartbeat, the 3s poll, each GPS fix) fires another one for as
  // long as the estimate fails to populate, and for a ride the backend won't
  // price it never does.
  bool _isFetchingEstimate = false;

  Future<void> fetchEstimateRideData({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
  }) async {
    if (_isFetchingEstimate) return;
    _isFetchingEstimate = true;

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
          debugPrint(
            'Estimate: price=$estimatePrice, dist=$estimateDistance, time=$estimateDuration',
          );
          update();
        }
      }
    } catch (e) {
      debugPrint('fetchEstimateRideData error: $e');
    } finally {
      _isFetchingEstimate = false;
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

          debugPrint(
            'Google Directions: Distance=$computedDistance km, Duration=$computedDuration min',
          );

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

    final newDistance = distance.toStringAsFixed(1);
    final newTime = timeMinutes.round().toString();

    // Guard against a no-op update(): pickup_screen.dart calls calculateETA()
    // from a postFrameCallback on every single build, and calculateETA used
    // to call update() unconditionally on every call — that is an infinite
    // rebuild loop (build -> postFrameCallback -> calculateETA -> update() ->
    // rebuild -> ...), firing as fast as the frame scheduler allows for as
    // long as the pickup screen is on screen. That constant full-screen
    // rebuild (GoogleMap + OTP Pinput + everything else) is why the OTP
    // boxes needed 2-3 taps before becoming responsive. Only rebuild when
    // the computed values actually changed.
    if (newDistance == totaldestance && newTime == totaltime) {
      return;
    }

    totaldestance = newDistance;
    totaltime = newTime;
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
                  color: ColorResources.textColorForGrey,
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
