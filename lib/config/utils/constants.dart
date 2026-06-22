class ApiConstants {
  //==== base url =====

  static const String baseUrl = 'https://myride.infinititechsolution.com/api/';

  ////========= api End Point ==================================
  static const String sendOtpUrl = 'send-otp';
  static const String verityOtpUrl = 'verify-otp';
  static const String reSendOtp = 're-send';
  static const String loginapi = 'login';
  static const String basicInfo = 'basic-info';
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
  static const String driverEarningActivityDetails =
      'driver-earning-activity-list';
  static const String getBankInfo = 'get-bank-info';
  ///// get-bank-info

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
  static String socialtoken = "";
  static String  gmailAddres ="";
  static String  userName ="";
   static String  profileImage ="";
 static String vehicleIdStore = "";
  static String verificationStatus = "verificationstatus";
 ///verification_status

  static const String imageurl = 'https://myride.infinititechsolution.com/';
  static const String fileUrl =
      'https://myride.infinititechsolution.com/storage/';
  static const String apiKey = 'AIzaSyBNHiJLxFa2qcs079P5TaYrB770_CVMldU';
}

dynamic driverLatitude;
dynamic driverLongitude;
dynamic driverId;
dynamic driverprofileStatus;
