class VehicleModel {
  String? code;
  String? message;
  VehicleDetailsData? data;

  VehicleModel({this.code, this.message, this.data});

  VehicleModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? VehicleDetailsData.fromJson(json['data']) : null;
  }


}

class VehicleDetailsData {
  String? vehicleNumber;
  String? brand;
  String? model;
  dynamic chassisNumber;
  dynamic engineNumber;
  dynamic manufactureYear;
  String? color;
  List<String>? images;
  // The vehicle type category (Car/Bike/etc.) id — still needed by the
  // vehical-info endpoint's payload on every submit, create or edit.
  dynamic vehicleTypeId;
  // The category's display name (Car/Bike/Auto/Electric Auto/...), used to
  // pick the right marker icon for this driver's own vehicle on the map
  // (see vehicle_marker_assets.dart). Only set when vehicle_type comes back
  // as a nested {id, name, ...} object rather than a bare id — profile_
  // controller.dart falls back to resolving the name from vehicleTypeId
  // against the vehicle-type list when this is null.
  String? vehicleTypeName;
  // The vehicle's own record id, now returned by get-vehicle-info. Sending
  // this back on an edit is what lets the backend treat the submission as
  // an update to this exact vehicle instead of validating it as a new one
  // (which previously rejected the driver's own unchanged vehicle number
  // as "already taken").
  dynamic vehicleId;

  VehicleDetailsData(
      {this.vehicleNumber,
      this.brand,
      this.model,
      this.chassisNumber,
      this.engineNumber,
      this.manufactureYear,
      this.color,
      this.images,
      this.vehicleTypeId,
      this.vehicleTypeName,
      this.vehicleId});

  VehicleDetailsData.fromJson(Map<String, dynamic> json) {
    vehicleNumber = json['vehicle_number'];
    brand = json['brand'];
    model = json['model'];
    chassisNumber = json['chassis_number'];
    engineNumber = json['engine_number'];
    manufactureYear = json['manufacture_year'];
    color = json['color']?.toString();
    // Was `json['images'].cast<String>()` with no null-guard — a vehicle
    // with no photos yet (or the backend simply omitting the field) sends
    // `images: null`, and calling .cast() on that throws immediately
    // inside fromJson(). Since getVehicleDetailsApi() has no try/catch,
    // that exception fired between isVehicleLoading = true and = false,
    // leaving it stuck true forever — the Vehicles screen showed a
    // loading spinner permanently and the details never rendered.
    final rawImages = json['images'];
    images = rawImages is List
        ? rawImages.map((e) => e.toString()).toList()
        : [];
    final rawVehicleType = json['vehicle_type'];
    if (rawVehicleType is Map) {
      vehicleTypeId = json['vehicle_type_id'] ?? rawVehicleType['id'];
      vehicleTypeName = rawVehicleType['name']?.toString();
    } else {
      vehicleTypeId = json['vehicle_type_id'] ?? rawVehicleType;
    }
    vehicleId = json['id'] ?? json['vehicle_id'];
  }
}
