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

  Future<void> _handleOnlinePayment() async {
    if (_isProcessing || _bookingId.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final controller = Get.find<HomeController>();

      // Show loader
      Get.dialog(
        const Center(child: PremiumBlurLoader()),
        barrierDismissible: false,
      );

      final QrPaymentData? qrData = await controller.generateOnlineQr(
        context: context,
        bookingId: _bookingId,
      );

      // Dismiss loader
      if (Get.isDialogOpen ?? false) Get.back();

      if (qrData != null && context.mounted) {
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
      if (Get.isDialogOpen ?? false) Get.back();
      debugPrint('Online payment error: $e');
      if (context.mounted) {
        AnimatedTopToast.show(
          context: context,
          message: 'Something went wrong. Please try again.',
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

    try {
      Get.dialog(
        const Center(child: PremiumBlurLoader()),
        barrierDismissible: false,
      );

      await Get.find<HomeController>().rideCompletedMarked(
        context: context,
        bookingId: _bookingId,
        source: 'offline',
      );
    } catch (e) {
      debugPrint('Cash payment error: $e');
      if (context.mounted) {
        AnimatedTopToast.show(
          context: context,
          message: 'Failed to complete ride. Please try again.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
    } finally {
      if (Get.isDialogOpen ?? false) Get.back();
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleWalletPayment() async {
    if (_isProcessing || _bookingId.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      Get.dialog(
        const Center(child: PremiumBlurLoader()),
        barrierDismissible: false,
      );

      await Get.find<HomeController>().rideCompletedMarked(
        context: context,
        bookingId: _bookingId,
        source: 'wallet',
      );
    } catch (e) {
      debugPrint('Wallet payment error: $e');
      if (context.mounted) {
        AnimatedTopToast.show(
          context: context,
          message: 'Wallet payment failed. Please try another method.',
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
    } finally {
      if (Get.isDialogOpen ?? false) Get.back();
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
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
              iconColor: const Color(0xFF4A90E2),
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
