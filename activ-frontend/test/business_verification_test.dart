import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:activ_app/Screens/ContactSupportFormScreen.dart';
import 'package:activ_app/Screens/Home/ViewDocumentScreen.dart';
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
  setUp(() => SharedPreferences.setMockInitialValues({'jwt_token': 'token'}));

  MockClient client(
          {bool verified = true,
          bool gstVerified = false,
          bool pending = false,
          bool fail = false,
          List<Map<String, dynamic>>? venueDocuments}) =>
      MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token');
        if (fail) return http.Response('{}', 500);
        if (request.url.path.endsWith('/gst-verification/my')) {
          return http.Response(
              jsonEncode({
                'data': pending
                    ? {
                        'status': 'pending',
                        'gstNumber': '27AAPFU0939F1ZV',
                        'gstName': 'ACTIV Venue',
                        'gstDocUrl': '/uploads/certificate.pdf',
                      }
                    : null
              }),
              200);
        }
        return http.Response(
            jsonEncode({
              'data': {
                'partner': {
                  if (venueDocuments != null) 'legalDocuments': venueDocuments,
                  'isVerified': verified,
                  'aadhaarCardUrl': '/uploads/aadhaar.jpg',
                  'panCardUrl': '/uploads/pan.pdf',
                  if (verified) 'aadhaarVerifiedAt': '2026-10-07T10:00:00Z',
                  if (verified) 'panVerifiedAt': '2026-10-07T10:00:00Z',
                  if (gstVerified) 'gstVerifiedAt': '2026-10-08T10:00:00Z',
                  if (gstVerified) 'gstinDocUrl': '/uploads/gst.pdf',
                }
              }
            }),
            200);
      });

  Future<void> show(WidgetTester tester, http.Client api, GlobalKey key,
      {Size size = const Size(360, 800), double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: RepaintBoundary(key: key, child: ViewDocumentScreen(client: api)),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/business-verification-screenshots')
        ..createSync(recursive: true);
      File('${directory.path}/$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> reveal(WidgetTester tester, String label) async {
    for (var attempt = 0; attempt < 25; attempt++) {
      if (find.text(label).hitTestable().evaluate().isNotEmpty) return;
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
    }
    fail('Could not scroll to $label');
  }

  testWidgets('verified documents, GST and support match mobile layout',
      (tester) async {
    final key = GlobalKey();
    await show(tester, client(), key);
    expect(find.text('Verified Business'), findsOneWidget);
    expect(find.text('Aadhaar Card'), findsOneWidget);
    expect(find.text('PAN Card'), findsOneWidget);
    expect(find.text('7 Oct 2026'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'documents');
    await reveal(tester, 'Add GSTIN');
    final gstTop = tester.getTopLeft(find.text('GST Details')).dy;
    await tester.drag(find.byType(ListView), Offset(0, 104 - gstTop));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'gst');
    await reveal(tester, 'Submit for Verification');
    await tester.tap(find.text('Submit for Verification'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid GSTIN number.'), findsOneWidget);
    expect(find.text('Enter the business name.'), findsOneWidget);
    await reveal(tester, 'Need to make changes?');
    expect(
        find.text(
            'Document changes are not allowed once verified. Contact ACTIV Support for any updates.'),
        findsOneWidget);
    await capture(tester, key, 'support');
    await tester.tap(find.text('Contact Support'));
    await tester.pumpAndSettle();
    expect(find.byType(ContactSupportFormScreen), findsOneWidget);
  });

  testWidgets('pending GST cannot be resubmitted', (tester) async {
    await show(tester, client(pending: true), GlobalKey());
    await reveal(tester, 'Verification Pending');
    final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Verification Pending'));
    expect(button.onPressed, isNull);
    expect(find.text('Browse'), findsNothing);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.readOnly, isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified GST is locked and has no submission form',
      (tester) async {
    await show(tester, client(gstVerified: true), GlobalKey());
    await reveal(tester, 'GST Certificate');
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Submit for Verification'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screen with larger text does not overflow',
      (tester) async {
    final key = GlobalKey();
    await show(tester, client(), key, size: const Size(320, 720), scale: 1.3);
    expect(tester.takeException(), isNull);
    await reveal(tester, 'Add GSTIN');
    expect(tester.takeException(), isNull);
    await reveal(tester, 'Need to make changes?');
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'narrow-support');
  });

  testWidgets('load failures offer retry without claiming verification',
      (tester) async {
    await show(tester, client(fail: true), GlobalKey());
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Verified Business'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses selected venue stored documents and approval status',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'jwt_token': 'token', 'venue_id': 'selected'});
    await show(
        tester,
        client(verified: false, venueDocuments: [
          {
            'venueId': 'other',
            'isVerified': false,
            'aadhaarCardUrl': null,
            'panCardUrl': null
          },
          {
            'venueId': 'selected',
            'isVerified': true,
            'aadhaarCardUrl': '/legal/aadhaar.jpg',
            'panCardUrl': '/legal/pan.pdf',
            'gstinDocUrl': '/legal/gst.pdf',
            'gstIsVerified': true,
            'aadhaarVerifiedAt': '2026-10-07T10:00:00Z',
            'panVerifiedAt': '2026-10-07T10:00:00Z'
          },
        ]),
        GlobalKey());
    expect(find.text('Verified Business'), findsOneWidget);
    expect(find.text('Not uploaded'), findsNothing);
    for (final button in tester.widgetList<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'View Document'))) {
      expect(button.onPressed, isNotNull);
    }
    await reveal(tester, 'GST Certificate');
    expect(find.text('Submit for Verification'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending stored documents remain viewable with updated date',
      (tester) async {
    await show(
        tester,
        client(verified: false, venueDocuments: [
          {
            'venueId': 'venue',
            'isVerified': false,
            'aadhaarCardUrl': '/legal/aadhaar.jpg',
            'panCardUrl': '/legal/pan.pdf',
            'gstinDocUrl': '/legal/gst.pdf',
            'documentsUpdatedAt': '2026-10-07T10:00:00Z'
          },
        ]),
        GlobalKey());
    expect(find.text('Verification Pending'), findsOneWidget);
    expect(find.text('Not uploaded'), findsNothing);
    expect(find.text('Updated On'), findsNWidgets(2));
    await reveal(tester, 'GST Certificate');
    expect(find.text('GST Certificate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'does not borrow another venues documents when selected venue has none',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'jwt_token': 'token', 'venue_id': 'empty'});
    await show(
        tester,
        client(verified: false, venueDocuments: [
          {
            'venueId': 'other',
            'isVerified': true,
            'aadhaarCardUrl': '/other.jpg',
            'panCardUrl': '/other.pdf'
          },
          {
            'venueId': 'empty',
            'isVerified': false,
            'aadhaarCardUrl': null,
            'panCardUrl': null
          },
        ]),
        GlobalKey());
    expect(find.text('Not uploaded'), findsNWidgets(2));
    expect(find.text('Verification Pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
