// @vitest-environment jsdom
import React from 'react';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { QuestionsList } from '../src/pages/questions/QuestionsList';
import { questionsApi } from '../src/api/questions.api';

const toast = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn() }));
vi.mock('../src/hooks/useToast', () => ({ useToast: () => toast }));
vi.mock('../src/api/categories.api', () => ({ categoriesApi: {
  getAll: vi.fn(async () => ({ data: { data: { items: [] } } })),
} }));
vi.mock('../src/api/questions.api', () => ({ questionsApi: {
  getAll: vi.fn(async () => ({ data: { data: { items: [{
    id: 'question', questionText: 'Activity Description', questionType: 'textarea',
    categoryId: null, options: [], order: 0, isRequired: true, isActive: true,
  }], total: 1 } } })),
  update: vi.fn(), create: vi.fn(), delete: vi.fn(), reorder: vi.fn(),
} }));

let client: QueryClient;
beforeEach(() => {
  vi.clearAllMocks();
  client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } });
});
afterEach(() => { cleanup(); client.clear(); });
function show() {
  render(<MemoryRouter><QueryClientProvider client={client}><QuestionsList /></QueryClientProvider></MemoryRouter>);
}

for (const fails of [false, true]) {
  it(`rapid Save Changes submissions send one request and one ${fails ? 'error, then allow retry' : 'success toast'}`, async () => {
    let finish!: () => void;
    vi.mocked(questionsApi.update).mockImplementationOnce(() => new Promise((resolve, reject) => {
      finish = () => fails ? reject({ response: { data: { message: 'Save failed' } } }) : resolve({ data: {} } as any);
    }));
    show();
    fireEvent.click(await screen.findByRole('button', { name: 'Edit Activity Description' }));
    const button = screen.getByRole('button', { name: 'Save Changes' });
    const form = document.getElementById(button.getAttribute('form')!)!;
    // Submitting directly also covers Enter or rapid events before disabled renders.
    fireEvent.submit(form);
    fireEvent.submit(form);
    fireEvent.submit(form);
    await waitFor(() => expect(questionsApi.update).toHaveBeenCalledTimes(1));
    expect((screen.getByRole('button', { name: 'Saving...' }) as HTMLButtonElement).disabled).toBe(true);
    expect((screen.getByRole('button', { name: 'Cancel' }) as HTMLButtonElement).disabled).toBe(true);
    expect(toast.success).not.toHaveBeenCalled();
    expect(toast.error).not.toHaveBeenCalled();
    await act(async () => { finish(); });
    if (fails) {
      await waitFor(() => expect(toast.error).toHaveBeenCalledTimes(1));
      expect(toast.success).not.toHaveBeenCalled();
      await waitFor(() => expect((screen.getByRole('button', { name: 'Save Changes' }) as HTMLButtonElement).disabled).toBe(false));
      vi.mocked(questionsApi.update).mockResolvedValueOnce({ data: {} } as any);
      fireEvent.click(screen.getByRole('button', { name: 'Save Changes' }));
      await waitFor(() => expect(questionsApi.update).toHaveBeenCalledTimes(2));
    }
    await waitFor(() => expect(toast.success).toHaveBeenCalledTimes(1));
    expect(screen.queryByRole('dialog', { name: 'Edit Question' })).toBeNull();
  });
}
