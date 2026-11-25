import 'dart:async';

import 'package:activ_app/Screens/Home/HomeScreen.dart';
import 'package:activ_app/Screens/LoginScreen.dart';
import 'package:activ_app/Screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'startup checks run behind splash and reveal only the resolved screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'saved-token',
      'user_type': 'partner',
      'is_profile_complete': 'true',
      'is_active': 'true',
    });
    final authResponse = Completer<http.Response>();
    var requestStarted = false;
    final client = MockClient((_) {
      requestStarted = true;
      return authResponse.future;
    });

    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(client: client)),
    );
    await tester.pump();

    expect(requestStarted, isTrue);
    expect(find.byKey(const ValueKey('startup-splash-overlay')),
        findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('startup-splash-overlay')),
        findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);

    authResponse.complete(http.Response('', 401));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
