import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';

class AddBankDetailsScreen extends StatefulWidget {
  const AddBankDetailsScreen({super.key});

  @override
  State<AddBankDetailsScreen> createState() => _AddBankDetailsScreenState();
}

class _AddBankDetailsScreenState extends State<AddBankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController accountController = TextEditingController();
  final TextEditingController ifscController = TextEditingController();
  final TextEditingController bankController = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Get.find<ProfileController>().getBankInfoDetails(context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(title: const Text("Bank Details"), centerTitle: true),

      body: GetBuilder<ProfileController>(
        builder: (controller) {
          final isLoading = controller.isBankInfoLoading;
          final bankData = controller.bankDetailsData?.data;

          /// 1. LOADING STATE
          if (isLoading == true) {
            return Center(
              child: PremiumBlurLoader(),

              ///  CircularProgressIndicator()
            );
          }

          if (bankData != null) {
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: width * .05,
                vertical: 20,
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance,
                      size: 55,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 20),

                    bankTile(
                      "Account Holder",
                      bankData.accountHolderName ?? "",
                    ),
                    bankTile("Account Number", bankData.accountNumber ?? ""),
                    bankTile("IFSC Code", bankData.ifscCode ?? ""),
                    bankTile("Bank Name", bankData.bankName ?? ""),

                    const SizedBox(height: 20),

                    InkWell(
                      onTap: () {
                        controller.bankVerify(context: context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: bankData.bankVerified == 1
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          bankData.bankVerified == 1
                              ? "Verified"
                              : "Verification not Completed",
                          style: TextStyle(
                            color: bankData.bankVerified == 1
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          /// 3. NO DATA → SHOW ADD BANK FORM
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.05,
              vertical: 20,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: nameController,
                          label: "Account Holder Name",
                          icon: Icons.person_outline,
                        ),
                        _buildTextField(
                          controller: accountController,
                          label: "Account Number",
                          keyboardType: TextInputType.number,
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                        _buildTextField(
                          controller: ifscController,
                          label: "IFSC Code",
                          icon: Icons.code,
                        ),
                        _buildTextField(
                          controller: bankController,
                          label: "Bank Name",
                          icon: Icons.account_balance,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  CustomPrimaryDyanamicButton(
                    text: 'Add Bank Details',
                    onTap: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) =>  PremiumBlurLoader(),
                            );
                          await controller.addBankDetailsDriver(
                            context: context,
                            holdername: nameController.text.trim(),
                            accountNumber: accountController.text.trim(),
                            ifsccode: ifscController.text.trim(),
                            bankName: bankController.text.trim(),
                          );
                        } catch (e) {
                          debugPrint('addBankDetailsDriver Error: $e');
                        } finally {
                          if (Get.isDialogOpen ?? false) {
                            Get.back();
                          }
                        }
                        // controller.addBankDetailsDriver(
                        //   context: context,
                        //   holdername: nameController.text.trim(),
                        //   accountNumber: accountController.text.trim(),
                        //   ifsccode: ifscController.text.trim(),
                        //   bankName: bankController.text.trim(),
                        // );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget bankTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Flexible(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Enter $label";
          }
          return null;
        },
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          filled: true,
          fillColor: const Color(0xffF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
