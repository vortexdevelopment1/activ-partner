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
  for (final automatic in [false, true]) {
    testWidgets(
        automatic
            ? 'temporary server error recovers automatically without booking'
            : 'server failure blocks cached slots; retry restores confirmed availability',
        (tester) async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
      BASE_URL = 'https://backend.test/api/v1';
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 950);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var calls = 0;
      var recovered = automatic;
      final activity = ActivityModel.fromJson({
        'activity_id': 'activity',
        'operate_value': {'title': 'Archery'},
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
              {'open': '09:00 AM', 'close': '07:00 PM'}
            ]
        },
      });
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer session');
        expect(
            request.url.path, '/api/v1/venues/venue/activities/activity/slots');
        expect(request.method, 'GET');
        calls++;
        if (calls == 1 || !recovered)
          return http.Response('Internal server error', 500);
        return http.Response(
            jsonEncode({
              'data': {
                'courts': ['Court 01'],
                'slots': [
                  {
                    'startTime': '09:00',
                    'endTime': '10:00',
                    'status': 'available'
                  },
                ]
              }
            }),
            200);
      });
      await tester.pumpWidget(MaterialApp(
          home: DirectBookSlotScreen(
        activity: activity,
        activityData: const {'id': 'activity'},
        venueId: 'venue',
        venueName: 'Arena',
        client: client,
      )));
      await tester.pumpAndSettle();
      if (!automatic) {
        expect(find.text('Unable to load slot availability. Please retry.'),
            findsOneWidget);
        expect(
            tester
                .widget<ElevatedButton>(
                    find.widgetWithText(ElevatedButton, 'Next'))
                .onPressed,
            isNull);
        expect(find.text('No slots available for this date.'), findsNothing);
        expect(calls, 2);
        recovered = true;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(calls, 3);
      } else {
        expect(calls, 2);
      }
      expect(find.text('Unable to load slot availability. Please retry.'),
          findsNothing);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Next'))
              .onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
    });
  }
}
