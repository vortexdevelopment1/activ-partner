import 'dart:convert';

import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivityAmenitiesScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddListActivityTypeScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenuePhotoUploadScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivitySubmissionResultScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddSelectedVenueFormScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenuePhotoListViewScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenueTimingScreen.dart';
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
    await (FontLoader('Satoshi')..addFont(rootBundle.load('fonts/Satoshi-Medium.otf'))).load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session', 'venue_id': 'venue',
      'operate_value': jsonEncode({'id': 'swimming', 'title': 'Swimming'})});
    BASE_URL = 'https://backend.test/api/v1';
  });
  http.Response response(Object? data, [int status = 200]) => http.Response(jsonEncode({'data': data}), status);

  testWidgets('uses approved venue and backend category IDs, excluding active sports', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/categories/active')) return response([
        {'id': 'tennis', 'name': 'Tennis'}, {'id': 'swimming', 'name': 'Swimming'},
      ]);
      if (request.url.path.endsWith('/my-approved-venues')) return response([
        {'id': 'venue', 'name': 'Arena', 'services': [
          {'categoryId': 'tennis', 'status': 'approved'},
        ]},
      ]);
      throw StateError('Unexpected request ${request.url}');
    });
    await tester.pumpWidget(MaterialApp(home: AddListActivityTypeScreen(client: client)));
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
    expect(jsonDecode(preferences.getString('operate_value')!)['id'], 'swimming');
    expect(tester.takeException(), isNull);
  });

  for (final failFirstSubmit in [false, true]) {
    testWidgets('photos → questions → amenities → timing → review${failFirstSubmit ? " with retry" : ""}', (tester) async {
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
        if (path == '/categories/active') return response([{'id': 'swimming', 'name': 'Swimming'}]);
        if (path == '/venues/venue/activities') return response({'id': 'activity', 'status': 'draft'}, 201);
        if (path.endsWith('/images')) return response({'imageUrls': List.filled(4, 'photo')}, 201);
        if (path.endsWith('/questions')) return response([
          {'id': 'courts', 'questionText': 'Number of pools', 'questionType': 'number', 'isRequired': true},
          {'id': 'description', 'questionText': 'Description', 'questionType': 'textarea', 'isRequired': true},
        ]);
        if (path.endsWith('/answers')) {
          expect(jsonDecode(request.body)['answers'], [
            {'questionId': 'courts', 'answer': 2}, {'questionId': 'description', 'answer': 'Indoor swimming pools'},
          ]);
          return response([]);
        }
        if (path == '/amenities/active') return response([{'id': 'parking', 'title': 'Parking', 'type': 'parking', 'active': true}]);
        if (path == '/venues/activities/activity') return response({'id': 'activity', 'venueId': 'venue', 'categoryId': 'swimming', 'status': 'draft', 'amenities': []});
        if (path.endsWith('/amenities')) {
          expect(jsonDecode(request.body), {'amenities': ['Parking']}); return response({});
        }
        if (path.endsWith('/availability')) {
          final timing = jsonDecode(request.body)['venue_timing'];
          expect((timing as Map).keys, ['swimming']);
          expect(timing['swimming']['Monday'], [{'open': '09:00 AM', 'close': '06:00 PM'}]);
          return response({});
        }
        if (path.endsWith('/submit')) {
          if (fail) return http.Response('{"message":"Unavailable"}', 503);
          return response({'id': 'activity', 'status': 'pending'});
        }
        throw StateError('Unexpected request ${request.method} $path');
      });
      final bytes = (await rootBundle.load('assets/activities/swimming.png')).buffer.asUint8List();
      await tester.pumpWidget(MaterialApp(home: AddVenuePhotoListViewScreen(
        images: List.generate(4, (_) => XFile.fromData(bytes, path: 'assets/activities/swimming.png')), client: client,
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
      await tester.enterText(find.byKey(const ValueKey('activity-question-courts')), '2');
      await tester.enterText(find.byKey(const ValueKey('activity-question-description')), 'Indoor swimming pools');
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
      state.timings['Mon'].timeSlots..clear()..add({'open': '09:00 AM', 'close': '06:00 PM'});
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      if (failFirstSubmit) {
        expect(find.byType(AddActivitySubmissionResultScreen), findsNothing);
        expect(find.byType(AddVenueTimingScreen), findsOneWidget);
        expect(state.timings['Mon'].timeSlots, [{'open': '09:00 AM', 'close': '06:00 PM'}]);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        fail = false;
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(AddActivitySubmissionResultScreen), findsOneWidget);
      expect(writes.indexOf('POST /venues/activities/activity/answers'), lessThan(writes.indexOf('PATCH /venues/activities/activity/amenities')));
      expect(writes.indexOf('PATCH /venues/venue/availability'), lessThan(writes.indexOf('POST /venues/activities/activity/submit')));
      expect(tester.takeException(), isNull);
    });
  }

  test('retry after a lost response accepts an already queued activity without writing again', () async {
    var calls = 0;
    final api = ActivitySetupApi(client: MockClient((request) async {
      calls++; expect(request.method, 'GET');
      return response({'id': 'activity', 'status': 'pending'});
    }));
    await api.submit('activity', {});
    expect(calls, 1);
  });

  test('failed schedule save never submits the activity for review', () async {
    final calls = <String>[];
    final api = ActivitySetupApi(client: MockClient((request) async {
      calls.add(request.method);
      if (request.method == 'GET') return response({'status': 'draft', 'venueId': 'venue', 'categoryId': 'swimming'});
      return http.Response('{}', 503);
    }));
    await expectLater(api.submit('activity', {'Monday': [{'open': '09:00 AM', 'close': '06:00 PM'}]}), throwsA(isA<ActivitySetupException>()));
    expect(calls, ['GET', 'PATCH']);
  });
}
