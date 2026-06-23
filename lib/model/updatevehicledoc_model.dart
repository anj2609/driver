import 'dart:io';

import 'package:flutter/material.dart';

class EditVehicleDocumentsModel {
  int? id;
  int? documentId;
  String? name;
  String? number;
  String? expriydate;
  String? status;
  String? remark;
  String? file;

  TextEditingController numberControllers = TextEditingController();
  TextEditingController expiryControllers = TextEditingController();
  File? imageFiles;

  bool? isRequired;

  EditVehicleDocumentsModel({
    this.id,
    this.documentId,
    this.name,
    this.number,
    this.expriydate,
    this.status,
    this.remark,
    this.file,
    this.isRequired,
  });

  factory EditVehicleDocumentsModel.fromJson(Map<String, dynamic> json) {
    final model = EditVehicleDocumentsModel(
      id: json['id'],
      documentId: json['document_id'],
      name: json['document_name'],
      number: json['document_number'],
      expriydate: json['expiry_date'],
      status: json['status'],
      remark: json['remark'],
      file: json['file'],
    );
    return model;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'document_id': documentId,
        'document_name': name,
        'document_number': numberControllers.text,
        'expiry_date': expiryControllers.text,
        'status': status,
        'remark': remark,
        'file': file,
      };
}
