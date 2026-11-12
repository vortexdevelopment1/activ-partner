import 'package:flutter/services.dart';

/// Allows manual entry while rejecting clipboard/keyboard bulk insertion.
class BankAccountInputFormatter extends TextInputFormatter {
  BankAccountInputFormatter({
    required this.allowed,
    required this.maxLength,
    this.uppercase = false,
  });

  final RegExp allowed;
  final int maxLength;
  final bool uppercase;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = uppercase ? newValue.text.toUpperCase() : newValue.text;
    final previous = oldValue.text;
    var prefix = 0;
    while (prefix < previous.length &&
        prefix < text.length &&
        previous[prefix] == text[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < previous.length - prefix &&
        suffix < text.length - prefix &&
        previous[previous.length - 1 - suffix] ==
            text[text.length - 1 - suffix]) {
      suffix++;
    }
    final inserted = text.substring(prefix, text.length - suffix);
    if (inserted.runes.length > 1 ||
        text.runes.length > maxLength ||
        !allowed.hasMatch(text)) {
      return oldValue;
    }
    return newValue.copyWith(text: text);
  }
}

final bankAccountDigits = RegExp(r'^[0-9]*$');
final bankIfscPrefix = RegExp(r'^(?:[A-Z]{0,4}|[A-Z]{4}0[A-Z0-9]{0,6})$');
final bankHolderCharacters = RegExp(r"^[\p{L}\p{M} .'-]*$", unicode: true);
final bankAccountTypeCharacters = RegExp(r"^[\p{L} -]*$", unicode: true);

bool isValidBankHolder(String value) =>
    value.trim().runes.length <= 100 &&
    bankHolderCharacters.hasMatch(value) &&
    RegExp(r'\p{L}', unicode: true).allMatches(value).length >= 2;
