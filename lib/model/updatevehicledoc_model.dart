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

  EditVehicleDocumentsModel({
    this.id,
    this.documentId,
    this.name,
    this.number,
    this.expriydate,
    this.status,
    this.remark,
    this.file,
  });

  factory EditVehicleDocumentsModel.fromJson(Map<String, dynamic> json) {
    return EditVehicleDocumentsModel(
      id: json['id'],
      documentId: json['document_id'],
      name: json['document_name'],
      number: json['document_number'],
      expriydate: json['expiry_date'],

      ///expiry_date
      status: json['status'],
      remark: json['remark'],
      file: json['file'],
    );
  }
}
