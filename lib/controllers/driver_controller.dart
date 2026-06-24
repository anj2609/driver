import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';

class DriveController extends GetxController {
  var isRideStarted = false.obs;
  var isRideCompleted = false.obs;

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
    // Reset state
    rating.value = 0;
    selectedTags.clear();
    isRideCompleted.value = false;
    isRideStarted.value = false;
    // Navigate to home — close the bottom sheet first, then ensure we're on home
    Get.back();
    // If we're already on the home screen (from rideCompletedMarked), just stay there.
    // If not, navigate to home.
    if (Get.currentRoute != RouteHelper.homescreen) {
      Get.offAllNamed(RouteHelper.getHomeScreen());
    }
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
    // Reset state
    rating.value = 0;
    selectedTags.clear();
    isRideCompleted.value = false;
    isRideStarted.value = false;
    // Close the bottom sheet
    Get.back();
    // If we're already on the home screen, stay there. Otherwise navigate.
    if (Get.currentRoute != RouteHelper.homescreen) {
      Get.offAllNamed(RouteHelper.getHomeScreen());
    }
  }
}
