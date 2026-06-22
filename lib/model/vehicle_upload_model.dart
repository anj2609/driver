import 'dart:io';

import 'package:flutter/widgets.dart';

class VehicleDocumentModel {
  String? code;
  String? message;
  List<VehicleDocumentDataModel>? data;

  VehicleDocumentModel({this.code, this.message, this.data});

 VehicleDocumentModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    if (json['data'] != null) {
      data = <VehicleDocumentDataModel>[];
      json['data'].forEach((v) {
        data!.add(new VehicleDocumentDataModel.fromJson(v));
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

class VehicleDocumentDataModel {
  int? id;
  String? name;
  String? status;
  bool? isRequired;
  String? type;
  bool? isExpiry;

 File? imageFiles;
  TextEditingController numberControllers = TextEditingController();
  TextEditingController expiryControllers = TextEditingController();
  VehicleDocumentDataModel({
    this.id,
    this.name,
    this.status,
    this.isRequired,
    this.type,
    this.isExpiry,
  });

  VehicleDocumentDataModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    status = json['status'];
    isRequired = json['is_required'];
    type = json['type'];
    isExpiry = json['is_expiry'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['status'] = this.status;
    data['is_required'] = this.isRequired;
    data['type'] = this.type;
    data['is_expiry'] = this.isExpiry;
    return data;
  }
}
