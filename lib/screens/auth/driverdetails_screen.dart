import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

// String? driverprofileStatus;

class DetailsScreen extends StatefulWidget {
  DetailsScreen({Key? key}) : super(key: key);

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  int currentStep = 0;
  int _docCounter = 1;
  int _driverdocCounter = 1;
  final TextEditingController dobController = TextEditingController();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  final TextEditingController modelCOntroller = TextEditingController();

  /// ================= VEHICLE VARIABLES =================

  String selectedVehicleType = "Car";

  String? selectedBrand;
  String? selectedModel;

  Map<String, List<String>> brandModels = {
    "Toyota": ["Innova 2020", "Fortuner", "Etios"],
    "Honda": ["City", "Amaze"],
  };

  final TextEditingController registrationController = TextEditingController();
  final TextEditingController engineNumberController = TextEditingController();
  final TextEditingController chassisNumberController = TextEditingController();

  final TextEditingController taxValidController = TextEditingController();
  final TextEditingController fitnessValidController = TextEditingController();
  final TextEditingController insuranceValidController =
      TextEditingController();

  // Controllers
  final vehicleNumberController = TextEditingController();
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final colorController = TextEditingController();
  final chassisController = TextEditingController();
  final engineController = TextEditingController();
  final yearController = TextEditingController();
  String? _selectedManufactureYear;

  int? selectedVehicleTypeId;

  List<String> selectedImages = [];

  List<File> vehicleImages = [];

  File? registrationDoc;
  File? engineDoc;
  File? chassisDoc;

  File? profileImage;
  File? docImage;
  File? vehiclImage;
  File? nidImage;
  bool isPersonalSaved = false;
  bool isDriverDocSaved = false;
  late bool? isPersonalSavedsave;
  bool isProfileCompleted = false;

  bool isProfileFromApi = false;
  final prefs = SharedPreferences.getInstance();

  final ImagePicker picker = ImagePicker();

