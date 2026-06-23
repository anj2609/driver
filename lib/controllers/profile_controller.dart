import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myridedriverapp/model/aboutus_model.dart';
import 'package:myridedriverapp/model/arningactivitylist_model.dart';
import 'package:myridedriverapp/model/bankdetals_model.dart';
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

        if (body['code'] == "200") {
          profile.value = ProfileModels.fromJson(body);

          final userData = profile.value.data;

          if (userData != null) {
            nameController.text = userData.name ?? "";
            phoneController.text = userData.phone ?? "";
            emailController.text = userData.email ?? "";
            genderController.text = userData.gender ?? "";
            profileimagee = userData.profileImage ?? "";
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
    ;

    if (body["code"] == "200") {
      await EasyLoading.dismiss();
      Get.snackbar(
        '',
        "${body['message'] ?? "Updated Successfully"}",
        backgroundColor: ColorResources.blueeebutton,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );

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
      print('testing mode for verifyPickupOtp ${response}');
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
      } else if (response.body != null && response.body['code'] == '401') {
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
          response.body['code'] == '200') {
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
      } else if (response.body != null && response.body['code'] == '401') {
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

    Response response = await profileRepo.getNotifications();

    if (response.statusCode == 200 && response.body['code'] == '200') {
      notificationModel = NotificationModel.fromJson(response.body);

      notificationList = notificationModel?.data ?? [];

      deleteAllNotifications(context: context);
      notificationList.clear();

      isNotificationLoading = false;
      update();
    } else {
      Get.snackbar(
        '',
        response.body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.textColorRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );

      isNotificationLoading = false;
      update();
    }

    return response;
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

    Response response = await profileRepo.getVehicleDetails();


    if (response.statusCode == 200 &&
        response.body['code'].toString() == '200') {
      vehicleModel = VehicleModel.fromJson(response.body);

      vehicleData = vehicleModel?.data;
      vehicleImages = vehicleData?.images?.cast<String>() ?? [];

      print('store imagess list data $vehicleImages');
      

      isVehicleLoading = false;
      update();
    } else {
       AnimatedTopToast.show(
        context: context,
        message:
            response.body['message'] ?? "Something went wrong",
        backgroundColor: ColorResources.redbuttoncolor,
        icon: Icons.check_circle_rounded,
      );
      // Get.snackbar(
      //   '',
      //   response.body['message'] ?? "Something went wrong",
      //   backgroundColor: ColorResources.textColorRed,
      //   colorText: Colors.white,
      //   snackPosition: SnackPosition.TOP,
      // );

      isVehicleLoading = false;
      update();
    }

    return response;
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

      print('Earning History ${response.body}');

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

  Future<Response> genrateQRCodeForPayment({
    required BuildContext context,
    required String id,
  }) async {
   // EasyLoading.show(status: "Generating QR...");
    isQrLoading = true;
    update();

    Response response;

    try {
      response = await profileRepo.genrateQrCOde(bookingid: id);
    } catch (e) {
    //  EasyLoading.dismiss();

     // Get.snackbar('Error', "$e", snackPosition: SnackPosition.TOP);

      rethrow;
    }

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

    isQrLoading = false;
    update();

    return response;
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

      print("API RESPONSE => ${response.body}");

      if (response.statusCode == 200) {
        earningActivityList.clear();

        earningActivityList.addAll(
          EarningActivityModel.fromJson(response.body).data ?? [],
        );
        print('tttttttttttt ${response.body.data}');
      }
    } catch (e) {
      print("ERROR => $e");
    } finally {
      isEarningActivityLoading = false;
      update(); // VERY IMPORTANT
    }
  }

  Future<Response> tripRideDetailsApi({
    required BuildContext context,
    required String? bookingid,
  }) async {
    update();

    Response response = await profileRepo.tripDetailsRideApi(
      bookingId: bookingid.toString(),
    );

    if (response.statusCode == 200) {
      final body = response.body;

      if (body['code'] == "200") {
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

      print("Bank Info Response => ${response.body}");

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'].toString() == "200") {
        if (response.body['data'] != null) {
          bankDetailsData = BankDetailModel.fromJson(response.body);

          print("Holder Name => ${bankDetailsData?.data?.accountHolderName}");
        } else {
          bankDetailsData = null;
        }
      } else {
        bankDetailsData = null;

        Get.snackbar(
          '',
          response.body['message'] ?? "Something went wrong",
          backgroundColor: ColorResources.textColorRed,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }

      isBankInfoLoading = false;
      update();

      return response;
    } catch (e) {
      print("Bank Info Error => $e");

      isBankInfoLoading = false;
      bankDetailsData = null;
      update();

      return Response(statusCode: 500, statusText: e.toString());
    }
  }
}
