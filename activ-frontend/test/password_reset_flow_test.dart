import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:activ_app/Screens/ForgotPasswordScreen.dart';
import 'package:activ_app/Screens/LoginScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'OnboardingRegular': 'fonts/Metropolis-Regular.ttf',
      'OnboardingSemibold': 'fonts/Metropolis-SemiBold.otf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value)))
          .load();
    }
  });

  for (final size in [const Size(430, 932), const Size(360, 740)]) {
    testWidgets('password recovery works at ${size.width}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final body = jsonDecode(request.body);
        if (request.url.path.endsWith('verify-reset-code') &&
            body['code'] != '1234') {
          return http.Response(
              jsonEncode({'message': 'Invalid or expired reset code.'}), 400);
        }
        return http.Response('{"message":"Success"}', 200);
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'OnboardingRegular'),
        builder: (_, child) => RepaintBoundary(key: boundary, child: child),
        home: ForgotPasswordScreen(
            emailId: 'partner@example.com', client: client),
      ));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(ForgotPasswordScreen));
        for (final asset in [
          'assets/logo.png',
          'assets/password_reset_success.png',
          'assets/password_reset_confetti.png'
        ]) {
          await precacheImage(AssetImage(asset), context);
        }
      });
      await tester.pumpAndSettle();

      Future<void> capture(String name) async {
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final context = tester.element(find.byType(Scaffold).last);
          for (final asset in [
            'assets/logo.png',
            'assets/password_reset_success.png',
            'assets/password_reset_confetti.png'
          ]) {
            await precacheImage(AssetImage(asset), context);
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory('build/password-reset-previews')
            ..createSync(recursive: true);
          File('${folder.path}/$name-${size.width.toInt()}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('email');
      await tester.tap(find.byKey(const Key('forgot-send')));
      await tester.pumpAndSettle();
      expect(find.text('Verify code'), findsOneWidget);
      await capture('verify');
      await tester.enterText(find.byKey(const Key('reset-code')), '9999');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Invalid or expired reset code.'), findsOneWidget);
      expect(find.text('Verify code'), findsOneWidget);

      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Didn't receive code? Resend"));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.url.path.endsWith('forgot-password')),
          hasLength(2));
      await tester.enterText(find.byKey(const Key('reset-code')), '1234');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Reset password'), findsOneWidget);
      await capture('password');
      await tester.enterText(
          find.byKey(const Key('reset-password')), 'new-password');
      await tester.enterText(
          find.byKey(const Key('reset-confirm')), 'different');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(requests.where((r) => r.url.path.endsWith('/reset-password')),
          isEmpty);
      await tester.enterText(
          find.byKey(const Key('reset-confirm')), 'new-password');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your password has been reset successfully!'),
          findsOneWidget);
      await capture('success');
      expect(jsonDecode(requests.last.body), {
        'email': 'partner@example.com',
        'code': '1234',
        'newPassword': 'new-password',
      });
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
