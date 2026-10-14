import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MobileNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) digits = digits.substring(0, 10);
    String newText = '';

    for (int i = 0; i < digits.length; i++) {
      newText += digits[i];
      if (i == 1 && digits.length > 2) {
        newText += '-';
      } else if (i == 5 && digits.length > 6) {
        newText += '-';
      }
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}