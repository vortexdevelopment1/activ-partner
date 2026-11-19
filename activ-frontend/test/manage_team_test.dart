import 'dart:convert';
import 'dart:async';
import 'package:activ_app/Screens/Home/ManageTeamScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final messages = <String>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'token'});
    messages.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      if (call.method == 'showToast') messages.add(call.arguments['msg'] as String);
      return true;
    });
  });
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

  Future<void> openDeleteConfirmation(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete Member'));
    await tester.tap(find.text('Delete Member'));
    await tester.pumpAndSettle();
  }

  for (final dismiss in ['cancel', 'close', 'back']) {
    testWidgets('member deletion confirmation $dismiss sends no DELETE request', (tester) async {
      var deletes = 0;
      await show(tester, MockClient((request) async {
        if (request.method == 'DELETE') deletes++;
        return http.Response(jsonEncode({'data': [member]}), 200);
      }));
      await openDeleteConfirmation(tester);
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('This action cannot be undone. This will permanently delete the member from your team.'), findsOneWidget);
      expect(find.text("Yes, I'm sure"), findsOneWidget);
      expect(find.text('Edit member details'), findsNothing);
      expect(find.text('Team members (1)'), findsOneWidget);
      expect(deletes, 0);
      if (dismiss == 'cancel') {
        await tester.tap(find.text('Cancel'));
      } else if (dismiss == 'close') {
        await tester.tap(find.byTooltip('Close'));
      } else {
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      }
      await tester.pumpAndSettle();
      expect(find.text('Are you sure?'), findsNothing);
      expect(find.text('+919876543210'), findsOneWidget);
      expect(deletes, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final success in [true, false]) {
    testWidgets('confirmed deletion ${success ? 'refreshes members' : 'preserves members on failure'}', (tester) async {
      final pending = Completer<http.Response>();
      var deletes = 0;
      var deleted = false;
      Uri? deleteUrl;
      String? authorization;
      await show(tester, MockClient((request) async {
        if (request.method == 'DELETE') {
          deletes++;
          deleteUrl = request.url;
          authorization = request.headers['Authorization'];
          return pending.future;
        }
        return http.Response(jsonEncode({'data': deleted ? [] : [member]}), 200);
      }));
      await openDeleteConfirmation(tester);
      await tester.tap(find.text("Yes, I'm sure"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(deletes, 1);
      expect(deleteUrl!.path, endsWith('/team/staff-1'));
      expect(authorization, 'Bearer token');
      expect(find.text("Yes, I'm sure"), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      deleted = success;
      pending.complete(http.Response(success ? '{}' : '{"message":"Unable to delete member"}', success ? 200 : 500));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('+919876543210'), success ? findsNothing : findsOneWidget);
      if (!success) expect(messages, contains('Unable to delete member'));
      expect(tester.takeException(), isNull);
    });
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
      'adding a member sends a normalized phone and email invitation',
      (tester) async {
    final rows = <Map<String, dynamic>>[];
    var writes = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        writes++;
        final body = jsonDecode(request.body);
        expect(body['phone'], '+919876543210');
        expect(body['email'], 'staff@example.com');
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
    expect(find.text('Mobile Number*'), findsOneWidget);
    expect(find.textContaining('replaces the existing account password'), findsOneWidget);
    expect(find.textContaining('Email Address'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Test Staff');
    await tester.enterText(find.byType(TextField).at(1), '98765 43210');
    await tester.enterText(find.byType(TextField).at(2), 'Staff@Example.com');
    await tester.ensureVisible(find.text('Send Invite'));
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
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(messages, contains('Enter a valid phone number with country code, e.g. +919876543210'));
    await tester.enterText(find.byType(TextField).at(1), '+91 9123456789');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('+919123456789'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resending uses the owned invitation endpoint and reports partial failure', (tester) async {
    var resends = 0;
    await show(tester, MockClient((request) async {
      if (request.method == 'POST') {
        resends++;
        expect(request.url.path, endsWith('/team/staff-1/invite'));
        return http.Response(jsonEncode({'data': {...member,
          'invitationDelivery': {'emailSent': true, 'smsSent': false}}}), 200);
      }
      return http.Response(jsonEncode({'data': [member]}), 200);
    }));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Resend Invite'));
    await tester.tap(find.text('Resend Invite'));
    await tester.pumpAndSettle();
    expect(resends, 1);
    expect(messages.any((message) => message.contains('Email: sent. SMS: not confirmed.')), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid invitation email is blocked before creating a member', (tester) async {
    var writes = 0;
    await show(tester, MockClient((request) async {
      if (request.method == 'POST') writes++;
      return http.Response('{"data":[]}', 200);
    }));
    await tester.tap(find.text('+ New Member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Alex');
    await tester.enterText(find.byType(TextField).at(1), '9876543210');
    await tester.enterText(find.byType(TextField).at(2), 'invalid');
    await tester.ensureVisible(find.text('Send Invite'));
    await tester.tap(find.text('Send Invite'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(messages, contains('Enter a valid email address'));
  });

  testWidgets('existing account SMS unavailability is explained after resend', (tester) async {
    await show(tester, MockClient((request) async => http.Response(jsonEncode({
      'data': request.method == 'POST' ? {...member, 'invitationDelivery': {
        'emailSent': true, 'smsSent': false,
        'smsUnavailableReason': 'password_template_requires_new_account',
      }} : [member],
    }), 200)));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Resend Invite'));
    await tester.tap(find.text('Resend Invite'));
    await tester.pumpAndSettle();
    expect(messages.any((message) => message.contains('SMS: unavailable for existing accounts/resends')), isTrue);
  });

  testWidgets('pending Send Invite blocks duplicate submissions and reports acceptance', (tester) async {
    final pending = Completer<http.Response>();
    var writes = 0;
    var reads = 0;
    await show(tester, MockClient((request) async {
      if (request.method == 'POST') { writes++; return pending.future; }
      reads++;
      return http.Response(jsonEncode({'data': []}), 200);
    }));
    await tester.tap(find.text('+ New Member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Test Staff');
    await tester.enterText(find.byType(TextField).at(1), '9876543210');
    await tester.enterText(find.byType(TextField).at(2), 'staff@example.com');
    await tester.ensureVisible(find.text('Send Invite'));
    await tester.tap(find.text('Send Invite'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Send Invite'), findsNothing);
    expect(writes, 1);
    pending.complete(http.Response(jsonEncode({'data': {...member,
      'invitationDelivery': {'emailSent': false, 'smsSent': true}}}), 201));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(messages.any((message) => message.contains('SMS: accepted; delivery unconfirmed')), isTrue);
    expect(tester.takeException(), isNull);
  });
}
