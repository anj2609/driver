class BankDetailModel {
  int? code;
  String? message;
  BankDetailListData? data;

  BankDetailModel({
    this.code,
    this.message,
    this.data,
  });

  BankDetailModel.fromJson(Map<String, dynamic> json) {
    code = int.tryParse(json['code'].toString());
    message = json['message'];

    data = json['data'] != null
        ? BankDetailListData.fromJson(json['data'])
        : null;
  }
}

class BankDetailListData {
  String? accountHolderName;
  String? accountNumber;
  String? ifscCode;
  String? bankName;
  int? bankVerified;

  BankDetailListData({
    this.accountHolderName,
    this.accountNumber,
    this.ifscCode,
    this.bankName,
    this.bankVerified,
  });

  BankDetailListData.fromJson(Map<String, dynamic> json) {
    accountHolderName = json['account_holder_name']?.toString();
    accountNumber = json['account_number']?.toString();
    ifscCode = json['ifsc_code']?.toString();
    bankName = json['bank_name']?.toString();

    bankVerified = int.tryParse(
      json['bank_verified'].toString(),
    );
  }
}