  /// ---------------- IMAGE PICK FUNCTION ----------------
  Future<void> pickImage(bool isProfile) async {
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      File file = File(picked.path);

      File? compressedFile = await compressTo50KB(file);

      if (compressedFile == null) {
        Get.snackbar("Error", "Image compression failed");
        return;
      }

      final size = await compressedFile.length();

      if (size > 50 * 1024) {
        Get.snackbar("Error", "Unable to compress under 50KB");
        return;
      }

      setState(() {
        if (isProfile) {
          profileImage = compressedFile;
        } else {
          nidImage = compressedFile;
        }
      });
    }
  }

  Future<File?> compressTo50KB(File file) async {
    final dir = await getTemporaryDirectory();

    final targetPath = p.join(
      dir.path,
      "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg",
    );

    int quality = 90;
    int minWidth = 800;
    int minHeight = 800;

    File? result;

    for (int i = 0; i < 8; i++) {
      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
      );

      if (compressed == null) return null;

      result = File(compressed.path);

      final size = await result.length();

      if (size <= 50 * 1024) {
        return result;
      }

      quality -= 10;
      minWidth = (minWidth * 0.8).toInt();
      minHeight = (minHeight * 0.8).toInt();
    }

    return result;
  }
  // ---------------- BRAND & MODEL ----------------

  // ---------------- DOCUMENT STATUS ----------------
  Map<String, bool> documentStatus = {
    "Registration Document Photo": false,
    "Engine Document Photo": true,
    "Chassis Document Photo": true,
  };
  String? selectedGender = "Male";
  // ---------------- DATE ----------------
  DateTime? taxValid;
  DateTime? fitnessValid;
  DateTime? insuranceValid;
  String? profilestatus;

  // ---------------- DATE PICKER ----------------
  Future<void> pickDate(Function(DateTime) onSelected) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      onSelected(picked);
    }
  }

  dynamic id, docNumer, expriydate;
  dynamic selectedVehicleId, vehicleDoNum, vehicleexpriydate;
  final FocusNode fullNameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _addNewDocument();
    _driverNewDocument();
    Get.find<AuthController>().driverdocument(context: context);
    Get.find<AuthController>().vehicalDocument(context: context);
    getstatusdata();
    currentStep = getStepFromStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        fullNameFocus.requestFocus();
      }
    });
  }

  void _addNewDocument() {
    documentss.add(DocumentModels(documentId: _docCounter.toString()));
    _docCounter++;
  }

  Future<void> getstatusdata() async {
    final prefs = await SharedPreferences.getInstance();

    driverprofileStatus = prefs
        .getString(ApiConstants.isPersonalSavedStatus)
        .toString();
    isPersonalSaved = prefs.getBool(ApiConstants.isPersonalSaved) ?? false;
    isProfileCompleted =
        (driverprofileStatus?.toString() == "3") || isPersonalSaved;

    setState(() {});
  }

  void _driverNewDocument() {
    driverDocument.add(
      DocumentModels(documentId: _driverdocCounter.toString()),
    );
    _driverdocCounter++;
  }

  int getStepFromStatus() {
    switch (driverprofileStatus?.toString()) {
      case "3":
        return 1;
      case "4":
        return 2;
      case "5":
        return 3;
      default:
        return 0;
    }
  }

  @override
  void dispose() {
    fullNameFocus.dispose();
    super.dispose();
  }

  /// ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildStepper(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: currentStep == 0
                      ? (((driverprofileStatus?.toString() == "3") ||
                                isPersonalSaved)
                            ? _buildDriverDocumentStep()
                            : _buildPersonalDetails())
                      : currentStep == 1
                      ? vehicleTypeGrid()
                      : currentStep == 2
                      ? _buildVehicleDocumentsStep()
                      : _buildPreviewStep(),
                ),
              ),
            ),

            //             Align(
            //   alignment: Alignment.bottomCenter,
            //   child: buildBottomButtons(),
            // ),
            currentStep == 0
                ? Column(
                    children: [
                      if (!((driverprofileStatus?.toString() == "3") ||
                          isPersonalSaved))
                        _buildSaveButton(),

                      if (((driverprofileStatus?.toString() == "3") ||
                              isPersonalSaved) &&
                          !isDriverDocSaved)
                        SizedBox(),

                      // _buildSaveButton(),
                      if (isDriverDocSaved) ...[
                        _buildSaveButton(),
                        const SizedBox(height: 10),
                        _buildNextButton(),
                      ],
                    ],
                  )
                : _buildNextButton(),
            // currentStep == 0
            //     ? Column(
            //         children: [
            //           if ((driverprofileStatus?.toString() == "3") &&
            //               isPersonalSaved &&
            //               !isDriverDocSaved)
            //             _buildSaveButton(),
            //           if (isDriverDocSaved) ...[
            //             _buildSaveButton(),
            //             const SizedBox(height: 10),
            //             _buildNextButton(),
            //           ],
            //         ],
            //       )
            //     : _buildNextButton(),
          ],
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
              decoration: InputDecoration(border: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------- APP BAR ----------------
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: const [
          Icon(Icons.arrow_back),
          Spacer(),
          Text(
            "Details",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Spacer(),
          SizedBox(width: 20),
        ],
      ),
    );
  }

  /// ---------------- STEPPER ----------------
  Widget _buildStepper() {
    List<String> steps = ["Personal", "Vehicle", "Document", "Preview"];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          /// STEP CIRCLE
          if (index.isEven) {
            int stepIndex = index ~/ 2;
            bool isActive = stepIndex == currentStep;
            bool isCompleted = stepIndex < currentStep;

            return Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isCompleted || isActive
                      ? Colors.blue
                      : Colors.grey.shade300,
                  child: Text(
                    "${stepIndex + 1}",
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted || isActive
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 60,
                  child: Text(
                    steps[stepIndex],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isCompleted || isActive
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            );
          }
          /// CONNECTING LINE
          else {
            int lineIndex = (index - 1) ~/ 2;
            bool isCompleted = lineIndex < currentStep;

            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                height: 2,
                color: isCompleted ? Colors.blue : Colors.grey.shade300,
              ),
            );
          }
        }),
      ),
    );
  }

  /// ---------------- PERSONAL FORM ----------------

  Widget _buildPersonalDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "Personal Details",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),

        /// Profile Image
        const Text("Take your photo *"),
        const SizedBox(height: 10),
        Center(
          child: GestureDetector(
            onTap: () => pickImage(true),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: profileImage != null
                  ? FileImage(profileImage!)
                  : null,
              child: profileImage == null
                  ? const Icon(Icons.camera_alt, size: 30)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 20),

        _buildTextField(label: "Full Name", controller: fullNameController),

        const SizedBox(height: 15),

        /// Adhaar Number
        _buildTextField(label: "Email", controller: emailController),
        const SizedBox(height: 15),
        // const SizedBox(height: 15),
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

              dobController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
            }
          },
          child: AbsorbPointer(
            child: buildTextField(
              dobController,
              icon: Icons.calendar_today_outlined,
            ),
          ),
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Gender",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Radio<String>(
                        value: "Male",
                        groupValue: selectedGender,
                        onChanged: (value) {
                          setState(() {
                            selectedGender = value;
                          });
                        },
                      ),
                      const Text("Male"),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Radio<String>(
                        value: "Female",
                        groupValue: selectedGender,
                        onChanged: (value) {
                          setState(() {
                            selectedGender = value;
                          });
                        },
                      ),
                      const Text("Female"),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Radio<String>(
                        value: "Other",
                        groupValue: selectedGender,
                        onChanged: (value) {
                          setState(() {
                            selectedGender = value;
                          });
                        },
                      ),
                      const Text("Other"),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  /////=============================== PreView =================================////////////////
  Widget _buildPreviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// PERSONAL DETAILS
          _previewCard(
            title: "Personal Details",
            onEdit: () => setState(() => currentStep = 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Profile Image
                if (profileImage != null)
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: FileImage(profileImage!),
                    ),
                  ),

                const SizedBox(height: 12),

                _previewRow("Full Name", fullNameController.text),
                _previewRow("Email", emailController.text),
                _previewRow("Date Of Birth", dobController.text),
                _previewRow("Gender", selectedGender ?? ""),

                const SizedBox(height: 10),

                /// Adhaar Image
                if (nidImage != null) ...[
                  const Text(
                    "Adhaar Image",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      nidImage!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          /// VEHICLE DETAILS
          _previewCard(
            title: "Vehicle Details",
            onEdit: () => setState(() => currentStep = 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Vehicle Images
                if (uploadedimages.isNotEmpty) ...[
                  const Text(
                    "Vehicle Photos",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: uploadedimages.map((img) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          img,
                          height: 90,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 15),
                ],

                _previewRow(
                  "Vehicle Type",
                  vehicleTypes2
                      .firstWhere(
                        (e) => e.id == selectedVehicleTypeId,
                        orElse: () =>
                            VehicleTypeModel2(id: 0, name: "", image: ""),
                      )
                      .name,
                ),

                _previewRow("Brand", selectedBrand ?? ""),
                _previewRow("Model", selectedModel ?? ""),
                _previewRow("Registration No", regController.text),
                _previewRow("Engine Number", engineController.text),
                _previewRow("Chassis Number", chassisController.text),
                _previewRow("Manufacture Year", yearController.text),
              ],
            ),
          ),
          const SizedBox(height: 20),

          /// DOCUMENT DETAILS
          _previewCard(
            title: "Vehicle Documents",
            onEdit: () => setState(() => currentStep = 2),
            child: Column(
              children: documentss.map((doc) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (doc.imageFile != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          doc.imageFile!,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),

                    const SizedBox(height: 8),

                    _previewRow("Document ID", doc.documentId),
                    _previewRow("Document Number", doc.numberController.text),
                    _previewRow("Expiry Date", doc.expiryController.text),

                    const Divider(height: 25),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  ////// ================== Preview card ============ ////////////

  Widget _previewCard({
    required String title,
    required Widget child,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: const Text("Edit", style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  //////////========================== Preview row ======================//////////////

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value.isEmpty ? "-" : value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// ---------------- TEXT FIELD ----------------
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextFormField(
      controller: controller,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "$label is required";
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// ============ save button =============================////////////////
  ///
  ///
  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: CustomPrimaryButton(
        text: "Save",
        onTap: () async {
          if (currentStep == 0) {
            if (!_formKey.currentState!.validate()) return;
            final prefs = await SharedPreferences.getInstance();

            if (profileImage == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Profile photo required")),
              );
              return;
            }

            if (selectedGender == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please select gender")),
              );
              return;
            }

            if (dobController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Date of birth required")),
              );
              return;
            }

            String dob = dobController.text.trim();

            await Get.find<AuthController>().fillPersonalInfoApi(
              name: fullNameController.text.trim(),
              email: emailController.text.trim(),
              gender: selectedGender.toString(),
              dob: dob,
              profileimage: profileImage,
              context: context,
            );
            Get.find<AuthController>().driverdocument(context: context);
            Get.find<AuthController>().vehicledoc(context: context);
            setState(() {
              isPersonalSaved = true;
              prefs.setBool(ApiConstants.isPersonalSaved, isPersonalSaved);
            });

            return;
          }

          /////uploadDocumentDriver

          if (currentStep == 1) {
            if (selectedVehicleTypeId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Select Vehicle Type")),
              );
              return;
            }
          }

          /// STEP 2 Save
          if (currentStep == 2) {
            // documents validation laga sakte ho yaha
          }

          /// Final Submit
          if (currentStep == 3) {
            Get.toNamed(RouteHelper.getsuccussfullLoader());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Form Submitted Successfully")),
            );
          }
        },
      ),
    );
  }

  /// ---------------- NEXT BUTTON ----------------
  Widget _buildNextButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: CustomPrimaryButton(
        text: "Save & Continue",
        onTap: () async {
          if (currentStep == 0) {
            if (!_formKey.currentState!.validate()) return;

            if (profileImage == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Profile photo required")),
              );
              return;
            }

            if (selectedGender == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please select gender")),
              );
              return;
            }

            if (dobController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Date of birth required")),
              );
              return;
            }

            String dob = dobController.text.trim();

            await Get.find<AuthController>().fillPersonalInfoApi(
              name: fullNameController.text.trim(),
              email: emailController.text.trim(),
              gender: selectedGender.toString(),
              dob: dob,
              profileimage: profileImage,
              context: context,
            );

            setState(() {
              isPersonalSaved = true;
            });

            return;
          }

          if (currentStep == 1) {
            final controller = Get.find<AuthController>();

            if (controller.selectedVehicleTypeId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please select vehicle type")),
              );
              return;
            }

            if (controller.selectedBrandName == null ||
                controller.selectedBrandName!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please select vehicle brand")),
              );
              return;
            }

            if (modelCOntroller.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Vehicle model is required")),
              );
              return;
            }

            if (regController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Registration number is required"),
                ),
              );
              return;
            }

            if (engineController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Engine number is required")),
              );
              return;
            }

            if (chassisController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Chassis number is required")),
              );
              return;
            }

            if (uploadedimages.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Please upload at least 1 vehicle image"),
                ),
              );
              return;
            }

            final response = await Get.find<AuthController>().vehicaleInfoApi(
              vehicalid: controller.selectedVehicleTypeId.toString(),
              vehicalnumber: regController.text.trim(),
              brand: controller.selectedBrandName.toString(),
              model: modelCOntroller.text.trim(),
              color: "",
              chassisnumber: chassisController.text.trim(),
              enginenumber: engineController.text.trim(),
              manufactureyear: yearController.text,
              vehicaleimages: uploadedimages,
              context: context,
            );
            if (response.statusCode == 200 && response.body['code'] == '200') {
              //Get.find<AuthController>().vehicaleInfoApi(context: context);
              setState(() {
                currentStep = 2;
              });
            }

            return;
          }

          if (currentStep == 2) {
            final controller = Get.find<AuthController>();

            for (var doc in controller.vehicleDocumentList) {
              if (doc.isRequired == true && doc.imageFiles == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${doc.name} image required")),
                );
                return;
              }

              if (doc.numberControllers.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${doc.name} number required")),
                );
                return;
              }

              if (doc.isExpiry == true &&
                  doc.expiryControllers.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${doc.name} expiry required")),
                );
                return;
              }
            }

            Response response = await controller.uploadVehicleDocument(
              context: context,
              documents: controller.vehicleDocumentList,
            );

            if (response.body["code"] == "200") {
              setState(() {
                currentStep = 3;
              });
            }
          }

          if (currentStep == 3) {
            Get.toNamed(RouteHelper.getsuccussfullLoader());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Form Submitted Successfully")),
            );
          }
        },
      ),
    );

    // Padding(
    //   padding: const EdgeInsets.all(16),
    //   child: CustomSecondaryButton(
    //     text: "Next",
    //     onTap: () {
    //       if (currentStep < 3) {
    //         setState(() {
    //           currentStep++;
    //         });
    //       }
    //     },
    //   ),
  }

  //////============== date picker ==============///////////////////

  Widget _buildDateField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          suffixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.blue),
          ),
        ),
        onTap: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
          );

          if (picked != null) {
            controller.text = "${picked.day}/${picked.month}/${picked.year}";
          }
        },
      ),
    );
  }

  List<VehicleTypeModel2> vehicleTypes2 = [
    VehicleTypeModel2(id: 1, name: "Car", image: "assets/images/car1.png"),
    VehicleTypeModel2(
      id: 2,
      name: "Motorcycle",
      image: "assets/images/pngegg (7) 1.png",
    ),
    VehicleTypeModel2(
      id: 3,
      name: "Scooter",
      image: "assets/images/pngegg (4) 1.png",
    ),
    VehicleTypeModel2(
      id: 4,
      name: "Micro-Van",
      image: "assets/images/carr4.png",
    ),
  ];

  /// ================= VEHICLE STEP =================
  Widget vehicleTypeGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Vehicle Type",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 10),
        GetBuilder<AuthController>(
          builder: (controller) {
            if (controller.isLoading) {
              return Center(child: PremiumBlurLoader());
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.vehicleTypeList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.7,
              ),
              itemBuilder: (context, index) {
                final vehicle = controller.vehicleTypeList[index];
                final bool isSelected =
                    controller.selectedVehicleTypeId == vehicle.id;
                // final String vehicalecolor = controller.vehicleTypes[index].;

                return InkWell(
                  onTap: () {
                    controller.selectVehicle(int.parse(vehicle.id.toString()));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.network(
                              vehicle.image != null && vehicle.image!.isNotEmpty
                                  ? "${ApiConstants.imageurl}${vehicle.image}"
                                  : "",
                              height: 40,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.directions_car,
                                  size: 40,
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              vehicle.name ?? "",
                              style: PoppinsMedium.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),

                        if (isSelected)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),

        // if (selectedVehicleTypeId == null)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            "Select vehicle type",
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
        SizedBox(height: 10),
        const Text(
          "Vehicle Brand *",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GetBuilder<AuthController>(
          builder: (controller) {
            return _buildDropdown(
              value: controller.selectedBrandName,
              hint: "Select Brand",
              items: controller.brands.map((e) => e["name"]!).toList(),
              onChanged: controller.selectBrand,
            );
          },
        ),

        const SizedBox(height: 16),

        /// Vehicle Model
        const Text(
          "Vehicle Model *",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildTextField(
          label: "Please Enter Model",
          controller: modelCOntroller,
        ),

        const SizedBox(height: 20),

        /// Upload Section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Upload Car Photo *",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Upload atleast 1 Picture",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: pickImage2,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      elevation: 0,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Add"),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              /// Image Preview
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(uploadedimages.length, (index) {
                  return Stack(
                    children: [
                      Container(
                        height: 100,
                        width: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: FileImage(uploadedimages[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: GestureDetector(
                          onTap: () => removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        _buildTextField2(
          "Registration Number (Car Number Plate) *",
          regController,
        ),

        _buildTextField2("Engine Number *", engineController),

        _buildTextField2("Chassis Number *", chassisController),

        _buildYearDropdown(),

        const SizedBox(height: 20),

        /// Upload Documents Section
        // _buildUploadSection(),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _buildYearDropdown() {
    final int currentYear = DateTime.now().year;
    final List<String> years = List.generate(
      currentYear - 1989,
      (i) => (currentYear - i).toString(),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Manufacture Year *",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedManufactureYear,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: "Select year",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: years
                .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedManufactureYear = value;
                yearController.text = value ?? "";
              });
            },
          ),
        ],
      ),
    );
  }

  final TextEditingController regController = TextEditingController();

  final TextEditingController taxDateController = TextEditingController();
  final TextEditingController fitnessDateController = TextEditingController();
  final TextEditingController insuranceDateController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> documents = [];

  Future<void> pickDocument(String title) async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        for (var file in pickedFiles) {
          documents.add({"title": title, "file": File(file.path)});
        }
      });
    }
  }

  void removeDocument(int index) {
    setState(() {
      documents.removeAt(index);
    });
  }

  Future<void> selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text = "${picked.day}/${picked.month}/${picked.year}";
    }
  }

  Widget _buildTextField2(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        controller.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {}); // icon show/hide refresh
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Upload Documents Photo *",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Upload atleast 1 Picture",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => pickDocument("Vehicle Document"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add"),
              ),
            ],
          ),

          const SizedBox(height: 15),

          /// Document List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xfff7f7f7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(documents[index]["file"]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Document Photo",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Completed",
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => removeDocument(index),
                      child: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateField2(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            readOnly: true,
            onTap: () => selectDate(controller),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String? selectedBrand2;
  String? selectedModel2;

  List<String> brands = ["Toyota", "Honda", "Hyundai"];
  Map<String, List<String>> models = {
    "Toyota": ["Innova Sedan 2026", "Fortuner", "Etios"],
    "Honda": ["City", "Amaze"],
    "Hyundai": ["i20", "Creta"],
  };

  List<File> uploadedimages = [];

  Future<void> pickImage2() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      if (uploadedimages.length + pickedFiles.length > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Maximum 5 images allowed")),
        );
        return;
      }

      setState(() {
        uploadedimages.addAll(pickedFiles.map((e) => File(e.path)).toList());
      });
    }
  }

  void removeImage(int index) {
    setState(() {
      uploadedimages.removeAt(index);
    });
  }

  List<DocumentModels> documentss = [];
  List<DocumentModels> driverDocument = [];

  ///driverDocument

  final ImagePicker _pickers = ImagePicker();

  Future<void> _pickImage(int index) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        documentss[index].imageFile = File(picked.path);
      });
    }
  }

  ///_driverimage driverDocument
  Future<void> _driverimage(int index) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        driverDocument[index].imageFile = File(picked.path);
      });
    }
  }

  Future<void> _pickDate(int index) async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      documentss[index].expiryController.text =
          "${date.year}-${date.month}-${date.day}";
    }
  }

  /////==================== Driver Document ================///////
  Widget _buildDriverDocumentStep() {
    return GetBuilder<AuthController>(
      builder: (controller) {
        if (controller.driverDocumentList.isEmpty) {
          return Center(child: PremiumBlurLoader());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Basic Driver Documents",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              /// 🔥 API Documents List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.driverDocumentList.length,
                itemBuilder: (context, index) {
                  final doc = controller.driverDocumentList[index];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        id = doc.id;
                        docNumer = doc.numberController.text;
                        expriydate = doc.expiryController;
                        docImage = doc.imageFile;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: RichText(
                              text: TextSpan(
                                text: doc.name ?? "",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                children: [
                                  if (doc.isRequired == true)
                                    const TextSpan(
                                      text: " *",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Align(
                          //   alignment: Alignment.centerLeft,
                          //   child: Text(
                          //     doc.name ?? "",
                          //     style: const TextStyle(fontWeight: FontWeight.w600),
                          //   ),
                          // ),
                          const SizedBox(height: 10),

                          /// IMAGE UPLOAD
                          GestureDetector(
                            onTap: () {
                              controller.pickDriverImage(index);
                            },
                            child: Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.grey.shade200,
                              ),
                              child: doc.imageFile != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        doc.imageFile!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.camera_alt, size: 35),
                                          SizedBox(height: 6),
                                          Text("Upload Document"),
                                        ],
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          /// Document Number
                          TextFormField(
                            controller: doc.numberController,
                            decoration: InputDecoration(
                              labelText: "Document Number",
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 12),

                          /// Expiry Date (Only if API says true)
                          if (doc.isExpiry == true)
                            TextFormField(
                              controller: doc.expiryController,
                              readOnly: true,
                              onTap: () {
                                controller.pickExpiryDate(index);
                              },
                              decoration: const InputDecoration(
                                labelText: "Expiry Date",
                                suffixIcon: Icon(Icons.calendar_today),
                                border: OutlineInputBorder(),
                              ),
                            ),

                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomPrimaryButton(
                  text: "Save",
                  onTap: () async {
                    final controller = Get.find<AuthController>();

                    for (var doc in controller.driverDocumentList) {
                      if (doc.isRequired == true && doc.imageFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("${doc.name} image required")),
                        );
                        return;
                      }

                      if (doc.numberController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("${doc.name} number required"),
                          ),
                        );
                        return;
                      }

                      if (doc.isExpiry == true &&
                          doc.expiryController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("${doc.name} expiry required"),
                          ),
                        );
                        return;
                      }
                    }

                    Response response = await controller.uploadDocumentDriver(
                      context: context,
                      documents: controller.driverDocumentList,
                    );

                    if (response.body["code"] == "200") {
                      Get.find<AuthController>().vehicleType(context: context);
                      setState(() {
                        isDriverDocSaved = true;
                        currentStep++;
                      });
                    }
                  },
                ),
              ),

              SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  //// =============== Document ========================
  Widget _buildVehicleDocumentsStep() {
    return GetBuilder<AuthController>(
      builder: (controller) {
        if (controller.vehicleDocumentList.isEmpty) {
          return Center(child: PremiumBlurLoader());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Vehicle Documents",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.vehicleDocumentList.length,
                itemBuilder: (context, index) {
                  final doc = controller.vehicleDocumentList[index];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedVehicleId = doc.id;
                        vehicleDoNum = doc.numberControllers;
                        vehicleexpriydate = doc.expiryControllers;
                        vehiclImage = doc.imageFiles;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: RichText(
                              text: TextSpan(
                                text: doc.name ?? "",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                children: [
                                  if (doc.isRequired == true)
                                    const TextSpan(
                                      text: " *",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          /// IMAGE UPLOAD
                          GestureDetector(
                            onTap: () {
                              controller.vehiclpickDriverImage(index);
                            },
                            child: Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.grey.shade200,
                              ),
                              child: doc.imageFiles != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        doc.imageFiles!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.camera_alt, size: 35),
                                          SizedBox(height: 6),
                                          Text("Upload Document"),
                                        ],
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          /// Document Number
                          TextFormField(
                            controller: doc.numberControllers,
                            decoration: InputDecoration(
                              labelText: "Document Number",
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 12),

                          if (doc.isExpiry == true)
                            TextFormField(
                              controller: doc.expiryControllers,
                              readOnly: true,
                              onTap: () {
                                controller.vehiclpickExpiryDate(index);
                              },
                              decoration: const InputDecoration(
                                labelText: "Expiry Date",
                                suffixIcon: Icon(Icons.calendar_today),
                                border: OutlineInputBorder(),
                              ),
                            ),

                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

class VehicleTypeModel2 {
  final int id;
  final String name;
  final String image;

  VehicleTypeModel2({
    required this.id,
    required this.name,
    required this.image,
  });
}

class DocumentModels {
  final String documentId;

  TextEditingController numberController = TextEditingController();
  TextEditingController expiryController = TextEditingController();
  File? imageFile;

  DocumentModels({required this.documentId});
}
