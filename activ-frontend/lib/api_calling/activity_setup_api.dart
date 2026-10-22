import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_constant.dart';
import 'api_request.dart';

class ActivitySetupException implements Exception {
  const ActivitySetupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ActivitySetupApi {
  ActivitySetupApi({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;
  final http.Client _client;
  final bool _ownsClient;
  void dispose() {
    if (_ownsClient) _client.close();
  }

  Future<dynamic> _request(String method, String path, [Object? body]) async {
    final token = await SharedPreference.readStr('jwt_token');
    if (token == null || token.isEmpty) {
      throw const ActivitySetupException(
          'Your session has expired. Please sign in again.');
    }
    try {
      final request = http.Request(method, Uri.parse('$BASE_URL$path'))
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 30));
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {/* Checked below. */}
      if (response.statusCode == 401) {
        throw const ActivitySetupException(
            'Your session has expired. Please sign in again.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map ? decoded['message'] : null;
        throw ActivitySetupException(
            response.statusCode < 500 && message is String
                ? message
                : 'Unable to save activity. Please try again.');
      }
      if (decoded is! Map) {
        throw const ActivitySetupException(
            'The server returned an invalid response. Please retry.');
      }
      return decoded['data'];
    } on TimeoutException {
      throw const ActivitySetupException(
          'The request timed out. Please check your connection and retry.');
    } on http.ClientException {
      throw const ActivitySetupException(
          'Unable to reach the server. Please check your connection and retry.');
    }
  }

  List<Map<String, dynamic>> _list(dynamic data) {
    if (data is! List) {
      throw const ActivitySetupException(
          'Unable to load activity setup. Please retry.');
    }
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> categories() async =>
      _list(await _request('GET', '/categories/active'));
  Future<List<Map<String, dynamic>>> approvedVenues() async =>
      _list(await _request('GET', '/venues/my-approved-venues'));
  Future<List<Map<String, dynamic>>> questions(String id) async =>
      _list(await _request('GET', '/venues/activities/$id/questions'));
  Future<List<Map<String, dynamic>>> amenities() async =>
      _list(await _request('GET', '/amenities/active'));
  Future<Map<String, dynamic>> activity(String id) async {
    final data = await _request('GET', '/venues/activities/$id');
    if (data is! Map) {
      throw const ActivitySetupException(
          'Activity could not be loaded. Please retry.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> saveAnswers(String id, Map<String, dynamic> answers) async {
    await _request('POST', '/venues/activities/$id/answers', {
      'answers': [
        for (final entry in answers.entries)
          {'questionId': entry.key, 'answer': entry.value},
      ]
    });
  }

  Future<void> saveAmenities(String id, List<String> amenities) async {
    if (amenities.isEmpty) {
      throw const ActivitySetupException('Please select at least one amenity.');
    }
    await _request(
        'PATCH', '/venues/activities/$id/amenities', {'amenities': amenities});
  }

  Future<String> uploadAnswerFile(
      String id, String questionId, List<int> bytes, String filename) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const ActivitySetupException('Please select a file under 5 MB.');
    }
    final extension = filename.split('.').last.toLowerCase();
    final mime = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png'
    }[extension];
    if (mime == null) {
      throw const ActivitySetupException(
          'Please select a PDF, JPG or PNG file.');
    }
    final token = await SharedPreference.readStr('jwt_token');
    if (token == null || token.isEmpty) {
      throw const ActivitySetupException('Please sign in again.');
    }
    final request = http.MultipartRequest('POST',
        Uri.parse('$BASE_URL/venues/activities/$id/questions/$questionId/file'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: filename, contentType: MediaType.parse(mime)));
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(minutes: 2));
      final decoded = jsonDecode(response.body);
      final url = decoded is Map && decoded['data'] is Map
          ? decoded['data']['url']
          : null;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          url is! String ||
          url.isEmpty) {
        throw const ActivitySetupException(
            'Document upload failed. Please retry.');
      }
      return url;
    } on TimeoutException {
      throw const ActivitySetupException(
          'Document upload timed out. Please retry.');
    } on http.ClientException {
      throw const ActivitySetupException(
          'Document upload failed. Please check your connection.');
    } on FormatException {
      throw const ActivitySetupException(
          'Document upload failed. Please retry.');
    }
  }

  /// Save only this activity's schedule, then enter the admin review queue.
  /// A retry after a lost submission response accepts an already queued draft.
  Future<void> submit(
      String id, Map<String, List<Map<String, String>>> timing) async {
    final record = await activity(id);
    if (record['status']?.toString().toLowerCase() == 'pending') return;
    if (!['draft', 'rejected']
        .contains(record['status']?.toString().toLowerCase())) {
      throw const ActivitySetupException(
          'Only draft or rejected activities can be submitted.');
    }
    if (!timing.values.expand((slots) => slots).any((slot) =>
        (slot['open'] ?? '').isNotEmpty &&
        slot['open'] != '-' &&
        (slot['close'] ?? '').isNotEmpty &&
        slot['close'] != '-')) {
      throw const ActivitySetupException(
          'Please add at least one operating time range.');
    }
    final venueId = record['venueId']?.toString() ?? '';
    final categoryId = record['categoryId']?.toString() ?? '';
    if (venueId.isEmpty || categoryId.isEmpty) {
      throw const ActivitySetupException(
          'This activity is missing its venue or sport. Please retry.');
    }
    await _request('PATCH', '/venues/$venueId/availability', {
      'venue_timing': {categoryId: timing},
    });
    final submitted = await _request('POST', '/venues/activities/$id/submit');
    if (submitted is! Map ||
        submitted['status']?.toString().toLowerCase() != 'pending') {
      throw const ActivitySetupException(
          'Activity review was not confirmed. Please retry.');
    }
  }
}
