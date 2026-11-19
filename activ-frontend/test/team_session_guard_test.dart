import 'dart:async';

import 'package:activ_app/Screens/LoginScreen.dart';
import 'package:activ_app/Screens/team_session_guard.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:activ_app/api_calling/api_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late GlobalKey<NavigatorState> navigator;
  late int signOuts;
  setUp(() async {
    navigator = GlobalKey<NavigatorState>();
    signOuts = 0;
    BASE_URL = 'https://backend.test/api/v1';
    SharedPreferences.setMockInitialValues({});
    await SharedPreference.clearSF();
    final session = {
      'jwt_token': 'staff-token', 'user_type': 'team_member',
      'permissions': '{"bookingManagement":true}', 'venue_id': 'private-venue',
    };
    for (final entry in session.entries) {
      await SharedPreference.addStringToSF(entry.key, entry.value);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  });
  tearDown(() => SharedPreference.clearSF());

  Future<void> show(WidgetTester tester, http.Client client,
      {Future<void> Function()? signOut}) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      builder: (_, child) => TeamSessionGuard(
        navigatorKey: navigator, client: client,
        signOut: signOut ?? () async { signOuts++; },
        child: child!,
      ),
      home: const Scaffold(body: Text('Team dashboard')),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('removed member is logged out while on a nested route and cannot navigate back', (tester) async {
    var removed = false;
    var checks = 0;
    final requestedTokens = <String?>[];
    final paths = <String>[];
    await show(tester, MockClient((request) async {
      checks++;
      paths.add(request.url.path);
      requestedTokens.add(request.headers['Authorization']);
      return http.Response('{}', removed ? 401 : 200);
    }));
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Private member detail')),
    ));
    await tester.pumpAndSettle();
    unawaited(showDialog<void>(context: navigator.currentContext!,
      builder: (_) => const AlertDialog(title: Text('Private dialog'))));
    await tester.pumpAndSettle();
    removed = true;
    await tester.pump(TeamSessionGuard.checkInterval);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Private member detail'), findsNothing);
    expect(find.text('Private dialog'), findsNothing);
    expect(navigator.currentState!.canPop(), isFalse);
    expect(await SharedPreference.readStr('jwt_token'), isNull);
    expect(await SharedPreference.readStr('permissions'), isNull);
    expect(await SharedPreference.readStr('venue_id'), isNull);
    expect(signOuts, 1);
    expect(paths.every((path) => path.endsWith('/auth/partner/auth-profile')), isTrue);
    expect(requestedTokens.every((token) => token == 'Bearer staff-token'), isTrue);
    final checksAfterLogout = checks;
    await tester.pump(TeamSessionGuard.checkInterval);
    expect(checks, checksAfterLogout);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final failure in ['server', 'permission', 'network']) {
    testWidgets('$failure failures preserve the session and retry', (tester) async {
      var checks = 0;
      await show(tester, MockClient((_) async {
        checks++;
        if (failure == 'network') throw http.ClientException('offline');
        return http.Response('{}', failure == 'server' ? 503 : 403);
      }));
      await tester.pump(TeamSessionGuard.checkInterval);
      await tester.pumpAndSettle();
      expect(checks, 2);
      expect(await SharedPreference.readStr('jwt_token'), 'staff-token');
      expect(find.text('Team dashboard'), findsOneWidget);
      expect(signOuts, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('a stale unauthorized response cannot clear a newer login', (tester) async {
    final pending = Completer<http.Response>();
    await show(tester, MockClient((_) => pending.future));
    await SharedPreference.addStringToSF('jwt_token', 'new-partner-token');
    await SharedPreference.addStringToSF('user_type', 'partner');
    pending.complete(http.Response('{}', 401));
    await tester.pumpAndSettle();
    expect(await SharedPreference.readStr('jwt_token'), 'new-partner-token');
    expect(await SharedPreference.readStr('user_type'), 'partner');
    expect(signOuts, 0);
    expect(find.byType(LoginScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('checks are paused in the background and run immediately on resume', (tester) async {
    var checks = 0;
    await show(tester, MockClient((_) async { checks++; return http.Response('{}', 200); }));
    expect(checks, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(checks, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(checks, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('partner accounts are not polled or logged out', (tester) async {
    await SharedPreference.addStringToSF('user_type', 'partner');
    var checks = 0;
    await show(tester, MockClient((_) async { checks++; return http.Response('{}', 401); }));
    await tester.pump(TeamSessionGuard.checkInterval);
    await tester.pumpAndSettle();
    expect(checks, 0);
    expect(signOuts, 0);
    expect(await SharedPreference.readStr('jwt_token'), 'staff-token');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Firebase sign-out failure does not prevent local logout', (tester) async {
    await show(tester, MockClient((_) async => http.Response('{}', 401)),
      signOut: () async { throw StateError('Firebase unavailable'); });
    expect(await SharedPreference.readStr('jwt_token'), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('disposing the app stops checks', (tester) async {
    var checks = 0;
    await show(tester, MockClient((_) async { checks++; return http.Response('{}', 200); }));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
    expect(checks, 1);
  });
}
