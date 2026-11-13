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

  testWidgets('displays Not Operational for gaps between slots matching Figma', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';

    // 14:57 India on Friday, Nov 13, 2026 (matching user screenshot)
    final now = DateTime.utc(2026, 11, 13, 9, 27);

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
              {'startTime': '18:00', 'endTime': '19:00', 'status': 'available'},
              // Note: 19:00 - 20:00 (7 PM to 8 PM) is omitted
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

    // 06:00 PM - 07:00 PM is present and Available
    expect(find.text('06:00 PM - 07:00 PM'), findsOneWidget);

    // 07:00 PM - 08:00 PM must be present as Not Operational
    expect(find.text('07:00 PM - 08:00 PM'), findsOneWidget);
    expect(find.text('Not Operational'), findsWidgets);

    // 08:00 PM - 09:00 PM is present and Available
    expect(find.text('08:00 PM - 09:00 PM'), findsOneWidget);

    // Tapping Not Operational slot does not select it
    await tester.tap(find.text('07:00 PM - 08:00 PM'));
    await tester.pump();

    // Next button remains disabled because no available slot was selected
    final nextBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next'));
    expect(nextBtn.onPressed, isNull);
  });
}

