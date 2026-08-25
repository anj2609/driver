import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/model/qr_payment_model.dart';

class OnlinePaymentSheet extends StatefulWidget {
  final String bookingId;
  final QrPaymentData qrData;
  final HomeController homeController;

  const OnlinePaymentSheet({
    super.key,
    required this.bookingId,
    required this.qrData,
    required this.homeController,
  });

  @override
  State<OnlinePaymentSheet> createState() => _OnlinePaymentSheetState();
}

class _OnlinePaymentSheetState extends State<OnlinePaymentSheet> {

  bool _isCheckingPayment = false;
  bool isPaid = false;
  bool isRegenerating = false;
  bool _isPaymentConfirmed = false;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  /// Current QR data — can be updated on regeneration
  late QrPaymentData _currentQrData;

  @override
  void initState() {
    super.initState();
    _currentQrData = widget.qrData;
    _startCountdown();
    _startPolling();
  }



  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_currentQrData.closeBy != null && _currentQrData.closeBy! > 0) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        _currentQrData.closeBy! * 1000,
      );
      _remainingSeconds =
          expiry.difference(DateTime.now()).inSeconds.clamp(0, 86400);
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _checkPaymentStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || isPaid) return;
      _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_isCheckingPayment || isPaid) return;
    if (widget.bookingId.isEmpty) return;
    _isCheckingPayment = true;

    try {
      final paid = await widget.homeController.checkPaymentStatusById(
        bookingId: widget.bookingId,
      );

      if (!mounted) return;

      if (paid) {
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        isPaid = true;
        await _onPaymentConfirmed();
      }
    } catch (e) {
      debugPrint('payment status check error: $e');
    } finally {
      _isCheckingPayment = false;
    }
  }

  /// Regenerate QR code using booking ID
  Future<void> _regenerateQr() async {
    if (isRegenerating) return;

    setState(() => isRegenerating = true);

    try {
      final newQrData = await widget.homeController.generateOnlineQr(
        context: context,
        bookingId: widget.bookingId,
      );

      if (!mounted) return;

      if (newQrData != null) {
        // Stop old timers
        _pollTimer?.cancel();
        _countdownTimer?.cancel();

        setState(() {
          _currentQrData = newQrData;
          isRegenerating = false;
        });

        // Restart countdown and polling with new QR
        _startCountdown();
        _startPolling();
        // No toast — post-accept ride flow is toast-free by design; the
        // fresh QR itself is the visible confirmation.
      } else {
        setState(() => isRegenerating = false);
      }
    } catch (e) {
      debugPrint('Regenerate QR error: $e');
      if (mounted) {
        setState(() => isRegenerating = false);
      }
    }
  }



  Future<void> _onPaymentConfirmed() async {
    if (!mounted) return;

    // 1. Replace sheet content with thank-you view immediately
    setState(() => _isPaymentConfirmed = true);

    widget.homeController.resetRideState();
    widget.homeController.stopListeningBookings();

    // 2. Let the thank-you message display for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    // 3. Actually close the ride out — this is what generate-qr-payment /
    // check-payment-status never do on their own: they only settle the
    // *payment*, not the booking itself. Without this call the backend's
    // own ride record is left "ongoing" forever, so it keeps getting
    // offered back to this driver as new-booking-list re-matches the exact
    // rider they just finished with, and driverBookingActives() keeps
    // reading it as an active ride to resume — reported as "redirected to
    // nearby rides with the completed rider's card still showing".
    // rideCompletedMarked() is also what records this booking id in the
    // permanent completed-ids guard (see its own comments) that filters it
    // out of both of those reads for good, clears the remaining saved ride
    // state, and — on success — navigates home itself, so nothing further
    // is needed here on that front.
    if (mounted) {
      try {
        await widget.homeController.rideCompletedMarked(
          context: context,
          bookingId: widget.bookingId,
          source: 'online',
        );
      } catch (e) {
        debugPrint('Online payment: rideCompletedMarked failed: $e');
      }
    }

    // Fallback: if rideCompletedMarked() didn't get a chance to navigate
    // (e.g. it threw before reaching its own returnToExistingHome()), still
    // get the driver back to Home rather than leaving them stuck here.
    if (mounted) {
      widget.homeController.returnToExistingHome();
    }
  }

  Widget _buildThankYouView() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade600,
              size: 64,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Payment Successful!',
            style: PoppinsBold.copyWith(fontSize: 20, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Thank you for choosing us!',
            textAlign: TextAlign.center,
            style: PoppinsReguler.copyWith(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }



  String _formatTime(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPaymentConfirmed) return _buildThankYouView();

    final qr = _currentQrData;
    // Prefer the real, already-rendered QR image the backend sent — only
    // fall back to drawing one from upi_link when there's genuinely no
    // image to show. See QrPaymentData's own note on why these two can no
    // longer be treated as interchangeable.
    final bool hasImage = (qr.imageUrl ?? '').isNotEmpty;
    final bool hasUpiLink = (qr.upiLink ?? '').isNotEmpty;
    final hasQr = hasImage || hasUpiLink;

    // A bottom sheet only ever got a fraction of the screen — the amount
    // card, timer and instructions above/below it all ate into that same
    // limited height, on top of which this used to size purely off screen
    // *width*. On a short/small device that meant a QR square capped by a
    // width that never actually became the binding constraint, while the
    // sheet's own height was the real ceiling — reported as "very small
    // and not visible". A full page fixed the height ceiling, but the size
    // was still capped well below the screen's actual width (shortestSide
    // * 0.78, maxing out at 380) — still reading small on most phones.
    // Now driven by width first: the real available width inside this
    // card, after this page's own 20+20 padding and the card's own
    // 16+16 — filling essentially all of it — with a height-based ceiling
    // only to keep a short/landscape screen from overflowing.
    final Size screenSize = MediaQuery.of(context).size;
    final double widthBudget = screenSize.width - 72;
    final double heightBudget = screenSize.height * 0.55;
    final double qrSize =
        (widthBudget < heightBudget ? widthBudget : heightBudget)
            .clamp(260.0, 480.0);

    // Was isDismissible: false as a bottom sheet — a payment in flight
    // shouldn't disappear on a stray back-swipe. canPop: false is the full-
    // page equivalent; the explicit close (X) below is still the one way
    // out, same as before.
    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Online Payment',
                  style: PoppinsSemiBold.copyWith(
                    fontSize: 18,
                    color: ColorResources.blackcolor11,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.black54),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Amount card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: ColorResources.appColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    'Amount to Collect',
                    style: PoppinsReguler.copyWith(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹ ${qr.amount ?? "0"}',
                    style: PoppinsBold.copyWith(
                      fontSize: 30,
                      color: ColorResources.appColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // --- QR Code section ---
            if (hasQr) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Show the real payment QR the backend already rendered
                    // whenever there is one — this used to always run
                    // QrImageView(data: qr.imageUrl!) regardless, which
                    // doesn't display an image at all: it draws a brand new
                    // QR code that *encodes the image_url string itself*.
                    // Scanning that redrew-a-QR-of-a-URL result just opened
                    // that URL (Razorpay's own hosted page) in a browser,
                    // instead of showing the passenger the actual scannable
                    // payment QR. QrImageView is still correct — just only
                    // for upi_link, a plain link that's genuinely meant to
                    // be encoded into a QR the app draws itself.
                    if (hasImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          qr.imageUrl!,
                          width: qrSize,
                          height: qrSize,
                          // Was BoxFit.cover + Alignment.bottomCenter, on
                          // the assumption the source image had a header
                          // above a bottom-anchored QR — confirmed wrong:
                          // the crop was cutting into the actual code, not
                          // just whatever sits above it, which can make a
                          // QR fail to scan outright (finder patterns in
                          // the corners have to stay intact). contain
                          // guarantees the *whole* image renders, code
                          // included, at some cost to how much of the
                          // square it fills — a smaller-but-complete QR
                          // beats a bigger-but-broken one, and qrSize is
                          // already sized generously (up to 480) since the
                          // move to a full page, so "small" shouldn't be
                          // the complaint this time.
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return SizedBox(
                              width: qrSize,
                              height: qrSize,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Falls back to drawing the link as a QR rather
                            // than showing nothing, if the image itself
                            // fails to load but a link is also available.
                            if (hasUpiLink) {
                              return QrImageView(
                                data: qr.upiLink!,
                                version: QrVersions.auto,
                                size: qrSize,
                                backgroundColor: Colors.white,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                              );
                            }
                            return SizedBox(
                              width: qrSize,
                              height: qrSize,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 40,
                                  color: Colors.black26,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      QrImageView(
                        data: qr.upiLink!,
                        version: QrVersions.auto,
                        size: qrSize,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),

                    const SizedBox(height: 10),

                    // Timer row
                    if (_remainingSeconds > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 15,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Expires in ${_formatTime(_remainingSeconds)}',
                            style: PoppinsReguler.copyWith(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: isRegenerating ? null : _regenerateQr,
                              icon: isRegenerating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, size: 18),
                              label: Text(
                                isRegenerating ? 'Regenerating...' : 'Regenerate QR',
                                style: PoppinsSemiBold.copyWith(fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ColorResources.appColor,
                                side: BorderSide(color: ColorResources.appColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Show this QR to the passenger — they scan & pay with any UPI app',
                textAlign: TextAlign.center,
                style: PoppinsReguler.copyWith(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 18),
            ] else ...[
                // QR not generated — show regenerate option
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.qr_code_2,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'QR code not available',
                        style: PoppinsSemiBold.copyWith(
                          fontSize: 15,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap below to generate a new QR code for this booking.',
                        textAlign: TextAlign.center,
                        style: PoppinsReguler.copyWith(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isRegenerating ? null : _regenerateQr,
                          icon: isRegenerating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh, color: Colors.white),
                          label: Text(
                            isRegenerating ? 'Generating...' : 'Generate QR Code',
                            style: PoppinsSemiBold.copyWith(color: Colors.white, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorResources.appColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
              ],

            const SizedBox(height: 8),
          ],
          ),
        ),
      ),
      ),
    );
  }
}
