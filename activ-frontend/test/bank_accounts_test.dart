import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:activ_app/Screens/Home/BankAccountScreen.dart';
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
      if (request.url.host == 'ifsc.razorpay.com') {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response(
            jsonEncode({'BANK': 'HDFC Bank', 'BRANCH': 'Test Branch'}), 200);
      }
      expect(request.headers['Authorization'], 'Bearer token');
      if (request.method == 'POST') {
        posts++;
        expect(request.body,
            contains('name="cancelledCheque"; filename="cheque.pdf"'));
        expect(request.body, contains('name="accountType"'));
        expect(request.body, contains('Saving Account'));
        expect(request.body, contains('Test Partner'));
        expect(request.body, contains('HDFC0001234'));
        expect(request.body, isNot(contains('confirmAccountNumber')));
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
                name: 'cheque.pdf',
                size: 4,
                bytes: Uint8List.fromList([37, 80, 68, 70]))));
    await show(tester, screen());
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Bank Account'));
    await tester.pumpAndSettle();
    for (final field in {
      'Account Holder Name': 'Test Partner',
      'Bank Name': 'HDFC Bank',
      'Account Number': '1234567890',
      'Confirm Account Number': '1234567890',
      'IFSC Code': 'HDFC0001234'
    }.entries) {
      final finder = find.byKey(ValueKey(field.key));
      await reveal(tester, finder);
      await tester.enterText(finder, field.value);
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final type = find.byKey(const ValueKey('Account Type'));
    await reveal(tester, type);
    await tester.tap(type);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saving Account').last);
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
    expect(find.text('XXXX XXXX 7890'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'saved');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await show(tester, screen());
    expect(find.text('Test Partner'), findsOneWidget);
    expect(find.text('Under Review'), findsOneWidget);
  });

  testWidgets('invalid form blocks submission and account mismatch',
      (tester) async {
    var posts = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') posts++;
      return http.Response('{}', 500);
    });
    await show(tester, AddBankAccountScreen(client: client));
    await tester.enterText(
        find.byKey(const ValueKey('Account Holder Name')), 'Name');
    await reveal(tester, find.byKey(const ValueKey('Confirm Account Number')));
    await tester.enterText(
        find.byKey(const ValueKey('Confirm Account Number')), '9999999999');
    await reveal(tester, find.text('Submit for Verification'));
    await tester.tap(find.text('Submit for Verification'));
    await tester.pumpAndSettle();
    expect(find.text('Account numbers do not match.'), findsOneWidget);
    expect(find.text('Select an account type.'), findsOneWidget);
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
