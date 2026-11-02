import 'dart:convert';

import 'package:activ_app/api_calling/api_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String token(String account, {String type = 'partner'}) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': account, 'type': type})))}.signature';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'jwt_token': token('first-partner'),
        'venue_id': 'first-partner-venue',
        'activity_questions_display': 'old answers',
        'navigation_stack': 'old agreement page',
      }));

  test('account switch removes the previous venue and onboarding state', () async {
    await SharedPreference.addStringToSF('jwt_token', token('second-partner'));
    expect(await SharedPreference.readStr('jwt_token'), token('second-partner'));
    for (final key in ['venue_id', 'activity_questions_display', 'navigation_stack']) {
      expect(await SharedPreference.readStr(key), isNull);
    }
  });

  test('login remembers account identity when removing the previous token', () async {
    await SharedPreference.remove('jwt_token');
    await SharedPreference.addStringToSF('jwt_token', token('second-partner'));
    expect(await SharedPreference.readStr('venue_id'), isNull);
  });

  test('logging back into the same account preserves its venue draft', () async {
    await SharedPreference.remove('jwt_token');
    await SharedPreference.addStringToSF('jwt_token', token('first-partner'));
    expect(await SharedPreference.readStr('venue_id'), 'first-partner-venue');
    expect(await SharedPreference.readStr('activity_questions_display'), 'old answers');
  });

  test('first sign-in preserves the draft entered before authentication', () async {
    SharedPreferences.setMockInitialValues({'owner_mobile_number': '1234567890'});
    await SharedPreference.addStringToSF('jwt_token', token('first-partner'));
    expect(await SharedPreference.readStr('owner_mobile_number'), '1234567890');
  });
}
