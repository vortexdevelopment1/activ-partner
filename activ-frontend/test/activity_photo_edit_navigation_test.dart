import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivityConfigureScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddActivitySubmitReviewScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenueTimingScreen.dart';
import 'package:activ_app/Screens/Home/Activities/AddActivities/EditActivityPhotosScreen.dart';
import 'package:activ_app/api_calling/activity_photo_upload.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'session'});
    BASE_URL = 'https://backend.test/api/v1';
  });
  final timing = {
    'Monday': [
      {'open': '09:00 AM', 'close': '06:00 PM', 'capacity': '4', 'price': '500'}
    ]
  };
  List<String> images() =>
      List.generate(5, (i) => 'https://images.test/photo-$i.jpg');
  http.Response response(Object data, [int status = 200]) =>
      http.Response(jsonEncode({'data': data}), status);
  void size(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 2600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> open(WidgetTester tester, http.Client client) async {
    size(tester);
    await tester.pumpWidget(MaterialApp(
        home: AddActivityConfigureScreen(
      activityId: 'same-activity',
      activityName: 'Pickle Ball',
      timing: timing,
      client: client,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-activity-photos')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<EditActivityPhotosScreen>(
                find.byType(EditActivityPhotosScreen))
            .activityId,
        'same-activity');
  }

  Future<void> removeLast(WidgetTester tester) async {
    await tester
        .ensureVisible(find.byKey(const Key('remove-activity-photo-4')));
    await tester.tap(find.byKey(const Key('remove-activity-photo-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove').last);
  }

  for (final exit in ['save', 'back', 'system']) {
    testWidgets(
        'photo edit returns to the same review via $exit and preserves slots',
        (tester) async {
      var urls = images();
      var deletes = 0;
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer session');
        if (request.method == 'DELETE') {
          expect(request.url.path,
              '/api/v1/venues/activities/same-activity/images');
          expect(jsonDecode(request.body), {'imageUrl': urls.last});
          urls = urls.take(4).toList();
          deletes++;
          return response({'imageUrls': urls});
        }
        expect(request.method,
            'GET'); // Never creates a new activity or writes timings.
        if (request.url.path.endsWith('/questions')) return response([]);
        expect(request.url.path, '/api/v1/venues/activities/same-activity');
        return response({
          'id': 'same-activity',
          'name': 'Pickle Ball',
          'imageUrls': urls,
          'amenities': ['Parking']
        });
      });
      await open(tester, client);
      await removeLast(tester);
      await tester.pumpAndSettle();
      expect(find.text('4 / 12 photos'), findsOneWidget);
      if (exit == 'save') {
        await tester.tap(find.text('Save Changes'));
      } else if (exit == 'back') {
        await tester.tap(find.byTooltip('Back to activity review'));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.byType(EditActivityPhotosScreen), findsNothing);
      final review = tester.widget<AddActivityConfigureScreen>(
          find.byType(AddActivityConfigureScreen));
      expect(review.activityId, 'same-activity');
      expect(review.timing, timing);
      expect(deletes, 1);
      expect(
          find
              .byType(Image)
              .evaluate()
              .where((element) =>
                  element.widget is Image &&
                  (element.widget as Image).image is NetworkImage)
              .length,
          4);
      if (exit == 'back') {
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        final dynamic slots = tester.state(find.byType(AddVenueTimingScreen));
        expect(slots.selectedDays, ['Mon']);
        expect(slots.timings['Mon'].timeSlots, timing['Monday']);
      } else {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<AddActivitySubmitReviewScreen>(
                    find.byType(AddActivitySubmitReviewScreen))
                .timing,
            timing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'failed removal keeps photos and allows retry; Back waits for the active save',
      (tester) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final urls = images();
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        if (++calls == 1)
          return http.Response('{"message":"Internal server error"}', 500);
        return pending.future;
      }
      return response(request.url.path.endsWith('/questions')
          ? []
          : {'id': 'same-activity', 'imageUrls': urls});
    });
    await open(tester, client);
    await removeLast(tester);
    await tester.pumpAndSettle();
    expect(find.text('5 / 12 photos'), findsOneWidget);
    expect(find.text('Unable to save activity. Please try again.'),
        findsOneWidget);
    await removeLast(tester);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(EditActivityPhotosScreen), findsOneWidget);
    pending.complete(response({'imageUrls': urls.take(4).toList()}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.byType(AddActivityConfigureScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
      'adding photos appends to this activity and returns saved URLs without creating a new activity',
      () async {
    final urls = images();
    final client = MockClient((request) async {
      expect(
          request.url.path, '/api/v1/venues/activities/same-activity/images');
      expect(request.method, 'POST');
      expect(latin1.decode(request.bodyBytes),
          contains('name="replaceImages"\r\n\r\nfalse'));
      return response({
        'imageUrls': [...urls, 'https://images.test/new.jpg']
      });
    });
    final saved = await ActivityPhotoUploader(client: client, baseUrl: BASE_URL)
        .uploadImages(
      token: 'session',
      serviceId: 'same-activity',
      replaceImages: false,
      images: [
        XFile.fromData(Uint8List.fromList([1, 2, 3]),
            name: 'new.jpg', mimeType: 'image/jpeg')
      ],
    );
    expect(saved.length, 6);
    expect(saved.take(5), urls);
  });
}
