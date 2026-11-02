import 'dart:convert';
import 'package:activ_app/Utills/venue_session_ownership.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
    'jwt_token': 'new-account', 'venue_id': 'old-venue',
    'navigation_stack': 'old-page', 'venue_details': 'unsaved new venue',
  }));

  test('removes unauthorized venue while preserving session and entered venue data', () async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/my-venues'));
      expect(request.headers['Authorization'], 'Bearer new-account');
      return http.Response('{"data":{"items":[],"totalPages":0}}', 200);
    });
    expect(await validateSavedVenueOwnership(client: client), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('venue_id'), isNull);
    expect(prefs.getString('navigation_stack'), isNull);
    expect(prefs.getString('jwt_token'), 'new-account');
    expect(prefs.getString('venue_details'), 'unsaved new venue');
  });

  test('checks all pages before rejecting an owned venue', () async {
    final client = MockClient((request) async => http.Response(jsonEncode({'data': {
      'items': request.url.queryParameters['page'] == '2' ? [{'id': 'old-venue'}] : [],
      'totalPages': 2,
    }}), 200));
    expect(await validateSavedVenueOwnership(client: client), isTrue);
    expect((await SharedPreferences.getInstance()).getString('venue_id'), 'old-venue');
  });

  test('network/server failure preserves the selection for retry', () async {
    final client = MockClient((_) async => http.Response('{}', 503));
    await expectLater(validateSavedVenueOwnership(client: client), throwsStateError);
    expect((await SharedPreferences.getInstance()).getString('venue_id'), 'old-venue');
  });

  test('a delayed response cannot erase a newer account session', () async {
    final client = MockClient((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', 'another-account');
      await prefs.setString('venue_id', 'another-venue');
      return http.Response('{"data":{"items":[],"totalPages":0}}', 200);
    });
    await expectLater(validateSavedVenueOwnership(client: client), throwsStateError);
    expect((await SharedPreferences.getInstance()).getString('venue_id'), 'another-venue');
  });
}
