import 'dart:convert';

import 'package:activ_app/Screens/GetStartedScreen.dart';
import 'package:activ_app/Screens/Menu/MenuScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Firebase failure does not prevent local logout', (tester) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'session',
      'user_type': 'partner',
    });
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'data': {
            'partner': {'firstName': 'Partner'}
          }
        }),
        200));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      home: MenuScreen(
        client: client,
        signOut: () async => throw StateError('Firebase unavailable'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Logout'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout').last);
    await tester.pumpAndSettle();

    expect((await SharedPreferences.getInstance()).getString('jwt_token'),
        isNull);
    expect(find.byType(GetStartedScreen), findsOneWidget);
    expect(find.text('Unable to logout. Please try again.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
