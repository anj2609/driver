import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Get.find<ProfileController>().aboutUsApi(context: context);
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
              controller.aboutUsDetails?.data?.name ?? "Loading...",
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
            return  Center(child: PremiumBlurLoader());
          }

          String details = controller.aboutUsDetails?.data?.details ?? "";

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
                  "p": Style(margin: Margins.only(bottom: 12)),
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
