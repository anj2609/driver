import 'dart:developer';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/apis/api_client.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/model/driveruploaddoc_model.dart';
import 'package:myridedriverapp/model/vehicleupload_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepo extends GetxService {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  AuthRepo({required this.apiClient, required this.sharedPreferences});

  /////========== Send  otp Api ======================///////
  Future<Response> sendOtpApi({
    String? phone,
    String? type,
    String? devicetoken,
    String? devicetype,
  }) async {
    log('resend  otp number $phone');
    return apiClient.postsignUpData(ApiConstants.sendOtpUrl, {
      "phone": phone,
      "type": type,
      "user_type": ApiConstants.driverLogin,
      "device_type": devicetype,
      "device_token": devicetoken,
    });
  }

  Future<Response> reSendOtp({String? phone, String? numOtp}) async {
    log('resend  otp number $phone');
    return apiClient.postsignUpData(ApiConstants.reSendOtp, {
      "phone": phone,

      "user_type": ApiConstants.driverLogin,
    });
  }

  Future<Response> logOut() async {
    return apiClient.myridepostData(ApiConstants.logOutUrl, {});
  }

  Future<Response> driveraddressApi({
    String? country,
    String? division,
    String? city,
  }) async {
    print('testing $city');
    return apiClient.myridepostData(ApiConstants.driveraddress, {
      "country": country.toString(),
      "division": division.toString(),
      "city": city.toString(),
    });
  }

  Future<Response> driverdocument() async {
    return apiClient.getApi(
      ApiConstants.driverDocument + ApiConstants.driverLogin,
    );
  }

  Future<Response> vehicalDocument() async {
    return apiClient.getApi(
      ApiConstants.driverDocument + ApiConstants.vehicaletype,
    );
  }

  Future<Response> vehicalType() async {
    return apiClient.getApi(ApiConstants.vehicaltypelist);
  }

  Future<Response> vehicaleInfo({
    String? vehicalid,
    String? vehicalnumber,
    String? brand,
    String? model,
    String? color,
    String? chassisnumber,
    String? enginenumber,
    String? manufactureyear,
    List<File>? images,
  }) async {
    return apiClient.postdrivervehicale(ApiConstants.vehicalInfo, {
      "vehicle_type_id": vehicalid,
      "vehicle_number": vehicalnumber,
      "brand": brand,
      "model": model,
      "color": color,
      "chassis_number": chassisnumber,
      "engine_number": enginenumber,
      "manufacture_year": manufactureyear,
    }, images: images);
  }

  //vehicalInfo

  /////========== verify otp Api ======================///////
  Future<Response> verifyOtpApi({String? phone, String? otp}) async {
    return apiClient.postsignUpData(ApiConstants.verityOtpUrl, {
      "phone": phone,
      "otp": otp,
      "user_type": ApiConstants.driverLogin,
    });
  }

  Future<Response> fillPersonalApi({
    String? name,
    String? email,
    String? gender,
    String? dob,
    File? profile_image,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    dynamic userId = prefs.getString(ApiConstants.profileid);

    return apiClient.postMultipartData(ApiConstants.basicInfo, {
      "name": name ?? "",
      "email": email ?? "",
      "gender": gender ?? "",
      "date_of_birth": dob ?? "",
      "user_id": userId ?? ApiConstants.userIdSocial,
    }, profile_image);
  }

  /////==============  driver upload document =======////
  ///
  Future<Response<dynamic>> driverOploadedDocument({
    required List<DriverDocumentUploadModel> documentList,
  }) async {
    return await apiClient.postDriverDocuments(
      ApiConstants.driverUploadDocument,
      documentList,
    );
  }

  Future<Response<dynamic>> updateDriverOploadedDocument({
    required List<DriverDocumentUploadModel> documentList,
  }) async {
    return await apiClient.postUpdateDriverDriverDocuments(
      ApiConstants.driverUploadDocument,
      documentList,
    );
  }
  ////// ================ Update

  Future<Response> vehicleDocUploaded({
    required List<VehicleDocumentUploadModels> documentList,
  }) async {
    return apiClient.postvehicleDocuments(
      ApiConstants.vehicleUploadDocument,
      documentList,
    );
  }

  ///driverUploadDocument
  Future<Response> usersignup({String? evnumber, String? passsowrd}) async {
    return apiClient.postData(ApiConstants.loginapi, {
      "ev_number": evnumber,
      "password": passsowrd,
    });
  }

  Future<Response> secoundotpverifyapi({
    String? useridd,
    String? otp,
    String? devicetoken,
  }) async {
    return apiClient.postData(ApiConstants.otpapi, {
      "application": 'true',
      "userId": useridd,
      "otp": otp,
      "device_token": devicetoken,
      "forceLogin": true,
    });
  }

  //////===================== Social Signup - SingIn =================================//////////

  // Future<http.Response> socialSignup({
  //   required String provider,
  //   required String idToken,
  // }) async {
  //   final url = Uri.parse(ApiConstants.baseUrl + ApiConstants.socialAuth);

  //   final response = await http.post(
  //     url,
  //     headers: {"Content-Type": "application/json"},
  //     body: jsonEncode({"provider": provider, "id_token": idToken}),
  //   );

  //   return response;
  // }

  Future<Response> socialSignup({
    required String provider,
    required String idToken,
  }) async {
    return apiClient.postsignUpData(ApiConstants.socialAuth, {
      "provider": provider,
      "id_token": idToken,
      "user_type": ApiConstants.driverLogin
    });
  }

  //postsignUpData
  Future<void> refreshToken(String? newToken, String? userId) async {
    if (newToken == null || newToken.isEmpty) {
      return;
    }

    await sharedPreferences.remove(ApiConstants.token);

    await sharedPreferences.setString(ApiConstants.token, newToken);

    if (userId != null && userId.isNotEmpty) {
      await sharedPreferences.setString(ApiConstants.profileid, userId);
    }
  }

  Future<bool> saveUserToken(String token) async {
    apiClient.token = token.toString();
    // ///apiClient.updateHeader(token.toString());
    return await sharedPreferences.setString(
      ApiConstants.token,
      token.toString(),
    );
  }

  ////vehicleId
  Future<bool> saveUserprofileid(String profileid) async {
    apiClient.profileid = profileid.toString();

    /// apiClient.updateHeader(profileid.toString(), token.toString());
    return await sharedPreferences.setString(
      ApiConstants.profileid,
      profileid.toString(),
    );
  }

  void removeUserToken() async {
    await sharedPreferences.remove(ApiConstants.token);
    await sharedPreferences.remove(ApiConstants.profileid);
  }

  void removeToken() async {
    await sharedPreferences.remove(ApiConstants.token);
  }

  String? getUserToken() {
    return sharedPreferences.getString(ApiConstants.token);
  }

  String? getUserprofileid() {
    return sharedPreferences.getString(ApiConstants.profileid);
  }
}
