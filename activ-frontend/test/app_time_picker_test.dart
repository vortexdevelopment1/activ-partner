import 'package:activ_app/Utills/app_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TimeOfDay? selected;
  bool completed = false;

  Future<void> open(
    WidgetTester tester, {
    TimeOfDay initial = const TimeOfDay(hour: 16, minute: 32),
    Size size = const Size(430, 932),
    double textScale = 1,
    double keyboardHeight = 0,
  }) async {
    selected = null;
    completed = false;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: keyboardHeight)),
        child: child!,
      ),
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                onPressed: () async {
                  selected = await showAppTimePicker(
                      context: context, initialTime: initial);
                  completed = true;
                },
                child: const Text('Pick time'),
              ))),
    ));
    await tester.tap(find.text('Pick time'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, int wheel, int item) async {
    final controller = tester
        .widget<ListWheelScrollView>(find.byType(ListWheelScrollView).at(wheel))
        .controller! as FixedExtentScrollController;
    controller.jumpToItem(item);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'uses the reference bottom sheet with wheels and AM/PM on 24-hour devices',
      (tester) async {
    await open(tester);
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.text('Select Time'), findsOneWidget);
    expect(find.text('Hour'), findsOneWidget);
    expect(find.text('Minute'), findsOneWidget);
    expect(find.text('AM / PM'), findsOneWidget);
    expect(find.byType(ListWheelScrollView), findsNWidgets(3));
    expect(find.text('Selected: 04:32 PM'), findsOneWidget);
    final sheet = tester.widget<Container>(find
        .ancestor(
            of: find.text('Select Time'), matching: find.byType(Container))
        .last);
    expect((sheet.decoration as BoxDecoration).color, const Color(0xFFF4FBD7));
    final confirm = tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Confirm'));
    expect(confirm.style!.backgroundColor!.resolve({}), Colors.black);
    expect(
        confirm.style!.foregroundColor!.resolve({}), const Color(0xFFD7FF35));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(selected, const TimeOfDay(hour: 16, minute: 32));
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each wheel updates the preview and confirms the selected time',
      (tester) async {
    await open(tester, initial: const TimeOfDay(hour: 9, minute: 0));
    await choose(tester, 0, 10);
    await choose(tester, 1, 59);
    await choose(tester, 2, 1);
    expect(find.text('Selected: 11:59 PM'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(selected, const TimeOfDay(hour: 23, minute: 59));
  });

  for (final hour in [0, 12]) {
    testWidgets('preserves ${hour == 0 ? 'midnight' : 'noon'} on confirm',
        (tester) async {
      await open(tester, initial: TimeOfDay(hour: hour, minute: 0));
      expect(find.text('Selected: 12:00 ${hour == 0 ? 'AM' : 'PM'}'),
          findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(selected, TimeOfDay(hour: hour, minute: 0));
    });
  }

  for (final exit in ['Cancel', 'Close', 'back']) {
    testWidgets('$exit discards wheel changes', (tester) async {
      await open(tester);
      await choose(tester, 1, 45);
      if (exit == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester
            .tap(exit == 'Close' ? find.byTooltip('Close') : find.text(exit));
      }
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(selected, isNull);
      expect(find.text('Select Time'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fits a short screen with large text and a keyboard inset',
      (tester) async {
    await open(tester,
        size: const Size(320, 568), textScale: 1.5, keyboardHeight: 220);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(selected, const TimeOfDay(hour: 16, minute: 32));
    expect(tester.takeException(), isNull);
  });
}
