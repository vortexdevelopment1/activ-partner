import 'dart:convert';

import 'package:activ_app/Screens/OTPVerificationScreen.dart';
import 'package:activ_app/Screens/AuthWrapper.dart';
import 'package:activ_app/Screens/ReviewSignAgreement.dart';
import 'package:activ_app/Screens/TellUsAboutScreen.dart';
import 'package:activ_app/Screens/VenueScreen.dart';
import 'package:activ_app/Screens/ListActivityTypeScreen.dart';
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
  Future<void> open(WidgetTester tester, Widget page) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  testWidgets('new account for reused contact details discards stale venue state', (tester) async {
    SharedPreferences.setMockInitialValues({
      'phoneCode': 'IND (+91)', 'userMobileNumber': '9876544567',
      'venue_id': 'previous-account-venue',
      'activity_questions_display': 'old account answers',
      'agreement_signature_draft': 'Old signature',
      'owner_full_name': 'Old name',
    });
    await open(tester, OTPVerificationScreen(client: MockClient((_) async =>
      http.Response(jsonEncode({'data': {
        'accessToken': 'new-account-token', 'isNewPartner': true,
        'isProfileComplete': false, 'partner': {'isActive': false},
      }}), 200))));
    await tester.enterText(find.byKey(const Key('otp-digit-0')), '1234');
    await tester.pumpAndSettle();
    expect(find.byType(TellUsAboutScreen), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['venue_id', 'activity_questions_display', 'agreement_signature_draft', 'owner_full_name']) {
      expect(prefs.getString(key), isNull);
    }
    expect(prefs.getString('jwt_token'), 'new-account-token');
    expect(prefs.getString('userMobileNumber'), '9876544567');
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale venue agreement offers explicit restart without submitting it', (tester) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'new-account-token', 'venue_id': 'previous-account-venue',
      'agreement_signature_draft': 'Old signature',
    });
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/my-venues')) {
        return http.Response('{"data":{"items":[{"id":"previous-account-venue"}],"totalPages":1}}', 200);
      }
      if (request.method == 'PATCH') {
        return http.Response('{"message":"You can only sign your own venue agreements"}', 403);
      }
      return http.Response('{"data":{"content":"<p>Partnership agreement</p>"}}', 200);
    });
    await open(tester, ReviewSignAgreement(client: client));
    await tester.tap(find.byType(Checkbox));
    await tester.enterText(find.byKey(const Key('agreement-signature')), 'New partner');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(find.text('Restart venue setup'), findsOneWidget);
    await tester.ensureVisible(find.text('Restart venue setup'));
    await tester.tap(find.text('Restart venue setup'));
    await tester.pumpAndSettle();
    expect(find.byType(VenueScreen), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('venue_id'), isNull);
    expect(prefs.getString('jwt_token'), 'new-account-token');
    expect(prefs.getString('agreement_signature_draft'), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup discards an unauthorized saved venue before resuming setup', (tester) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'recreated-account-token', 'venue_id': 'old-venue',
      'navigation_stack': '[{"page":"agreement"}]',
      'pending_legal_camera_document_type': 'panCard',
    });
    final paths = <String>[];
    await open(tester, AuthWrapper(client: MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/my-venues')) {
        return http.Response('{"data":{"items":[],"totalPages":0}}', 200);
      }
      return http.Response('{"data":{"isProfileComplete":true,"partner":{"isActive":false}}}', 200);
    })));
    expect(find.byType(VenueScreen), findsOneWidget);
    expect(paths.any((path) => path.contains('old-venue')), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('venue_id'), isNull);
    expect(prefs.getString('navigation_stack'), isNull);
    expect(prefs.getString('jwt_token'), 'recreated-account-token');
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving setup creates an own venue instead of updating a stale selection', (tester) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'new-account', 'venue_id': 'old-venue',
      'venue_details': jsonEncode({'venue_name': 'New venue', 'venue_city': 'Indore'}),
      'operate_value': jsonEncode([{'id': 'badminton', 'title': 'Badminton'}]),
    });
    final writes = <http.Request>[];
    final client = MockClient((request) async {
      if (request.method != 'GET') {
        writes.add(request);
        return http.Response('{"data":{"id":"new-own-venue","name":"New venue"}}', 201);
      }
      if (request.url.path.endsWith('/my-venues')) {
        return http.Response('{"data":{"items":[],"totalPages":0}}', 200);
      }
      if (request.url.path.endsWith('/categories/active')) {
        return http.Response('{"data":[{"id":"badminton","name":"Badminton","isActive":true}]}', 200);
      }
      return http.Response('{"data":[]}', 200);
    });
    await open(tester, ListActivityTypeScreen(client: client));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    expect(writes.single.method, 'POST');
    expect(writes.single.url.path, endsWith('/venues'));
    expect((await SharedPreferences.getInstance()).getString('venue_id'), 'new-own-venue');
    expect(tester.takeException(), isNull);
  });
}
