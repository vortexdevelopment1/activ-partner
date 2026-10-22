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

  for (final size in [const Size(360, 740), const Size(430, 932)]) {
    testWidgets('confirm password stays above the keyboard at ${size.width}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
      await tester.pumpAndSettle();
      final confirm = find.byType(TextFormField).at(2);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      await tester.enterText(confirm, 'UpdatedPassword1!');
      await tester.pumpAndSettle();

      final field = tester.getRect(confirm);
      final button = tester
          .getRect(find.widgetWithText(ElevatedButton, 'Update Password'));
      final header = tester.getRect(find.text('Change Password'));
      expect(field.top, greaterThan(header.bottom));
      expect(field.bottom, lessThanOrEqualTo(button.top));
      expect(button.bottom, lessThanOrEqualTo(size.height - 320));
      expect(
          tester
              .widget<EditableText>(find.descendant(
                  of: confirm, matching: find.byType(EditableText)))
              .controller
              .text,
          'UpdatedPassword1!');
      expect(tester.takeException(), isNull);

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.text('Password must contain:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
