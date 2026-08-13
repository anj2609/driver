import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/model/acceptride_details_model.dart';
import 'package:myridedriverapp/model/qr_payment_model.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';
import 'package:myridedriverapp/widgets/online_payment_sheet.dart';
import 'package:myridedriverapp/widgets/toaster_animation.dart';

class PaymentScreen extends StatefulWidget {
  final AcceptRideModel? acceptData;
  PaymentScreen({super.key, this.acceptData});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  /// 0 = none, 1 = online, 2 = cash, 3 = wallet
  int _selectedMethod = 0;
  bool _isProcessing = false;

  String get _bookingId =>
      widget.acceptData?.data?.bookingId?.toString() ?? '';

  String get _paymentMode =>
      (widget.acceptData?.data?.paymentMode ?? '').toLowerCase();

  String get _totalFare =>
      widget.acceptData?.data?.totalFare?.toString() ?? '0';

  /// Whether the customer chose online payment
  bool get _isOnlinePayment => _paymentMode == 'online';

  @override
  void initState() {
    super.initState();
    // Auto-select based on customer's chosen payment mode
    if (_isOnlinePayment) {
      _selectedMethod = 1;
    } else {
      _selectedMethod = 2; // default cash
    }
  }

  /// Dismisses a loader dialog, tolerating a context whose element is already
  /// gone.
  ///
  /// Every handler below captures the dialog's context before an await and
  /// uses it after — and completing a ride runs returnToExistingHome(), which
  /// replaces the entire route stack via Get.offAllNamed(). The captured
  /// context is defunct by then, and Navigator.of() on a defunct context
  /// throws. The old code did that from inside `finally`, so the throw
  /// skipped the pop entirely and left this barrier-blocking loader stranded
  /// on top of the new Home screen — the spinner that never goes away after a
  /// ride completes.
  void _closeLoader(BuildContext? ctx) {
    if (ctx == null || !ctx.mounted) return;
    final navigator = Navigator.maybeOf(ctx);
    if (navigator != null && navigator.canPop()) navigator.pop();
  }

