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
    await tester.pumpWidget(MaterialApp(
        home: ActivityManagementScreen(
      activity: ActivityModel.fromJson({
        'activity_id': 'activity',
        'operate_value': {'title': 'Adventure Sports'}
      }),
      initialStatus: 'Inactive',
      venueId: 'venue',
      client: client,
    )));
    await tester.pumpAndSettle();
  }

  http.Response response(Map<String, dynamic> data) => http.Response(
      jsonEncode({
        'data': {'id': 'activity', 'name': 'Adventure Sports', ...data}
      }),
      200);

  for (final scenario in [
    (status: 'approved', isActive: true, bookingAccept: true, visible: false),
    (status: 'approved', isActive: false, bookingAccept: true, visible: true),
    (status: 'approved', isActive: true, bookingAccept: false, visible: true),
    (status: 'pending', isActive: false, bookingAccept: false, visible: false),
    (status: 'rejected', isActive: false, bookingAccept: false, visible: false),
  ]) {
    testWidgets(
        'inactive notice respects ${scenario.status}, activity=${scenario.isActive}, venue=${scenario.bookingAccept}',
        (tester) async {
      await open(tester, MockClient((request) async {
        expect(request.method, 'GET');
        return response({
          'status': scenario.status,
          'isActive': scenario.isActive,
          'bookingAccept': scenario.bookingAccept
        });
      }));
      final expected = scenario.visible ? findsOneWidget : findsNothing;
      expect(find.text('What happens next?'), expected);
      expect(
          find.text(
              'New bookings are paused. Existing bookings are preserved.'),
          expected);
      expect(find.text('This activity is hidden from search & discovery'),
          expected);
      expect(find.text('ACTIV team may reach out if required'), expected);
    });
  }

  testWidgets(
      'notice disappears only after activity resume succeeds on the backend',
      (tester) async {
    var accepting = false;
    final pending = Completer<http.Response>();
    await open(tester, MockClient((request) async {
      if (request.method == 'PATCH') {
        expect(
            request.url.path, '/api/v1/venues/activities/activity/management');
        expect(jsonDecode(request.body), {'isActive': true});
        final result = await pending.future;
        accepting = true;
        return result;
      }
      return response(
          {'status': 'approved', 'isActive': true, 'bookingAccept': accepting});
    }));
    expect(find.text('What happens next?'), findsOneWidget);
    await tester.ensureVisible(find.text('Resume Booking'));
    await tester.tap(find.text('Resume Booking'));
    await tester.pump();
    expect(find.text('What happens next?'), findsOneWidget);
    pending.complete(http.Response('{"data":{}}', 200));
    await tester.pumpAndSettle();
    expect(find.text('What happens next?'), findsNothing);
    expect(find.text('This activity is hidden from search & discovery'),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed loading does not display an inactive notice from a fallback status',
      (tester) async {
    await open(
        tester,
        MockClient(
            (_) async => http.Response('{"message":"Unavailable"}', 503)));
    expect(find.text('What happens next?'), findsNothing);
  });

  for (final failSecond in [false, true]) {
    testWidgets(
        'multi activity pause reports saved results, second fails=$failSecond',
        (tester) async {
      final active = {'activity': true, 'other': true, 'unselected': true};
      final writes = <String>[];
      await open(tester, MockClient((request) async {
        if (request.method == 'PATCH') {
          final id =
              request.url.pathSegments[request.url.pathSegments.length - 2];
          writes.add(id);
          expect(jsonDecode(request.body),
              {'isActive': false, 'reason': 'Maintenance'});
          if (failSecond && id == 'other')
            return http.Response('{"message":"Try again"}', 503);
          active[id] = false;
          return http.Response('{"data":{}}', 200);
        }
        if (request.url.path.endsWith('/my-approved-venues')) {
          return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'venue',
                    'bookingAccept': true,
                    'services': [
                      for (final id in active.keys)
                        {
                          'id': id,
                          'name': id == 'activity' ? 'Adventure Sports' : id,
                          'status': 'approved',
                          'isActive': active[id]
                        },
                      {
                        'id': 'draft',
                        'name': 'Draft activity',
                        'status': 'draft'
                      },
                    ],
                  },
                  {
                    'id': 'another-venue',
                    'services': [
                      {
                        'id': 'unrelated',
                        'name': 'Unrelated',
                        'status': 'approved'
                      }
                    ]
                  }
                ]
              }),
              200);
        }
        return response({
          'status': 'approved',
          'isActive': active['activity'],
          'bookingAccept': true
        });
      }));
      await tester.ensureVisible(find.text('Pause multiple activities'));
      await tester.tap(find.text('Pause multiple activities'));
      await tester.pumpAndSettle();
      expect(find.text('Draft activity'), findsNothing);
      expect(find.text('Unrelated'), findsNothing);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Pause selected'))
              .onPressed,
          isNull);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'other'));
      await tester.enterText(find.byType(TextField), 'Maintenance');
      await tester.pump();
      await tester.tap(find.text('Pause selected'));
      await tester.pumpAndSettle();
      expect(writes, ['activity', 'other']);
      expect(active['activity'], isFalse);
      expect(active['other'], failSecond);
      expect(active['unselected'], isTrue);
      expect(find.text('Resume Booking'), findsOneWidget);
      expect(
          find.text(failSecond
              ? '1 activity paused. Could not pause: other. Please retry.'
              : '2 activities paused. Existing bookings are preserved.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('single activity pause waits for server and refreshes status',
      (tester) async {
    var active = true;
    final pending = Completer<http.Response>();
    var writes = 0;
    await open(tester, MockClient((request) async {
      if (request.method == 'PATCH') {
        writes++;
        expect(
            request.url.path, '/api/v1/venues/activities/activity/management');
        expect(jsonDecode(request.body),
            {'isActive': false, 'reason': 'Maintenance / Repair'});
        final result = await pending.future;
        active = false;
        return result;
      }
      return response(
          {'status': 'approved', 'isActive': active, 'bookingAccept': true});
    }));
    await tester.ensureVisible(find.text('Activity Control'));
    await tester.tap(find.text('Activity Control'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause Booking'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(active, isTrue);
    expect(writes, 1);
    pending.complete(http.Response('{"data":{}}', 200));
    await tester.pumpAndSettle();
    expect(find.text('Resume Booking'), findsOneWidget);
    expect(find.text('Bookings paused. Existing bookings are preserved.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
