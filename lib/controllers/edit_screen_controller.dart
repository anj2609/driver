import 'package:get/get.dart';

class EditAddressController extends GetxController {
  var isRidesExpanded = false.obs;
  var isAdditionalExpanded = true.obs;
  var isVehicleExpanded = false.obs;

  void toggleRides() => isRidesExpanded.toggle();
  void toggleAdditional() => isAdditionalExpanded.toggle();
  void toggleVehicle() => isVehicleExpanded.toggle();
}