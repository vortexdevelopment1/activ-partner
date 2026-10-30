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
  late DateTime now;
  setUp(() {
    now = DateTime.utc(2026, 10, 30, 12, 2); // 17:32 India
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';
  });

  Future<void> open(WidgetTester tester, {List<Map<String, String>>? slots}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: DirectBookSlotScreen(
      activity: ActivityModel.fromJson({'activity_id': 'activity', 'operate_value': {'title': 'Tennis'}}),
      activityData: const {'id': 'activity'}, venueId: 'venue', venueName: 'Arena',
      now: () => now,
      client: MockClient((_) async => http.Response(jsonEncode({'data': {
        'courts': ['Court 01'], 'slots': slots ?? [
          {'startTime': '09:00', 'endTime': '10:00', 'status': 'activ_booking'},
          {'startTime': '16:00', 'endTime': '17:00', 'status': 'available'},
          {'startTime': '17:00', 'endTime': '18:00', 'status': 'available'},
          {'startTime': '18:00', 'endTime': '19:00', 'status': 'available'},
        ],
      }}), 200)),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  testWidgets('picker hides expired booked and available slots and their empty sections', (tester) async {
    await open(tester);
    expect(find.text('Select Slot'), findsOneWidget);
    expect(find.text('09:00 AM - 10:00 AM'), findsNothing);
    expect(find.text('04:00 PM - 05:00 PM'), findsNothing);
    expect(find.text('Morning'), findsNothing);
    expect(find.text('05:00 PM - 06:00 PM'), findsOneWidget);
    expect(find.text('06:00 PM - 07:00 PM'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('selected slot disappears at its end and Next becomes disabled', (tester) async {
    now = DateTime.utc(2026, 10, 30, 12, 29, 59);
    await open(tester);
    await tester.tap(find.text('05:00 PM - 06:00 PM'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next')).onPressed, isNotNull);
    now = DateTime.utc(2026, 10, 30, 12, 30);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('05:00 PM - 06:00 PM'), findsNothing);
    expect(find.text('06:00 PM - 07:00 PM'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next')).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('future-date morning slots remain visible after today has ended', (tester) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('31 October 2026, Saturday'), findsOneWidget);
    expect(find.text('09:00 AM - 10:00 AM'), findsOneWidget);
    await tester.tap(find.text('05:00 PM - 06:00 PM'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Participant');
    await tester.enterText(find.byType(TextFormField).at(1), '9876543210');
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Review Booking'), findsOneWidget);
    expect(find.textContaining('31 October 2026, Saturday', findRichText: true), findsOneWidget);
    expect(find.textContaining('30 October 2026, Friday', findRichText: true), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
