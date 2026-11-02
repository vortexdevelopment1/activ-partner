import 'package:activ_app/Screens/Home/bank_account_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue value(String text) => TextEditingValue(
    text: text, selection: TextSelection.collapsed(offset: text.length));

void main() {
  test('account number accepts manual digits, rejects paste and excess length',
      () {
    final formatter =
        BankAccountInputFormatter(allowed: bankAccountDigits, maxLength: 20);
    expect(formatter.formatEditUpdate(value('12'), value('123')).text, '123');
    expect(formatter.formatEditUpdate(value('12'), value('12a')).text, '12');
    expect(formatter.formatEditUpdate(value(''), value('1234567890')).text, '');
    expect(formatter.formatEditUpdate(value('12'), value('1')).text, '1');
    final maximum = '12345678901234567890';
    expect(
        formatter.formatEditUpdate(value(maximum), value('${maximum}1')).text,
        maximum);
    expect(formatter.formatEditUpdate(value('1234'), value('12abc34')).text,
        '1234');
  });

  test('IFSC normalizes lowercase and enforces each position and length', () {
    final formatter = BankAccountInputFormatter(
        allowed: bankIfscPrefix, maxLength: 11, uppercase: true);
    var current = value('');
    for (final character in 'hdfc0001234'.split('')) {
      current =
          formatter.formatEditUpdate(current, value(current.text + character));
    }
    expect(current.text, 'HDFC0001234');
    expect(formatter.formatEditUpdate(value('HD'), value('HD1')).text, 'HD');
    expect(
        formatter.formatEditUpdate(value('HDFC'), value('HDFC1')).text, 'HDFC');
    expect(formatter.formatEditUpdate(current, value('${current.text}5')).text,
        current.text);
    expect(
        formatter.formatEditUpdate(value(''), value('HDFC0001234')).text, '');
  });

  test('holder names accept letters and reject links, digits and empty names',
      () {
    expect(isValidBankHolder('Rahul Sharma'), isTrue);
    expect(isValidBankHolder("Anne-Marie O'Neil"), isTrue);
    expect(isValidBankHolder('\u0930\u093e\u0939\u0941\u0932'), isTrue);
    for (final name in [
      '',
      ' ',
      '1234',
      'Rahul123',
      'https://example.com',
      'A'
    ]) {
      expect(isValidBankHolder(name), isFalse);
    }
  });
}
