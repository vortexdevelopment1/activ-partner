// @vitest-environment jsdom
import React from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { CreateVenueModal } from '../src/pages/venues/CreateVenueModal';
import { categoriesApi } from '../src/api/categories.api';
import { partnersApi } from '../src/api/partners.api';
import { questionsApi } from '../src/api/questions.api';

vi.mock('../src/api/axios', () => ({ default: {
  get: vi.fn().mockResolvedValue({ data: { data: { city: 'Indore', state: 'Madhya Pradesh' } } }),
} }));
vi.mock('../src/api/categories.api', () => ({ categoriesApi: { getAllActive: vi.fn() } }));
vi.mock('../src/api/partners.api', () => ({ partnersApi: { getAll: vi.fn() } }));
vi.mock('../src/api/questions.api', () => ({ questionsApi: { getByCategory: vi.fn() } }));

const response = (data: unknown) => ({ data: { data } }) as any;
const question = (categoryId: string) => ({
  id: `${categoryId}-floor`, categoryId, questionText: `${categoryId} flooring`,
  questionType: 'select', options: ['Wood', 'Synthetic'], isRequired: true,
});

let queryClient: QueryClient;
beforeEach(() => {
  vi.clearAllMocks();
  vi.stubGlobal('google', { maps: { places: {
    PlacesServiceStatus: { OK: 'OK' },
    AutocompleteService: class { getPlacePredictions(_request: unknown, callback: Function) { callback([], 'OK'); } },
  } } });
  queryClient = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } });
  vi.mocked(categoriesApi.getAllActive).mockResolvedValue(response([
    { id: 'squash', name: 'Squash' }, { id: 'basketball', name: 'Basketball' },
  ]));
  vi.mocked(partnersApi.getAll).mockResolvedValue(response({ items: [
    { id: 'partner', firstName: 'Test', lastName: 'Partner' },
  ] }));
  vi.mocked(questionsApi.getByCategory).mockImplementation(async (id) => response([question(id)]));
});
afterEach(() => { cleanup(); queryClient.clear(); vi.unstubAllGlobals(); });

async function openCategories() {
  render(<QueryClientProvider client={queryClient}><CreateVenueModal open onClose={() => {}} /></QueryClientProvider>);
  fireEvent.focus(screen.getByPlaceholderText(/Search partner by name/));
  fireEvent.mouseDown(await screen.findByRole('button', { name: 'Test Partner' }));
  fireEvent.change(screen.getByPlaceholderText('Gold Star Gym'), { target: { value: 'Sports Arena' } });
  fireEvent.change(screen.getByPlaceholderText('9876543210'), { target: { value: '9876543210' } });
  fireEvent.click(screen.getByRole('button', { name: 'Next' }));
  fireEvent.change(screen.getByPlaceholderText(/Search address/), { target: { value: 'Indore' } });
  fireEvent.change(screen.getByPlaceholderText('Bengaluru'), { target: { value: 'Indore' } });
  fireEvent.change(screen.getByPlaceholderText('Karnataka'), { target: { value: 'Madhya Pradesh' } });
  fireEvent.change(screen.getByPlaceholderText('560008'), { target: { value: '452010' } });
  fireEvent.click(screen.getByRole('button', { name: 'Next' }));
  fireEvent.click(screen.getByRole('button', { name: 'Next' }));
  expect(screen.getByText('Step 4 of 7: Categories')).toBeTruthy();
}

describe('Create Venue sport changes', () => {
  it('supports Next, Back and repeated sport changes with cached questions', async () => {
    await openCategories();
    for (const [sport, id] of [['Squash', 'squash'], ['Basketball', 'basketball'], ['Squash', 'squash']]) {
      fireEvent.click(screen.getByRole('radio', { name: sport }));
      fireEvent.click(screen.getByRole('button', { name: 'Next' }));
      expect(await screen.findByText(`${id} flooring`)).toBeTruthy();
      expect((screen.getByRole('button', { name: 'Next' }) as HTMLButtonElement).disabled).toBe(true);
      expect(screen.getByRole('button', { name: 'Wood' })).toBeTruthy();
      fireEvent.click(screen.getByRole('button', { name: 'Wood' }));
      fireEvent.click(screen.getByRole('button', { name: 'Back' }));
      expect(screen.getByRole('dialog')).toBeTruthy();
      expect(screen.getByText('Step 4 of 7: Categories')).toBeTruthy();
    }
  });

  it('keeps the wizard usable when the new sport questions fail and supports retry', async () => {
    vi.mocked(questionsApi.getByCategory).mockRejectedValueOnce(new Error('offline'));
    await openCategories();
    fireEvent.click(screen.getByRole('radio', { name: 'Basketball' }));
    fireEvent.click(screen.getByRole('button', { name: 'Next' }));
    expect(await screen.findByText('Unable to load questions. Please try again.')).toBeTruthy();
    expect((screen.getByRole('button', { name: 'Next' }) as HTMLButtonElement).disabled).toBe(true);
    fireEvent.click(screen.getByRole('button', { name: 'Retry' }));
    expect(await screen.findByText('basketball flooring')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Back' })).toBeTruthy();
  });

  it('does not let a late response restore the previous sport questions', async () => {
    let finishSquash!: (value: any) => void;
    vi.mocked(questionsApi.getByCategory).mockImplementation((id) => id === 'squash'
      ? new Promise(resolve => { finishSquash = resolve; })
      : Promise.resolve(response([question(id)])));
    await openCategories();
    fireEvent.click(screen.getByRole('radio', { name: 'Squash' }));
    const body = screen.getByRole('dialog').querySelector('.modal-scroll-body')!;
    body.scrollTop = 400;
    fireEvent.click(screen.getByRole('button', { name: 'Next' }));
    expect(body.scrollTop).toBe(0);
    expect((screen.getByRole('button', { name: 'Next' }) as HTMLButtonElement).disabled).toBe(true);
    fireEvent.click(screen.getByRole('button', { name: 'Back' }));
    fireEvent.click(screen.getByRole('radio', { name: 'Basketball' }));
    fireEvent.click(screen.getByRole('button', { name: 'Next' }));
    expect(await screen.findByText('basketball flooring')).toBeTruthy();
    finishSquash(response([question('squash')]));
    await waitFor(() => expect(screen.queryByText('squash flooring')).toBeNull());
    expect(screen.getByRole('dialog')).toBeTruthy();
  });

  it('shows an error instead of crashing when question data is malformed', async () => {
    vi.mocked(questionsApi.getByCategory).mockResolvedValueOnce(response({ unexpected: true }));
    await openCategories();
    fireEvent.click(screen.getByRole('radio', { name: 'Squash' }));
    fireEvent.click(screen.getByRole('button', { name: 'Next' }));
    expect(await screen.findByRole('alert')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Back' }));
    fireEvent.click(screen.getByRole('radio', { name: 'Basketball' }));
    fireEvent.click(screen.getByRole('button', { name: 'Next' }));
    expect(await screen.findByText('basketball flooring')).toBeTruthy();
  });
});
