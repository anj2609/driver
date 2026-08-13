import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/style.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/image_source_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? userProfileStatuss;
String? vehicleid;

//profileStatuss
class SocialDetailScreen extends StatefulWidget {
  const SocialDetailScreen({super.key});

  @override
  State<SocialDetailScreen> createState() => _SocialDetailScreenState();
}

class _SocialDetailScreenState extends State<SocialDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  int currentStep = 0;

  final TextEditingController dobController = TextEditingController();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  final TextEditingController modelCOntroller = TextEditingController();

  /// ================= VEHICLE VARIABLES =================

  String selectedVehicleType = "Car";

  String? selectedBrand;
  String? selectedModel;

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

  /// ---------------- IMAGE PICK FUNCTION ----------------
  Future<void> pickImage(bool isProfile) async {
    final File? picked = await pickImageFromSource(context);

    if (picked != null) {
      setState(() {
        if (isProfile) {
          profileImage = picked;
        } else {
          nidImage = picked;
        }
      });
    }
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
  @override
  void initState() {
    super.initState();
    Get.find<AuthController>().driverdocument(context: context);
    Get.find<AuthController>().vehicleType(context: context);
    getstatusdata();
    getsocilaData();
    // Was `currentStep = getStepFromStatus();` here, synchronously, at a
    // point where getStepFromStatus() switched on userProfileStatuss — an
    // in-memory global that's only fresh immediately after socailLogin()
    // just set it and navigated here in the same session. On a cold
    // restart (splash_screen.dart resuming into this screen with no
    // socailLogin() call in this process at all), that global is null, so
    // this always landed on step 0 regardless of how far the driver had
    // actually gotten. Moved into getstatusdata() below, using the
    // persisted status instead, after prefs have actually loaded.
  }

  Future<void> getstatusdata() async {
    final prefs = await SharedPreferences.getInstance();

    driverprofileStatus = prefs
        .getString(ApiConstants.isPersonalSavedStatus)
        .toString();
    isPersonalSaved = prefs.getBool(ApiConstants.isPersonalSaved) ?? false;
    isProfileCompleted =
        (driverprofileStatus?.toString() == "3") || isPersonalSaved;

    // Route arguments are already a UI step index here (socailLogin()
    // passes 0/1/2/3 directly, not a raw profile_status) — the freshest
    // signal right after a fresh login. Fall back to the persisted status
    // for a cold-restart resume, where there are no arguments at all.
    final args = Get.arguments;
    if (args is Map && args.containsKey('step')) {
      final argStep = int.tryParse(args['step'].toString());
      if (argStep != null) {
        setState(() => currentStep = argStep);
        return;
      }
    }

    setState(() => currentStep = getStepFromStatus());
  }

  Future<void> getsocilaData() async {
    emailController.text = ApiConstants.gmailAddres;
    fullNameController.text = ApiConstants.userName;
     Get.find<AuthController>().vehicalDocument(context: context);
  }

  int getStepFromStatus() {
    switch (driverprofileStatus?.toString()) {
      case "2":
        isPersonalSaved = false;
        return 0;

      case "3":
        isPersonalSaved = true;
        return 0;

      case "4":
        isPersonalSaved = false;
        return 1;

      case "5":
        isPersonalSaved = false;
        return 2;

      case "6":
        isPersonalSaved = false;
        return 3;

      default:
        isPersonalSaved = false;
        return 0;
    }
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
                      ? (isPersonalSaved
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
            buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget buildBottomButtons() {
    if (currentStep == 0 && isPersonalSaved) {
      return const SizedBox();
    }
    return _buildNextButton();
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
        color: const Color(0xFFF5F7FA),
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
                      ? const Color(0xFF123EBC)
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
                color: isCompleted ? const Color(0xFF123EBC) : Colors.grey.shade300,
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
                  ? FileImage(profileImage!) as ImageProvider
                  : (ApiConstants.profileImage.isNotEmpty
                        ? NetworkImage(ApiConstants.profileImage)
                        : null),

              child: profileImage == null && ApiConstants.profileImage.isEmpty
                  ? const Icon(Icons.camera_alt, size: 30)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 20),

        /// Full Name
        _buildTextFieldnameEmail(
          label: "Full Name",
          controller: fullNameController,
        ),

        const SizedBox(height: 15),

        _buildTextFieldnameEmail(label: "Email", controller: emailController),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
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
                child: const Text("Edit", style: TextStyle(color: Color(0xFF123EBC))),
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

  Widget _buildTextFieldnameEmail({
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



  /// ---------------- NEXT BUTTON ----------------
  Widget _buildNextButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      // Reactive to whichever submit call is relevant to the current
      // step, so this one button — used for every step in this flow —
      // disables + spins for the actual in-flight request instead of
      // staying tappable for the whole round trip.
      child: GetBuilder<AuthController>(
        builder: (authController) => CustomPrimaryButton(
          text: currentStep == 3 ? "Submit" : "Save & Continue",
          isLoading: (currentStep == 0 && authController.isSubmittingPersonalInfo) ||
              (currentStep == 1 && authController.isSubmittingVehicleInfo) ||
              (currentStep == 2 && authController.isSubmittingDriverDocs),
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

                  final response = await Get.find<AuthController>().fillPersonalInfoApi(
                    name: fullNameController.text.trim(),
                    email: emailController.text.trim(),
                    gender: selectedGender.toString(),
                    dob: dob,
                    profileimage: profileImage,
                    context: context,
                  );

                  // Was unconditional — advanced past personal details
                  // even when the save failed. fillPersonalInfoApi's own
                  // toast already told the driver why; only actually
                  // move on when it reports success.
                  final body = response.body;
                  final code = body is Map ? body['code']?.toString() : null;
                  if (code != '200') return;

                  setState(() {
                    isPersonalSaved = true;
                  });

                  return;
                }

                if (currentStep == 1) {
                  final controller = Get.find<AuthController>();

                  if (controller.selectedVehicleTypeId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please select vehicle type"),
                      ),
                    );
                    return;
                  }

                  if (brandController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Vehicle brand is required"),
                      ),
                    );
                    return;
                  }

                  if (modelCOntroller.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Vehicle model is required"),
                      ),
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

                  if (colorController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Vehicle color is required")),
                    );
                    return;
                  }

                  if (engineController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Engine number is required"),
                      ),
                    );
                    return;
                  }

                  if (chassisController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Chassis number is required"),
                      ),
                    );
                    return;
                  }

                  if (yearController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please select the manufacture year")),
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

                  final response = await Get.find<AuthController>()
                      .vehicaleInfoApi(
                        vehicalid: controller.selectedVehicleTypeId.toString(),
                        vehicalnumber: regController.text.trim(),
                        brand: brandController.text.trim(),
                        model: modelCOntroller.text.trim(),
                        color: colorController.text.trim(),
                        chassisnumber: chassisController.text.trim(),
                        enginenumber: engineController.text.trim(),
                        manufactureyear: yearController.text,
                        vehicaleimages: uploadedimages,
                        context: context,
                      );
                  // Same fix as the phone-registration flow's equivalent
                  // step (driverdetails_screen.dart) — a bare `== '200'`
                  // would silently strand the wizard on step 1 if this
                  // backend ever sends "code" as a JSON number here.
                  if (response.statusCode == 200 &&
                      response.body['code']?.toString() == '200') {
                   // Get.find<AuthController>().vehicaleInfoApi(
                    //  context: context,
                    //);
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
                        SnackBar(content: Text("Please upload an image for ${doc.name}")),
                      );
                      return;
                    }

                    if (doc.numberControllers.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Please enter the ${doc.name} number")),
                      );
                      return;
                    }

                    if (doc.isExpiry == true &&
                        doc.expiryControllers.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Please select the expiry date for ${doc.name}")),
                      );
                      return;
                    }
                  }

                  Response response = await controller.uploadVehicleDocument(
                    context: context,
                    documents: controller.vehicleDocumentList,
                  );

                  if (response.body["code"]?.toString() == "200") {
                    setState(() {
                      currentStep = 3;
                    });
                  }
                }

                if (currentStep == 3) {
                  Get.toNamed(RouteHelper.getsuccussfullLoader());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Form Submitted Successfully"),
                    ),
                  );
                }
              },
            ),
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
              return const Center(child: CircularProgressIndicator());
            }

            // Was previously an empty GridView with no explanation and no
            // way to recover if the vehicle-type fetch failed — the
            // driver would see a blank space and "Please select vehicle
            // type" kept firing on Save & Continue with no route forward.
            if (controller.vehicleTypeList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                    const SizedBox(height: 10),
                    const Text(
                      "Could not load vehicle types.\nPlease check your connection and retry.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          Get.find<AuthController>().vehicleType(context: context),
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              );
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
                        color: isSelected ? const Color(0xFF123EBC) : Colors.transparent,
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
                                    ? const Color(0xFF123EBC)
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
                                color: Color(0xFF123EBC),
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
        _buildTextField(
          label: "Please Enter Brand",
          controller: brandController,
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

        // colorController existed but was never attached to a field — the
        // Save & Continue call always sent color: "" instead. If the
        // backend requires a non-empty color, that alone fails every
        // vehicle-info save with the generic "Unable to save vehicle
        // information" error regardless of what else was filled in.
        _buildTextField2("Vehicle Color *", colorController),

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
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              // showDatePicker() (the old approach) opens on a year grid
              // but still lets the driver drill into a month and a day —
              // full date-picker behavior for a field that only ever
              // stores a year. YearPicker is the same widget Flutter's
              // date picker uses for its own year view, used here on its
              // own so there's no month/day step to land on at all.
              final firstYear = 1990;
              final lastYear = now.year;
              final initialYear = _selectedManufactureYear != null
                  ? int.tryParse(_selectedManufactureYear!) ?? lastYear
                  : lastYear;

              final pickedYear = await showDialog<int>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text("Select Manufacture Year"),
                    content: SizedBox(
                      width: 300,
                      height: 300,
                      child: YearPicker(
                        firstDate: DateTime(firstYear),
                        lastDate: DateTime(lastYear),
                        selectedDate: DateTime(initialYear),
                        currentDate: now,
                        onChanged: (DateTime dateTime) {
                          Navigator.of(dialogContext).pop(dateTime.year);
                        },
                      ),
                    ),
                  );
                },
              );
              if (pickedYear != null) {
                setState(() {
                  _selectedManufactureYear = pickedYear.toString();
                  yearController.text = pickedYear.toString();
                });
              }
            },
            child: AbsorbPointer(
              child: TextFormField(
                controller: yearController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Select year",
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
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
      firstDate: DateTime.now(),
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


  /////==================== Driver Document ================///////
  Widget _buildDriverDocumentStep() {
    return GetBuilder<AuthController>(
      builder: (controller) {
        if (controller.isDriverDocsFetching) {
          return const Center(child: CircularProgressIndicator());
        }

        // Was an unconditional spinner whenever the list was empty — with
        // no distinction between "still loading" and "the fetch already
        // failed" (isDriverDocsFetching resets to false either way), a
        // failed fetch here left the driver looking at a spinner
        // forever, with no retry. The phone-OTP flow's equivalent screen
        // already had this covered; this one didn't.
        if (controller.driverDocumentList.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  "Could not load document types.\nPlease go back and try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      Get.find<AuthController>().driverdocument(context: context),
                  child: const Text("Retry"),
                ),
              ],
            ),
          );
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
                            color: Colors.black.withValues(alpha: 0.06),
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
                // `controller` is this same GetBuilder's own builder param,
                // so this reflects isSubmittingDriverDocs live.
                child: CustomPrimaryButton(
                  text: "Save",
                  isLoading: controller.isSubmittingDriverDocs,
                  onTap: () async {
                    final controller = Get.find<AuthController>();

                    for (var doc in controller.driverDocumentList) {
                      if (doc.isRequired == true && doc.imageFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Please upload an image for ${doc.name}")),
                        );
                        return;
                      }

                      if (doc.numberController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Please enter the ${doc.name} number"),
                          ),
                        );
                        return;
                      }

                      if (doc.isExpiry == true &&
                          doc.expiryController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Please select the expiry date for ${doc.name}"),
                          ),
                        );
                        return;
                      }
                    }

                    Response response = await controller.uploadDocumentDriver(
                      context: context,
                      documents: controller.driverDocumentList,
                    );

                    if (response.body["code"]?.toString() == "200") {
                      Get.find<AuthController>().vehicleType(context: context);
                      setState(() {
                        userProfileStatuss = "4";
                        isPersonalSaved = false;
                        currentStep = 1;
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
        if (controller.isVehicleDocsFetching) {
          return const Center(child: CircularProgressIndicator());
        }

        // Same reasoning as the driver-documents step above — a failed
        // fetch used to leave a spinner on screen forever with no retry.
        if (controller.vehicleDocumentList.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  "Could not load document types.\nPlease go back and try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      Get.find<AuthController>().vehicalDocument(context: context),
                  child: const Text("Retry"),
                ),
              ],
            ),
          );
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
                            color: Colors.black.withValues(alpha: 0.06),
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
