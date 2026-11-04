// @vitest-environment jsdom
import React from 'react';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { PartnerEditor } from '../src/pages/partners/PartnerEditor';
import { partnersApi } from '../src/api/partners.api';

const toast = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn() }));
vi.mock('../src/hooks/useToast', () => ({ useToast: () => toast }));
vi.mock('../src/api/partners.api', () => ({ partnersApi: { getById: vi.fn(), update: vi.fn(), uploadDocument: vi.fn() } }));
let client: QueryClient;
const close = vi.fn();
beforeEach(() => {
  vi.clearAllMocks();
  client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } });
  vi.mocked(partnersApi.getById).mockResolvedValue({ data: { data: {
    id: 'partner', legalName: 'Business', firstName: 'Old', phone: '+919876543210', status: 'active', kycStatus: 'PENDING',
    panNumber: 'ABCDE1234F', aadhaarNumber: '123456789012', createdAt: '2026-01-01', updatedAt: '2026-01-01', bankAccounts: [{ id: 'bank', accountHolderName: 'Owner', bankName: 'Bank', accountNumber: '123456', ifscCode: 'ABCD0123456', status: 'UNDER_REVIEW', isPrimary: false }],
  } } } as any);
  vi.mocked(partnersApi.update).mockResolvedValue({ data: {} } as any);
});
afterEach(() => { cleanup(); client.clear(); });
const show = () => render(<QueryClientProvider client={client}><PartnerEditor id="partner" onClose={close} /></QueryClientProvider>);

it('loads full details and sends only edited profile fields', async () => {
  show();
  const pan = await screen.findByLabelText('PAN number');
  expect((pan as HTMLInputElement).value).toBe('ABCDE1234F');
  fireEvent.change(pan, { target: { value: 'BCDEF2345G' } });
  fireEvent.click(screen.getByRole('button', { name: 'Account status' }));
  fireEvent.click(screen.getByRole('option', { name: /suspended/i }));
  fireEvent.click(screen.getByRole('button', { name: 'Save changes' }));
  await waitFor(() => expect(partnersApi.update).toHaveBeenCalledWith('partner', { panNumber: 'BCDEF2345G', status: 'SUSPENDED' }));
  await waitFor(() => expect(close).toHaveBeenCalledTimes(1));
});

it('keeps the form open with edits after a failed save', async () => {
  vi.mocked(partnersApi.update).mockRejectedValueOnce({ response: { data: { message: ['Email is already registered'] } } });
  show();
  fireEvent.change(await screen.findByLabelText('Login email'), { target: { value: 'used@example.com' } });
  fireEvent.click(screen.getByRole('button', { name: 'Save changes' }));
  await waitFor(() => expect(toast.error).toHaveBeenCalledWith('Email is already registered'));
  expect(close).not.toHaveBeenCalled();
  expect((screen.getByLabelText('Login email') as HTMLInputElement).value).toBe('used@example.com');
});

it('saves bank edits with their existing account ID', async () => {
  show();
  fireEvent.change(await screen.findByLabelText('Account number'), { target: { value: '987654' } });
  fireEvent.click(screen.getByRole('button', { name: 'Save changes' }));
  await waitFor(() => expect(partnersApi.update).toHaveBeenCalledWith('partner', { bankAccounts: [expect.objectContaining({ id: 'bank', accountNumber: '987654' })] }));
});

it('prevents duplicate submissions while saving', async () => {
  vi.mocked(partnersApi.update).mockImplementation(() => new Promise(() => {}));
  show();
  fireEvent.change(await screen.findByLabelText('First name'), { target: { value: 'New' } });
  const form = screen.getByRole('button', { name: 'Save changes' }).closest('form')!;
  fireEvent.submit(form); fireEvent.submit(form);
  await waitFor(() => expect(partnersApi.update).toHaveBeenCalledTimes(1));
});

