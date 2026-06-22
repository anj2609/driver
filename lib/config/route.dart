import 'package:get/get.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/screens/auth/aboutus_screen.dart';
import 'package:myridedriverapp/screens/auth/driverdetails_screen.dart';
import 'package:myridedriverapp/screens/auth/ernwithmyride_screen.dart';
import 'package:myridedriverapp/screens/auth/login_screen.dart';
import 'package:myridedriverapp/screens/auth/otp_screen.dart';
import 'package:myridedriverapp/screens/auth/privacypolicy_screen.dart';
import 'package:myridedriverapp/screens/auth/sign_up_screen.dart';
import 'package:myridedriverapp/screens/auth/socialauth_screen.dart';
import 'package:myridedriverapp/screens/auth/successfull_signup_loader.dart';
import 'package:myridedriverapp/screens/auth/termsandcondtions_model.dart';
import 'package:myridedriverapp/screens/auth/user_ride_signin_screen.dart';
import 'package:myridedriverapp/screens/auth/verfication_screen.dart';
import 'package:myridedriverapp/screens/editScreen/editvehicledocument_screen.dart';
import 'package:myridedriverapp/screens/home/payment_screen.dart';
import 'package:myridedriverapp/screens/home/ridedetails_screen.dart';
import 'package:myridedriverapp/screens/home/startride_screen.dart';
import 'package:myridedriverapp/screens/profile/account_document_screen.dart';
import 'package:myridedriverapp/screens/home/home_screen.dart';
import 'package:myridedriverapp/screens/home/notification_screen.dart';
import 'package:myridedriverapp/screens/profile/account_screen.dart';
import 'package:myridedriverapp/screens/profile/add_bank_screen.dart';
import 'package:myridedriverapp/screens/profile/chat_screen.dart';
import 'package:myridedriverapp/screens/profile/edit_profile.dart';
import 'package:myridedriverapp/screens/profile/vehicles_screen.dart';
import 'package:myridedriverapp/screens/profile/edit_address_screen.dart';
import 'package:myridedriverapp/screens/profile/profile_screen.dart';
import 'package:myridedriverapp/screens/ride/erningmain_activitydashboard_screen.dart';
import 'package:myridedriverapp/screens/ride/erningride_dashboard_screen.dart';
import 'package:myridedriverapp/screens/ride/mainactivity_detail_screen.dart';
import 'package:myridedriverapp/screens/ride/pickup_screen.dart';
import 'package:myridedriverapp/screens/ride/weaklyerning_screen.dart';

import 'package:myridedriverapp/splash/onbording_screen.dart';
import 'package:myridedriverapp/splash/splash_screen.dart';

class RouteHelper {
  static const String splash = '/splash';
  static const String onbordingscreen = '/onbordingscreen';
  static const String login = '/login';
  static const String otpVerification = '/OtpVerificationScreen';
  static const String ernwithmyRide = '/ernwithmyRidelocation';
  static const String signupScreen = '/signupDriverScreen';
  static const String details = '/detailsscreen';
  static const String succussfullLoader = '/RegistrationSuccessScreen';
  static const String verityscreen = '/VerificationLoaderScreen';
  static const String homescreen = '/homeScreen';
  static const String accountscreen = '/accountscreen';
  static const String profilescreen = '/profilescreen';
  static const String rideDetailsscreen = '/rideDetailsscreen';
  static const String notificationScreen = '/notificationScreen';
  static const String erningRidescreen = '/erningRidescreen';
  static const String weaklyErningRidescreen = '/weaklyErningRidescreen';
  static const String customerFareBrarekdownescreen =
      '/customerFareBrarekdownescreen';
  static const String erningMainActivityscreen = '/erningMainActivityscreen';
  static const String mainActivityTripDetails = '/mainActivityTripDetails';
  static const String vehiclesScreen = '/vehiclesScreen';
  static const String accountDocumentsScreen = '/accountDocumentsScreen';
  static const String manageAccountScreen = '/manageAccountScreen';
  static const String editAddressScreen = '/editAddressScreen';
  static const String insuranceScreen = '/insuranceScreen';
  static const String tripNavigationScreen = '/tripNavigationScreen';
  static const String chatDriverChatScreen = '/chatDriverChatScreen';
  static const String startDriverRideScreen = '/startDriverRideScreen';
  static const String bookingTripDetailsScreen = '/bookingTripDetailsScreen';
  static const String myRideLoginScreen = '/myRideLoginScreen';
  static const String earnWithMyRideScreen = '/earnWithMyRideScreen';
  static const String editVehicleDocumentScreen = '/editVehicleDocumentScreen';
  static const String editEditProfileScreen = '/editEditProfileScreen';
  static const String goingForPickupScreen = '/goingForPickupScreen';
  static const String addBankDetailsScreen = '/addBankDetailsScreen';
  static const String privacyPolicyScreen = '/privacyPolicyScreen';
  static const String termsAndConditionScreen = '/termsAndConditionScreen';
  static const String aboutUsScreen = '/aboutUsScreen';
  static const String paymentScreen = '/paymentScreen';
  static const String socialDetailScreen = '/socialDetailScreen';

