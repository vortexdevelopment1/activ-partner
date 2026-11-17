import 'dart:convert';

import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenueTimingScreen.dart';
import 'package:activ_app/Utills/slot_price_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final value in ['', 'PDF or CSV', '0', '-1', '1.5', '2147483648']) {
    test('rejects invalid capacity $value',
        () => expect(validateSlotCapacity(value), isNotNull));
  }
  for (final value in [
    '',
    'PDF or CSV',
    '0',
    '-1',
    'NaN',
    'Infinity',
    '1e999'
  ]) {
    test('rejects invalid base price $value',
        () => expect(validateSlotPrice(value), isNotNull));
  }
  for (final value in ['PDF or CSV', '-1', 'NaN', 'Infinity', '501']) {
    test('rejects invalid discount $value',
        () => expect(validateDiscountedSlotPrice(value, '500'), isNotNull));
  }
  test('accepts valid numeric values and optional discount', () {
    expect(validateSlotCapacity('20'), isNull);
    expect(validateSlotPrice('500'), isNull);
    expect(validateSlotPrice('123.45'), isNull);
    for (final discount in [null, '', '0', '350', '500']) {
      expect(validateDiscountedSlotPrice(discount, '500'), isNull);
    }
  });

  String? toast;
  var requests = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    requests = 0;
    toast = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      toast = call.arguments['msg'] as String?;
      return true;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'), null));

  Map<String, String> slot([Map<String, String> changes = const {}]) => {
        'open': '09:00 AM',
        'close': '07:00 PM',
        'capacity': '20',
        'price': '500',
        ...changes,
      };
  Future<void> open(
      WidgetTester tester, List<Map<String, String>> slots) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(550, 2500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
        home: AddVenueTimingScreen(
      activityId: 'validation',
      initialTiming: {'Monday': slots},
      client: MockClient((request) async {
        requests++;
        return http.Response(
            jsonEncode({
              'data': request.url.path.endsWith('/questions')
                  ? []
                  : {
                      'id': 'validation',
                      'name': 'Activity',
                      'imageUrls': [],
                      'amenities': []
                    }
            }),
            200);
      }),
    )));
    await tester.pumpAndSettle();
  }

  for (final changes in [
    {'price': 'PDF or CSV'},
    {'discountedPrice': 'PDF or CSV'},
    {'price': 'NaN'},
    {'discountedPrice': 'NaN'},
    {'discountedPrice': 'Infinity'},
    {'capacity': '0'},
    {'capacity': '1.5'},
    {'price': '0'},
    {'discountedPrice': '-1'},
    {'discountedPrice': '501'},
  ]) {
    testWidgets('restored invalid values $changes cannot proceed',
        (tester) async {
      await open(tester, [slot(changes)]);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(toast, isNotNull);
      expect(find.byType(AddVenueTimingScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'price and discount reject pasted document text and show numeric errors',
      (tester) async {
    await open(tester, [slot()]);
    for (final key in ['price', 'discountedPrice', 'capacity']) {
      final field = find.byKey(ValueKey('slot-Mon-$key-0'));
      await tester.enterText(field, 'PDF or CSV');
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)));
      expect(input.controller!.text, isEmpty);
    }
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.text('Enter a valid whole number of members greater than 0.'),
        findsOneWidget);
    expect(
        find.text('Enter a valid slot price greater than 0.'), findsOneWidget);
  });

  for (final changes in [
    {'open': 'bad time'},
    {'open': '99:99 AM'},
    {'close': '09:00 AM'},
    {'open': '08:00 PM'},
  ]) {
    testWidgets('invalid time range $changes cannot proceed', (tester) async {
      await open(tester, [slot(changes)]);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(toast, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('overlapping or repeated ranges cannot proceed', (tester) async {
    await open(tester, [
      slot(),
      slot({'open': '10:00 AM', 'close': '08:00 PM'})
    ]);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(toast, 'Time ranges for Mon must not overlap or repeat.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('adjacent ranges and a blank optional discount can proceed',
      (tester) async {
    await open(tester, [
      slot({'close': '12:00 PM'}),
      slot({'open': '12:00 PM'})
    ]);
    final dynamic state = tester.state(find.byType(AddVenueTimingScreen));
    final timing = state.buildVenueTiming();
    expect(timing['Monday'][0]['discountedPrice'], '500');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(requests, greaterThan(0));
    expect(toast, isNull);
    expect(tester.takeException(), isNull);
  });
}