for (const [label, kind, field] of [['PAN document', 'pan', 'panCardUrl'], ['GST document', 'gst', 'gstinDocUrl'], ['Aadhaar document', 'aadhaar', 'aadhaarCardUrl'], ['profile photo', 'avatar', 'avatarUrl']]) {
  it('uploads and saves ' + label, async () => {
    vi.mocked(partnersApi.uploadDocument).mockResolvedValueOnce({ data: { data: { url: 'https://example.com/uploaded.png' } } } as any);
    show();
    const file = new File(['image'], 'document.png', { type: 'image/png' });
    fireEvent.change(await screen.findByLabelText('Upload ' + label), { target: { files: [file] } });
    await waitFor(() => expect(partnersApi.uploadDocument).toHaveBeenCalledWith('partner', kind, file));
    await screen.findByText('document.png uploaded. Save changes to apply it.');
    expect(partnersApi.update).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole('button', { name: 'Save changes' }));
    await waitFor(() => expect(partnersApi.update).toHaveBeenCalledWith('partner', { [field]: 'https://example.com/uploaded.png' }));
  });
}

it('uploads a cancelled cheque into the correct bank account', async () => {
  vi.mocked(partnersApi.uploadDocument).mockResolvedValueOnce({ data: { data: { url: 'https://example.com/cheque.pdf' } } } as any);
  show();
  const file = new File(['%PDF-1.7'], 'cheque.pdf', { type: 'application/pdf' });
  fireEvent.change(await screen.findByLabelText('Upload cancelled cheque for account 1'), { target: { files: [file] } });
  await screen.findByText('cheque.pdf uploaded. Save changes to apply it.');
  fireEvent.click(screen.getByRole('button', { name: 'Save changes' }));
  await waitFor(() => expect(partnersApi.update).toHaveBeenCalledWith('partner', { bankAccounts: [expect.objectContaining({ id: 'bank', cancelledChequeUrl: 'https://example.com/cheque.pdf' })] }));
});

it('preserves the current document on upload failure and allows retry', async () => {
  vi.mocked(partnersApi.uploadDocument).mockRejectedValueOnce({ response: { data: { message: 'Upload unavailable' } } });
  show();
  fireEvent.change(await screen.findByLabelText('PAN document URL'), { target: { value: 'https://example.com/original.pdf' } });
  const file = new File(['%PDF-1.7'], 'pan.pdf', { type: 'application/pdf' });
  fireEvent.change(screen.getByLabelText('Upload PAN document'), { target: { files: [file] } });
  await screen.findByText('Upload unavailable');
  expect((screen.getByLabelText('PAN document URL') as HTMLInputElement).value).toBe('https://example.com/original.pdf');
  vi.mocked(partnersApi.uploadDocument).mockResolvedValueOnce({ data: { data: { url: 'https://example.com/new.pdf' } } } as any);
  fireEvent.change(screen.getByLabelText('Upload PAN document'), { target: { files: [file] } });
  await screen.findByText('pan.pdf uploaded. Save changes to apply it.');
  expect((screen.getByLabelText('PAN document URL') as HTMLInputElement).value).toBe('https://example.com/new.pdf');
});

it('blocks saving and closing while an upload is in progress', async () => {
  let finish!: (value: any) => void;
  vi.mocked(partnersApi.uploadDocument).mockImplementationOnce(() => new Promise(resolve => { finish = resolve; }));
  show();
  fireEvent.change(await screen.findByLabelText('Upload GST document'), { target: { files: [new File(['pdf'], 'gst.pdf', { type: 'application/pdf' })] } });
  expect((screen.getByRole('button', { name: 'Save changes' }) as HTMLButtonElement).disabled).toBe(true);
  fireEvent.click(screen.getByRole('button', { name: 'Close dialog' }));
  fireEvent.submit(screen.getByRole('button', { name: 'Save changes' }).closest('form')!);
  expect(close).not.toHaveBeenCalled(); expect(partnersApi.update).not.toHaveBeenCalled();
  finish({ data: { data: { url: 'https://example.com/gst.pdf' } } });
  await screen.findByText('gst.pdf uploaded. Save changes to apply it.');
});

