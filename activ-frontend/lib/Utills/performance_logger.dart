import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Development-only, opt-in performance diagnostics.
/// Enable with: flutter run --dart-define=ACTIV_PERF_LOGGING=true
class PerformanceLogger {
  static const enabled = bool.fromEnvironment('ACTIV_PERF_LOGGING', defaultValue: false) && kDebugMode;
  static int _nextId = 0;

  static String id() => 'flutter-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  static String path(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return value.split('?').first;
    return uri.path;
  }

  static void event(String name, Map<String, Object?> fields) {
    if (!enabled) return;
    developer.log({'event': name, ...fields}.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' '), name: 'ACTIV_PERF');
  }

  static void apiStart(String id, String method, String endpoint, int attempt) => event('api_start', {
        'id': id, 'method': method, 'endpoint': path(endpoint), 'attempt': attempt,
      });

  static void apiEnd(String id, String method, String endpoint, int attempt,
      int durationMs, String outcome, {int? status, int? bytes}) => event('api_end', {
        'id': id, 'method': method, 'endpoint': path(endpoint), 'attempt': attempt,
        'duration_ms': durationMs, 'outcome': outcome, if (status != null) 'status': status,
        if (bytes != null) 'response_bytes': bytes,
      });
}
