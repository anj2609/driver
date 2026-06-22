class VehicalTypeModel {
  String? code;
  String? message;
  List<VehicalTypleData>? data;

  VehicalTypeModel({this.code, this.message, this.data});

  VehicalTypeModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    if (json['data'] != null) {
      data = <VehicalTypleData>[];
      json['data'].forEach((v) {
        data!.add(new VehicalTypleData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['code'] = this.code;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}
////VehicalTypeModel VehicalTypleData
class VehicalTypleData {
  int? id;
  String? name;
  String? baseFare;
  String? perKmRate;
  String? image;
  String? status;
  String? remark;
  String? createdAt;
  String? updatedAt;

  VehicalTypleData({
    this.id,
    this.name,
    this.baseFare,
    this.perKmRate,
    this.image,
    this.status,
    this.remark,
    this.createdAt,
    this.updatedAt,
  });

  VehicalTypleData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    baseFare = json['base_fare'];
    perKmRate = json['per_km_rate'];
    image = json['image'];
    status = json['status'];
    remark = json['remark'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['base_fare'] = this.baseFare;
    data['per_km_rate'] = this.perKmRate;
    data['image'] = this.image;
    data['status'] = this.status;
    data['remark'] = this.remark;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}
