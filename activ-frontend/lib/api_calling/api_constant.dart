import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const LOCAL = "LOCAL";
const DEVELOPMENT = "DEVELOPMENT";
const PRODUCTION = "PRODUCTION";
const ACTIVE_CODE_STATUS = PRODUCTION;

const THUMBNAIL_DEFAULT_IMG = "http://via.placeholder.com/120x120&text=image";
const NO_DATA_FOUND = "No data found please click here to refresh";
const NO_INTERNET = "No Internet";
const LOADING = "";

const totalSetup = 7;
const onboardingProfileStep = 1;
const onboardingVenueStep = 2;
const onboardingAmenitiesStep = 3;
const onboardingActivitiesStep = 4;
const onboardingActivityReviewStep = 5;
const onboardingLegalStep = 6;
const onboardingReviewStep = 7;

String get LOCAL_API_URL => const bool.hasEnvironment('LOCAL_API_URL')
    ? const String.fromEnvironment('LOCAL_API_URL')
    : dotenv.isInitialized
        ? dotenv.env['LOCAL_API_URL'] ?? ''
        : '';
String get DEPLOYED_API_URL => const bool.hasEnvironment('API_URL')
    ? const String.fromEnvironment('API_URL')
    : dotenv.isInitialized
        ? dotenv.env['API_URL'] ?? ''
        : '';

String BASE_URL =
    (DEPLOYED_API_URL.trim().isNotEmpty ? DEPLOYED_API_URL : LOCAL_API_URL)
        .trim()
        .replaceFirst(RegExp(r'/+$'), '');

Future<void> initializeApiBaseUrl() async {
  if (!dotenv.isInitialized) {
    await dotenv.load(fileName: '.env');
  }
  final localUrl = LOCAL_API_URL.trim().replaceFirst(RegExp(r'/+$'), '');
  final deployedUrl = DEPLOYED_API_URL.trim().replaceFirst(RegExp(r'/+$'), '');
  if (localUrl.isEmpty && deployedUrl.isEmpty) {
    throw StateError(
      'Set API_URL or LOCAL_API_URL in .env.',
    );
  }
  if (const bool.hasEnvironment('API_URL') && deployedUrl.isNotEmpty) {
    BASE_URL = deployedUrl;
    return;
  }
  if (kDebugMode && localUrl.isNotEmpty) {
    BASE_URL = _localUrlForCurrentPlatform(localUrl);
    return;
  }
  if (localUrl.isEmpty) {
    BASE_URL = deployedUrl;
    return;
  }

  if (ACTIVE_CODE_STATUS == PRODUCTION && deployedUrl.isNotEmpty) {
    BASE_URL = deployedUrl;
    return;
  }

  if (ACTIVE_CODE_STATUS == LOCAL) {
    BASE_URL = _localUrlForCurrentPlatform(localUrl);
    return;
  }

  BASE_URL = deployedUrl.isNotEmpty ? deployedUrl : localUrl;
}

String _localUrlForCurrentPlatform(String localUrl) {
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      Uri.parse(localUrl).host == 'localhost') {
    return localUrl.replaceFirst('localhost', '10.0.2.2');
  }
  return localUrl;
}

String get REQUEST_OTP_URL => "$BASE_URL/auth/partner/request-otp";
String get VERIFY_OTP_URL => "$BASE_URL/auth/partner/verify-otp";
String get COMPLETE_PROFILE_URL => "$BASE_URL/auth/partner/complete-profile";
String get PARTNER_LOGIN_URL => "$BASE_URL/auth/partner/login";
String get CREATE_VENUE_URL => "$BASE_URL/venues";
String get CATEGORIES_URL => "$BASE_URL/categories/active";
String get UPLOAD_SERVICE_IMAGES_URL => "$BASE_URL/venues";
String get VENUE_AVAILABILITY_URL => "$BASE_URL/venues";
String get QUESTIONS_BY_CATEGORY_URL => "$BASE_URL/questions/category";
String get VENUE_ANSWERS_URL => "$BASE_URL/venues";
String get COMMISSION_BY_CITY_URL => "$BASE_URL/commissions/city";
String get MY_VENUES_URL => "$BASE_URL/venues/my-venues";
String get MY_APPROVED_VENUES_URL => "$BASE_URL/venues/my-approved-venues";
String get PAUSE_BOOKINGS_URL => "$BASE_URL/venues";
String get MANAGE_SLOTS_URL => "$BASE_URL/venues/slots";
String get AUTH_PROFILE_URL => "$BASE_URL/auth/partner/auth-profile";
String get CHANGE_PARTNER_PASSWORD_URL =>
    "$BASE_URL/auth/partner/change-password";
String get NOTIFICATION_PREFERENCES_URL => "$BASE_URL/notification-preferences";
String get DELETE_PARTNER_ACCOUNT_URL => "$BASE_URL/partners/account";
String get PINCODE_LOOKUP_URL => "$BASE_URL/location/pincode";
String get LEGAL_URL => "$BASE_URL/legal";
String get TEAM_URL => "$BASE_URL/team";
