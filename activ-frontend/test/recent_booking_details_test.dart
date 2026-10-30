import 'dart:convert';
import 'package:activ_app/Screens/Home/HomeScreen.dart';
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

  testWidgets('recent card opens full details and refreshes after check-in',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'jwt_token': 'session', 'user_type': 'partner'});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var status = 'Upcoming';
    var reads = 0;
    var writes = 0;
    final client = MockClient((request) async {
      Object data = {};
      if (request.method == 'PATCH') {
        expect(request.url.path.endsWith('/bookings/booking/check-in'), isTrue);
        expect(request.headers['Authorization'], 'Bearer session');
        writes++;
        status = 'Ongoing';
      } else if (request.url.path.endsWith('/my-approved-venues')) {
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
        reads++;
        data = {
          'name': 'Basketball',
          'bookings': [
            {
              'id': 'booking',
              'bookingReference': 'ACT-TEST-001',
              'customerName': 'Recent Customer',
              'phone': '+919876543210',
              'startsAt': '2030-01-01T09:00:00Z',
              'bookedOn': '2026-10-26T08:00:00Z',
              'amount': 500,
              'participants': 1,
              'status': status,
              'paymentMode': 'UPI',
            }
          ]
        };
      } else if (request.url.path.endsWith('/team') ||
          request.url.path.endsWith('/bank-accounts/my')) {
        data = [];
      } else if (request.url.path.endsWith('/unread-count')) {
        data = {'count': 0};
      }
      return http.Response(jsonEncode({'data': data}), 200);
    });
    await tester.pumpWidget(MaterialApp(home: HomeScreen(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('Pause Bookings'), findsNothing);
    expect(find.text('Venue Status'), findsNothing);
    await tester.scrollUntilVisible(find.text('Recent Customer'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Recent Customer'));
    await tester.pumpAndSettle();
    expect(find.text('Booking details'), findsOneWidget);
    expect(find.text('ACT-TEST-001'), findsOneWidget);
    expect(find.text('+919876543210'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(
        reads, 1); // Opening details does not reload/navigate to all bookings.
    await tester.ensureVisible(find.text('Check-in'));
    await tester.tap(find.text('Check-in'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(reads, 2);
    expect(find.text('Booking details'), findsNothing);
    expect(find.text('Ongoing'), findsOneWidget);
    await tester.tap(find.text('Recent Customer'));
    await tester.pumpAndSettle();
    expect(find.text('Mark Completed'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithIcon(IconButton, Icons.close)));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(tester.takeException(), isNull);
  });
}
