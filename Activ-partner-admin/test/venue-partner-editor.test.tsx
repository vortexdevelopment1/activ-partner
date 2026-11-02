// @vitest-environment jsdom
import React from 'react';
import { afterEach, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { VenueDetail } from '../src/pages/venues/VenueDetail';
import { venuesApi } from '../src/api/venues.api';
import { partnersApi } from '../src/api/partners.api';

vi.mock('../src/hooks/useToast', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }));
vi.mock('../src/api/venues.api', () => ({ venuesApi: { getById: vi.fn() } }));
vi.mock('../src/api/partners.api', () => ({ partnersApi: { getById: vi.fn(), update: vi.fn() } }));
afterEach(() => { cleanup(); vi.resetAllMocks(); });

it('opens the correct partner from the venue page and refreshes the displayed details after saving', async () => {
  let name = 'Original';
  vi.mocked(venuesApi.getById).mockImplementation(async () => ({ data: { data: {
    id: 'venue', name: 'Arena', partnerId: 'owner-partner', status: 'draft',
    partner: { id: 'owner-partner', firstName: name, businessName: 'Business' },
    createdAt: '2026-11-02', updatedAt: '2026-11-02',
  } } } as any));
  vi.mocked(partnersApi.getById).mockResolvedValue({ data: { data: {
    id: 'owner-partner', legalName: 'Business', firstName: name, phone: '+919876543210',
    status: 'active', kycStatus: 'PENDING', createdAt: '2026-11-02', updatedAt: '2026-11-02',
  } } } as any);
  vi.mocked(partnersApi.update).mockImplementation(async () => { name = 'Updated'; return { data: {} } as any; });
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } });
  render(<QueryClientProvider client={client}><MemoryRouter initialEntries={['/venues/venue']}><Routes><Route path="/venues/:id" element={<VenueDetail />} /></Routes></MemoryRouter></QueryClientProvider>);
  fireEvent.click(await screen.findByRole('button', { name: 'Edit partner' }));
  const firstName = await screen.findByLabelText('First name');
  expect(partnersApi.getById).toHaveBeenCalledWith('owner-partner');
  fireEvent.change(firstName, { target: { value: 'Updated' } });
  fireEvent.click(screen.getByRole('button', { name: 'Save changes' }));
  await waitFor(() => expect(partnersApi.update).toHaveBeenCalledWith('owner-partner', { firstName: 'Updated' }));
  expect(await screen.findByText('Updated', { selector: 'span' })).toBeTruthy();
  expect(screen.queryByRole('dialog', { name: 'Partner details' })).toBeNull();
  client.clear();
});
