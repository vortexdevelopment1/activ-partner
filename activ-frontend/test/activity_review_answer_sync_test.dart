import 'dart:async';
import 'dart:convert';

import 'package:activ_app/Screens/ActivityReviewScreen.dart';
import 'package:activ_app/Screens/CategoryQuestionsScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final editing in [false, true]) {
    testWidgets(
        'review shows ${editing ? 'edited' : 'initial'} answers before API save completes',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'session',
        'activity_questions_display': jsonEncode([
          {
            'categoryId': 'tennis',
            'categoryTitle': 'Tennis',
            'questionId': 'description',
            'questionText': 'Activity Description',
            'answer': 'Keep tennis details',
          },
        ]),
      });
      final save = Completer<http.Response>();
      var saveStarted = false;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          saveStarted = true;
          return save.future;
        }
        if (request.url.path.endsWith('/activities/full')) {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response(jsonEncode({'data': [
          {
            'id': 'description',
            'questionText': 'Activity Description',
            'questionType': 'textarea',
            'isRequired': true,
            'isActive': true,
          },
        ]}), 200);
      });
      const category = {'id': 'badminton', 'title': 'Badminton'};
      await tester.pumpWidget(MaterialApp(
        home: editing
            ? ActivityReviewScreen(
                activityId: 'venue',
                categoryTimings: const [category],
                client: client,
              )
            : CategoryQuestionsScreen(
                venueId: 'venue', currentCategory: category, client: client),
      ));
      await tester.pumpAndSettle();
      if (editing) {
        final header = find.ancestor(
            of: find.text('Activity Specific Details'),
            matching: find.byType(Row)).first;
        await tester.tap(
            find.descendant(of: header, matching: find.byType(TextButton)));
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextField).first, 'Badminton details');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(saveStarted, isTrue);
      expect(save.isCompleted, isFalse);
      expect(find.byType(ActivityReviewScreen), findsOneWidget);
      expect(find.text('Badminton details'), findsOneWidget);
      expect(find.text('No details available.'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('activity_questions_display'),
          contains('Keep tennis details'));

      save.complete(http.Response('{}', 200));
      await tester.pumpAndSettle();
      expect(find.text('Badminton details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
