import 'dart:convert';

import 'package:activ_app/Screens/VenueScreen.dart';
import 'package:activ_app/Screens/Home/VenueInfoScreen.dart';
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
      'Satoshi': 'fonts/Satoshi-Medium.otf',
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

  testWidgets('selected venue address fills a missing PIN from coordinates and replaces old PIN', (tester) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'token', 'venue_id': 'venue-1', 'user_type': 'partner',
    });
    var postalLookups = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('places:autocomplete')) return suggestions();
      if (request.url.host == 'places.googleapis.com') {
        return http.Response(jsonEncode({
          'addressComponents': [
            {'longText': 'Ajmer', 'types': ['locality']},
            {'longText': 'Rajasthan', 'types': ['administrative_area_level_1']},
          ],
          'location': {'latitude': 26.45, 'longitude': 74.64},
        }), 200);
      }
      if (request.url.host == 'maps.googleapis.com') {
        postalLookups++;
        return http.Response(jsonEncode({
          'status': 'OK', 'results': [
            {'address_components': [
              {'long_name': '305001', 'types': ['postal_code']},
            ]},
          ],
        }), 200);
      }
      return http.Response(jsonEncode({'data': request.url.path.contains('update-requests/my') ? [] : [
        {'id': 'venue-1', 'name': 'Sports Arena', 'city': 'Indore', 'state': 'Madhya Pradesh', 'zipCode': '452010'},
      ]}), 200);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: VenueInfoScreen(client: client)));
    await tester.pumpAndSettle();
    final address = find.byKey(const Key('venue-update-address'));
    await tester.ensureVisible(address);
    await tester.enterText(address, 'ajmer');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ajmer, Rajasthan, India'));
    await tester.tap(find.text('Ajmer, Rajasthan, India'));
    await tester.pumpAndSettle();
    expect(postalLookups, 1);
    expect(tester.widget<TextFormField>(find.byKey(const Key('venue-update-zipCode'))).controller!.text, '305001');
    expect(tester.widget<TextFormField>(find.byKey(const Key('venue-update-city'))).controller!.text, 'Ajmer');
    expect(tester.takeException(), isNull);
  });
}
