import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Utills/app_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app clock uses onboarding theme and AM/PM on 24-hour devices',
      (tester) async {
    TimeOfDay? selected;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            selected = await showAppTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 16, minute: 32),
            );
          },
          child: const Text('Pick time'),
        ),
      ),
    ));
    await tester.tap(find.text('Pick time'));
    await tester.pumpAndSettle();
    final dialog = find.byType(TimePickerDialog);
    final context = tester.element(dialog);
    expect(MediaQuery.of(context).alwaysUse24HourFormat, isFalse);
    expect(Theme.of(context).colorScheme.primary, AppColors.green);
    expect(tester.widget<TimePickerDialog>(dialog).initialEntryMode,
        TimePickerEntryMode.dial);
    expect(find.text('AM'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(selected, const TimeOfDay(hour: 16, minute: 32));
  });
}
