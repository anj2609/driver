
class WeekEarningModel {
  final String title;
  final double totalAmount;
  final List<double> dailyEarning;
  final List<int> dates;

  WeekEarningModel({
    required this.title,
    required this.totalAmount,
    required this.dailyEarning,
    required this.dates,
  });
}