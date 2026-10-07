import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

const LOCAL_API_URL = String.fromEnvironment(
  "LOCAL_API_URL",
  defaultValue: "http://localhost:3000/api/v1",
);
const DEPLOYED_API_URL = String.fromEnvironment(
  "API_URL",
  defaultValue: "https://activ-partner.onrender.com/api/v1",
);

String BASE_URL = DEPLOYED_API_URL;

Future<void> initializeApiBaseUrl() async {
  final localCandidates = <String>[LOCAL_API_URL];
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      LOCAL_API_URL.contains('localhost')) {
    localCandidates.add(LOCAL_API_URL.replaceFirst('localhost', '10.0.2.2'));
  }

  for (final candidate in localCandidates.toSet()) {
    try {
      final response = await http
          .get(Uri.parse("$candidate/categories/active"))
          .timeout(const Duration(seconds: 5));
      // Any HTTP response proves the local server is reachable. Keep API
      // errors local instead of hiding them behind the deployed backend.
      if (response.statusCode > 0) {
        BASE_URL = candidate;
        return;
      }
    } catch (_) {
      // Try the next local address before falling back to Render.
    }
  }

  BASE_URL = DEPLOYED_API_URL;
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
String get PINCODE_LOOKUP_URL => "$BASE_URL/location/pincode";
String get LEGAL_URL => "$BASE_URL/legal";
String get TEAM_URL => "$BASE_URL/team";
