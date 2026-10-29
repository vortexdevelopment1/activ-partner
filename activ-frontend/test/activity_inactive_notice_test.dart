import 'dart:async';
import 'dart:convert';
import 'package:activ_app/Beans/activity_model.dart';
import 'package:activ_app/Screens/Home/Activities/ActivityManagementScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';
  });
  Future<void> open(WidgetTester tester, http.Client client) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: ActivityManagementScreen(
      activity: ActivityModel.fromJson({'activity_id': 'activity',
        'operate_value': {'title': 'Adventure Sports'}}),
      initialStatus: 'Inactive', venueId: 'venue', client: client,
    )));
    await tester.pumpAndSettle();
  }
  http.Response response(Map<String, dynamic> data) =>
      http.Response(jsonEncode({'data': {'id': 'activity', 'name': 'Adventure Sports', ...data}}), 200);

  for (final scenario in [
    (status: 'approved', isActive: true, bookingAccept: true, visible: false),
    (status: 'approved', isActive: false, bookingAccept: true, visible: true),
    (status: 'approved', isActive: true, bookingAccept: false, visible: true),
    (status: 'pending', isActive: false, bookingAccept: false, visible: false),
    (status: 'rejected', isActive: false, bookingAccept: false, visible: false),
  ]) {
    testWidgets('inactive notice respects ${scenario.status}, activity=${scenario.isActive}, venue=${scenario.bookingAccept}', (tester) async {
      await open(tester, MockClient((request) async {
        expect(request.method, 'GET');
        return response({'status': scenario.status, 'isActive': scenario.isActive,
          'bookingAccept': scenario.bookingAccept});
      }));
      final expected = scenario.visible ? findsOneWidget : findsNothing;
      expect(find.text('What happens next?'), expected);
      expect(find.text('Upcoming bookings will be blocked during inactive period'), expected);
      expect(find.text('Venue will be hidden from search & discovery'), expected);
      expect(find.text('ACTIV team may reach out if required'), expected);
    });
  }

  testWidgets('notice disappears only after venue resume succeeds on the backend', (tester) async {
    var accepting = false;
    final pending = Completer<http.Response>();
    await open(tester, MockClient((request) async {
      if (request.method == 'PATCH') {
        expect(request.url.path, '/api/v1/venues/venue/pause-bookings');
        expect(jsonDecode(request.body), {'bookingAccept': true});
        final result = await pending.future;
        accepting = true;
        return result;
      }
      return response({'status': 'approved', 'isActive': true, 'bookingAccept': accepting});
    }));
    expect(find.text('What happens next?'), findsOneWidget);
    await tester.ensureVisible(find.text('Resume Booking'));
    await tester.tap(find.text('Resume Booking'));
    await tester.pump();
    expect(find.text('What happens next?'), findsOneWidget);
    pending.complete(http.Response('{"data":{}}', 200));
    await tester.pumpAndSettle();
    expect(find.text('What happens next?'), findsNothing);
    expect(find.text('Venue will be hidden from search & discovery'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed loading does not display an inactive notice from a fallback status', (tester) async {
    await open(tester, MockClient((_) async => http.Response('{"message":"Unavailable"}', 503)));
    expect(find.text('What happens next?'), findsNothing);
  });
}
