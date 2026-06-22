import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';

class PaymentQrScreen extends StatefulWidget {

  final String bookingId;

  const PaymentQrScreen({
    Key? key,
    required this.bookingId,
  }) : super(key: key);

  @override
  State<PaymentQrScreen> createState() =>
      _PaymentQrScreenState();
}

class _PaymentQrScreenState
    extends State<PaymentQrScreen> {

  Timer? timer;

  final controller=
      Get.find<ProfileController>();


  @override
  void initState() {
    super.initState();

    /// every 5 sec payment verify check
    timer=Timer.periodic(
      Duration(seconds:5),
      (value){
        verifyPaymentStatus();
      },
    );
  }


  verifyPaymentStatus() async {

    await controller.verifyQrCodePayment(
      bookingId: widget.bookingId,
      context: context
    );

    if(controller.isPaymentVerifying==true){

      timer?.cancel();

      Get.snackbar(
        "Success",
        "Payment Received",
      );

      Get.back();

    }

  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text("Scan To Pay"),
      ),

      body: GetBuilder<ProfileController>(
        builder: (controller) {

          return Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [

                Text(
                  "Customer Scan This QR",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(height:30),

                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),

                  child: Image.network(
                    controller.qrImage,
                    height:250,
                    width:250,
                    fit:BoxFit.contain,
                  ),
                ),

                SizedBox(height:30),

                CircularProgressIndicator(),

                SizedBox(height:15),

                Text(
                  "Waiting for payment verification...",
                )

              ],
            ),
          );
        },
      ),
    );
  }
}