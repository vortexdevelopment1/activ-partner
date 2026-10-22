import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class ActivityUploadException implements Exception {
  const ActivityUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Uploads the ordered photo selection; the first photo is the cover.
class ActivityPhotoUploader {
  ActivityPhotoUploader({required this.client, required this.baseUrl});

  final http.Client client;
  final String baseUrl;

  Future<String> upload({
    required String token,
    required String venueId,
    required Map<String, dynamic> category,
    required List<XFile> images,
  }) async {
    if (token.isEmpty) {
      throw const ActivityUploadException(
          'Your session has expired. Please sign in again.');
    }
    if (images.length < 4 || images.length > 12) {
      throw const ActivityUploadException(
          'Please select between 4 and 12 images.');
    }
    final files = <http.MultipartFile>[];
    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        throw const ActivityUploadException(
            'Each image must be non-empty and less than 5 MB.');
      }
      final name = image.name.isEmpty ? 'activity_$index.jpg' : image.name;
      final extension = name.split('.').last.toLowerCase();
      final type = image.mimeType ??
          {
            'png': 'image/png',
            'webp': 'image/webp',
            'gif': 'image/gif',
            'heic': 'image/heic',
            'heif': 'image/heif',
          }[extension] ??
          'image/jpeg';
      files.add(http.MultipartFile.fromBytes('images', bytes,
          filename: name, contentType: MediaType.parse(type)));
    }

    final headers = {'Authorization': 'Bearer $token'};
    try {
      // Older selections contain Firebase IDs; resolve them to backend IDs.
      final categories = _data(await client
          .get(Uri.parse('$baseUrl/categories/active'), headers: headers)
          .timeout(const Duration(seconds: 30)));
      final selectedId = category['id']?.toString() ?? '';
      final name = (category['name'] ?? category['title'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final available =
          categories is List ? categories.whereType<Map>().toList() : <Map>[];
      final match = available
              .where((item) => item['id']?.toString() == selectedId)
              .firstOrNull ??
          available
              .where((item) =>
                  item['name']?.toString().trim().toLowerCase() == name)
              .firstOrNull;
      if (match == null) {
        throw const ActivityUploadException(
            'This activity is unavailable. Please select it again.');
      }
      if (venueId.isEmpty) {
        final venues = _data(await client
            .get(Uri.parse('$baseUrl/venues/my-approved-venues'),
                headers: headers)
            .timeout(const Duration(seconds: 30)));
        if (venues is List && venues.length == 1 && venues.first is Map) {
          venueId = venues.first['id']?.toString() ?? '';
        }
      }
      if (venueId.isEmpty) {
        throw const ActivityUploadException(
            'Please select an approved venue before adding an activity.');
      }
      final created = _data(await client
          .post(Uri.parse('$baseUrl/venues/$venueId/activities'),
              headers: {...headers, 'Content-Type': 'application/json'},
              body: jsonEncode({'categoryId': match['id']}))
          .timeout(const Duration(seconds: 30)));
      final serviceId = created is Map ? created['id']?.toString() ?? '' : '';
      if (created is Map &&
          ['approved', 'pending']
              .contains(created['status']?.toString().toLowerCase())) {
        throw const ActivityUploadException(
            'This sport is already active or under review at your venue.');
      }
      if (serviceId.isEmpty) {
        throw const ActivityUploadException(
            'Activity setup failed. Please try again.');
      }
      final request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/venues/activities/$serviceId/images'))
        ..headers.addAll(headers)
        ..fields['replaceImages'] = 'true'
        ..files.addAll(files);
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(minutes: 2));
      final uploaded = _data(response);
      if (uploaded is! Map ||
          uploaded['imageUrls'] is! List ||
          (uploaded['imageUrls'] as List).length < images.length) {
        throw const ActivityUploadException(
            'The photos were not saved. Please try again.');
      }
      return serviceId;
    } on TimeoutException {
      throw const ActivityUploadException(
          'The upload timed out. Please check your connection and retry.');
    } on http.ClientException {
      throw const ActivityUploadException(
          'Unable to reach the server. Please check your connection and retry.');
    }
  }

  dynamic _data(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {/* Handled below. */}
    if (response.statusCode == 401) {
      throw const ActivityUploadException(
          'Your session has expired. Please sign in again.');
    }
    if (response.statusCode == 413) {
      throw const ActivityUploadException(
          'The photos are too large. Please use smaller images.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map ? body['message'] : null;
      // Validation errors explain what the partner can correct. Server errors
      // may contain provider internals, so keep those out of the screen.
      if (response.statusCode < 500 &&
          message is String &&
          message.isNotEmpty) {
        throw ActivityUploadException(message);
      }
      throw ActivityUploadException(
          'Unable to save activity photos (${response.statusCode}). Please try again.');
    }
    if (body is! Map || body['data'] == null) {
      throw const ActivityUploadException(
          'The server returned an incomplete response. Please try again.');
    }
    return body['data'];
  }
}
