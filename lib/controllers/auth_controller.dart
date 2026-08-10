import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/model/coupon_model.dart';
import 'package:myridedriverapp/model/driverdocument_model.dart';
import 'package:myridedriverapp/model/driveruploaddoc_model.dart';
import 'package:myridedriverapp/model/updatevehicledoc_model.dart';
import 'package:myridedriverapp/model/vehicale_model.dart';
import 'package:myridedriverapp/model/vehicle_upload_model.dart';
import 'package:myridedriverapp/model/vehicleupload_model.dart';
import 'package:myridedriverapp/repository/auth_repo.dart';
import 'package:myridedriverapp/screens/auth/socialauth_screen.dart';
import 'package:myridedriverapp/widgets/image_source_sheet.dart';
import 'package:myridedriverapp/widgets/toaster_animation.dart';
import 'package:http/http.dart' as http;
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

  CouponData? validatedCoupon;
  bool isCouponValidated = false;
  bool isCouponLoading = false;

  int? selectedVehicleTypeId;
  String? updateStroeId;
  bool isLoading = false;
  int currentStep = 0;
  bool isPersonalSaved = false;
  bool isDriverDocSaved = false;
  bool isSoicialSaved = false;
  String? vehicleStoreId;
  String? _lastKnownVehicleId;
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

    try {
      deviceToken = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 10),
      );
    } catch (e) {
      deviceToken = null;
      print("FCM getToken failed: $e");
    }

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
    final originalFile = await pickImageFromSource(Get.context!, allowFiles: true);

    if (originalFile == null) return;

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
      firstDate: DateTime.now(),
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
    final originalFile = await pickImageFromSource(Get.context!, allowFiles: true);

    if (originalFile == null) return;

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
      firstDate: DateTime.now(),
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
    final picked = await pickImageFromSource(Get.context!, allowFiles: true);

    if (picked != null) {
      if (isDriver) {
        editDriverDocumentList[index].imageFiles = picked;
      } else {
        editVehicleDocumentList[index].imageFiles = picked;
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

      // profileStatus is used by userProfileStatuss below

      vehicleid = response.body['data']?['vehicle_id'].toString() ?? "0";
      userProfileStatuss = response.body['data']['profile_status'].toString();
      await prefs.setString(
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
        // verification_status is stored for future use via prefs

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

      // Persist token so auth headers survive app restart
      if (ApiConstants.userTokenSocial.isNotEmpty) {
        authRepo.saveUserToken(ApiConstants.userTokenSocial);
        authRepo.saveUserprofileid(ApiConstants.userIdSocial);
      }

      editDriverDocumentList.clear();
      editVehicleDocumentList.clear();

      /// DRIVER DOCS
      if (response.body['data']?["driver_doc"] != null) {
        for (var item in response.body['data']["driver_doc"]) {
          final doc = _buildEditDocFromJson(item);
          if (doc != null) editDriverDocumentList.add(doc);
        }
      }

      /// VEHICLE DOCS
      if (response.body['data']?["vehicle_doc"] != null) {
        for (var item in response.body['data']["vehicle_doc"]) {
          final doc = _buildEditDocFromJson(item);
          if (doc != null) editVehicleDocumentList.add(doc);
        }
      }

      // Only persist docs and show toast for users who have submitted all docs
      if (isComplete == 1) {
          _saveDocsToCache();

        isDocLoading = false;
        update();
      } else {
        isDocLoading = false;
        update();
      }
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

      RouteHelper.getOtpVerification(mobileNumber, type);
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
        message: 'Unable to send OTP. Please check your number and try again.',
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
      RouteHelper.getOtpVerification(mobileNumber, ApiConstants.UserRegister);
      return;
    }

    // Register failed. Only fall back to a login OTP when the backend says
    // this exact number is already registered (code 401, "already in use");
    // any other failure is a real error and should be shown as-is instead
    // of being silently retried as a login attempt.
    final registerMessage = (registerResponse.body?["message"] ?? '')
        .toString();
    final phoneAlreadyInUse =
        registerResponse.body?["code"] == "401" &&
        registerMessage.toLowerCase().contains("already in use");

    if (!phoneAlreadyInUse) {
      if (Get.isDialogOpen ?? false) Get.back();
      AnimatedTopToast.show(
        context: context,
        message: registerMessage.isNotEmpty
            ? registerMessage
            : "Failed to send OTP. Please check your number and try again.",
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
      return;
    }

    // Number is already registered — automatically retry as a login OTP.
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
      RouteHelper.getOtpVerification(mobileNumber, ApiConstants.UserLogin);
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
        message: 'Unable to save address. Please try again.',
        backgroundColor: Colors.red,
        icon: Icons.error_rounded,
      );
    }
    update();
    return response;
  }

  Future<String> _currentUserId() async {
    if (ApiConstants.userIdSocial.isNotEmpty) return ApiConstants.userIdSocial;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ApiConstants.profileid) ?? '';
  }

  Future<Response> validateCouponApi({
    required BuildContext context,
    required String code,
  }) async {
    isCouponLoading = true;
    update();

    try {
      final userId = await _currentUserId();
      Response response = await authRepo.validateCoupon(
        userId: userId,
        code: code,
      );

      final body = response.body;
      final resCode = body?['code']?.toString();

      if (resCode == '200') {
        validatedCoupon = body?['data'] != null
            ? CouponData.fromJson(body['data'])
            : null;
        isCouponValidated = true;
      } else {
        isCouponValidated = false;
        validatedCoupon = null;
      }

      return response;
    } catch (e) {
      rethrow;
    } finally {
      isCouponLoading = false;
      update();
    }
  }

  Future<Response> redeemCouponApi({
    required BuildContext context,
    required String code,
  }) async {
    isCouponLoading = true;
    update();

    try {
      final userId = await _currentUserId();
      Response response = await authRepo.redeemCoupon(
        userId: userId,
        code: code,
      );

      final body = response.body;
      final resCode = body?['code']?.toString();

      if (resCode == '200') {
        if (body?['data'] != null) {
          validatedCoupon = CouponData.fromJson(body['data']);
        }
      }

      return response;
    } catch (e) {
      rethrow;
    } finally {
      isCouponLoading = false;
      update();
    }
  }

  Future<Response> driverdocument({required BuildContext context}) async {
    isDriverDocsFetching = true;
    update();
    try {
      Response response = await authRepo.driverdocument();
      if (response.statusCode == 200 && response.body['code'] == '200') {
        driverDocumentModel = DriverDocumentModel.fromJson(response.body);
        driverDocumentList = driverDocumentModel?.data ?? [];
        _applyDriverDocDisplayNames(driverDocumentList);
      } else {
        AnimatedTopToast.show(
          context: context,
          message: 'Unable to load driver documents. Please try again.',
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
        _applyVehicleDocDisplayNames(vehicleDocumentList);
      } else {
        AnimatedTopToast.show(
          context: context,
          message: 'Unable to load vehicle documents. Please try again.',
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

  /// Normalizes a document name for matching: lowercase, all whitespace
  /// removed. The backend's actual spacing is inconsistent (observed both
  /// "Driver Doc 1" and "Driver Doc1" in the wild), so matching must not
  /// depend on exact spacing.
  String _normalizeDocName(String? name) =>
      (name ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// Relabels the API-provided "Driver Doc 1"/"Driver Doc 2" entries with
  /// clearer names. Only the display name changes — `id` (used for
  /// upload/matching) is left untouched.
  void _applyDriverDocDisplayNames(List<DriverDocumentDataModel> docs) {
    for (final doc in docs) {
      final normalized = _normalizeDocName(doc.name);
      if (normalized == 'driverdoc1') {
        doc.name = 'Driving License Front';
      } else if (normalized == 'driverdoc2') {
        doc.name = 'Driving License Back';
      }
    }
  }

  /// The backend returns two RC document slots ("Rc Document 1" and
  /// "Rc Document 2"); the product only wants a single Registration
  /// Certificate upload, so the second slot is dropped entirely (not just
  /// hidden) and the first is relabelled. Dropping it here — before the
  /// list is used for both rendering and the required-fields validation —
  /// means the removed slot can never block submission.
  void _applyVehicleDocDisplayNames(List<VehicleDocumentDataModel> docs) {
    docs.removeWhere(
      (doc) => _normalizeDocName(doc.name) == 'rcdocument2',
    );
    for (final doc in docs) {
      final normalized = _normalizeDocName(doc.name);
      if (normalized == 'rcdocument1') {
        doc.name = 'Registration Certificate';
      }
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
        message: 'Unable to resend OTP. Please try again.',
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

  final token = data?['token']?.toString() ?? "";

  // No token → wrong OTP, not a document-pending response
  if (token.isEmpty) {
    AnimatedTopToast.show(
      context: context,
      message: body?['message'] ?? 'Incorrect OTP. Please try again.',
      backgroundColor: Colors.red,
      icon: Icons.error_rounded,
    );
    return response;
  }

  ApiConstants.userTokenSocial = token;

  ApiConstants.userIdSocial =
      data?['id']?.toString() ?? "";

  // Persist token so auth headers survive app restart
  authRepo.saveUserToken(ApiConstants.userTokenSocial);
  authRepo.saveUserprofileid(ApiConstants.userIdSocial);

  // profile_status "1" means this is a brand-new number's very first OTP
  // verify — nothing has been entered yet, so there's no profile on the
  // backend to fetch. Calling fetchProfile() here anyway made the very
  // first screen after signing up show a confusing "Unable to load
  // profile" error toast for every new driver.
  final String? profileStatusForFetch = data?['profile_status']?.toString();
  if (profileStatusForFetch != null && profileStatusForFetch != '1') {
    Get.find<ProfileController>().fetchProfile();
  }

  editDriverDocumentList.clear();
  editVehicleDocumentList.clear();

  /// DRIVER DOCS
  if (data != null &&
      data["driver_doc"] != null &&
      data["driver_doc"] is List) {
    for (var item in data["driver_doc"]) {
      final doc = _buildEditDocFromJson(item);
      if (doc != null) editDriverDocumentList.add(doc);
    }
  }

  /// VEHICLE DOCS
  if (data != null &&
      data["vehicle_doc"] != null &&
      data["vehicle_doc"] is List) {
    for (var item in data["vehicle_doc"]) {
      final doc = _buildEditDocFromJson(item);
      if (doc != null) editVehicleDocumentList.add(doc);
    }
  }

  _saveDocsToCache();
}
else {
  AnimatedTopToast.show(
    context: context,
    message: 'Invalid or expired OTP. Please try again.',
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
        message: 'Unable to save your information. Please try again.',
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
        // Populate editDriverDocumentList so they appear immediately in My Documents
        editDriverDocumentList.clear();
        for (int i = 0; i < documents.length; i++) {
          final doc = documents[i];
          final edit = EditVehicleDocumentsModel(
            id: doc.id,
            documentId: doc.id,
            name: doc.name,
            number: doc.numberController.text,
            expriydate: doc.expiryController.text.isNotEmpty
                ? doc.expiryController.text
                : null,
            status: 'pending',
          );
          edit.numberControllers.text = doc.numberController.text;
          if (doc.expiryController.text.isNotEmpty) {
            edit.expiryControllers.text = doc.expiryController.text;
          }

          editDriverDocumentList.add(edit);
        }
        _saveDocsToCache();

        AnimatedTopToast.show(
          context: context,
          message: "Documents uploaded successfully.",
          backgroundColor: Colors.green,
          icon: Icons.check_circle_rounded,
        );
      } else {
        AnimatedTopToast.show(
          context: context,
          message: 'Unable to upload documents. Please check your details and try again.',
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
        // Populate editVehicleDocumentList so they appear immediately in My Documents
        editVehicleDocumentList.clear();
        for (int i = 0; i < documents.length; i++) {
          final doc = documents[i];
          final edit = EditVehicleDocumentsModel(
            id: doc.id,
            documentId: doc.id,
            name: doc.name,
            number: doc.numberControllers.text,
            expriydate: doc.expiryControllers.text.isNotEmpty
                ? doc.expiryControllers.text
                : null,
            status: 'pending',
          );
          edit.numberControllers.text = doc.numberControllers.text;
          if (doc.expiryControllers.text.isNotEmpty) {
            edit.expiryControllers.text = doc.expiryControllers.text;
          }

          editVehicleDocumentList.add(edit);
        }

        // All registration docs submitted — mark as pending and persist session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConstants.verificationStatus, "pending");
        await prefs.setBool(ApiConstants.docsSubmittedForReview, true);
        // Persist in-memory registration token so session survives app restart
        if (ApiConstants.userTokenSocial.isNotEmpty) {
          await authRepo.saveUserToken(ApiConstants.userTokenSocial);
          await authRepo.saveUserprofileid(ApiConstants.userIdSocial);
        }
        _saveDocsToCache();
        AnimatedTopToast.show(
          context: context,
          message: "Vehicle documents saved successfully.",
          backgroundColor: Colors.green,
          icon: Icons.check_circle_rounded,
        );
      } else {
        AnimatedTopToast.show(
          context: context,
          message: 'Unable to upload vehicle documents. Please try again.',
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
            // Keep imageFiles so the freshly-uploaded image stays visible
            // under the "Under Review" overlay until the next app restart
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
          message: 'Unable to update documents. Please check your details and try again.',
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
      // Use the actual vehicle ID from the API (saved by fetchDocumentStatus),
      // NOT doc.id which is the document record ID.
      final vehicleIdForUpload = _lastKnownVehicleId
          ?? vehicleStoreId
          ?? '';
      debugPrint('[UpdateVehicleDoc] vehicleId=$vehicleIdForUpload '
          '(lastKnown=$_lastKnownVehicleId, storeId=$vehicleStoreId)');

      List<VehicleDocumentUploadModels> documentLists = documents.map((doc) {
        return VehicleDocumentUploadModels(
          documentId: doc.documentId.toString(),
          documentNumber: doc.numberControllers.text.trim(),
          expiryDate: doc.expiryControllers.text.trim(),
          documentImage: doc.imageFiles,
          vehicleId: vehicleIdForUpload,
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
            // Keep imageFiles so the freshly-uploaded image stays visible
            // under the "Under Review" overlay until the next app restart
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
          message: 'Unable to update vehicle documents. Please check your details and try again.',
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
          message: 'Unable to load vehicle types. Please try again.',
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
          message: 'Unable to load vehicle brands. Please try again.',
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
    String? vehicleId,
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
      vehicleId: vehicleId,
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
        message: 'Unable to save vehicle information. Please try again.',
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
        message: 'Invalid verification code. Please try again.',
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
    // Clear registration-step state so next login starts fresh
    await prefs.remove(ApiConstants.isPersonalSavedStatus);
    await prefs.remove(ApiConstants.isPersonalSaved);
    await prefs.remove(ApiConstants.docsSubmittedForReview);
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

    if (driverJson != null) {
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

    if (vehicleJson != null) {
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



  /// POSTs to driver-document-status with user_id to get the latest doc status.
  /// Called every 30 seconds by the timer, on pull-to-refresh, and on the
  /// refresh AppBar button. Updates each doc's status/remark in real time and
  /// auto-navigates to home when the driver is fully approved.
  /// Fetches the driver's document approval status from the server and
  /// syncs local state (edit lists, cached verification_status, navigation
  /// on approval) exactly as before. Returns whether the driver is, as of
  /// this fresh check, fully approved — used by [HomeController] to
  /// strictly gate going online. On a genuine network/parse failure (no
  /// verdict available), falls back to the last cached verification_status
  /// rather than hard-blocking an already-approved driver over an
  /// unrelated connectivity hiccup.
  Future<bool> fetchDocumentStatus({bool navigateOnApproved = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = ApiConstants.userIdSocial.isNotEmpty
          ? ApiConstants.userIdSocial
          : (prefs.getString(ApiConstants.profileid) ?? '');

      debugPrint('[DocStatus] userId=$userId '
          'userIdSocial=${ApiConstants.userIdSocial}');

      if (userId.isEmpty) {
        debugPrint('[DocStatus] userId is empty — aborting');
        return prefs.getString(ApiConstants.verificationStatus) == 'approved';
      }

      final resp = await authRepo.fetchDriverDocumentStatus(userId);

      debugPrint('[DocStatus] statusCode=${resp.statusCode} '
          'body=${resp.body}');

      if (resp.statusCode != 200 || resp.body == null) {
        debugPrint('[DocStatus] bad response — aborting');
        return prefs.getString(ApiConstants.verificationStatus) == 'approved';
      }

      // When all docs are approved, the server may return an empty body
      // or a non-JSON string. Handle gracefully — treat as approved.
      if (resp.body is! Map<String, dynamic>) {
        debugPrint('[DocStatus] body is not a Map (${resp.body.runtimeType}) — treating as approved');
        await _navigateToHomeAsApproved(navigate: navigateOnApproved);
        return true;
      }

      final body = resp.body as Map<String, dynamic>;
      final data = body['data'];

      debugPrint('[DocStatus] keys=${body.keys.toList()} '
          'dataType=${data.runtimeType}');

      // Save the vehicle_id from the response for re-upload use.
      // The API returns vehicle_id as an array like [48].
      if (data is Map<String, dynamic>) {
        final vid = data['vehicle_id'];
        if (vid is List && vid.isNotEmpty) {
          _lastKnownVehicleId = vid.first.toString();
        } else if (vid != null) {
          _lastKnownVehicleId = vid.toString();
        }
        debugPrint('[DocStatus] saved vehicleId=$_lastKnownVehicleId');
      }

      // Check overall approval status first (root-level verification_status).
      // The body also has a domain "code" field (e.g. "401" meaning "pending")
      // which is NOT a real HTTP failure — ignore it for auth purposes.
      final String? overallStatus = _extractVerificationStatus(body, data);
      debugPrint('[DocStatus] overallStatus=$overallStatus');
      if (overallStatus != null &&
          overallStatus != 'pending' &&
          overallStatus != 'rejected' &&
          overallStatus != 'under_review' &&
          overallStatus.isNotEmpty) {
        await _navigateToHomeAsApproved(navigate: navigateOnApproved);
        return true;
      }

      // Parse driver doc arrays — try every common key name.
      bool updated = false;
      int totalChanged = 0;
      for (final key in [
        'pending_driver_docs',
        'driver_doc',
        'driver_documents',
        'documents',
      ]) {
        final docs = _parseDocList(body, listKey: key);
        if (docs != null && docs.isNotEmpty) {
          debugPrint('[DocStatus] driver docs from key "$key": '
              '${docs.map((d) => d['status']).toList()}');
          totalChanged += _mergeDocStatus(editDriverDocumentList, docs);
          updated = true;
          break;
        }
      }
      for (final key in [
        'pending_vehicle_docs',
        'vehicle_doc',
        'vehicle_documents',
      ]) {
        final docs = _parseDocList(body, listKey: key);
        if (docs != null && docs.isNotEmpty) {
          debugPrint('[DocStatus] vehicle docs from key "$key": '
              '${docs.map((d) => d['status']).toList()}');
          totalChanged += _mergeDocStatus(editVehicleDocumentList, docs);
          updated = true;
          break;
        }
      }

      // Flat list fallback — split by type discriminator or try both lists.
      if (!updated) {
        final flat = _parseDocList(body);
        debugPrint('[DocStatus] flat list: ${flat?.length} items — '
            '${flat?.map((d) => d['status']).toList()}');
        if (flat != null && flat.isNotEmpty) {
          final driverDocs = flat
              .where((d) =>
                  d['type']?.toString() == 'driver' ||
                  d['doc_type']?.toString() == 'driver')
              .toList();
          final vehicleDocs = flat
              .where((d) =>
                  d['type']?.toString() == 'vehicle' ||
                  d['type']?.toString() == 'vehical' ||
                  d['doc_type']?.toString() == 'vehicle')
              .toList();
          if (driverDocs.isNotEmpty) {
            totalChanged += _mergeDocStatus(editDriverDocumentList, driverDocs);
            updated = true;
          }
          if (vehicleDocs.isNotEmpty) {
            totalChanged += _mergeDocStatus(editVehicleDocumentList, vehicleDocs);
            updated = true;
          }
          if (!updated) {
            // No type discriminator — try merging against both lists.
            totalChanged += _mergeDocStatus(editDriverDocumentList, flat);
            totalChanged += _mergeDocStatus(editVehicleDocumentList, flat);
            updated = flat.isNotEmpty;
          }
        }
      }

      debugPrint('[DocStatus] updated=$updated changed=$totalChanged '
          'driverStatuses=${editDriverDocumentList.map((d) => d.status).toList()} '
          'vehicleStatuses=${editVehicleDocumentList.map((d) => d.status).toList()}');

      // When all docs are approved the backend may return empty pending lists
      // but verification_status == "approved" at the root — already handled above.
      // If parsing found nothing but the body has a code indicating approval, guard here too.
      if (!updated) {
        final bodyCode = body['code']?.toString();
        if (bodyCode != null && bodyCode != '401' && bodyCode == '200') {
          // Server returned success code with no pending docs — treat as approved.
          await _navigateToHomeAsApproved(navigate: navigateOnApproved);
          return true;
        }
        return false;
      }

      final allApproved =
          editDriverDocumentList.isNotEmpty &&
          editVehicleDocumentList.isNotEmpty &&
          editDriverDocumentList.every((d) => d.status == 'approved') &&
          editVehicleDocumentList.every((d) => d.status == 'approved');

      if (allApproved) {
        await _navigateToHomeAsApproved(navigate: navigateOnApproved);
        return true;
      }

      _saveDocsToCache();
      if (totalChanged > 0) {
        // Notify the user that the admin has updated at least one document status.
        Get.snackbar(
          'Document Status Updated',
          'One or more document statuses have changed. Please review.',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF1F2937),
          colorText: const Color(0xFFFFFFFF),
        );
      }
      update();
      return false;
    } catch (e, st) {
      debugPrint('[DocStatus] ERROR: $e\n$st');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(ApiConstants.verificationStatus) == 'approved';
    }
  }

  Future<void> _navigateToHomeAsApproved({bool navigate = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.verificationStatus, 'approved');
    if (navigate) {
      Get.offAllNamed(RouteHelper.gethomescreen());
    }
  }

  /// Extract overall verification status from a response body, trying common
  /// field names at both the root level and inside `data`.
  String? _extractVerificationStatus(
    Map<String, dynamic> body,
    dynamic data,
  ) {
    const fields = [
      'verification_status',
      'approval_status',
      'document_status',
      'account_status',
    ];
    for (final f in fields) {
      final v = body[f]?.toString();
      if (v != null && v.isNotEmpty) return v;
    }
    if (data is Map<String, dynamic>) {
      for (final f in fields) {
        final v = data[f]?.toString();
        if (v != null && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  /// Parse a list of doc maps from an API response body.
  /// Searches: body[listKey], body['data'][listKey], body['data'] (if List).
  List<Map<String, dynamic>>? _parseDocList(
    Map<String, dynamic> body, {
    String? listKey,
  }) {
    dynamic raw;
    if (listKey != null) {
      raw = body[listKey] ?? (body['data'] is Map ? body['data'][listKey] : null);
    } else {
      raw = body['data'];
    }
    if (raw is List && raw.isNotEmpty) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return null;
  }

  /// Updates status and remark on existing docs in [list] from [freshDocs].
  /// Returns how many docs had their status actually changed.
  int _mergeDocStatus(
    List<EditVehicleDocumentsModel> list,
    List<Map<String, dynamic>> freshDocs,
  ) {
    int changed = 0;
    for (final raw in freshDocs) {
      // Primary match: document_id or id as integer.
      final docId = int.tryParse(
        raw['document_id']?.toString() ?? raw['id']?.toString() ?? '',
      );
      int idx = docId != null
          ? list.indexWhere((d) => d.documentId == docId)
          : -1;

      // Fallback: match by document name (case-insensitive).
      if (idx < 0) {
        final rawName =
            (raw['document_name'] ?? raw['name'] ?? '').toString().toLowerCase().trim();
        if (rawName.isNotEmpty) {
          idx = list.indexWhere(
            (d) => (d.name ?? '').toLowerCase().trim() == rawName,
          );
        }
      }

      if (idx >= 0) {
        final newStatus = raw['status']?.toString();
        if (newStatus != null && newStatus != list[idx].status) {
          list[idx].status = newStatus;
          changed++;
        }
        list[idx].remark = raw['remark']?.toString() ?? list[idx].remark;
        if (list[idx].imageFiles == null && raw['file'] != null) {
          list[idx].file = raw['file'].toString();
        }
      } else {
        // No local record for this document (e.g. the upload-time list
        // population never ran, or the app/controller restarted and the
        // cache didn't restore it) — build one straight from the server
        // response instead of silently dropping it. Without this, the
        // status screen can end up showing "No documents found" even
        // though the server clearly has documents pending review.
        final doc = _buildEditDocFromJson(raw);
        if (doc == null) continue; // dropped by design (rc document 2)
        list.add(doc);
        changed++;
      }
    }
    return changed;
  }

  /// Builds an [EditVehicleDocumentsModel] from a raw server document map,
  /// applying the same display-name relabeling used across the app, and
  /// returns null for document types that should be dropped entirely (the
  /// redundant second RC document slot).
  EditVehicleDocumentsModel? _buildEditDocFromJson(Map<String, dynamic> item) {
    final normalized = _normalizeDocName(
      (item['document_name'] ?? item['name'])?.toString(),
    );
    if (normalized == 'rcdocument2') return null;

    final doc = EditVehicleDocumentsModel.fromJson(item);
    if (normalized == 'driverdoc1') {
      doc.name = 'Driving License Front';
    } else if (normalized == 'driverdoc2') {
      doc.name = 'Driving License Back';
    } else if (normalized == 'rcdocument1') {
      doc.name = 'Registration Certificate';
    }
    doc.numberControllers.text = doc.number ?? '';
    if ((doc.expriydate ?? '').isNotEmpty) {
      try {
        doc.expiryControllers.text = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.parse(doc.expriydate!));
      } catch (_) {}
    }
    return doc;
  }

  String _buildServerDocUrl(String? file) {
    if (file == null || file.trim().isEmpty) return '';
    if (file.startsWith('http://') || file.startsWith('https://')) return file;
    final path = file.startsWith('/') ? file.substring(1) : file;
    if (path.startsWith('storage/')) {
      return '${ApiConstants.imageurl}$path';
    }
    final base = ApiConstants.fileUrl.endsWith('/')
        ? ApiConstants.fileUrl
        : '${ApiConstants.fileUrl}/';
    return '$base$path';
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
