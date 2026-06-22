import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

class EarnWithMyRideScreen extends StatefulWidget {
  EarnWithMyRideScreen({Key? key}) : super(key: key);

  @override
  State<EarnWithMyRideScreen> createState() => _EarnWithMyRideScreenState();
}

class _EarnWithMyRideScreenState extends State<EarnWithMyRideScreen> {
  final _formKey = GlobalKey<FormState>();
  // Stored Values
  String selectedCountry = "India";
  String selectedDivision = "Tripura";
  int? selectedCityId;
  String? selecteDivision;

  String? selectedCityName;
  String referralCode = "";

  // Only Tripura Division
  final List<String> divisions = ["Tripura"];

  final Map<String, List<Map<String, dynamic>>> divisionWiseCities = {
    "Tripura": [
      {"id": 1, "name": "Agartala"},
      {"id": 2, "name": "Udaipur"},
      {"id": 3, "name": "Dharmanagar"},
      {"id": 4, "name": "Kailasahar"},
      {"id": 5, "name": "Belonia"},
      {"id": 6, "name": "Khowai"},
      {"id": 7, "name": "Ambassa"},
      {"id": 8, "name": "Kamalpur"},
      {"id": 9, "name": "Sabroom"},
      {"id": 10, "name": "Sonamura"},
      {"id": 11, "name": "Amarpur"},
      {"id": 12, "name": "Teliamura"},
      {"id": 13, "name": "Bishalgarh"},
      {"id": 14, "name": "Melaghar"},
      {"id": 15, "name": "Ranirbazar"},
      {"id": 16, "name": "Jirania"},
      {"id": 17, "name": "Panisagar"},
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorResources.backgroundColor,
      appBar: AppBar(
        backgroundColor: ColorResources.backgroundColor,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () {
              Get.back();
            },
            child: Container(
              decoration: BoxDecoration(
                color: ColorResources.whiteColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back, color: ColorResources.blackcolor),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Image
                Center(
                  child: Image.asset(
                    "assets/images/group.png", // apni image yaha lagana
                    height: 150,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Address with My Ride",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                // const SizedBox(height: 6),

                // const Text(
                //   "Decide When, Where, and how you want to earn.",
                //   style: TextStyle(color: Colors.grey),
                // ),
                const SizedBox(height: 25),

                /// COUNTRY DROPDOWN
                const Text("Country *"),
                const SizedBox(height: 6),
                _buildDropdown(
                  value: selectedCountry,
                  items: ["India"],
                  onChanged: (value) {
                    setState(() {
                      selectedCountry = value!;
                    });
                  },
                ),

                const SizedBox(height: 16),

                /// DIVISION DROPDOWN
                const Text("Division *"),
                const SizedBox(height: 6),
                _buildDropdown(
                  value: selectedDivision,
                  hint: "Select Division",
                  items: divisions,
                  onChanged: (value) {
                    setState(() {
                      selectedDivision = value!;
                      selectedCityId = null;
                      selectedCityName = null;
                    });
                  },
                  validator: (value) =>
                      value == null ? "Please select division" : null,
                ),

                const SizedBox(height: 16),
                const Text("City *"),
                const SizedBox(height: 6),

                DropdownButtonFormField<String>(
                  value: selectedCityName,
                  decoration: InputDecoration(
                    hintText: "Select City",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: (divisionWiseCities[selectedDivision] ?? [])
                      .map(
                        (city) => DropdownMenuItem<String>(
                          value: city["name"],
                          child: Text(city["name"]),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCityName = value;

                      // ✅ ID store karna
                      selectedCityId = divisionWiseCities[selectedDivision]
                          ?.firstWhere((city) => city["name"] == value)["id"];

                      print("Selected City ID: $selectedCityId");
                    });
                  },
                  validator: (value) =>
                      value == null ? "Please select city" : null,
                ),

                // _buildDropdown(
                //   value: selectedDivision,
                //   items: divisions,
                //   onChanged: (value) {
                //     setState(() {
                //       selectedDivision = value!;
                //       selectedCityId = null;
                //       selectedCityName = null;
                //       print('testing selctedddd |||||| ${selectedCityName}');
                //     });
                //   },
                // ),
                const SizedBox(height: 16),

                /// REFERRAL CODE
                const Text("Referral Code"),
                const SizedBox(height: 6),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: "Code",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    referralCode = value; // store in string
                  },
                ),

                const SizedBox(height: 25),

                /// CONTINUE BUTTON
                CustomPrimaryButton(
                  text: "Continue",
                  onTap: () async {
                    if (_formKey.currentState!.validate()) {
                      if (selectedCityId == null) {
                        Get.snackbar(
                          "Error",
                          "Please select city",
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      // Get.find<AuthController>().driveraddAddress(
                      //   context: context,
                      //   country: selectedCountry,
                      //   devision: selectedDivision,
                      //   city: selectedCityName.toString(),
                      // );
                      try {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => PremiumBlurLoader(),
                        );

                        await Get.find<AuthController>().driveraddAddress(
                          context: context,
                          country: selectedCountry,
                          devision: selectedDivision,
                          city: selectedCityName.toString(),
                        );
                        if (Get.isDialogOpen ?? false) {
                          Get.back();
                        }

                        FocusManager.instance.primaryFocus?.unfocus();
                      } catch (e) {
                        debugPrint('driveraddAddress Error: $e');
                      } finally {
                        if (Get.isDialogOpen ?? false) {
                          Get.back();
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Reusable Dropdown Widget
  Widget _buildDropdown({
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? value,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: items.isEmpty ? null : onChanged,
    );
  }
}
