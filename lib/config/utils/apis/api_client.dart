import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart' as Foundation;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/request/request.dart';
import 'package:http/http.dart' as Http;
import 'package:myridedriverapp/config/utils/apis/api_checker.dart';
import 'package:myridedriverapp/config/utils/apis/image_compress.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/model/driveruploaddoc_model.dart';
import 'package:myridedriverapp/model/vehicleupload_model.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ApiClient extends GetxService {
  final SharedPreferences sharedPreferences;
  final String noInternetMessage =
      'Connection to API server failed due to internet connection';
  final int timeoutInSeconds = 60;

  String? token;
  String? profileid;
  String? username;
  String? emailid;
  String? pancardno;
  String? passordss;

  ///Map<String, String>? _mainHeadersMain;

  ApiClient({required this.sharedPreferences}) {}

  Map<String, String> get _mainHeadersMain {
    return {
      'Accept': 'application/json',
      'id': ApiConstants.userIdSocial.isNotEmpty
          ? ApiConstants.userIdSocial
          : (sharedPreferences.getString(ApiConstants.profileid) ?? ""),

      'authorizationToken': ApiConstants.userTokenSocial.isNotEmpty
          ? ApiConstants.userTokenSocial
          : (sharedPreferences.getString(ApiConstants.token) ?? ""),
      // 'id': sharedPreferences.getString(ApiConstants.profileid) ?? "",
      // 'authorizationToken':
      //     "${sharedPreferences.getString(ApiConstants.token) ?? ""}",
    };
  }

  //////// userIdSocial userTokenSocial

  Future<Response> postsignUpData(String uri, dynamic body) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }
    {
      try {
        if (Foundation.kDebugMode) {
          print('====> GetX Call: $uri');
          print('====> GetX Body: $body');
          print('====> GetX Body: ${ApiConstants.baseUrl}');
        }
        print('====> GetX Basebodyy: $body');
        Http.Response _response = await Http.post(
          Uri.parse(ApiConstants.baseUrl + uri),
          body: jsonEncode(body),
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
          },
          //_mainHeaders,
        ).timeout(Duration(seconds: timeoutInSeconds));
        print("++++++++++++>>>=====");
        Response response = handleResponse(_response, uri);

        if (Foundation.kDebugMode) {
          print(
            '====> API Response: [${response.statusCode}] $uri\n${response.body}',
          );
        }
        print('====>  respnosee : ${response.body}');
        return response;
      } catch (e) {
        return Response(statusCode: 1, statusText: noInternetMessage);
      }
    }
  }

  Future<Response> postChatData(String uri, dynamic body) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }

    try {
      if (Foundation.kDebugMode) {
        print('====> GetX Base URL: $ApiConstants.baseUrl');
        print('====> GetX Call: $uri');
        print('====> GetX Body: ${jsonEncode(body)}');
      }
      // Map<String, String> headerschat = {
      //   'id': '${sharedPreferences.getString(ApiConstants.profileid)}',
      //   "authorizationToken":
      //       "${sharedPreferences.getString(ApiConstants.token)}",
      // };

      Http.Response _response = await Http.post(
        Uri.parse(ApiConstants.baseUrl + uri),
        body: jsonEncode(body),
        headers: {..._mainHeadersMain, "Content-Type": "application/json"},
      ).timeout(Duration(seconds: timeoutInSeconds));

      print("STATUS CODE: ${_response.statusCode}");
      print("RESPONSE BODY: ${_response.body}");

      Response response = handleResponse(_response, uri);

      return response;
    } catch (e) {
      print("❌ ERROR: $e");
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postData(String uri, dynamic body) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }

    try {
      if (Foundation.kDebugMode) {
        print('====> GetX Base URL: $ApiConstants.baseUrl');
        print('====> GetX Call: $uri');
        print('====> GetX Body: $body');
      }

      Http.Response _response = await Http.post(
        Uri.parse(ApiConstants.baseUrl + uri),
        body: body,

        /// jsonEncode(body),
        headers: _mainHeadersMain,
      ).timeout(Duration(seconds: timeoutInSeconds));

      print("STATUS CODE: ${_response.statusCode}");
      print("RESPONSE BODY: ${_response.body}");
      print(" BODY: ${_mainHeadersMain}");

      Response response = handleResponse(_response, uri);

      if (Foundation.kDebugMode) {
        print(
          '====> API Response: [${response.statusCode}] $uri\n${response.body}',
        );
      }

      return response;
    } catch (e) {
      print("❌ ERROR: $e");
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postDriverUpdateLocationData(
    String uri,
    dynamic body,
  ) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'You are using VPN');
    }

    try {
      // Map<String, String> headers = {
      //   'id': '${sharedPreferences.getString(ApiConstants.profileid)}',
      //   "authorizationToken":
      //       "${sharedPreferences.getString(ApiConstants.token)}",
      // };
      // print('testing body::: $headers');

      Http.Response httpResponse = await Http.post(
        Uri.parse(ApiConstants.baseUrl + uri),
        body: body,

        ///jsonEncode(body),
        headers: _mainHeadersMain,
      ).timeout(Duration(seconds: timeoutInSeconds));

      print("STATUS: ${httpResponse.statusCode}");
      print("BODY: ${httpResponse.body}");
      print("header: ${_mainHeadersMain}");
      print("parms: ${body}");

      return handleResponse(httpResponse, uri);
    } catch (e, s) {
      print("ERROR: $e");
      print("STACK: $s");
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> myridepostData(String uri, dynamic body) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'You are using VPN');
    }
    print('complete ||| ${body}');
    try {
      Http.Response httpResponse = await Http.post(
        Uri.parse(ApiConstants.baseUrl + uri),
        body: body,

        ///jsonEncode(body),
        headers: _mainHeadersMain,
      ).timeout(Duration(seconds: timeoutInSeconds));
      print("body: ${_mainHeadersMain}");
      print("STATUS: ${httpResponse.statusCode}");
      print("BODY: ${httpResponse.body}");
      print('testing |||| $_mainHeadersMain');

      return handleResponse(httpResponse, uri);
    } catch (e, s) {
      print("ERROR: $e");
      print("STACK: $s");
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postdrivervehicale(
    String uri,
    dynamic body, {
    List<File>? images,
  }) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'You are using VPN');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? profileId = prefs.getString(ApiConstants.profileid);
      String? token = prefs.getString(ApiConstants.token);

      if (images != null && images.isNotEmpty) {
        var request = Http.MultipartRequest(
          "POST",
          Uri.parse(ApiConstants.baseUrl + uri),
        );

        /// 🔹 Text Fields
        body.forEach((key, value) {
          request.fields[key] = value.toString();
        });

        for (int i = 0; i < images.length; i++) {
          request.files.add(
            await Http.MultipartFile.fromPath("images[]", images[i].path),
          );
        }

        request.headers.addAll({
          'Accept': 'application/json',
          'id': ApiConstants.userIdSocial.isNotEmpty
          ? ApiConstants.userIdSocial
          : (sharedPreferences.getString(ApiConstants.profileid) ?? ""),

      'authorizationToken': ApiConstants.userTokenSocial.isNotEmpty
          ? ApiConstants.userTokenSocial
          : (sharedPreferences.getString(ApiConstants.token) ?? ""),
          // 'id': profileId ?? "",
          // 'authorizationToken': token ?? "",
          // 'User-Agent': 'Mozilla/5.0',
        });

        var streamedResponse = await request.send();
        var response = await Http.Response.fromStream(streamedResponse);

        return handleResponse(response, uri);
      }

      Http.Response httpResponse = await Http.post(
        Uri.parse(ApiConstants.baseUrl + uri),
        body: jsonEncode(body),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'id': ApiConstants.userIdSocial.isNotEmpty
          ? ApiConstants.userIdSocial
          : (sharedPreferences.getString(ApiConstants.profileid) ?? ""),

      'authorizationToken': ApiConstants.userTokenSocial.isNotEmpty
          ? ApiConstants.userTokenSocial
          : (sharedPreferences.getString(ApiConstants.token) ?? ""),
          // 'id': profileId ?? "",
          // 'authorizationToken': token ?? "",
        },
      ).timeout(Duration(seconds: timeoutInSeconds));

      return handleResponse(httpResponse, uri);
    } catch (e, s) {
      print("ERROR: $e");
      print("STACK: $s");
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postDriverDocuments(
    String uri,
    List<DriverDocumentUploadModel> documentList,
  ) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }

    try {
      Map<String, String> headers = {
        'Accept': 'application/json',
        'id': ApiConstants.userIdSocial.isNotEmpty
            ? ApiConstants.userIdSocial
            : (sharedPreferences.getString(ApiConstants.profileid) ?? ""),
        'authorizationToken': ApiConstants.userTokenSocial.isNotEmpty
            ? ApiConstants.userTokenSocial
            : (sharedPreferences.getString(ApiConstants.token) ?? ""),
      };
      print(' testing  header ${headers}');

      var request = Http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.baseUrl + uri),
      );
      ////_mainHeadersMain
      request.headers.addAll(headers);

      for (int i = 0; i < documentList.length; i++) {
        request.fields["documents[$i][document_id]"] =
            documentList[i].documentId;

        request.fields["documents[$i][document_number]"] =
            documentList[i].documentNumber;

        request.fields["documents[$i][expiry_date]"] =
            documentList[i].expiryDate;

        if (documentList[i].documentImage != null) {
          request.files.add(
            await Http.MultipartFile.fromPath(
              "documents[$i][file]",
              documentList[i].documentImage!.path,
            ),
          );

          print("Uploading file path: ${documentList[i].documentImage!.path}");
        }

        print("ID: ${request.fields["documents[$i][document_id]"]}");
      }

      var streamedResponse = await request.send();
      var response = await Http.Response.fromStream(streamedResponse);
      print('testing  |||||||||| $response');
      return handleResponse(response, uri);
    } catch (e) {
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postUpdateDriverDriverDocuments(
    String uri,
    List<DriverDocumentUploadModel> documentList,
  ) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }

    try {
     // final prefs = await SharedPreferences.getInstance();

      // String? profileId = prefs.getString(ApiConstants.profileid);
      // String? token = prefs.getString(ApiConstants.token);

      Map<String, String> headers = {
        'Accept': 'application/json',
       'id': ApiConstants.userIdSocial.isNotEmpty
            ? ApiConstants.userIdSocial
            : (sharedPreferences.getString(ApiConstants.profileid) ?? ""),
        'authorizationToken': ApiConstants.userTokenSocial.isNotEmpty
            ? ApiConstants.userTokenSocial
            : (sharedPreferences.getString(ApiConstants.token) ?? ""),
      };

      var request = Http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.baseUrl + uri),
      );

      request.headers.addAll(headers);

      for (int i = 0; i < documentList.length; i++) {
        final doc = documentList[i];

        request.fields["documents[$i][document_id]"] = doc.documentId ?? "";

        request.fields["documents[$i][document_number]"] =
            doc.documentNumber ?? "";

        if ((doc.expiryDate ?? "").isNotEmpty) {
          request.fields["documents[$i][expiry_date]"] = doc.expiryDate!;
        }

        if (doc.documentImage != null) {
          request.files.add(
            await Http.MultipartFile.fromPath(
              "documents[$i][file]",
              doc.documentImage!.path,
            ),
          );
        }

        /// debug logs
        print("Doc[$i] ID: ${doc.documentId}");
        print("Doc[$i] Number: ${doc.documentNumber}");
        print("Doc[$i] Expiry: ${doc.expiryDate}");
        print("Doc[$i] File: ${doc.documentImage?.path}");
      }

      var streamedResponse = await request.send();
      var response = await Http.Response.fromStream(streamedResponse);

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      return handleResponse(response, uri);
    } catch (e) {
      print("API ERROR 👉 $e");
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postvehicleDocuments(
    String uri,
    List<VehicleDocumentUploadModels> vehicleDocumentList,
  ) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }

    try {
      //  final prefs = await SharedPreferences.getInstance();

      // String? profileId = prefs.getString(ApiConstants.profileid);
      // String? token = prefs.getString(ApiConstants.token);

      // Map<String, String> headers = {
      //   'Accept': 'application/json',
      //   'id': profileId ?? "",
      //   'authorizationToken': token ?? "",
      //   'User-Agent': 'Mozilla/5.0',
      // };

      var request = Http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.baseUrl + uri),
      );

      request.headers.addAll(_mainHeadersMain);

      for (int i = 0; i < vehicleDocumentList.length; i++) {
        print(
          'Suchi test Vehicle Id ${request.fields['vehicle_id'] = vehicleDocumentList[i].vehicleId.toString()}',
        );
        request.fields['vehicle_id'] = vehicleDocumentList[i].vehicleId
            .toString();
        request.fields["documents[$i][document_id]"] = vehicleDocumentList[i]
            .documentId
            .toString();

        request.fields["documents[$i][document_number]"] =
            vehicleDocumentList[i].documentNumber ?? "";

        request.fields["documents[$i][expiry_date]"] =
            vehicleDocumentList[i].expiryDate ?? "";

        /// File Upload
        if (vehicleDocumentList[i].documentImage != null) {
          request.files.add(
            await Http.MultipartFile.fromPath(
              "documents[$i][file]",
              vehicleDocumentList[i].documentImage!.path,
            ),
          );

          print(
            "Uploading file path: ${vehicleDocumentList[i].documentImage!.path}",
          );
        }

        print("ID: ${vehicleDocumentList[i].documentId}");
      }

      var streamedResponse = await request.send();
      var response = await Http.Response.fromStream(streamedResponse);

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      return handleResponse(response, uri);
    } catch (e) {
      print("Error: $e");
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postUpdateVehicleDocuments(
    String uri,
    List<VehicleDocumentUploadModels> vehicleDocumentList,
  ) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }

    try {
      // final prefs = await SharedPreferences.getInstance();

      // String? profileId = prefs.getString(ApiConstants.profileid);
      // String? token = prefs.getString(ApiConstants.token);

      // Map<String, String> headers = {
      //   'Accept': 'application/json',
      //   'id': profileId ?? "",
      //   'authorizationToken': token ?? "",
      //   'User-Agent': 'Mozilla/5.0',
      // };

      var request = Http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.baseUrl + uri),
      );

      request.headers.addAll(_mainHeadersMain);

      for (int i = 0; i < vehicleDocumentList.length; i++) {
        request.fields['vehicle_id'] = vehicleDocumentList[i].vehicleId
            .toString();
        request.fields["documents[$i][document_id]"] = vehicleDocumentList[i]
            .documentId
            .toString();

        request.fields["documents[$i][document_number]"] =
            vehicleDocumentList[i].documentNumber ?? "";

        request.fields["documents[$i][expiry_date]"] =
            vehicleDocumentList[i].expiryDate ?? "";

        /// File Upload
        if (vehicleDocumentList[i].documentImage != null) {
          request.files.add(
            await Http.MultipartFile.fromPath(
              "documents[$i][file]",
              vehicleDocumentList[i].documentImage!.path,
            ),
          );

          print(
            "Uploading file path: ${vehicleDocumentList[i].documentImage!.path}",
          );
        }

        print("ID: ${vehicleDocumentList[i].documentId}");
      }

      var streamedResponse = await request.send();
      var response = await Http.Response.fromStream(streamedResponse);

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      return handleResponse(response, uri);
    } catch (e) {
      print("Error: $e");
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postMultipartData(
    String uri,
    Map<String, String> body,
    File? imageFile,
  ) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }

    log('testing   $body');
    try {
      Map<String, String> headers = {'Accept': 'application/json'};

      var request = Http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.baseUrl + uri),
      );

      request.headers.addAll(headers);

      request.fields.addAll(body);

      if (imageFile != null) {
        request.files.add(
          await Http.MultipartFile.fromPath('profile_image', imageFile.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await Http.Response.fromStream(streamedResponse);

      return handleResponse(response, uri);
    } catch (e) {
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postMultipartNewSelectProfile(
    String uri,
    Map<String, String> body,
    File? imageFile,
  ) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // dynamic userId = prefs.getString(ApiConstants.profileid);
    // log('user id ||||| $userId');

    // log('testing   $body');
    try {
      // Map<String, String> headers = {
      //   'Accept': 'application/json',
      //   'id': userId,
      //   'authorizationToken':
      //       'Bearer ${sharedPreferences.getString(ApiConstants.token)}',
      // };

      var request = Http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.baseUrl + uri),
      );

      request.headers.addAll(_mainHeadersMain);

      request.fields.addAll(body);

      if (imageFile != null) {
        request.files.add(
          await Http.MultipartFile.fromPath('profile_image', imageFile.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await Http.Response.fromStream(streamedResponse);

      return handleResponse(response, uri);
    } catch (e) {
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postMultipartUpdate(
    String uri,
    Map<String, String> body,
    dynamic imageFile,
  ) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'You are using VPN');
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString(ApiConstants.profileid);
      String? token = prefs.getString(ApiConstants.token);
      print('testing mode $imageFile');
      var request = Http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.baseUrl + uri),
      );

      request.headers.addAll(
        _mainHeadersMain,
        //   {
        //   'Accept': 'application/json',

        //   if (userId != null) 'id': userId,
        //   if (token != null) 'authorizationToken': token,
        // }
      );

      request.fields.addAll(body);

      if (imageFile != null) {
        if (imageFile is File && await imageFile.exists()) {
          /// 🔥 FORMAT CHECK
          if (!isValidImageFormat(imageFile)) {
            return Response(
              statusCode: 0,
              statusText: "Only JPG, JPEG, PNG, WEBP allowed",
            );
          }

          /// 🔥 COMPRESS
          File finalFile = await compressImageUnder2MB(imageFile);

          int finalSize = await finalFile.length();
          print("✅ FINAL SIZE: ${finalSize / 1024} KB");

          if (finalSize > 2048 * 1024) {
            return Response(
              statusCode: 0,
              statusText: "Image must be less than 2MB",
            );
          }

          request.files.add(
            await Http.MultipartFile.fromPath('profile_image', finalFile.path),
          );
        } else if (imageFile is String) {
          request.fields['old_profile_image'] = imageFile;
        }
      }

      var streamedResponse = await request.send();
      var response = await Http.Response.fromStream(streamedResponse);

      return handleResponse(response, uri);
    } catch (e, st) {
      print('Multipart error: $e\n$st');
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postDataMap(String uri, dynamic body) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }
    {
      try {
        if (Foundation.kDebugMode) {
          print('====> GetX Base URL: $ApiConstants.baseUrl');
          print('====> GetX Call: $uri');
          print('====> GetX Body: $body');
        }
        print('====> GetX Basebodyy: $body');
        Http.Response _response = await Http.post(
          Uri.parse(ApiConstants.baseUrl + uri),
          body: body,
          headers: _mainHeadersMain,
        ).timeout(Duration(seconds: timeoutInSeconds));
        print("++++++++++++>>>=====");
        Response response = handleResponse(_response, uri);

        if (Foundation.kDebugMode) {
          print(
            '====> API Response: [${response.statusCode}] $uri\n${response.body}',
          );
        }
        print('====>  respnosee : ${response.body}');
        return response;
      } catch (e) {
        return Response(statusCode: 1, statusText: noInternetMessage);
      }
    }
  }

  ///_mainHeadersMain
  ///
  ///

  Future<Response> getDataalltypeApi(String uri) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    } else {
      try {
        // Map<String, String> headers = {
        //   'Accept': 'application/json',
        //   'id': '${sharedPreferences.getString(ApiConstants.profileid)}',
        //   'authorizationToken':
        //       '${sharedPreferences.getString(ApiConstants.token)}',
        // };

        Http.Response _response = await Http.get(
          Uri.parse(ApiConstants.baseUrl + uri),
          headers: _mainHeadersMain,
        ).timeout(Duration(seconds: timeoutInSeconds));
        print(' Majannah headers $_mainHeadersMain');
        debugPrint('====> API  Fund : - response data v${_response.body}');
        return handleResponse(_response, uri);
      } catch (e) {
        return Response(statusCode: 1, statusText: noInternetMessage);
      }
    }
  }

  Future<Response> getDataApi(String uri) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    } else {
      try {
        print('testing  modeee==== ${_mainHeadersMain}');

        Http.Response _response = await Http.get(
          Uri.parse(ApiConstants.baseUrl + uri),
          headers: _mainHeadersMain,
        ).timeout(Duration(seconds: timeoutInSeconds));
        print(' Majannah headers $_mainHeadersMain');
        debugPrint('====> API  Fund : - response data v${_response.body}');
        return handleResponse(_response, uri);
      } catch (e) {
        return Response(statusCode: 1, statusText: noInternetMessage);
      }
    }
  }

  Future<Response> getApi(String uri) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    } else {
      try {
        print('====> GetX Base URL: $ApiConstants.baseUrl');
        print('====> GetX Call : $uri');

        print(' url $uri');
        Http.Response _response = await Http.get(
          Uri.parse(ApiConstants.baseUrl + uri),
          headers: {"Accept": 'application/json'},
        ).timeout(Duration(seconds: timeoutInSeconds));

        debugPrint('====> API  Fund : - response data v${_response.body}');
        return handleResponse(_response, uri);
      } catch (e) {
        return Response(statusCode: 1, statusText: noInternetMessage);
      }
    }
  }

  Future<Response> getData(String uri) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    } else {
      try {
        debugPrint('====> API Call: $uri\nHeader: $_mainHeadersMain');
        print(' Majannaha headers $_mainHeadersMain');
        print(' url $uri');
        Http.Response _response = await Http.get(
          Uri.parse(ApiConstants.baseUrl + uri),
          headers: _mainHeadersMain,
        ).timeout(Duration(seconds: timeoutInSeconds));
        print(' Majannah headers $_mainHeadersMain');
        debugPrint('====> API  Fund : - response data v${_response.body}');
        return handleResponse(_response, uri);
      } catch (e) {
        return Response(statusCode: 1, statusText: noInternetMessage);
      }
    }
  }

  Response handleResponse(Http.Response response, String uri) {
    dynamic _body;
    try {
      _body = jsonDecode(response.body);
    } catch (e) {}
    Response _response = Response(
      // ignore: prefer_if_null_operators
      body: _body != null ? _body : response.body,
      bodyString: response.body.toString(),
      request: Request(
        headers: response.request!.headers,
        method: response.request!.method,
        url: response.request!.url,
      ),
      headers: response.headers,
      statusCode: response.statusCode,
      statusText: response.reasonPhrase,
    );
    if (_response.statusCode != 200 &&
        _response.body != null &&
        _response.body is! String) {
      // if (_response.body.toString().startsWith('{errors: [{code:')) {
      //   ErrorResponse errorResponse = ErrorResponse.fromJson(_response.body);
      //   _response = Response(
      //       statusCode: _response.statusCode,
      //       body: _response.body,
      //       statusText: errorResponse.errors[0].message);
      // } else if (_response.body.toString().startsWith('{message')) {
      //   _response = Response(
      //       statusCode: _response.statusCode,
      //       body: _response.body,
      //       statusText: _response.body['message']);
      // }
    } else if (_response.statusCode != 200 && _response.body == null) {
      _response = Response(statusCode: 0, statusText: noInternetMessage);
    }
    debugPrint(
      '====> API Response: [${_response.statusCode}] $uri\n${_response.body}',
    );
    return _response;
  }
}
