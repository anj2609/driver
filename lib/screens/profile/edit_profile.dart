import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';
import 'package:myridedriverapp/widgets/profileimage_full.dart';

class EditProfileScreen extends StatefulWidget {
  EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final controller = Get.find<ProfileController>();

  final TextEditingController nameController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();

  final TextEditingController dobController = TextEditingController();

  String selectedGender = "Male";
  List<String> genderList = ["Male", "Female", "Other"];

  File? selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  void showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Camera"),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    Get.find<ProfileController>().fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorResources.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: ColorResources.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
        title: Text(
          "Edit Personal Info",
          style: PoppinsMedium.copyWith(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Obx(() {
            if (controller.isLoading.value) {
              return Center(child: PremiumBlurLoader());
            }
            nameController.text = controller.nameController.text;
            emailController.text = controller.emailController.text;
            phoneController.text = controller.phoneController.text;
            dobController.text = controller.dobController.text;

            // Gender safe set
            String apiGender = controller.genderController.text;

            if (genderList.contains(apiGender)) {
              selectedGender = apiGender;
            } else {
              selectedGender = "Male"; // default fallback
            }
            // DateTime date = DateTime.parse(controller.dobController.text);
            // dobController.text = DateFormat('yyyy-MM-dd').format(date);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 25),

                /// Profile Image
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          String imageUrl = controller.profileimagee ?? "";

                          if (selectedImage != null || imageUrl.isNotEmpty) {
                            Get.to(
                              () => FullImageView(
                                file: selectedImage,
                                imageUrl:
                                    '${ApiConstants.imageurl}${controller.profileimagee}',
                              ),
                            );
                          }
                        },

                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: selectedImage != null
                              ? FileImage(selectedImage!)
                              : (controller.profileimagee != null &&
                                    controller.profileimagee!.isNotEmpty)
                              ? NetworkImage(
                                  "${ApiConstants.imageurl}${controller.profileimagee}",
                                )
                              : null,
                          child:
                              selectedImage == null &&
                                  (controller.profileimagee == null ||
                                      controller.profileimagee!.isEmpty)
                              ? Icon(Icons.person, size: 50, color: Colors.grey)
                              : null,
                        ),
                      ),

                      /// ✏️ EDIT BUTTON
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: showImageSourceDialog,
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                buildLabel("Full Name"),
                buildTextField(nameController),

                const SizedBox(height: 22),

                buildLabel("Email"),
                buildTextField(emailController, icon: Icons.mail_outline),

                const SizedBox(height: 22),

                buildLabel("Phone Number"),
                controller.phoneController.text == ''
                    ? Container(
                        height: 55,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFF1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            const Text("🇮🇳", style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            const Icon(Icons.keyboard_arrow_down, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                //readOnly: true,
                                controller: phoneController,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        height: 55,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFF1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            const Text("🇮🇳", style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            const Icon(Icons.keyboard_arrow_down, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                readOnly: true,
                                controller: phoneController,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                // Container(
                //   height: 55,
                //   padding: const EdgeInsets.symmetric(horizontal: 15),
                //   decoration: BoxDecoration(
                //     color: const Color(0xFFEFEFF1),
                //     borderRadius: BorderRadius.circular(15),
                //   ),
                //   child: Row(
                //     children: [
                //       const Text("🇮🇳", style: TextStyle(fontSize: 18)),
                //       const SizedBox(width: 6),
                //       const Icon(Icons.keyboard_arrow_down, size: 18),
                //       const SizedBox(width: 10),
                //       Expanded(
                //         child: TextField(
                //           readOnly: true,
                //           controller: phoneController,
                //           decoration: const InputDecoration(
                //             border: InputBorder.none,
                //           ),
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                const SizedBox(height: 22),

                buildLabel("Gender"),
                Container(
                  height: 55,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFF1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedGender,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: genderList
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, style: PoppinsMedium),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedGender = value!;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                buildLabel("Date of Birth"),
                GestureDetector(
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );

                    if (pickedDate != null) {
                      dobController.text =
                          "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";

                      dobController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(pickedDate);
                    }
                  },
                  child: AbsorbPointer(
                    child: buildTextField(
                      dobController,
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                CustomPrimaryButton(
                  text: "Continue",
                  onTap: () async {
                    ////// ======= api =========//////

                    // Get.find<ProfileController>().updatePersonalInfoApi(
                    //   name: nameController.text.trim(),
                    //   email: emailController.text.trim(),
                    //   gender: selectedGender.toString(),
                    //   dob: dobController.text.toString(),
                    //   phonenumber: phoneController.text.trim(),
                    //   profileimage: selectedImage,
                    //   oldProfile: controller.profileimagee.toString(),
                    //   context: context,
                    // );
                    try {
                     showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) =>  PremiumBlurLoader(),
                            );

                      await Get.find<ProfileController>().updatePersonalInfoApi(
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        gender: selectedGender.toString(),
                        dob: dobController.text.toString(),
                        phonenumber: phoneController.text.trim(),
                        profileimage: selectedImage,
                        oldProfile: controller.profileimagee.toString(),
                        context: context,
                      );
                    } catch (e) {
                      debugPrint('updatePersonalInfoApi Error: $e');
                    } finally {
                      if (Get.isDialogOpen ?? false) {
                        Get.back();
                      }
                    }
                  },
                ),

                const SizedBox(height: 25),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: PoppinsMedium.copyWith(fontSize: 14, color: Colors.black),
      ),
    );
  }

  Widget buildTextField(TextEditingController controller, {IconData? icon}) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.grey),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }
}
