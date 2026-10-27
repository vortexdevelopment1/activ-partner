import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../api_calling/api_request.dart';
import 'activity_image_platform.dart';

/// Stores image references and ordering only. Binary image data is never put
/// into SharedPreferences. Mobile callers should pass app-owned file paths;
/// web callers should pass durable remote/blob references.
class ActivityImageDraftStore {
  static String _key(String activityId) => 'activity_images_$activityId';

  static Future<void> save(String activityId, List<XFile> images) async {
    final durable = <XFile>[];
    if (!kIsWeb) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        for (var i = 0; i < images.length; i++) {
          final source = images[i];
          final filename = 'activity_${activityId.hashCode}_${i}_${DateTime.now().microsecondsSinceEpoch}${p.extension(source.name).isEmpty ? '.jpg' : p.extension(source.name)}';
          final destination = p.join(directory.path, 'activity_drafts', filename);
          await source.saveTo(destination);
          durable.add(XFile(destination, name: filename));
        }
      } catch (_) {
        durable.addAll(images);
      }
    } else {
      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        try {
          final bytes = await image.readAsBytes();
          final imageId = '${i}_${image.name}';
          await persistImageBytes(
            draftId: activityId,
            imageId: imageId,
            bytes: bytes,
            name: image.name,
            mimeType: image.mimeType ?? 'image/jpeg',
          );
          durable.add(XFile.fromData(bytes, name: image.name, mimeType: image.mimeType));
        } catch (_) {
          durable.add(image);
        }
      }
    }
    await SharedPreference.addStringToSF(
      _key(activityId),
      jsonEncode(durable.map((image) => {'path': image.path, 'name': image.name}).toList()),
    );
  }

  static Future<List<XFile>> read(String activityId) async {
    final raw = await SharedPreference.readStr(_key(activityId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final values = jsonDecode(raw) as List;
      final images = values.asMap().entries.map((entry) {
        final value = entry.value;
        final item = Map<String, dynamic>.from(value as Map);
        return XFile(item['path'].toString(), name: item['name']?.toString());
      }).toList();
      final valid = <XFile>[];
      for (var i = 0; i < images.length; i++) {
        var image = images[i];
        if (kIsWeb) {
          final bytes = await readImageBytes(
            draftId: activityId,
            imageId: '${i}_${image.name}',
          );
          if (bytes != null) image = XFile.fromData(bytes, name: image.name);
        }
        try {
          if (await image.length() > 0) valid.add(image);
        } catch (_) {
          // Missing local references are safely omitted.
        }
      }
      return valid;
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear(String activityId) => SharedPreference.remove(_key(activityId));

  static Future<void> migrate(String fromId, String toId) async {
    if (fromId == toId || fromId.isEmpty || toId.isEmpty) return;
    final raw = await SharedPreference.readStr(_key(fromId));
    if (raw == null || raw.isEmpty) return;
    await SharedPreference.addStringToSF(_key(toId), raw);
    await SharedPreference.remove(_key(fromId));
  }
}
