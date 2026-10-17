import 'dart:convert';

import 'package:activ_app/Utills/venue_postal_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _NativeGeocoder extends GeocodingPlatform {
  List<Placemark> places = [];
  @override
  Future<List<Placemark>> placemarkFromCoordinates(
          double latitude, double longitude) async =>
      places;
}

void main() {
  late _NativeGeocoder native;
  setUp(() {
    native = _NativeGeocoder();
    GeocodingPlatform.instance = native;
  });

  Future<String> resolve(http.Client client) => resolveVenuePostalCode(
        latitude: 26.45,
        longitude: 74.64,
        apiKey: 'test-key',
        client: client,
      );

  test(
      'missing place PIN is resolved at selected coordinates, skipping non-postal codes',
      () async {
    final result = await resolve(MockClient((request) async {
      expect(request.url.queryParameters['latlng'], '26.45,74.64');
      expect(request.url.queryParameters['result_type'], 'postal_code');
      return http.Response(
          jsonEncode({
            'status': 'OK',
            'results': [
              {
                'address_components': [
                  {
                    'long_name': '123456',
                    'types': ['plus_code']
                  },
                ]
              },
              {
                'address_components': [
                  {
                    'long_name': '305001',
                    'types': ['postal_code']
                  },
                ]
              },
            ],
          }),
          200);
    }));
    expect(result, '305001');
  });

  test('native geocoder supplies PIN when HTTP API is denied', () async {
    native.places = [
      const Placemark(locality: 'Ajmer'),
      const Placemark(postalCode: '305001')
    ];
    expect(await resolve(MockClient((_) async => http.Response('{}', 403))),
        '305001');
  });

  test(
      'unresolved coordinates leave PIN editable rather than inventing a city PIN',
      () async {
    native.places = [const Placemark(locality: 'Ajmer', postalCode: '000000')];
    expect(
        await resolve(MockClient((_) async => http.Response(
            jsonEncode({'status': 'ZERO_RESULTS', 'results': []}), 200))),
        isEmpty);
  });

  test('network failures still use the native postal code', () async {
    native.places = [const Placemark(postalCode: '305001')];
    expect(
        await resolve(
            MockClient((_) async => throw http.ClientException('offline'))),
        '305001');
  });
}
