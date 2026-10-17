import 'dart:typed_data';

import 'package:activ_app/Screens/VenuePhotoUploadScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PhotoPicker extends ImagePicker {
  final List<List<XFile>> batches;
  XFile? camera;
  _PhotoPicker(this.batches, {this.camera});

  @override
  Future<List<XFile>> pickMultiImage(
          {double? maxWidth,
          double? maxHeight,
          int? imageQuality,
          int? limit,
          bool requestFullMetadata = true}) async =>
      batches.removeAt(0);

  @override
  Future<XFile?> pickImage(
          {required ImageSource source,
          double? maxWidth,
          double? maxHeight,
          int? imageQuality,
          CameraDevice preferredCameraDevice = CameraDevice.rear,
          bool requestFullMetadata = true}) async =>
      camera;
}

class _Compressor extends UnsupportedFlutterImageCompress {
  int calls = 0;
  Uint8List Function(Uint8List)? convert;
  @override
  Future<Uint8List> compressWithList(
    Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    int inSampleSize = 1,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async {
    calls++;
    return convert?.call(image) ?? image;
  }
}

void main() {
  late FlutterImageCompressPlatform originalCompressor;
  late _Compressor compressor;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalCompressor = FlutterImageCompressPlatform.instance;
    compressor = _Compressor();
    FlutterImageCompressPlatform.instance = compressor;
  });
  tearDown(() => FlutterImageCompressPlatform.instance = originalCompressor);

  Future<Uint8List> photo(String name) async =>
      (await rootBundle.load('assets/activities/$name.png'))
          .buffer
          .asUint8List();

  XFile file(Uint8List bytes, String name) =>
      XFile.fromData(Uint8List.fromList(bytes),
          name: name, mimeType: 'image/png');

  Future<void> showUpload(WidgetTester tester, _PhotoPicker picker,
      {List<Uint8List> initial = const []}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: VenuePhotoUploadScreen(
      imagePicker: picker,
      initialImageBytes: initial,
      currentCategory: const {'id': 'badminton', 'title': 'Badminton'},
    )));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, {String source = 'Gallery'}) async {
    await tester.ensureVisible(find.text('Browse'));
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(source));
    await tester.pumpAndSettle();
  }

  List<Image> thumbnails(WidgetTester tester) => tester
      .widgetList<Image>(find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is MemoryImage))
      .toList();

  void expectPopup() {
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
        find.text(
            'You can’t upload the same photo twice. Please choose a different photo.'),
        findsOneWidget);
  }

  testWidgets(
      'duplicate photos in one gallery batch show one popup and keep distinct photos',
      (tester) async {
    final first = await photo('badminton');
    final second = await photo('tennis');
    await showUpload(
        tester,
        _PhotoPicker([
          [
            file(first, 'court.png'),
            file(first, 'renamed-copy.png'),
            file(second, 'court.png'),
          ]
        ]));
    await pick(tester);
    expectPopup();
    expect(thumbnails(tester), hasLength(2));
    expect(compressor.calls, 2);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final source in ['Gallery', 'Camera']) {
    testWidgets('duplicate from $source is rejected against restored photos',
        (tester) async {
      final bytes = await photo('badminton');
      final copy = file(bytes, 'copy.png');
      await showUpload(
          tester,
          _PhotoPicker([
            [copy]
          ], camera: copy),
          initial: [bytes]);
      await pick(tester, source: source);
      expectPopup();
      expect(thumbnails(tester), hasLength(1));
      expect(compressor.calls, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'reselecting an original is rejected even when its preview was compressed differently',
      (tester) async {
    final raw = await photo('badminton');
    final compressed = await photo('tennis');
    compressor.convert = (_) => compressed;
    await showUpload(
        tester,
        _PhotoPicker([
          [file(raw, 'original.png')],
          [file(raw, 'duplicate.png')],
        ]));
    await pick(tester);
    expect(find.byType(AlertDialog), findsNothing);
    await pick(tester);
    expectPopup();
    expect(thumbnails(tester), hasLength(1));
    expect(compressor.calls, 1);
  });

  testWidgets('matching normalized image content is rejected after compression',
      (tester) async {
    final existing = await photo('badminton');
    final incoming = await photo('tennis');
    compressor.convert = (_) => existing;
    await showUpload(
        tester,
        _PhotoPicker([
          [file(incoming, 'reencoded.png')]
        ]),
        initial: [existing]);
    await pick(tester);
    expectPopup();
    expect(thumbnails(tester), hasLength(1));
    expect(compressor.calls, 1);
  });

  testWidgets(
      'a removed photo can be selected again without a duplicate warning',
      (tester) async {
    final first = await photo('badminton');
    final second = await photo('tennis');
    await showUpload(
        tester,
        _PhotoPicker([
          [file(first, 'court.png')]
        ]),
        initial: [first, second]);
    await tester.ensureVisible(find.byIcon(Icons.close).first);
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(thumbnails(tester), hasLength(1));
    await pick(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(thumbnails(tester), hasLength(2));
    expect(compressor.calls, 1);
    expect(tester.takeException(), isNull);
  });
}
