import 'dart:developer';
import 'dart:io';

import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/apis/api_client.dart';
import 'package:myridedriverapp/config/utils/constants.dart';

class ProfiileRepo extends GetxService {
  final ApiClient apiClient;

  ProfiileRepo({required this.apiClient});
  Future<Response> profileRepoApi() async {
    return apiClient.getDataApi(ApiConstants.getUserProfileUrl);
  }

  Future<Response> upatePersonalApi({
    String? name,
    String? email,
    String? gender,
    String? dob,
    String? phonenumber,
    File? profile_image,
    String? old_profile_image,
  }) async {
    if (profile_image != null) {
      return apiClient
          .postMultipartNewSelectProfile(ApiConstants.editProfileUrl, {
            "name": name ?? "",
            "email": email ?? "",
            "gender": gender ?? "",
            "date_of_birth": dob ?? "",
            "phone": phonenumber ?? "",
          }, profile_image);
    } else {
      return apiClient.postMultipartUpdate(ApiConstants.editProfileUrl, {
        "name": name ?? "",
        "email": email ?? "",
        "gender": gender ?? "",
        "date_of_birth": dob ?? "",
        "phone": phonenumber ?? "",
      }, old_profile_image);
    }
  }

  Future<Response> customerAddAddressapi({
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) async {
    return apiClient.myridepostData(ApiConstants.customeraddAddress, {
      "label": label,
      "address": address,
      "lat": lat,
      "lng": lng,
    });
  }

  Future<Response> getcustomeraddress() async {
    return apiClient.getDataApi(ApiConstants.customeraddAddressListApi);
  }

  Future<Response> customerUpdateAddress({
    required String label,
    required String address,
    required double lat,
    required double lng,
    required dynamic id,
  }) async {
    return apiClient.myridepostData(ApiConstants.customeraddAddressUpdate, {
      "label": label,
      "address": address,
      "lat": lat,
      "lng": lng,
      "address_id": id,
    });
  }

  Future<Response> customerDeleteapi({required dynamic id}) async {
    return apiClient.myridepostData(ApiConstants.customeraddAddresdelete, {
      "address_id": id,
    });
  }

  Future<Response> customerConnectSocial({
    required String provider,
    required String access,
  }) async {
    return apiClient.myridepostData(ApiConstants.customerconnectsocial, {
      "provider": provider,
      "access_token": access,
    });
  }

  Future<Response> customerdisconnectSocial({required String provider}) async {
    return apiClient.myridepostData(ApiConstants.customerdisconnectsocial, {
      "provider": provider,
    });
  }

  Future<Response> customerfqlapi({required type}) async {
    return apiClient.getApi('${ApiConstants.customerfqlurl}${type}');
  }

  Future<Response> customerpromocard({required cattype}) async {
    return apiClient.getApi('${ApiConstants.promoslist} ${cattype}');
  }

  Future<Response> getprivacypolicy({required slug}) async {
    return apiClient.getApi('${ApiConstants.cmsdetails}${slug}');
  }

  Future<Response> gettermsandConditions({required slug}) async {
    return apiClient.getApi('${ApiConstants.cmsdetails}${slug}');
  }

  Future<Response> getaboutUs({required slug}) async {
    return apiClient.getApi('${ApiConstants.cmsdetails}${slug}');
  }

  Future<Response> gettermandConditions({required slug}) async {
    return apiClient.getApi('${ApiConstants.cmsdetails}${slug}');
  }

  Future<Response> getsettingDetail() async {
    return apiClient.getApi(ApiConstants.settingDetail);
  }

  Future<Response> getpromoCategorylist() async {
    return apiClient.getApi(ApiConstants.promoscategorylist);
  }

  Future<Response> promoCategorywisedata({required String category}) async {
    return apiClient.myridepostData(ApiConstants.promoslisturl, {
      "category": category,
    });
  }

  Future<Response> promodetails({required String id}) async {
    return apiClient.myridepostData(ApiConstants.promosDetail, {
      "id": id.toString(),
    });
  }

  Future<Response> promoAddCustomerSide({required String promoid}) async {
    return apiClient.myridepostData(ApiConstants.customeraddpromo, {
      "promo_id": promoid.toString(),
    });
  }

  Future<Response> addBankDetails({
    required String holderName,
    required String accountNumber,
    required String ifscCode,
    required String bankName,
  }) async {
    return apiClient.myridepostData(ApiConstants.addBankDetails, {
      "account_holder_name": holderName,
      "account_number": accountNumber,
      "ifsc_code": ifscCode,
      "bank_name": bankName,
    });
  }

  Future<Response> bankVerify() async {
    return apiClient.getDataApi(ApiConstants.bankVerify,
    //  {
    //   "account_holder_name": holderName,
    //   "account_number": accountNumber,
    //   "ifsc_code": ifscCode,
    //   "bank_name": bankName,
    // }
    );
  }

  Future<Response> getNotifications() async {
    return apiClient.getDataApi(ApiConstants.getnotification);
  }

  Future<Response> deleteNotification({required String id}) async {
    return apiClient.myridepostData(ApiConstants.getdeletNofitions, {"id": id});
  }

  Future<Response> deleteNotificationAll() async {
    return apiClient.getData(ApiConstants.getDeleteNotificationAll);
  }

  Future<Response> readNotification({required String id}) async {
    return apiClient.myridepostData(ApiConstants.getReadNotification, {
      "id": id,
    });
  }

  Future<Response> getVehicleDetails() async {
    return apiClient.getData(ApiConstants.getvehicleInfo);
  }

 Future<Response> getBankInfoDetails() async {
    return apiClient.getData(ApiConstants.getBankInfo);
  }


  ///

  Future<Response> driverEaring({
    required String type,
    required String startdate,
    required String enddate,
  }) async {
    return apiClient.myridepostData(ApiConstants.driverEarningHistory, {
      "type": type,
      "start_date": startdate,
      "end_date": enddate,
    });
  }

  Future<Response> driverEaringWithOutDate({
    required String type,
   
  }) async {
    return apiClient.myridepostData(ApiConstants.driverEarningHistory, {
      "type": type,
     
    });
  }
    Future<Response> genrateQrCOde({String? bookingid}) async {
    return apiClient.myridepostData(ApiConstants.genrateQrCode, {
      "booking_id": bookingid.toString(),
    });
  }


  Future<Response> verifyQrCode({String? bookingid}) async {
    return apiClient.myridepostData(ApiConstants.verifyQrPayment, {
      "booking_id": bookingid.toString(),
    });
  }


   Future<Response> getdriverErningActivity() async {
    return apiClient.getData(ApiConstants.driverEarningActivityDetails);
  }


   Future<Response> tripDetailsRideApi({required String bookingId}) async {
    log(' booking $bookingId');
    return apiClient.myridepostData(ApiConstants.tripdetail, {
      "booking_id": bookingId,
    });
  }
 
}
