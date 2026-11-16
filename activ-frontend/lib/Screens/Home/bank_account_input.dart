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

const supportedBankAccountTypes = <String>[
  'Savings Account',
  'Current Account',
  'Salary Account',
  'Zero Balance Account / BSBDA',
];

const disallowedBankAccountKeywords = <String>[
  'jan dhan',
  'pmjdy',
  'nre',
  'nro',
  'fcnr',
  'fixed deposit',
  'recurring deposit',
  'cash credit',
  'overdraft',
  'od',
];

String? normalizeBankAccountType(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final lower = trimmed.toLowerCase();
  if (lower == 'saving account' || lower == 'savings') {
    return 'Savings Account';
  }
  if (lower == 'current') {
    return 'Current Account';
  }
  if (lower == 'salary') {
    return 'Salary Account';
  }
  if (lower == 'zero balance account / bsbda' ||
      lower == 'zero balance account' ||
      lower == 'bsbda' ||
      lower == 'zero balance') {
    return 'Zero Balance Account / BSBDA';
  }
  return trimmed;
}

String? validateRazorpaySettlementAccountType(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Enter account type.';
  final normalized = normalizeBankAccountType(text);
  if (supportedBankAccountTypes.contains(normalized)) {
    return null;
  }
  final lower = text.toLowerCase();
  for (final keyword in disallowedBankAccountKeywords) {
    if (lower.contains(keyword)) {
      return 'Ineligible for settlements (Jan Dhan, NRE/NRO, FD/RD, CC/OD not supported).';
    }
  }
  if (!bankAccountTypeCharacters.hasMatch(text) || text.length < 3) {
    return 'Enter a valid account type.';
  }
  return 'Select: Savings, Current, Salary, or Zero Balance / BSBDA.';
}

bool isValidBankHolder(String value) =>
    value.trim().runes.length <= 100 &&
    bankHolderCharacters.hasMatch(value) &&
    RegExp(r'\p{L}', unicode: true).allMatches(value).length >= 2;
