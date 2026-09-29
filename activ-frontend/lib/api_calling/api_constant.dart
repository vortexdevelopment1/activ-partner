
const LOCAL = "LOCAL";
const DEVELOPMENT = "DEVELOPMENT";
const PRODUCTION = "PRODUCTION";
const ACTIVE_CODE_STATUS = PRODUCTION;

const THUMBNAIL_DEFAULT_IMG = "http://via.placeholder.com/120x120&text=image";
const NO_DATA_FOUND = "No data found please click here to refresh";
const NO_INTERNET = "No Internet";
const LOADING = "";

const totalSetup = 10;

const BASE_URL = "https://staging-be.activ.co.in/api/v1";
const REQUEST_OTP_URL = "$BASE_URL/auth/partner/request-otp";
const VERIFY_OTP_URL = "$BASE_URL/auth/partner/verify-otp";
const COMPLETE_PROFILE_URL = "$BASE_URL/auth/partner/complete-profile";
const PARTNER_LOGIN_URL = "$BASE_URL/auth/partner/login";
const CREATE_VENUE_URL = "$BASE_URL/venues";
const CATEGORIES_URL = "$BASE_URL/categories/active";
const UPLOAD_SERVICE_IMAGES_URL = "$BASE_URL/venues";
const VENUE_AVAILABILITY_URL = "$BASE_URL/venues";
const QUESTIONS_BY_CATEGORY_URL = "$BASE_URL/questions/category";
const VENUE_ANSWERS_URL = "$BASE_URL/venues";
const COMMISSION_BY_CITY_URL = "$BASE_URL/commissions/city";
const MY_VENUES_URL = "$BASE_URL/venues/my-venues";
const MY_APPROVED_VENUES_URL = "$BASE_URL/venues/my-approved-venues";
const PAUSE_BOOKINGS_URL = "$BASE_URL/venues";
const MANAGE_SLOTS_URL = "$BASE_URL/venues/slots";
const AUTH_PROFILE_URL = "$BASE_URL/auth/partner/auth-profile";
const PINCODE_LOOKUP_URL = "$BASE_URL/location/pincode";
const LEGAL_URL = "$BASE_URL/legal";
const TEAM_URL = "$BASE_URL/team";