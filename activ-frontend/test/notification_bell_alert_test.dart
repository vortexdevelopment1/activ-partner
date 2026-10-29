import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:activ_app/Screens/Home/HomeScreen.dart';
import 'package:activ_app/Screens/Home/NotificationsScreen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'fake_jwt_token',
      'user_type': 'partner',
    });
  });

  testWidgets('notification bell shows alert badge when there are unread notifications', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/unread-count')) {
        return http.Response(
          jsonEncode({
            'message': 'Unread count fetched successfully',
            'data': {'count': 3},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/my-approved-venues')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'venue_123',
                'name': 'The Hunt',
                'status': 'APPROVED',
                'bookingAccept': true,
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/team')) {
        return http.Response(
          jsonEncode({'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/bank-accounts/my')) {
        return http.Response(
          jsonEncode({'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(jsonEncode({'data': {}}), 200, headers: {'content-type': 'application/json'});
    });

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(client: mockClient),
    ));

    await tester.pumpAndSettle();

    // Verify unread alert badge with '3' is rendered in the bell stack
    final bellStack = find.byWidgetPredicate(
      (widget) => widget is Stack && widget.clipBehavior == Clip.none,
    );
    expect(bellStack, findsOneWidget);

    final badgeFinder = find.descendant(of: bellStack, matching: find.text('3'));
    expect(badgeFinder, findsOneWidget);

    // Tap the bell icon
    final bellFinder = find.byWidgetPredicate(
      (widget) => widget is InkWell && widget.child is Stack,
    );
    expect(bellFinder, findsOneWidget);

    await tester.tap(bellFinder);
    await tester.pumpAndSettle();

    // Navigated to NotificationsScreen
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('notification bell shows no badge when unread count is 0', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/unread-count')) {
        return http.Response(
          jsonEncode({
            'message': 'Unread count fetched successfully',
            'data': {'count': 0},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/my-approved-venues')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'venue_123',
                'name': 'The Hunt',
                'status': 'APPROVED',
                'bookingAccept': true,
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/team')) {
        return http.Response(
          jsonEncode({'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/bank-accounts/my')) {
        return http.Response(
          jsonEncode({'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(jsonEncode({'data': {}}), 200, headers: {'content-type': 'application/json'});
    });

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(client: mockClient),
    ));

    await tester.pumpAndSettle();

    // Verify no badge is rendered inside the bell stack
    final bellStack = find.byWidgetPredicate(
      (widget) => widget is Stack && widget.clipBehavior == Clip.none,
    );
    expect(bellStack, findsOneWidget);

    final badgeDescendant = find.descendant(of: bellStack, matching: find.byType(Positioned));
    expect(badgeDescendant, findsNothing);
  });
}
