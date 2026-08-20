import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/duration_format.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/model/newbooking_nearby_model.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

/// The incoming-ride request card. Mounted as a child of the home screen's
/// own Stack — deliberately NOT pushed as a route.
///
/// It used to be a full-screen route carrying its own GoogleMap, which is why
/// the map "disappeared" when a request arrived. Pushing it transparently
/// (opaque:false) over the home map didn't work either: on Android a
/// GoogleMap is a platform view, and platform views don't composite reliably
/// underneath a non-opaque route — the map goes blank. Living inside the home
/// screen's widget tree sidesteps the problem entirely: one route, one map,
/// and this is just a sibling painted above it.
///
/// It also means there's no route to track, so no open/closed flag to get out
/// of sync — visibility follows [HomeController.incomingTrips] directly.
class IncomingBookingScreen extends StatefulWidget {
  const IncomingBookingScreen({super.key});

  @override
  State<IncomingBookingScreen> createState() => _IncomingBookingScreenState();
}

class _IncomingBookingScreenState extends State<IncomingBookingScreen> {
  final HomeController controller = Get.find();

  int currentIndex = 0;

  // Guards the Accept button against a second tap while one accept is
  // already in flight (belt-and-suspenders alongside the controller-level
  // guard in acceptRidesTrip) — see the onTap handler in _rideCard() for
  // the full story on why this mattered.
  bool _isAcceptingTrip = false;

  // Owned by the State and disposed with it. This used to be constructed
  // inline in build() — and this widget is a GetBuilder<HomeController>, so it
  // rebuilds on every HomeController.update(): the 3s booking poll, the 5s
  // location heartbeat, and every location-stream event (distanceFilter is
  // 5m, so continuously while the driver is moving). That allocated a fresh
  // PageController, each holding a ScrollPosition attached to the viewport,
  // on every one of those — and never disposed any of them. The leak grew for
  // exactly as long as the request card stayed on screen.
  final PageController _pageController = PageController(viewportFraction: 0.92);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // The controller's own list is the source of truth — widget.trips is only
  // the snapshot at the moment this screen was first pushed. Reading from
  // the controller here means the "Accept"/"X" buttons and any new booking
  // the poll adds while this screen is open are reflected immediately,
  // instead of the screen staying frozen on its original snapshot.
  List<NewBookingNearByModel> get _trips => controller.incomingTrips;

  /// Index of the request currently on screen, clamped to the live list.
  ///
  /// Reads the PageView's own position when it has one, falling back to the
  /// last reported page. Deliberately derived on demand instead of held in
  /// State: nothing here needs a rebuild when the driver swipes, which is what
  /// let the setState() call go away entirely.
  int get _visibleIndex {
    final int count = _trips.length;
    if (count == 0) return 0;
    final double? page =
        _pageController.hasClients ? _pageController.page : null;
    final int index = page?.round() ?? currentIndex;
    return index.clamp(0, count - 1);
  }

