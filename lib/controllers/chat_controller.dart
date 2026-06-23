
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/model/chatmessages_model.dart';
import 'package:myridedriverapp/repository/chat_repo.dart';

class ChatController extends GetxController {
  final ChatRepo chatRepo;

  ChatController({required this.chatRepo});

  String? chatId;
  String? chatIds;
  String? senderId;
  String? messagesDate;
  int? isRead;

  bool isLoading = false;
  bool messagesSeen = false;

  List<ChatMessagesModel> chatMessagesList = [];
  Future<Response> startChats({
    required BuildContext context,
    required String bookingId,
    required String driverId,
    required String customerId,
  }) async {
    update();

    try {
      Response response = await chatRepo.startChat(
        bookingId: bookingId,
        driverId: driverId,
        customerId: customerId,
      );

      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'] == '200') {
        if (response.body['data'] != null &&
            response.body['data']['id'] != null) {
          chatId = response.body['data']['id'].toString();

          print("Created Chat Id: $chatId");
        }

        update();
        return response;
      } else if (response.body != null && response.body['code'] == '401') {
        print("Unauthorized request");
        return response;
      } else {
        print("Chat creation failed");
        return response;
      }
    } catch (e) {
      print("Start Chat Error: $e");

      return Response(statusCode: 500, statusText: e.toString());
    }
  }

  /////=============== Send Chat Messages =============================
  Future<Response> sendChatMessages({
    required BuildContext context,
    required String bookingId,
    required String driverId,
    required String customerId,
    required String message,
  }) async {
    update();

    try {
      Response response = await chatRepo.sendChat(
        bookingId: bookingId.toString(),
        driverId: driverId.toString(),
        customerId: customerId.toString(),
        chatId: chatId.toString(),
        messages: message.toString(),
      );

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'] == '200') {
        var resp = response.body;

        chatId = resp['data']['chat_id'];
        senderId = resp['data']['sender_id'];
        messagesDate = resp['data']['created_at'];
        isRead = resp['data']['is_read'];
        chatessagesList(context: context);
        

        update();
        return response;
      } else if (response.body != null && response.body['code'] == '401') {
        return response;
      } else {
        return response;
      }
    } catch (e) {
      rethrow;
    }
  }

  /////===============  Chat Messages Lists  =============================
  Future<Response> chatessagesList({required BuildContext context}) async {
   // isLoading = true;
    update();

    try {
      Response response = await chatRepo.chatMessagesLists(
        chatId: chatId,
        lastid: '1',
      );
      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'].toString() == "200") {
        MessagesModel messagesModel = MessagesModel.fromJson(response.body);

        chatMessagesList.clear();
        chatMessagesList.addAll(messagesModel.data ?? []);

        update();

        return response;
      } else if (response.body != null &&
          response.body['code'].toString() == "401") {
        return response;
      } else {
        return response;
      }
    } catch (e) {
      rethrow;
    } finally {
     /// isLoading = false;
      update();
    }
  }

  Future<Response> chatMessageListingSeen({
    required BuildContext context,
  }) async {
    isLoading = true;
    update();

    try {
      Response response = await chatRepo.chatLists();
      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'].toString() == "200") {
        update();

        return response;
      } else if (response.body != null &&
          response.body['code'].toString() == "401") {
        return response;
      } else {
        return response;
      }
    } catch (e) {
      rethrow;
    } finally {
      isLoading = false;
      update();
    }
  }

  Future<Response> messageRead({
    required BuildContext context,
    required String chatId,
  }) async {
    try {
      Response response = await chatRepo.chatRead(chatId: chatId);

      if (response.statusCode == 200 && response.body['code'] == '200') {
        messagesSeen = true;
        update();

        print("Messages Seen Successfully");
      }

      return response;
    } catch (e) {
      print(e);
      rethrow;
    }
  }
}
