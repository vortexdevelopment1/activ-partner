import 'dart:convert';
import 'dart:async';

import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivityAmenitiesScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddListActivityTypeScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenuePhotoUploadScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivitySubmissionResultScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivitySubmitReviewScreen.dart';
import 'package:activ_app/Screens/Home/Activities/VenueActivityListScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddSelectedVenueFormScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenuePhotoListViewScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenueTimingScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivityConfigureScreen.dart';
import 'package:activ_app/api_calling/activity_setup_api.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Satoshi')
          ..addFont(rootBundle.load('fonts/Satoshi-Medium.otf')))
        .load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'session',
      'venue_id': 'venue',
      'operate_value': jsonEncode({'id': 'swimming', 'title': 'Swimming'})
    });
    BASE_URL = 'https://backend.test/api/v1';
  });
  http.Response response(Object? data, [int status = 200]) =>
      http.Response(jsonEncode({'data': data}), status);

  for (final back in ['button', 'system', 'root']) {
    testWidgets('add another activity returns to management using $back back',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        if (request.url.path.endsWith('/categories/active')) {
          return response([
            {'id': 'basketball', 'name': 'Basketball'}
          ]);
        }
        if (request.url.path.endsWith('/my-approved-venues')) {
          return response([
            {'id': 'venue', 'name': 'Arena', 'services': []}
          ]);
        }
        return response({
          'id': 'activity',
          'name': 'Padell',
          'status': 'pending',
          'imageUrls': []
        });
      });
      await tester.pumpWidget(MaterialApp(
          home: back == 'root'
              ? AddListActivityTypeScreen(client: client)
              : AddActivitySubmissionResultScreen(
                  activityId: 'activity', client: client)));
      await tester.pumpAndSettle();
      if (back != 'root') {
        await tester.tap(find.text('Add Another Activity'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(AddListActivityTypeScreen), findsOneWidget);
      if (back == 'system') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text('Back'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(VenueActivityListScreen), findsOneWidget);
      expect(find.byType(AddListActivityTypeScreen), findsNothing);
      expect(find.byType(AddActivitySubmissionResultScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final fail in [false, true]) {
    testWidgets(
        'discard draft ${fail ? 'keeps the draft on failure' : 'removes it and refreshes activities'}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activity_draft_resume_activity', '{}');
      var deletes = 0;
      var listLoads = 0;
      final deletion = Completer<http.Response>();
      final client = MockClient((request) async {
        if (request.method == 'DELETE') {
          expect(request.url.path,
              '/api/v1/venues/activities/activity/management');
          expect(request.headers['Authorization'], 'Bearer session');
          deletes++;
          return deletion.future;
        }
        if (request.url.path.endsWith('/my-approved-venues')) {
          listLoads++;
          return response([]);
        }
        expect(request.url.path, '/api/v1/venues/activities/activity');
        return response({'id': 'activity', 'name': 'Padell', 'imageUrls': []});
      });
      await tester.pumpWidget(MaterialApp(
          home: AddActivitySubmissionResultScreen(
              activityId: 'activity',
              savedAsDraft: true,
              activityName: 'Padell',
              client: client)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Discard Draft'));
      final point = tester.getCenter(find.text('Discard Draft'));
      await tester.tapAt(point);
      await tester.tapAt(point);
      await tester.pump();
      expect(deletes, 1);
      expect(listLoads, 0);
      expect(find.text('Discarding...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      deletion.complete(
          fail ? response({'message': 'Unavailable'}, 503) : response(null));
      await tester.pumpAndSettle();
      if (fail) {
        expect(find.byType(AddActivitySubmissionResultScreen), findsOneWidget);
        expect(find.text('Unable to discard this draft. Please retry.'),
            findsOneWidget);
        expect(prefs.containsKey('activity_draft_resume_activity'), isTrue);
        expect(listLoads, 0);
      } else {
        expect(find.byType(VenueActivityListScreen), findsOneWidget);
        expect(find.text('Padell'), findsNothing);
        expect(prefs.containsKey('activity_draft_resume_activity'), isFalse);
        expect(listLoads, 1);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final reopened in [false, true]) {
    testWidgets(
        '${reopened ? 'reopened' : 'just saved'} draft continues the same activity with its saved timing',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final timing = {
        'Monday': [
          {'open': '09:00 AM', 'close': '06:00 PM', 'price': '500'}
        ]
      };
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/venues/activities/saved-activity');
        return response(
            {'id': 'saved-activity', 'name': 'Padell', 'imageUrls': []});
      });
      if (reopened) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'activity_draft_resume_saved-activity', jsonEncode(timing));
      }
      await tester.pumpWidget(MaterialApp(
          home: reopened
              ? AddActivitySubmissionResultScreen(
                  activityId: 'saved-activity',
                  activityName: 'Padell',
                  savedAsDraft: true,
                  client: client)
              : AddActivitySubmitReviewScreen(
                  activityId: 'saved-activity',
                  activityName: 'Padell',
                  timing: timing,
                  client: client)));
      await tester.pumpAndSettle();
      if (!reopened) {
        await tester.tap(find.text('Save as Draft'));
        await tester.pumpAndSettle();
        expect(find.text('Activity Saved as Draft'), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Continue Editing'));
      await tester.tap(find.text('Continue Editing'));
      await tester.pumpAndSettle();
      final editor = tester.widget<AddActivityConfigureScreen>(
          find.byType(AddActivityConfigureScreen));
      expect(editor.activityId, 'saved-activity');
      expect(editor.timing, timing);
      expect(find.text('Please review activity details and proceed'), findsOneWidget);
      expect(find.byType(AddActivitySubmissionResultScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'older draft opens its own editable details instead of the activity list',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/questions')) return response([]);
      expect(request.url.path, '/api/v1/venues/activities/older-activity');
      return response(
          {'id': 'older-activity', 'name': 'Padell', 'imageUrls': []});
    });
    await tester.pumpWidget(MaterialApp(
        home: AddActivitySubmissionResultScreen(
            activityId: 'older-activity',
            activityName: 'Padell',
            savedAsDraft: true,
            client: client)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue Editing'));
    await tester.tap(find.text('Continue Editing'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AddSelectedVenueFormScreen>(
                find.byType(AddSelectedVenueFormScreen))
            .activityId,
        'older-activity');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'details identifies the current activity and explains an empty question set',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      if (request.url.path.endsWith('/questions')) return response([]);
      if (request.url.path.endsWith('/amenities/active')) return response([]);
      if (request.url.path.endsWith('/venues/activities/activity'))
        return response(
            {'id': 'activity', 'name': 'Pickle Ball', 'amenities': []});
      throw StateError('Unexpected request ${request.url}');
    });
    await tester.pumpWidget(MaterialApp(
        home: AddSelectedVenueFormScreen(
            activityId: 'activity', client: client)));
    await tester.pumpAndSettle();
    expect(find.text('4/6'), findsOneWidget);
    expect(find.text('Pickle Ball'), findsOneWidget);
    expect(find.text('No extra details needed'), findsOneWidget);
    expect(find.text('You can continue to choose amenities for Pickle Ball.'),
        findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(AddActivityAmenitiesScreen), findsOneWidget);
    expect(find.text('5/6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed question load shows Retry rather than claiming no questions are needed',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/questions'))
        return http.Response('{}', 503);
      return response({'id': 'activity', 'name': 'Pickle Ball'});
    });
    await tester.pumpWidget(MaterialApp(
        home: AddSelectedVenueFormScreen(
            activityId: 'activity', client: client)));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No extra details needed'), findsNothing);
    await tester.tap(find.text('Next'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AddActivityAmenitiesScreen), findsNothing);
  });

  testWidgets(
      'uses approved venue and backend category IDs, excluding active sports',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/categories/active'))
        return response([
          {'id': 'tennis', 'name': 'Tennis'},
          {'id': 'swimming', 'name': 'Swimming'},
        ]);
      if (request.url.path.endsWith('/my-approved-venues'))
        return response([
          {
            'id': 'venue',
            'name': 'Arena',
            'services': [
              {'categoryId': 'tennis', 'status': 'approved'},
            ]
          },
        ]);
      throw StateError('Unexpected request ${request.url}');
    });
    await tester.pumpWidget(
        MaterialApp(home: AddListActivityTypeScreen(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('1/6'), findsOneWidget);
    expect(find.text('Tennis'), findsNothing);
    await tester.tap(find.text('Swimming'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(AddVenuePhotoUploadScreen), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('venue_id'), 'venue');
    expect(
        jsonDecode(preferences.getString('operate_value')!)['id'], 'swimming');
    expect(tester.takeException(), isNull);
  });

  for (final failFirstSubmit in [false, true]) {
    testWidgets(
        'photos → questions → amenities → timing → review${failFirstSubmit ? " with retry" : ""}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1100);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var fail = failFirstSubmit;
      final writes = <String>[];
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer session');
        final path = request.url.path.replaceFirst('/api/v1', '');
        if (request.method != 'GET') writes.add('${request.method} $path');
        if (path == '/categories/active')
          return response([
            {'id': 'swimming', 'name': 'Swimming'}
          ]);
        if (path == '/venues/venue/activities')
          return response({'id': 'activity', 'status': 'draft'}, 201);
        if (path.endsWith('/images'))
          return response({'imageUrls': List.filled(4, 'photo')}, 201);
        if (path.endsWith('/questions'))
          return response([
            {
              'id': 'courts',
              'questionText': 'Number of pools',
              'questionType': 'number',
              'isRequired': true
            },
            {
              'id': 'description',
              'questionText': 'Description',
              'questionType': 'textarea',
              'isRequired': true
            },
          ]);
        if (path.endsWith('/answers')) {
          expect(jsonDecode(request.body)['answers'], [
            {'questionId': 'courts', 'answer': 2},
            {'questionId': 'description', 'answer': 'Indoor swimming pools'},
          ]);
          return response([]);
        }
        if (path == '/amenities/active')
          return response([
            {
              'id': 'parking',
              'title': 'Parking',
              'type': 'parking',
              'active': true
            }
          ]);
        if (path == '/venues/activities/activity')
          return response({
            'id': 'activity',
            'venueId': 'venue',
            'categoryId': 'swimming',
            'status': 'draft',
            'amenities': []
          });
        if (path.endsWith('/amenities')) {
          expect(jsonDecode(request.body), {
            'amenities': ['Parking']
          });
          return response({});
        }
        if (path.endsWith('/availability')) {
          final timing = jsonDecode(request.body)['venue_timing'];
          expect((timing as Map).keys, ['swimming']);
          expect(timing['swimming']['Monday'], [
            {
              'open': '09:00 AM',
              'close': '06:00 PM',
              'capacity': '2',
              'price': '500'
            }
          ]);
          return response({});
        }
        if (path.endsWith('/submit')) {
          if (fail) return http.Response('{"message":"Unavailable"}', 503);
          return response({'id': 'activity', 'status': 'pending'});
        }
        throw StateError('Unexpected request ${request.method} $path');
      });
      final bytes = (await rootBundle.load('assets/activities/swimming.png'))
          .buffer
          .asUint8List();
      await tester.pumpWidget(MaterialApp(
          home: AddVenuePhotoListViewScreen(
        activityIdFuture: Future.value('activity'),
        uploadFuture: Future<void>.value(),
        images: List.generate(
            4,
            (_) =>
                XFile.fromData(bytes, path: 'assets/activities/swimming.png')),
        client: client,
      )));
      await tester.pumpAndSettle();
      expect(find.text('3/6'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(AddSelectedVenueFormScreen), findsOneWidget);
      expect(find.text('4/6'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Please answer this question'), findsNWidgets(2));
      await tester.enterText(
          find.byKey(const ValueKey('activity-question-courts')), '2');
      await tester.enterText(
          find.byKey(const ValueKey('activity-question-description')),
          'Indoor swimming pools');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(AddActivityAmenitiesScreen), findsOneWidget);
      expect(find.text('5/6'), findsOneWidget);
      await tester.tap(find.text('Parking'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(AddVenueTimingScreen), findsOneWidget);
      expect(find.text('6/6'), findsOneWidget);
      final dynamic state = tester.state(find.byType(AddVenueTimingScreen));
      state.toggleDay('Mon', true);
      state.timings['Mon'].timeSlots
        ..clear()
        ..add({
          'open': '09:00 AM',
          'close': '06:00 PM',
          'capacity': '2',
          'price': '500'
        });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(AddActivitySubmitReviewScreen), findsOneWidget);
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      if (failFirstSubmit) {
        expect(find.byType(AddActivitySubmissionResultScreen), findsNothing);
        expect(find.byType(AddActivitySubmitReviewScreen), findsOneWidget);
        expect(state.timings['Mon'].timeSlots, [
          {
            'open': '09:00 AM',
            'close': '06:00 PM',
            'capacity': '2',
            'price': '500'
          }
        ]);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        fail = false;
        await tester.tap(find.text('Submit for review'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(AddActivitySubmissionResultScreen), findsOneWidget);
      expect(
          writes.indexOf('POST /venues/activities/activity/answers'),
          lessThan(
              writes.indexOf('PATCH /venues/activities/activity/amenities')));
      expect(writes.indexOf('PATCH /venues/venue/availability'),
          lessThan(writes.indexOf('POST /venues/activities/activity/submit')));
      expect(tester.takeException(), isNull);
    });
  }

  test(
      'retry after a lost response accepts an already queued activity without writing again',
      () async {
    var calls = 0;
    final api = ActivitySetupApi(client: MockClient((request) async {
      calls++;
      expect(request.method, 'GET');
      return response({'id': 'activity', 'status': 'pending'});
    }));
    await api.submit('activity', {});
    expect(calls, 1);
  });

  test('failed schedule save never submits the activity for review', () async {
    final calls = <String>[];
    final api = ActivitySetupApi(client: MockClient((request) async {
      calls.add(request.method);
      if (request.method == 'GET')
        return response(
            {'status': 'draft', 'venueId': 'venue', 'categoryId': 'swimming'});
      return http.Response('{}', 503);
    }));
    await expectLater(
        api.submit('activity', {
          'Monday': [
            {'open': '09:00 AM', 'close': '06:00 PM'}
          ]
        }),
        throwsA(isA<ActivitySetupException>()));
    expect(calls, ['GET', 'PATCH']);
  });
}
