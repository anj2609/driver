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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle — matches other bottom sheets
          Container(
            height: 5,
            width: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 32),
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
    final hasQr = (qr.imageUrl ?? '').isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              height: 5,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 16),

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
                    QrImageView(
                      data: qr.imageUrl!,
                      version: QrVersions.auto,
                      size: 210,
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
    );
  }
}
