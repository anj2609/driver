import 'dart:io';

class DriverDocumentUploadModel {
  String documentId;
  String documentNumber;
  String expiryDate;
  File? documentImage;

  DriverDocumentUploadModel({
    required this.documentId,
    required this.documentNumber,
    required this.expiryDate,
    this.documentImage,
  });
}




class UpdateVehicleDocumentUploadModels {
  String documentId;
  String vehicleId;
  String documentNumber;
  String expiryDate;
  File? documentImage;

  UpdateVehicleDocumentUploadModels({
    required this.documentId,
    required this.vehicleId,
    required this.documentNumber,
    required this.expiryDate,
    this.documentImage,
  });
}