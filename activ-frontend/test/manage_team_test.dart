import 'dart:convert';
import 'package:activ_app/Screens/Home/ManageTeamScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'jwt_token': 'token'}));
  final member = {
    'id': 'staff-1',
    'fullName': 'Test Staff',
    'phone': '+919876543210',
    'role': 'manager',
    'status': 'invite_sent',
    'permissions': <String, bool>{}
  };

  Future<void> show(WidgetTester tester, http.Client client) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(MaterialApp(home: ManageTeamScreen(client: client)));
    await tester.pumpAndSettle();
  }

  testWidgets('database outage shows Retry without claiming the team is empty', (tester) async {
    var unavailable = true;
    await show(tester, MockClient((_) async => unavailable
        ? http.Response('{}', 503)
        : http.Response(jsonEncode({'data': [member]}), 200)));
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No team members found'), findsNothing);
    unavailable = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    expect(find.text('+919876543210'), findsOneWidget);
  });

  testWidgets(
      'adding a member sends a normalized phone instead of unsupported email',
      (tester) async {
    final rows = <Map<String, dynamic>>[];
    var writes = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        writes++;
        final body = jsonDecode(request.body);
        expect(body['phone'], '+919876543210');
        expect(body.containsKey('email'), isFalse);
        expect(body['fullName'], 'Test Staff');
        expect(body['role'], 'manager');
        expect(request.headers['Authorization'], 'Bearer token');
        rows.add(member);
        return http.Response(jsonEncode({'data': member}), 201);
      }
      return http.Response(jsonEncode({'data': rows}), 200);
    });
    await show(tester, client);
    await tester.tap(find.text('+ New Member'));
    await tester.pumpAndSettle();
    expect(find.text('Phone Number*'), findsOneWidget);
    expect(find.text('Email Address'), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), 'Test Staff');
    await tester.enterText(find.byType(TextField).at(1), '98765 43210');
    await tester.tap(find.text('Send Invite'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Add new team member'), findsNothing);
    expect(find.text('+919876543210'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing persists phone and blocks invalid numbers locally',
      (tester) async {
    var writes = 0;
    var saved = {...member};
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        writes++;
        final body = jsonDecode(request.body);
        expect(body['phone'], '+919123456789');
        expect(body.containsKey('email'), isFalse);
        saved = {...saved, 'phone': body['phone']};
        return http.Response(jsonEncode({'data': saved}), 200);
      }
      return http.Response(
          jsonEncode({
            'data': [saved]
          }),
          200);
    });
    await show(tester, client);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(
        find.text(
            'Enter a valid phone number with country code, e.g. +919876543210'),
        findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '+91 9123456789');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('+919123456789'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
