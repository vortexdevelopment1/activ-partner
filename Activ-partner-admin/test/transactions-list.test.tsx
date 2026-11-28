// @vitest-environment jsdom
import React from 'react';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, expect, it, vi } from 'vitest';
import { transactionsApi } from '../src/api/transactions.api';
import { TransactionsList } from '../src/pages/transactions/TransactionsList';

vi.mock('../src/api/transactions.api', () => ({ transactionsApi: { list: vi.fn() } }));
afterEach(() => { cleanup(); vi.resetAllMocks(); });

it('paginates payments and opens each transaction type at page one', async () => {
  vi.mocked(transactionsApi.list).mockImplementation(async (view, page, limit) => ({
    page, limit, total: 26, totalPages: 2,
    items: [{
      id: view, reference: `${view}-${page}`, date: '2026-11-27T12:00:00Z',
      amount: 1000, currency: 'INR', status: 'CAPTURED', partner: 'Venue Partner',
      commission: { commissionPercent: 5, activCommission: 50, gstOnCommission: 9, netReceived: 941 },
    }],
  }));
  const client = new QueryClient({ defaultOptions: { queries: { gcTime: 0, retry: false } } });
  render(
    <QueryClientProvider client={client}>
      <MemoryRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <TransactionsList />
      </MemoryRouter>
    </QueryClientProvider>,
  );
  expect(await screen.findByText('payments-1')).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'Next page' }));
  expect(await screen.findByText('payments-2')).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'Refunds' }));
  expect(await screen.findByText('refunds-1')).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'Commission estimates' }));
  expect(await screen.findByText('ACTIV (5%) · 50.00 INR')).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'Partner payouts' }));
  expect(await screen.findByText('payouts-1')).toBeTruthy();
});
