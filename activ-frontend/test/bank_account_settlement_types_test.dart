import 'package:flutter_test/flutter_test.dart';
import 'package:activ_app/Screens/Home/bank_account_input.dart';

void main() {
  group('Razorpay Settlement Eligible Bank Account Types', () {
    test('supports only the 4 specified settlement-eligible account types', () {
      expect(supportedBankAccountTypes, [
        'Savings Account',
        'Current Account',
        'Salary Account',
        'Zero Balance Account / BSBDA',
      ]);
    });

    test('validates and accepts each of the 4 supported account types', () {
      for (final type in supportedBankAccountTypes) {
        expect(validateRazorpaySettlementAccountType(type), isNull);
        expect(normalizeBankAccountType(type), type);
      }
    });

    test('normalizes legacy Saving Account to Savings Account', () {
      expect(normalizeBankAccountType('Saving Account'), 'Savings Account');
      expect(normalizeBankAccountType('savings'), 'Savings Account');
      expect(validateRazorpaySettlementAccountType('Saving Account'), isNull);
    });

    test('rejects disallowed account types with descriptive error', () {
      final disallowedList = [
        'Jan Dhan Account',
        'PMJDY',
        'NRE Account',
        'NRO Account',
        'FCNR Account',
        'Fixed Deposit',
        'Recurring Deposit',
        'Cash Credit',
        'Overdraft Account',
        'OD Account',
      ];

      for (final type in disallowedList) {
        final error = validateRazorpaySettlementAccountType(type);
        expect(error, isNotNull);
        expect(error, contains('Ineligible for settlements'));
      }
    });

    test('rejects unrecognized account types', () {
      expect(
        validateRazorpaySettlementAccountType('Loan Account'),
        'Select: Savings, Current, Salary, or Zero Balance / BSBDA.',
      );
      expect(
        validateRazorpaySettlementAccountType(''),
        'Enter account type.',
      );
    });
  });
}

