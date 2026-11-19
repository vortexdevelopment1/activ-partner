import 'dart:convert';

import 'package:activ_app/Screens/Home/ManagerHomeScreen.dart';
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

  testWidgets('manager filters match Figma order and filter bookings with search', (tester) async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'token'});
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now().toUtc();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/my-approved-venues')) {
        return http.Response(jsonEncode({'data': [
          {'id': 'venue', 'name': 'Arena', 'services': [{'id': 'sport'}]},
        ]}), 200);
      }
      if (!request.url.path.endsWith('/management')) return http.Response('{"data":{}}', 200);
      return http.Response(jsonEncode({'data': {'name': 'Badminton', 'bookings': [
        for (final entry in [
          ('Today Customer', 'completed', now),
          ('Future Customer', 'upcoming', now.add(const Duration(days: 1))),
          ('Past Customer', 'cancelled', now.subtract(const Duration(days: 1))),
        ]) {
          'id': entry.$1, 'customerName': entry.$1, 'status': entry.$2,
          'startsAt': entry.$3.toIso8601String(), 'amount': 500, 'participants': 1,
        },
      ]}}), 200);
    });
    await tester.pumpWidget(MaterialApp(home: ManagerHomeScreen(client: client)));
    await tester.pumpAndSettle();
    Finder tab(String label) => find.widgetWithText(ElevatedButton, label);
    final labels = ['Today', 'Upcoming', 'Past', 'All'];
    for (var i = 0; i < labels.length; i++) {
      expect(tab(labels[i]), findsOneWidget);
      if (i > 0) expect(tester.getCenter(tab(labels[i])).dx,
          greaterThan(tester.getCenter(tab(labels[i - 1])).dx));
    }
    expect(find.text('Today Customer'), findsOneWidget);
    expect(find.text('Future Customer'), findsNothing);
    expect(find.text('Past Customer'), findsNothing);
    await tester.tap(tab('Upcoming'));
    await tester.pumpAndSettle();
    expect(find.text('Future Customer'), findsOneWidget);
    expect(find.text('Today Customer'), findsNothing);
    await tester.tap(tab('Past'));
    await tester.pumpAndSettle();
    expect(find.text('Past Customer'), findsOneWidget);
    expect(find.text('Today Customer'), findsOneWidget);
    await tester.tap(tab('All'));
    await tester.pumpAndSettle();
    expect(find.text('Future Customer'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Future');
    await tester.pumpAndSettle();
    expect(find.text('Future Customer'), findsOneWidget);
    expect(find.text('Today Customer'), findsNothing);
    expect(find.text('Past Customer'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
