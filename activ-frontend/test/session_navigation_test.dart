import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:activ_app/Screens/AuthWrapper.dart';
import 'package:activ_app/Screens/ContactSupportScreen.dart';
import 'package:activ_app/Screens/LoginScreen.dart';
import 'package:activ_app/Screens/GetStartedScreen.dart';
import 'package:activ_app/Screens/MobileNumberScreen.dart';
import 'package:activ_app/Screens/OTPVerificationScreen.dart';
import 'package:activ_app/Screens/TellUsAboutScreen.dart';
import 'package:activ_app/Screens/VenueScreen.dart';
import 'package:activ_app/Screens/CustomerPlacesOffer.dart';
import 'package:activ_app/Screens/ListActivityTypeScreen.dart';
import 'package:activ_app/Screens/CategoryQuestionsScreen.dart';
import 'package:activ_app/Screens/VenueTimingScreen.dart';
import 'package:activ_app/Screens/VenuePhotoUploadScreen.dart';
import 'package:activ_app/Screens/ActivityReviewScreen.dart';
import 'package:activ_app/Screens/LegalInformationScreen.dart';
import 'package:activ_app/Screens/ReviewVenueDetailsScreen.dart';
import 'package:activ_app/Screens/ReviewSignAgreement.dart';
import 'package:activ_app/Screens/session_navigation.dart';
import 'package:activ_app/Utills/browser_session.dart';
import 'package:activ_app/Utills/session_photo_draft.dart';
import 'package:activ_app/Screens/VenuePhotoListViewScreen.dart';
import 'package:activ_app/api_calling/api_request.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clearBrowserSession();
  });
  tearDown(clearBrowserSession);

  test(
      'all onboarding pages and category parameters survive checkpoint encoding',
      () {
    final pages = <Widget>[
      const GetStartedScreen(),
      const LoginScreen(),
      const MobileNumberScreen(isCreatingAccount: true),
      const OTPVerificationScreen(isCreatingAccount: true),
      const TellUsAboutScreen(),
      const VenueScreen(),
      const CustomerPlacesOffer(),
      const ListActivityTypeScreen(),
      const CategoryQuestionsScreen(
          venueId: 'venue-1',
          currentCategory: {'id': 'badminton'},
          remainingCategories: [
            {'id': 'tennis'}
          ],
          categoryIndex: 2,
          totalCategories: 3,
          accumulatedTimings: [
            {'id': 'football'}
          ],
          reviewMode: true),
      const VenueTimingScreen(
          activityId: 'venue-1',
          categoryId: 'badminton',
          categoryTitle: 'Badminton'),
      const VenuePhotoUploadScreen(currentCategory: {'id': 'badminton'}),
      const ActivityReviewScreen(
          activityId: 'venue-1', initialActivityIndex: 1),
      const LegalInformationScreen(),
      const ReviewVenueDetailsScreen(),
      const ReviewSignAgreement(),
      const ContactSupportScreen(),
    ];
    for (final page in pages) {
      final data = jsonDecode(jsonEncode(SessionNavigation.describe(page)))
          as Map<String, dynamic>;
      final restored = SessionNavigation.restore(data);
      expect(restored.runtimeType, page.runtimeType);
      expect(SessionNavigation.describe(restored!), data);
    }
  });

  test('only login and verification pages can restore without authentication',
      () {
    expect(SessionNavigation.isPublic({'page': 'login'}), isTrue);
    expect(SessionNavigation.isPublic({'page': 'otp'}), isTrue);
    expect(SessionNavigation.isPublic({'page': 'venue'}), isFalse);
    expect(SessionNavigation.isPublic({'page': 'submitted'}), isFalse);
  });

  testWidgets('fresh startup opens welcome and Get Started opens Login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthWrapper()));
    await tester.pumpAndSettle();
    expect(find.byType(GetStartedScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(VenueScreen), findsNothing);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Back to Login clears authentication and completed onboarding',
      (tester) async {
    await SharedPreference.addStringToSF('jwt_token', 'saved-token');
    await SharedPreference.addStringToSF('venue_id', 'venue-1');
    await SharedPreference.addStringToSF('venue_name', 'Club');
    await SharedPreference.addStringToSF(
        'venue_details', '{"venue_name":"Club"}');
    await tester.pumpWidget(MaterialApp(home: const ContactSupportScreen(),
      navigatorObservers: [SessionNavigation()]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await SharedPreference.readStr('jwt_token'), isNull);
    expect(await SharedPreference.readStr('venue_id'), isNull);
    expect(await SharedPreference.readStr('venue_details'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaterialApp(home: AuthWrapper()));
    await tester.pumpAndSettle();
    expect(find.byType(isBrowserSession ? LoginScreen : GetStartedScreen), findsOneWidget);
  });

  test('web ignores old persistent login tokens and keeps current tab state',
      () async {
    SharedPreferences.setMockInitialValues(
        {'jwt_token': 'old-local-storage-token'});
    expect(await SharedPreference.readStr('jwt_token'), isNull);
    await SharedPreference.addStringToSF('jwt_token', 'tab-token');
    await SharedPreference.addStringToSF('venue_details', 'tab-draft');
    expect(await SharedPreference.readStr('jwt_token'), 'tab-token');
    expect(readBrowserSession('venue_details'), 'tab-draft');
    clearBrowserSession(); // Represents the empty session storage of a new tab.
    expect(await SharedPreference.readStr('jwt_token'), isNull);
    expect(await SharedPreference.readStr('venue_details'), isNull);
  }, skip: !isBrowserSession);

  test('same-tab checkpoint survives a new app startup', () {
    writeBrowserSession(
        SessionNavigation.storageKey,
        jsonEncode([
          {'page': 'partner', 'review': false},
          {'page': 'venue', 'review': false},
        ]));
    final stack = SessionNavigation.savedStack();
    expect(stack.length, 2);
    expect(SessionNavigation.restore(stack.last), isA<VenueScreen>());
    clearBrowserSession();
    expect(SessionNavigation.savedStack(), isEmpty);
  }, skip: !isBrowserSession);

  testWidgets(
      'refresh restores the current onboarding page instead of inferring another step',
      (tester) async {
    await SharedPreference.addStringToSF('jwt_token', 'tab-token');
    writeBrowserSession(
        SessionNavigation.storageKey,
        jsonEncode([
          {'page': 'partner', 'review': false},
        ]));
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'data': {
            'isProfileComplete': true,
            'partner': {'isActive': true}
          },
        }),
        200));
    await tester.pumpWidget(MaterialApp(home: AuthWrapper(client: client)));
    await tester.pumpAndSettle();
    expect(find.byType(TellUsAboutScreen), findsOneWidget);
  }, skip: !isBrowserSession);

  testWidgets(
      'stale onboarding checkpoint cannot bypass login without this tab token',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'jwt_token': 'old-persistent-token'});
    writeBrowserSession(SessionNavigation.storageKey, '[{"page":"venue"}]');
    final client = MockClient(
        (_) async => throw StateError('Must not authenticate an old tab'));
    await tester.pumpWidget(MaterialApp(home: AuthWrapper(client: client)));
    await tester.pumpAndSettle();
    expect(find.byType(GetStartedScreen), findsOneWidget);
  }, skip: !isBrowserSession);

  testWidgets('refresh on welcome stays on welcome', (tester) async {
    writeBrowserSession(SessionNavigation.storageKey, '[{"page":"welcome"}]');
    await tester.pumpWidget(const MaterialApp(home: AuthWrapper()));
    await tester.pumpAndSettle();
    expect(find.byType(GetStartedScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  }, skip: !isBrowserSession);

  testWidgets('refresh restores verification context and its Back navigation',
      (tester) async {
    await SharedPreference.addStringToSF('phoneCode', '+91');
    await SharedPreference.addStringToSF('userMobileNumber', '73-3983-9573');
    writeBrowserSession(
        SessionNavigation.storageKey,
        jsonEncode([
          {'page': 'login'},
          {'page': 'mobile', 'create': true},
          {'page': 'otp', 'create': true},
        ]));
    await tester.pumpWidget(const MaterialApp(home: AuthWrapper()));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<OTPVerificationScreen>(find.byType(OTPVerificationScreen))
            .isCreatingAccount,
        isTrue);
    final context = tester.element(find.byType(OTPVerificationScreen));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.byType(MobileNumberScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !isBrowserSession);

  testWidgets('page observer tracks pushes and Back without saving popup dialogs', (tester) async {
    final observer = SessionNavigation();
    await tester.pumpWidget(MaterialApp(home: const LoginScreen(), navigatorObservers: [observer]));
    await tester.pumpAndSettle();
    expect(SessionNavigation.savedStack().last['page'], 'login');
    final navigator = Navigator.of(tester.element(find.byType(LoginScreen)));
    navigator.push(MaterialPageRoute(builder: (_) => const MobileNumberScreen(isCreatingAccount: true)));
    await tester.pumpAndSettle();
    expect(SessionNavigation.savedStack().last, {'page': 'mobile', 'create': true});
    navigator.push(PageRouteBuilder(pageBuilder: (_, __, ___) => const OTPVerificationScreen(isCreatingAccount: true)));
    await tester.pumpAndSettle();
    expect(SessionNavigation.savedStack().last['page'], 'otp');
    showDialog<void>(context: tester.element(find.byType(OTPVerificationScreen)),
      builder: (_) => const AlertDialog(content: Text('Temporary dialog')));
    await tester.pumpAndSettle();
    expect(SessionNavigation.savedStack().last['page'], 'otp');
    navigator.pop();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(SessionNavigation.savedStack().last['page'], 'mobile');
    navigator.pop();
    await tester.pumpAndSettle();
    expect(SessionNavigation.savedStack(), [{'page': 'login'}]);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !isBrowserSession);

  test('photo review restores bytes and cover after refresh', () {
    final category = <String, dynamic>{'id': 'badminton'};
    final bytes = base64Decode('AQID');
    SessionPhotoDraft.save(category, [bytes, bytes], 1);
    final restored = SessionNavigation.restore({'page': 'photoReview', 'current': category}) as VenuePhotoListViewScreen;
    expect(restored.imageBytes, [bytes, bytes]);
    expect(restored.initialCoverIndex, 1);
    SessionPhotoDraft.save(category, [bytes], 0);
    final afterDeletion = SessionNavigation.restore({'page': 'photoReview', 'current': category}) as VenuePhotoListViewScreen;
    expect(afterDeletion.images.length, 1);
  }, skip: !isBrowserSession);
}
