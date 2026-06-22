class ProfileModels {
  String? code;
  String? message;
  ProfileData? data;

  ProfileModels({this.code, this.message, this.data});

  ProfileModels.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? ProfileData.fromJson(json['data']) : null;
  }
}

class ProfileData {
  int? id;
  String? apiToken;
  String? name;
  String? phone;
  String? email;
  String? userType;
  String? gender;
  String? dateOfBirth;
  String? profileImage;

  ProfileData({
    this.id,
    this.apiToken,
    this.name,
    this.phone,
    this.email,
    this.userType,
    this.gender,
    this.dateOfBirth,
    this.profileImage,
  });

  ProfileData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    apiToken = json['api_token'];
    name = json['name'];
    phone = json['phone'];
    email = json['email'];
    userType = json['user_type'];
    gender = json['gender'];
    dateOfBirth = json['date_of_birth'];
    profileImage = json['profile_image'];
  }
}
