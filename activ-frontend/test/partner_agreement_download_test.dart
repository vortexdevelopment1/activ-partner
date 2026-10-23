import 'dart:convert';

import 'package:activ_app/Screens/Home/PartnerAgreementScreen.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AgreementPicker extends FilePicker {
  Uint8List? saved;
  String? name;
  @override
  Future<String?> saveFile(
      {String? dialogTitle,
      String? fileName,
      String? initialDirectory,
      FileType type = FileType.any,
      List<String>? allowedExtensions,
      Uint8List? bytes,
      bool lockParentWindow = false}) async {
    saved = bytes;
    name = fileName;
    return fileName;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _AgreementPicker picker;
  final messages = <String>[];
  final pdf = utf8.encode('%PDF-1.7 signed agreement');
  http.Response response(Object data) =>
      http.Response(jsonEncode({'data': data}), 200);
  http.Response download() => response(
      {'filename': 'signed-agreement.pdf', 'base64': base64Encode(pdf)});
  setUp(() {
    messages.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      if (call.method == 'showToast') {
        messages.add(call.arguments['msg'] as String);
      }
      return true;
    });
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';
    picker = _AgreementPicker();
    FilePicker.platform = picker;
  });

  Future<void> open(WidgetTester tester, http.Client client) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester
        .pumpWidget(MaterialApp(home: PartnerAgreementScreen(client: client)));
    await tester.tap(find.byTooltip('Download agreement'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
      'recovers missing venue from signed-in account and saves the signed PDF',
      (tester) async {
    final paths = <String>[];
    await open(tester, MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer session');
      paths.add(request.url.path);
      if (request.url.path.endsWith('/my-venues')) {
        return response({
          'items': [
            {'id': 'draft', 'termsAccepted': false},
            {'id': 'signed', 'termsAcceptedAt': '2026-10-22'}
          ],
          'totalPages': 1,
        });
      }
      return download();
    }));
    expect(paths, [
      '/api/v1/venues/my-venues',
      '/api/v1/venues/signed/partner-agreement/download'
    ]);
    expect(picker.saved, pdf);
    expect(picker.name, 'signed-agreement.pdf');
    expect((await SharedPreferences.getInstance()).getString('venue_id'),
        'signed');
    expect(find.text('Your session is missing. Please sign in again.'),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the selected venue when one is already saved',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'jwt_token': 'session', 'venue_id': 'selected'});
    await open(tester, MockClient((request) async {
      expect(request.url.path,
          '/api/v1/venues/selected/partner-agreement/download');
      return download();
    }));
    expect(picker.saved, pdf);
  });

  testWidgets('asks which signed venue to download when selection is missing',
      (tester) async {
    var downloaded = false;
    await open(tester, MockClient((request) async {
      if (request.url.path.endsWith('/my-venues')) {
        return response({
          'items': [
            {'id': 'one', 'name': 'First venue', 'termsAccepted': true},
            {'id': 'two', 'name': 'Second venue', 'termsAccepted': true},
          ]
        });
      }
      expect(request.url.path, '/api/v1/venues/two/partner-agreement/download');
      downloaded = true;
      return download();
    }));
    expect(downloaded, isFalse);
    await tester.tap(find.text('Second venue'));
    await tester.pumpAndSettle();
    expect(picker.saved, pdf);
    expect(
        (await SharedPreferences.getInstance()).getString('venue_id'), 'two');
  });

  testWidgets('missing token does not send a request or save a file',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await open(
        tester,
        MockClient(
            (_) async => throw StateError('Must not request without token')));
    expect(picker.saved, isNull);
    expect(
        messages, contains('Your session is missing. Please sign in again.'));
  });

  testWidgets(
      'no signed venue reports agreement availability rather than missing session',
      (tester) async {
    await open(
        tester,
        MockClient((_) async => response({
              'items': [
                {'id': 'draft', 'termsAccepted': false}
              ]
            })));
    expect(picker.saved, isNull);
    expect(
        messages,
        contains(
            'No signed partnership agreement is available for your venues.'));
  });

  testWidgets('expired session cannot save the PDF', (tester) async {
    await open(tester, MockClient((_) async => http.Response('{}', 401)));
    expect(picker.saved, isNull);
    expect(
        messages, contains('Your session has expired. Please sign in again.'));
  });
}
