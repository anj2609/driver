import 'package:get/get.dart';

import 'package:myridedriverapp/config/utils/apis/api_client.dart';
import 'package:myridedriverapp/config/utils/constants.dart';

class ChatRepo extends GetxService {
  final ApiClient apiClient;

  ChatRepo({required this.apiClient});

  /////========================= Start Chat API =========================
  Future<Response> startChat({
    String? bookingId,
    String? driverId,
    String? customerId,
  }) async {
    return apiClient.postChatData(ApiConstants.chatStartUrl, {
      "booking_id": bookingId,
      "driver_id": driverId,
      "customer_id": customerId,
    });
  }

  ////// =============================== Send Message  Api ===================

  Future<Response> sendChat({
    String? chatId,
    String? bookingId,
    String? driverId,
    String? customerId,
    String? messages,
  }) async {
    return apiClient.postData(ApiConstants.chatSendUrl, {
      "booking_id": bookingId,
      "driver_id": driverId,
      "customer_id": customerId,
      "message": messages,
      "chat_id": chatId,
      "type": 'text',
    });
  }

  ////// ===============================  Get Chat List  Api ===================

  Future<Response> chatMessagesLists({String? chatId, String? lastid}) async {
    return apiClient.getData(
      '${ApiConstants.chatMessages}chat_id=$chatId&last_id=$lastid',
    );
  }

  ////// ===============================  Get Chat List  Api ===================

  Future<Response> chatLists() async {
    return apiClient.getApi(ApiConstants.messageList);
  }

  ////// ===============================  Chat Read Api ===================

  Future<Response> chatRead({String? chatId}) async {
    return apiClient.postData(ApiConstants.chatRead, {"chat_id": chatId});
  }
}
