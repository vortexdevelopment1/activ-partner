import 'dart:convert';
import '../api_calling/api_request.dart';

/// Local editor drafts, distinct from published/server availability. SharedPreference
/// uses browser session storage on web and device preferences on mobile.
class SlotTimingDraft {
  static Future<void> save(String key, Map<String, dynamic> data) async {
    final snapshot = jsonEncode(data);
    await SharedPreference.addStringToSF(key, snapshot);
  }

  static Future<Map<String, dynamic>?> read(String key) async {
    try {
      final raw = await SharedPreference.readStr(key);
      return raw == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String key) async {
    await SharedPreference.remove(key);
  }
}
