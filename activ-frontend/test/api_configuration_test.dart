import 'dart:convert';

import 'package:activ_app/api_calling/api_constant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.clean();
    BASE_URL = '';
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    dotenv.clean();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('normal startup loads backend configuration from the env asset',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      expect(
          utf8.decode(message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          )),
          '.env');
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(
        'LOCAL_API_URL=\nAPI_URL=https://backend.example.test/api/v1/\n',
      )));
    });

    await initializeApiBaseUrl();

    expect(BASE_URL, 'https://backend.example.test/api/v1');
    expect(REQUEST_OTP_URL,
        'https://backend.example.test/api/v1/auth/partner/request-otp');
  });

  test('reinitialization keeps already loaded configuration', () async {
    dotenv.loadFromString(
        envString: 'API_URL=https://backend.example.test/api/v1');

    await initializeApiBaseUrl();
    await initializeApiBaseUrl();

    expect(BASE_URL, 'https://backend.example.test/api/v1');
  });

  test('empty backend configuration reports the required env values', () async {
    dotenv.loadFromString(envString: 'API_URL=\nLOCAL_API_URL=');

    await expectLater(initializeApiBaseUrl(), throwsStateError);
  });

  test('debug startup uses the local API when both hosts are configured',
      () async {
    dotenv.loadFromString(
        envString:
            'LOCAL_API_URL=http://localhost:3000/api/v1\nAPI_URL=https://backend.example.test/api/v1');
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await initializeApiBaseUrl();
    expect(BASE_URL, 'http://localhost:3000/api/v1');
  });

  test('Android debug startup uses the emulator host for the local API',
      () async {
    dotenv.loadFromString(
        envString:
            'LOCAL_API_URL=http://localhost:3000/api/v1\nAPI_URL=https://backend.example.test/api/v1');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await initializeApiBaseUrl();
    expect(BASE_URL, 'http://10.0.2.2:3000/api/v1');
  });
}
