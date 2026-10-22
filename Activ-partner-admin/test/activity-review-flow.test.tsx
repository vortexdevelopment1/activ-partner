// @vitest-environment jsdom
import React from 'react';
import { afterEach, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ActivityApprovalList } from '../src/pages/activities/ActivityApprovalList';
import { activitiesApi } from '../src/api/activities.api';

vi.mock('../src/api/activities.api', () => ({ activitiesApi: {
  getPending: vi.fn(), approve: vi.fn(), reject: vi.fn(),
} }));
vi.mock('../src/hooks/useToast', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }));
afterEach(() => { cleanup(); vi.resetAllMocks(); });

it('approves the submitted activity and refreshes the pending queue', async () => {
  let approved = false;
  vi.mocked(activitiesApi.getPending).mockImplementation(async () => ({ data: { data: {
    items: approved ? [] : [{ id: 'activity', name: 'Swimming', status: 'pending',
      venue: { name: 'Arena', city: 'Indore' }, category: { name: 'Swimming' },
      amenities: ['Parking'], createdAt: '2026-10-22T10:00:00Z' }], total: approved ? 0 : 1,
  } } } as any));
  vi.mocked(activitiesApi.approve).mockImplementation(async () => {
    approved = true;
    return { data: { data: { status: 'approved' } } } as any;
  });
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } });
  render(<QueryClientProvider client={client}><ActivityApprovalList /></QueryClientProvider>);
  expect(await screen.findByText('Swimming', { selector: 'p' })).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'Approve', exact: true }));
  expect(activitiesApi.approve).not.toHaveBeenCalled();
  fireEvent.click(screen.getByRole('button', { name: 'Approve Activity', exact: true }));
  await waitFor(() => expect(activitiesApi.approve).toHaveBeenCalledWith('activity'));
  expect(await screen.findByText('No pending activities')).toBeTruthy();
  expect(activitiesApi.getPending).toHaveBeenCalledTimes(2);
  client.clear();
});
