import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';

/// Validate legacy saved selections against the authenticated account, including
/// after account deletion/recreation when no previous token identity survives.
Future<bool> validateSavedVenueOwnership({http.Client? client}) async {
  final venueId = await SharedPreference.readStr('venue_id');
  if (venueId == null || venueId.isEmpty) return true;
  final token = await SharedPreference.readStr('jwt_token');
  if (token == null || token.isEmpty) throw StateError('Sign in required');

  var page = 1;
  while (true) {
    final response = await (client?.get ?? http.get)(
      Uri.parse(MY_VENUES_URL).replace(queryParameters: {
        'page': '$page', 'limit': '100',
      }),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Unable to verify your venue. Please try again.');
    }
    final data = jsonDecode(response.body)['data'];
    if (data is! Map || data['items'] is! List) {
      throw const FormatException('Invalid venue ownership response');
    }
    final items = data['items'] as List;
    if (items.whereType<Map>().any((venue) => venue['id']?.toString() == venueId)) {
      return true;
    }
    final pages = (data['totalPages'] as num?)?.toInt() ?? 1;
    if (page >= pages) break;
    page++;
  }

  // A request for an earlier session must never clear a newer session's draft.
  if (await SharedPreference.readStr('jwt_token') != token ||
      await SharedPreference.readStr('venue_id') != venueId) {
    throw StateError('Your session changed. Please reopen venue setup.');
  }
  for (final key in ['venue_id', 'venue_name', 'navigation_stack',
    'agreement_signature_draft', 'pending_legal_camera_document_type']) {
    await SharedPreference.remove(key);
  }
  return false;
}

/// Check if the partner has an approved venue that has not yet seen the
/// congratulations / welcome screen.
Future<Map<String, dynamic>?> checkUnseenApprovedVenue(
  String token, {
  http.Client? client,
}) async {
  try {
    final response = await (client?.get ?? http.get)(
      Uri.parse(MY_APPROVED_VENUES_URL),
      headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      final list = (body['data'] is List) ? body['data'] as List : [];
      for (final item in list) {
        if (item is Map) {
          final venueMap = Map<String, dynamic>.from(item);
          final venueId = venueMap['id']?.toString() ?? '';
          final venueRef = venueMap['publicReference']?.toString() ??
              venueMap['venueReference']?.toString() ??
              '';
          final bool hasSeenBackend = venueMap['hasSeenWelcome'] == true;
          final seenById = venueId.isNotEmpty
              ? await SharedPreference.readStr('venue_approved_seen_$venueId')
              : null;
          final seenByRef = venueRef.isNotEmpty
              ? await SharedPreference.readStr('venue_approved_seen_$venueRef')
              : null;
          final seenByHashRef = venueRef.isNotEmpty
              ? await SharedPreference.readStr('venue_approved_seen_#$venueRef')
              : null;

          if (hasSeenBackend ||
              seenById == 'true' ||
              seenByRef == 'true' ||
              seenByHashRef == 'true') {
            continue;
          }
          if (venueId.isNotEmpty) {
            return venueMap;
          }
        }
      }
    }
  } catch (e) {
    // Graceful fallback
  }
  return null;
}
