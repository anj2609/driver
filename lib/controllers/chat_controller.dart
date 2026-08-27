
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

  /// The real pagination cursor for /chat/messages' `last_id` param — was
  /// hardcoded to the literal string '1' on every single poll, never
  /// advancing. "last_id" reads as "messages after this id", and a cursor
  /// that never moves is very likely why a rider's *second* message
  /// specifically never reached the driver: every 2s poll kept asking for
  /// "everything after id 1" and the backend most plausibly answers that
  /// with a bounded window anchored there, not the true growing tail of
  /// the conversation. Advanced to the highest message id actually seen
  /// after each fetch.
  int _lastFetchedMessageId = 0;

  /// Preset "quick reply" strings from /driver-chat-master-list — tapping
  /// one sends it exactly like a typed message. Fetched once per screen
  /// visit; this is effectively static content, not something that changes
  /// mid-conversation.
  List<String> quickMessages = [];
  bool isQuickMessagesLoading = false;

  Future<void> loadQuickMessages() async {
    isQuickMessagesLoading = true;
    update();
    try {
      final response = await chatRepo.quickMessagesList();
      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'].toString() == '200' &&
          response.body['data'] is List) {
        quickMessages = (response.body['data'] as List)
            .map((e) => e is Map ? (e['value']?.toString() ?? '') : e.toString())
            .where((v) => v.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('Quick messages fetch error: $e');
    } finally {
      isQuickMessagesLoading = false;
      update();
    }
  }

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

      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");

      final startChatCode =
          response.body is Map ? response.body['code']?.toString() : null;
      if (response.statusCode == 200 &&
          response.body != null &&
          startChatCode == '200') {
        if (response.body['data'] != null &&
            response.body['data']['id'] != null) {
          final newChatId = response.body['data']['id'].toString();

          // A genuinely different chat (a new ride's conversation, not a
          // re-fetch of the one already open) — the previous thread's
          // messages and pagination cursor belong to that other chat, not
          // this one, and would otherwise bleed across rides.
          if (chatId != null && chatId != newChatId) {
            chatMessagesList.clear();
            _lastFetchedMessageId = 0;
          }
          chatId = newChatId;

          debugPrint("Created Chat Id: $chatId");
        }

        update();
        return response;
      } else if (response.body != null && startChatCode == '401') {
        debugPrint("Unauthorized request");
        return response;
      } else {
        debugPrint("Chat creation failed");
        return response;
      }
    } catch (e) {
      debugPrint("Start Chat Error: $e");

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

      final sendChatCode =
          response.body is Map ? response.body['code']?.toString() : null;
      if (response.statusCode == 200 &&
          response.body != null &&
          sendChatCode == '200') {
        final resp = response.body;
        final data = resp['data'] is Map ? resp['data'] as Map : null;

        // Only overwrites chatId when the response actually supplies one —
        // never blanks out a known-good id with null. This used to
        // reassign chatId unconditionally (and without null-safety —
        // resp['data']['chat_id'] on a genuinely absent 'data' key would
        // throw) from every send response; if chat_id is ever absent on
        // some sends, chatId silently went null right there, and every
        // subsequent chatessagesList() call — chat_id=null in the query
        // string — came back empty from then on. That matches "messages
        // stop after a couple back and forth" exactly.
        final newChatId = data?['chat_id']?.toString();
        if (newChatId != null && newChatId.isNotEmpty) {
          chatId = newChatId;
        }
        senderId = data?['sender_id']?.toString();
        messagesDate = data?['created_at']?.toString();
        isRead = data?['is_read'];

        debugPrint('[Chat] sendChatMessages ok — chatId now: $chatId');

        if (context.mounted) {
          await chatessagesList(context: context);
        }

        update();
        return response;
      } else if (response.body != null && sendChatCode == '401') {
        return response;
      } else {
        return response;
      }
    } catch (e) {
      debugPrint('Send Message Error: $e');
      rethrow;
    }
  }

  /////===============  Chat Messages Lists  =============================
  Future<Response> chatessagesList({required BuildContext context}) async {
   // isLoading = true;
    update();

    // Traced unconditionally (not just on failure) — this endpoint is the
    // one thing standing between "messages exist" and "they show up on
    // screen", and a null/stale chatId here silently returns nothing with
    // no error to catch. Cheap: this runs on the same 2s refresh poll the
    // screen already had.
    debugPrint('[Chat] fetching messages — chatId: $chatId');

    if (chatId == null || chatId!.isEmpty) {
      debugPrint('[Chat] no chatId yet — skipping fetch (startChats may not have completed)');
      update();
      return Response(statusCode: 200, body: {'code': '200', 'data': []});
    }

    try {
      Response response = await chatRepo.chatMessagesLists(
        chatId: chatId,
        lastid: _lastFetchedMessageId.toString(),
      );

      debugPrint(
        '[Chat] messages response (last_id=$_lastFetchedMessageId): '
        'status=${response.statusCode} body=${response.body}',
      );

      if (response.statusCode == 200 &&
          response.body != null &&
          response.body['code'].toString() == "200") {
        MessagesModel messagesModel = MessagesModel.fromJson(response.body);
        final incoming = messagesModel.data ?? [];

        // Merged by id rather than replaced outright — correct whether
        // this endpoint returns the whole thread every time or only
        // messages newer than last_id (the param name says the latter,
        // and it's what a cursor that actually advances is for).
        // Replacing wholesale would have been fine under the first
        // reading but would silently drop history under the second.
        final existingIds = chatMessagesList.map((m) => m.id).toSet();
        for (final msg in incoming) {
          if (!existingIds.contains(msg.id)) {
            chatMessagesList.add(msg);
            existingIds.add(msg.id);
          }
          final id = msg.id;
          if (id != null && id > _lastFetchedMessageId) {
            _lastFetchedMessageId = id;
          }
        }
        chatMessagesList.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));

        debugPrint(
          '[Chat] ${incoming.length} in response, '
          '${chatMessagesList.length} total, cursor now $_lastFetchedMessageId',
        );

        update();

        return response;
      } else if (response.body != null &&
          response.body['code'].toString() == "401") {
        return response;
      } else {
        return response;
      }
    } catch (e) {
      debugPrint('[Chat] fetch error: $e');
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

      if (response.statusCode == 200 &&
          response.body['code']?.toString() == '200') {
        messagesSeen = true;
        update();

        debugPrint("Messages Seen Successfully");
      }

      return response;
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }
}
