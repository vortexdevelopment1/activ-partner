import 'dart:convert';

import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenuePhotoListViewScreen.dart';
import 'package:activ_app/api_calling/activity_photo_upload.dart';
import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PhotoPicker extends ImagePicker {
  _PhotoPicker(this.photos);
  final List<XFile> photos;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => photos;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Satoshi')
          ..addFont(rootBundle.load('fonts/Satoshi-Medium.otf')))
        .load();
  });
  final photos = List.generate(
      4,
      (i) => XFile.fromData(Uint8List.fromList([137, 80, 78, 71, i]),
          name: 'photo_$i.png', path: 'photo_$i.png', mimeType: 'image/png'));
  http.Response json(dynamic data, {int status = 200}) =>
      http.Response(jsonEncode({'data': data}), status);
  Future<String> upload(http.Client client,
          {List<XFile>? images, String venueId = 'venue'}) =>
      ActivityPhotoUploader(
              client: client, baseUrl: 'https://backend.test/api/v1')
          .upload(
        token: 'session',
        venueId: venueId,
        category: {'id': 'legacy-firebase-id', 'title': 'Swimming'},
        images: images ?? photos,
      );
  http.Response categories() => json([
        {'id': 'swimming-category', 'name': 'Swimming'}
      ]);

  testWidgets('review header is left aligned and plus adds another photo',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'operate_value': jsonEncode({'title': 'Boxing'}),
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    List<XFile>? changed;
    final added = XFile.fromData(
      Uint8List.fromList([137, 80, 78, 71, 99]),
      name: 'added.png',
      mimeType: 'image/png',
    );

    await tester.pumpWidget(MaterialApp(
      home: AddVenuePhotoListViewScreen(
        images: photos,
        imagePicker: _PhotoPicker([added]),
        onPhotosChanged: (images) => changed = images,
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Boxing')).dx,
        tester.getTopLeft(find.text("Upload this activity's images")).dx);
    await tester.tap(find.byKey(const ValueKey('add-activity-photos')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(changed, hasLength(5));
    expect(changed!.last, same(added));
  });

  testWidgets('photo added from review is included in the final upload',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'session',
      'operate_value': jsonEncode({'title': 'Boxing'}),
    });
    final added = XFile.fromData(
      Uint8List.fromList([137, 80, 78, 71, 99]),
      name: 'added.png',
      mimeType: 'image/png',
    );
    var uploadedFiles = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/questions')) return json([]);
      if (request.method == 'GET') {
        return json({'id': 'activity', 'status': 'draft'});
      }
      if (request.method == 'POST') {
        final body = latin1.decode(request.bodyBytes);
        uploadedFiles = 'name="images"'.allMatches(body).length;
        expect(body, contains('added.png'));
        return json({
          'imageUrls': List.generate(uploadedFiles, (i) => 'image-$i'),
        });
      }
      throw StateError('Unexpected request ${request.method} ${request.url}');
    });

    await tester.pumpWidget(MaterialApp(
      home: AddVenuePhotoListViewScreen(
        images: photos,
        activityId: 'activity',
        uploadFuture: Future<void>.value(),
        imagePicker: _PhotoPicker([added]),
        client: client,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-activity-photos')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(uploadedFiles, 5);
  });

  for (final useHandle in [true, false]) {
    testWidgets('photo review swaps cover using ${useHandle ? 'the visible handle' : 'a long press'}', (tester) async {
      SharedPreferences.setMockInitialValues({'operate_value': jsonEncode({'title': 'Gym'})});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1100);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final images = ['swimming', 'tennis', 'yoga', 'volleyball']
          .map((name) => XFile('assets/activities/$name.png')).toList();
      List<XFile>? changed;
      await tester.pumpWidget(MaterialApp(home: AddVenuePhotoListViewScreen(
        images: images, onPhotosChanged: (photos) => changed = photos,
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('drag the handle to reorder'), findsOneWidget);
      final handles = find.byType(ReorderableDragStartListener);
      final from = useHandle
          ? tester.getCenter(handles.at(1))
          : tester.getCenter(find.byType(Card).at(1));
      final to = tester.getCenter(handles.first);
      if (useHandle) expect(handles.at(1).hitTestable(), findsOneWidget);
      final gesture = await tester.startGesture(from);
      if (!useHandle) await tester.pump(const Duration(milliseconds: 650));
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(changed?.map((image) => image.path), [
        images[1].path, images[0].path, images[2].path, images[3].path,
      ]);
      expect(find.descendant(
          of: find.byKey(ValueKey('img_1_${images[1].path}')),
          matching: find.text('Cover Photo')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('uploads ordered photos with MIME types, auth and replacement on retry',
      () async {
    var uploads = 0;
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer session');
      if (request.url.path.endsWith('categories/active')) return categories();
      if (request.url.path.endsWith('venue/activities')) {
        expect(jsonDecode(request.body), {'categoryId': 'swimming-category'});
        return json({'id': 'activity'}, status: 201);
      }
      expect(request.url.path, '/api/v1/venues/activities/activity/images');
      expect(request.headers['content-type'],
          startsWith('multipart/form-data; boundary='));
      final body = latin1.decode(request.bodyBytes);
      expect(body, contains('name="replaceImages"\r\n\r\ntrue'));
      expect('content-type: image/png'.allMatches(body), hasLength(4));
      expect(
          body.indexOf('photo_0.png'), lessThan(body.indexOf('photo_1.png')));
      uploads++;
      return json({
        'id': 'activity',
        'imageUrls': List.generate(4, (i) => 'https://images.test/$i')
      }, status: 201);
    });
    expect(await upload(client), 'activity');
    expect(await upload(client), 'activity');
    expect(uploads, 2);
  });

  test('missing venue selection recovers the only approved venue', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('categories/active')) return categories();
      if (request.url.path.endsWith('my-approved-venues')) {
        return json([
          {'id': 'approved'}
        ]);
      }
      if (request.method == 'POST' && request.url.path.endsWith('activities')) {
        expect(request.url.path, contains('/venues/approved/activities'));
        return json({'id': 'activity'});
      }
      return json({'imageUrls': List.filled(4, 'url')});
    });
    expect(await upload(client, venueId: ''), 'activity');
  });

  test('rejects fewer than four photos before any network requests', () async {
    await expectLater(
        upload(MockClient((_) async => throw StateError('Unexpected request')),
            images: photos.take(3).toList()),
        throwsA(isA<ActivityUploadException>()
            .having((e) => e.message, 'message', contains('4 and 12'))));
  });

  test('rejects renamed duplicate files before any upload', () async {
    final client =
        MockClient((_) async => throw StateError('Unexpected request'));
    await expectLater(
      ActivityPhotoUploader(client: client, baseUrl: BASE_URL).uploadImages(
        token: 'session',
        serviceId: 'activity',
        images: [
          photos.first,
          XFile.fromData(await photos.first.readAsBytes(), name: 'renamed.png'),
        ],
      ),
      throwsA(isA<ActivityUploadException>().having(
          (e) => e.message, 'message', contains('Photo already added'))),
    );
  });

  test(
      'rejects a photo already saved to the activity without sending auth to the CDN',
      () async {
    var uploads = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') uploads++;
      expect(request.url.host, 'images.test');
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response.bytes(await photos.first.readAsBytes(), 200);
    });
    await expectLater(
      ActivityPhotoUploader(client: client, baseUrl: BASE_URL).uploadImages(
        token: 'session',
        serviceId: 'activity',
        images: [photos.first],
        replaceImages: false,
        existingImageUrls: ['https://images.test/saved.png'],
      ),
      throwsA(isA<ActivityUploadException>().having(
          (e) => e.message, 'message', contains('Photo already added'))),
    );
    expect(uploads, 0);
  });

  test('distinct content uploads even when filenames match', () async {
    var uploads = 0;
    final saved = ['https://images.test/old.png'];
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response.bytes([9, 8, 7], 200);
      uploads++;
      expect(request.headers['Authorization'], 'Bearer session');
      expect(latin1.decode(request.bodyBytes),
          contains('name="replaceImages"\r\n\r\nfalse'));
      return json({
        'imageUrls': [...saved, 'new-1', 'new-2']
      });
    });
    final urls = await ActivityPhotoUploader(client: client, baseUrl: BASE_URL)
        .uploadImages(
      token: 'session',
      serviceId: 'activity',
      replaceImages: false,
      existingImageUrls: saved,
      images: [
        for (final bytes in [
          [1, 2],
          [3, 4]
        ])
          XFile.fromData(Uint8List.fromList(bytes), name: 'photo.png')
      ],
    );
    expect(uploads, 1);
    expect(urls, [...saved, 'new-1', 'new-2']);
  });

  test('failed saved-photo check prevents uploading and allows retry',
      () async {
    var fail = true;
    var uploads = 0;
    final uploader = ActivityPhotoUploader(
        baseUrl: BASE_URL,
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return fail
                ? http.Response('', 503)
                : http.Response.bytes([9], 200);
          }
          uploads++;
          return json({
            'imageUrls': ['old', 'new']
          });
        }));
    Future<List<String>> add() => uploader.uploadImages(
          token: 'session',
          serviceId: 'activity',
          replaceImages: false,
          existingImageUrls: ['https://images.test/old.png'],
          images: [photos.first],
        );
    await expectLater(add(), throwsA(isA<ActivityUploadException>()));
    expect(uploads, 0);
    fail = false;
    expect(await add(), ['old', 'new']);
    expect(uploads, 1);
  });

  test('expired session and backend validation explain how to recover',
      () async {
    for (final status in [401, 400]) {
      await expectLater(
          upload(MockClient((_) async => http.Response(
              jsonEncode({
                'message': 'Activities can only be added to an approved venue'
              }),
              status))),
          throwsA(isA<ActivityUploadException>().having(
              (e) => e.message,
              'message',
              contains(status == 401 ? 'sign in again' : 'approved venue'))));
    }
  });

  test('connection failure has a retry message', () async {
    await expectLater(
        upload(MockClient((_) async => throw http.ClientException('offline'))),
        throwsA(isA<ActivityUploadException>()
            .having((e) => e.message, 'message', contains('connection'))));
  });

  test('does not advance when upload returns no saved image URLs', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('categories/active')) return categories();
      return json({'id': 'activity'});
    });
    await expectLater(
        upload(client),
        throwsA(isA<ActivityUploadException>()
            .having((e) => e.message, 'message', contains('not saved'))));
  });

  testWidgets(
      'failed upload retains the Swimming photo review at 3/6 and permits retry',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'session',
      'venue_id': 'venue',
      'operate_value': jsonEncode({'title': 'Swimming'}),
    });
    BASE_URL = 'https://backend.test/api/v1';
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(292, 642);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = (await rootBundle.load('assets/activities/swimming.png'))
        .buffer
        .asUint8List();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: AddVenuePhotoListViewScreen(
      images: List.generate(4,
          (_) => XFile.fromData(bytes, path: 'assets/activities/swimming.png')),
      activityId: 'activity',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/questions')) return json([]);
        calls++;
        return http.Response(
            '{"message":"Activities can only be added to an approved venue"}',
            400);
      }),
    )));
    await tester.pumpAndSettle();
    expect(find.text('3/6'), findsOneWidget);
    expect(find.text('Swimming'), findsOneWidget);
    expect(find.text("Upload this activity's images"), findsOneWidget);
    expect(find.text('Cover Photo'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Next'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Activities can only be added to an approved venue'),
        findsOneWidget);
    expect(find.text('3/6'), findsOneWidget);
    // The snackbar temporarily covers the footer, as in the reported screen.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Next'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
