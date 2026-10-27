import 'dart:async';
import 'package:activ_app/Screens/ContactSupportFormScreen.dart';
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
  for (final failFirst in [false, true]) {
    testWidgets(
        'contact submission ${failFirst ? 'stops the loader on failure and supports retry' : 'stops the loader before showing success'}',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'phoneCode': '91', 'jwt_token': 'session'});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final pending = Completer<http.Response>();
      final toastMessages = <String>[];
      const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(toastChannel, (call) async {
        if (call.method == 'showToast')
          toastMessages.add((call.arguments as Map)['msg'].toString());
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(toastChannel, null));
      var writes = 0;
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer session');
        writes++;
        return writes == 1 ? pending.future : http.Response('{}', 201);
      });
      await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              ContactSupportFormScreen(client: client))),
                  child: const Text('Previous page'),
                ))),
      ));
      await tester.tap(find.text('Previous page'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test Partner');
      await tester.enterText(find.byType(TextFormField).at(1), '9764946494');
      await tester.enterText(
          find.byType(TextFormField).at(2), 'Please contact me');
      final point = tester.getCenter(find.text('Submit'));
      await tester.tapAt(point);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 100));
      expect(writes, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(http.Response('{}', failFirst ? 503 : 201));
      await tester.pumpAndSettle();
      if (failFirst) {
        expect(toastMessages,
            contains('Unable to send your request. Please try again.'));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Support Request Sent'), findsNothing);
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
        expect(writes, 2);
      }
      expect(find.text('Support Request Sent'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Okay'));
      await tester.pumpAndSettle();
      expect(find.byType(ContactSupportFormScreen), findsNothing);
      expect(find.text('Previous page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
