class MessageReadModel {
  String? code;
  String? message;
  List<ReadData>? data;

  MessageReadModel({this.code, this.message, this.data});

  MessageReadModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];

    if (json['data'] != null) {
      data = <ReadData>[];
      json['data'].forEach((v) {
        data!.add(ReadData.fromJson(v));
      });
    }
  }
}

class ReadData {
  int? id;
  int? bookingId;
  int? driverId;
  int? customerId;
  String? createdAt;
  String? updatedAt;

  ReadData({
    this.id,
    this.bookingId,
    this.driverId,
    this.customerId,
    this.createdAt,
    this.updatedAt,
  });

  ReadData.fromJson(Map<String,dynamic> json){
    id = json['id'];
    bookingId = json['booking_id'];
    driverId = json['driver_id'];
    customerId = json['customer_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }
}