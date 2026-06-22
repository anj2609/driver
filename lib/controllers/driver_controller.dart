import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';

class DriveController extends GetxController {
  var isRideStarted = false.obs;
  var isRideCompleted = false.obs; // ✅ new variable

  var timeText = "5:49".obs;
  var rating = 0.obs;

  var selectedTags = <String>[].obs;

  void startRide() {
    isRideStarted.value = true;
    isRideCompleted.value = false;
  }

  void completeRide() {
    isRideStarted.value = false;
    isRideCompleted.value = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      Get.toNamed(RouteHelper.getbookingTripDetailsScreen());
    });
  }

  void updateRating(int value) {
    rating.value = value;
  }

  void submitRating() {
    print("Rating Submitted: ${rating.value}");
    Get.back(); 
  }

  void toggleTag(String tag) {
    if (selectedTags.contains(tag)) {
      selectedTags.remove(tag);
    } else {
      selectedTags.add(tag);
    }
  }

  void skipRating() {
    print("Rating Skipped");
    isRideCompleted.value = false; // reset
    Get.back();
  }
}
