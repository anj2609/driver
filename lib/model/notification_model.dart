class NotificationModel {
  String? code;
  String? message;
  List<NotificationDetailsModel>? data;

  NotificationModel({this.code, this.message, this.data});

  NotificationModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    if (json['data'] != null) {
      data = <NotificationDetailsModel>[];
      json['data'].forEach((v) {
        data!.add(new NotificationDetailsModel.fromJson(v));
      });
    }
  }
}

///NotificationModel

class NotificationDetailsModel {
  String? id;
  String? type;
  String? message;
  String? isRead;
  String? date;

  NotificationDetailsModel({
    this.id,
    this.type,
    this.message,
    this.isRead,
    this.date,
  });

  NotificationDetailsModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    type = json['type'];
    message = json['message'];
    isRead = json['is_read'];
    date = json['date'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['type'] = this.type;
    data['message'] = this.message;
    data['is_read'] = this.isRead;
    data['date'] = this.date;
    return data;
  }
}
