import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Pencil, Trash2, MessageCircleQuestion, Search } from 'lucide-react';
import { faqsApi } from '../../api/faqs.api';
import { FAQForm } from './FAQForm';
import { ConfirmDialog } from '../../components/common/ConfirmDialog';
import { Pagination } from '../../components/ui/Pagination';
import { useToast } from '../../hooks/useToast';
import type { FAQ } from '../../types';

export const FAQsList: React.FC = () => {
  const queryClient = useQueryClient();
  const { success, error } = useToast();
  const [page, setPage] = useState(1);
  const limit = 20;
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');

  const [formOpen, setFormOpen] = useState(false);
  const [editItem, setEditItem] = useState<FAQ | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['faqs', page, search],
    queryFn: () => faqsApi.getAll({ page, limit, ...(search ? { search } : {}) }),
  });

  const faqs: FAQ[] = data?.data?.data?.items ?? [];
  const total: number = data?.data?.data?.total ?? 0;

  const createMutation = useMutation({
    mutationFn: (payload: { question: string; answer: string; isActive: boolean }) =>
      faqsApi.create(payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['faqs'] });
      success('FAQ created successfully');
      setFormOpen(false);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to create'),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: { question?: string; answer?: string; isActive?: boolean } }) =>
      faqsApi.update(id, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['faqs'] });
      success('FAQ updated successfully');
      setFormOpen(false);
      setEditItem(null);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to update'),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => faqsApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['faqs'] });
      success('FAQ deleted');
      setDeleteId(null);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to delete'),
  });

  const handleSubmit = (payload: { question: string; answer: string; isActive: boolean }) => {
    if (editItem) {
      updateMutation.mutate({ id: editItem.id, payload });
    } else {
      createMutation.mutate(payload);
    }
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    setSearch(searchInput);
  };

  const isSaving = createMutation.isPending || updateMutation.isPending;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">FAQs</h2>
          <p className="text-sm text-gray-500 mt-0.5">Manage frequently asked questions</p>
        </div>
        <button
          onClick={() => { setEditItem(null); setFormOpen(true); }}
          className="btn-primary flex items-center gap-2"
        >
          <Plus size={16} /> Add FAQ
        </button>
      </div>

      {/* Search */}
      <form onSubmit={handleSearch} className="flex gap-2 max-w-sm">
        <div className="relative flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Search FAQs..."
            className="input w-full pl-9"
          />
        </div>
        <button type="submit" className="btn-secondary">Search</button>
      </form>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100">
              {['Question', 'Answer', 'Status', 'Created', ''].map((h) => (
                <th
                  key={h}
                  className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide"
                >
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={5} className="text-center py-16 text-gray-400">Loading...</td>
              </tr>
            ) : faqs.length === 0 ? (
              <tr>
                <td colSpan={5} className="text-center py-16">
                  <MessageCircleQuestion size={32} className="mx-auto text-gray-200 mb-2" />
                  <p className="text-gray-400 text-sm">
                    {search ? 'No FAQs match your search.' : 'No FAQs yet. Add your first one!'}
                  </p>
                </td>
              </tr>
            ) : (
              faqs.map((item) => (
                <tr key={item.id} className="border-b border-gray-50 hover:bg-gray-50/50">
                  {/* Question */}
                  <td className="px-5 py-3.5 max-w-xs">
                    <p className="font-medium text-gray-900 line-clamp-2">{item.question}</p>
                  </td>

                  {/* Answer */}
                  <td className="px-5 py-3.5 max-w-sm">
                    <p className="text-gray-500 line-clamp-2">{item.answer}</p>
                  </td>

                  {/* Status */}
                  <td className="px-5 py-3.5">
                    <span
                      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        item.isActive
                          ? 'bg-green-50 text-green-700'
                          : 'bg-gray-100 text-gray-500'
                      }`}
                    >
                      {item.isActive ? 'Active' : 'Inactive'}
                    </span>
                  </td>

                  {/* Created */}
                  <td className="px-5 py-3.5 text-gray-500 text-xs whitespace-nowrap">
                    {new Date(item.createdAt).toLocaleDateString('en-IN', {
                      day: '2-digit',
                      month: 'short',
                      year: 'numeric',
                    })}
                  </td>

                  {/* Actions */}
                  <td className="px-5 py-3.5">
                    <div className="flex items-center gap-1 justify-end">
                      <button
                        onClick={() => { setEditItem(item); setFormOpen(true); }}
                        className="p-1.5 text-gray-400 hover:text-primary-600 hover:bg-primary-50 rounded-lg transition-colors"
                        title="Edit"
                      >
                        <Pencil size={15} />
                      </button>
                      <button
                        onClick={() => setDeleteId(item.id)}
                        className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                        title="Delete"
                      >
                        <Trash2 size={15} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>

        {total > limit && (
          <div className="px-5 py-4 border-t border-gray-50">
            <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
          </div>
        )}
      </div>

      {/* Form modal */}
      <FAQForm
        open={formOpen}
        initial={editItem}
        loading={isSaving}
        onSubmit={handleSubmit}
        onClose={() => { setFormOpen(false); setEditItem(null); }}
      />

      {/* Confirm delete */}
      <ConfirmDialog
        open={!!deleteId}
        title="Delete FAQ"
        message="Are you sure you want to delete this FAQ? This action cannot be undone."
        confirmLabel="Delete"
        variant="danger"
        onConfirm={() => deleteId && deleteMutation.mutate(deleteId)}
        onCancel={() => setDeleteId(null)}
      />
    </div>
  );
};
