class PrivacyModel {
  String? code;
  String? message;
  PrivacysModel? data;

  PrivacyModel({this.code, this.message, this.data});

  PrivacyModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? new PrivacysModel.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['code'] = this.code;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class PrivacysModel {
  String? name;
  String? slug;
  String? details;

  PrivacysModel({this.name, this.slug, this.details});

  PrivacysModel.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    slug = json['slug'];
    details = json['details'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['slug'] = this.slug;
    data['details'] = this.details;
    return data;
  }
}
