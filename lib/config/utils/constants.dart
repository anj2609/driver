class ApiConstants {
  //==== base url =====

  static const String baseUrl = 'https://app.nride.in/api/';

  ////========= api End Point ==================================
  static const String sendOtpUrl = 'send-otp';
  static const String verityOtpUrl = 'verify-otp';
  static const String reSendOtp = 're-send';
  static const String loginapi = 'login';
  static const String basicInfo = 'basic-info';
  // Short-lived token from verify-otp for a brand-new driver, used to
  // authenticate their basic-info submission before a real session token.
  static const String signupToken = 'signup_token';
  // The phone number being verified, persisted so basic-info can send it —
  // driverdetails_screen (where basic-info is submitted) is reached with no
  // route argument carrying it, unlike the rider's equivalent screen.
  static const String pendingPhone = 'pending_phone';
  static const String getUserProfileUrl = 'get-profile';
  static const String editProfileUrl = 'update-profile';
  static const String logOutUrl = 'logout';
  static const String socialAuth = 'social-auth';
  static const String estimateUrl = 'estimate-ride-list';
  static const String trackRide = 'track-ride';
  static const String createBooking = 'create-booking';
  static const String tripdetail = 'trip-detail';
  static const String cancelRide = 'cancel-ride';
  static const String rateDriver = 'rate-driver';
  static const String customeraddAddress = 'customer-add-address';
  static const String customeraddAddressListApi = 'customer-address-list';
  static const String customeraddAddressUpdate = 'customer-address-update';
  static const String customeraddAddresdelete = 'customer-address-delete';
  static const String customernotificationsettings =
      'customer-notification-settings';
  static const String customernotificationupdate =
      'customer-notification-settings-update';
  static const String customeraccountsecurity = 'customer-account-security';
  static const String customeraccountsecurityupdate =
      'customer-account-security-update';
  static const String customersocialaccounts = 'customer-social-accounts';
  static const String customerconnectsocial = 'customer-connect-social';
  static const String customerdisconnectsocial = 'customer-disconnect-social';
  static const String customeraddpromo = 'customer-add-promo';
  static const String customerpromolist = 'customer-promo-list';
  static const String driverTracke = 'track-driver'; ////// remaining /////
  static const String customerfqlurl = 'faq-list?type=';
  static const String promoslist = 'promos-list?category=';
  static const String cmsdetails = 'cms-details?slug=';
  static const String settingDetail = 'setting-details';
  static const String promoscategorylist = 'promos-category-list';
  static const String promoslisturl = 'promos-list';
  static const String promosDetail = 'promos-details';

  ///////=================== Driver  app ======================///////////
  ///driver-address
  static const String driveraddress = 'driver-address';
  static const String driverDocument = 'document-list?type=';
  static const String driverUploadDocument = 'driver-document';
  static const String driverDocumentStatus = 'driver-document-status';
  static const String vehicaltypelist = 'vehical-type-list';
  static const String vehicalInfo = 'vehical-info';
  static const String vehicleUploadDocument = 'vehical-document';
  static const String newBookingLUrl = 'new-booking-list';
  static const String acceptRideUrl = 'accept-ride';
  static const String verifyPickupOtpUrl = 'verify-pickup-otp';
  static const String cancelRideByDriverUrl = 'cancel-ride-by-driver';
  static const String driverArrived = 'driver-arrived';
  static const String completeRideUrl = 'complete-ride';
  static const String driverStatus = 'driver-status';
  static const String driverLocationUpdate = 'driver-location-update';
  static const String cancellation = 'cancellation-type-list?type=$driverLogin';
  static const String trackBookingRide = 'track-booking-ride';
  static const String driverBookingActive = 'driver-booking-active';
  static const String addBankDetails = 'add-bank-details';
  static const String bankVerify = 'verify-bank';
  static const String bankStatus = 'bank-status';
  static const String chatStartUrl = 'chat/start';
  static const String chatSendUrl = 'chat/send';
  static const String chatMessages = 'chat/messages?';
  static const String messageList = 'chat/list';
  static const String chatRead = 'chat/read';
  static const String driverWalletBalance = 'driver-wallet-balance';
  static const String driverEarningHistory = 'driver-earning-history';
  static const String driverRequestWithdraw = 'driver-request-withdraw';
  static const String getnotification = 'notification/get';
  static const String getdeletNofitions = 'notification/delete';
  static const String getDeleteNotificationAll = 'notification/delete-all';
  static const String getReadNotification = 'notification/read';
  static const String getvehicleInfo = 'get-vehicle-info';
  static const String genrateQrCode = 'generate-qr-payment';
  static const String verifyQrPayment = 'verify-qr-payment';
  static const String paymentStatus = 'payment-status';
  // Live key_id — safe to ship client-side (that's what key_id is for).
  // Not currently referenced anywhere: razorpay_flutter is a pubspec
  // dependency but the app's actual online-payment flow goes through this
  // app's own generate-qr-payment/verify-qr-payment backend endpoints, not
  // the Razorpay Checkout SDK directly. RAZORPAY_SECRET must never be added
  // here or anywhere in this repo — it belongs only in that backend's own
  // environment/secrets config, never in client code.
  static const String razorpayKeyId = 'rzp_live_TOTCxhsFSNJuPe';
  static const String driverEarningActivityDetails =
      'driver-earning-activity-list';
  static const String getBankInfo = 'get-bank-info';
  ///// get-bank-info

  static const String validateCoupon = 'validate-coupon';
  static const String redeemCoupon = 'redeem-coupon';
  static const String couponHistory = 'coupon-history';

  ///////========= local store data ====================================//////////

  static const String otpapi = 'subscription-add';
  static const int screenTransitionTime = 0;
  static const String theme = 'theme';
  static const String token = 'token';
  static const String profileid = 'id';
  static const String name = 'FirstName';
  static const String vehicleId = 'id';

  //////======================  User  Static Data ==================================
  static const String userType = 'customer';
  // Not lowerCamelCase on purpose — auth_controller.dart's whole
  // register/login type-detection flow references these by this exact
  // capitalization; a prior lint-driven rename only touched this
  // declaration, not its usages, which broke the build.
  static const String UserLogin = 'login';
  static const String driverLogin = 'driver';
  static const String UserRegister = 'register';
  static const String vehicaletype = 'vehical';
  static const String isPersonalSavedStatus = 'ispersonalsaved';
  static const String isPersonalSaved = 'ispersonalsavedKey';
  static const String acceptedtrip = 'trips';
  static const String bookingid = 'bookingid';
  static const String statusCode = 'code';
  static const String tripKey = "tripKey";
  static const String acceptRideKey = "acceptRideKey";
  static String userIdSocial = "";
  static String userTokenSocial = "";
  static const String isDocumentSaved = 'isDocumentsavedKey';
  // Set exactly once — right when the final vehicle-document upload
  // succeeds. Unlike isPersonalSavedStatus/verification_status (which get
  // written at other points too, including with backend-default values for
  // brand-new accounts), this is the one unambiguous "registration fully
  // submitted, now under review" signal splash routing can trust.
  static const String docsSubmittedForReview = 'docs_submitted_for_review';
  static String socialtoken = "";
  static String gmailAddres = "";
  static String userName = "";
  static String profileImage = "";
  static String vehicleIdStore = "";
  static String verificationStatus = "verificationstatus";

  ///verification_status

  // Uploaded files (profile photos, vehicle photos, documents) are served by
  // the same deployment that serves [baseUrl] — anything the app uploads
  // through the API lands there. These previously pointed at
  // myride.infinititechsolution.com, which is a separate server: requesting
  // the same path from each returns a different file (different byte length,
  // different Server header — hcdn vs the API's nginx), so it is a distinct
  // deployment with its own storage, not a CDN edge in front of this one.
  // Anything a driver uploaded through the API was therefore being looked up
  // on a host that had never received it.
  static const String imageurl = 'https://app.nride.in/';
  static const String fileUrl = 'https://app.nride.in/';
  static const String apiKey = 'AIzaSyBNHiJLxFa2qcs079P5TaYrB770_CVMldU';
}

dynamic driverLatitude;
dynamic driverLongitude;
dynamic driverId;

/// Kicked off in main() without being awaited, so Flutter can paint its
/// first frame (and dismiss Android's mandatory native splash) immediately
/// instead of waiting on Firebase/DI setup. Anything that needs Firebase or
/// GetX bindings ready (FCM listeners, Get.find calls) should await this
/// first.
Future<void>? appInitialization;
dynamic driverprofileStatus;
