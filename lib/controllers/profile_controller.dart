import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myridedriverapp/model/aboutus_model.dart';
import 'package:myridedriverapp/model/arningactivitylist_model.dart';
import 'package:myridedriverapp/model/bankdetals_model.dart';
import 'package:myridedriverapp/model/coupon_model.dart';
import 'package:myridedriverapp/model/earning_model.dart';
import 'package:myridedriverapp/model/notification_model.dart';
import 'package:myridedriverapp/model/privacy_model.dart';
import 'package:myridedriverapp/model/profileModel.dart';
import 'package:myridedriverapp/model/termsandcondtion_model.dart';
import 'package:myridedriverapp/model/trinpdetails_model.dart';
import 'package:myridedriverapp/model/vehicledetails_model.dart';
import 'package:myridedriverapp/repository/profile_repo.dart';
import 'package:myridedriverapp/screens/profile/genrateqr_code_screen.dart';
import 'package:myridedriverapp/widgets/toaster_animation.dart';

class ProfileController extends GetxController implements GetxService {
  final ProfiileRepo profileRepo;

  ProfileController({required this.profileRepo});
  RxBool isLoading = false.obs;
  bool isCmsLoading = false;
  bool isNotificationLoading = false;
  Rx<ProfileModels> profile = ProfileModels().obs;

  final evController = TextEditingController();
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final genderController = TextEditingController();
  final dobController = TextEditingController();
  PrivacyModel? privacyDetails;
  AboutUsModel? aboutUsDetails;
  Rx<File?> profileImage = Rx<File?>(null);
  String? profileimagee;

  /// The profile photo as a ready-to-load URL, or null when there is none.
  ///
  /// Every avatar used to build `imageurl + profileimagee` by hand, which
  /// breaks the moment the backend returns an absolute URL (it becomes
  /// `https://host/https://host/...`) or the literal string "null". After a
  /// text-only profile edit the server can return the photo in a different
  /// form than the get-profile that first loaded it, which is what made the
  /// avatar vanish on Continue. Resolving it in one place — absolute URLs used
  /// as-is, blank/"null" treated as no photo, everything else prefixed —
  /// keeps every screen consistent regardless of which form comes back.
  String? get resolvedProfileImageUrl {
    final raw = profileimagee?.trim();
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${ApiConstants.imageurl}$raw';
  }
  String? userName;
  String? emailAddress;
  String selectedCategory = "ride";
  List<String> categories = ["ride"];
  bool isPromoDataLoading = false;
  TermAndConditionModel? termsansConditionsDetails;
  NotificationModel? notificationModel;
  List<NotificationDetailsModel> notificationList = [];
  VehicleModel? vehicleModel;
  VehicleDetailsData? vehicleData;
  bool isVehicleLoading = false;
  List<String> vehicleImages = [];
  bool isEarningLoading = false;

  bool isCouponHistoryLoading = false;
  bool hasCouponHistoryError = false;
  List<CouponHistoryItem> couponHistoryList = [];

  EarningModels? earningModel;

  List<BarChartGroupData> barGroups = [];
  double totalEarnings = 0.0;
  String selectedType = "weekly";

  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();
  String qrImage = "";
  bool isQrLoading = false;
  bool isPaymentVerifying = false;
  bool isEarningActivityLoading = false;
  bool isTripDetailsLoading = false;
  List earningActivityList = [];
  TripDetailsModel? tripDetailsModel;
  bool isBankInfoLoading = false;
  List<BankDetailListData> bankDetails = [];
  BankDetailModel? bankDetailsData;

  ///BankDetailModel

  static const String _keyName = 'cached_profile_name';
  static const String _keyEmail = 'cached_profile_email';
  static const String _keyPhone = 'cached_profile_phone';
  static const String _keyImage = 'cached_profile_image';
  static const String _keyGender = 'cached_profile_gender';
  static const String _keyDob = 'cached_profile_dob';

