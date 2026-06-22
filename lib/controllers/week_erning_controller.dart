import 'package:get/get.dart';
import '../model/weekerning_model.dart';

class WeeklyEarningController extends GetxController {
  var weekList = <WeekEarningModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadWeeks();
  }

  void loadWeeks() {
    weekList.addAll([
      WeekEarningModel(
        title: "June 22 - June 28",
        totalAmount: 850,
        dailyEarning: [0, 200, 300, 0, 250, 280, 0],
        dates: [22, 23, 24, 25, 26, 27, 28],
      ),
      WeekEarningModel(
        title: "June 15 - June 21",
        totalAmount: 1204,
        dailyEarning: [300, 250, 200, 0, 180, 0, 270],
        dates: [15, 16, 17, 18, 19, 20, 21],
      ),
      WeekEarningModel(
        title: "June 8 - June 14",
        totalAmount: 670,
        dailyEarning: [0, 150, 0, 200, 180, 0, 140],
        dates: [8, 9, 10, 11, 12, 13, 14],
      ),
    ]);
  }
}