  static getSplashRoute() => splash;
  static getOnboardingRoute() => onbordingscreen;
  static getLoginRoute() => login;

  static getOtpVerification(String? phoneNumber, String? type) {
    Get.toNamed(
      otpVerification,
      arguments: {"phone": phoneNumber ?? "", "type": type ?? ""},
      // arguments: phoneNumber.toString()
    );
  }

  static getSignupScreen() => signupScreen;
  static getmyRideLoginScreen() => myRideLoginScreen;
  static geternwithMyRide() => ernwithmyRide;
  static getDriverDetails() => details;
  static getsuccussfullLoader() => succussfullLoader;
  static getDoverifyScreen() => verityscreen;
  static getHomeScreen() => homescreen;
  static getAccountScreen() => accountscreen;
  static getProfileScreen() => profilescreen;
  static getRideDetailsScreen() => rideDetailsscreen;
  static getNotificationScreen() => notificationScreen;
  static getErningRideScreen() => erningRidescreen;
  static getWeaklyErningRideScreen() => weaklyErningRidescreen;
  static getCustomerFareBrarekdownScreen() => customerFareBrarekdownescreen;
  static geterningMainactivityScreen() => erningMainActivityscreen;
  static getmainActivityTripDetailsScreen() => mainActivityTripDetails;
  // static getmainActivityTripDetailsScreen(EarningModel data) {
  //   Get.toNamed(mainActivityTripDetails, arguments: data);
  // }

  static getvehiclesScreen() => vehiclesScreen;
  static getaccountDocumentsScreen() => accountDocumentsScreen;
  static getmanageAccountScreen() => manageAccountScreen;
  static geteditAddressScreen() => editAddressScreen;
  static getinsuranceScreen() => insuranceScreen;
  static gettripNavigationScreen() => tripNavigationScreen;
  static getchatDriverChatScreen() => chatDriverChatScreen;
  static getstartDriverRideScreen() => startDriverRideScreen;
  static getbookingTripDetailsScreen() => bookingTripDetailsScreen;
  static getearnWithMyRideScreen() => earnWithMyRideScreen;
  static gethomescreen() => homescreen;
  static getEditVehicleDocumentScreen() => editVehicleDocumentScreen;
  static geteditProfileScreenScreen() => editEditProfileScreen;
  static getgoingForPickupScreen() => goingForPickupScreen;
  static getaddBankDetailsScreen() => addBankDetailsScreen;
  static gettermsAndConditionScreen() => termsAndConditionScreen;
  static getprivacyPolicyScreen() => privacyPolicyScreen;
  static getaboutUsScreen() => aboutUsScreen;
  static getpaymentScreen() => paymentScreen;
  static getsocialDetailScreen() => socialDetailScreen;

  /////// AuthEditVehicleDocumentScreen socialDetailScreen
  /////

