import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'browser_session.dart';

/// Photo drafts use the same tab lifetime as the rest of onboarding.
class SessionPhotoDraft {
  static final changes = ValueNotifier<int>(0);
  static String _key(Map<String, dynamic> category) =>
      'photos_${category['id'] ?? 'venue'}';

  static ({List<Uint8List> bytes, int cover})? read(
      Map<String, dynamic> category) {
    if (!isBrowserSession) return null;
    try {
      final raw = readBrowserSession(_key(category));
      if (raw == null) return null;
      final data = jsonDecode(raw);
      return (
        bytes: (data['images'] as List)
            .map((e) => base64Decode(e as String))
            .toList(),
        cover: data['cover'] as int? ?? 0
      );
    } catch (_) {
      return null;
    }
  }

  static void save(
      Map<String, dynamic> category, List<Uint8List> bytes, int cover) {
    if (!isBrowserSession) return;
    writeBrowserSession(
        _key(category),
        jsonEncode({
          'images': bytes.map(base64Encode).toList(),
          'cover': cover,
        }));
    changes.value++;
  }
}
