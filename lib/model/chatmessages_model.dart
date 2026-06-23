class MessagesModel {
  String? code;
  String? message;
  List<ChatMessagesModel>? data;

  MessagesModel({this.code, this.message, this.data});

  MessagesModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    if (json['data'] != null) {
      data = <ChatMessagesModel>[];
      json['data'].forEach((v) {
        data!.add(ChatMessagesModel.fromJson(v));
      });
    }
  }
}

class ChatMessagesModel {
  int? id;
  int? chatId;
  int? senderId;
  String? message;
  String? type;
  int? isRead;
  int? status;
  String? createdAt;
  dynamic updatedAt;

  ChatMessagesModel({
    this.id,
    this.chatId,
    this.senderId,
    this.message,
    this.type,
    this.isRead,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  ChatMessagesModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    chatId = json['chat_id'];
    senderId = json['sender_id'];
    message = json['message'];
    type = json['type'];
    isRead = json['is_read'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }
}
