import 'dart:convert';

import 'package:activ_app/Screens/VenueScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'FontRegular': 'fonts/Acumin-RPro.otf',
      'FontMedium': 'fonts/AcuminPro-Medium.otf',
      'FontSemiBold': 'fonts/AcuminPro-Semibold.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value))).load();
    }
  });
  setUp(() {
    dotenv.loadFromString(envString: 'GOOGLE_MAPS_API_KEY=test-key');
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> show(WidgetTester tester, http.Client client) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: VenueScreen(client: client)));
    await tester.pumpAndSettle();
  }

  Finder addressField() => find.byWidgetPredicate((widget) =>
      widget is TextField &&
      widget.decoration?.hintText == 'Search your venue address');

  http.Response suggestions() => http.Response(jsonEncode({
    'suggestions': [
      {'placePrediction': {'placeId': 'ajmer-place', 'text': {'text': 'Ajmer, Rajasthan, India'}}},
      {'queryPrediction': {'text': {'text': 'Ignored query'}}},
    ],
  }), 200);

  testWidgets('venue address lookup sends the valid India filter and displays places', (tester) async {
    var calls = 0;
    await show(tester, MockClient((request) async {
      calls++;
      expect(request.headers['X-Goog-Api-Key'], 'test-key');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['input'], 'ajmer');
      expect(body['includedRegionCodes'], ['in']);
      return suggestions();
    }));
    await tester.enterText(addressField(), 'ajmer');
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Ajmer, Rajasthan, India'), findsOneWidget);
    expect(find.text('Ignored query'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed location search shows an error and search button retries', (tester) async {
    var calls = 0;
    await show(tester, MockClient((_) async =>
      ++calls == 1 ? http.Response('{}', 403) : suggestions()));
    await tester.enterText(addressField(), 'ajmer');
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(find.text('Unable to search locations. Please try again.'), findsOneWidget);
    await tester.tap(find.byTooltip('Search locations'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Ajmer, Rajasthan, India'), findsOneWidget);
    expect(find.text('Unable to search locations. Please try again.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
