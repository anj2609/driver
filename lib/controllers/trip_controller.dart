import 'package:get/get.dart';

class TripDetailsController extends GetxController {
  var tripAmount = 28.00.obs;
  var duration = "15 min 34 sec".obs;
  var distance = "6.02 miles".obs;

  var pickupLocation = "Nayasharak Point".obs;
  var pickupAddress = "Nayasharak, Sylhet 3100".obs;

  var dropLocation = "SRS International University".obs;
  var dropAddress = "Baghbari, Delhi 3100".obs;

  var fare = 25.00.obs;
  var tip = 3.00.obs;

  double get total => fare.value + tip.value;
}