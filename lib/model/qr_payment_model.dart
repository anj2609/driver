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

  /// A real, already-rendered QR *image* (Razorpay's own PNG) — meant to be
  /// displayed as a picture, e.g. Image.network(imageUrl).
  String? imageUrl;

  /// A plain UPI deep-link (upi://pay?...) — meant to be *encoded into* a
  /// QR code this app draws itself, e.g. QrImageView(data: upiLink).
  ///
  /// These two used to be merged into one `imageUrl` field ("use whichever
  /// is present"), and every renderer downstream fed that single field
  /// straight into QrImageView — which draws a QR that *encodes whatever
  /// string it's given*, it doesn't display an image. That's harmless for
  /// upi_link (a link is exactly what's supposed to be encoded into a scan
  /// target), but wrong for image_url: encoding an image *URL* as text
  /// produces a QR that, when scanned, just opens that URL in a browser —
  /// landing on Razorpay's own hosted page — instead of showing the actual
  /// payment QR the backend already rendered. Kept separate so callers can
  /// tell which one they actually have and render it correctly.
  String? upiLink;

  String? amount;
  int? paymentAmount;
  String? status;
  int? closeBy;

  QrPaymentData({
    this.qrId,
    this.qrCode,
    this.imageUrl,
    this.upiLink,
    this.amount,
    this.paymentAmount,
    this.status,
    this.closeBy,
  });

  QrPaymentData.fromJson(Map<String, dynamic> json) {
    qrId = json['qr_id']?.toString();
    qrCode = json['qr_code']?.toString();
    imageUrl = json['image_url']?.toString();
    upiLink = json['upi_link']?.toString();
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