  /// Dismisses the accept-loading dialog, tolerating the case where its
  /// element is already gone.
  ///
  /// [ctx] is captured before an await and used after it, and accepting a ride
  /// replaces the whole route stack — so by the time this runs the dialog may
  /// have been torn down with everything else. Calling Navigator.of() on a
  /// defunct context throws, and the old code did exactly that from inside a
  /// catch block, where nothing was left to catch it.
  void _closeLoader(BuildContext? ctx) {
    if (ctx == null || !ctx.mounted) return;
    final navigator = Navigator.maybeOf(ctx);
    if (navigator != null && navigator.canPop()) navigator.pop();
  }


  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (_) {
        final trips = _trips;

        // Diagnostic for a reported debug-vs-release split: the ringtone
        // plays in release (confirming incomingTrips is populated and
        // update() ran) but no card appears — this print, present in both
        // build modes, is what tells us whether this widget's build() is
        // even being invoked with a non-empty list when that happens, or
        // whether the gap is elsewhere entirely.
        debugPrint(
          '[IncomingCard] build() trips=${trips.length} mounted=$mounted',
        );

        // No request pending — render nothing at all, leaving the home map
        // completely untouched. Nothing to pop or dismiss, because this was
        // never a route.
        if (trips.isEmpty) return const SizedBox.shrink();

        return Stack(
          children: [
              Positioned(
                top: 50,
                right: 20,
                child: CircleAvatar(
                  backgroundColor: ColorResources.whiteColor,
                  child: IconButton(
                    icon: Icon(Icons.close),
                    // Resolves which request to dismiss at tap time from the
                    // PageView's own live position, rather than from an index
                    // captured during build. That is what let this button stop
                    // needing a rebuild — and therefore stop needing setState —
                    // when the driver swipes between requests.
                    onPressed: () {
                      final current = _trips;
                      if (current.isEmpty) return;
                      controller.rejectTrip(current[_visibleIndex]);
                    },
                  ),
                ),
              ),

              Positioned(
                bottom: MediaQuery.of(context).padding.bottom,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 300,
                  // No ValueKey on the trip count any more. It forced a full
                  // PageView teardown/rebuild every time a request arrived or
                  // was dismissed, which with a State-owned controller risks
                  // attaching one ScrollController to two positions at once.
                  // PageView.builder already handles itemCount changing, and
                  // _safeIndex keeps the index in range.
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: trips.length,
                    // Plain assignment — deliberately not setState().
                    //
                    // onPageChanged is a scroll-settle callback, so it can fire
                    // after this State is gone: the card lives inside the home
                    // screen, and the ride flow replaces that screen wholesale
                    // (returnToExistingHome() → Get.offAllNamed) while a swipe
                    // may still be animating. Disposing _pageController here
                    // can itself trigger a final settle. A `mounted` guard
                    // narrows that window but doesn't close it, because
                    // `mounted` is still true while dispose() is running.
                    // Nothing in this widget needs to rebuild on a swipe — the
                    // close button resolves the visible request at tap time —
                    // so there is simply no setState to misfire.
                    onPageChanged: (index) => currentIndex = index,
                    itemBuilder: (context, index) {
                      return _rideCard(trips[index]);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _rideCard(NewBookingNearByModel trip) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColorResources.whiteColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: ColorResources.blackcolor, blurRadius: 12),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffF4C430),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 16),
                      SizedBox(width: 6),
                      Text("New Booking", style: PoppinsReguler),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    // Without this, a second tap while the first accept
                    // was still in flight (e.g. while the driver was
                    // waiting for the stuck dialog below to go away) fired
                    // a second, overlapping acceptRidesTrip() for the same
                    // booking.
                    if (_isAcceptingTrip) return;
                    _isAcceptingTrip = true;

                    // Captures the dialog's own BuildContext so it can be
                    // dismissed unambiguously via Navigator.of(dialogContext)
                    // regardless of what else happens to the navigation
                    // stack in between. The old code showed this dialog
                    // with plain showDialog() but dismissed it via
                    // `if (Get.isDialogOpen ?? false) Get.back();` — GetX's
                    // own dialog-open tracking, which is not guaranteed to
                    // reflect a dialog that was never opened through
                    // Get.dialog() in the first place. On top of that,
                    // acceptRidesTrip() navigates to the pickup screen via
                    // Get.offAndToNamed() on success *without* closing this
                    // dialog first, so it could easily be left floating on
                    // top of the new screen — looking exactly like a loading
                    // popup that never goes away, with the only way out
                    // being to back out and land back here to try again.
                    BuildContext? dialogContext;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dCtx) {
                        dialogContext = dCtx;
                        return const PremiumBlurLoader();
                      },
                    );

