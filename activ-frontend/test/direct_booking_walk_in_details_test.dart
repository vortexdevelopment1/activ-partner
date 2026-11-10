import 'dart:convert';
import 'package:activ_app/Beans/activity_model.dart';
import 'package:activ_app/Screens/Home/Activities/DirectBookSlotScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'tapping Walk-In Reserved row opens details, and removing reservation deletes it and refreshes slot to available',
      (tester) async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 950);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    bool reservationReleased = false;
    final deletedReservationIds = <String>[];

    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer session');
      final path = request.url.path;

      if (path == '/api/v1/venues/venue/activities/activity/slots') {
        return http.Response(
          jsonEncode({
            'data': {
              'courts': ['Court 01 (6*6)'],
              'slots': [
                {
                  'startTime': '16:00',
                  'endTime': '17:00',
                  'status': reservationReleased ? 'available' : 'walk_in_reserved',
                  if (!reservationReleased) 'reservationId': 'res-123',
                },
              ],
            },
          }),
          200,
        );
      }

      if (path == '/api/v1/venues/venue/activities/activity/walk-in/res-123') {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'res-123',
                'venueName': 'Sports Arena Complex',
                'court': 'Court 01 (6*6)',
                'date': '2026-06-16',
                'participantName': 'Virat Kohli',
                'participantPhone': '+91 98000 00000',
                'participantEmail': 'xyz@gmail.com',
                'slots': [
                  {'startTime': '16:00', 'endTime': '17:00'},
                ],
              },
            }),
            200,
          );
        } else if (request.method == 'DELETE') {
          deletedReservationIds.add('res-123');
          reservationReleased = true;
          return http.Response(
            jsonEncode({'message': 'Reservation released successfully'}),
            200,
          );
        }
      }

      return http.Response('Not found', 404);
    });

    final activity = ActivityModel.fromJson({
      'activity_id': 'activity',
      'operate_value': {'title': 'Badminton'},
      'venue_timing': {
        for (final day in [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ])
          day: [
            {'open': '09:00 AM', 'close': '11:00 PM'}
          ]
      },
    });

    await tester.pumpWidget(MaterialApp(
      home: DirectBookSlotScreen(
        activity: activity,
        activityData: const {},
        venueId: 'venue',
        venueName: 'Sports Arena Complex',
        client: client,
        now: () => DateTime(2026, 6, 16, 10, 0),
      ),
    ));

    await tester.pumpAndSettle();

    // Tap Next to open slot selection screen
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    // Verify slot list shows "Walk-In Reserved"
    expect(find.text('Walk-In Reserved'), findsOneWidget);
    expect(find.text('04:00 PM - 05:00 PM'), findsOneWidget);

    // Tap the Walk-In Reserved row
    await tester.tap(find.text('Walk-In Reserved'));
    await tester.pumpAndSettle();

    // Verify Walk-In Reservation Details screen opens and header is single line
    final titleFinder = find.text('Walk-In Reservation Details');
    expect(titleFinder, findsOneWidget);
    final Text titleText = tester.widget(titleFinder);
    expect(titleText.maxLines, 1);
    expect(titleText.softWrap, isFalse);
    expect(find.byType(FittedBox), findsWidgets);
    expect(find.text('Slot Details'), findsOneWidget);
    expect(find.text('Sports Arena Complex'), findsOneWidget);
    expect(find.text('Court 01 (6*6)'), findsOneWidget);
    expect(find.text('Participant Details'), findsOneWidget);
    expect(find.text('Virat Kohli'), findsOneWidget);
    expect(find.text('+91 98000 00000'), findsOneWidget);
    expect(find.text('xyz@gmail.com'), findsOneWidget);
    expect(find.text('Remove Reservation'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Tap "Remove Reservation"
    await tester.tap(find.widgetWithText(OutlinedButton, 'Remove Reservation'));
    await tester.pumpAndSettle();

    // Confirmation bottom sheet should appear
    expect(find.text('Release Walk-In Reservation?'), findsOneWidget);
    expect(find.text('Keep Reserved'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Remove Reservation'),
        findsOneWidget);
    final keepText = tester.widget<Text>(find.text('Keep Reserved'));
    final removeFinder = find.descendant(
      of: find.byType(ElevatedButton),
      matching: find.text('Remove Reservation'),
    );
    final removeText = tester.widget<Text>(removeFinder);
    expect(keepText.style?.fontSize, 14);
    expect(removeText.style?.fontSize, 14);

    // Confirm removal
    await tester
        .tap(find.widgetWithText(ElevatedButton, 'Remove Reservation'));
    await tester.pumpAndSettle();

    // Verify backend DELETE was called
    expect(deletedReservationIds, ['res-123']);

    // Verify Slot Released! screen is displayed directly (Select Slot header is not visible)
    expect(find.text('Slot Released!'), findsOneWidget);
    expect(find.text('This slot is now available for\nbooking on ACTIV.'),
        findsOneWidget);
    expect(
        find.widgetWithText(ElevatedButton, 'Back to Slots'), findsOneWidget);
    expect(find.text('Select Slot'), findsNothing);

    // Tap "Back to Slots"
    await tester.tap(find.widgetWithText(ElevatedButton, 'Back to Slots'));
    await tester.pumpAndSettle();

    // Verify returning to Select Slot screen with the slot updated to "Available"
    expect(find.text('Select Slot'), findsOneWidget);
    expect(find.text('Walk-In Reserved'), findsNothing);
    expect(find.text('Available'), findsOneWidget);
  });

  testWidgets(
      'Walk-In Reservation Details header fits on single line on mobile screen without overflow',
      (tester) async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final client = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/v1/venues/venue/activities/activity/slots') {
        return http.Response(
          jsonEncode({
            'data': {
              'courts': ['Court 01 (6*6)'],
              'slots': [
                {
                  'startTime': '16:00',
                  'endTime': '17:00',
                  'status': 'walk_in_reserved',
                  'reservationId': 'res-123',
                },
              ],
            },
          }),
          200,
        );
      }
      if (path == '/api/v1/venues/venue/activities/activity/walk-in/res-123') {
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'res-123',
              'venueName': 'Sports Arena Complex',
              'court': 'Court 01 (6*6)',
              'date': '2026-06-16',
              'participantName': 'Virat Kohli',
              'participantPhone': '+91 98000 00000',
              'participantEmail': 'xyz@gmail.com',
              'slots': [
                {'startTime': '16:00', 'endTime': '17:00'},
              ],
            },
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    final activity = ActivityModel.fromJson({
      'activity_id': 'activity',
      'operate_value': {'title': 'Badminton'},
      'venue_timing': {
        for (final day in [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ])
          day: [
            {'open': '09:00 AM', 'close': '11:00 PM'}
          ]
      },
    });

    await tester.pumpWidget(MaterialApp(
      home: DirectBookSlotScreen(
        activity: activity,
        activityData: const {},
        venueId: 'venue',
        venueName: 'Sports Arena Complex',
        client: client,
        now: () => DateTime(2026, 6, 16, 10, 0),
      ),
    ));

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Walk-In Reserved'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final titleFinder = find.text('Walk-In Reservation Details');
    expect(titleFinder, findsOneWidget);
    final Text titleText = tester.widget(titleFinder);
    expect(titleText.maxLines, 1);
    expect(titleText.softWrap, isFalse);
  });
}
