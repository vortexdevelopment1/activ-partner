import 'package:activ_app/Screens/activity_details_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Unit picker dropdown opens adjacent to the dropdown field when near bottom', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String selected = 'hours';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 620),
              ActivityQuestionInput(
                label: 'Session Duration',
                type: 'number',
                inputKey: const ValueKey('session-duration'),
                unit: 'mins',
                selectedUnit: selected,
                onUnitChanged: (val) => selected = val,
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final pickerFinder = find.text('hours');
    expect(pickerFinder, findsOneWidget);
    final pickerY = tester.getTopLeft(pickerFinder).dy;
    expect(pickerY, greaterThan(600));

    await tester.tap(pickerFinder);
    await tester.pumpAndSettle();

    final minsFinder = find.text('mins');
    expect(minsFinder, findsOneWidget);
    final minsY = tester.getTopLeft(minsFinder).dy;

    // The menu should open near pickerY, NOT at the top of the screen (e.g. minsY should be > 500)
    expect(minsY, greaterThan(500), reason: 'Dropdown opened at $minsY which is too far from picker at $pickerY');
  });
}
