import 'dart:async';
import 'package:activ_app/Screens/LegalInformationScreen.dart';
import 'package:activ_app/Screens/ReviewVenueDetailsScreen.dart';
import 'package:activ_app/Utills/gstin_validation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Picker extends ImagePicker {
  _Picker(this.bytes);
  final Uint8List bytes;
  @override
  Future<XFile?> pickImage(
          {required ImageSource source,
          double? maxWidth,
          double? maxHeight,
          int? imageQuality,
          CameraDevice preferredCameraDevice = CameraDevice.rear,
          bool requestFullMetadata = true}) async =>
      XFile.fromData(bytes, path: 'document.png');
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      respond(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  for (final value in [
    '27AAPFU0939F1ZV',
    '33ABCCA3430E1ZD',
    ' 27aapfu0939f1zv '
  ]) {
    test('accepts valid GSTIN $value',
        () => expect(isValidGstin(value), isTrue));
  }
  for (final value in [
    '',
    'Heueueieieieidu',
    '27AAPFU0939F1ZA',
    '00AAPFU0939F1ZV',
    '27AAPFU0939F0ZV',
    '27AAPFU0939F1YV',
    '27AAPFU0939F1Z',
    '27AAPFU0939F1ZVV',
    '27AAPF!0939F1ZV'
  ]) {
    test('rejects invalid GSTIN $value',
        () => expect(isValidGstin(value), isFalse));
  }

  String? toast;
  String clipboard = '';
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    toast = null;
    clipboard = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = call.arguments['text'] as String;
      }
      if (call.method == 'Clipboard.getData') return {'text': clipboard};
      if (call.method == 'Clipboard.hasStrings') {
        return {'value': clipboard.isNotEmpty};
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      toast = call.arguments['msg'] as String?;
      return true;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), null);
  });

  Future<void> open(WidgetTester tester, {Dio? client}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = (await rootBundle.load('assets/activities/badminton.png'))
        .buffer
        .asUint8List();
    await tester.pumpWidget(MaterialApp(
        home: LegalInformationScreen(
      imagePicker: _Picker(bytes),
      client: client,
    )));
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(LegalInformationScreen));
    state.fullNameController.text = 'Test Owner';
    state.aadhaarNumberController.text = '123456789012';
    state.panCardNumberController.text = 'AAPFU0939F';
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Browse').first);
      await tester.tap(find.text('Browse').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> enterGstin(WidgetTester tester, String value) async {
    final dynamic state = tester.state(find.byType(LegalInformationScreen));
    final field = find.byWidgetPredicate((widget) =>
        widget is TextFormField && widget.controller == state.gstINController);
    await tester.scrollUntilVisible(field, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.showKeyboard(field);
    tester.testTextInput.updateEditingValue(TextEditingValue.empty);
    await tester.pump();
    for (final character in value.runes) {
      final text = state.gstINController.text + String.fromCharCode(character);
      tester.testTextInput.updateEditingValue(TextEditingValue(
          text: text, selection: TextSelection.collapsed(offset: text.length)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Aadhaar PAN and GSTIN allow typing but block clipboard actions and bulk insertion',
      (tester) async {
    await open(tester);
    final dynamic state = tester.state(find.byType(LegalInformationScreen));
    for (final entry in [
      (
        state.aadhaarNumberController as TextEditingController,
        '123456789012',
        '1234-5678-9012'
      ),
      (
        state.panCardNumberController as TextEditingController,
        'aapfu0939f',
        'AAPFU0939F'
      ),
      (
        state.gstINController as TextEditingController,
        '27aapfu0939f1zv',
        '27AAPFU0939F1ZV'
      ),
    ]) {
      final controller = entry.$1;
      controller.clear();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate((widget) =>
          widget is TextFormField && widget.controller == controller);
      await tester.scrollUntilVisible(field, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.enterText(field, entry.$2);
      expect(controller.text, isEmpty);
      for (final character in entry.$2.runes) {
        final text = controller.text + String.fromCharCode(character);
        tester.testTextInput.updateEditingValue(TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length)));
        await tester.pump();
      }
      expect(controller.text, entry.$3);
      final input = tester.widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)));
      expect(input.enableInteractiveSelection, isFalse);
      expect(input.enableSuggestions, isFalse);
      expect(input.autocorrect, isFalse);
      controller.selection =
          TextSelection(baseOffset: 0, extentOffset: controller.text.length);
      await Clipboard.setData(const ClipboardData(text: 'clipboard unchanged'));
      for (final intent in [
        CopySelectionTextIntent.copy,
        const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
        const PasteTextIntent(SelectionChangedCause.keyboard)
      ]) {
        Actions.invoke(
            tester.element(find.descendant(
                of: field, matching: find.byType(EditableText))),
            intent);
        await tester.pumpAndSettle();
        expect(controller.text, entry.$3);
        expect((await Clipboard.getData(Clipboard.kTextPlain))!.text,
            'clipboard unchanged');
      }
      await tester.longPress(field);
      await tester.pumpAndSettle();
      expect(find.text('Paste'), findsNothing);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Cut'), findsNothing);
      controller.selection =
          TextSelection.collapsed(offset: controller.text.length);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid GSTIN blocks Next even with its document uploaded',
      (tester) async {
    var requests = 0;
    final client = Dio()
      ..httpClientAdapter = _Adapter((_) async {
        requests++;
        return ResponseBody.fromString('{}', 200);
      });
    await open(tester, client: client);
    await enterGstin(tester, 'Heueueieieieidu');
    await tester.ensureVisible(find.text('Browse').first);
    await tester.tap(find.text('Browse').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid 15-character GSTIN.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(toast, 'Enter a valid 15-character GSTIN.');
    expect(requests, 0);
    expect(find.byType(ReviewVenueDetailsScreen), findsNothing);
    await enterGstin(tester, '27AAPFU0939F1ZA');
    expect(find.text('Enter a valid 15-character GSTIN.'), findsOneWidget);
    await enterGstin(tester, '27aapfu0939f1zv');
    expect(find.text('Enter a valid 15-character GSTIN.'), findsNothing);
    final dynamic state = tester.state(find.byType(LegalInformationScreen));
    expect(
        state.validation(tester.element(find.byType(LegalInformationScreen))),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional GST stays optional and a GSTIN requires its document',
      (tester) async {
    await open(tester);
    final dynamic state = tester.state(find.byType(LegalInformationScreen));
    final context = tester.element(find.byType(LegalInformationScreen));
    expect(state.validation(context), isTrue);
    await enterGstin(tester, '27AAPFU0939F1ZV');
    expect(state.validation(context), isFalse);
    expect(toast, 'Please upload GSTIN card.');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'save waits for the API, blocks duplicate taps and allows retry after rejection',
      (tester) async {
    var requests = 0;
    final pending = Completer<ResponseBody>();
    final client = Dio()
      ..httpClientAdapter = _Adapter((options) async {
        expect(options.method, 'PATCH');
        expect(options.headers['Authorization'], 'Bearer session');
        requests++;
        return requests == 1
            ? pending.future
            : ResponseBody.fromString('{}', 200);
      });
    await open(tester, client: client);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('venue_id', 'venue');
    await prefs.setString('jwt_token', 'session');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Saving...'), findsOneWidget);
    await tester.tap(find.text('Saving...'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.byType(ReviewVenueDetailsScreen), findsNothing);
    pending.complete(
        ResponseBody.fromString('{"message":"Invalid GSTIN"}', 400, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    }));
    await tester.pumpAndSettle();
    expect(toast, 'Invalid GSTIN');
    expect(find.byType(ReviewVenueDetailsScreen), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.byType(ReviewVenueDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
