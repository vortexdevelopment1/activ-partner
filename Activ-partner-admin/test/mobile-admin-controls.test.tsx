// @vitest-environment jsdom
import React from 'react';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { CategoryForm } from '../src/pages/categories/CategoryForm';
import { QuestionForm } from '../src/pages/questions/QuestionForm';
import { QuestionsList } from '../src/pages/questions/QuestionsList';
import { UsersList } from '../src/pages/users/UsersList';
import { CallbackDetail } from '../src/pages/support/CallbackDetail';
import { supportApi } from '../src/api/support.api';
import { LogsList } from '../src/pages/logs/LogsList';

vi.mock('../src/api/axios', () => ({ default: {} }));
vi.mock('../src/api/categories.api', () => ({ categoriesApi: {
  getAll: vi.fn(async () => ({ data: { data: { items: [{ id: 'yoga', name: 'Yoga' }] } } })),
} }));
vi.mock('../src/api/questions.api', () => ({ questionsApi: {
  getAll: vi.fn(async () => ({ data: { data: { items: [
    { id: 'global', questionText: 'Global question', questionType: 'text', categoryId: null, isActive: true },
    { id: 'yoga-q', questionText: 'Yoga question', questionType: 'text', categoryId: 'yoga', isActive: true },
  ], total: 2 } } })),
} }));
vi.mock('../src/api/users.api', () => ({ usersApi: {
  getAll: vi.fn(async () => ({ data: { data: { items: [
    { id: 'user', firstName: 'Alice', role: 'user', createdAt: '2026-10-20', isActive: true },
    { id: 'partner', firstName: 'Bob', role: 'partner', createdAt: '2026-10-20', isActive: true },
  ], total: 2 } } })),
} }));
vi.mock('../src/api/support.api', () => ({ supportApi: {
  getCallbackById: vi.fn(async () => ({ data: { data: {
    id: 'callback', partnerName: 'Test Partner', phone: '9876543210', email: 'partner@example.test',
    status: 'pending', adminNotes: '', venueName: 'Arena', callbackDate: '2026-10-21', callbackTime: '10:00',
    createdAt: '2026-10-20T10:00:00Z',
  } } })),
  updateCallback: vi.fn(async () => ({ data: {} })),
} }));
const targetId = '80a358d3-2910-4ee0-854c-13a7f5d0aaaa';
vi.mock('../src/api/logs.api', () => ({ logsApi: {
  getResources: vi.fn(async () => ({ data: { data: ['content_documents'] } })),
  getAll: vi.fn(async () => ({ data: { data: { items: [{
    id: 'log', action: 'publish', resource: 'content_documents',
    targetId: '80a358d3-2910-4ee0-854c-13a7f5d0aaaa', actor: 'Super Admin',
    details: { outcome: 'success', statusCode: 200, decision: null }, createdAt: '2026-10-22T10:00:00Z',
  }], total: 1 } } })),
} }));

let client: QueryClient;
beforeEach(() => {
  client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } });
  vi.stubGlobal('innerWidth', 360);
  vi.stubGlobal('innerHeight', 640);
});
afterEach(() => { cleanup(); client.clear(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });

function show(element: React.ReactElement, path = '/') {
  render(<MemoryRouter initialEntries={[path]}><QueryClientProvider client={client}>{element}</QueryClientProvider></MemoryRouter>);
}

function openSelect(name: string) {
  const trigger = screen.getByRole('button', { name });
  vi.spyOn(trigger, 'getBoundingClientRect').mockReturnValue({
    x: 24, y: 460, left: 24, right: 336, top: 460, bottom: 504,
    width: 312, height: 44, toJSON: () => ({}),
  });
  fireEvent.click(trigger);
  const panel = screen.getByRole('listbox', { name });
  expect(Number.parseFloat(panel.style.left) + Number.parseFloat(panel.style.width)).toBeLessThanOrEqual(360);
  expect(Number.parseFloat(panel.style.maxHeight)).toBeLessThanOrEqual(280);
  expect(Number.parseFloat(panel.style.top) - Number.parseFloat(panel.style.maxHeight)).toBeGreaterThanOrEqual(0);
  return panel;
}

it('category type dropdown stays bounded and its pinned submit button saves the selected value', async () => {
  const submit = vi.fn().mockResolvedValue(undefined);
  show(<CategoryForm open onClose={() => {}} onSubmit={submit} />);
  fireEvent.change(screen.getByPlaceholderText('e.g. Swimming Pool'), { target: { value: 'Swimming' } });
  openSelect('Category type');
  fireEvent.click(screen.getByRole('option', { name: 'Court Booking' }));
  const save = screen.getByRole('button', { name: 'Add Category' });
  expect(save.closest('.modal-scroll-body')).toBeNull();
  fireEvent.click(save);
  await waitFor(() => expect(submit).toHaveBeenCalledWith(expect.objectContaining({
    name: 'Swimming', type: 'court_booking',
  }), null));
});

it('question category dropdown and pinned footer preserve the submitted category', async () => {
  const submit = vi.fn().mockResolvedValue(undefined);
  show(<QuestionForm open onClose={() => {}} onSubmit={submit} />);
  await waitFor(() => expect(client.isFetching()).toBe(0));
  fireEvent.change(screen.getByPlaceholderText(/What is your gym capacity/), { target: { value: 'How many mats?' } });
  const panel = openSelect('Question category');
  expect(panel.closest('[role="dialog"]')).toBeNull();
  fireEvent.click(screen.getByRole('option', { name: 'Yoga' }));
  const save = screen.getByRole('button', { name: 'Add Question' });
  expect(save.closest('.modal-scroll-body')).toBeNull();
  fireEvent.click(save);
  await waitFor(() => expect(submit).toHaveBeenCalledWith(expect.objectContaining({
    questionText: 'How many mats?', categoryId: 'yoga',
  }), expect.anything()));
});

it('questions category filter uses the bounded menu and filters the rows', async () => {
  show(<QuestionsList />);
  expect(await screen.findByText('Global question')).toBeTruthy();
  openSelect('Filter questions by category');
  fireEvent.click(screen.getByRole('option', { name: 'Yoga' }));
  expect(screen.getByText('Yoga question')).toBeTruthy();
  expect(screen.queryByText('Global question')).toBeNull();
});

it('users role filter uses the bounded menu and preserves role filtering', async () => {
  show(<UsersList />);
  expect(await screen.findByText('Alice')).toBeTruthy();
  openSelect('Filter users by role');
  fireEvent.click(screen.getByRole('option', { name: 'Partner' }));
  expect(screen.getByText('Bob')).toBeTruthy();
  expect(screen.queryByText('Alice')).toBeNull();
});

it('callback status menu stays bounded and saves the selected status', async () => {
  show(<Routes><Route path="/support/callback/:id" element={<CallbackDetail />} /></Routes>, '/support/callback/callback');
  await screen.findByText('Update Status');
  openSelect('Callback status');
  fireEvent.click(screen.getByRole('option', { name: 'In Progress' }));
  fireEvent.click(screen.getAllByRole('button', { name: 'Save Changes' })[0]);
  await waitFor(() => expect(supportApi.updateCallback).toHaveBeenCalledWith('callback', {
    status: 'in_progress', adminNotes: '',
  }));
});

it('event details preserve the complete target ID for selecting and copying', async () => {
  show(<LogsList />);
  fireEvent.click(await screen.findByTitle('View event details'));
  const target = screen.getByLabelText('Target ID');
  expect(target.textContent).toBe(targetId);
  expect(target.getAttribute('title')).toBe(targetId);
});