it('rejects unsupported files before uploading', async () => {
  show();
  fireEvent.change(await screen.findByLabelText('Upload PAN document'), { target: { files: [new File(['html'], 'document.html', { type: 'text/html' })] } });
  await screen.findByText('Choose a JPG, PNG, WebP image or PDF.');
  expect(partnersApi.uploadDocument).not.toHaveBeenCalled();
});

it('validates PAN number and blocks saving on invalid format', async () => {
  show();
  const panInput = (await screen.findByLabelText('PAN number')) as HTMLInputElement;
  fireEvent.change(panInput, { target: { value: 'invalid!pan' } });
  expect(panInput.value).toBe('INVALIDPAN'); // Non-alphanumeric filtered, uppercase
  expect(await screen.findByText('PAN must be 10 characters in ABCDE1234F format')).toBeDefined();
  expect((screen.getByRole('button', { name: 'Save changes' }) as HTMLButtonElement).disabled).toBe(true);

  fireEvent.change(panInput, { target: { value: 'ABCDE1234F' } });
  expect(screen.queryByText('PAN must be 10 characters in ABCDE1234F format')).toBeNull();
  expect((screen.getByRole('button', { name: 'Save changes' }) as HTMLButtonElement).disabled).toBe(false);
});

it('validates GST number and blocks saving on invalid format', async () => {
  show();
  const gstInput = (await screen.findByLabelText('GST number')) as HTMLInputElement;
  fireEvent.change(gstInput, { target: { value: '383hdhsueudud@@@@@' } });
  expect(gstInput.value).toBe('383HDHSUEUDUD');
  expect(await screen.findByText('GST must be 15 characters in 27AAPFU0939F1ZV format')).toBeDefined();
  expect((screen.getByRole('button', { name: 'Save changes' }) as HTMLButtonElement).disabled).toBe(true);

  fireEvent.change(gstInput, { target: { value: '27AAPFU0939F1ZV' } });
  expect(screen.queryByText('GST must be 15 characters in 27AAPFU0939F1ZV format')).toBeNull();
  expect((screen.getByRole('button', { name: 'Save changes' }) as HTMLButtonElement).disabled).toBe(false);
});

it('displays and formats Aadhaar number, validates 12 digits, and sends unhyphenated digits', async () => {
  show();
  const aadhaarInput = (await screen.findByLabelText('Aadhaar number')) as HTMLInputElement;
  expect(aadhaarInput.value).toBe('1234-5678-9012');

  fireEvent.change(aadhaarInput, { target: { value: '98765' } });
  expect(aadhaarInput.value).toBe('9876-5');
  expect(await screen.findByText('Aadhaar number must be exactly 12 digits')).toBeDefined();
  expect((screen.getByRole('button', { name: 'Save changes' }) as HTMLButtonElement).disabled).toBe(true);

  fireEvent.change(aadhaarInput, { target: { value: '987654321098' } });
  expect(aadhaarInput.value).toBe('9876-5432-1098');
  expect(screen.queryByText('Aadhaar number must be exactly 12 digits')).toBeNull();
  expect((screen.getByRole('button', { name: 'Save changes' }) as HTMLButtonElement).disabled).toBe(false);

  fireEvent.click(screen.getByRole('button', { name: 'Save changes' }));
  await waitFor(() => expect(partnersApi.update).toHaveBeenCalledWith('partner', { aadhaarNumber: '987654321098' }));
});

it('displays human-readable formatted status labels for bank status and account status', async () => {
  show();
  const bankStatusButton = await screen.findByRole('button', { name: 'Status' });
  expect(bankStatusButton.textContent).toContain('Under Review');

  fireEvent.click(bankStatusButton);
  expect(screen.getByRole('option', { name: 'Under Review' })).toBeDefined();
  expect(screen.getByRole('option', { name: 'Approved' })).toBeDefined();
  expect(screen.getByRole('option', { name: 'Rejected' })).toBeDefined();

  fireEvent.click(screen.getByRole('option', { name: 'Approved' }));
  expect(bankStatusButton.textContent).toContain('Approved');
});
