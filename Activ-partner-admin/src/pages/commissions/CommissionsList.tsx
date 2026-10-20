import React, { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Pencil, Trash2, Percent, Search, Save } from 'lucide-react';
import { commissionsApi } from '../../api/commissions.api';
import { CommissionForm } from './CommissionForm';
import { ConfirmDialog } from '../../components/common/ConfirmDialog';
import { Pagination } from '../../components/ui/Pagination';
import { useToast } from '../../hooks/useToast';
import type { Commission, EffectiveCityCommission } from '../../types';

export const CommissionsList: React.FC = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const search = searchParams.get('search') ?? '';
  const queryClient = useQueryClient();
  const { success, error } = useToast();
  const [page, setPage] = useState(1);
  const limit = 20;

  const [formOpen, setFormOpen] = useState(false);
  const [editItem, setEditItem] = useState<Commission | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [defaultRate, setDefaultRate] = useState('');

  const { data: defaultData, isFetching: isDefaultLoading, isError: isDefaultError, refetch: refetchDefault } = useQuery({
    queryKey: ['commissions', 'default'],
    queryFn: commissionsApi.getDefault,
  });

  useEffect(() => {
    const rate = defaultData?.data?.data?.commissionPercentage;
    if (typeof rate === 'number') setDefaultRate(String(rate));
  }, [defaultData]);

  const { data, isLoading } = useQuery({
    queryKey: ['commissions', 'cities', page, search],
    queryFn: () => commissionsApi.getCities({ page, limit, search: search || undefined }),
  });

  const commissions: EffectiveCityCommission[] = data?.data?.data?.items ?? [];
  const total: number = data?.data?.data?.total ?? 0;

  const createMutation = useMutation({
    mutationFn: (payload: { city: string; state: string; commissionPercentage: number }) =>
      commissionsApi.create(payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['commissions'] });
      success('Commission created successfully');
      setFormOpen(false);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to create'),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: { city?: string; state?: string; commissionPercentage?: number } }) =>
      commissionsApi.update(id, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['commissions'] });
      success('Commission updated successfully');
      setFormOpen(false);
      setEditItem(null);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to update'),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => commissionsApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['commissions'] });
      success('Commission deleted');
      setDeleteId(null);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to delete'),
  });

  const defaultMutation = useMutation({
    mutationFn: (rate: number) => commissionsApi.updateDefault(rate),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['commissions'] });
      success('India-wide commission updated');
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to update default commission'),
  });

  const saveDefaultRate = () => {
    if (isDefaultLoading || isDefaultError || defaultRate.trim() === '') {
      error('Wait for the commission rate to load before saving');
      return;
    }
    const rate = Number(defaultRate);
    if (!Number.isFinite(rate) || rate < 0 || rate > 100) {
      error('Enter a commission percentage between 0 and 100');
      return;
    }
    defaultMutation.mutate(rate);
  };

  const handleSubmit = (payload: { city: string; state: string; commissionPercentage: number }) => {
    if (editItem?.id) {
      updateMutation.mutate({ id: editItem.id, payload });
    } else {
      createMutation.mutate(payload);
    }
  };

  const isSaving = createMutation.isPending || updateMutation.isPending;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Commissions</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            Set the India-wide rate and add location overrides when needed
          </p>
        </div>
        <button
          onClick={() => { setEditItem(null); setFormOpen(true); }}
          className="btn-primary flex items-center gap-2"
        >
          <Plus size={16} /> Add Commission
        </button>
      </div>

      <section className="bg-white border border-gray-200 rounded-lg p-4 sm:p-5">
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              <Percent size={18} className="text-primary-600" />
              <h3 className="font-semibold text-gray-900">India-wide default</h3>
            </div>
            <p className="text-sm text-gray-500 mt-1">
              Applies to every state and city unless a location override exists.
            </p>
          </div>
          <div className="flex items-end gap-2 w-full sm:w-auto">
            <label className="flex-1 sm:w-36">
              <span className="block text-xs font-medium text-gray-600 mb-1">Commission (%)</span>
              <input
                aria-label="India-wide commission percentage"
                type="number"
                min="0"
                max="100"
                step="0.01"
                value={isDefaultLoading || isDefaultError ? '' : defaultRate}
                placeholder={isDefaultLoading ? 'Loading...' : isDefaultError ? 'Unavailable' : 'Enter rate'}
                aria-busy={isDefaultLoading}
                disabled={isDefaultLoading || isDefaultError || defaultMutation.isPending}
                onChange={(event) => setDefaultRate(event.target.value)}
                className="input w-full"
              />
            </label>
            <button
              type="button"
              onClick={saveDefaultRate}
              disabled={isDefaultLoading || isDefaultError || defaultRate.trim() === '' || defaultMutation.isPending}
              className="btn-primary flex items-center gap-2 whitespace-nowrap"
            >
              <Save size={16} /> {defaultMutation.isPending ? 'Saving...' : 'Save'}
            </button>
          </div>
        </div>
        {isDefaultError && (
          <p role="alert" className="mt-3 text-sm text-red-600">
            Could not load the current commission rate.{' '}
            <button type="button" onClick={() => refetchDefault()} className="font-medium underline">Retry</button>
          </p>
        )}
      </section>

      <div>
        <h3 className="font-semibold text-gray-900">All Indian cities</h3>
        <p className="text-sm text-gray-500 mt-0.5">Edit any city to give it a rate different from its state or India-wide default.</p>
      </div>

      <label className="relative block max-w-sm">
        <span className="sr-only">Search commissions</span>
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input className="input pl-9" value={search} placeholder="Search city or state..."
          onChange={(event) => { setPage(1); setSearchParams(event.target.value ? { search: event.target.value } : {}, { replace: true }); }} />
      </label>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <div className="overflow-x-auto" role="region" aria-label="Scrollable table" tabIndex={0}>
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100">
              {['City', 'State', 'Commission %', 'Rate source', ''].map((h) => (
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
                <td colSpan={5} className="text-center py-16 text-gray-400">
                  Loading...
                </td>
              </tr>
            ) : commissions.length === 0 ? (
              <tr>
                <td colSpan={5} className="text-center py-16">
                  <Percent size={32} className="mx-auto text-gray-200 mb-2" />
                  <p className="text-gray-400 text-sm">No Indian cities match this search.</p>
                </td>
              </tr>
            ) : (
              commissions.map((item) => (
                <tr key={`${item.state}-${item.city}`} className="border-b border-gray-50 hover:bg-gray-50/50">
                  {/* City */}
                  <td className="px-5 py-3.5">
                    <p className="font-medium text-gray-900">{item.city || 'All cities'}</p>
                  </td>
                  <td className="px-5 py-3.5 text-gray-600">{item.state}</td>

                  {/* Commission % */}
                  <td className="px-5 py-3.5">
                    <span className="inline-flex items-center gap-1 text-sm font-semibold text-primary-700 bg-primary-50 px-2.5 py-0.5 rounded-full">
                      <Percent size={12} />
                      {item.commissionPercentage}%
                    </span>
                  </td>

                  {/* Source */}
                  <td className="px-5 py-3.5 text-xs">
                    <span className="capitalize text-gray-600 bg-gray-100 px-2 py-1 rounded-full">
                      {item.source === 'default' ? 'India default' : `${item.source} override`}
                    </span>
                  </td>

                  {/* Actions */}
                  <td className="px-5 py-3.5">
                    <div className="flex items-center gap-1 justify-end">
                      <button
                        onClick={() => {
                          setEditItem({
                            id: item.overrideId ?? '',
                            city: item.city,
                            state: item.state,
                            commissionPercentage: item.commissionPercentage,
                            createdAt: '',
                            updatedAt: '',
                          });
                          setFormOpen(true);
                        }}
                        className="p-1.5 text-gray-400 hover:text-primary-600 hover:bg-primary-50 rounded-lg transition-colors"
                        title="Edit"
                      >
                        <Pencil size={15} />
                      </button>
                      {item.overrideId && (
                        <button
                          onClick={() => setDeleteId(item.overrideId)}
                          className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                          title="Remove city override"
                        >
                          <Trash2 size={15} />
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
        </div>

        {total > limit && (
          <div className="px-5 py-4 border-t border-gray-50">
            <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
          </div>
        )}
      </div>

      {/* Form modal */}
      <CommissionForm
        open={formOpen}
        initial={editItem}
        loading={isSaving}
        onSubmit={handleSubmit}
        onClose={() => { setFormOpen(false); setEditItem(null); }}
      />

      {/* Confirm delete */}
      <ConfirmDialog
        open={!!deleteId}
        title="Delete Commission"
        message="Are you sure you want to delete this commission rule? This action cannot be undone."
        confirmLabel="Delete"
        variant="danger"
        onConfirm={() => deleteId && deleteMutation.mutate(deleteId)}
        onCancel={() => setDeleteId(null)}
      />
    </div>
  );
};
