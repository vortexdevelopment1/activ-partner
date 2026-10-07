import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_constant.dart';

class PasswordResetException implements Exception {
  const PasswordResetException(this.message, {this.invalidCode = false});
  final String message;
  final bool invalidCode;
}

class PasswordResetService {
  PasswordResetService([this.client]);
  final http.Client? client;

  Future<void> sendCode(String email) =>
      _post('forgot-password', {'email': email});

  Future<void> verifyCode(String email, String code) =>
      _post('verify-reset-code', {'email': email, 'code': code});

  Future<void> resetPassword(String email, String code, String password) =>
      _post('reset-password',
          {'email': email, 'code': code, 'newPassword': password});

  Future<void> _post(String path, Map<String, String> body) async {
    try {
      final response = await (client?.post ?? http.post)(
        Uri.parse('$BASE_URL/auth/partner/$path'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json'
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      final payload = jsonDecode(response.body);
      final message = payload is Map ? payload['message'] : null;
      final text = message is List
          ? message.join('\n')
          : message?.toString() ??
              'Unable to complete this request. Please try again.';
      throw PasswordResetException(text,
          invalidCode:
              text.toLowerCase().contains('invalid or expired reset code'));
    } on PasswordResetException {
      rethrow;
    } catch (_) {
      throw const PasswordResetException(
          'Unable to connect. Please check your connection and try again.');
    }
  }
}
