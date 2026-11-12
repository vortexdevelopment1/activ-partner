import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:activ_app/Screens/Home/BankAccountScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart' as api_config;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'Satoshi': 'fonts/Satoshi-Medium.otf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf'
    }.entries) {
      await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value)))
          .load();
    }
  });
  setUp(() {
    api_config.BASE_URL = 'https://api.test/api/v1';
    SharedPreferences.setMockInitialValues({'jwt_token': 'token'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'),
            (_) async => true);
  });
  final saved = {
    'id': 'bank-1',
    'accountHolderName': 'Test Partner',
    'bankName': 'HDFC Bank',
    'accountNumber': '1234567890',
    'ifscCode': 'HDFC0001234',
    'accountType': 'Saving Account',
    'branchName': 'Test Branch',
    'cancelledChequeUrl': '/uploads/cheque.pdf',
    'status': 'under_review'
  };

  Future<void> show(WidgetTester tester, Widget screen,
      {Size size = const Size(360, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 30; i++) {
      if (target.hitTestable().evaluate().isNotEmpty) return;
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -170));
      await tester.pumpAndSettle();
    }
    fail('Could not scroll to $target');
  }

  Future<void> typeManually(
      WidgetTester tester, Finder target, String value) async {
    await tester.showKeyboard(target);
    var text = '';
    for (final character in value.runes) {
      text += String.fromCharCode(character);
      tester.testTextInput.updateEditingValue(TextEditingValue(
          text: text, selection: TextSelection.collapsed(offset: text.length)));
      await tester.pump();
    }
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/bank-account-screenshots')
        ..createSync(recursive: true);
      File('${dir.path}/$name.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  MockClient api(List<Map<String, dynamic>> accounts) =>
      MockClient((request) async {
        return http.Response(
            jsonEncode({
              'data': request.url.path.endsWith('/summary')
                  ? {'totalEarnings': 0, 'totalCredited': 0}
                  : accounts
            }),
            200);
      });

  testWidgets('empty bank tab matches reference and opens account form',
      (tester) async {
    final key = GlobalKey();
    await show(tester,
        RepaintBoundary(key: key, child: BankAccountScreen(client: api([]))));
    expect(find.text('Total Earnings'), findsOneWidget);
    expect(find.text('Adding bank account is mandatory to receive payouts'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'empty');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Bank Account'));
    await tester.pumpAndSettle();
    expect(find.byType(AddBankAccountScreen), findsOneWidget);
    expect(find.text('Bank Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'submission uploads cheque, reloads saved account and persists when reopened',
      (tester) async {
    final accounts = <Map<String, dynamic>>[];
    var posts = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'ifsc.razorpay.com' ||
          request.url.path.contains('/bank-accounts/ifsc/')) {
        if (request.url.host == 'ifsc.razorpay.com') {
          expectSync(request.headers.containsKey('Authorization'), isFalse);
        } else {
          expectSync(request.headers['Authorization'], 'Bearer token');
        }
        return request.url.host == 'ifsc.razorpay.com'
            ? http.Response(
                jsonEncode({'BANK': 'HDFC Bank', 'BRANCH': 'Test Branch'}), 200)
            : http.Response(
                jsonEncode({
                  'data': {'bank': 'HDFC Bank', 'branch': 'Test Branch'}
                }),
                200);
      }
      expectSync(request.headers['Authorization'], 'Bearer token');
      if (request.method == 'POST') {
        posts++;
        final body = utf8.decode(request.bodyBytes, allowMalformed: true);
        expectSync(body,
            contains('name="cancelledCheque"; filename="cheque.png"'));
        expectSync(body, contains('name="accountType"'));
        expectSync(body, contains('Saving Account'));
        expectSync(body, contains('Test Partner'));
        expectSync(body, contains('HDFC0001234'));
        expectSync(body, isNot(contains('confirmAccountNumber')));
        accounts.add(saved);
        return http.Response(jsonEncode({'data': saved}), 201);
      }
      return http.Response(
          jsonEncode({
            'data': request.url.path.endsWith('/summary')
                ? {'totalEarnings': 0, 'totalCredited': 0}
                : accounts
          }),
          200);
    });
    final key = GlobalKey();
    Widget screen() => RepaintBoundary(
        key: key,
        child: BankAccountScreen(
            client: client,
            pickCheque: () async => PlatformFile(
                name: 'cheque.png',
                size: 68,
                bytes: base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))));
    await show(tester, screen());
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Bank Account'));
    await tester.pumpAndSettle();
    for (final field in {
      'Account Holder Name': 'Test Partner',
      'Account Number': '1234567890',
      'Confirm Account Number': '1234567890',
      'IFSC Code': 'HDFC0001234'
    }.entries) {
      final finder = find.byKey(ValueKey(field.key));
      await reveal(tester, finder);
      await typeManually(tester, finder, field.value);
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('IFSC Code')))
        .controller!.text, 'HDFC0001234');
    final type = find.byKey(const ValueKey('Account Type'));
    await reveal(tester, type);
    await typeManually(tester, type, 'Saving Account');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('Branch Name')))
            .controller!
            .text,
        'Test Branch');
    await reveal(tester, find.text('Browse'));
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Submit for Verification'));
    await tester.tap(find.text('Submit for Verification'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(find.byType(AddBankAccountScreen), findsNothing);
    expect(find.text('Under Review'), findsOneWidget);
    expect(find.byType(BankVerificationProgressScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await show(tester, screen());
    expect(find.text('Test Partner'), findsOneWidget);
    expect(find.text('Under Review'), findsOneWidget);
    expect(find.text('A/C No. XXXX XXXX 7890'), findsOneWidget);
    await capture(tester, key, 'saved');
  });

  testWidgets('bank form blocks clipboard entry and uses verified bank names',
      (tester) async {
    await show(tester, AddBankAccountScreen(client: api([])));
    final bank = find.byKey(const ValueKey('Bank Name'));
    expect(tester.widget<TextField>(find.descendant(
        of: bank, matching: find.byType(TextField))).readOnly, isTrue);
    final account = find.byKey(const ValueKey('Account Number'));
    await reveal(tester, account);
    await tester.enterText(account, '1234567890');
    expect(tester.widget<TextFormField>(account).controller!.text, isEmpty);
    await typeManually(tester, account, '12345678901234567890123');
    expect(tester.widget<TextFormField>(account).controller!.text,
        '12345678901234567890');
    final field = tester.widget<TextField>(find.descendant(
        of: account, matching: find.byType(TextField)));
    expect(field.enableInteractiveSelection, isFalse);
    await tester.showKeyboard(account);
    Actions.invoke(
        tester.element(find.descendant(of: account, matching: find.byType(EditableText))),
        const PasteTextIntent(SelectionChangedCause.keyboard));
    expect(tester.widget<TextFormField>(account).controller!.text,
        '12345678901234567890');
    final ifsc = find.byKey(const ValueKey('IFSC Code'));
    await reveal(tester, ifsc);
    await typeManually(tester, ifsc, 'hdfc1');
    expect(tester.widget<TextFormField>(ifsc).controller!.text, 'HDFC');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('invalid form blocks submission and account mismatch',
      (tester) async {
    var posts = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') posts++;
      return http.Response('{}', 500);
    });
    await show(tester, AddBankAccountScreen(client: client));
    await typeManually(
        tester, find.byKey(const ValueKey('Account Holder Name')), 'Name');
    await reveal(tester, find.byKey(const ValueKey('Confirm Account Number')));
    await typeManually(tester,
        find.byKey(const ValueKey('Confirm Account Number')), '9999999999');
    await reveal(tester, find.text('Submit for Verification'));
    await tester.tap(find.text('Submit for Verification'));
    await tester.pumpAndSettle();
    expect(find.text('Account numbers do not match.'), findsOneWidget);
    expect(find.text('Enter account type.'), findsOneWidget);
    expect(posts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bank states and form fit a narrow phone', (tester) async {
    await show(
        tester,
        BankAccountScreen(
            client: api([
          {...saved, 'status': 'approved'}
        ])),
        size: const Size(320, 720));
    expect(find.text('Verified'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await show(tester, AddBankAccountScreen(client: api([])),
        size: const Size(320, 720));
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Submit for Verification'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'load failure displays retry instead of claiming no account exists',
      (tester) async {
    await show(
        tester,
        BankAccountScreen(
            client: MockClient((_) async => http.Response('{}', 500))));
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Add Bank Account'), findsNothing);
  });

  testWidgets('reference form screenshots show upload and submit controls',
      (tester) async {
    final key = GlobalKey();
    await show(
        tester,
        RepaintBoundary(
            key: key, child: AddBankAccountScreen(client: api([]))));
    await capture(tester, key, 'form-top');
    await reveal(tester, find.text('Submit for Verification'));
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'form-upload');
  });

  testWidgets(
      'expired sessions explain how to recover instead of showing an empty account',
      (tester) async {
    await show(
        tester,
        BankAccountScreen(
            client: MockClient((_) async => http.Response('{}', 401))));
    expect(find.text('Your session has expired. Please sign in again.'),
        findsOneWidget);
    expect(find.text('Add Bank Account'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
