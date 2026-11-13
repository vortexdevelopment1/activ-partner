import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:activ_app/Screens/activity_details_form.dart';

void main() {
  testWidgets('Dropdown popup menu stays within form padding when alignedDropdown is true', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: ActivityQuestionInput(
              label: 'Court Type',
              type: 'select',
              inputKey: const ValueKey('court-type'),
              options: const ['Full Court', 'Half Court'],
              controller: controller,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final dropdownFinder = find.byType(DropdownButton<String>);
    final inputRect = tester.getRect(dropdownFinder);

    // Tap to open dropdown
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // Find CustomPaint of _DropdownMenuPainter
    final customPaintFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_DropdownMenuPainter',
    );
    expect(customPaintFinder, findsOneWidget);
    final menuRect = tester.getRect(customPaintFinder);

    // Verify the menu popup aligns exactly with the input field bounds and respects the 15px form padding
    expect(menuRect.left, equals(inputRect.left));
    expect(menuRect.right, equals(inputRect.right));
    expect(menuRect.width, equals(inputRect.width));
    expect(menuRect.left, equals(15.0));
  });
}
