import React, { useRef, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { PartnerDocumentUpload } from './PartnerDocumentUpload';
import { partnersApi, type PartnerDocumentKind } from '../../api/partners.api';
import { bankAccountsApi } from '../../api/bank-accounts.api';
import { Modal } from '../../components/ui/Modal';
import { SelectMenu } from '../../components/ui/SelectMenu';
import { useToast } from '../../hooks/useToast';

type Bank = { id?: string; accountHolderName: string; bankName: string; accountNumber: string; ifscCode: string; accountType: string; branchName: string; cancelledChequeUrl: string; upiId: string; status: string; isPrimary: boolean; rejectionReason: string };

const groups = [
  { title: 'Owner and login', fields: [['firstName', 'First name'], ['lastName', 'Last name'], ['email', 'Login email'], ['phone', 'Login phone'], ['avatarUrl', 'Profile photo URL']] },
  { title: 'Business details', fields: [['legalName', 'Legal name'], ['businessName', 'Business name'], ['ownerName', 'Business owner name'], ['businessEmail', 'Business email'], ['contactPhone', 'Business contact phone'], ['businessAddress', 'Address line 1'], ['addressLine2', 'Address line 2'], ['city', 'City'], ['state', 'State'], ['zipCode', 'Postal code']] },
  {
    title: 'Documents and verification',
    fields: [
      ['panNumber', 'PAN number'],
      ['panCardUrl', 'PAN document URL'],
      ['gstNumber', 'GST number'],
      ['gstinDocUrl', 'GST document URL'],
      ['aadhaarNumber', 'Aadhaar number'],
      ['aadhaarCardUrl', 'Aadhaar document URL'],
      ['rejectionReason', 'Verification rejection reason'],
    ],
  },
];

const bankFields = [['accountHolderName', 'Account holder'], ['bankName', 'Bank name'], ['accountNumber', 'Account number'], ['ifscCode', 'IFSC code'], ['accountType', 'Account type'], ['branchName', 'Branch'], ['cancelledChequeUrl', 'Cancelled cheque URL'], ['upiId', 'UPI ID'], ['rejectionReason', 'Rejection reason']] as const;

const accountStatusOptions = [
  { value: 'PENDING', label: 'Pending', color: 'amber' },
  { value: 'ACTIVE', label: 'Active', color: 'emerald' },
  { value: 'SUSPENDED', label: 'Suspended', color: 'red' },
];

const kycStatusOptions = [
  { value: 'PENDING', label: 'Pending', color: 'amber' },
  { value: 'APPROVED', label: 'Approved', color: 'emerald' },
  { value: 'REJECTED', label: 'Rejected', color: 'red' },
];

const bankStatusOptions = [
  { value: 'UNDER_REVIEW', label: 'Under Review', color: 'amber' },
  { value: 'APPROVED', label: 'Approved', color: 'emerald' },
  { value: 'REJECTED', label: 'Rejected', color: 'red' },
];

export const accountTypeOptions = [
  { value: 'Saving Account', label: 'Savings Account' },
  { value: 'Current Account', label: 'Current Account' },
];

export const PAN_REGEX = /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/;
export const GST_REGEX = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/;
export const BANK_HOLDER_REGEX = /^[\p{L}\p{M}\s.'-]+$/u;
export const BANK_ACCOUNT_REGEX = /^[0-9]{6,20}$/;
export const IFSC_REGEX = /^[A-Z]{4}0[A-Z0-9]{6}$/;
export const UPI_REGEX = /^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$/;
export const PHONE_REGEX = /^\+?[0-9]{10,15}$/;
export const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const formatAadhaar = (val: string): string => {
  const digits = val.replace(/\D/g, '').slice(0, 12);
  let formatted = '';
  for (let i = 0; i < digits.length; i++) {
    formatted += digits[i];
    if ((i + 1) % 4 === 0 && i + 1 !== digits.length) {
      formatted += '-';
    }
  }
  return formatted;
};

export const validateField = (key: string, val: string): string | null => {
  if (!val || !val.trim()) return null;
  const trimmed = val.trim();
  if (key === 'panNumber') {
    if (!PAN_REGEX.test(trimmed)) {
      return 'PAN must be 10 characters in ABCDE1234F format';
    }
  } else if (key === 'gstNumber') {
    if (!GST_REGEX.test(trimmed)) {
      return 'GST must be 15 characters in 27AAPFU0939F1ZV format';
    }
  } else if (key === 'aadhaarNumber') {
    const raw = trimmed.replace(/\D/g, '');
    if (raw.length !== 12) {
      return 'Aadhaar number must be exactly 12 digits';
    }
  } else if (key === 'phone' || key === 'contactPhone') {
    if (!PHONE_REGEX.test(trimmed.replace(/[\s-]/g, ''))) {
      return 'Phone number must be 10 to 15 digits (e.g. +919876543210)';
    }
  } else if (key === 'email' || key === 'businessEmail') {
    if (!EMAIL_REGEX.test(trimmed)) {
      return 'Please enter a valid email address';
    }
  }
  return null;
};

export const validateBankField = (key: string, val: string | undefined): string | null => {
  const trimmed = (val ?? '').trim();
  if (!trimmed) {
    if (['accountHolderName', 'bankName', 'accountNumber', 'ifscCode'].includes(key)) {
      const labels: Record<string, string> = {
        accountHolderName: 'Account holder',
        bankName: 'Bank name',
        accountNumber: 'Account number',
        ifscCode: 'IFSC code',
      };
      return `${labels[key]} is required`;
    }
    return null;
  }
  if (key === 'accountHolderName') {
    if (!BANK_HOLDER_REGEX.test(trimmed) || (trimmed.match(/\p{L}/gu) || []).length < 2) {
      return 'Account holder name must contain only letters and at least 2 characters';
    }
    if (trimmed.length > 100) {
      return 'Account holder name cannot exceed 100 characters';
    }
  } else if (key === 'accountNumber') {
    if (!BANK_ACCOUNT_REGEX.test(trimmed)) {
      return 'Account number must be 6 to 20 digits';
    }
  } else if (key === 'ifscCode') {
    if (!IFSC_REGEX.test(trimmed.toUpperCase())) {
      return 'IFSC code must be 11 characters (e.g. HDFC0001234)';
    }
  } else if (key === 'upiId') {
    if (!UPI_REGEX.test(trimmed)) {
      return 'Enter a valid UPI ID (e.g. name@bank)';
    }
  }
  return null;
};

export const PartnerEditor: React.FC<{ id: string; onClose: () => void }> = ({ id, onClose }) => {
  const submitting = useRef(false);
  const uploadingRef = useRef(false);
  const [uploading, setUploading] = useState(false);
  const onUploadBusyChange = (busy: boolean) => { uploadingRef.current = busy; setUploading(busy); };
  const queryClient = useQueryClient();
  const { success, error } = useToast();
  const [changes, setChanges] = useState<Record<string, string>>({});
  const [banks, setBanks] = useState<Bank[] | null>(null);
  const [attemptedSubmit, setAttemptedSubmit] = useState(false);
  const query = useQuery({ queryKey: ['partner', id], queryFn: () => partnersApi.getById(id) });
  const partner = query.data?.data?.data;

  const mutation = useMutation({
    mutationFn: () => {
      const payload: Record<string, any> = { ...changes };
      if (payload.aadhaarNumber !== undefined) {
        payload.aadhaarNumber = payload.aadhaarNumber ? payload.aadhaarNumber.replace(/\D/g, '') : '';
      }
      return partnersApi.update(id, { ...payload, ...(banks ? { bankAccounts: banks } : {}) });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['partners'] });
      queryClient.invalidateQueries({ queryKey: ['venue'] });
      queryClient.invalidateQueries({ queryKey: ['venues'] });
      queryClient.invalidateQueries({ queryKey: ['partner', id] });
      queryClient.invalidateQueries({ queryKey: ['bank-accounts'] });
      queryClient.invalidateQueries({ queryKey: ['bank-account'] });
      success('Partner details saved'); onClose();
    },
    onSettled: () => { submitting.current = false; },
    onError: (err: any) => {
      const message = err?.response?.data?.message;
      error(Array.isArray(message) ? message.join(', ') : message ?? 'Failed to save partner');
    },
  });

  const value = (key: string) => {
    if (changes[key] !== undefined) return changes[key];
    if (key === 'status') return partner?.status?.toUpperCase() ?? '';
    const rawVal = partner?.[key] ?? '';
    if (key === 'aadhaarNumber' && rawVal) {
      return formatAadhaar(String(rawVal));
    }
    return rawVal;
  };

  const handleInputChange = (key: string, rawVal: string) => {
    let nextVal = rawVal;
    if (key === 'panNumber') {
      nextVal = rawVal.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10);
    } else if (key === 'gstNumber') {
      nextVal = rawVal.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 15);
    } else if (key === 'aadhaarNumber') {
      nextVal = formatAadhaar(rawVal);
    }
    setChanges(previous => ({ ...previous, [key]: nextVal }));
  };

  const accounts: Bank[] = banks ?? partner?.bankAccounts ?? [];
  const updateBank = (index: number, field: string, value: string | boolean) => {
    setBanks(accounts.map((bank, i) => ({ ...bank, ...(i === index ? { [field]: value } : field === 'isPrimary' && value ? { isPrimary: false } : {}) })));
  };

  const lookupIfsc = async (index: number, code: string) => {
    if (!IFSC_REGEX.test(code)) return;
    try {
      const res = await bankAccountsApi.lookupIfsc(code);
      const data = res.data?.data || res.data;
      if (data && (data.bank || data.BANK)) {
        setBanks(prev => {
          const current: Bank[] = prev ?? partner?.bankAccounts ?? [];
          return current.map((b: Bank, i: number) => {
            if (i !== index) return b;
            return {
              ...b,
              bankName: String(data.bank || data.BANK || b.bankName),
              branchName: String(data.branch || data.BRANCH || b.branchName),
            };
          });
        });
      }
    } catch {
      // Ignore background lookup failure so user can enter manually
    }
  };

  const handleBankInputChange = (index: number, key: string, rawVal: string) => {
    let nextVal = rawVal;
    if (key === 'accountNumber') {
      nextVal = rawVal.replace(/\D/g, '').slice(0, 20);
    } else if (key === 'ifscCode') {
      nextVal = rawVal.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 11);
      if (nextVal.length === 11 && IFSC_REGEX.test(nextVal)) {
        lookupIfsc(index, nextVal);
      }
    } else if (key === 'accountHolderName') {
      nextVal = rawVal.replace(/[0-9]/g, '').slice(0, 100);
    } else if (key === 'upiId') {
      nextVal = rawVal.trim().slice(0, 100);
    }
    updateBank(index, key, nextVal);
  };

  const close = () => { if (!mutation.isPending && !uploadingRef.current) onClose(); };

  const documentFields: Record<string, { kind: PartnerDocumentKind; label: string }> = {
    avatarUrl: { kind: 'avatar', label: 'profile photo' },
    panCardUrl: { kind: 'pan', label: 'PAN document' },
    gstinDocUrl: { kind: 'gst', label: 'GST document' },
    aadhaarCardUrl: { kind: 'aadhaar', label: 'Aadhaar document' },
  };

  const hasGroupErrors = groups.some(group =>
    group.fields.some(([key]) => Boolean(validateField(key, value(key))))
  );

  const bankHasError = (bank: Bank) => {
    return Boolean(
      validateBankField('accountHolderName', bank.accountHolderName) ||
      validateBankField('bankName', bank.bankName) ||
      validateBankField('accountNumber', bank.accountNumber) ||
      validateBankField('ifscCode', bank.ifscCode) ||
      validateBankField('upiId', bank.upiId)
    );
  };
  const hasBankErrors = accounts.some(bankHasError);
  const hasValidationErrors = Boolean(hasGroupErrors || hasBankErrors);

  return <Modal open onClose={close} title="Partner details" size="xl" subtitle={id}>
    {query.isLoading ? <p role="status">Loading partner details...</p> : query.isError ? <div role="alert">Could not load partner details. <button className="btn-secondary" onClick={() => query.refetch()}>Retry</button></div> : partner ?
      <form className="space-y-6" onSubmit={event => {
        event.preventDefault();
        setAttemptedSubmit(true);
        if (submitting.current || uploadingRef.current) return;
        if (hasValidationErrors) {
          error('Please resolve validation errors before saving');
          return;
        }
        submitting.current = true;
        mutation.mutate();
      }}>
        <fieldset disabled={mutation.isPending || uploading} className="space-y-6">
          <p className="text-xs text-gray-500">Created: {new Date(partner.createdAt).toLocaleString()} | Updated: {new Date(partner.updatedAt).toLocaleString()} | Venues: {partner.venueCount ?? 0}</p>
          {groups.map(group => <section key={group.title} className="space-y-3">
            <h4 className="font-semibold text-gray-900">{group.title}</h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">{group.fields.map(([key, label]) => {
              const val = value(key);
              const err = validateField(key, val);
              const maxLength = key === 'panNumber' ? 10 : key === 'gstNumber' ? 15 : key === 'aadhaarNumber' ? 14 : undefined;
              return <div key={key}>
                <label className="block text-sm text-gray-600 space-y-1">
                  <span>{label}</span>
                  <input
                    className={`input w-full ${err ? '!border-red-500 focus:!border-red-500 focus:!ring-red-200' : ''}`}
                    value={val}
                    maxLength={maxLength}
                    required={key === 'phone' || key === 'legalName'}
                    type={key.toLowerCase().includes('email') ? 'email' : 'text'}
                    placeholder={
                      key === 'panNumber'
                        ? 'ABCDE1234F'
                        : key === 'gstNumber'
                        ? '27AAPFU0939F1ZV'
                        : key === 'aadhaarNumber'
                        ? '1234-5678-9012'
                        : undefined
                    }
                    onChange={event => handleInputChange(key, event.target.value)}
                  />
                </label>
                {err && <p role="alert" className="text-xs text-red-600 mt-1">{err}</p>}
                {documentFields[key] && <PartnerDocumentUpload partnerId={id} {...documentFields[key]} onBusyChange={onUploadBusyChange} onUploaded={url => setChanges(previous => ({ ...previous, [key]: url }))} />}
              </div>;
            })}</div>
          </section>)}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {([
              ['status', 'Account status', accountStatusOptions],
              ['kycStatus', 'Verification status', kycStatusOptions],
            ] as const).map(([key, label, options]) => (
              <label key={key} className="text-sm text-gray-600 space-y-1 block">
                <span>{label}</span>
                <SelectMenu
                  ariaLabel={label}
                  value={value(key)}
                  placeholder={`Select ${label.toLowerCase()}`}
                  options={options}
                  onChange={val => setChanges(previous => ({ ...previous, [key]: val }))}
                  disabled={mutation.isPending || uploading}
                />
              </label>
            ))}
          </div>
          <section className="space-y-3"><h4 className="font-semibold text-gray-900">Bank accounts</h4>
            {accounts.length === 0 && <p className="text-sm text-gray-500">No bank accounts added.</p>}
            {accounts.map((bank, index) => <div key={bank.id ?? index} className="border rounded-lg p-3 space-y-3">
              <h5 className="text-sm font-medium">Account {index + 1}</h5>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {bankFields.map(([key, label]) => {
                  if (key === 'accountType') {
                    const typeOptions = [...accountTypeOptions];
                    if (bank.accountType && !typeOptions.some(o => o.value.toLowerCase() === bank.accountType.toLowerCase())) {
                      typeOptions.push({ value: bank.accountType, label: bank.accountType });
                    }
                    const matchedValue = typeOptions.find(o => o.value.toLowerCase() === (bank.accountType || '').toLowerCase())?.value || bank.accountType || '';
                    return (
                      <label key={key} className="text-sm text-gray-600 space-y-1 block">
                        <span>{label}</span>
                        <SelectMenu
                          ariaLabel={label}
                          value={matchedValue}
                          placeholder="Select account type"
                          options={typeOptions}
                          onChange={val => updateBank(index, 'accountType', val)}
                          disabled={mutation.isPending || uploading}
                        />
                      </label>
                    );
                  }
                  const val = bank[key] ?? '';
                  const err = validateBankField(key, val);
                  const maxLength = key === 'accountNumber' ? 20 : key === 'ifscCode' ? 11 : key === 'accountHolderName' ? 100 : undefined;
                  const isInvalid = Boolean(err && (val || attemptedSubmit));
                  return (
                    <div key={key}>
                      <label className="block text-sm text-gray-600 space-y-1">
                        <span>{label}</span>
                        <input
                          className={`input w-full ${isInvalid ? '!border-red-500 focus:!border-red-500 focus:!ring-red-200' : ''}`}
                          value={val}
                          maxLength={maxLength}
                          inputMode={key === 'accountNumber' ? 'numeric' : undefined}
                          required={['accountHolderName', 'bankName', 'accountNumber', 'ifscCode'].includes(key)}
                          placeholder={
                            key === 'accountHolderName'
                              ? 'Rahul Sharma'
                              : key === 'bankName'
                              ? 'HDFC Bank'
                              : key === 'accountNumber'
                              ? '1234567890'
                              : key === 'ifscCode'
                              ? 'HDFC0001234'
                              : key === 'branchName'
                              ? 'Kormangala, Bengaluru'
                              : key === 'upiId'
                              ? 'partner@upi'
                              : undefined
                          }
                          onChange={event => handleBankInputChange(index, key, event.target.value)}
                        />
                      </label>
                      {isInvalid && <p role="alert" className="text-xs text-red-600 mt-1">{err}</p>}
                    </div>
                  );
                })}
              </div>
              <PartnerDocumentUpload partnerId={id} kind="cancelled-cheque" label={`cancelled cheque for account ${index + 1}`} onBusyChange={onUploadBusyChange} onUploaded={url => updateBank(index, 'cancelledChequeUrl', url)} />
              <label className="block text-sm text-gray-600 space-y-1">
                <span>Status</span>
                <SelectMenu
                  ariaLabel="Status"
                  value={bank.status}
                  placeholder="Select status"
                  options={bankStatusOptions}
                  onChange={val => updateBank(index, 'status', val)}
                  disabled={mutation.isPending || uploading}
                />
              </label>
              <label className="flex items-center gap-2 text-sm"><input type="checkbox" className="cursor-pointer disabled:cursor-not-allowed" checked={bank.isPrimary} onChange={event => updateBank(index, 'isPrimary', event.target.checked)} />Primary account</label>
            </div>)}
            <button type="button" className="btn-secondary" onClick={() => setBanks([...accounts, { accountHolderName: '', bankName: '', accountNumber: '', ifscCode: '', accountType: 'Saving Account', branchName: '', cancelledChequeUrl: '', upiId: '', status: 'UNDER_REVIEW', isPrimary: accounts.length === 0, rejectionReason: '' }])}>Add bank account</button>
          </section>
        </fieldset>
        <div className="flex justify-end gap-2"><button type="button" className="btn-secondary" disabled={mutation.isPending || uploading} onClick={close}>Cancel</button><button type="submit" className="btn-primary" disabled={mutation.isPending || uploading || (!Object.keys(changes).length && !banks) || hasValidationErrors}>{mutation.isPending ? 'Saving...' : 'Save changes'}</button></div>
      </form> : <p>Partner not found.</p>}
  </Modal>;
};
