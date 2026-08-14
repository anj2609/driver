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

  Map<String, Map<String, String>> languages = {};
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
  // permanent: true is load-bearing, and only GetInstance().lazyPut() exposes
  // it (the Get.lazyPut() extension takes tag/fenix only).
  //
  // GetBuilder decides on mount whether it "created" the controller with
  // `_isCreator = Get.isPrepared<T>()` — which is true for any lazyPut'd
  // controller that hasn't been instantiated yet. So the FIRST
  // GetBuilder<HomeController> to mount claims ownership, and its dispose()
  // then runs `GetInstance().delete<HomeController>()` (autoRemove defaults
  // to true). With fenix the factory survives, so the next Get.find() hands
  // back a BRAND NEW HomeController — and the app ends up running two of
  // them at once:
  //
  //   * the orphaned one still finishes its in-flight _pollNearbyBookings(),
  //     which calls playRingtone() — and onClose() nulls _playerInstance, so
  //     the lazy getter happily builds it a fresh player. The driver HEARS a
  //     ride request.
  //   * the live one that every widget is actually bound to starts at
  //     incomingTrips = [], so the card renders nothing — exactly the
  //     "[IncomingCard] build() trips=0" in the device log, with the
  //     ringtone playing over it.
  //
  // It also silently reset _rejectedTripIds/_cachedIsBusy on every swap,
  // which is why declined rides could come back. Marking it permanent makes
  // delete() refuse (see GetInstance.delete's `builder.permanent` guard), so
  // there is exactly one HomeController for the life of the process. Still
  // lazy, so nothing here changes when it's first built — no pre-login API
  // calls from onInit().
  GetInstance().lazyPut<HomeController>(
    () => HomeController(homeRepo: Get.find()),
    fenix: true,
    permanent: true,
  );

  ///Get.lazyPut(() => HomeController(homeRepo: Get.find()));
  Get.lazyPut(() => ChatController(chatRepo: Get.find()));

  Get.lazyPut(() => ProfiileRepo(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => ProfileController(profileRepo: Get.find()), fenix: true);
  return languages;
}
