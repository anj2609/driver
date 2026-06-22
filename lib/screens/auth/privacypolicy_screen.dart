import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';


class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Get.find<ProfileController>()
          .privacyPolicy(context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: GetBuilder<ProfileController>(
          builder: (controller) {
            return Text(
              controller.privacyDetails?.data?.name ?? "Loading...",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
      ),

      body: GetBuilder<ProfileController>(
        builder: (controller) {

          if (controller.isCmsLoading) {
            return  Center(
              child: PremiumBlurLoader(),
            );
          }

          String details =
              controller.privacyDetails?.data?.details ?? "";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Html(
                data: details.isNotEmpty
                    ? "<p>$details</p>"
                    : "<p>No content available</p>",
                style: {
                  "body": Style(
                    fontSize: FontSize(14),
                    lineHeight: const LineHeight(1.6),
                    color: Colors.black87,
                  ),
                  "p": Style(
                    margin: Margins.only(bottom: 12),
                  ),
                },
              ),
            ),
          );
        },
      ),
    );
  }
}