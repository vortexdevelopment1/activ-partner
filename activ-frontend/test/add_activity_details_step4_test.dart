import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:activ_app/Screens/Home/Activities/AddActivities/AddSelectedVenueFormScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivityAmenitiesScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Satoshi')..addFont(rootBundle.load('fonts/Satoshi-Medium.otf'))).load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session_token'});
    BASE_URL = 'https://backend.test/api/v1';
  });

  testWidgets('renders the step 4 activity description screen matching ss1 and saves description', (tester) async {
    final writes = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer session_token');
      if (request.url.path == '/api/v1/venues/activities/activity_123') {
        return http.Response(jsonEncode({
          'data': {
            'id': 'activity_123',
            'name': 'Badminton',
            'description': '',
          }
        }), 200);
      }
      if (request.url.path == '/api/v1/venues/activities/activity_123/questions') {
        return http.Response(jsonEncode({
          'data': [
            {
              'id': 'desc_q_1',
              'questionText': 'Activity Description',
              'questionType': 'textarea',
              'isRequired': true,
              'answer': '',
            },
          ]
        }), 200);
      }
      if (request.url.path == '/api/v1/venues/activities/activity_123/answers' && request.method == 'POST') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        writes.add(payload);
        return http.Response(jsonEncode({'data': []}), 200);
      }
      if (request.url.path == '/api/v1/venues/activities/activity_123/amenities' ||
          request.url.path == '/api/v1/amenities/active') {
        return http.Response(jsonEncode({'data': []}), 200);
      }
      return http.Response('Not Found', 404);
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      home: AddSelectedVenueFormScreen(
        activityId: 'activity_123',
        client: client,
      ),
    ));

    await tester.pumpAndSettle();

    // Verify step bar indicator 4/6
    expect(find.text('4/6'), findsOneWidget);

    // Verify Title & Subtitle
    expect(find.text('Badminton'), findsOneWidget);
    expect(find.text('Tell us about your activity'), findsOneWidget);

    // Verify Activity Description label & info tooltip
    expect(find.textContaining('Activity Description'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(
      find.text("Share the details you want players to know. We'll help convert your description into clear English."),
      findsOneWidget,
    );

    // Verify "Need an idea?" card
    expect(find.text('Need an idea?'), findsOneWidget);
    expect(
      find.text('Write in Hindi , Hinglish, or English. Mention your facilities, equipment, coaching, who can join, and what makes your venue special.'),
      findsOneWidget,
    );

    // Verify "See an example for Badminton" card
    expect(find.text('See an example for Badminton'), findsOneWidget);
    expect(
      find.textContaining('We have 3 indoor badminton courts with synthetic flooring'),
      findsWidgets, // in example box and hint
    );

    // Verify Back and Next buttons
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // Validate empty submission
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter an activity description'), findsOneWidget);
    expect(writes, isEmpty);

    // Enter description
    await tester.enterText(
      find.byKey(const ValueKey('activity-description-field')),
      '3 premier wooden badminton courts with Yonex mats and AC.',
    );
    await tester.pumpAndSettle();

    // Tap Next
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Verify answers were submitted
    expect(writes, hasLength(1));
    final answers = writes.single['answers'] as List;
    expect(answers, contains(equals({
      'questionId': 'desc_q_1',
      'answer': '3 premier wooden badminton courts with Yonex mats and AC.',
    })));

    // Verify navigation to Amenities screen
    expect(find.byType(AddActivityAmenitiesScreen), findsOneWidget);
  });
}