  @override
  void onInit() {
    super.onInit();
    _loadCachedProfile();
    fetchProfile();
  }

  Future<void> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedName = prefs.getString(_keyName) ?? "";
    final cachedEmail = prefs.getString(_keyEmail) ?? "";
    final cachedPhone = prefs.getString(_keyPhone) ?? "";
    final cachedImage = prefs.getString(_keyImage) ?? "";
    final cachedGender = prefs.getString(_keyGender) ?? "";
    final cachedDob = prefs.getString(_keyDob) ?? "";

    if (cachedName.isNotEmpty) {
      nameController.text = cachedName;
      emailController.text = cachedEmail;
      phoneController.text = cachedPhone;
      genderController.text = cachedGender;
      dobController.text = cachedDob;
      profileimagee = cachedImage;
      userName = cachedName;
      emailAddress = cachedEmail;
      update();
    }
  }

  Future<void> _saveProfileToCache(ProfileData userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, userData.name ?? "");
    await prefs.setString(_keyEmail, userData.email ?? "");
    await prefs.setString(_keyPhone, userData.phone ?? "");
    await prefs.setString(_keyImage, userData.profileImage ?? "");
    await prefs.setString(_keyGender, userData.gender ?? "");
    await prefs.setString(_keyDob, userData.dateOfBirth ?? "");
  }

  Future<void> pickStartDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      startDateController.text = "${picked.year}-${picked.month}-${picked.day}";
      update();
    }
  }

  Future<void> pickEndDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      endDateController.text = "${picked.year}-${picked.month}-${picked.day}";
      update();
    }
  }

  void fetchProfile() async {
    try {
      isLoading.value = true;

      final response = await profileRepo.profileRepoApi();

      if (response.statusCode == 200) {
        final body = response.body;

        if (body['code']?.toString() == "200") {
          profile.value = ProfileModels.fromJson(body);

          final userData = profile.value.data;

          if (userData != null) {
            nameController.text = userData.name ?? "";
            phoneController.text = userData.phone ?? "";
            emailController.text = userData.email ?? "";
            genderController.text = userData.gender ?? "";
            profileimagee = userData.profileImage ?? "";
            // If this logs empty right after a text-only edit, the backend
            // dropped the photo on update (old_profile_image not honoured) —
            // a server fix, not a client one. If it logs a full https URL,
            // resolvedProfileImageUrl below now handles it instead of
            // double-prefixing it into a broken link.
            debugPrint('[Profile] profile_image from server = "${userData.profileImage}"');
            dobController.text = userData.dateOfBirth ?? "";
            userName = userData.name ?? "";
            emailAddress = userData.email ?? "";
            _saveProfileToCache(userData);
          }
          update();
        } else {
          Get.snackbar("Error", "Unable to load profile. Please try again.");
        }
      } else {
        Get.snackbar("Error", "Server error. Please try again later.");
      }
    } catch (e) {
      // /Get.snackbar("Error", e.toString());
    } finally {
      update();
      isLoading.value = false;
    }
  }

  ////addBankDetails
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      profileImage.value = File(image.path);
    }
  }

  void printAllData() {
    debugPrint("EV: ${evController.text}");
    debugPrint("Name: ${nameController.text}");
    debugPrint("Address: ${addressController.text}");
    debugPrint("Phone: ${phoneController.text}");
    debugPrint("Email: ${emailController.text}");
    debugPrint("Profile Image: ${profileImage.value?.path}");
  }

  ///// ========= Api  First Sig-Up Api Call  =========

  Future<Response> updatePersonalInfoApi({
    required BuildContext context,
    String? name,
    String? email,
    String? gender,
    String? dob,
    String? phonenumber,
    File? profileimage,
    String? oldProfile,
  }) async {
    EasyLoading.show(status: "Please wait...");
    update();

    Response response;

    try {
      File? finalFile;
      String? oldImageUrl;

      if (profileimage != null) {
        finalFile = profileimage;
      } else if (oldProfile != null && oldProfile.isNotEmpty) {
        oldImageUrl = oldProfile;
      }

      response = await profileRepo.upatePersonalApi(
        name: name?.trim(),
        email: email?.trim(),
        gender: gender?.trim(),
        dob: dob?.trim(),
        phonenumber: phonenumber,
        profile_image: finalFile,
        old_profile_image: oldImageUrl,
      );
    } catch (e) {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Error',
        "Something went wrong. Please try again.",
        backgroundColor: ColorResources.whiteColor,
        colorText: ColorResources.textColorRed,
        snackPosition: SnackPosition.TOP,
      );
      rethrow;
    }

    final body = response.body;

    if (body["code"]?.toString() == "200") {
      await EasyLoading.dismiss();
      Get.snackbar(
        '',
        "${body['message'] ?? "Updated Successfully"}",
        backgroundColor: ColorResources.blueeebutton,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );

      // Was missing entirely — a successful update-profile call never
      // refreshed profileimagee/profile.value (or nameController etc.) from
      // the server, it only showed a toast and navigated home. Every screen
      // reading profileimagee (the home profile card, this controller's own
      // GetBuilder-wrapped avatar) kept showing whatever was loaded at app
      // start — i.e. a freshly uploaded photo would never appear until the
      // app was fully restarted and fetchProfile() ran again from onInit().
      // fetchProfile() is fire-and-forget (declared `void`, not
      // `Future<void>`) but it calls update() itself once the refetch
      // lands, so every GetBuilder<ProfileController> picks up the new
      // image as soon as it resolves, regardless of which screen is on
      // screen by then.
      fetchProfile();

      await Future.delayed(const Duration(milliseconds: 500));

      Get.offAllNamed(RouteHelper.gethomescreen());
    } else {
      await EasyLoading.dismiss();
      Get.snackbar(
        '',
        body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.red,
        snackPosition: SnackPosition.TOP,
      );
    }

    update();
    return response;
  }

  Future<Response> linkAccountConnectCallApi({
    required BuildContext context,
    required String provider,
    required String accesstoken,
  }) async {
    EasyLoading.show(status: "Please wait...");
    update();

    Response response;

    try {
      response = await profileRepo.customerConnectSocial(
        provider: provider.toString(),
        access: accesstoken.toString(),
      );
    } catch (e) {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Error',
        "Something went wrong. Please try again.",
        backgroundColor: ColorResources.whiteColor,
        colorText: ColorResources.textColorRed,
        snackPosition: SnackPosition.TOP,
      );
      rethrow;
    }

    final body = response.body;

    if (body['code'].toString() == '200') {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Success',
        "${body['message'] ?? "Updated Successfully"}",
        backgroundColor: ColorResources.blueeebutton,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );

      // Future.delayed(Duration(seconds: 1), () {
      //   getAddressCustomer(context: context);
      // });
      Get.back();
    } else {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Error',
        body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.red,
        snackPosition: SnackPosition.TOP,
      );
    }

    update();
    return response;
  }

  Future<Response> addBankDetailsDriver({
    required BuildContext context,
    required String holdername,
    required String accountNumber,
    required String ifsccode,
    required String bankName,
  }) async {
    EasyLoading.show(status: "Please wait...");
    update();

    try {
      Response response = await profileRepo.addBankDetails(
        holderName: holdername.trim(),
        accountNumber: accountNumber.trim(),
        ifscCode: ifsccode.trim(),
        bankName: bankName.trim(),
      );
      debugPrint('testing mode for verifyPickupOtp ${response}');
      EasyLoading.dismiss();
      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['status'] == '200') {
        EasyLoading.dismiss();
        Get.snackbar(
          '',
          response.body['message'],
          backgroundColor: ColorResources.appColor,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        // bankVerify(
        //   context: context,

        // );

        update();
        return response;
      } else if (response.body != null &&
          response.body['code']?.toString() == '401') {
        Get.snackbar(
          '',
          response.body['message'] ?? "Something went wrong",
          backgroundColor: ColorResources.textColorRed,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );

        return response;
      } else {
        Get.snackbar(
          '',
          response.body['message'] ?? "Something went wrong",
          backgroundColor: ColorResources.textColorRed,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );

        return response;
      }
    } catch (e) {
      EasyLoading.dismiss();
      rethrow;
    }
  }

  Future<Response> bankVerify({required BuildContext context}) async {
    EasyLoading.show(status: "Please wait...");
    update();

    try {
      Response response = await profileRepo.bankVerify();
      EasyLoading.dismiss();
      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code']?.toString() == '200') {
        EasyLoading.dismiss();
        Get.snackbar(
          '',
          response.body['message'],
          backgroundColor: ColorResources.appColor,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        Get.offAllNamed(RouteHelper.gethomescreen());
        update();
        return response;
      } else if (response.body != null &&
          response.body['code']?.toString() == '401') {
        Get.snackbar(
          '',
          response.body['message'] ?? "Something went wrong",
          backgroundColor: ColorResources.textColorRed,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );

        return response;
      } else {
        Get.snackbar(
          '',
          response.body['message'] ?? "Something went wrong",
          backgroundColor: ColorResources.textColorRed,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );

        return response;
      }
    } catch (e) {
      EasyLoading.dismiss();
      rethrow;
    }
  }

  ///bankVerify

  Future<Response?> aboutUsApi({required BuildContext context}) async {
    isCmsLoading = true;
    update();

    EasyLoading.show(status: "Please wait...");

    Response? response;

    try {
      response = await profileRepo.getaboutUs(slug: "about-us");
    } catch (e) {
      await EasyLoading.dismiss();
      isCmsLoading = false;
      update();

      Get.snackbar(
        'Error',
        "Something went wrong. Please try again.",
        backgroundColor: ColorResources.whiteColor,
        colorText: ColorResources.textColorRed,
        snackPosition: SnackPosition.TOP,
      );
      return null;
    }

    await EasyLoading.dismiss();

    final body = response.body;

    if (response.statusCode == 200 && body['code'].toString() == "200") {
      aboutUsDetails = AboutUsModel.fromJson(body);
    } else {
      Get.snackbar(
        'Error',
        body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }

    isCmsLoading = false;
    update();

    return response;
  }

  Future<Response?> privacyPolicy({required BuildContext context}) async {
    isCmsLoading = true;
    update();

    EasyLoading.show(status: "Please wait...");

    Response? response;

    try {
      response = await profileRepo.getprivacypolicy(slug: "privacy-policy");
    } catch (e) {
      await EasyLoading.dismiss();
      isCmsLoading = false;
      update();

      Get.snackbar(
        'Error',
        "Something went wrong. Please try again.",
        backgroundColor: ColorResources.whiteColor,
        colorText: ColorResources.textColorRed,
        snackPosition: SnackPosition.TOP,
      );
      return null;
    }

    await EasyLoading.dismiss();

    final body = response.body;

    if (response.statusCode == 200 && body['code'].toString() == "200") {
      privacyDetails = PrivacyModel.fromJson(body);
    } else {
      Get.snackbar(
        'Error',
        body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }

    isCmsLoading = false;
    update();

    return response;
  }

  Future<Response?> termsAndConditions({required BuildContext context}) async {
    isCmsLoading = true;
    update();

    EasyLoading.show(status: "Please wait...");

    Response? response;

    try {
      response = await profileRepo.getprivacypolicy(slug: "terms-of-service");
    } catch (e) {
      await EasyLoading.dismiss();
      isCmsLoading = false;
      update();

      Get.snackbar(
        'Error',
        "Something went wrong. Please try again.",
        backgroundColor: ColorResources.whiteColor,
        colorText: ColorResources.textColorRed,
        snackPosition: SnackPosition.TOP,
      );
      return null;
    }

    await EasyLoading.dismiss();

    final body = response.body;

    if (response.statusCode == 200 && body['code'].toString() == "200") {
      privacyDetails = PrivacyModel.fromJson(body);
    } else {
      Get.snackbar(
        'Error',
        body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }

    isCmsLoading = false;
    update();

    return response;
  }

  Future<Response> getNotificationsDetails({
    required BuildContext context,
  }) async {
    isNotificationLoading = true;
    update();

    // Was no try/catch around this call at all — both resets below sat past
    // the await, so a network failure or a malformed response (thrown from
    // NotificationModel.fromJson) skipped both and left isNotificationLoading
    // stuck true forever. The notification screen would spin on any hiccup
    // with no way out short of restarting the app.
    try {
      Response response = await profileRepo.getNotifications();

      if (response.statusCode == 200 &&
          response.body['code']?.toString() == '200') {
        notificationModel = NotificationModel.fromJson(response.body);

        notificationList = notificationModel?.data ?? [];

        deleteAllNotifications(context: context);
        notificationList.clear();
      } else {
        Get.snackbar(
          '',
          response.body['message'] ?? "Something went wrong",
          backgroundColor: ColorResources.textColorRed,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }

      return response;
    } catch (e) {
      Get.snackbar(
        '',
        "Unable to load notifications. Please try again.",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      rethrow;
    } finally {
      isNotificationLoading = false;
      update();
    }
  }

  Future<Response> deleteAllNotifications({
    required BuildContext context,
  }) async {
    EasyLoading.show(status: "Please wait...");
    update();

    Response response;

    try {
      response = await profileRepo.deleteNotificationAll();
    } catch (e) {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Error',
        "Something went wrong. Please try again.",
        backgroundColor: ColorResources.whiteColor,
        colorText: ColorResources.textColorRed,
        snackPosition: SnackPosition.TOP,
      );
      rethrow;
    }

    final body = response.body;

    if (body['code'].toString() == '200') {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Success',
        "${body['message'] ?? "Updated Successfully"}",
        backgroundColor: ColorResources.blueeebutton,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );

      // Future.delayed(Duration(seconds: 1), () {
      //   getAddressCustomer(context: context);
      // });
      Get.back();
    } else {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Error',
        body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.red,
        snackPosition: SnackPosition.TOP,
      );
    }

    update();
    return response;
  }

  Future<Response> deleteNotifications({
    required BuildContext context,
    required String id,
    int? indexxx,
  }) async {
    EasyLoading.show(status: "Please wait...");
    update();

    Response response;

    try {
      response = await profileRepo.deleteNotification(id: id.toString());
    } catch (e) {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Error',
        "Something went wrong. Please try again.",
        backgroundColor: ColorResources.whiteColor,
        colorText: ColorResources.textColorRed,
        snackPosition: SnackPosition.TOP,
      );
      rethrow;
    }

    final body = response.body;

    if (body['code'].toString() == '200') {
      await EasyLoading.dismiss();
      Get.snackbar(
        '',
        "${body['message']}",
        backgroundColor: ColorResources.blueeebutton,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );

      Get.back();
    } else {
      await EasyLoading.dismiss();
      Get.snackbar(
        '',
        body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.red,
        snackPosition: SnackPosition.TOP,
      );
    }

    update();
    return response;
  }

  Future<Response> readNotifications({
    required BuildContext context,
    required String id,
  }) async {
    EasyLoading.show(status: "Please wait...");
    update();

    Response response;

    try {
      response = await profileRepo.readNotification(id: id.toString());
    } catch (e) {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Error',
        "Something went wrong. Please try again.",
        backgroundColor: ColorResources.whiteColor,
        colorText: ColorResources.textColorRed,
        snackPosition: SnackPosition.TOP,
      );
      rethrow;
    }

    final body = response.body;

    if (body['code'].toString() == '200') {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Success',
        "${body['message'] ?? "Updated Successfully"}",
        backgroundColor: ColorResources.blueeebutton,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );

      Get.back();
    } else {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Error',
        body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.red,
        snackPosition: SnackPosition.TOP,
      );
    }

    update();
    return response;
  }

  Future<Response> getVehicleDetailsApi({required BuildContext context}) async {

    isVehicleLoading = true;
    update();

    try {
      Response response = await profileRepo.getVehicleDetails();

      if (response.statusCode == 200 &&
          response.body is Map &&
          response.body['code'].toString() == '200') {
        vehicleModel = VehicleModel.fromJson(response.body);

        vehicleData = vehicleModel?.data;
        vehicleImages = vehicleData?.images?.cast<String>() ?? [];

        debugPrint('store imagess list data $vehicleImages');

        // debugPrint (not gated behind kDebugMode) runs identically in
        // release builds and still reaches `adb logcat` — unlike the
        // "-" shown on screen, this shows the actual raw value AND its
        // runtime type straight from get-vehicle-info's response, for
        // exactly the three fields reported as debug-only. That
        // distinguishes every plausible cause at a glance: key genuinely
        // absent (null, "field: null (Null)"), present but empty
        // ("field: \"\" (String)"), or actually populated but something
        // downstream of this line is the problem instead.
        debugPrint(
          '[VehicleDetails] chassis_number: ${vehicleData?.chassisNumber} '
          '(${vehicleData?.chassisNumber.runtimeType}), '
          'engine_number: ${vehicleData?.engineNumber} '
          '(${vehicleData?.engineNumber.runtimeType}), '
          'manufacture_year: ${vehicleData?.manufactureYear} '
          '(${vehicleData?.manufactureYear.runtimeType}) '
          '-- raw data: ${response.body['data']}',
        );

        return response;
      } else {
        AnimatedTopToast.show(
          context: context,
          message: (response.body is Map ? response.body['message'] : null) ??
              "Unable to load vehicle details. Please try again.",
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
        return response;
      }
    } catch (e) {
      // Was uncaught — any parsing failure (a malformed/missing field in
      // the response, e.g. the images-cast bug above) threw straight out
      // of this function with isVehicleLoading still true, leaving the
      // Vehicles screen on its loading spinner forever with no error and
      // no way to retry.
      debugPrint('getVehicleDetailsApi error: $e');
      AnimatedTopToast.show(
        context: context,
        message: "Unable to load vehicle details. Please check your connection and try again.",
        backgroundColor: ColorResources.redbuttoncolor,
        icon: Icons.error_rounded,
      );
      return Response(statusCode: 0, body: {'code': 'error'});
    } finally {
      isVehicleLoading = false;
      update();
    }
  }

  Future<Response> getCouponHistoryApi({required BuildContext context}) async {
    isCouponHistoryLoading = true;
    hasCouponHistoryError = false;
    update();

    try {
      final userId = ApiConstants.userIdSocial.isNotEmpty
          ? ApiConstants.userIdSocial
          : ((await SharedPreferences.getInstance())
                  .getString(ApiConstants.profileid) ??
              '');

      Response response = await profileRepo.getCouponHistory(userId: userId);

      if (response.statusCode == 200 &&
          response.body['code'].toString() == '200') {
        final data = response.body['data'];
        couponHistoryList = data is List
            ? data
                .map((e) => CouponHistoryItem.fromJson(e))
                .toList()
            : [];
      } else {
        // Never surface the backend's raw message here — show a plain,
        // user-facing explanation instead and let the screen render a
        // proper error state (not just a toast) with a retry option.
        hasCouponHistoryError = true;
      }

      return response;
    } catch (e) {
      hasCouponHistoryError = true;
      return Response(statusCode: 0);
    } finally {
      isCouponHistoryLoading = false;
      update();
    }
  }

  Future<Response> driverEarningHistory({
    required BuildContext context,
    required String type,
    required String startDate,
    required String endDate,
  }) async {
    isEarningLoading = true;
    update();

    try {
      Response response;
      if (type == "custom_date") {
        response = await profileRepo.driverEaring(
          type: type,
          startdate: startDate,
          enddate: endDate,
        );
      } else {
        response = await profileRepo.driverEaringWithOutDate(type: type);
      }

      debugPrint('Earning History ${response.body}');

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'].toString() == '200') {
        earningModel = EarningModels.fromJson(response.body);

        totalEarnings = 0;
        if (earningModel?.data?.values != null) {
          for (var item in earningModel!.data!.values!) {
            totalEarnings += item.toDouble();
          }
        }

        /// Bar Graph Data
        barGroups.clear();

        for (int i = 0; i < (earningModel?.data?.values?.length ?? 0); i++) {
          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: earningModel!.data!.values![i].toDouble(),
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        }
      }

      isEarningLoading = false;
      update();

      return response;
    } catch (e) {
      isEarningLoading = false;
      update();
      rethrow;
    }
  }

  /// Currently unreachable — the live online-payment flow runs through
  /// HomeController.generateOnlineQr(). [actualDistance] is required rather
  /// than defaulted because the backend rejects generate-qr-payment without
  /// it, and this controller has no view of the ride's distance; whoever wires
  /// this up must pass HomeController's value (see _actualDistanceForBackend
  /// there) instead of guessing one here.
  Future<Response> genrateQRCodeForPayment({
    required BuildContext context,
    required String id,
    required String actualDistance,
  }) async {
   // EasyLoading.show(status: "Generating QR...");
    isQrLoading = true;
    update();

    // Was rethrow with no reset above it — the two `isQrLoading = false`
    // lines at the end were only ever reached on success, so any failure
    // generating the payment QR (network drop, timeout) left this screen's
    // loader spinning forever with no way to retry short of restarting the
    // app. A driver waiting to collect payment is exactly the wrong place
    // for that to happen silently.
    try {
      Response response = await profileRepo.genrateQrCOde(
        bookingid: id,
        actualDistance: actualDistance,
      );

      final body = response.body;

      if (response.statusCode == 200 && body['code'].toString() == "200") {
        qrImage = body["data"]["qr_code"].toString();
        // api response according adjust if key different

        EasyLoading.dismiss();

        Get.to(() => PaymentQrScreen(bookingId: id));
      } else {
        EasyLoading.dismiss();

        Get.snackbar("Error", body["message"] ?? "Unable to generate QR code. Please try again.");
      }

      return response;
    } catch (e) {
      EasyLoading.dismiss();
      Get.snackbar('Error', "Unable to generate QR code. Please try again.", snackPosition: SnackPosition.TOP);
      rethrow;
    } finally {
      isQrLoading = false;
      update();
    }
  }

  Future<Response> verifyQrCodePayment({
    required BuildContext context,
    required String bookingId,
  }) async {
    EasyLoading.show(status: "Please wait...");
    update();

    Response response;

    try {
      response = await profileRepo.verifyQrCode(
        bookingid: bookingId.toString(),
      );
    } catch (e) {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Error',
        "Something went wrong. Please try again.",
        backgroundColor: ColorResources.whiteColor,
        colorText: ColorResources.textColorRed,
        snackPosition: SnackPosition.TOP,
      );
      rethrow;
    }

    final body = response.body;

    if (body['code'].toString() == '200') {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Success',
        "${body['message'] ?? "Updated Successfully"}",
        backgroundColor: ColorResources.blueeebutton,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );

      Get.back();
    } else {
      await EasyLoading.dismiss();
      Get.snackbar(
        'Error',
        body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.red,
        snackPosition: SnackPosition.TOP,
      );
    }

    update();
    return response;
  }

  Future<void> getEarningActivityDetailList({
    required BuildContext context,
  }) async {
    isEarningActivityLoading = true;
    update(); // loader show

    try {
      Response response = await profileRepo.getdriverErningActivity();

      debugPrint("API RESPONSE => ${response.body}");

      if (response.statusCode == 200) {
        earningActivityList.clear();

        earningActivityList.addAll(
          EarningActivityModel.fromJson(response.body).data ?? [],
        );
        debugPrint('tttttttttttt ${response.body.data}');
      }
    } catch (e) {
      debugPrint("ERROR => $e");
    } finally {
      isEarningActivityLoading = false;
      update(); // VERY IMPORTANT
    }
  }

  // trip-detail requests currently in flight, keyed by booking id.
  //
  // This endpoint is called from several screens, and some of those calls sit
  // in an addPostFrameCallback registered during build(). Because the old code
  // also called update() *before* awaiting, one such call synchronously
  // rebuilt every GetBuilder watching this controller, which re-registered the
  // callback, which called this again — an unbounded loop that fired requests
  // far faster than responses came back. A device log showed dozens of
  // identical `trip-detail {booking_id: 99}` calls back to back, saturating the
  // main thread and starving the renderer ("Unable to acquire a buffer item").
  //
  // De-duplicating here fixes it for every caller at once, rather than relying
  // on each screen to guard its own build path correctly.
  final Map<String, Future<Response>> _tripDetailInFlight =
      <String, Future<Response>>{};

  Future<Response> tripRideDetailsApi({
    required BuildContext context,
    required String? bookingid,
  }) {
    final String key = bookingid.toString();

    // Join the existing request rather than starting a second one. Callers
    // still get a Future that completes with the same response.
    final Future<Response>? pending = _tripDetailInFlight[key];
    if (pending != null) return pending;

    final Future<Response> request = _tripRideDetailsRequest(key);
    _tripDetailInFlight[key] = request;
    return request.whenComplete(() => _tripDetailInFlight.remove(key));
  }

  Future<Response> _tripRideDetailsRequest(String bookingid) async {
    // No update() before the request: nothing has changed yet, and calling it
    // here is what let a build-time caller re-enter this method synchronously.
    Response response = await profileRepo.tripDetailsRideApi(
      bookingId: bookingid,
    );

    if (response.statusCode == 200) {
      final body = response.body;

      if (body['code']?.toString() == "200") {
        tripDetailsModel = TripDetailsModel.fromJson(response.body);
      }
    } else if (response.statusCode == 500) {
      Get.snackbar(
        '',
        response.body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } else {}

    update();
    return response;
  }

  Future<Response> getBankInfoDetails({required BuildContext context}) async {
    isBankInfoLoading = true;
    update();

    try {
      Response response = await profileRepo.getBankInfoDetails();

      debugPrint("Bank Info Response => ${response.body}");

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'].toString() == "200") {
        if (response.body['data'] != null) {
          bankDetailsData = BankDetailModel.fromJson(response.body);

          debugPrint("Holder Name => ${bankDetailsData?.data?.accountHolderName}");
        } else {
          bankDetailsData = null;
        }
      } else {
        // A non-200 here (this backend represents "no data yet" the same
        // way it represents real errors) almost always just means the
        // driver hasn't added bank details yet — the screen already
        // falls back to the add-bank form for that case, so a raw/red
        // "Something went wrong" toast (via Get.snackbar's default,
        // empty-title layout) was both alarming and visually broken.
        // A plain, friendly prompt is all this needs.
        bankDetailsData = null;

        AnimatedTopToast.show(
          context: context,
          message: "Please add your bank details to receive payments.",
          backgroundColor: ColorResources.appColor,
          icon: Icons.info_outline,
        );
      }

      isBankInfoLoading = false;
      update();

      return response;
    } catch (e) {
      debugPrint("Bank Info Error => $e");

      isBankInfoLoading = false;
      bankDetailsData = null;
      update();

      return Response(statusCode: 500, statusText: e.toString());
    }
  }
}
