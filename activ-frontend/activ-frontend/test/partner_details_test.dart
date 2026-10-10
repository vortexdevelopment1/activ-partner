import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:activ_app/Screens/Home/ProfileScreen.dart';
import 'package:activ_app/Screens/ContactSupportFormScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'Satoshi': 'fonts/Satoshi-Medium.otf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value)))
          .load();
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({
        'jwt_token': 'token',
        'user_type': 'partner',
        'venue_id': 'selected',
      }));

  MockClient client(
          {bool verified = true, bool fail = false, bool venueFail = false}) =>
      MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token');
        if (fail) return http.Response('{}', 500);
        if (request.url.path.endsWith('/my-approved-venues')) {
          return http.Response(
              jsonEncode({
                'data': [
                  {'id': 'other', 'venuePhone': '+91 9999999999'},
                  {'id': 'selected', 'venuePhone': '+91 9111467798'},
                ]
              }),
              venueFail ? 500 : 200);
        }
        return http.Response(
            jsonEncode({
              'data': {
                'partner': {
                  'firstName': 'Chetan',
                  'lastName': 'Pawar',
                  'businessName': 'Hsjs',
                  'email': 'Priyanshpawar1207@gmail.com',
                  'phone': '+91 9111467798',
                  'isActive': verified,
                }
              }
            }),
            200);
      });

  Future<void> show(
      WidgetTester tester, http.Client client, Size size, GlobalKey key,
      {double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: RepaintBoundary(key: key, child: ProfileScreen(client: client))));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/partner-details-screenshots')
        ..createSync(recursive: true);
      File('${directory.path}/$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'reference layout displays real locked details and selected venue phone',
      (tester) async {
    final key = GlobalKey();
    await show(tester, client(), const Size(360, 800), key);
    expect(find.text('Partner Details'), findsOneWidget);
    expect(find.text('Verified Partner'), findsOneWidget);
    expect(find.text('Hsjs'), findsOneWidget);
    expect(find.text('Chetan Pawar'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Edit profile photo'), findsOneWidget);
    expect(find.text('Contact Support'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, '360-top');
    await tester.scrollUntilVisible(
        find.text('Need to update your details?'), 180);
    await tester.pumpAndSettle();
    expect(find.text('+91 9111467798'), findsNWidgets(2));
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    await capture(tester, key, '360-bottom');
    await tester.tap(find.text('Contact Support'));
    await tester.pumpAndSettle();
    expect(find.byType(ContactSupportFormScreen), findsOneWidget);
  });

  testWidgets('small, large and enlarged-text layouts do not overflow',
      (tester) async {
    for (final size in [
      const Size(320, 640),
      const Size(430, 932),
      const Size(800, 932)
    ]) {
      final key = GlobalKey();
      await tester.pumpWidget(const SizedBox());
      await show(tester, client(), size, key, scale: 1.5);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
          find.text('Need to update your details?'), 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, key, '${size.width.toInt()}-large-text');
    }
  });

  testWidgets('does not show a verified badge for inactive accounts',
      (tester) async {
    await show(
        tester, client(verified: false), const Size(360, 800), GlobalKey());
    expect(find.text('Verified Partner'), findsNothing);
  });

  testWidgets('profile failure shows retry instead of sample identity',
      (tester) async {
    await show(tester, client(fail: true), const Size(360, 800), GlobalKey());
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Chetan Pawar'), findsNothing);
  });

  testWidgets('venue fetch failure preserves the personal profile',
      (tester) async {
    await show(
        tester, client(venueFail: true), const Size(360, 800), GlobalKey());
    expect(find.text('Chetan Pawar'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Venue Primary Number'), 180);
    expect(find.text('Unable to load venue number'), findsOneWidget);
  });
}