  Future<void> _handleOnlinePayment() async {
    if (_isProcessing || _bookingId.isEmpty) return;

    setState(() => _isProcessing = true);

    // Captures the loader dialog's own BuildContext so it can be dismissed
    // unambiguously via Navigator.of(dialogContext), regardless of what
    // else happens to the navigation stack in between — same fix already
    // applied to the Accept-ride dialog in trip_request_screen.dart.
    // Get.dialog() pushes onto GetX's own dialog/overlay stack, which is
    // *separate* from the main route stack Get.offAllNamed()/Get.offAll()
    // operate on. generateOnlineQr() itself doesn't navigate, but a
    // completed payment inside OnlinePaymentSheet below eventually calls
    // rideCompletedMarked(), which replaces the whole route stack with
    // Home via returnToExistingHome() — that call does not know or care
    // that this loader dialog is still open, so relying on
    // `Get.isDialogOpen`/`Get.back()` after the fact could pop the wrong
    // thing (or, since Get.offAllNamed() never touches the dialog stack at
    // all, leave this barrier-blocking loader stranded on top of the new
    // Home screen forever — indistinguishable from an infinite loading
    // state).
    BuildContext? dialogContext;
    try {
      final controller = Get.find<HomeController>();

      // Show loader
      Get.dialog(
        Builder(
          builder: (dCtx) {
            dialogContext = dCtx;
            return const Center(child: PremiumBlurLoader());
          },
        ),
        barrierDismissible: false,
      );

      final QrPaymentData? qrData = await controller.generateOnlineQr(
        context: context,
        bookingId: _bookingId,
      );

      _closeLoader(dialogContext);

      if (qrData == null) {
        // generateOnlineQr() returns null for every non-success — a rejected
        // request, a malformed body, a dropped connection — and deliberately
        // shows nothing itself ("post-accept ride flow is toast-free"). That
        // left the driver tapping "Proceed Online Payment", watching a
        // spinner, and then getting nothing at all with no reason given.
        // There is no affordance to retry other than tapping again, so the
        // failure has to be visible.
        if (context.mounted) {
          AnimatedTopToast.show(
            context: context,
            message: "Couldn't create the payment QR. Please check your "
                "connection and try again.",
            backgroundColor: ColorResources.redbuttoncolor,
            icon: Icons.error_rounded,
          );
        }
        return;
      }

      if (context.mounted) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: false,
          builder: (_) => OnlinePaymentSheet(
            bookingId: _bookingId,
            qrData: qrData,
            homeController: controller,
          ),
        );
      }
    } catch (e) {
      _closeLoader(dialogContext);
      debugPrint('Online payment error: $e');
      if (context.mounted) {
        AnimatedTopToast.show(
          context: context,
          message: "Couldn't start the online payment. Please try again.",
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCashPayment() async {
    if (_isProcessing || _bookingId.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Confirm Cash Payment',
            style: PoppinsSemiBold.copyWith(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_outlined, size: 52, color: Colors.green.shade600),
            const SizedBox(height: 12),
            Text(
              'Collect ₹$_totalFare in cash from the passenger.',
              textAlign: TextAlign.center,
              style: PoppinsReguler.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Have you received the cash?',
              textAlign: TextAlign.center,
              style: PoppinsSemiBold.copyWith(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('No', style: PoppinsSemiBold.copyWith(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Yes, Received',
                style: PoppinsSemiBold.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    // Same fix as _handleOnlinePayment above: capture the loader dialog's
    // own BuildContext so it can be dismissed via Navigator.of(dialogContext)
    // regardless of what else happens to the navigation stack. This is the
    // exact case that mattered most — on success, rideCompletedMarked()
    // calls returnToExistingHome(), which replaces the *entire* route
    // stack with Home via Get.offAllNamed(). That call has no idea this
    // loader dialog (pushed via Get.dialog(), onto GetX's separate
    // dialog/overlay stack) is still open, and never closes it — so the
    // old code's `if (Get.isDialogOpen ?? false) Get.back()` in finally
    // was racing a dialog stack that offAllNamed() never touched at all.
    // The barrier is non-dismissible, so once stranded there's no way out
    // except restarting the app — indistinguishable from an infinite
    // loading state, which is exactly what was reported.
    BuildContext? dialogContext;
    try {
      Get.dialog(
        Builder(
          builder: (dCtx) {
            dialogContext = dCtx;
            return const Center(child: PremiumBlurLoader());
          },
        ),
        barrierDismissible: false,
      );

      await Get.find<HomeController>().rideCompletedMarked(
        context: context,
        bookingId: _bookingId,
        source: 'offline',
      );
    } catch (e) {
      debugPrint('Cash payment error: $e');
    } finally {
      _closeLoader(dialogContext);
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleWalletPayment() async {
    if (_isProcessing || _bookingId.isEmpty) return;

    setState(() => _isProcessing = true);

    // Same dialog-stranding fix as _handleCashPayment/_handleOnlinePayment
    // above.
    BuildContext? dialogContext;
    try {
      Get.dialog(
        Builder(
          builder: (dCtx) {
            dialogContext = dCtx;
            return const Center(child: PremiumBlurLoader());
          },
        ),
        barrierDismissible: false,
      );

      await Get.find<HomeController>().rideCompletedMarked(
        context: context,
        bookingId: _bookingId,
        source: 'wallet',
      );
    } catch (e) {
      debugPrint('Wallet payment error: $e');
    } finally {
      _closeLoader(dialogContext);
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: InkWell(
          onTap: () => Get.back(),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text("Payment Method",
            style: PoppinsSemiBold.copyWith(color: Colors.black)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey,
              child: Icon(Icons.help_outline, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.05,
          vertical: size.height * 0.02,
        ),
        child: Column(
          children: [
            /// HEADER CARD — shows amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: ColorResources.gradientVibrant,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Payment Method',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Fare: ₹$_totalFare',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customer chose: ${_isOnlinePayment ? "Online" : "Cash"} payment',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            SizedBox(height: size.height * 0.03),

            /// ONLINE PAYMENT OPTION
            _buildPaymentOption(
              methodId: 1,
              icon: Icons.account_balance_wallet_outlined,
              iconColor: ColorResources.appColor,
              title: 'Online Payment',
              subtitle: _isOnlinePayment ? 'Customer selected this method' : 'UPI / Card payment via QR',
              isEnabled: _isOnlinePayment,
            ),

            SizedBox(height: size.height * 0.015),

            /// CASH PAYMENT OPTION
            _buildPaymentOption(
              methodId: 2,
              icon: Icons.payments_outlined,
              iconColor: Colors.green.shade600,
              title: 'Cash Payment',
              subtitle: !_isOnlinePayment ? 'Customer selected this method' : 'Collect cash from passenger',
              isEnabled: !_isOnlinePayment,
            ),

            SizedBox(height: size.height * 0.015),

            /// WALLET PAYMENT OPTION
            _buildPaymentOption(
              methodId: 3,
              icon: Icons.account_balance,
              iconColor: Colors.orange.shade600,
              title: 'Wallet Payment',
              subtitle: 'Deduct from customer wallet',
              isEnabled: false, // wallet is typically controlled by backend
            ),

            const Spacer(),

            /// CONFIRM BUTTON
            if (_selectedMethod > 0)
              _isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : CustomPrimaryButton(
                      text: _selectedMethod == 1
                          ? 'Proceed Online Payment'
                          : _selectedMethod == 2
                              ? 'Confirm Cash Received'
                              : 'Pay via Wallet',
                      onTap: () {
                        switch (_selectedMethod) {
                          case 1:
                            _handleOnlinePayment();
                            break;
                          case 2:
                            _handleCashPayment();
                            break;
                          case 3:
                            _handleWalletPayment();
                            break;
                        }
                      },
                    ),

            SizedBox(height: size.height * 0.03),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required int methodId,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isEnabled,
  }) {
    final bool isSelected = _selectedMethod == methodId;
    final bool canSelect = isEnabled;

    return GestureDetector(
      onTap: canSelect
          ? () {
              setState(() => _selectedMethod = methodId);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: !canSelect
              ? Colors.grey.shade200
              : isSelected
                  ? iconColor.withValues(alpha: 0.08)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !canSelect
                ? Colors.grey.shade300
                : isSelected
                    ? iconColor
                    : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Opacity(
          opacity: canSelect ? 1.0 : 0.5,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: canSelect
                      ? iconColor.withValues(alpha: 0.12)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: canSelect ? iconColor : Colors.grey, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PoppinsSemiBold.copyWith(
                        fontSize: 15,
                        color: canSelect ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !canSelect ? 'Not available for this ride' : subtitle,
                      style: PoppinsReguler.copyWith(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected && canSelect)
                Icon(Icons.check_circle, color: iconColor, size: 24)
              else if (!canSelect)
                Icon(Icons.block, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
