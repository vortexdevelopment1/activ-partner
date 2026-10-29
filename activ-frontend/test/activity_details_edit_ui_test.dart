import 'dart:convert';
import 'package:activ_app/Beans/activity_model.dart';
import 'package:activ_app/Screens/Home/Activities/ActivityManagementScreen.dart';
import 'package:activ_app/Screens/CategoryQuestionsScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Satoshi')..addFont(rootBundle.load('fonts/Satoshi-Medium.otf'))).load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session',
      'activity_questions_display': jsonEncode([{'categoryId': 'basketball', 'questionId': 'description', 'questionText': 'Activity Description', 'answer': 'Stale unrelated draft'}])});
    BASE_URL = 'https://backend.test/api/v1';
  });
  Future<List<Map<String, dynamic>>> openEditor(WidgetTester tester, {bool failSave = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var data = <String, dynamic>{'id': 'activity', 'name': 'Basketball',
      'categoryId': 'basketball', 'categoryName': 'Basketball', 'venueId': 'venue',
      'status': 'approved', 'description': 'Existing description',
      'numberOfCourt': '3', 'courtType': 'Full Court',
      'playingEnvironment': ['Outdoor', 'Air Conditioned'], 'coachingAvailable': ['Beginner']};
    final questions = <Map<String, dynamic>>[
      {'id': 'description', 'questionText': 'Activity Description', 'questionType': 'textarea', 'isRequired': true, 'answer': 'Old answer', 'order': 1},
      {'id': 'arenas', 'questionText': 'Total Arenas', 'questionType': 'number', 'answer': '52', 'order': 2},
      {'id': 'courts', 'questionText': 'Total Courts', 'questionType': 'number', 'answer': '3', 'order': 3},
      {'id': 'pitch', 'questionText': 'Pitch Surface', 'questionType': 'select', 'options': ['Synthetic', 'Grass'], 'answer': 'Synthetic', 'order': 4},
      {'id': 'type', 'questionText': 'Court Type', 'questionType': 'select', 'options': ['Full Court', 'Half Court'], 'answer': 'Full Court', 'order': 5},
      {'id': 'playing', 'questionText': 'Playing Environment', 'questionType': 'checkbox', 'options': ['Indoor', 'Outdoor', 'Air Conditioned', 'Covered', 'Floodlights', 'Spectator Seating'], 'answer': ['Outdoor', 'Air Conditioned'], 'order': 6},
      {'id': 'coaching', 'questionText': 'Coaching Available', 'questionType': 'checkbox', 'options': ['Beginner', 'Intermediate'], 'answer': ['Beginner'], 'order': 7},
    ];
    final writes = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer session');
      if (request.url.path.endsWith('/questions')) {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/venues/activities/activity/questions');
        return http.Response(jsonEncode({'data': questions}), 200);
      }
      expect(request.url.path, '/api/v1/venues/activities/activity/management');
      if (request.method == 'PATCH') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        writes.add(payload);
        if (failSave) return http.Response('{"message":"Save unavailable"}', 503);
        final answers = {for (final value in payload['answers']) value['questionId']: value['answer']};
        for (final question in questions) { question['answer'] = answers[question['id']]; }
        data = {...data, 'description': answers['description'], 'numberOfCourt': answers['courts']};
      } else {
        expect(request.method, 'GET');
      }
      return http.Response(jsonEncode({'data': data}), 200);
    });
    await tester.pumpWidget(MaterialApp(home: ActivityManagementScreen(
      activity: ActivityModel.fromJson({'activity_id': 'activity',
        'operate_value': {'id': 'basketball', 'title': 'Basketball'}}),
      venueId: 'venue', client: client,
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Activity Information'));
    await tester.tap(find.text('Activity Information'));
    await tester.pumpAndSettle();
    return writes;
  }

  testWidgets('management uses the exact venue onboarding screen and saves all real category fields', (tester) async {
    final writes = await openEditor(tester);
    expect(find.byType(CategoryQuestionsScreen), findsOneWidget);
    expect(find.text('Tell us about your venue!'), findsOneWidget);
    expect(find.text('Please answer the questions for each selected category'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('Basketball'), findsOneWidget);
    expect(find.text('Update Activity Details'), findsNothing);
    expect(find.text('Provide Activity Specific Details'), findsNothing);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Existing description'), findsOneWidget);
    expect(find.text('52'), findsOneWidget);
    expect(find.text('Stale unrelated draft'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('question-basketball-description')), 'Updated description');
    await tester.enterText(find.byKey(const ValueKey('question-basketball-courts')), '4');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('question-basketball-pitch')), 150, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('question-basketball-pitch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grass').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Indoor'), 150, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final indoorRow = find.ancestor(of: find.text('Indoor'), matching: find.byType(Row)).first;
    final checkbox = find.descendant(of: indoorRow, matching: find.byType(Checkbox));
    expect(tester.getCenter(checkbox).dx, lessThan(tester.getCenter(find.text('Indoor')).dx));
    await tester.tap(find.text('Indoor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    final answers = {for (final answer in writes.single['answers']) answer['questionId']: answer['answer']};
    expect(answers, containsPair('description', 'Updated description'));
    expect(answers, containsPair('arenas', '52'));
    expect(answers, containsPair('courts', '4'));
    expect(answers, containsPair('pitch', 'Grass'));
    expect(answers['playing'], unorderedEquals(['Outdoor', 'Air Conditioned', 'Indoor']));
    expect(find.byType(CategoryQuestionsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('required validation and Back keep unsaved edits off the server', (tester) async {
    final writes = await openEditor(tester);
    await tester.enterText(find.byKey(const ValueKey('question-basketball-description')), '');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryQuestionsScreen), findsOneWidget);
    expect(writes, isEmpty);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(find.byType(CategoryQuestionsScreen), findsNothing);
  });

  testWidgets('the reference form scrolls on narrow screens and keeps Back/Next fixed', (tester) async {
    await openEditor(tester);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(find.text('Next').hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Intermediate'), 150, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Intermediate').hitTestable(), findsOneWidget);
    expect(find.text('Back').hitTestable(), findsOneWidget);
    expect(find.text('Next').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save keeps answers on the same form and never advances onboarding', (tester) async {
    final writes = await openEditor(tester, failSave: true);
    await tester.enterText(find.byKey(const ValueKey('question-basketball-description')), 'Keep this edit');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    expect(find.byType(CategoryQuestionsScreen), findsOneWidget);
    expect(find.text('Keep this edit'), findsOneWidget);
    expect(find.text('Save unavailable'), findsOneWidget);
  });

  testWidgets('the same screen still preserves the original onboarding answer flow', (tester) async {
    Map<String, dynamic>? submitted;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        expect(request.url.path, '/api/v1/venues/venue/answers');
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"data":[]}', 200);
      }
      expect(request.url.path, '/api/v1/questions/category/basketball');
      return http.Response(jsonEncode({'data': [
        {'id': 'description', 'questionText': 'Activity Description', 'questionType': 'textarea', 'isRequired': true, 'order': 1},
        {'id': 'type', 'questionText': 'Court Type', 'questionType': 'select', 'options': ['Full Court', 'Half Court'], 'order': 2},
      ]}), 200);
    });
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => CategoryQuestionsScreen(venueId: 'venue',
          currentCategory: const {'id': 'basketball', 'title': 'Basketball'}, reviewMode: true, client: client))),
        child: const Text('Open onboarding')),
    ))));
    await tester.tap(find.text('Open onboarding'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('question-basketball-description')), 'Onboarding description');
    final dropdown = find.byKey(const ValueKey('question-basketball-type'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Half Court').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(submitted!['answers'], contains(equals({'questionId': 'type', 'answer': 'Half Court'})));
    expect(submitted!['answers'], contains(equals({'questionId': 'description', 'answer': 'Onboarding description'})));
    expect(find.text('Open onboarding'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
