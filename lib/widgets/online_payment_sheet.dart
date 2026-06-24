import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/model/qr_payment_model.dart';
import 'package:myridedriverapp/widgets/toaster_animation.dart';

class OnlinePaymentSheet extends StatefulWidget {
  final String bookingId;
  final QrPaymentData qrData;

  const OnlinePaymentSheet({
    super.key,
    required this.bookingId,
    required this.qrData,
  });

  @override
  State<OnlinePaymentSheet> createState() => _OnlinePaymentSheetState();
}

class _OnlinePaymentSheetState extends State<OnlinePaymentSheet> {
  late Razorpay _razorpay;
  bool isVerifying = false;
  bool isPaid = false;
  bool isRegenerating = false;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  /// Current QR data — can be updated on regeneration
  late QrPaymentData _currentQrData;

  @override
  void initState() {
    super.initState();
    _currentQrData = widget.qrData;
    _initRazorpay();
    _startCountdown();
    _startPolling();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
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
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || isPaid) return;
      await _checkPayment(silent: true);
    });
  }

  Future<void> _checkPayment({bool silent = false}) async {
    if (isVerifying || isPaid) return;

    setState(() => isVerifying = true);

    final controller = Get.find<HomeController>();
    final verified = await controller.verifyOnlinePayment(
      context: context,
      bookingId: widget.bookingId,
      qrId: _currentQrData.qrId ?? '',
    );

    if (!mounted) return;

    if (verified) {
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        isPaid = true;
        isVerifying = false;
      });
      // Brief success display then complete ride
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) await _completeRide();
    } else {
      setState(() => isVerifying = false);
      if (!silent) {
        AnimatedTopToast.show(
          context: context,
          message: 'Payment not received yet. Please try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.info_rounded,
        );
      }
    }
  }

  /// Regenerate QR code using booking ID
  Future<void> _regenerateQr() async {
    if (isRegenerating) return;

    setState(() => isRegenerating = true);

    try {
      final controller = Get.find<HomeController>();
      final newQrData = await controller.generateOnlineQr(
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

        AnimatedTopToast.show(
          context: context,
          message: 'QR code regenerated successfully.',
          backgroundColor: ColorResources.appColor,
          icon: Icons.check_circle_rounded,
        );
      } else {
        setState(() => isRegenerating = false);
        AnimatedTopToast.show(
          context: context,
          message: 'Failed to regenerate QR. Please try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
    } catch (e) {
      debugPrint('Regenerate QR error: $e');
      if (mounted) {
        setState(() => isRegenerating = false);
        AnimatedTopToast.show(
          context: context,
          message: 'Something went wrong. Please try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('Razorpay success: ${response.paymentId}');
    if (!mounted) return;
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() => isPaid = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) await _completeRide();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    AnimatedTopToast.show(
      context: context,
      message: response.message ?? 'Payment failed. Please try again.',
      backgroundColor: ColorResources.redbuttoncolor,
      icon: Icons.error_rounded,
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet: ${response.walletName}');
  }

  Future<void> _completeRide() async {
    if (!mounted) return;
    Navigator.of(context).pop();
    await Get.find<HomeController>().rideCompletedMarked(
      context: Get.context!,
      bookingId: widget.bookingId,
      source: 'online',
    );
  }

  void _openRazorpay() {
    // Amount in paise — use paymentAmount first, fallback to parsing amount string
    int amountInPaise = _currentQrData.paymentAmount ?? 0;
    if (amountInPaise == 0 && _currentQrData.amount != null) {
      final parsed = double.tryParse(_currentQrData.amount!);
      if (parsed != null) amountInPaise = (parsed * 100).toInt();
    }

    if (amountInPaise <= 0) {
      AnimatedTopToast.show(
        context: context,
        message: 'Invalid payment amount. Please regenerate QR.',
        backgroundColor: ColorResources.redbuttoncolor,
        icon: Icons.error_rounded,
      );
      return;
    }

    final options = {
      'key': ApiConstants.razorpayKeyId,
      'amount': amountInPaise,
      'name': 'My Ride',
      'description': 'Booking #${widget.bookingId}',
      'theme': {'color': '#1A237E'},
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
      AnimatedTopToast.show(
        context: context,
        message: 'Could not open Razorpay. Please try QR payment.',
        backgroundColor: ColorResources.redbuttoncolor,
        icon: Icons.error_rounded,
      );
    }
  }

  String _formatTime(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _razorpay.clear();
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

            // --- Success state ---
            if (isPaid) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 72,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Payment Received!',
                      style: PoppinsSemiBold.copyWith(
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Completing your ride...',
                      style: PoppinsReguler.copyWith(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
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
                            Text(
                              'QR Expired',
                              style: PoppinsReguler.copyWith(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Regenerate button when expired
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

                // Verify Payment button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isVerifying ? null : () => _checkPayment(silent: false),
                    icon: isVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_outlined, color: Colors.white),
                    label: Text(
                      isVerifying ? 'Checking...' : 'Verify Payment',
                      style: PoppinsSemiBold.copyWith(color: Colors.white, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorResources.appColor,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // OR divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: PoppinsReguler.copyWith(
                          color: Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 14),
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

                // OR divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: PoppinsReguler.copyWith(
                          color: Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 14),
              ],

              // Pay with Razorpay button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _openRazorpay,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/razorpay_logo.png',
                        height: 20,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.payment,
                          color: Colors.black87,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Pay with Razorpay',
                        style: PoppinsSemiBold.copyWith(
                          color: Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
