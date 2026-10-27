import 'dart:convert';
import 'package:activ_app/Beans/activity_model.dart';
import 'package:activ_app/Screens/Home/Activities/ActivityManagementScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Satoshi')
          ..addFont(rootBundle.load('fonts/Satoshi-Medium.otf')))
        .load();
  });
  for (final allBookings in [false, true]) {
    for (final status in [
      'Completed',
      'Canceled',
      'Cancelled',
      'No Show',
      'NO_SHOW',
      'Upcoming'
    ]) {
      testWidgets(
          '${allBookings ? 'all' : 'recent'} bookings hides attendance actions for $status',
          (tester) async {
        SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
        BASE_URL = 'https://backend.test/api/v1';
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(430, 1000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path,
              '/api/v1/venues/activities/activity/management');
          return http.Response(
              jsonEncode({
                'data': {
                  'id': 'activity',
                  'name': 'Archery',
                  'status': 'approved',
                  'bookings': [
                    {
                      'id': 'booking',
                      'customerName': 'Test Customer',
                      'activity': 'Archery',
                      'status': status,
                      'startsAt': '2026-10-26T16:30:00Z',
                      'amount': 50,
                      'participants': 1,
                    }
                  ],
                }
              }),
              200);
        });
        await tester.pumpWidget(MaterialApp(
            home: ActivityManagementScreen(
          activity: ActivityModel.fromJson({
            'activity_id': 'activity',
            'operate_value': {'title': 'Archery'}
          }),
          venueId: 'venue',
          client: client,
        )));
        await tester.pumpAndSettle();
        if (allBookings) {
          await tester.ensureVisible(find.textContaining('View all'));
          await tester.tap(find.textContaining('View all'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Test Customer'));
        await tester.tap(find.text('Test Customer'));
        await tester.pumpAndSettle();
        expect(find.text('Booking details'), findsOneWidget);
        if (status == 'Upcoming') {
          expect(find.text('Mark No-show'), findsOneWidget);
          expect(find.text('Check-in'), findsOneWidget);
        } else {
          expect(find.text('Mark No-show'), findsNothing);
          expect(find.text('Check-in'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
