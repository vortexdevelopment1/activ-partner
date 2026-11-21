import 'dart:async';
import 'dart:convert';

import 'package:activ_app/Screens/MobileNumberScreen.dart';
import 'package:activ_app/Screens/OTPVerificationScreen.dart';
import 'package:activ_app/Screens/TellUsAboutScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> open(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: child));
    await tester.pump();
  }

  testWidgets('request and verification use the same normalized phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    http.Request? request;
    await open(tester, MobileNumberScreen(client: MockClient((value) async {
      request = value;
      return http.Response('{}', 200);
    })));

    await tester.enterText(find.byKey(const Key('mobile-number')), '9876544567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-submit')));
    await tester.pumpAndSettle();

    expect(jsonDecode(request!.body), {'phone': '9876544567'});
    final otp = tester.widget<OTPVerificationScreen>(find.byType(OTPVerificationScreen));
    expect(otp.mobileNumber, '9876544567');
    expect((await SharedPreferences.getInstance()).getString('userMobileNumber'), '9876544567');
  });

  for (final pasted in [false, true]) {
    testWidgets('${pasted ? 'pasted' : 'typed'} OTP waits for Verify and submits once', (tester) async {
      SharedPreferences.setMockInitialValues({
        'phoneCode': '+91',
        'userMobileNumber': '1111111111',
      });
      final response = Completer<http.Response>();
      final requests = <http.Request>[];
      await open(
        tester,
        OTPVerificationScreen(
          mobileNumber: '9876544567',
          client: MockClient((request) {
            requests.add(request);
            return response.future;
          }),
        ),
      );

      if (pasted) {
        await tester.enterText(find.byKey(const Key('otp-digit-0')), '1234');
      } else {
        for (var i = 0; i < 4; i++) {
          await tester.enterText(find.byKey(Key('otp-digit-$i')), '${i + 1}');
        }
      }
      await tester.pump();
      expect(requests, isEmpty);

      await tester.tap(find.byKey(const Key('otp-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('otp-submit')));
      expect(requests, hasLength(1));
      expect(jsonDecode(requests.single.body), {'phone': '9876544567', 'otp': '1234'});
      expect(tester.widget<TextField>(find.byKey(const Key('otp-digit-0'))).enabled, isFalse);

      response.complete(http.Response('{"message":"Invalid or expired OTP."}', 400));
      await tester.pumpAndSettle();
      expect(find.text('Invalid or expired OTP.'), findsOneWidget);
      expect(find.byType(OTPVerificationScreen), findsOneWidget);
    });
  }

  testWidgets('Firebase failure after HTTP 200 keeps the JWT and navigation',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'phoneCode': '+91',
      'userMobileNumber': '9876544567',
    });
    var syncAttempts = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/verify-otp')) {
        return http.Response(jsonEncode({
          'data': {
            'accessToken': 'test-token',
            'isProfileComplete': false,
            'partner': {
              'isActive': false,
              'phone': '+919876544567',
            },
          }
        }), 200);
      }
      return http.Response('{"data":[]}', 200);
    });

    for (var attempt = 0; attempt < 2; attempt++) {
      await open(
        tester,
        OTPVerificationScreen(
          key: ValueKey(attempt),
          client: client,
          firebasePartnerSync: (_) async {
            syncAttempts++;
            throw StateError('denied');
          },
        ),
      );
      await tester.enterText(find.byKey(const Key('otp-digit-0')), '1234');
      await tester.tap(find.byKey(const Key('otp-submit')));
      await tester.pumpAndSettle();

      expect(find.byType(TellUsAboutScreen), findsOneWidget);
      expect(find.text('Network error. Please check your connection.'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('jwt_token'), 'test-token');
      expect(prefs.getString('firebase_partner_sync_pending'), 'true');
    }
    expect(syncAttempts, 2);
  });
}