  static List<GetPage> routes = [
    GetPage(name: splash, page: () => const SplashScreen()),
    GetPage(
      name: onbordingscreen,
      page: () => OnboardingScreen(),
      transitionDuration: const Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: login,
      page: () => LoginScreen(),
      transitionDuration: const Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: otpVerification,
      page: () {
        final args = Get.arguments as Map<String, String>? ?? {};
        return OtpScreen(
          phoneNumber: args["phone"] ?? "",
          type: args["type"] ?? "",
        );
      },
      // page: () => OtpScreen(),
      transitionDuration: const Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: signupScreen,
      page: () => DriverSignInpScreen(),
      transitionDuration: const Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: ernwithmyRide,
      page: () => EarnWithMyRideScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: details,
      page: () => DetailsScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: socialDetailScreen,
      page: () => SocialDetailScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),

    ///socialDetailScreen
    GetPage(
      name: succussfullLoader,
      page: () => RegistrationSuccessScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    // /succussfullLoader
    GetPage(
      name: verityscreen,
      page: () => VerificationLoaderScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: myRideLoginScreen,
      page: () => MyRideLoginScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),

      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: homescreen,
      page: () => HomeMapScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: accountscreen,
      page: () => AccountScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: profilescreen,
      page: () => ProfileScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: notificationScreen,
      page: () => NotificationScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: erningRidescreen,
      page: () => EarningsScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: weaklyErningRidescreen,
      page: () => WeeklyEarningScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),

    // GetPage(
    //   name: customerFareBrarekdownescreen,
    //   page: () => CustomerFareScreen(),
    //   transitionDuration: Duration(
    //     milliseconds: ApiConstants.screenTransitionTime,
    //   ),
    //   transition: Transition.rightToLeft,
    // ),
    GetPage(
      name: erningMainActivityscreen,
      page: () => EarningActivityScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: mainActivityTripDetails,
      page: () => TripDetailsScreen(bookingId: Get.arguments['bookingid']),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),

      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: vehiclesScreen,
      page: () => VehiclesScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),

      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: accountDocumentsScreen,
      page: () => AccountDocumentsScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),

      transition: Transition.rightToLeft,
    ),
    // GetPage(
    //   name: manageAccountScreen,
    //   page: () => ManageAccountScreen(),
    //   transitionDuration: Duration(
    //     milliseconds: ApiConstants.screenTransitionTime,
    //   ),

    //   transition: Transition.rightToLeft,
    // ),
    GetPage(
      name: editAddressScreen,
      page: () => EditAddressScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),

      transition: Transition.rightToLeft,
    ),
    // GetPage(
    //   name: insuranceScreen,
    //   page: () => InsuranceScreen(),
    //   transitionDuration: Duration(
    //     milliseconds: ApiConstants.screenTransitionTime,
    //   ),

    //   transition: Transition.rightToLeft,
    // ),

    // GetPage(
    //   name: insuranceScreen,
    //   page: () => InsuranceScreen(),
    //   transitionDuration: Duration(
    //     milliseconds: ApiConstants.screenTransitionTime,
    //   ),

    //   transition: Transition.rightToLeft,
    // ),

    // GetPage(
    //   name: tripNavigationScreen,
    //   page: () => TripNavigationTrackScreen(),
    //   transitionDuration: Duration(
    //     milliseconds: ApiConstants.screenTransitionTime,
    //   ),

    //   transition: Transition.rightToLeft,
    // ),
    GetPage(
      name: chatDriverChatScreen,
      page: () => DriverChatScreen(
        isDriverScreen: true,
        bookingId: Get.arguments['id'],
        acceptData: Get.arguments['acceptData'],
        trips: Get.arguments['trips'],
      ),

      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),

      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: startDriverRideScreen,
      page: () => StartDriverRideScreen(
        // trips: Get.arguments['trips'],
        // acceptData: Get.arguments['acceptData'],

        /////trips acceptData
      ),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),

      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: bookingTripDetailsScreen,
      page: () => BookingTripDetailsScreen(
        bookingId: Get.arguments['bookingId'],
        // Get.arguments['trips'],
        // acceptData: Get.arguments['acceptData'],
      ),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),

      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: earnWithMyRideScreen,
      page: () => EarnWithMyRideScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),

      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: editVehicleDocumentScreen,
      page: () => EditVehicleDocumentScreen(
            status: (Get.arguments is Map) ? Get.arguments['status'] : null,
          ),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: editEditProfileScreen,
      page: () => EditProfileScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: goingForPickupScreen,
      page: () => GoingForPickupScreen(
        //trips: Get.arguments['trips']
      ),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: addBankDetailsScreen,
      page: () => AddBankDetailsScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: aboutUsScreen,
      page: () => AboutUsScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: privacyPolicyScreen,
      page: () => PrivacyPolicyScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: termsAndConditionScreen,
      page: () => TermsAndConditionScreen(),
      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: paymentScreen,
      page: () => PaymentScreen(acceptData: Get.arguments['acceptData']),

      transitionDuration: Duration(
        milliseconds: ApiConstants.screenTransitionTime,
      ),
      transition: Transition.rightToLeft,
    ),
  ];
}
