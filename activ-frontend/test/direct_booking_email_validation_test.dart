import 'dart:convert';
import 'package:activ_app/Beans/activity_model.dart';
import 'package:activ_app/Screens/Home/Activities/DirectBookSlotScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Satoshi')..addFont(rootBundle.load('fonts/Satoshi-Medium.otf'))).load();
  });

  testWidgets('validates email format on Reserve Walk-In Slot screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';

    // 10:00 AM India
    final now = DateTime.utc(2026, 11, 13, 4, 30);
    bool reservationSubmitted = false;

    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/slots')) {
        return http.Response(
          jsonEncode({
            'data': {
              'courts': ['Court 01'],
              'slots': [
                {'startTime': '16:00', 'endTime': '17:00', 'status': 'available'},
              ],
            }
          }),
          200,
        );
      }
      if (request.method == 'POST' && request.url.path.contains('/walk-in')) {
        reservationSubmitted = true;
        return http.Response(
          jsonEncode({
            'data': {'id': 'res-1'}
          }),
          201,
        );
      }
      return http.Response('{"message":"not found"}', 404);
    });

    await tester.pumpWidget(MaterialApp(
      home: DirectBookSlotScreen(
        activity: ActivityModel.fromJson({
          'activity_id': 'activity',
          'operate_value': {'title': 'Badminton'},
        }),
        activityData: const {'id': 'activity'},
        venueId: 'venue',
        venueName: 'Sports Arena Complex',
        now: () => now,
        client: client,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. On "Book Slots" screen, tap Next
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    // 2. On "Select Slot" screen, select 04:00 PM - 05:00 PM and tap Next
    await tester.tap(find.text('04:00 PM - 05:00 PM'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    // 3. Now on "Reserve Walk-In Slot" screen
    expect(find.text('Reserve Walk-In Slot'), findsOneWidget);

    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(3));

    // Enter valid name and 10-digit phone
    await tester.enterText(textFields.at(0), 'nikhil');
    await tester.enterText(textFields.at(1), '8464345434');

    // Enter invalid email as shown in user screenshot
    await tester.enterText(textFields.at(2), '><@@@<x_+<@%#*#|');
    await tester.pump();

    // Tap Next to submit
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    // Verification error must be shown and request must NOT be sent
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(reservationSubmitted, isFalse);

    // Now fix email to a valid email address
    await tester.enterText(textFields.at(2), 'nikhil@yopmail.com');
    await tester.pump();

    // Validation error should disappear
    expect(find.text('Enter a valid email address'), findsNothing);

    // Tap Next again
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    // Reservation should now be successfully submitted
    expect(reservationSubmitted, isTrue);
  });
}

