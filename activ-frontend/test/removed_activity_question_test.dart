import 'dart:convert';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddSelectedVenueFormScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivityAmenitiesScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivityConfigureScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'jwt_token': 'session'}));
  final questions = [
    {'id': 'equipment', 'questionText': ' Equipment   Available ', 'questionType': 'text', 'isRequired': true, 'answer': 'Old equipment answer'},
    {'id': 'covered', 'questionText': 'Covered', 'questionType': 'text', 'isRequired': false},
  ];
  http.Response response(Object value) => http.Response(jsonEncode({'data': value}), 200);

  testWidgets('removed equipment question neither renders nor submits cached answers', (tester) async {
    final writes = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'POST') { writes.add(request.body); return response([]); }
      return response([]);
    });
    await tester.pumpWidget(MaterialApp(home: AddSelectedVenueFormScreen(
      activityId: 'activity', initialActivity: const {'id': 'activity', 'name': 'Pickle Ball'},
      initialQuestions: questions, client: client,
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Equipment'), findsNothing);
    expect(find.text('Covered'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.tap(find.text('Next')); await tester.pumpAndSettle();
    expect(find.byType(AddActivityAmenitiesScreen), findsOneWidget);
    expect(writes.join(), isNot(contains('equipment')));
    expect(writes.join(), isNot(contains('Old equipment answer')));
  });

  testWidgets('review excludes previously saved equipment answers', (tester) async {
    final client = MockClient((request) async => response(request.url.path.endsWith('/questions')
        ? questions : {'id': 'activity', 'name': 'Pickle Ball', 'imageUrls': []}));
    await tester.pumpWidget(MaterialApp(home: AddActivityConfigureScreen(
      activityId: 'activity', activityName: 'Pickle Ball', timing: const {}, client: client,
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Equipment'), findsNothing);
    expect(find.textContaining('Old equipment answer'), findsNothing);
    expect(find.textContaining('Covered'), findsOneWidget);
  });
}
