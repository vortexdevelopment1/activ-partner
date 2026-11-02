// @vitest-environment jsdom
import React from 'react';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { PartnerEditor } from '../src/pages/partners/PartnerEditor';
import { partnersApi } from '../src/api/partners.api';

const toast = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn() }));
vi.mock('../src/hooks/useToast', () => ({ useToast: () => toast }));
vi.mock('../src/api/partners.api', () => ({ partnersApi: { getById: vi.fn(), update: vi.fn() } }));
let client: QueryClient;
const close = vi.fn();
beforeEach(() => {
  vi.clearAllMocks();
  client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } });
  vi.mocked(partnersApi.getById).mockResolvedValue({ data: { data: {
    id: 'partner', legalName: 'Business', firstName: 'Old', phone: '+919876543210', status: 'active', kycStatus: 'PENDING',
    panNumber: 'OLD-PAN', createdAt: '2026-01-01', updatedAt: '2026-01-01', bankAccounts: [{ id: 'bank', accountHolderName: 'Owner', bankName: 'Bank', accountNumber: '123456', ifscCode: 'ABCD0123456', status: 'UNDER_REVIEW', isPrimary: false }],
  } } } as any);
  vi.mocked(partnersApi.update).mockResolvedValue({ data: {} } as any);
});
afterEach(() => { cleanup(); client.clear(); });
const show = () => render(<QueryClientProvider client={client}><PartnerEditor id="partner" onClose={close} /></QueryClientProvider>);

it('loads full details and sends only edited profile fields', async () => {
  show();
  const pan = await screen.findByLabelText('PAN number');
  expect((pan as HTMLInputElement).value).toBe('OLD-PAN');
  fireEvent.change(pan, { target: { value: 'NEW-PAN' } });
  fireEvent.change(screen.getByLabelText('Account status'), { target: { value: 'SUSPENDED' } });
  fireEvent.click(screen.getByRole('button', { name: 'Save changes' }));
  await waitFor(() => expect(partnersApi.update).toHaveBeenCalledWith('partner', { panNumber: 'NEW-PAN', status: 'SUSPENDED' }));
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
