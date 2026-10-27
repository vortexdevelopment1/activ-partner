import 'dart:math';

import '../api_calling/api_request.dart';

/// Stable identity used before the backend creates an activity record.
class ActivityDraftIdentity {
  static String _key(String venueId, String categoryId) =>
      'activity_provisional_id_${venueId}_$categoryId';

  static Future<String> forActivity({
    required String venueId,
    required String categoryId,
    String? backendActivityId,
  }) async {
    if (backendActivityId != null && backendActivityId.trim().isNotEmpty) {
      await link(venueId: venueId, categoryId: categoryId, activityId: backendActivityId);
      return backendActivityId;
    }
    final key = _key(venueId, categoryId);
    final existing = await SharedPreference.readStr(key);
    if (existing != null && existing.trim().isNotEmpty) return existing;
    final created = 'local-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
    await SharedPreference.addStringToSF(key, created);
    return created;
  }

  static Future<String> createNew({required String venueId, required String categoryId}) async {
    final id = 'local-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
    await SharedPreference.addStringToSF('activity_provisional_id_${venueId}_$categoryId:$id', id);
    return id;
  }

  static Future<void> link({
    required String venueId,
    required String categoryId,
    required String activityId,
  }) => SharedPreference.addStringToSF(_key(venueId, categoryId), activityId);
}
