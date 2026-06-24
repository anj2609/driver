class QrPaymentModel {
  String? code;
  String? message;
  QrPaymentData? data;

  QrPaymentModel({this.code, this.message, this.data});

  QrPaymentModel.fromJson(Map<String, dynamic> json) {
    code = json['code']?.toString();
    message = json['message'];
    data = json['data'] != null ? QrPaymentData.fromJson(json['data']) : null;
  }
}

class QrPaymentData {
  String? qrId;
  String? qrCode;
  String? imageUrl;
  String? amount;
  int? paymentAmount;
  String? status;
  int? closeBy;

  QrPaymentData({
    this.qrId,
    this.qrCode,
    this.imageUrl,
    this.amount,
    this.paymentAmount,
    this.status,
    this.closeBy,
  });

  QrPaymentData.fromJson(Map<String, dynamic> json) {
    qrId = json['qr_id']?.toString();
    qrCode = json['qr_code']?.toString();
    imageUrl = json['image_url']?.toString();
    amount = json['amount']?.toString();
    paymentAmount = json['payment_amount'] is int
        ? json['payment_amount'] as int
        : int.tryParse(json['payment_amount']?.toString() ?? '0');
    status = json['status']?.toString();
    closeBy = json['close_by'] is int
        ? json['close_by'] as int
        : int.tryParse(json['close_by']?.toString() ?? '0');
  }
}
