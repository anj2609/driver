import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';

class CustomPopup extends StatelessWidget {
  final String status;
 
  const CustomPopup({Key? key, required this.status,}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('testing profile status ${status}');
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status == "pending"
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
              ),
              child: Icon(
                status == "pending"
                    ? Icons.hourglass_bottom_rounded
                    : Icons.close_rounded,
                size: 40,
                color: status == "pending" ? Colors.orange : Colors.red,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              status == "pending"
                  ? "Verification Under Review"
                  : "Verification Rejected",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            Text(
              status == "pending"
                  ? "Your submitted documents are currently under review."
                  : "Your documents were rejected. Please re-upload.",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 25),

            GestureDetector(
              onTap: () {
                log('loginnnnnn ${status}');
                Get.offAndToNamed(RouteHelper.getEditVehicleDocumentScreen(),
                arguments: {
                  "status":status.toString()

                }
                );
                //  Get.back();
              },
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: status == "pending"
                        ? [
                            ColorResources.primarycolor3,
                            ColorResources.blueeebutton,
                          ]
                        : [
                            ColorResources.primarycolor3,
                            ColorResources.blueeebutton,
                          ],
                  ),
                ),
                child: const Center(
                  child: Text(
                    "Check Status",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
