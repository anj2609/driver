import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/request/request.dart';
import 'package:http/http.dart' as http;
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

  ApiClient({required this.sharedPreferences});

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
        if (foundation.kDebugMode) {
          debugPrint('====> GetX Call: $uri');
          debugPrint('====> GetX Body: $body');
          debugPrint('====> GetX Body: ${ApiConstants.baseUrl}');
        }
        debugPrint('====> GetX Basebodyy: $body');
        http.Response httpResp = await http.post(
          Uri.parse(ApiConstants.baseUrl + uri),
          body: jsonEncode(body),
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
          },
          //_mainHeaders,
        ).timeout(Duration(seconds: timeoutInSeconds));
        debugPrint("++++++++++++>>>=====");
        Response response = handleResponse(httpResp, uri);

        if (foundation.kDebugMode) {
          debugPrint(
            '====> API Response: [${response.statusCode}] $uri\n${response.body}',
          );
        }
        debugPrint('====>  respnosee : ${response.body}');
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
      if (foundation.kDebugMode) {
        debugPrint('====> GetX Base URL: $ApiConstants.baseUrl');
        debugPrint('====> GetX Call: $uri');
        debugPrint('====> GetX Body: ${jsonEncode(body)}');
      }
      // Map<String, String> headerschat = {
      //   'id': '${sharedPreferences.getString(ApiConstants.profileid)}',
      //   "authorizationToken":
      //       "${sharedPreferences.getString(ApiConstants.token)}",
      // };

      http.Response httpResp = await http.post(
        Uri.parse(ApiConstants.baseUrl + uri),
        body: jsonEncode(body),
        headers: {..._mainHeadersMain, "Content-Type": "application/json"},
      ).timeout(Duration(seconds: timeoutInSeconds));

      debugPrint("STATUS CODE: ${httpResp.statusCode}");
      debugPrint("RESPONSE BODY: ${httpResp.body}");

      Response response = handleResponse(httpResp, uri);

      return response;
    } catch (e) {
      debugPrint("Ã¢ÂÅ’ ERROR: $e");
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postData(String uri, dynamic body) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }

    try {
      if (foundation.kDebugMode) {
        debugPrint('====> GetX Base URL: $ApiConstants.baseUrl');
        debugPrint('====> GetX Call: $uri');
        debugPrint('====> GetX Body: $body');
      }

      http.Response httpResp = await http.post(
        Uri.parse(ApiConstants.baseUrl + uri),
        body: body,

        /// jsonEncode(body),
        headers: _mainHeadersMain,
      ).timeout(Duration(seconds: timeoutInSeconds));

      debugPrint("STATUS CODE: ${httpResp.statusCode}");
      debugPrint("RESPONSE BODY: ${httpResp.body}");
      debugPrint(" BODY: $_mainHeadersMain");

      Response response = handleResponse(httpResp, uri);

      if (foundation.kDebugMode) {
        debugPrint(
          '====> API Response: [${response.statusCode}] $uri\n${response.body}',
        );
      }

      return response;
    } catch (e) {
      debugPrint("Ã¢ÂÅ’ ERROR: $e");
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
      // debugPrint('testing body::: $headers');

      http.Response httpResponse = await http.post(
        Uri.parse(ApiConstants.baseUrl + uri),
        body: body,

        ///jsonEncode(body),
        headers: _mainHeadersMain,
      ).timeout(Duration(seconds: timeoutInSeconds));

      debugPrint("STATUS: ${httpResponse.statusCode}");
      debugPrint("BODY: ${httpResponse.body}");
      debugPrint("header: $_mainHeadersMain");
      debugPrint("parms: $body");

      return handleResponse(httpResponse, uri);
    } catch (e, s) {
      debugPrint("ERROR: $e");
      debugPrint("STACK: $s");
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> myridepostData(String uri, dynamic body) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'You are using VPN');
    }
    debugPrint('complete ||| $body');
    try {
      http.Response httpResponse = await http.post(
        Uri.parse(ApiConstants.baseUrl + uri),
        body: body,

        ///jsonEncode(body),
        headers: _mainHeadersMain,
      ).timeout(Duration(seconds: timeoutInSeconds));
      debugPrint("body: $_mainHeadersMain");
      debugPrint("STATUS: ${httpResponse.statusCode}");
      debugPrint("BODY: ${httpResponse.body}");
      debugPrint('testing |||| $_mainHeadersMain');

      return handleResponse(httpResponse, uri);
    } catch (e, s) {
      debugPrint("ERROR: $e");
      debugPrint("STACK: $s");
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

      if (images != null && images.isNotEmpty) {
        var request = http.MultipartRequest(
          "POST",
          Uri.parse(ApiConstants.baseUrl + uri),
        );

        /// Ã°Å¸â€Â¹ Text Fields
        body.forEach((key, value) {
          request.fields[key] = value.toString();
        });

        for (int i = 0; i < images.length; i++) {
          request.files.add(
            await http.MultipartFile.fromPath("images[]", images[i].path),
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
        var response = await http.Response.fromStream(streamedResponse);

        return handleResponse(response, uri);
      }

      http.Response httpResponse = await http.post(
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
      debugPrint("ERROR: $e");
      debugPrint("STACK: $s");
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
      debugPrint(' testing  header $headers');

      var request = http.MultipartRequest(
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
            await http.MultipartFile.fromPath(
              "documents[$i][file]",
              documentList[i].documentImage!.path,
            ),
          );

          debugPrint("Uploading file path: ${documentList[i].documentImage!.path}");
        }

        debugPrint("ID: ${request.fields["documents[$i][document_id]"]}");
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      debugPrint('testing  |||||||||| $response');
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

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.baseUrl + uri),
      );

      request.headers.addAll(headers);

      for (int i = 0; i < documentList.length; i++) {
        final doc = documentList[i];

        request.fields["documents[$i][document_id]"] = doc.documentId;

        request.fields["documents[$i][document_number]"] =
            doc.documentNumber;

        if (doc.expiryDate.isNotEmpty) {
          request.fields["documents[$i][expiry_date]"] = doc.expiryDate;
        }

        if (doc.documentImage != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              "documents[$i][file]",
              doc.documentImage!.path,
            ),
          );
        }

        /// debug logs
        debugPrint("Doc[$i] ID: ${doc.documentId}");
        debugPrint("Doc[$i] Number: ${doc.documentNumber}");
        debugPrint("Doc[$i] Expiry: ${doc.expiryDate}");
        debugPrint("Doc[$i] File: ${doc.documentImage?.path}");
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      return handleResponse(response, uri);
    } catch (e) {
      debugPrint("API ERROR Ã°Å¸â€˜â€° $e");
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

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.baseUrl + uri),
      );

      request.headers.addAll(_mainHeadersMain);

      for (int i = 0; i < vehicleDocumentList.length; i++) {
        debugPrint(
          'Suchi test Vehicle Id ${request.fields['vehicle_id'] = vehicleDocumentList[i].vehicleId.toString()}',
        );
        request.fields['vehicle_id'] = vehicleDocumentList[i].vehicleId
            .toString();
        request.fields["documents[$i][document_id]"] = vehicleDocumentList[i]
            .documentId
            .toString();

        request.fields["documents[$i][document_number]"] =
            vehicleDocumentList[i].documentNumber;

        request.fields["documents[$i][expiry_date]"] =
            vehicleDocumentList[i].expiryDate;

        /// File Upload
        if (vehicleDocumentList[i].documentImage != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              "documents[$i][file]",
              vehicleDocumentList[i].documentImage!.path,
            ),
          );

          debugPrint(
            "Uploading file path: ${vehicleDocumentList[i].documentImage!.path}",
          );
        }

        debugPrint("ID: ${vehicleDocumentList[i].documentId}");
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      return handleResponse(response, uri);
    } catch (e) {
      debugPrint("Error: $e");
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

      var request = http.MultipartRequest(
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
            vehicleDocumentList[i].documentNumber;

        request.fields["documents[$i][expiry_date]"] =
            vehicleDocumentList[i].expiryDate;

        /// File Upload
        if (vehicleDocumentList[i].documentImage != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              "documents[$i][file]",
              vehicleDocumentList[i].documentImage!.path,
            ),
          );

          debugPrint(
            "Uploading file path: ${vehicleDocumentList[i].documentImage!.path}",
          );
        }

        debugPrint("ID: ${vehicleDocumentList[i].documentId}");
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      return handleResponse(response, uri);
    } catch (e) {
      debugPrint("Error: $e");
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

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.baseUrl + uri),
      );

      request.headers.addAll(headers);

      request.fields.addAll(body);

      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_image', imageFile.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

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

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.baseUrl + uri),
      );

      request.headers.addAll(_mainHeadersMain);

      request.fields.addAll(body);

      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_image', imageFile.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

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
      debugPrint('testing mode $imageFile');
      var request = http.MultipartRequest(
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
          /// Ã°Å¸â€Â¥ FORMAT CHECK
          if (!isValidImageFormat(imageFile)) {
            return Response(
              statusCode: 0,
              statusText: "Only JPG, JPEG, PNG, WEBP allowed",
            );
          }

          /// Ã°Å¸â€Â¥ COMPRESS
          File finalFile = await compressImageUnder2MB(imageFile);

          int finalSize = await finalFile.length();
          debugPrint("Ã¢Å“â€¦ FINAL SIZE: ${finalSize / 1024} KB");

          if (finalSize > 2048 * 1024) {
            return Response(
              statusCode: 0,
              statusText: "Image must be less than 2MB",
            );
          }

          request.files.add(
            await http.MultipartFile.fromPath('profile_image', finalFile.path),
          );
        } else if (imageFile is String) {
          request.fields['old_profile_image'] = imageFile;
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return handleResponse(response, uri);
    } catch (e, st) {
      debugPrint('Multipart error: $e\n$st');
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postDataMap(String uri, dynamic body) async {
    if (await ApiChecker.isVpnActive()) {
      return Response(statusCode: -1, statusText: 'you are using vpn');
    }
    {
      try {
        if (foundation.kDebugMode) {
          debugPrint('====> GetX Base URL: $ApiConstants.baseUrl');
          debugPrint('====> GetX Call: $uri');
          debugPrint('====> GetX Body: $body');
        }
        debugPrint('====> GetX Basebodyy: $body');
        http.Response httpResp = await http.post(
          Uri.parse(ApiConstants.baseUrl + uri),
          body: body,
          headers: _mainHeadersMain,
        ).timeout(Duration(seconds: timeoutInSeconds));
        debugPrint("++++++++++++>>>=====");
        Response response = handleResponse(httpResp, uri);

        if (foundation.kDebugMode) {
          debugPrint(
            '====> API Response: [${response.statusCode}] $uri\n${response.body}',
          );
        }
        debugPrint('====>  respnosee : ${response.body}');
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

        http.Response httpResp = await http.get(
          Uri.parse(ApiConstants.baseUrl + uri),
          headers: _mainHeadersMain,
        ).timeout(Duration(seconds: timeoutInSeconds));
        debugPrint(' Majannah headers $_mainHeadersMain');
        debugPrint('====> API  Fund : - response data v${httpResp.body}');
        return handleResponse(httpResp, uri);
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
        debugPrint('testing  modeee==== $_mainHeadersMain');

        http.Response httpResp = await http.get(
          Uri.parse(ApiConstants.baseUrl + uri),
          headers: _mainHeadersMain,
        ).timeout(Duration(seconds: timeoutInSeconds));
        debugPrint(' Majannah headers $_mainHeadersMain');
        debugPrint('====> API  Fund : - response data v${httpResp.body}');
        return handleResponse(httpResp, uri);
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
        debugPrint('====> GetX Base URL: $ApiConstants.baseUrl');
        debugPrint('====> GetX Call : $uri');

        debugPrint(' url $uri');
        http.Response httpResp = await http.get(
          Uri.parse(ApiConstants.baseUrl + uri),
          headers: {"Accept": 'application/json'},
        ).timeout(Duration(seconds: timeoutInSeconds));

        debugPrint('====> API  Fund : - response data v${httpResp.body}');
        return handleResponse(httpResp, uri);
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
        debugPrint(' Majannaha headers $_mainHeadersMain');
        debugPrint(' url $uri');
        http.Response httpResp = await http.get(
          Uri.parse(ApiConstants.baseUrl + uri),
          headers: _mainHeadersMain,
        ).timeout(Duration(seconds: timeoutInSeconds));
        debugPrint(' Majannah headers $_mainHeadersMain');
        debugPrint('====> API  Fund : - response data v${httpResp.body}');
        return handleResponse(httpResp, uri);
      } catch (e) {
        return Response(statusCode: 1, statusText: noInternetMessage);
      }
    }
  }

  Response handleResponse(http.Response response, String uri) {
    dynamic _body;
    try {
      _body = jsonDecode(response.body);
    } catch (e) {}
    Response httpResp = Response(
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
    if (httpResp.statusCode != 200 &&
        httpResp.body != null &&
        httpResp.body is! String) {
      // if (httpResp.body.toString().startsWith('{errors: [{code:')) {
      //   ErrorResponse errorResponse = ErrorResponse.fromJson(httpResp.body);
      //   httpResp = Response(
      //       statusCode: httpResp.statusCode,
      //       body: httpResp.body,
      //       statusText: errorResponse.errors[0].message);
      // } else if (httpResp.body.toString().startsWith('{message')) {
      //   httpResp = Response(
      //       statusCode: httpResp.statusCode,
      //       body: httpResp.body,
      //       statusText: httpResp.body['message']);
      // }
    } else if (httpResp.statusCode != 200 && httpResp.body == null) {
      httpResp = Response(statusCode: 0, statusText: noInternetMessage);
    }
    debugPrint(
      '====> API Response: [${httpResp.statusCode}] $uri\n${httpResp.body}',
    );
    return httpResp;
  }
}
