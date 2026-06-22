import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/model/acceptride_details_model.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';

class PaymentScreen extends StatefulWidget {
  final AcceptRideModel? acceptData;
  PaymentScreen({super.key, this.acceptData});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

bool isOfflineSelected = false;

class _PaymentScreenState extends State<PaymentScreen> {
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
          onTap: () {
            Get.back();
          },
          child: Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text("Payment Method", style: TextStyle(color: Colors.black)),
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
                children: const [
                  Text(
                    'Choose Payment Method',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Select your preferred payment option',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            SizedBox(height: size.height * 0.04),

            /// ONLINE PAYMENT DISABLED
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Opacity(
                opacity: 0.6,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.grey,
                        size: 30,
                      ),
                    ),

                    const SizedBox(width: 16),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Online Payment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),

                          SizedBox(height: 4),

                          Text(
                            'Currently unavailable',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    /// DISABLED BUTTON
                    IgnorePointer(
                      ignoring: true,
                      child: Switch(
                        value: false,
                        onChanged: null,
                        activeColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: size.height * 0.025),

            GestureDetector(
              onTap: () {
                setState(() {
                  isOfflineSelected = true;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isOfflineSelected
                      ? Colors.green.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isOfflineSelected
                        ? Colors.green
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: isOfflineSelected ? Colors.green : Colors.black54,
                    ),
                    const SizedBox(width: 12),

                    const Expanded(
                      child: Text(
                        "Cash Payment",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    if (isOfflineSelected)
                      const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// SHOW BUTTON ONLY AFTER OFFLINE SELECT
            if (isOfflineSelected)
              CustomPrimaryButton(
                text: "Cash",

                onTap: () {
                  Get.find<HomeController>().rideCompletedMarked(
                    context: context,
                    bookingId: widget.acceptData!.data!.bookingId.toString(),
                  );
                },
              ),

            // CustomPrimaryButton(
            //                     text: "Cash",

            //                     //text: "Complete My Ride",
            //                     onTap: () {
            //                      Get.find<HomeController>().rideCompletedMarked(
            //                         context: context,
            //                         bookingId: widget.acceptData!.data!.bookingId
            //                             .toString(),
            //                       );
            //                     },
            //                   ),
            SizedBox(height: size.height * 0.02),
          ],
        ),
      ),
    );
  }
}
