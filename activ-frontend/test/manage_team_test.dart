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
  setUpAll(() async {
    await (FontLoader('Satoshi')..addFont(rootBundle.load('fonts/Satoshi-Medium.otf'))).load();
  });
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
      'adding a member sends a normalized phone without requiring email',
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
    expect(find.text('Mobile Number*'), findsOneWidget);
    expect(find.textContaining('replaces the existing account password'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).at(0), 'Test Staff');
    await tester.enterText(find.byType(TextField).at(1), '98765 43210');
    await tester.ensureVisible(find.text('Send Invite'));
    await tester.tap(find.text('Send Invite'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Add new team member'), findsNothing);
    expect(find.text('+919876543210'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile input limits digits, normalizes country code and rejects invalid numbers', (tester) async {
    var writes = 0;
    await show(tester, MockClient((request) async {
      if (request.method == 'POST') writes++;
      return http.Response('{"data":[]}', 200);
    }));
    await tester.tap(find.text('+ New Member'));
    await tester.pumpAndSettle();
    final mobile = find.byType(TextField).at(1);
    await tester.enterText(find.byType(TextField).first, 'Test Staff');
    for (final value in ['', '123', '5123456789']) {
      await tester.enterText(mobile, value);
      await tester.tap(find.text('Send Invite'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(messages.last, 'Enter a valid 10-digit mobile number starting with 6, 7, 8 or 9');
    }
    for (final entry in {
      '747065099400': '7470650994',
      '+91 98765 43210': '9876543210',
      'abc98765xyz43210': '9876543210',
    }.entries) {
      await tester.enterText(mobile, '');
      await tester.enterText(mobile, entry.key);
      expect(tester.widget<TextField>(mobile).controller!.text, entry.value);
    }
    expect(tester.takeException(), isNull);
  });

  for (final keyboard in [false, true]) {
    testWidgets('invite modal fits reference viewport with keyboard $keyboard', (tester) async {
      await show(tester, MockClient((_) async => http.Response('{"data":[]}', 200)));
      tester.view.physicalSize = const Size(366, 780);
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ New Member'));
      await tester.pumpAndSettle();
      if (keyboard) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
      }
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Role*'), findsOneWidget);
      expect(find.text('Permissions'), findsOneWidget);
      expect(find.textContaining('Sending or resending'), findsNothing);
      await tester.ensureVisible(find.text('Send Invite'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Send Invite')).bottom, lessThan(keyboard ? 480 : 780));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('editing persists phone and blocks invalid numbers locally',
      (tester) async {
    var writes = 0;
    var saved = {...member, 'email': 'existing@example.test'};
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
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Resend Invite'), findsNothing);
    expect(find.text('Delete Member'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(messages, contains('Enter a valid 10-digit mobile number starting with 6, 7, 8 or 9'));
    await tester.enterText(find.byType(TextField).at(1), '+91 9123456789');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('+919123456789'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending Send Invite blocks duplicate submissions and reports only SMS status', (tester) async {
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
    await tester.ensureVisible(find.text('Send Invite'));
    await tester.tap(find.text('Send Invite'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Send Invite'), findsNothing);
    expect(writes, 1);
    pending.complete(http.Response(jsonEncode({'data': {...member,
      'invitationDelivery': {'smsSent': true}}}), 201));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(messages, [
      'SMS: accepted; delivery unconfirmed. The member can sign in using their phone OTP.',
    ]);
    expect(tester.takeException(), isNull);
  });
}
