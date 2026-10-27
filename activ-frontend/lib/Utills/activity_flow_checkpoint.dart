import 'dart:convert';

import '../api_calling/api_request.dart';

/// Persistent, activity-scoped resume state for the add-activity wizard.
/// Image entries are references (paths or remote URLs), never image bytes.
class ActivityFlowCheckpoint {
  static bool restoring = false;
  static const _prefix = 'activity_flow_checkpoint_';

  final String activityId;
  final String step;
  final Map<String, dynamic> data;
  final bool interrupted;
  final DateTime updatedAt;

  const ActivityFlowCheckpoint({
    required this.activityId,
    required this.step,
    this.data = const {},
    this.interrupted = true,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'activityId': activityId,
        'step': step,
        'data': data,
        'interrupted': interrupted,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static ActivityFlowCheckpoint? fromJson(String raw) {
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      return ActivityFlowCheckpoint(
        activityId: value['activityId']?.toString() ?? '',
        step: value['step']?.toString() ?? '',
        data: Map<String, dynamic>.from(value['data'] as Map? ?? {}),
        interrupted: value['interrupted'] != false,
        updatedAt: DateTime.tryParse(value['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static String key(String activityId) => '$_prefix$activityId';

  static Future<void> save({
    required String activityId,
    required String step,
    Map<String, dynamic> data = const {},
  }) async {
    if (activityId.trim().isEmpty) return;
    final checkpoint = ActivityFlowCheckpoint(
      activityId: activityId,
      step: step,
      data: data,
      updatedAt: DateTime.now(),
    );
    await SharedPreference.addStringToSF(
      key(activityId),
      jsonEncode(checkpoint.toJson()),
    );
  }

  static Future<ActivityFlowCheckpoint?> read(String activityId) async {
    if (activityId.trim().isEmpty) return null;
    final raw = await SharedPreference.readStr(key(activityId));
    return raw == null ? null : fromJson(raw);
  }

  static Future<void> clear(String activityId) async {
    if (activityId.trim().isEmpty) return;
    await SharedPreference.remove(key(activityId));
  }

  static Future<void> migrate(String fromId, String toId) async {
    if (fromId.isEmpty || toId.isEmpty || fromId == toId) return;
    final source = await read(fromId);
    if (source == null) return;
    final destination = ActivityFlowCheckpoint(
      activityId: toId, step: source.step, data: source.data,
      interrupted: source.interrupted, updatedAt: source.updatedAt,
    );
    await SharedPreference.addStringToSF(key(toId), jsonEncode(destination.toJson()));
    final verified = await read(toId);
    if (verified != null && verified.step == source.step) await clear(fromId);
  }

  static Future<void> markCompletedDraft(String activityId) async {
    final current = await read(activityId);
    if (current == null) return;
    final completed = ActivityFlowCheckpoint(
      activityId: current.activityId,
      step: current.step,
      data: current.data,
      interrupted: false,
      updatedAt: DateTime.now(),
    );
    await SharedPreference.addStringToSF(key(activityId), jsonEncode(completed.toJson()));
  }
}
