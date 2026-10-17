import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

bool matchesVenuePhoto(Uint8List candidate, Iterable<Uint8List> photos) =>
    photos.any((photo) => listEquals(candidate, photo));

Future<bool> containsVenuePhoto(
  Uint8List candidate, {
  required Iterable<XFile> selectedPhotos,
  Iterable<Uint8List> processedPhotos = const [],
}) async {
  if (matchesVenuePhoto(candidate, processedPhotos)) return true;
  for (final photo in selectedPhotos) {
    try {
      if (await photo.length() == candidate.length &&
          listEquals(candidate, await photo.readAsBytes())) {
        return true;
      }
    } catch (_) {
      // Existing previews remain comparable if a source file is unavailable.
    }
  }
  return false;
}

Future<void> showDuplicateVenuePhotoDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Photo already added'),
        content: const Text(
          'You can’t upload the same photo twice. Please choose a different photo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
