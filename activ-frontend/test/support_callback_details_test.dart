import 'dart:async';
import 'dart:convert';

import 'package:activ_app/Screens/HelpSupportScreen.dart';
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
  setUp(() => SharedPreferences.setMockInitialValues({
    'jwt_token': 'token', 'venue_id': 'selected',
  }));

  Future<void> show(WidgetTester tester, http.Client client, {bool settle = true}) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: RequestCallbackScreen(client: client)));
    await tester.pump();
    if (settle) await tester.pumpAndSettle();
  }

  String value(WidgetTester tester, int index) =>
      tester.widget<TextField>(find.byType(TextField).at(index)).controller!.text;
  http.Response profile() => http.Response(jsonEncode({'data': {'partner': {
    'firstName': 'Test', 'lastName': 'Partner',
    'phone': '+919876543210', 'email': 'partner@example.com',
  }}}), 200);
  http.Response venue() => http.Response(jsonEncode({'data': {
    'id': 'selected', 'name': 'Selected Arena', 'city': 'Pune',
  }}), 200);

  testWidgets('fresh login autofills contact details and the selected venue from APIs', (tester) async {
    final paths = <String>[];
    await show(tester, MockClient((request) async {
      paths.add(request.url.path);
      expect(request.headers['Authorization'], 'Bearer token');
      return request.url.path.endsWith('/auth-profile') ? profile() : venue();
    }));
    expect(paths.any((path) => path.endsWith('/venues/selected')), isTrue);
    expect(paths.any((path) => path.endsWith('/my-venues')), isFalse);
    expect([for (var i = 0; i < 5; i++) value(tester, i)],
        ['Test Partner', 'Selected Arena', 'Pune', '9876543210', 'partner@example.com']);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cached details remain available during an outage without changing venue cache', (tester) async {
    final cachedVenue = jsonEncode({'venue_name': 'Cached Arena', 'venue_city': 'Delhi', 'other': 'preserved'});
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'token', 'owner_full_name': 'Cached Partner',
      'owner_email': 'cached@example.com', 'userMobileNumber': '+919123456789',
      'venue_details': cachedVenue,
    });
    await show(tester, MockClient((_) async => http.Response('{}', 503)));
    expect([for (var i = 0; i < 5; i++) value(tester, i)],
        ['Cached Partner', 'Cached Arena', 'Delhi', '9123456789', 'cached@example.com']);
    expect((await SharedPreferences.getInstance()).getString('venue_details'), cachedVenue);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('without a selected venue the partner venue list supplies the identity', (tester) async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'token'});
    await show(tester, MockClient((request) async {
      if (request.url.path.endsWith('/auth-profile')) return profile();
      expect(request.url.path, endsWith('/my-venues'));
      return http.Response(jsonEncode({'data': {'items': [
        {'id': 'first', 'name': 'First Arena', 'city': 'Mumbai'},
        {'id': 'last', 'name': 'Other Arena', 'city': 'Delhi'},
      ]}}), 200);
    }));
    expect(value(tester, 1), 'First Arena');
    expect(value(tester, 2), 'Mumbai');
  });

  testWidgets('failed autofill offers retry and then loads details', (tester) async {
    var failed = true;
    await show(tester, MockClient((request) async => failed
        ? http.Response('{}', 503)
        : request.url.path.endsWith('/auth-profile') ? profile() : venue()));
    expect(find.text('Retry'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(value(tester, 0), 'Test Partner');
    expect(value(tester, 1), 'Selected Arena');
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('late autofill preserves edited contact fields', (tester) async {
    final pending = Completer<http.Response>();
    await show(tester, MockClient((request) => request.url.path.endsWith('/auth-profile')
        ? pending.future : Future.value(venue())), settle: false);
    await tester.enterText(find.byType(TextField).at(3), '9123456789');
    await tester.enterText(find.byType(TextField).at(4), 'updated@example.com');
    pending.complete(profile());
    await tester.pumpAndSettle();
    expect(value(tester, 3).replaceAll(RegExp(r'\D'), ''), '9123456789');
    expect(value(tester, 4), 'updated@example.com');
    expect(value(tester, 0), 'Test Partner');
  });

  testWidgets('leaving the form while loading does not update disposed controllers', (tester) async {
    final pending = Completer<http.Response>();
    await show(tester, MockClient((_) => pending.future), settle: false);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(profile());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
