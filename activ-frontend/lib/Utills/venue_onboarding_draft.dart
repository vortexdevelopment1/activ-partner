import 'dart:convert';
import '../api_calling/api_request.dart';

Future<void> restoreVenueOnboardingDraft(Map<String, dynamic> venue) async {
    final venueId = venue['id']?.toString() ?? '';
    if (venueId.isNotEmpty) {
      await SharedPreference.addStringToSF('venue_id', venueId);
    }
    final venueName = venue['name']?.toString() ?? '';
    if (venueName.isNotEmpty) {
      await SharedPreference.addStringToSF('venue_name', venueName);
    }

    await SharedPreference.addStringToSF(
        'venue_details',
        jsonEncode({
          'venue_name': venueName,
          'venue_description': venue['description'] ?? '',
          'venue_search_address': venue['address'] ?? '',
          'venue_address': venue['address'] ?? '',
          'venue_area': venue['flatBuilding'] ?? '',
          'venue_city': venue['city'] ?? '',
          'venue_state': venue['state'] ?? '',
          'venue_pin_code': venue['zipCode'] ?? '',
          'venue_location_url': venue['locationUrl'] ?? '',
          'venue_latitude': venue['latitude'],
          'venue_longitude': venue['longitude'],
        }));
    await SharedPreference.addStringToSF(
        'venue_commission', venue['commission']?.toString() ?? '');

    final categories = (venue['categories'] as List? ?? [])
        .whereType<Map>()
        .map((category) => {
              'id': category['id'],
              'title': category['name'],
              'description': category['description'],
            })
        .toList();
    if (categories.isNotEmpty) {
      await SharedPreference.addStringToSF(
          'operate_value', jsonEncode(categories));
    }

    final amenities = (venue['amenities'] as List? ?? [])
        .map((amenity) => {'title': amenity.toString()})
        .toList();
    if (amenities.isNotEmpty) {
      await SharedPreference.addStringToSF(
          'place_offer', jsonEncode({'place_offer': amenities}));
    }
  }

