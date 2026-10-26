import 'dart:async';
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
    await (FontLoader('Satoshi')
          ..addFont(rootBundle.load('fonts/Satoshi-Medium.otf')))
        .load();
  });
  for (final recovery in ['none', 'exact', 'other', 'partial']) {
    testWidgets(
        'confirmation recovers only the exact complete booking: $recovery',
        (tester) async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
      BASE_URL = 'https://backend.test/api/v1';
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final firstConfirmation = Completer<http.Response>();
      final payloads = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer session');
        if (request.method == 'GET' && request.url.path.endsWith('/walk-in')) {
          final booking = payloads.single;
          return http.Response(
              jsonEncode({
                'data': recovery == 'none'
                    ? []
                    : [
                        {
                          'id': 'reservation',
                          'idempotencyKey': recovery == 'other'
                              ? 'another-booking'
                              : booking['idempotencyKey'],
                          'venueId': 'venue',
                          'venueServiceId': 'service',
                          'court': booking['court'],
                          'date': booking['date'],
                          'participantPhone': booking['participantPhone'],
                          'status': 'reserved',
                          'slots': [
                            {'startTime': '09:00', 'endTime': '10:00'}
                          ],
                        }
                      ]
              }),
              200);
        }
        if (request.method == 'GET')
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
                    if (recovery == 'partial')
                      {
                        'startTime': '10:00',
                        'endTime': '11:00',
                        'status': 'available'
                      },
                  ],
                }
              }),
              200);
        expect(request.url.path,
            '/api/v1/venues/venue/activities/service/walk-in');
        payloads.add(Map<String, dynamic>.from(jsonDecode(request.body)));
        if (payloads.length == 1) return firstConfirmation.future;
        return http.Response(
            jsonEncode({
              'data': {'id': 'reservation'}
            }),
            201);
      });
      await tester.pumpWidget(MaterialApp(
          home: DirectBookSlotScreen(
        activity: ActivityModel.fromJson({
          'activity_id': 'legacy-activity',
          'operate_value': {'title': 'Basketball'}
        }),
        activityData: const {'id': 'service'},
        venueId: 'venue',
        venueName: 'Arena',
        client: client,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('09:00 AM - 10:00 AM'));
      if (recovery == 'partial')
        await tester.tap(find.text('10:00 AM - 11:00 AM'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).at(0), 'Test Participant');
      await tester.enterText(find.byType(TextFormField).at(1), '9876543210');
      expect(tester.takeException(), isNull,
          reason: 'participant details layout');
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Review Booking'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'review layout');
      await tester.tap(find.text('Confirm'));
      await tester.tap(find.text('Confirm'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(payloads, hasLength(1));
      expect(tester.takeException(), isNull,
          reason: 'confirmation loader layout');
      expect(find.text('Confirming...'), findsOneWidget);
      expect(find.text('Review Booking'), findsOneWidget);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Confirming...'))
              .onPressed,
          isNull);
      firstConfirmation
          .complete(http.Response('{"message":"Internal server error"}', 500));
      await tester.pumpAndSettle();
      if (recovery != 'exact') {
        expect(find.text('Review Booking'), findsOneWidget);
        expect(find.text('Unable to confirm this booking. Please retry.'),
            findsOneWidget);
        expect(find.textContaining('Test Participant', findRichText: true),
            findsOneWidget);
        await tester.tap(find.text('Retry confirmation'));
        await tester.pumpAndSettle();
        expect(payloads, hasLength(2));
        expect(payloads[1], payloads[0]);
      } else {
        expect(payloads, hasLength(1));
      }
      expect(find.text('Walk-In Slot Reserved!'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('walk-in-success-card')), findsOneWidget);
      expect(find.text('Slot Details'), findsOneWidget);
      expect(find.text('Participant Details'), findsOneWidget);
      expect(find.text('Test Participant'), findsOneWidget);
      expect(find.text('Arena'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
