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

  testWidgets('groups adjacent Not Operational slots into one disabled row', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';

    // 04:00 India on Friday, Nov 13, 2026, before every returned slot.
    final now = DateTime.utc(2026, 11, 12, 22, 30);

    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'data': {
            'courts': ['Court 01'],
            'slots': [
              {'startTime': '14:00', 'endTime': '15:00', 'status': 'available'},
              {'startTime': '15:00', 'endTime': '16:00', 'status': 'activ_booking'},
              {'startTime': '16:00', 'endTime': '17:00', 'status': 'available'},
              {'startTime': '17:00', 'endTime': '18:00', 'status': 'available'},
              {'startTime': '18:00', 'endTime': '19:00', 'status': 'blocked'},
              // 19:00 - 20:00 is omitted and filled as Not Operational.
              {'startTime': '20:00', 'endTime': '21:00', 'status': 'available'},
              {'startTime': '21:00', 'endTime': '22:00', 'status': 'available'},
            ],
          }
        }),
        200,
      );
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

    // Tap Next on the Book Slots screen
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    // Verify Select Slot screen is open
    expect(find.text('Select Slot'), findsOneWidget);

    // Do not fabricate closures before opening or after closing.
    expect(find.text('05:00 AM - 02:00 PM'), findsNothing);
    expect(find.text('10:00 PM - 05:00 AM'), findsNothing);

    expect(find.text('05:00 PM - 06:00 PM'), findsOneWidget);

    final closedRange = find.text('06:00 PM - 08:00 PM');
    expect(closedRange, findsOneWidget);
    expect(find.text('06:00 PM - 07:00 PM'), findsNothing);
    expect(find.text('07:00 PM - 08:00 PM'), findsNothing);
    final closedRow = find.ancestor(
      of: closedRange,
      matching: find.byType(InkWell),
    ).first;
    expect(
      find.descendant(of: closedRow, matching: find.text('Not Operational')),
      findsOneWidget,
    );

    // 08:00 PM - 09:00 PM is present and Available
    expect(find.text('08:00 PM - 09:00 PM'), findsOneWidget);

    // Tapping Not Operational slot does not select it
    await tester.tap(closedRange);
    await tester.pump();

    // Next button remains disabled because no available slot was selected
    final nextBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next'));
    expect(nextBtn.onPressed, isNull);
  });
}

