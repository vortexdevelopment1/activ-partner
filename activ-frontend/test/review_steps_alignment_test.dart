import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivitySubmitReviewScreen.dart';

void main() {
  testWidgets('verifies that stepper circles 1 to 5 are horizontally centered above their numbers', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AddActivitySubmitReviewScreen(
          activityId: 'activity_test',
          activityName: 'Badminton',
          timing: {},
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('What happens next?'), findsOneWidget);

    for (var i = 1; i <= 5; i++) {
      final numberFinder = find.text('$i');
      expect(numberFinder, findsOneWidget);
    }

    // Verify each circle's center X matches its number's center X
    final circles = find.byType(Container).evaluate().where((element) {
      final widget = element.widget as Container;
      final dec = widget.decoration;
      return dec is BoxDecoration && dec.shape == BoxShape.circle;
    }).toList();

    expect(circles.length, greaterThanOrEqualTo(5));

    // The first 5 circle containers corresponding to the 5 step icons
    for (var i = 0; i < 5; i++) {
      final numberFinder = find.text('${i + 1}');
      final numberCenterX = tester.getCenter(numberFinder).dx;
      final circleFinder = find.byWidget(circles[i].widget);
      final circleCenterX = tester.getCenter(circleFinder).dx;

      // Center of circle must match center of number within 1 pixel
      expect(
        (numberCenterX - circleCenterX).abs(),
        lessThan(1.0),
        reason: 'Circle ${i + 1} and Number ${i + 1} must be centered on the same X coordinate',
      );
    }

    // Verify distance between consecutive circles is equal
    final x1 = tester.getCenter(find.byWidget(circles[0].widget)).dx;
    final x2 = tester.getCenter(find.byWidget(circles[1].widget)).dx;
    final x3 = tester.getCenter(find.byWidget(circles[2].widget)).dx;
    final x4 = tester.getCenter(find.byWidget(circles[3].widget)).dx;
    final x5 = tester.getCenter(find.byWidget(circles[4].widget)).dx;

    final dist12 = x2 - x1;
    final dist23 = x3 - x2;
    final dist34 = x4 - x3;
    final dist45 = x5 - x4;

    expect((dist12 - dist23).abs(), lessThan(1.5), reason: 'Steps 1-2 and 2-3 must be equally spaced');
    expect((dist23 - dist34).abs(), lessThan(1.5), reason: 'Steps 2-3 and 3-4 must be equally spaced');
    expect((dist34 - dist45).abs(), lessThan(1.5), reason: 'Steps 3-4 and 4-5 must be equally spaced');
  });
}
