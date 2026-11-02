import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:activ_app/Screens/AuthWrapper.dart';
import 'package:activ_app/Screens/Home/HomeScreen.dart';
import 'package:activ_app/Screens/LoginScreen.dart';
import 'package:activ_app/Screens/VenueApprovedCongratsScreen.dart';
import 'package:activ_app/api_calling/api_request.dart';

Finder findRichText(String text) => find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText().contains(text),
    );

void main() {
  setUpAll(() async {
    for (final entry in {
      'Satoshi': 'fonts/Satoshi-Medium.otf',
    }.entries) {
      try {
        await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value)))
            .load();
      } catch (_) {}
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VenueApprovedCongratsScreen UI and Behavior', () {
    testWidgets('renders all UI elements properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VenueApprovedCongratsScreen(
            venueId: 'venue-123456',
            venueReference: '123456',
            venueName: 'Elite Sports Arena',
          ),
        ),
      );

      // Verify header and heading
      expect(
          find.text('🥳 Congratulations! Your\nvenue has been approved.'),
          findsOneWidget);

      // Verify venue reference in subtitle via RichText
      expect(findRichText('123456'), findsOneWidget);
      expect(findRichText('Let\'s do some checks'), findsOneWidget);

      // Verify bottom button
      expect(find.text('Let\'s Begin'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      // Verify images
      expect(find.byType(Image), findsAtLeastNWidgets(2));
    });

    testWidgets('formats UUID as 6-char fallback reference when none provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VenueApprovedCongratsScreen(
            venueId: 'abc12345-6789-4000-8000-000000000000',
          ),
        ),
      );

      expect(findRichText('ABC123'), findsOneWidget);
    });

    testWidgets(
        'tapping Let\'s Begin calls mark-welcome-seen and marks preference',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'dummy_partner_jwt'});

      bool patchCalled = false;
      final client = MockClient((request) async {
        if (request.method == 'PATCH' &&
            request.url.path.contains('mark-welcome-seen')) {
          patchCalled = true;
          return http.Response(
            jsonEncode({'message': 'Welcome screen marked as seen', 'data': {}}),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: VenueApprovedCongratsScreen(
            venueId: 'test-venue-id-123',
            venueReference: '123456',
            venueName: 'Test Arena',
            client: client,
          ),
        ),
      );

      await tester.tap(find.text('Let\'s Begin'));
      await tester.pumpAndSettle();

      expect(patchCalled, isTrue);
      final seen =
          await SharedPreference.readStr('venue_approved_seen_test-venue-id-123');
      expect(seen, 'true');
    });
  });

  group('AuthWrapper integration with VenueApprovedCongratsScreen', () {
    testWidgets('shows VenueApprovedCongratsScreen when venue not yet seen',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'active-token'});

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth-profile')) {
          return http.Response(
            jsonEncode({
              'data': {
                'isProfileComplete': true,
                'partner': {'isActive': true},
              }
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/my-approved-venues')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'venue-approved-1',
                  'name': 'FitZone Central',
                  'publicReference': '998877',
                  'hasSeenWelcome': false,
                }
              ]
            }),
            200,
          );
        }
        return http.Response('{"data":[]}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AuthWrapper(client: client),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VenueApprovedCongratsScreen), findsOneWidget);
      expect(findRichText('998877'), findsOneWidget);
    });

    testWidgets('skips VenueApprovedCongratsScreen when already seen',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'active-token',
        'venue_approved_seen_venue-approved-1': 'true',
      });

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth-profile')) {
          return http.Response(
            jsonEncode({
              'data': {
                'isProfileComplete': true,
                'partner': {'isActive': true},
              }
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/my-approved-venues')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'venue-approved-1',
                  'name': 'FitZone Central',
                  'publicReference': '998877',
                  'hasSeenWelcome': true,
                }
              ]
            }),
            200,
          );
        }
        return http.Response('{"data":[]}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AuthWrapper(client: client),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VenueApprovedCongratsScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('LoginScreen to VenueApprovedCongratsScreen integration', () {
    testWidgets(
        'approved partner login navigates to congrats screen on first login',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      final client = MockClient((request) async {
        if (request.url.path.contains('/auth/partner/login')) {
          return http.Response(
            jsonEncode({
              'statusCode': 200,
              'data': {
                'accessToken': 'valid-jwt-token',
                'partner': {
                  'id': 'partner-uuid-1',
                  'isActive': true,
                  'businessName': 'FitZone',
                  'phone': '+919876543210',
                },
                'userType': 'partner',
              },
            }),
            200,
          );
        }
        if (request.url.path.contains('/venues/my-approved-venues')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'venue-approved-1',
                  'name': 'FitZone Central',
                  'publicReference': '998877',
                  'hasSeenWelcome': false,
                }
              ]
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(client: client),
        ),
      );

      final emailFields = find.byType(TextFormField);
      await tester.enterText(emailFields.at(0), 'partner@example.com');
      await tester.enterText(emailFields.at(1), 'password123');

      final loginBtn = find.text('Login');
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Should land on VenueApprovedCongratsScreen
      expect(find.byType(VenueApprovedCongratsScreen), findsOneWidget);
      expect(findRichText('998877'), findsOneWidget);
    });

    testWidgets(
        'approved partner login goes directly to HomeScreen if already seen',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'venue_approved_seen_venue-approved-1': 'true',
      });

      final client = MockClient((request) async {
        if (request.url.path.contains('/auth/partner/login')) {
          return http.Response(
            jsonEncode({
              'statusCode': 200,
              'data': {
                'accessToken': 'valid-jwt-token',
                'partner': {
                  'id': 'partner-uuid-1',
                  'isActive': true,
                  'businessName': 'FitZone',
                  'phone': '+919876543210',
                },
                'userType': 'partner',
              },
            }),
            200,
          );
        }
        if (request.url.path.contains('/venues/my-approved-venues')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'venue-approved-1',
                  'name': 'FitZone Central',
                  'publicReference': '998877',
                  'hasSeenWelcome': true,
                }
              ]
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(client: client),
        ),
      );

      final emailFields = find.byType(TextFormField);
      await tester.enterText(emailFields.at(0), 'partner@example.com');
      await tester.enterText(emailFields.at(1), 'password123');

      final loginBtn = find.text('Login');
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Should NOT show congrats screen, should go to HomeScreen
      expect(find.byType(VenueApprovedCongratsScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
