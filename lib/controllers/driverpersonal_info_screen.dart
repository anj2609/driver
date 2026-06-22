import 'package:get/get.dart';
import 'package:myridedriverapp/model/driver_model.dart';


class DriverController extends GetxController {
  var currentStep = 0.obs;
  var driverData = DriverModel().obs;

  void nextStep() {
    if (currentStep.value < 3) {
      currentStep.value++;
    }
  }

  void previousStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
    }
  }

  void goToStep(int step) {
    currentStep.value = step;
  }

  void addDocument(String type, String number) {
    driverData.value.documents.add({
      "type": type,
      "number": number,
    });
    driverData.refresh();
  }
}