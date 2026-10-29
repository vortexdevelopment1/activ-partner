import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:activ_app/Screens/onboarding_widgets.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivitySubmitReviewScreen.dart';

void main() {
  testWidgets('outlined OnboardingButton retains black disabledForegroundColor when disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnboardingButton(
            label: 'Save as Draft',
            outlined: true,
            onPressed: null,
          ),
        ),
      ),
    );

    final textButton = tester.widget<TextButton>(find.byType(TextButton));
    final resolvedDisabledColor = textButton.style?.foregroundColor?.resolve({WidgetState.disabled});
    expect(resolvedDisabledColor, equals(Colors.black));
    expect(resolvedDisabledColor, isNot(equals(AppColors.yellow)));
  });

  testWidgets('non-outlined OnboardingButton has AppColors.yellow disabledForegroundColor when disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnboardingButton(
            label: 'Submit for review',
            outlined: false,
            onPressed: null,
          ),
        ),
      ),
    );

    final textButton = tester.widget<TextButton>(find.byType(TextButton));
    final resolvedDisabledColor = textButton.style?.foregroundColor?.resolve({WidgetState.disabled});
    expect(resolvedDisabledColor, equals(AppColors.yellow));
  });

  testWidgets('AddActivitySubmitReviewScreen Save as Draft button has black disabledForegroundColor', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddActivitySubmitReviewScreen(
            activityId: 'activity_test',
            activityName: 'Badminton',
            timing: {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final draftButtonFinder = find.widgetWithText(OnboardingButton, 'Save as Draft');
    expect(draftButtonFinder, findsOneWidget);

    final draftButton = tester.widget<OnboardingButton>(draftButtonFinder);
    expect(draftButton.outlined, isTrue);
    expect(draftButton.disabledForegroundColor, equals(Colors.black));

    final textButton = tester.widget<TextButton>(
      find.descendant(of: draftButtonFinder, matching: find.byType(TextButton)),
    );
    final resolvedDisabledColor = textButton.style?.foregroundColor?.resolve({WidgetState.disabled});
    expect(resolvedDisabledColor, equals(Colors.black));
    expect(resolvedDisabledColor, isNot(equals(AppColors.yellow)));
  });
}