                    try {
                      final response = await controller.acceptRidesTrip(
                        context: context,
                        bookingId: trip.id.toString(),
                        trips: trip,
                      );

                      // acceptRidesTrip() itself calls Get.offAndToNamed()
                      // on success — which is Navigator.popAndPushNamed()
                      // under the hood, i.e. it pops whatever is currently
                      // on top (at that point, this loading dialog, not
                      // this screen) and pushes the pickup screen in its
                      // place. So on success the dialog is *already gone*
                      // by the time we get here — popping it again via
                      // dialogContext would pop the pickup screen that
                      // just replaced it instead, since Navigator.of()
                      // resolves to the same navigator either way. Only
                      // the non-success paths (busy/401/rejected/error —
                      // none of which navigate anywhere) still have the
                      // dialog sitting on top and actually need it closed
                      // here.
                      final body = response.body;
                      final code = body is Map ? body['code']?.toString() : null;
                      final alreadyNavigatedAway = code == '200';

                      if (!alreadyNavigatedAway) _closeLoader(dialogContext);
                    } catch (e) {
                      debugPrint('acceptRidesTrip Error: $e');
                      _closeLoader(dialogContext);
                    } finally {
                      _isAcceptingTrip = false;
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ColorResources.appColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          color: ColorResources.whiteColor,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Accept",
                          style: PoppinsReguler.copyWith(
                            color: ColorResources.whiteColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Was two unconstrained children in a spaceBetween Row —
                // each sized to its own content with nothing capping either
                // one, so a long customer name or a long trip-stats line
                // (a big fare, an unformatted multi-thousand-minute duration)
                // simply overflowed the card's right edge instead of
                // shrinking to fit. Expanded here / Flexible on the price
                // side below makes that overflow structurally impossible —
                // both sides now share the row's actual width instead of
                // each claiming as much as they want.
                Expanded(
                  child: Row(
                    children: [
                      // Was a hardcoded local asset — the model never parsed
                      // a customer image at all, so nothing the backend sent
                      // could ever have shown up here regardless.
                      // This card rebuilds on every poll (every ~3s, plus the
                      // 5s location heartbeat), and new-booking-list doesn't
                      // always have the rider's photo ready on the very first
                      // response for a freshly-created booking — it shows up
                      // a poll or two later. That's a genuine backend timing
                      // gap, not something fixable from here, but the abrupt
                      // placeholder→photo swap it produces can be smoothed:
                      // keyed on the actual image identity, so this only
                      // animates when the image genuinely changes rather than
                      // on every unrelated rebuild the poll causes.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: CircleAvatar(
                          key: ValueKey(trip.customerImage ?? 'placeholder'),
                          radius: 22,
                          backgroundImage:
                              (trip.customerImage != null && trip.customerImage!.isNotEmpty)
                                  ? NetworkImage(ApiConstants.imageurl + trip.customerImage!)
                                      as ImageProvider
                                  : const AssetImage("assets/images/profile.png"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        // Was a hardcoded "Customer" label for the same
                        // reason — the name was never parsed from the
                        // response.
                        Text(
                          trip.customerName?.isNotEmpty == true
                              ? trip.customerName!
                              : "Customer",
                          style: PoppinsBold.copyWith(
                            color: ColorResources.blackcolor,
                          ),
                        ),
                        // How far away the rider is — the driver's approach,
                        // which is what belongs beside their name. The trip's
                        // own length sits with the trip duration on the right,
                        // so the two pairs never get read as one figure.
                        // Labelled so the number reads as what it is — how far
                        // the driver is from the rider's pickup — rather than a
                        // bare figure next to the name.
                        Text(
                          "PICKUP DISTANCE",
                          style: PoppinsReguler.copyWith(
                            fontSize: 10,
                            letterSpacing: 0.4,
                            color: ColorResources.textColorForGrey,
                          ),
                        ),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 14),
                                Flexible(
                                  child: Text(
                                    // Zero means the backend gave no figure,
                                    // not that the rider is at the driver's
                                    // feet.
                                    (trip.driverToPickupDistance != null &&
                                            trip.driverToPickupDistance! > 0)
                                        ? "${trip.driverToPickupDistance!.toStringAsFixed(1)} km away"
                                        : "Nearby",
                                    style: PoppinsReguler,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Fare, now under a label — a bare "₹120" on the right gave
                    // no clue whether it was the fare, a distance, or a time.
                    if (trip.fare != null && trip.fare!.isNotEmpty) ...[
                      Text(
                        "FARE",
                        style: PoppinsReguler.copyWith(
                          fontSize: 10,
                          letterSpacing: 0.4,
                          color: ColorResources.textColorForGrey,
                        ),
                      ),
                      Text(
                        "₹${trip.fare}",
                        style: PoppinsBold.copyWith(
                          color: ColorResources.appColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                    // The trip itself: how long it is and how long it takes,
                    // under its own label so it isn't mistaken for the pickup
                    // distance on the left. Either half can be missing without
                    // leaving a stray separator.
                    if (trip.distance != null ||
                        (trip.time?.isNotEmpty ?? false)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          "TRIP",
                          style: PoppinsReguler.copyWith(
                            fontSize: 10,
                            letterSpacing: 0.4,
                            color: ColorResources.textColorForGrey,
                          ),
                        ),
                      ),
                      Text(
                        [
                          // Left out entirely rather than shown as "0.0 km";
                          // this line joins whatever it has, so an absent
                          // distance simply doesn't appear.
                          if (trip.distance != null && trip.distance! > 0)
                            "${trip.distance!.toStringAsFixed(1)} km",
                          // Now formatted through the shared duration helper
                          // rather than shown as the raw minute count the
                          // backend/model can still hand this widget — same
                          // "2000 min" problem the pickup screen's ETA had.
                          if (trip.time?.isNotEmpty ?? false)
                            formatMinutesLabel(trip.time) ?? trip.time!,
                        ].join("  •  "),
                        style: PoppinsReguler.copyWith(
                          color: ColorResources.blackcolor,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ColorResources.appColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 30,
                      color: Colors.blue.shade200,
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ColorResources.appColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pickup",
                        style: PoppinsReguler.copyWith(
                          color: ColorResources.textColorForGrey,
                        ),
                      ),
                      Text(trip.pickupAddress ?? "N/A", style: PoppinsReguler),

                      const SizedBox(height: 15),

                      Text(
                        "Drop",
                        style: PoppinsReguler.copyWith(
                          color: ColorResources.blackcolor,
                        ),
                      ),
                      Text(
                        trip.dropAddress ?? "N/A",
                        style: PoppinsReguler.copyWith(
                          color: ColorResources.textColorForGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
