import 'dart:async';
import 'dart:convert';

import 'package:activ_app/Screens/onboarding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const buttonKey = Key('support-drag-button');
  Future<void> showSupport(WidgetTester tester, {http.Client? client}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Stack(children: [
        const Positioned.fill(child: ColoredBox(color: Colors.white)),
        DraggableOnboardingSupportMenu(buttonKey: buttonKey, client: client),
      ])),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openCallback(WidgetTester tester, http.Client client) async {
    await showSupport(tester, client: client);
    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request Callback'));
    await tester.pumpAndSettle();
  }

  testWidgets('signed-out visitors can enter and submit callback details', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Map<String, dynamic>? sentDetails;
    await openCallback(tester, MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/support/callback'));
      sentDetails = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 201);
    }));

    final details = {
      'partnerName': 'Alex Sharma',
      'venueName': 'City Arena',
      'city': 'Pune',
      'phone': '9876543210',
      'email': 'alex@example.test',
      'query': 'Please help me list a venue.',
    };
    for (final entry in details.values.indexed) {
      final field = find.byType(TextField).at(entry.$1);
      await tester.ensureVisible(field);
      expect(tester.widget<TextField>(field).readOnly, isFalse);
      await tester.enterText(field, entry.$2);
    }
    await tester.tap(find.text('Request Call Back'));
    await tester.pumpAndSettle();

    expect(sentDetails, containsPair('callbackTime', '10:00 AM'));
    for (final entry in details.entries) {
      expect(sentDetails, containsPair(entry.key, entry.value));
    }
    expect(find.text('Callback requested successfully.'), findsOneWidget);
  });

  testWidgets('late venue autofill preserves callback fields already edited', (tester) async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session', 'venue_name': 'Saved Arena'});
    final response = Completer<http.Response>();
    await openCallback(tester, MockClient((_) => response.future));
    final venue = find.byType(TextField).at(1);
    final city = find.byType(TextField).at(2);
    expect(tester.widget<TextField>(venue).controller!.text, 'Saved Arena');
    await tester.enterText(venue, 'Typed Arena');
    await tester.enterText(city, 'Pune');

    response.complete(http.Response(jsonEncode({
      'data': [{'name': 'Server Arena', 'city': 'Mumbai'}],
    }), 200));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(venue).controller!.text, 'Typed Arena');
    expect(tester.widget<TextField>(city).controller!.text, 'Pune');
  });

  testWidgets('support button moves with a drag and remains tappable', (tester) async {
    await showSupport(tester);
    final button = find.byKey(buttonKey);
    final before = tester.getCenter(button);
    await tester.drag(button, const Offset(-240, -180));
    await tester.pumpAndSettle();
    final after = tester.getCenter(button);
    expect(after.dx, lessThan(before.dx - 150));
    expect(after.dy, lessThan(before.dy - 100));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-support-panel')), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-support-panel')), findsNothing);
  });

  testWidgets('open support button can be dragged and panel follows it', (tester) async {
    await showSupport(tester);
    final button = find.byKey(buttonKey);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final before = tester.getCenter(button);
    final panel = find.byKey(const Key('onboarding-support-panel'));
    final panelBefore = tester.getRect(panel);
    await tester.drag(button, const Offset(-240, -120));
    await tester.pumpAndSettle();
    expect(tester.getCenter(button).dx, lessThan(before.dx - 150));
    expect(tester.getCenter(button).dy, lessThan(before.dy - 80));
    expect(tester.getRect(panel).top, lessThan(panelBefore.top - 80));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
