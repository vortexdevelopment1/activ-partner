import 'dart:async';
import 'dart:convert';
import 'package:activ_app/Screens/Home/ManageBookingsScreen.dart';
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
  testWidgets('UPI booking appears in the list, revenue, and payment details',
      (tester) async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final client = MockClient((request) async {
      Object data;
      if (request.url.path.endsWith('/my-approved-venues')) {
        data = [
          {
            'id': 'venue',
            'name': 'Arena',
            'services': [
              {'id': 'service'}
            ]
          }
        ];
      } else if (request.url.path.endsWith('/management')) {
        data = {
          'name': 'Basketball',
          'bookings': [
            {
              'id': 'upi-booking',
              'customerName': 'UPI Customer',
              'startsAt': '2030-01-01T09:00:00Z',
              'bookedOn': '2026-10-26T08:00:00Z',
              'amount': 500,
              'participants': 1,
              'status': 'Upcoming',
              'paymentMode': 'UPI',
            }
          ]
        };
      } else {
        throw StateError('Unexpected request ${request.url}');
      }
      return http.Response(jsonEncode({'data': data}), 200);
    });
    await tester.pumpWidget(MaterialApp(
        home: ManageBookingsScreen(venueId: 'venue', client: client)));
    await tester.pumpAndSettle();
    expect(find.text('UPI Customer'), findsOneWidget);
    expect(find.textContaining('1 person  |  UPI'), findsOneWidget);
    expect(find.text('₹500.00'), findsOneWidget);
    await tester.ensureVisible(find.text('UPI Customer'));
    await tester.tap(find.text('UPI Customer'));
    await tester.pumpAndSettle();
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('26 Oct 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final action in ['no-show', 'check-in', 'complete', 'failed-no-show']) {
    testWidgets(
        '$action stays busy, blocks repeated taps, and refreshes the saved status',
        (tester) async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
      BASE_URL = 'https://backend.test/api/v1';
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final route = action == 'failed-no-show' ? 'no-show' : action;
      final button = route == 'no-show'
          ? 'Mark No-show'
          : route == 'check-in'
              ? 'Check-in'
              : 'Mark Completed';
      final expected = route == 'no-show'
          ? 'No Show'
          : route == 'check-in'
              ? 'Ongoing'
              : 'Completed';
      var status = action == 'complete' ? 'Ongoing' : 'Upcoming';
      var writes = 0;
      final first = Completer<http.Response>();
      http.Response response(Object data) =>
          http.Response(jsonEncode({'data': data}), 200);
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer session');
        if (request.method == 'PATCH') {
          expect(request.url.path, '/api/v1/bookings/booking/$route');
          writes++;
          final result = writes == 1 ? await first.future : response({});
          if (result.statusCode == 200) status = expected;
          return result;
        }
        if (request.url.path.endsWith('/my-approved-venues'))
          return response([
            {
              'id': 'venue',
              'name': 'Arena',
              'services': [
                {'id': 'service'}
              ]
            },
          ]);
        if (request.url.path.endsWith('/management'))
          return response({
            'id': 'service',
            'name': 'Basketball',
            'bookings': [
              {
                'id': 'booking',
                'customerName': 'Test Customer',
                'startsAt': '2030-01-01T09:00:00Z',
                'amount': 500,
                'participants': 1,
                'status': status,
                'phone': '+919876543210',
              }
            ],
          });
        throw StateError('Unexpected request ${request.url}');
      });
      await tester.pumpWidget(MaterialApp(
          home: ManageBookingsScreen(venueId: 'venue', client: client)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Test Customer'));
      await tester.tap(find.text('Test Customer'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(button));
      await tester.tap(find.text(button));
      await tester.tap(find.text(button));
      await tester.pump(const Duration(milliseconds: 200));
      expect(writes, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Booking details'), findsOneWidget);
      expect(
          tester
              .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close))
              .onPressed,
          isNull);
      first.complete(action == 'failed-no-show'
          ? http.Response('{"message":"Internal server error"}', 500)
          : response({}));
      await tester.pumpAndSettle();
      if (action == 'failed-no-show') {
        expect(find.text('Booking details'), findsOneWidget);
        expect(find.text('Unable to update booking. Please retry.'),
            findsOneWidget);
        await tester.ensureVisible(find.text(button));
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
        expect(writes, 2);
      }
      expect(find.text('Booking details'), findsNothing);
      expect(status, expected);
      await tester.ensureVisible(find.text('Test Customer'));
      await tester.tap(find.text('Test Customer'));
      await tester.pumpAndSettle();
      if (route == 'check-in')
        expect(find.text('Mark Completed'), findsOneWidget);
      else
        expect(find.text('Mark No-show'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
