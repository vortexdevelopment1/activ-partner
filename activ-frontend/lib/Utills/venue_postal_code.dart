import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

bool isValidVenuePostalCode(String value) =>
    RegExp(r'^[1-9]\d{5}$').hasMatch(value.trim());

/// Resolve the postal delivery area at the venue coordinates, not a city default.
Future<String> resolveVenuePostalCode({
  required double latitude,
  required double longitude,
  required String apiKey,
  http.Client? client,
}) async {
  if (apiKey.trim().isNotEmpty) {
    try {
      final response = await (client?.get ?? http.get)(
        Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
          'latlng': '$latitude,$longitude',
          'result_type': 'postal_code',
          'key': apiKey,
        }),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          for (final result in data['results'] as List? ?? []) {
            for (final component
                in result['address_components'] as List? ?? []) {
              final types = component['types'] as List? ?? [];
              final value = component['long_name']?.toString().trim() ?? '';
              if (types.contains('postal_code') &&
                  isValidVenuePostalCode(value)) {
                return value;
              }
            }
          }
        }
      }
    } catch (_) {
      // Native geocoding can still work when the HTTP API is unavailable.
    }
  }
  try {
    final places = await placemarkFromCoordinates(latitude, longitude)
        .timeout(const Duration(seconds: 5));
    for (final place in places) {
      final value = place.postalCode?.trim() ?? '';
      if (isValidVenuePostalCode(value)) return value;
    }
  } catch (_) {}
  return '';
}
