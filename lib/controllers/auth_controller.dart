import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/customdailog_screen.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/model/driverdocument_model.dart';
import 'package:myridedriverapp/model/driveruploaddoc_model.dart';
import 'package:myridedriverapp/model/updatevehicledoc_model.dart';
import 'package:myridedriverapp/model/vehicale_model.dart';
import 'package:myridedriverapp/model/vehicle_upload_model.dart';
import 'package:myridedriverapp/model/vehicleupload_model.dart';
import 'package:myridedriverapp/repository/auth_repo.dart';
import 'package:myridedriverapp/screens/auth/socialauth_screen.dart';
import 'package:myridedriverapp/widgets/toaster_animation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthController extends GetxController implements GetxService {
  final AuthRepo authRepo;
  AuthController({required this.authRepo});
  String? deviceToken;
  String? deviceType;
  DriverDocumentModel? driverDocumentModel;
  List<DriverDocumentDataModel> driverDocumentList = [];
  VehicleDocumentModel? vehicleDocumentModel;
  List<VehicleDocumentDataModel> vehicleDocumentList = [];
  VehicalTypeModel? vehicleTypeModel;
  List<VehicalTypleData> vehicleTypeList = [];
  List<EditVehicleDocumentsModel> editDriverDocumentList = [];
  List<EditVehicleDocumentsModel> editVehicleDocumentList = [];

  int? selectedVehicleTypeId;
  String? updateStroeId;
  bool isLoading = false;
  int currentStep = 0;
  bool isPersonalSaved = false;
  bool isDriverDocSaved = false;
  bool isSoicialSaved = false;
  String? selectedBrandId;
  String? selectedBrandName;
  String? vehicleStoreId;
  bool isDocLoading = true;
  bool isDriverbuttonHide = true;
  bool isVehicleButtonHide = true;
  bool isUpdatingDriverDocs = false;
  bool isUpdatingVehicleDocs = false;
  bool isDriverDocsFetching = false;
  bool isVehicleDocsFetching = false;
  // final GoogleSignIn _googleSignIn = GoogleSignIn();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  static const String _keyDriverDocsCache = 'cached_driver_docs_json';
  static const String _keyVehicleDocsCache = 'cached_vehicle_docs_json';

  @override
  Future<void> onInit() async {
    super.onInit();
    initDeviceData();
    listenTokenRefresh();
    _loadDocsFromCache();

    ///  Get.find<AuthController>().vehicleType(context: context);

    // _googleSignIn.initialize(
    //   serverClientId:
    //       "816050400087-4pv5deujt52p78pv3u785cf32f9cv269.apps.googleusercontent.com",
    // );
  }

  Future<void> initDeviceData() async {
    deviceType = Platform.isAndroid ? "android" : "ios";

    deviceToken = await FirebaseMessaging.instance.getToken();

    await saveDeviceData();

    print("Saved Token: $deviceToken");
    print("Saved Device Type: $deviceType");
  }

  Future<void> saveDeviceData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("device_token", deviceToken ?? "");
    await prefs.setString("device_type", deviceType ?? "");
  }

  Future<void> loadSavedDeviceData() async {
    final prefs = await SharedPreferences.getInstance();

    deviceToken = prefs.getString("device_token");
    deviceType = prefs.getString("device_type");
  }

  Future<void> pickDriverImage(int index) async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return;

    final originalFile = File(pickedFile.path);

    // temp folder
    final dir = await getTemporaryDirectory();

    final targetPath = p.join(
      dir.path,
      "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg",
    );

    File? compressedFile;
    int quality = 80;

    while (quality > 10) {
      final result = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        targetPath,
        quality: quality,
      );

      if (result == null) break;

      final fileSize = await File(result.path).length();

      if (fileSize <= 50 * 1024) {
        compressedFile = File(result.path);
        break;
      }

      quality -= 10;
    }

    compressedFile ??= File(targetPath);

    driverDocumentList[index].imageFile = compressedFile;

    update();
  }

  // Future<void> pickDriverImage(int index) async {
  //   final pickedFile = await ImagePicker().pickImage(
  //     source: ImageSource.gallery,
  //   );

  //   if (pickedFile != null) {
  //     driverDocumentList[index].imageFile = File(pickedFile.path);

  //     update(); // UI refresh karega
  //   }
  // }

  /// 🔥 Expiry Date Pick
  Future<void> pickExpiryDate(int index) async {
    DateTime? pickedDate = await showDatePicker(
      context: Get.context!,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      driverDocumentList[index].expiryController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(pickedDate);

      update();
    }
  }

  Future<void> vehiclpickDriverImage(int index) async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return;

    final originalFile = File(pickedFile.path);

    final dir = await getTemporaryDirectory();

    final targetPath = p.join(
      dir.path,
      "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg",
    );
    File? compressedFile;
    int quality = 80;

    // Try loop to reach ~50KB
    while (quality > 10) {
      final result = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        targetPath,
        quality: quality,
      );

      if (result == null) break;

      final fileSize = await File(result.path).length();

      if (fileSize <= 50 * 1024) {
        compressedFile = File(result.path);
        break;
      }

      quality -= 10;
    }

    // fallback if not achieved
    compressedFile ??= File(targetPath);

    vehicleDocumentList[index].imageFiles = compressedFile;

    update();
  }

  Future<void> vehiclpickExpiryDate(int index) async {
    DateTime? pickedDate = await showDatePicker(
      context: Get.context!,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);

      if (index >= 0 && index < vehicleDocumentList.length) {
        vehicleDocumentList[index].expiryControllers.text = formattedDate;
      }

      update();
    }
  }

  /// ================= PICK IMAGE =================
  Future<void> pickImage(int index, bool isDriver) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked != null) {
      if (isDriver) {
        editDriverDocumentList[index].imageFiles = File(picked.path);
      } else {
        editVehicleDocumentList[index].imageFiles = File(picked.path);
      }
      update();
    }
  }

  /// ================= PICK DATE =================
  Future<void> pickDate(int index, bool isDriver) async {
    DateTime? date = await showDatePicker(
      context: Get.context!,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      String formatted = DateFormat('yyyy-MM-dd').format(date);

      if (isDriver) {
        editDriverDocumentList[index].expiryControllers.text = formatted;
      } else {
        editVehicleDocumentList[index].expiryControllers.text = formatted;
      }

      update();
    }
  }

  bool get isAnyDriverRejected {
    return editDriverDocumentList.any((doc) => doc.status == "rejected");
  }

  bool get isAnyVehicleRejected {
    return editVehicleDocumentList.any((doc) => doc.status == "rejected");
  }

  //////////  ///autheditDriverDocumentList autheditVehicleDocumentList

  void listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      deviceToken = newToken;
      await saveDeviceData();

      print("Updated Token: $newToken");
    });
  }

  ///// ============= FaceBook Login  =================/////////////

  Future<Response?> signInWithGoogle({
    required BuildContext context,
    String? provider,
  }) async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        print("User cancelled login");
        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      final String? idToken = auth.idToken;
      final String? accessToken = auth.accessToken;

      /// ===== STORE DATA =====
      ApiConstants.socialtoken = accessToken.toString();

      ApiConstants.gmailAddres = account.email;

      // User Name
      ApiConstants.userName = account.displayName ?? "";

      ApiConstants.profileImage = account.photoUrl ?? "";

      print("User Name: ${account.displayName}");
      print("Gmail: ${account.email}");
      print("Photo: ${account.photoUrl}");

      print("ID Token: $idToken");
      print("Access Token: $accessToken");

      /// API CALL
      final response = await socailLogin(
        provider: provider.toString(),
        userToken: idToken,
        context: context,
      );

      return response;
    } catch (e) {
      print("Error: $e");
      return null;
    }
  }

  Future<Response> socailLogin({
    required BuildContext context,
    required String provider,
    String? userToken,
  }) async {
    isDocLoading = true;
    update();

    try {

    final prefs = await SharedPreferences.getInstance();

    Response response = await authRepo.socialSignup(
      provider: provider,
      idToken: userToken.toString(),
    );

    // await EasyLoading.dismiss();

    print("API RESPONSE => ${response.body}");

    if (response.body != null && (response.body['code'] == '200')) {
      ApiConstants.userTokenSocial = response.body['data']['api_token']
          .toString();
      ApiConstants.userIdSocial = response.body['data']['id'].toString();
      authRepo.saveUserToken(ApiConstants.userTokenSocial);
      authRepo.saveUserprofileid(ApiConstants.userIdSocial);
      AnimatedTopToast.show(
        context: context,
        message: "Login successful. Welcome to My Ride!",
        backgroundColor: ColorResources.blueeebutton,
        icon: Icons.check_circle_rounded,
      );
      update();
    } else if (response.body['code'] == '401') {
      print("FULL RESPONSE => ${response.body}");


      int isComplete =
          int.tryParse(
            response.body['data']?['is_complete'].toString() ?? "0",
          ) ??
          0;

      String profileStatus =
          response.body['data']?['profile_status'].toString() ?? "0";

      vehicleid = response.body['data']?['vehicle_id'].toString() ?? "0";
      userProfileStatuss = response.body['data']['profile_status'].toString();
      var statuscode = prefs.setString(
        ApiConstants.statusCode,
        response.body['code'].toString(),
      );

      print("isComplete => $isComplete");
      print("profileStatus => $userProfileStatuss");
      update();

      Future.delayed(const Duration(milliseconds: 300), () async {
        ApiConstants.userTokenSocial = response.body['data']['token']
            .toString();
        ApiConstants.userIdSocial = response.body['data']['id'].toString();
        String verificationstatus = response.body['verification_status']
            .toString();

        if (userProfileStatuss == "1") {
          print("Navigate => Earn With My Ride");

          Get.offAllNamed(RouteHelper.getearnWithMyRideScreen());

          ApiConstants.userTokenSocial = response.body['data']['token']
              .toString();
          ApiConstants.userIdSocial = response.body['data']['id'].toString();

          update();
        } else if (userProfileStatuss == "2" || userProfileStatuss == "3") {
          print("Navigate => Driver Details Step 3");
          isSoicialSaved = true;
          await prefs.setBool(ApiConstants.isDocumentSaved, isSoicialSaved);
          Get.offAllNamed(
            RouteHelper.getsocialDetailScreen(),
            arguments: {"step": 0},
          );
        }
        update();
        if (userProfileStatuss == "4") {
          Get.find<AuthController>().vehicleType(context: context);

          Get.toNamed(
            RouteHelper.getsocialDetailScreen(),
            arguments: {"step": 1},
          );
        }
        if (userProfileStatuss == "5") {
          Get.toNamed(
            RouteHelper.getsocialDetailScreen(),
            arguments: {"step": 2},
          );
        } else if (userProfileStatuss == "6") {
          print("Navigate => Driver Details Step 4");

          Get.offAllNamed(
            RouteHelper.getsocialDetailScreen(),
            arguments: {"step": 3},
          );
        }
      });

     ///// Get.find<ProfileController>().fetchProfile();

      editDriverDocumentList.clear();
      editVehicleDocumentList.clear();

      /// DRIVER DOCS
      if (response.body['data']?["driver_doc"] != null) {
        for (var item in response.body['data']["driver_doc"]) {
          var doc = EditVehicleDocumentsModel.fromJson(item);
          doc.numberControllers.text = doc.number ?? "";

          if (doc.expriydate != null && doc.expriydate!.isNotEmpty) {
            DateTime parsedDate = DateTime.parse(doc.expriydate!);
            doc.expiryControllers.text = DateFormat(
              'yyyy-MM-dd',
            ).format(parsedDate);
          }

          editDriverDocumentList.add(doc);
        }
      }

      /// VEHICLE DOCS
      if (response.body['data']?["vehicle_doc"] != null) {
        for (var item in response.body['data']["vehicle_doc"]) {
          var doc = EditVehicleDocumentsModel.fromJson(item);
          doc.numberControllers.text = doc.number ?? "";

          if (doc.expriydate != null && doc.expriydate!.isNotEmpty) {
            DateTime parsedDate = DateTime.parse(doc.expriydate!);
            doc.expiryControllers.text = DateFormat(
              'yyyy-MM-dd',
            ).format(parsedDate);
          }

          editVehicleDocumentList.add(doc);
        }
      }

      _saveDocsToCache();

      isDocLoading = false;
      update();
      AnimatedTopToast.show(
        context: context,
        message: "Your profile is under review. We will notify you once approved.",
        backgroundColor: Colors.orange,
        icon: Icons.info_rounded,
      );
    } else {
      AnimatedTopToast.show(
        context: context,
        message: "Unable to sign in. Please try again.",
        backgroundColor: Colors.orange,
        icon: Icons.error_rounded,
      );
      print("ERROR RESPONSE => ${response.body}");
    }

    return response;

    } catch (e) {
      rethrow;
    } finally {
      isDocLoading = false;
      update();
    }
  }

  Future<Response> sendOtp({
    required BuildContext context,
    required String mobileNumber,
    required String type,
    required String deviceToken,
  }) async {
    update();

    Response response = await authRepo.sendOtpApi(
      phone: mobileNumber,
      type: type,
      devicetoken: deviceToken,
      devicetype: deviceType,
    );

    if (response.body != null && response.body["code"] == "200") {
      AnimatedTopToast.show(
        context: context,
        message: "OTP sent to your mobile number. Please check your messages.",
        backgroundColor: Colors.green,
        icon: Icons.check_circle_rounded,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      Get.toNamed(
        RouteHelper.getOtpVerification(mobileNumber, type),
        arguments: {
          "type": type.toString(),
          "phoneNumber": mobileNumber.toString(),
        },
      );
    } else if (response.statusCode == 500) {
      AnimatedTopToast.show(
        context: context,
        message: "Server error. Please try again later.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
    } else {
      AnimatedTopToast.show(
        context: context,
        message: response.body?['message'] ?? "Failed to send OTP. Please try again.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
    }
    update();
    return response;
  }

  /// Tries register first; if the number is already registered, falls back to login.
  Future<void> sendOtpWithTypeDetection({
    required BuildContext context,
    required String mobileNumber,
    required String deviceToken,
  }) async {
    final registerResponse = await authRepo.sendOtpApi(
      phone: mobileNumber,
      type: ApiConstants.UserRegister,
      devicetoken: deviceToken,
      devicetype: deviceType,
    );

    if (registerResponse.body?["code"] == "200") {
      if (Get.isDialogOpen ?? false) Get.back();
      AnimatedTopToast.show(
        context: context,
        message: "OTP sent to your mobile number. Please check your messages.",
        backgroundColor: Colors.green,
        icon: Icons.check_circle_rounded,
      );
      await Future.delayed(const Duration(milliseconds: 500));
      Get.toNamed(RouteHelper.getOtpVerification(mobileNumber, ApiConstants.UserRegister));
      return;
    }

    // Register failed — number may already be registered; try login.
    final loginResponse = await authRepo.sendOtpApi(
      phone: mobileNumber,
      type: ApiConstants.UserLogin,
      devicetoken: deviceToken,
      devicetype: deviceType,
    );

    if (loginResponse.body?["code"] == "200") {
      if (Get.isDialogOpen ?? false) Get.back();
      AnimatedTopToast.show(
        context: context,
        message: "Welcome back! OTP sent to your registered number.",
        backgroundColor: Colors.green,
        icon: Icons.check_circle_rounded,
      );
      await Future.delayed(const Duration(milliseconds: 500));
      Get.toNamed(RouteHelper.getOtpVerification(mobileNumber, ApiConstants.UserLogin));
    } else {
      AnimatedTopToast.show(
        context: context,
        message: "Failed to send OTP. Please check your number and try again.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
    }
  }

  Future<Response> driveraddAddress({
    required BuildContext context,
    required String country,
    required String devision,
    required String city,
  }) async {
    update();

    Response response = await authRepo.driveraddressApi(
      country: country,
      division: devision,
      city: city,
    );

    if (response.body['code'] == '200') {
      Get.find<AuthController>().vehicleType(context: context);

      AnimatedTopToast.show(
        context: context,
        message: "Address saved successfully.",
        backgroundColor: Colors.green,
        icon: Icons.check_circle_rounded,
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (ApiConstants.userIdSocial.isNotEmpty) {
        Get.toNamed(RouteHelper.getsocialDetailScreen());
      } else {
        Get.toNamed(RouteHelper.getDriverDetails());
      }
    } else if (response.statusCode == 500) {
      AnimatedTopToast.show(
        context: context,
        message: "Server error. Please try again later.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
    } else {
      AnimatedTopToast.show(
        context: context,
        message: response.body['message'] ?? "Failed to save address. Please try again.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
    }
    update();
    return response;
  }

  Future<Response> driverdocument({required BuildContext context}) async {
    isDriverDocsFetching = true;
    update();
    try {
      Response response = await authRepo.driverdocument();
      if (response.statusCode == 200 && response.body['code'] == '200') {
        driverDocumentModel = DriverDocumentModel.fromJson(response.body);
        driverDocumentList = driverDocumentModel?.data ?? [];
      } else {
        AnimatedTopToast.show(
          context: context,
          message: response.body['message'] ?? "Something went wrong",
          backgroundColor: Colors.red,
          icon: Icons.error_rounded,
        );
      }
      return response;
    } catch (e) {
      rethrow;
    } finally {
      isDriverDocsFetching = false;
      update();
    }
  }

  Future<Response> vehicalDocument({required BuildContext context}) async {
    isVehicleDocsFetching = true;
    update();
    try {
      Response response = await authRepo.vehicalDocument();
      if (response.statusCode == 200 && response.body['code'] == '200') {
        vehicleDocumentModel = VehicleDocumentModel.fromJson(response.body);
        vehicleDocumentList = vehicleDocumentModel?.data ?? [];
      } else {
        AnimatedTopToast.show(
          context: context,
          message: response.body['message'] ?? "Something went wrong",
          backgroundColor: Colors.red,
          icon: Icons.error_rounded,
        );
      }
      return response;
    } catch (e) {
      rethrow;
    } finally {
      isVehicleDocsFetching = false;
      update();
    }
  }

  Future<Response> reSendOtp({
    required BuildContext context,
    required String mobileNumber,
    required String otpNumber,
    //reSendOtp
  }) async {
    update();

    Response response = await authRepo.reSendOtp(
      phone: mobileNumber,
      //  numOtp: otpNumber,
    );

    if (response.body["code"] == "200") {
      AnimatedTopToast.show(
        context: context,
        message: "OTP resent to your mobile number. Please check your messages.",
        backgroundColor: Colors.green,
        icon: Icons.check_circle_rounded,
      );
    } else {
      AnimatedTopToast.show(
        context: context,
        message: response.body['message'] ?? "Failed to resend OTP. Please try again.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
    }
    update();
    return response;
  }

  Future<Response> userLogOut({
    required BuildContext context,

    //reSendOtp
  }) async {
    update();

    Response response = await authRepo.logOut();

    if (response.body['code'] == '200') {
      /// await EasyLoading.dismiss();
      logOut();
      AnimatedTopToast.show(
        context: context,
        message: "You have been logged out successfully.",
        backgroundColor: Colors.green,
        icon: Icons.check_circle_rounded,
      );

      Get.offAllNamed(RouteHelper.getmyRideLoginScreen());
    } else if (response.statusCode == 500) {
      AnimatedTopToast.show(
        context: context,
        message: "Server error. Please try again later.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
    } else {
      // await EasyLoading.dismiss();
      AnimatedTopToast.show(
        context: context,
        message: "Could not log out. Please try again.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
    }

    update();
    return response;
  }

  Future<Response> verifyOtpApi({
    required BuildContext context,
    required String mobileNumber,
    required String numOfOtp,
    required String type,
  }) async {
    isDocLoading = true;
    update();

    try {

    Response response = await authRepo.verifyOtpApi(
      phone: mobileNumber,
      otp: numOfOtp,
    );

    await EasyLoading.dismiss();

    print("API Response: ${response.body}");

    final body = response.body;

    String code = body?["code"]?.toString() ?? "";
    var data = body?["data"];

    /// ================= SUCCESS (200) =================
    if (code == "200") {
  String? tokenDriver = data?["token"]?.toString();
  String? userIdDriver = data?["user"]?["id"]?.toString();

  authRepo.saveUserToken(tokenDriver ?? "");
  authRepo.saveUserprofileid(userIdDriver ?? "");

  AnimatedTopToast.show(
    context: context,
    message: "OTP verified. Welcome to My Ride!",
    backgroundColor: Colors.green,
    icon: Icons.check_circle_rounded,
  );
}
else if (code == "401") {

  // Save token if available
  ApiConstants.userTokenSocial =
      data?['token']?.toString() ?? "";

  ApiConstants.userIdSocial =
      data?['id']?.toString() ?? "";

  Get.find<ProfileController>().fetchProfile();

  editDriverDocumentList.clear();
  editVehicleDocumentList.clear();

  /// DRIVER DOCS
  if (data != null &&
      data["driver_doc"] != null &&
      data["driver_doc"] is List) {

    for (var item in data["driver_doc"]) {
      var doc = EditVehicleDocumentsModel.fromJson(item);

      doc.numberControllers.text = doc.number ?? "";

      if ((doc.expriydate ?? "").isNotEmpty) {
        try {
          DateTime parsedDate =
              DateTime.parse(doc.expriydate!);

          doc.expiryControllers.text =
              DateFormat('yyyy-MM-dd')
                  .format(parsedDate);
        } catch (e) {
          log("Driver Date Parse Error: $e");
        }
      }

      editDriverDocumentList.add(doc);
    }
  }

  /// VEHICLE DOCS
  if (data != null &&
      data["vehicle_doc"] != null &&
      data["vehicle_doc"] is List) {

    for (var item in data["vehicle_doc"]) {
      var doc = EditVehicleDocumentsModel.fromJson(item);

      doc.numberControllers.text = doc.number ?? "";

      if ((doc.expriydate ?? "").isNotEmpty) {
        try {
          DateTime parsedDate =
              DateTime.parse(doc.expriydate!);

          doc.expiryControllers.text =
              DateFormat('yyyy-MM-dd')
                  .format(parsedDate);
        } catch (e) {
          log("Vehicle Date Parse Error: $e");
        }
      }

      editVehicleDocumentList.add(doc);
    }
  }

  _saveDocsToCache();

  AnimatedTopToast.show(
    context: context,
    message: "Your profile is under review. We will notify you once approved.",
    backgroundColor: Colors.orange,
    icon: Icons.info_rounded,
  );
}
else {
  AnimatedTopToast.show(
    context: context,
    message: body?['message'] ?? "Invalid or expired OTP. Please try again.",
    backgroundColor: Colors.red,
    icon: Icons.error_rounded,
  );
}

    return response;

    } catch (e) {
      rethrow;
    } finally {
      isDocLoading = false;
      update();
    }
//     if (code == "200") {
//       String? tokenDriver = body?["data"]?["token"]?.toString();
//       String? userIdDriver = body?["data"]?["user"]?["id"]?.toString();

//       authRepo.saveUserToken(tokenDriver.toString());
//       authRepo.saveUserprofileid(userIdDriver.toString());

//       isDocLoading = false;

//       AnimatedTopToast.show(
//         context: context,
//         message: "${response.body['message']} ",
//         backgroundColor: Colors.green,
//         icon: Icons.check_circle_rounded,
//       );

//       update();

//       log(
//         'login  user token  driverrrrr ||||||||||||||| ====== ${response.body['data']["token"].toString()}',
//       );
//     } else if (code == '401') {
//       ApiConstants.userTokenSocial = response.body['data']['token'].toString();
//       ApiConstants.userIdSocial = response.body['data']['id'].toString();
//       // authRepo.saveUserToken(ApiConstants.userTokenSocial);
//       // authRepo.saveUserprofileid(ApiConstants.userIdSocial);
//     }
//     /// ================= UNDER REVIEW (401) =================
//     else if (code == '401') {
//       Map<String, dynamic>? datas = body["data"] is Map<String, dynamic>
//           ? body["data"]
//           : null;

//       String? tokens = datas?["token"]?.toString();

//       log(
//         'login  user token ||||||||||||||| ====== ${response.body['data']["token"].toString()}',
//       );
//       log(
//         'login  user user Id ||||||||||||||| ====== ${response.body['data']['id'].toString()}',
//       );
//  isDocLoading = false;
//       Get.find<ProfileController>().fetchProfile();

//       editDriverDocumentList.clear();
//       editVehicleDocumentList.clear();

//       /// DRIVER DOCS
//       if (data?["driver_doc"] != null) {
//         for (var item in data["driver_doc"]) {
//           var doc = EditVehicleDocumentsModel.fromJson(item);
//           doc.numberControllers.text = doc.number ?? "";

//           if (doc.expriydate != null && doc.expriydate!.isNotEmpty) {
//             DateTime parsedDate = DateTime.parse(doc.expriydate!);
//             doc.expiryControllers.text = DateFormat(
//               'yyyy-MM-dd',
//             ).format(parsedDate);
//           }

//           editDriverDocumentList.add(doc);
//         }
//       }

//       /// VEHICLE DOCS
//       if (data?["vehicle_doc"] != null) {
//         for (var item in data["vehicle_doc"]) {
//           var doc = EditVehicleDocumentsModel.fromJson(item);
//           doc.numberControllers.text = doc.number ?? "";

//           if (doc.expriydate != null && doc.expriydate!.isNotEmpty) {
//             DateTime parsedDate = DateTime.parse(doc.expriydate!);
//             doc.expiryControllers.text = DateFormat(
//               'yyyy-MM-dd',
//             ).format(parsedDate);
//           }

//           editVehicleDocumentList.add(doc);
//         }
//       }

//       isDocLoading = false;
//       update();
//       AnimatedTopToast.show(
//         context: context,
//         message: body?['message'] ?? "Documents Under Review",
//         backgroundColor: Colors.orange,
//         icon: Icons.check_circle_rounded,
//       );
//     }
//     /// ================= ERROR =================
//     else {
//       isDocLoading = false;
//       update();
//       AnimatedTopToast.show(
//         context: context,
//         message: body?['message'] ?? "Invalid OTP",
//         backgroundColor: Colors.red,
//         icon: Icons.error_rounded,
//       );
//     }
//      isDocLoading = false;

//     update();
//     return response;
  }

  ///// ========= Api  First Sig-Up Api Call  =========
  Future<Response> fillPersonalInfoApi({
    required BuildContext context,
    String? name,
    String? email,
    String? gender,
    String? dob,
    File? profileimage,
  }) async {
    update();

    Response response = await authRepo.fillPersonalApi(
      name: name!.trim(),
      email: email!.trim(),
      gender: gender!.trim(),
      dob: dob!.trim(),
      profile_image: profileimage,
    );

    if (response.body["code"] == "200") {
      AnimatedTopToast.show(
        context: context,
        message: "Personal information saved successfully.",
        backgroundColor: Colors.green,
        icon: Icons.check_circle_rounded,
      );

      vehicalDocument(context: context);

      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      AnimatedTopToast.show(
        context: context,
        message: response.body['message'] ?? "Failed to save personal information. Please try again.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
    }

    update();
    return response;
  }

  //////==================== Driver Document uploaded ========================///////////
  //driver-document

  Future<Response> uploadDocumentDriver({
    required BuildContext context,
    required List<DriverDocumentDataModel> documents,
  }) async {
    update();

    try {
      List<DriverDocumentUploadModel> documentList = documents.map((doc) {
        return DriverDocumentUploadModel(
          documentId: doc.id.toString(),
          documentNumber: doc.numberController.text.trim(),
          expiryDate: doc.isExpiry == true
              ? doc.expiryController.text.trim()
              : "",
          documentImage: doc.imageFile,
        );
      }).toList();

      print("Uploading Docs Count: ${documentList.length}");

      Response response = await authRepo.driverOploadedDocument(
        documentList: documentList,
      );

      await EasyLoading.dismiss();

      if (response.body["code"] == "200") {
        AnimatedTopToast.show(
          context: context,
          message: "Documents uploaded successfully.",
          backgroundColor: Colors.green,
          icon: Icons.check_circle_rounded,
        );
      } else {
        AnimatedTopToast.show(
          context: context,
          message: response.body['message'] ?? "Failed to upload documents. Please check your information and try again.",
          backgroundColor: Colors.red,
          icon: Icons.error_rounded,
        );
      }

      update();
      return response;
    } catch (e) {
      // await EasyLoading.dismiss();
      AnimatedTopToast.show(
        context: context,
        message: "Failed to upload documents. Please try again.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );

      update();
      rethrow;
    }
  }

  ///// ========== vehicle model uploaded ==================

  Future<Response> uploadVehicleDocument({
    required BuildContext context,
    required List<VehicleDocumentDataModel> documents,
  }) async {
    // EasyLoading.show(status: "Please wait...");
    update();

    try {
      print('testing demo ${vehicleStoreId} ${vehicleid}');
      List<VehicleDocumentUploadModels> documentLists = documents.map((doc) {
        return VehicleDocumentUploadModels(
          documentId: doc.id.toString(),
          documentNumber: doc.numberControllers.text.trim(),
          expiryDate: doc.isExpiry == true
              ? doc.expiryControllers.text.trim()
              : "",
          documentImage: doc.imageFiles,
          vehicleId: (vehicleid != null && vehicleid!.isNotEmpty &&
            vehicleid != "0")
              ? vehicleid!
              : vehicleStoreId.toString(),

          //  vehicleid!.isNotEmpty
          //     ? vehicleid.toString()
          //     : vehicleStoreId.toString(),
        );
      }).toList();
      print('testinggg |||||| store id ${vehicleStoreId}');

      Response response = await authRepo.vehicleDocUploaded(
        documentList: documentLists,
      );

      // await EasyLoading.dismiss();

      if (response.body["code"] == "200") {
        AnimatedTopToast.show(
          context: context,
          message: "Vehicle documents saved successfully.",
          backgroundColor: Colors.green,
          icon: Icons.check_circle_rounded,
        );
      } else {
        AnimatedTopToast.show(
          context: context,
          message: response.body['message'] ?? "Failed to upload vehicle documents. Please try again.",
          backgroundColor: Colors.red,
          icon: Icons.error_rounded,
        );
      }

      update();
      return response;
    } catch (e) {
      AnimatedTopToast.show(
        context: context,
        message: "Failed to upload vehicle documents. Please try again.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );

      update();
      rethrow;
    }
  }

  /////// ==================== DRIVER UPDATE API ==================================
  Future<Response> updateDriverDocument({
    required BuildContext context,
    required List<EditVehicleDocumentsModel> documents,
  }) async {
    isUpdatingDriverDocs = true;
    update();

    try {
      List<DriverDocumentUploadModel> documentLists = documents.map((doc) {
        return DriverDocumentUploadModel(
          documentId: doc.documentId?.toString() ?? "",
          documentNumber: doc.numberControllers.text.trim(),
          expiryDate: doc.expiryControllers.text.trim(),
          documentImage: doc.imageFiles,
        );
      }).toList();

      Response response = await authRepo.updateDriverOploadedDocument(
        documentList: documentLists,
      );

      if (response.body != null && response.body["code"] == "200") {
        for (var doc in editDriverDocumentList) {
          if (doc.status == "rejected") {
            doc.status = "pending";
            doc.remark = null;
            doc.imageFiles = null;
          }
        }
        _saveDocsToCache();
        AnimatedTopToast.show(
          context: context,
          message: "Driver documents submitted for review. We will notify you once approved.",
          backgroundColor: ColorResources.blueeebutton,
          icon: Icons.check_circle_rounded,
        );
      } else {
        AnimatedTopToast.show(
          context: context,
          message: response.body['message'] ?? "Failed to update documents. Please check your information and try again.",
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }

      return response;
    } catch (e) {
      AnimatedTopToast.show(
        context: context,
        message: "Could not submit documents. Please check your connection and try again.",
        backgroundColor: ColorResources.redbuttoncolor,
        icon: Icons.error_rounded,
      );
      rethrow;
    } finally {
      isUpdatingDriverDocs = false;
      update();
    }
  }
  ///// ================== VEHICLE UPDATE API ==============

  Future<Response> updateVehicleDocument({
    required BuildContext context,
    required List<EditVehicleDocumentsModel> documents,
  }) async {
    isUpdatingVehicleDocs = true;
    update();

    try {
      List<VehicleDocumentUploadModels> documentLists = documents.map((doc) {
        return VehicleDocumentUploadModels(
          documentId: doc.documentId.toString(),
          documentNumber: doc.numberControllers.text.trim(),
          expiryDate: doc.expiryControllers.text.trim(),
          documentImage: doc.imageFiles,
          vehicleId: doc.id.toString(),
        );
      }).toList();

      Response response = await authRepo.vehicleDocUploaded(
        documentList: documentLists,
      );

      if (response.body["code"] == "200") {
        for (var doc in editVehicleDocumentList) {
          if (doc.status == "rejected") {
            doc.status = "pending";
            doc.remark = null;
            doc.imageFiles = null;
          }
        }
        _saveDocsToCache();
        AnimatedTopToast.show(
          context: context,
          message: "Vehicle documents submitted for review. We will notify you once approved.",
          backgroundColor: ColorResources.blueeebutton,
          icon: Icons.check_circle_rounded,
        );
      } else {
        AnimatedTopToast.show(
          context: context,
          message: response.body['message'] ?? "Failed to update vehicle documents. Please check your information and try again.",
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }

      return response;
    } catch (e) {
      AnimatedTopToast.show(
        context: context,
        message: "Could not submit vehicle documents. Please check your connection and try again.",
        backgroundColor: ColorResources.redbuttoncolor,
        icon: Icons.error_rounded,
      );
      rethrow;
    } finally {
      isUpdatingVehicleDocs = false;
      update();
    }
  }

  Future<Response> vehicledoc({required BuildContext context}) async {
    isLoading = true;
    update();
    try {
      Response response = await authRepo.vehicalDocument();
      if (response.statusCode == 200 && response.body['code'] == '200') {
        vehicleTypeModel = VehicalTypeModel.fromJson(response.body);
        vehicleTypeList = vehicleTypeModel?.data ?? [];
      } else {
        AnimatedTopToast.show(
          context: context,
          message: response.body['message'] ?? "Something went wrong",
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
      return response;
    } catch (e) {
      rethrow;
    } finally {
      isLoading = false;
      update();
    }
  }

  Future<Response> vehicleType({required BuildContext context}) async {
    isLoading = true;
    update();
    try {
      Response response = await authRepo.vehicalType();
      if (response.statusCode == 200 && response.body['code'] == '200') {
        vehicleTypeModel = VehicalTypeModel.fromJson(response.body);
        vehicleTypeList = vehicleTypeModel?.data ?? [];
      } else {
        AnimatedTopToast.show(
          context: context,
          message: response.body['message'] ?? "Something went wrong",
          backgroundColor: ColorResources.redbuttoncolor,
          icon: Icons.error_rounded,
        );
      }
      return response;
    } catch (e) {
      rethrow;
    } finally {
      isLoading = false;
      update();
    }
  }

  /////========================== post Vehicale data =====================/////////////

  Future<Response> vehicaleInfoApi({
    required BuildContext context,
    String? vehicalid,
    String? vehicalnumber,
    String? brand,
    String? model,
    String? color,
    String? chassisnumber,
    String? enginenumber,
    String? manufactureyear,
    List<File>? vehicaleimages,
  }) async {
    // EasyLoading.show(status: "Please wait...");
    update();

    Response response = await authRepo.vehicaleInfo(
      vehicalid: vehicalid,
      vehicalnumber: vehicalnumber,
      brand: brand,
      model: model,
      color: color,
      chassisnumber: chassisnumber,
      enginenumber: enginenumber,
      manufactureyear: manufactureyear,
      images: vehicaleimages,
    );

    if (response.body["code"] == "200") {
      // await EasyLoading.dismiss();
      vehicleStoreId = response.body['data']['id'].toString();

      AnimatedTopToast.show(
        context: context,
        message: "Vehicle information saved successfully.",
        backgroundColor: ColorResources.blueeebutton,
        icon: Icons.check_circle_rounded,
      );
      await Future.delayed(const Duration(milliseconds: 500));
    } else if (response.body['data'] == "401") {
      AnimatedTopToast.show(
        context: context,
        message: "Unauthorized. Please log in again.",
        backgroundColor: ColorResources.redbuttoncolor,
        icon: Icons.error_rounded,
      );
    } else {
      AnimatedTopToast.show(
        context: context,
        message: response.body['message'] ?? "Failed to save vehicle information. Please try again.",
        backgroundColor: ColorResources.redbuttoncolor,
        icon: Icons.error_rounded,
      );
      // await EasyLoading.dismiss();
    }

    update();
    return response;
  }

  ///postdrivervehical

  void selectVehicle(int id) {
    selectedVehicleTypeId = id;
    update();
  }
  ////vehicalType
  ///vehical-type-list

  void showAlreadyLoggedInIOSDialog({
    required BuildContext context,
    required String message,
    VoidCallback? onYes,
    VoidCallback? onNo,
  }) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Session Alert'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Get.back();
                onNo?.call();
              },
              child: const Text('No'),
            ),

            CupertinoDialogAction(
              onPressed: () {
                Get.back();
                onYes?.call();
              },
              isDefaultAction: true,
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  Future<Response> secoundortverifyapi({
    required BuildContext context,
    required String userid,
    required String otp,
    required String devicetoken,
    required String mobilenu7mber,
  }) async {
    // EasyLoading.show();
    update();

    Response response = await authRepo.secoundotpverifyapi(
      useridd: userid,
      otp: otp,
      devicetoken: devicetoken,
    );

    if (response.statusCode == 200) {
    } else if (response.statusCode == 422) {
      AnimatedTopToast.show(
        context: context,
        message: response.body['message'] ?? "Invalid verification code. Please try again.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
    } else {
      // EasyLoading.dismiss();
    }

    update();
    return response;
  }

  String? getAuthToken() {
    return authRepo.getUserToken();
  }

  String? getAuthprofileid() {
    return authRepo.getUserprofileid();
  }

  void logOut() {
    _googleSignIn.signOut();
    authRepo.removeUserToken();
    _clearProfileCache();
  }

  void _clearProfileCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_profile_name');
    await prefs.remove('cached_profile_email');
    await prefs.remove('cached_profile_phone');
    await prefs.remove('cached_profile_image');
    await prefs.remove('cached_profile_gender');
    await prefs.remove('cached_profile_dob');
    await prefs.remove(ApiConstants.verificationStatus);
    await prefs.remove(_keyDriverDocsCache);
    await prefs.remove(_keyVehicleDocsCache);
  }

  Future<void> _saveDocsToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final driverJson = jsonEncode(editDriverDocumentList.map((d) => d.toJson()).toList());
    final vehicleJson = jsonEncode(editVehicleDocumentList.map((d) => d.toJson()).toList());
    await prefs.setString(_keyDriverDocsCache, driverJson);
    await prefs.setString(_keyVehicleDocsCache, vehicleJson);
  }

  Future<void> reloadDocsFromCache() => _loadDocsFromCache();

  Future<void> _loadDocsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final driverJson = prefs.getString(_keyDriverDocsCache);
    final vehicleJson = prefs.getString(_keyVehicleDocsCache);

    if (driverJson != null && editDriverDocumentList.isEmpty) {
      try {
        final rawList = jsonDecode(driverJson) as List;
        editDriverDocumentList.clear();
        for (var item in rawList) {
          var doc = EditVehicleDocumentsModel.fromJson(item);
          doc.numberControllers.text = doc.number ?? "";
          if ((doc.expriydate ?? "").isNotEmpty) {
            try {
              doc.expiryControllers.text =
                  DateFormat('yyyy-MM-dd').format(DateTime.parse(doc.expriydate!));
            } catch (_) {}
          }
          editDriverDocumentList.add(doc);
        }
      } catch (_) {}
    }

    if (vehicleJson != null && editVehicleDocumentList.isEmpty) {
      try {
        final rawList = jsonDecode(vehicleJson) as List;
        editVehicleDocumentList.clear();
        for (var item in rawList) {
          var doc = EditVehicleDocumentsModel.fromJson(item);
          doc.numberControllers.text = doc.number ?? "";
          if ((doc.expriydate ?? "").isNotEmpty) {
            try {
              doc.expiryControllers.text =
                  DateFormat('yyyy-MM-dd').format(DateTime.parse(doc.expriydate!));
            } catch (_) {}
          }
          editVehicleDocumentList.add(doc);
        }
      } catch (_) {}
    }

    isDocLoading = false;
    update();
  }

  void changeStep(int step) {
    currentStep = step;
    update();
  }

  void nextStep() {
    currentStep++;
    update();
  }

  void previousStep() {
    if (currentStep > 0) {
      currentStep--;
      update();
    }
  }

  void savePersonal() {
    isPersonalSaved = true;
    update();
  }

  void saveDriverDoc() {
    isDriverDocSaved = true;
    update();
  }

  List<Map<String, String>> brands = [
    {"id": "Maruti Suzuki", "name": "Maruti Suzuki"},
    {"id": "Hyundai", "name": "Hyundai"},
    {"id": "Tata Motors", "name": "Tata Motors"},
    {"id": "Mahindra", "name": "Mahindra"},
    {"id": "Honda", "name": "Honda"},
    {"id": "Toyota", "name": "Toyota"},
    {"id": "Kia", "name": "Kia"},
    {"id": "Renault", "name": "Renault"},
    {"id": "Nissan", "name": "Nissan"},
    {"id": "Volkswagen", "name": "Volkswagen"},
    {"id": "Skoda", "name": "Skoda"},
    {"id": "MG (Morris Garages)", "name": "MG (Morris Garages)"},
    {"id": "Ford", "name": "Ford"},
    {"id": "Citroen", "name": "Citroen"},
    {"id": "Jeep", "name": "Jeep"},
    {"id": "BMW", "name": "BMW"},
    {"id": "Mercedes-Benz", "name": "Mercedes-Benz"},
    {"id": "Audi", "name": "Audi"},
    {"id": "Lexus", "name": "Lexus"},
    {"id": "Volvo", "name": "Volvo"},
    {"id": "Jaguar", "name": "Jaguar"},
    {"id": "Land Rover", "name": "Land Rover"},
    {"id": "Porsche", "name": "Porsche"},
    {"id": "Mini", "name": "Mini"},
    {"id": "Isuzu", "name": "Isuzu"},
    {"id": "Tesla", "name": "Tesla"},
    {"id": "BYD", "name": "BYD"},
    {"id": "Aston Martin", "name": "Aston Martin"},
    {"id": "Bentley", "name": "Bentley"},
    {"id": "Rolls-Royce", "name": "Rolls-Royce"},
    {"id": "Ferrari", "name": "Ferrari"},
    {"id": "Lamborghini", "name": "Lamborghini"},
    {"id": "Maserati", "name": "Maserati"},
    {"id": "McLaren", "name": "McLaren"},
    {"id": "Bugatti", "name": "Bugatti"},
    {"id": "Peugeot", "name": "Peugeot"},
    {"id": "Fiat", "name": "Fiat"},
    {"id": "Chevrolet", "name": "Chevrolet"},
    {"id": "Mitsubishi", "name": "Mitsubishi"},
    {"id": "Suzuki (Global)", "name": "Suzuki (Global)"},
    {"id": "Genesis", "name": "Genesis"},
    {"id": "Changan", "name": "Changan"},
    {"id": "Geely", "name": "Geely"},
    {"id": "Great Wall Motors", "name": "Great Wall Motors"},
    {"id": "Haval", "name": "Haval"},
    {"id": "SsangYong", "name": "SsangYong"},
    {"id": "Opel", "name": "Opel"},
    {"id": "Datsun", "name": "Datsun"},
    {"id": "Infiniti", "name": "Infiniti"},
    {"id": "Acura", "name": "Acura"},
  ];

  void selectBrand(String? brandName) {
    selectedBrandName = brandName;

    final brand = brands.firstWhere((e) => e["name"] == brandName);

    selectedBrandId = brand["id"];

    update();
  }

  bool validateRejectedDocs({
    required List<EditVehicleDocumentsModel> documents,
    required BuildContext context,
  }) {
    for (var doc in documents) {
      if (doc.status == "rejected") {
        /// Document Number check
        if (doc.numberControllers.text.trim().isEmpty) {
          Get.snackbar("Error", "${doc.name} number required");
          return false;
        }

        /// Image check
        if (doc.imageFiles == null && (doc.file == null || doc.file!.isEmpty)) {
          Get.snackbar("Error", "${doc.name} image required");
          return false;
        }

        /// Expiry check (agar required hai)
        if (doc.expiryControllers.text.trim().isEmpty) {
          Get.snackbar("Error", "${doc.name} expiry date required");
          return false;
        }
      }
    }

    return true;
  }
}
