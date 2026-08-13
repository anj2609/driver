import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
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

  // The controller's own list is the source of truth — widget.trips is only
  // the snapshot at the moment this screen was first pushed. Reading from
  // the controller here means the "Accept"/"X" buttons and any new booking
  // the poll adds while this screen is open are reflected immediately,
  // instead of the screen staying frozen on its original snapshot.
  List<NewBookingNearByModel> get _trips => controller.incomingTrips;

  int get _safeIndex =>
      _trips.isEmpty ? 0 : currentIndex.clamp(0, _trips.length - 1);

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

        // No request pending — render nothing at all, leaving the home map
        // completely untouched. Nothing to pop or dismiss, because this was
        // never a route.
        if (trips.isEmpty) return const SizedBox.shrink();

        final safeIndex = _safeIndex;
        final trip = trips[safeIndex];

        return Stack(
          children: [
              Positioned(
                top: 50,
                right: 20,
                child: CircleAvatar(
                  backgroundColor: ColorResources.whiteColor,
                  child: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      controller.rejectTrip(trip);
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
                  // Re-keying on the trip list forces the PageView (and its
                  // internal controller/scroll position) to reset cleanly
                  // whenever a request is rejected or a new one arrives,
                  // instead of holding onto a stale page index.
                  child: PageView.builder(
                    key: ValueKey(trips.length),
                    controller: PageController(
                      viewportFraction: 0.92,
                      initialPage: safeIndex,
                    ),
                    itemCount: trips.length,
                    onPageChanged: (index) {
                      // onPageChanged is a scroll-settle callback, so it can
                      // still fire after this State is gone — the card now
                      // lives inside the home screen, and the ride flow
                      // replaces that screen wholesale (returnToExistingHome()
                      // → Get.offAllNamed) while a swipe may still be
                      // animating. Back when this was its own route it stayed
                      // mounted for its whole life and the guard wasn't
                      // needed; now it is.
                      if (!mounted) return;
                      setState(() => currentIndex = index);
                    },
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Was a hardcoded local asset — the model never parsed
                    // a customer image at all, so nothing the backend sent
                    // could ever have shown up here regardless.
                    CircleAvatar(
                      radius: 22,
                      backgroundImage:
                          (trip.customerImage != null && trip.customerImage!.isNotEmpty)
                              ? NetworkImage(ApiConstants.imageurl + trip.customerImage!)
                                  as ImageProvider
                              : const AssetImage("assets/images/profile.png"),
                    ),
                    const SizedBox(width: 10),
                    Column(
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
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14),
                            Text(
                              "${trip.distance?.toStringAsFixed(2) ?? 0} km",
                              style: PoppinsReguler,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Fare was never shown at all — same root cause, the
                    // model had nowhere to hold it.
                    if (trip.fare != null && trip.fare!.isNotEmpty)
                      Text(
                        "₹${trip.fare}",
                        style: PoppinsBold.copyWith(
                          color: ColorResources.appColor,
                          fontSize: 16,
                        ),
                      ),
                    // Same gap as fare — the model never parsed a time
                    // field either, so there was nothing to show here
                    // regardless of what the backend sent.
                    if (trip.time != null && trip.time!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          trip.time!,
                          style: PoppinsReguler.copyWith(
                            color: ColorResources.textColorForGrey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
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
