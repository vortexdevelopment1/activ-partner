import 'dart:io';
import 'dart:ui' as ui;
import 'package:activ_app/Screens/Home/Activities/WalkInBookingSuccessScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Satoshi')
          ..addFont(rootBundle.load('fonts/Satoshi-Medium.otf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final bookAnother in [true, false]) {
    testWidgets(
        'success receipt shows real details and returns bookAnother=$bookAnother',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1100);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      bool? result;
      final capture = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Builder(
                builder: (context) => Scaffold(
                        body: TextButton(
                      onPressed: () async {
                        result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const WalkInBookingSuccessScreen(
                                        venueName: 'Sports Arena Complex',
                                        date: '26 October 2026, Monday',
                                        court: 'Court 01',
                                        slots: [
                                          '06:00 AM - 07:00 AM',
                                          '10:00 PM - 11:00 PM'
                                        ],
                                        participantName: 'Test Participant',
                                        participantPhone: '+91 98000 00000',
                                        participantEmail:
                                            'participant@example.test')));
                      },
                      child: const Text('Open confirmation'),
                    ))),
          )));
      await tester.tap(find.text('Open confirmation'));
      await tester.pumpAndSettle();
      expect(find.text('Walk-In Slot Reserved!'), findsOneWidget);
      expect(find.text('Sports Arena Complex'), findsOneWidget);
      expect(find.text('26 October 2026, Monday'), findsOneWidget);
      expect(find.text('06:00 AM - 07:00 AM'), findsOneWidget);
      expect(find.text('10:00 PM - 11:00 PM'), findsOneWidget);
      expect(find.text('participant@example.test'), findsOneWidget);
      if (const bool.fromEnvironment('CAPTURE_WALK_IN_SUCCESS')) {
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('.dart_tool/booking-preview')
            ..createSync(recursive: true);
          await File('${directory.path}/success.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
      final button = find.text(
          bookAnother ? 'Book Another Slot' : 'Back To Activity Management');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(result, bookAnother);
      expect(tester.takeException(), isNull);
    });
  }
}
