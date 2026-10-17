import 'dart:typed_data';

import 'package:activ_app/Screens/VenuePhotoListViewScreen.dart';
import 'package:activ_app/Screens/VenuePhotoUploadScreen.dart';
import 'package:activ_app/Screens/onboarding_widgets.dart';
import 'package:activ_app/Utills/common_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CommonUtilities.callVenueImagesClear = '';
    VenuePhotoListViewScreen.returnToReviewBuilder = null;
  });

  Future<List<Uint8List>> showUpload(WidgetTester tester,
      {int count = 5, int coverIndex = 0}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final photos = <Uint8List>[];
    for (final name in [
      'badminton',
      'tennis',
      'basketball',
      'hockey',
      'swimming'
    ].take(count)) {
      photos.add((await rootBundle.load('assets/activities/$name.png'))
          .buffer
          .asUint8List());
    }
    await tester.pumpWidget(MaterialApp(
        home: VenuePhotoUploadScreen(
      currentCategory: const {'id': 'badminton', 'title': 'Badminton'},
      initialImageBytes: photos,
      initialCoverIndex: coverIndex,
    )));
    await tester.pumpAndSettle();
    return photos;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(VenuePhotoListViewScreen), findsOneWidget);
  }

  Future<void> chooseAction(WidgetTester tester, String action,
      {int index = 0}) async {
    final menu = find
        .byWidgetPredicate((widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/ic_three_dot.png')
        .at(index);
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  List<Uint8List> thumbnails(WidgetTester tester) => tester
      .widgetList<Image>(find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is MemoryImage))
      .map((widget) => (widget.image as MemoryImage).bytes)
      .toList();

  for (final systemBack in [false, true]) {
    testWidgets(
        'deleted review photo stays deleted after ${systemBack ? "system" : "button"} Back and Next',
        (tester) async {
      final photos = await showUpload(tester);
      await next(tester);
      await chooseAction(tester, 'Delete photo');
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text('Back'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(VenuePhotoUploadScreen), findsOneWidget);
      expect(thumbnails(tester), orderedEquals(photos.skip(1)));
      await next(tester);
      final review = tester.widget<VenuePhotoListViewScreen>(
          find.byType(VenuePhotoListViewScreen));
      expect(review.imageBytes, orderedEquals(photos.skip(1)));
      expect(review.images, hasLength(4));
      expect(review.initialCoverIndex, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cover photo ordering survives Back and Next', (tester) async {
    final photos = await showUpload(tester);
    await next(tester);
    final originalFiles = tester.widget<VenuePhotoListViewScreen>(
        find.byType(VenuePhotoListViewScreen)).images.toList();
    await chooseAction(tester, 'Set as cover photo', index: 1);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    final expected = [photos[1], photos[0], ...photos.skip(2)];
    expect(thumbnails(tester).take(2), orderedEquals(expected.take(2)));
    await next(tester);
    final review = tester.widget<VenuePhotoListViewScreen>(
        find.byType(VenuePhotoListViewScreen));
    expect(review.imageBytes, orderedEquals(expected));
    expect(review.initialCoverIndex, 0);
    expect(review.images.first, same(originalFiles[1]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting before the cover preserves the same cover photo',
      (tester) async {
    final photos = await showUpload(tester, coverIndex: 3);
    await next(tester);
    await chooseAction(tester, 'Delete photo');
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await next(tester);
    final review = tester.widget<VenuePhotoListViewScreen>(
        find.byType(VenuePhotoListViewScreen));
    expect(review.imageBytes, orderedEquals(photos.skip(1)));
    expect(review.initialCoverIndex, 2);
    expect(review.imageBytes[review.initialCoverIndex], same(photos[3]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('review deletion updates the upload minimum photo requirement',
      (tester) async {
    final photos = await showUpload(tester, count: 4);
    await next(tester);
    await chooseAction(tester, 'Delete photo');
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(thumbnails(tester), orderedEquals(photos.skip(1)));
    expect(
        tester
            .widget<OnboardingButton>(
                find.widgetWithText(OnboardingButton, 'Next'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting all review photos clears the upload selection',
      (tester) async {
    await showUpload(tester, count: 4);
    await next(tester);
    for (var index = 0; index < 4; index++) {
      await chooseAction(tester, 'Delete photo');
    }
    expect(find.byType(VenuePhotoListViewScreen), findsNothing);
    expect(find.byType(VenuePhotoUploadScreen), findsOneWidget);
    expect(thumbnails(tester), isEmpty);
    expect(
        tester
            .widget<OnboardingButton>(
                find.widgetWithText(OnboardingButton, 'Next'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
}
