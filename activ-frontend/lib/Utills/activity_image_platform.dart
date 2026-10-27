import 'dart:typed_data';

import 'activity_image_platform_stub.dart'
    if (dart.library.html) 'activity_image_platform_web.dart' as platform;

Future<void> persistImageBytes({
  required String draftId,
  required String imageId,
  required Uint8List bytes,
  required String name,
  required String mimeType,
}) => platform.persistImageBytes(
      draftId: draftId,
      imageId: imageId,
      bytes: bytes,
      name: name,
      mimeType: mimeType,
    );

Future<Uint8List?> readImageBytes({required String draftId, required String imageId}) =>
    platform.readImageBytes(draftId: draftId, imageId: imageId);
