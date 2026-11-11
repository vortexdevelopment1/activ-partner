import 'package:activ_app/Screens/Menu/SettingsScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Satoshi')
          ..addFont(rootBundle.load('fonts/Satoshi-Medium.otf')))
        .load();
  });

  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    for (final textScale in [1.0, 1.25]) {
      testWidgets(
          'Cancel and Delete Account buttons fit on one line at ${width}px with scale $textScale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => SettingsScreen.showDeleteAccountSheetForTesting(context),
                    child: const Text('Open Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Delete Account?'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Delete Account'), findsOneWidget);

        // Cancel text must have a single line height (should not wrap)
        final cancelTextWidget = tester.firstWidget<Text>(find.text('Cancel'));
        expect(cancelTextWidget.maxLines, equals(1));

        final deleteTextWidget = tester.firstWidget<Text>(find.text('Delete Account'));
        expect(deleteTextWidget.maxLines, equals(1));

        // Check button bounds do not overflow screen
        final cancelRect = tester.getRect(find.widgetWithText(OutlinedButton, 'Cancel'));
        final deleteRect = tester.getRect(find.widgetWithText(ElevatedButton, 'Delete Account'));

        expect(cancelRect.left, greaterThanOrEqualTo(0));
        expect(cancelRect.right, lessThan(deleteRect.left));
        expect(deleteRect.right, lessThanOrEqualTo(width));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

