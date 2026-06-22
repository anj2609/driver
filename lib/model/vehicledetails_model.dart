class VehicleModel {
  String? code;
  String? message;
  VehicleDetailsData? data;

  VehicleModel({this.code, this.message, this.data});

  VehicleModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? new VehicleDetailsData.fromJson(json['data']) : null;
  }


}

class VehicleDetailsData {
  String? vehicleNumber;
  String? brand;
  String? model;
  Null? chassisNumber;
  Null? engineNumber;
  Null? manufactureYear;
  List<String>? images;

  VehicleDetailsData(
      {this.vehicleNumber,
      this.brand,
      this.model,
      this.chassisNumber,
      this.engineNumber,
      this.manufactureYear,
      this.images});

  VehicleDetailsData.fromJson(Map<String, dynamic> json) {
    vehicleNumber = json['vehicle_number'];
    brand = json['brand'];
    model = json['model'];
    chassisNumber = json['chassis_number'];
    engineNumber = json['engine_number'];
    manufactureYear = json['manufacture_year'];
    images = json['images'].cast<String>();
  }

 
}
