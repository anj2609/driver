import 'dart:io';

class VehicleDocumentUploadModels {
  String documentId;
  String vehicleId;
  String documentNumber;
  String expiryDate;
  File? documentImage;

  VehicleDocumentUploadModels({
    required this.documentId,
    required this.vehicleId,
    required this.documentNumber,
    required this.expiryDate,
    this.documentImage,
  });
}
