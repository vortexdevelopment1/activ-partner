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
  expect(await screen.findByText('No activity submissions')).toBeTruthy();
  expect(activitiesApi.getPending).toHaveBeenCalledTimes(2);
  client.clear();
});

it('filters submissions on the server and only allows pending activities to be reviewed', async () => {
  const records = ['pending', 'approved', 'rejected'].map(status => ({
    id: status, name: `${status} activity`, status, venue: { name: 'Arena' }, createdAt: '2026-10-22T10:00:00Z',
  }));
  vi.mocked(activitiesApi.getPending).mockImplementation(async (params) => {
    const items = params?.status === 'all' ? records : records.filter(record => record.status === params?.status);
    return { data: { data: { items, total: params?.status === 'all' ? 30 : items.length } } } as any;
  });
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } });
  render(<QueryClientProvider client={client}><ActivityApprovalList /></QueryClientProvider>);
  expect(await screen.findByText('approved activity', { selector: 'p' })).toBeTruthy();
  expect(screen.getAllByRole('button', { name: 'Approve', exact: true })).toHaveLength(1);
  fireEvent.click(screen.getByRole('button', { name: 'Next page' }));
  await waitFor(() => expect(activitiesApi.getPending).toHaveBeenLastCalledWith({ page: 2, limit: 15, status: 'all' }));
  for (const [label, status] of [['Accepted', 'approved'], ['Rejected', 'rejected'], ['In Review', 'pending']] as const) {
    fireEvent.click(screen.getByRole('button', { name: label, exact: true }));
    await waitFor(() => expect(activitiesApi.getPending).toHaveBeenLastCalledWith({ page: 1, limit: 15, status }));
    expect(await screen.findByText(`${status} activity`, { selector: 'p' })).toBeTruthy();
    expect(screen.getByRole('button', { name: label, exact: true }).getAttribute('aria-pressed')).toBe('true');
    if (status !== 'pending') {
      expect(screen.queryByRole('button', { name: 'Approve', exact: true })).toBeNull();
      fireEvent.click(screen.getByTitle('View details'));
      expect(screen.queryByRole('button', { name: 'Approve', exact: true })).toBeNull();
      fireEvent.click(screen.getByRole('button', { name: 'Close dialog' }));
    }
  }
  client.clear();
});
