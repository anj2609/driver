import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/style.dart';

class TermsAndConditionScreen extends StatelessWidget {
  const TermsAndConditionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
        title: Text(
          "Terms & Conditions",
          style: PoppinsSemiBold.copyWith(
            fontSize: 17,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _intro(),
            _section(
              "1. Service Availability",
              "NRIDE provides a technology platform connecting passengers with independent driver partners. NRIDE does not own or operate transportation vehicles unless specifically stated.",
            ),
            _sectionWithBullets(
              "2. User Responsibilities",
              "Users shall:",
              [
                "Provide accurate information",
                "Maintain respectful conduct",
                "Not misuse the platform",
                "Comply with applicable laws",
              ],
            ),
            _sectionWithBullets(
              "3. Driver Partner Responsibilities",
              "Drivers shall:",
              [
                "Maintain valid licenses and permits",
                "Ensure vehicle fitness and insurance",
                "Follow all transport regulations",
                "Maintain professional behavior",
              ],
            ),
            _section(
              "4. Payments",
              "Users agree to pay applicable fares, taxes, tolls, parking charges, and service fees associated with the ride.",
            ),
            _section(
              "5. Limitation of Liability",
              "NRIDE shall not be liable for delays, traffic conditions, weather disruptions, vehicle breakdowns, or circumstances beyond reasonable control.",
            ),
            _section(
              "6. Modifications",
              "NRIDE reserves the right to modify services, pricing, and policies at any time without prior notice.",
            ),
            _section(
              "7. Governing Law",
              "These terms shall be governed by the laws of India and subject to the jurisdiction of courts in Agartala, Tripura.",
            ),
            _heading("8. Refund Policy"),
            _body(
              "NRIDE strives to ensure a fair and transparent refund process.",
            ),
            _subSectionWithBullets(
              "Eligible Refund Cases",
              "Refunds may be considered in cases such as:",
              [
                "Payment deducted but ride not assigned",
                "Duplicate payment",
                "Technical system error",
                "Incorrect fare charged due to system malfunction",
              ],
            ),
            _subSectionWithBullets(
              "Non-Refundable Situations",
              "Refunds will generally not be provided for:",
              [
                "User no-show",
                "Late cancellations beyond permitted limits",
                "Delays caused by traffic, weather, or force majeure",
                "Disputes arising after successful ride completion without supporting evidence",
              ],
            ),
            _subSection(
              "Refund Timeline",
              "Approved refunds shall normally be processed within 7 to 10 business days through the original payment method.",
            ),
            _subSection(
              "Refund Decision",
              "NRIDE reserves the right to review each refund request and make the final determination based on available records and evidence.",
            ),
            _sectionWithBullets(
              "9. Driver Partner Terms",
              "Key points:",
              [
                "Minimum age 18 years",
                "Valid Driving License mandatory",
                "Vehicle RC, Insurance, Fitness Certificate, Pollution Certificate mandatory",
                "Police verification may be required",
                "Driver responsible for vehicle maintenance",
                "Driver responsible for traffic violations and challans",
                "NRIDE may suspend accounts for misconduct, fraud, intoxication, overcharging, harassment, or safety violations",
                "Driver commission and payout schedules subject to company policy",
                "Driver must not solicit off-platform rides from NRIDE customers",
              ],
            ),
            _heading("10. Cancellation Policy"),
            _subSectionWithBullets(
              "Passenger Cancellation",
              null,
              [
                "Within 2 minutes: No charge",
                "After driver assignment: Nominal cancellation fee may apply",
                "Repeated cancellations may lead to account restrictions",
              ],
            ),
            _subSectionWithBullets(
              "Driver Cancellation",
              null,
              [
                "Drivers should avoid unnecessary cancellations",
                "Repeated cancellations may affect ratings and platform access",
              ],
            ),
            _subSection(
              "No Show",
              "If passenger is unavailable after reasonable waiting time, driver may cancel and applicable charges may be levied.",
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorResources.blueeebutton.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorResources.blueeebutton.withOpacity(0.25),
        ),
      ),
      child: Text(
        "By accessing or using NRIDE services, users agree to the following terms:",
        style: PoppinsMedium.copyWith(
          fontSize: 14,
          color: ColorResources.blueeebutton,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _heading(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: PoppinsSemiBold.copyWith(
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _body(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: PoppinsMedium.copyWith(
          fontSize: 13.5,
          color: const Color(0xFF444444),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _section(String title, String content) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(title),
          _body(content),
        ],
      ),
    );
  }

  Widget _sectionWithBullets(
      String title, String? intro, List<String> bullets) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(title),
          if (intro != null) _body(intro),
          ...bullets.map((b) => _bullet(b)),
        ],
      ),
    );
  }

  Widget _subSection(String title, String content) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              title,
              style: PoppinsSemiBold.copyWith(
                fontSize: 13.5,
                color: Colors.black87,
              ),
            ),
          ),
          _body(content),
        ],
      ),
    );
  }

  Widget _subSectionWithBullets(
      String title, String? intro, List<String> bullets) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              title,
              style: PoppinsSemiBold.copyWith(
                fontSize: 13.5,
                color: Colors.black87,
              ),
            ),
          ),
          if (intro != null) _body(intro),
          ...bullets.map((b) => _bullet(b)),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: ColorResources.blueeebutton,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: PoppinsMedium.copyWith(
                fontSize: 13.5,
                color: const Color(0xFF444444),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
