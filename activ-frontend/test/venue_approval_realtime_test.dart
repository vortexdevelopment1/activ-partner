import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:no_context_navigation/no_context_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:activ_app/Screens/ContactSupportScreen.dart';
import 'package:activ_app/Screens/VenueApprovedCongratsScreen.dart';
import 'package:activ_app/api_calling/api_request.dart';

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
    SharedPreferences.setMockInitialValues({'jwt_token': 'dummy_token'});
    VenueApprovalService.resetState();
  });

  tearDown(() {
    VenueApprovalService.resetState();
  });

  group('Real-time venue approval polling on ContactSupportScreen', () {
    testWidgets(
        'automatically navigates to VenueApprovedCongratsScreen when admin approves venue while on ContactSupportScreen',
        (WidgetTester tester) async {
      bool isApproved = false;

      final client = MockClient((request) async {
        if (request.url.path.contains('/venues/my-approved-venues')) {
          if (!isApproved) {
            return http.Response(
              jsonEncode({'data': []}),
              200,
            );
          } else {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'venue-live-99',
                    'name': 'Lucky Sports Complex',
                    'publicReference': 'VEN-000055',
                    'hasSeenWelcome': false,
                  }
                ]
              }),
              200,
            );
          }
        }
        if (request.url.path.contains('/venues/my-venues')) {
          return http.Response(
            jsonEncode({
              'data': {
                'total': 1,
                'items': [
                  {
                    'id': 'venue-live-99',
                    'name': 'Lucky Sports Complex',
                    'status': isApproved ? 'published' : 'pending',
                  }
                ]
              }
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ContactSupportScreen(client: client),
        ),
      );
      await tester.pump();

      // Initially on ContactSupportScreen
      expect(find.byType(ContactSupportScreen), findsOneWidget);
      expect(find.byType(VenueApprovedCongratsScreen), findsNothing);

      // Now admin approves the venue
      isApproved = true;

      // Advance by 3 seconds so the polling timer triggers
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Successfully transitioned to VenueApprovedCongratsScreen without restarting app!
      expect(find.byType(VenueApprovedCongratsScreen), findsOneWidget);
      expect(find.text('🥳 Congratulations! Your\nvenue has been approved.'),
          findsOneWidget);
    });

    testWidgets(
        'tapping Let\'s Begin ensures the congratulations screen is never shown again in the future',
        (WidgetTester tester) async {
      bool patchCalled = false;
      bool hasSeenWelcomeBackend = false;

      final client = MockClient((request) async {
        if (request.url.path.contains('/venues/my-approved-venues')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'venue-live-300',
                  'name': 'Future Champions Arena',
                  'publicReference': 'VEN-000300',
                  'hasSeenWelcome': hasSeenWelcomeBackend,
                }
              ]
            }),
            200,
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path.contains('mark-welcome-seen')) {
          patchCalled = true;
          hasSeenWelcomeBackend = true;
          return http.Response(
            jsonEncode({'message': 'Welcome screen marked as seen', 'data': {}}),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      // 1. Initial check returns unseen venue
      final firstCheck =
          await VenueApprovalService.checkUnseenApprovedVenue(client: client);
      expect(firstCheck, isNotNull);
      expect(firstCheck!['id'], 'venue-live-300');

      // 2. Display the screen and tap "Let's Begin"
      await tester.pumpWidget(
        MaterialApp(
          home: VenueApprovedCongratsScreen(
            venueId: 'venue-live-300',
            venueReference: 'VEN-000300',
            venueName: 'Future Champions Arena',
            client: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Let\'s Begin'), findsOneWidget);
      await tester.tap(find.text('Let\'s Begin'));
      await tester.pumpAndSettle();

      // Verified PATCH was called and local flags set
      expect(patchCalled, isTrue);
      expect(
          await SharedPreference.readStr('venue_approved_seen_venue-live-300'),
          'true');
      expect(
          await SharedPreference.readStr('venue_approved_seen_VEN-000300'),
          'true');

      // 3. Subsequent checks in future sessions or app restarts MUST return null
      final secondCheck =
          await VenueApprovalService.checkUnseenApprovedVenue(client: client);
      expect(secondCheck, isNull,
          reason: 'Venue was marked seen and must never trigger congrats again');
    });

    testWidgets(
        'AppLifecycleState.resumed triggers instant check and navigates when approved',
        (WidgetTester tester) async {
      bool isApproved = false;

      final client = MockClient((request) async {
        if (request.url.path.contains('/venues/my-approved-venues')) {
          return http.Response(
            jsonEncode({
              'data': isApproved
                  ? [
                      {
                        'id': 'venue-resumed-1',
                        'name': 'Premier Arena',
                        'publicReference': 'VEN-000077',
                        'hasSeenWelcome': false,
                      }
                    ]
                  : []
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ContactSupportScreen(client: client),
        ),
      );
      await tester.pump();

      expect(find.byType(VenueApprovedCongratsScreen), findsNothing);

      // User received approval email while app was in background
      isApproved = true;

      // Bring app back to foreground (transition paused -> resumed)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Instantly shows VenueApprovedCongratsScreen
      expect(find.byType(VenueApprovedCongratsScreen), findsOneWidget);
    });

    testWidgets(
        'VenueApprovalWatcher over any screen automatically transitions to VenueApprovedCongratsScreen when approved',
        (WidgetTester tester) async {
      bool isApproved = false;

      final client = MockClient((request) async {
        if (request.url.path.contains('/venues/my-approved-venues')) {
          return http.Response(
            jsonEncode({
              'data': isApproved
                  ? [
                      {
                        'id': 'venue-live-101',
                        'name': 'Olympic Arena',
                        'publicReference': 'VEN-000101',
                        'hasSeenWelcome': false,
                      }
                    ]
                  : []
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: NavigationService.navigationKey,
          builder: (context, child) =>
              VenueApprovalWatcher(client: client, child: child),
          home: const Scaffold(body: Text('Some Other App Screen')),
        ),
      );
      await tester.pump();

      expect(find.text('Some Other App Screen'), findsOneWidget);
      expect(find.byType(VenueApprovedCongratsScreen), findsNothing);

      // Admin approves venue while partner is on Some Other App Screen
      isApproved = true;

      // Advance by 3 seconds for polling timer
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(VenueApprovedCongratsScreen), findsOneWidget);
      expect(find.text('🥳 Congratulations! Your\nvenue has been approved.'),
          findsOneWidget);
    });
  });
}
