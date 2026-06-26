import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/apis/api_client.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:myridedriverapp/controllers/chat_controller.dart';
import 'package:myridedriverapp/controllers/home_controller.dart';
import 'package:myridedriverapp/controllers/profile_controller.dart';
import 'package:myridedriverapp/repository/auth_repo.dart';
import 'package:myridedriverapp/repository/chat_repo.dart';
import 'package:myridedriverapp/repository/home_repo.dart';
import 'package:myridedriverapp/repository/profile_repo.dart';

import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, Map<String, String>>> init() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  Get.lazyPut(() => sharedPreferences, fenix: true);

  Map<String, Map<String, String>> _languages = Map();
  Get.lazyPut(() => AuthController(authRepo: Get.find()));
  Get.lazyPut<ApiClient>(
    () => ApiClient(sharedPreferences: Get.find()),
    fenix: true,
  );

  Get.lazyPut(
    () => AuthRepo(apiClient: Get.find(), sharedPreferences: Get.find()),
  );
  Get.lazyPut(() => ChatRepo(apiClient: Get.find()));
  Get.lazyPut(() => (apiClient: Get.find(), sharedPreferences: Get.find()));
  
  Get.lazyPut(() => HomeRepo(apiClient: Get.find()), fenix: true);
  Get.lazyPut<HomeController>(
    () => HomeController(homeRepo: Get.find()),
    fenix: true,
  );

  ///Get.lazyPut(() => HomeController(homeRepo: Get.find()));
  Get.lazyPut(() => ChatController(chatRepo: Get.find()));

  Get.lazyPut(() => ProfiileRepo(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => ProfileController(profileRepo: Get.find()), fenix: true);
  return _languages;
}
