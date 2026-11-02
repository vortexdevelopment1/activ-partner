import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:activ_app/Screens/CategoryQuestionsScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivityDetailsScreen.dart';
import 'package:activ_app/Screens/activity_details_form.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final questions = <Map<String, dynamic>>[
  {
    'id': 'description',
    'questionText': 'Activity Description',
    'questionType': 'textarea',
    'isRequired': true
  },
  {
    'id': 'area',
    'questionText': 'Studio Area Size',
    'questionType': 'number',
    'unit': 'sq ft',
    'answer': '1200'
  },
  {
    'id': 'batch',
    'questionText': 'Max Batch Size',
    'questionType': 'number_stepper',
    'answer': 25
  },
  {
    'id': 'environment',
    'questionText': 'Indoor/Outdoor',
    'questionType': 'radio',
    'options': ['Indoor', 'Outdoor'],
    'answer': 'Indoor'
  },
  {'id': 'floor', 'questionText': 'Floor Type', 'questionType': 'text'},
  {
    'id': 'instructor',
    'questionText': 'Instructor Availability',
    'questionType': 'select',
    'options': ['Yes', 'No'],
    'answer': 'Yes'
  },
];

void main() {
  setUpAll(() async {
    await (FontLoader('Satoshi')
          ..addFont(rootBundle.load('fonts/Satoshi-Medium.otf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() {
    BASE_URL = 'https://backend.test/api/v1';
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'session',
      'activity_questions_display': jsonEncode([
        for (final q in questions.where((q) => q['answer'] != null))
          {
            'categoryId': 'yoga',
            'categoryTitle': 'Yoga Studio',
            'questionId': q['id'],
            'answer': q['answer'],
          },
      ])
    });
  });

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/activity-details-reference')
        ..createSync(recursive: true);
      File('${directory.path}/$name.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final onboarding in [false, true]) {
    testWidgets(
        '${onboarding ? 'onboarding' : 'add activity'} uses the reference controls and preserves canonical units',
        (tester) async {
      tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(600, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final writes = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          writes.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{"data":[]}', 200);
        }
        return http.Response(
            jsonEncode({
              'data': request.url.path.endsWith('/amenities') ||
                      request.url.path.endsWith('/active')
                  ? []
                  : questions
            }),
            200);
      });
      final screen = onboarding
          ? CategoryQuestionsScreen(
              venueId: 'venue',
              currentCategory: const {'id': 'yoga', 'title': 'Yoga Studio'},
              reviewMode: true,
              client: client)
          : AddActivityDetailsScreen(
              activityId: 'activity',
              client: client,
              initialActivity: const {'id': 'activity', 'name': 'Yoga Studio'},
              initialQuestions: questions);
      await tester.pumpWidget(
          MaterialApp(home: RepaintBoundary(key: key, child: screen)));
      await tester.pumpAndSettle();
      expect(find.text('Yoga Studio (Single booking)'), findsOneWidget);
      expect(find.text('Provide Activity Specific Details'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('0/150'), findsOneWidget);
      expect(find.text('sq ft'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, onboarding ? 'onboarding' : 'add-activity');
      await tester.tap(find.byTooltip('Increase Max Batch Size'));
      await tester.pumpAndSettle();
      expect(find.text('26'), findsOneWidget);
      await tester.tap(find.text('Outdoor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('sq ft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('sq m').last);
      await tester.pumpAndSettle();
      final description = find.byKey(ValueKey(onboarding
          ? 'question-yoga-description'
          : 'activity-question-description'));
      await tester.ensureVisible(description);
      await tester.enterText(description, 'A calm yoga studio.');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      final answers = {
        for (final answer in writes.single['answers'])
          answer['questionId']: answer['answer']
      };
      expect(num.parse('${answers['area']}'), closeTo(1200, .001));
      expect('${answers['batch']}', '26');
      expect(answers['environment'], 'Outdoor');
      expect(tester.takeException(), isNull);
    });
  }

  test(
      'reference booking groups distinguish table tennis, snooker and turf activities',
      () {
    expect(activityBookingLabel('Table Tennis'), 'Table booking');
    expect(activityBookingLabel('Snooker'), 'Table booking');
    expect(activityBookingLabel('Paintball'), 'Turf booking');
    expect(activityBookingLabel('Frisbee'), 'Turf booking');
    expect(activityBookingLabel('Cricket Nets'), 'Cricket Nets booking');
    expect(activityBookingLabel('Yoga Studio'), 'Single booking');
  });
}
