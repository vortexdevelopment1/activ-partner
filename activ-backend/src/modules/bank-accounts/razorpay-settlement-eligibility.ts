import { BadRequestException } from '@nestjs/common';
import { SUPPORTED_BANK_ACCOUNT_TYPES } from './dto/submit-bank-account.dto';

export const DISALLOWED_BANK_ACCOUNT_KEYWORDS = [
  'jan dhan',
  'pmjdy',
  'nre',
  'nro',
  'fcnr',
  'fixed deposit',
  'recurring deposit',
  'cash credit',
  'overdraft',
] as const;

export function normalizeBankAccountType(type: string): string {
  const trimmed = type.trim();
  const lower = trimmed.toLowerCase();
  if (lower === 'saving account' || lower === 'savings') {
    return 'Savings Account';
  }
  if (lower === 'current') {
    return 'Current Account';
  }
  if (lower === 'salary') {
    return 'Salary Account';
  }
  if (lower === 'zero balance account / bsbda' || lower === 'bsbda' || lower === 'zero balance') {
    return 'Zero Balance Account / BSBDA';
  }
  return trimmed;
}

export function validateRazorpaySettlementEligibility(params: {
  accountNumber: string;
  accountType: string;
  ifscData?: {
    neft?: boolean;
    rtgs?: boolean;
    imps?: boolean;
    [key: string]: unknown;
  };
}): void {
  const { accountNumber, accountType, ifscData } = params;

  // 1. Account number validation
  if (/^0+$/.test(accountNumber.trim())) {
    throw new BadRequestException('Invalid account number. Account number cannot consist of only zeros.');
  }

  // 2. Disallowed account types check
  const lowerType = (accountType || '').toLowerCase();
  for (const keyword of DISALLOWED_BANK_ACCOUNT_KEYWORDS) {
    if (lowerType.includes(keyword)) {
      throw new BadRequestException(
        `Account type "${accountType}" is not eligible for Razorpay settlements. Jan Dhan, NRE, NRO, FCNR, Fixed Deposit, Recurring Deposit, Cash Credit and Overdraft accounts are not supported. Supported account types: ${SUPPORTED_BANK_ACCOUNT_TYPES.join(', ')}.`,
      );
    }
  }

  // 3. Supported account types check
  const normalized = normalizeBankAccountType(accountType);
  if (!SUPPORTED_BANK_ACCOUNT_TYPES.includes(normalized as any)) {
    throw new BadRequestException(
      `accountType must be one of the following eligible settlement account types: ${SUPPORTED_BANK_ACCOUNT_TYPES.join(', ')}`,
    );
  }

  // 4. IFSC settlement capability check
  if (ifscData && ifscData.neft === false && ifscData.rtgs === false && ifscData.imps === false) {
    throw new BadRequestException(
      'This bank branch does not support electronic settlements (NEFT/RTGS/IMPS). Please provide an IFSC for a settlement-enabled branch.',
    );
  }
}

