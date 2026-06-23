class EditVehicleDocumentModel {
  String? code;
  String? message;
  String? verificationStatus;
  EditVehicleData? data;

  EditVehicleDocumentModel(
      {this.code, this.message, this.verificationStatus, this.data});

  EditVehicleDocumentModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    verificationStatus = json['verification_status'];
    data = json['data'] != null ? EditVehicleData.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['code'] = code;
    data['message'] = message;
    data['verification_status'] = verificationStatus;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class EditVehicleData {
  List<int>? vehicleId;
  List<DriverDoc>? driverDoc;
  List<VehicleDoc>? vehicleDoc;

  EditVehicleData({this.vehicleId, this.driverDoc, this.vehicleDoc});

  EditVehicleData.fromJson(Map<String, dynamic> json) {
    vehicleId = json['vehicle_id'].cast<int>();
    if (json['driver_doc'] != null) {
      driverDoc = <DriverDoc>[];
      json['driver_doc'].forEach((v) {
        driverDoc!.add(DriverDoc.fromJson(v));
      });
    }
    if (json['vehicle_doc'] != null) {
      vehicleDoc = <VehicleDoc>[];
      json['vehicle_doc'].forEach((v) {
        vehicleDoc!.add(VehicleDoc.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['vehicle_id'] = vehicleId;
    if (driverDoc != null) {
      data['driver_doc'] = driverDoc!.map((v) => v.toJson()).toList();
    }
    if (vehicleDoc != null) {
      data['vehicle_doc'] = vehicleDoc!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class DriverDoc {
  int? id;
  int? documentId;
  String? documentName;
  String? documentNumber;
  String? status;
  dynamic remark;
  String? file;

  DriverDoc(
      {this.id,
      this.documentId,
      this.documentName,
      this.documentNumber,
      this.status,
      this.remark,
      this.file});

  DriverDoc.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    documentId = json['document_id'];
    documentName = json['document_name'];
    documentNumber = json['document_number'];
    status = json['status'];
    remark = json['remark'];
    file = json['file'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['document_id'] = documentId;
    data['document_name'] = documentName;
    data['document_number'] = documentNumber;
    data['status'] = status;
    data['remark'] = remark;
    data['file'] = file;
    return data;
  }
}



class VehicleDoc {
  int? id;
  int? documentId;
  String? documentName;
  String? documentNumber;
  String? status;
  String? remark;
  String? file;

  VehicleDoc({
    this.id,
    this.documentId,
    this.documentName,
    this.documentNumber,
    this.status,
    this.remark,
    this.file,
  });

  VehicleDoc.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    documentId = json['document_id'];
    documentName = json['document_name'];
    documentNumber = json['document_number'];
    status = json['status'];
    remark = json['remark'];
    file = json['file'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['id'] = id;
    data['document_id'] = documentId;
    data['document_name'] = documentName;
    data['document_number'] = documentNumber;
    data['status'] = status;
    data['remark'] = remark;
    data['file'] = file;
    return data;
  }
}
