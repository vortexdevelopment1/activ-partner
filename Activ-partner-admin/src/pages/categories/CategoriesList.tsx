import React, { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Pencil, Trash2, ToggleLeft, ToggleRight, Search } from 'lucide-react';
import { categoriesApi } from '../../api/categories.api';
import { activityLogoUrl } from '../../utils/activityLogos';
import { CategoryForm } from './CategoryForm';
import { ConfirmDialog } from '../../components/common/ConfirmDialog';
import { Pagination } from '../../components/ui/Pagination';
import { useToast } from '../../hooks/useToast';
import type { Category, CategoryType } from '../../types';

const CATEGORY_TYPE_LABELS: Record<CategoryType, string> = {
  single_booking: 'Single Booking',
  court_booking: 'Court Booking',
  turf_booking: 'Turf Booking',
  table_booking: 'Table Booking',
  cricket_nets_booking: 'Cricket Nets Booking',
};

export const CategoriesList: React.FC = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const search = searchParams.get('search') ?? '';
  const queryClient = useQueryClient();
  const { success, error } = useToast();
  const [page, setPage] = useState(1);
  const limit = 12;

  const [formOpen, setFormOpen] = useState(false);
  const [editItem, setEditItem] = useState<Category | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);

  const categoryQueryKey = ['categories', search, page] as const;
  const { data, isLoading } = useQuery({
    queryKey: categoryQueryKey,
    queryFn: () => categoriesApi.getAll({ page, limit, search: search || undefined }),
  });

  const categories: Category[] = data?.data?.data?.items ?? [];
  const total: number = data?.data?.data?.total ?? 0;

  const createMutation = useMutation({
    mutationFn: ({ formData }: { formData: FormData }) =>
      categoriesApi.create(formData),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['categories'] });
      success('Category created successfully');
      setFormOpen(false);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to create'),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, formData }: { id: string; formData: FormData }) =>
      categoriesApi.update(id, formData),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['categories'] });
      success('Category updated successfully');
      setFormOpen(false);
      setEditItem(null);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to update'),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => categoriesApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['categories'] });
      success('Category deleted');
      setDeleteId(null);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to delete'),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id }: { id: string; isActive: boolean }) => categoriesApi.toggleStatus(id),
    onMutate: async ({ id, isActive }) => {
      await queryClient.cancelQueries({ queryKey: ['categories'] });
      const previous = queryClient.getQueryData(categoryQueryKey);

      queryClient.setQueryData(categoryQueryKey, (current: any) => {
        const items = current?.data?.data?.items;
        if (!Array.isArray(items)) return current;
        return {
          ...current,
          data: {
            ...current.data,
            data: {
              ...current.data.data,
              items: items.map((category: Category) =>
                category.id === id ? { ...category, isActive: !isActive } : category,
              ),
            },
          },
        };
      });

      return { previous, nextActive: !isActive };
    },
    onSuccess: (_res, _vars, context) => {
      success(`Category ${context?.nextActive ? 'enabled' : 'disabled'} successfully`);
    },
    onError: (err: any, _vars, context) => {
      if (context?.previous) queryClient.setQueryData(categoryQueryKey, context.previous);
      error(err?.response?.data?.message ?? 'Failed to update category status');
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: ['categories'] }),
  });

  const handleFormSubmit = async (
    formData: {
      name: string;
      description: string;
      icon: string;
      type: CategoryType | '';
      order: number;
      isActive: boolean;
    },
    imageFile: File | null,
  ) => {
    const fd = new FormData();
    fd.append('name', formData.name);
    if (formData.description) fd.append('description', formData.description);
    if (formData.icon) fd.append('icon', formData.icon);
    fd.append('type', formData.type);
    fd.append('order', String(formData.order));
    fd.append('isActive', String(formData.isActive));
    if (imageFile) fd.append('image', imageFile);

    if (editItem) {
      updateMutation.mutate({ id: editItem.id, formData: fd });
    } else {
      createMutation.mutate({ formData: fd });
    }
  };

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Categories</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            Manage venue categories (gym, swimming pool, etc.)
          </p>
        </div>
        <button
          onClick={() => { setEditItem(null); setFormOpen(true); }}
          className="btn-primary flex items-center gap-2"
        >
          <Plus size={16} /> Add Category
        </button>
      </div>

      <label className="relative block max-w-sm">
        <span className="sr-only">Search categories</span>
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input className="input pl-9" value={search} placeholder="Search categories..."
          onChange={(event) => {
            setPage(1);
            setSearchParams(event.target.value ? { search: event.target.value } : {}, { replace: true });
          }} />
      </label>

      {/* Grid */}
      {isLoading ? (
        <div className="text-center py-20 text-gray-400">Loading...</div>
      ) : categories.length === 0 ? (
        <div className="text-center py-20 text-gray-400">
          No categories yet. Add your first one!
        </div>
      ) : (
        <>
        <div className="hidden sm:grid sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {categories.map((cat) => (
            <div
              key={cat.id}
              className="bg-white rounded-xl border border-gray-100 overflow-hidden hover:shadow-sm transition-shadow"
            >
              {/* Image */}
              <div className="h-36 bg-gray-50 relative">
                <img
                  src={activityLogoUrl(cat.name)}
                  alt={cat.name}
                  className="w-full h-full object-contain p-4"
                />
                {/* Active badge */}
                <span
                  className={`absolute top-2 right-2 text-xs font-medium px-2 py-0.5 rounded-full ${
                    cat.isActive
                      ? 'bg-emerald-100 text-emerald-700'
                      : 'bg-gray-100 text-gray-500'
                  }`}
                >
                  {cat.isActive ? 'Active' : 'Inactive'}
                </span>
              </div>

              {/* Body */}
              <div className="p-4">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <h3 className="font-semibold text-gray-900 text-sm">{cat.name}</h3>
                    {cat.type && (
                      <span className="inline-block mt-1 text-[10px] font-medium px-2 py-0.5 rounded-full bg-blue-50 text-blue-700">
                        {CATEGORY_TYPE_LABELS[cat.type] ?? cat.type}
                      </span>
                    )}
                    {cat.description && (
                      <p className="text-xs text-gray-500 mt-0.5 line-clamp-2">
                        {cat.description}
                      </p>
                    )}
                  </div>
                  <span className="text-xs text-gray-400 shrink-0">
                    #{cat.order}
                  </span>
                </div>

                {/* Actions */}
                <div className="flex items-center gap-1 mt-3 pt-3 border-t border-gray-50">
                  <button
                    onClick={() => {
                      setEditItem(cat);
                      setFormOpen(true);
                    }}
                    className="flex-1 flex items-center justify-center gap-1.5 text-xs text-gray-500 hover:text-primary-600 py-1.5 rounded-lg hover:bg-primary-50 transition-colors"
                  >
                    <Pencil size={12} /> Edit
                  </button>
                  <button
                    onClick={() =>
                      toggleMutation.mutate({ id: cat.id, isActive: cat.isActive })
                    }
                    disabled={toggleMutation.isPending}
                    className="flex-1 flex items-center justify-center gap-1.5 text-xs text-gray-500 hover:text-amber-600 py-1.5 rounded-lg hover:bg-amber-50 transition-colors"
                  >
                    {cat.isActive ? (
                      <ToggleRight size={12} />
                    ) : (
                      <ToggleLeft size={12} />
                    )}
                    {cat.isActive ? 'Disable' : 'Enable'}
                  </button>
                  <button
                    onClick={() => setDeleteId(cat.id)}
                    className="flex-1 flex items-center justify-center gap-1.5 text-xs text-gray-500 hover:text-red-600 py-1.5 rounded-lg hover:bg-red-50 transition-colors"
                  >
                    <Trash2 size={12} /> Delete
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
        <div className="space-y-2 sm:hidden">
          {categories.map((cat) => (
            <div key={cat.id} className="bg-white rounded-lg border border-gray-100 p-3">
              <div className="flex gap-3">
                <div className="relative h-16 w-16 shrink-0 rounded-lg bg-gray-50">
                  <img src={activityLogoUrl(cat.name)} alt={cat.name} className="h-full w-full object-contain p-2" />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-2">
                    <h3 className="break-words text-sm font-semibold text-gray-900">{cat.name}</h3>
                    <span className={`shrink-0 rounded-full px-2 py-0.5 text-[10px] font-medium ${cat.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-500'}`}>
                      {cat.isActive ? 'Active' : 'Inactive'}
                    </span>
                  </div>
                  <div className="mt-1 flex items-center gap-2">
                    {cat.type && <span className="rounded-full bg-blue-50 px-2 py-0.5 text-[10px] font-medium text-blue-700">{CATEGORY_TYPE_LABELS[cat.type] ?? cat.type}</span>}
                    <span className="text-[10px] text-gray-400">#{cat.order}</span>
                  </div>
                  {cat.description && <p className="mt-1 line-clamp-1 text-xs text-gray-500">{cat.description}</p>}
                </div>
              </div>
              <div className="mt-3 grid grid-cols-3 gap-1 border-t border-gray-100 pt-2">
                <button type="button" onClick={() => { setEditItem(cat); setFormOpen(true); }}
                  className="flex h-9 items-center justify-center gap-1.5 rounded-md text-xs text-gray-600 hover:bg-primary-50 hover:text-primary-700">
                  <Pencil size={13} /> Edit
                </button>
                <button type="button" onClick={() => toggleMutation.mutate({ id: cat.id, isActive: cat.isActive })}
                  disabled={toggleMutation.isPending}
                  className="flex h-9 items-center justify-center gap-1.5 rounded-md text-xs text-gray-600 hover:bg-amber-50 hover:text-amber-700 disabled:opacity-50">
                  {cat.isActive ? <ToggleRight size={13} /> : <ToggleLeft size={13} />}
                  {cat.isActive ? 'Disable' : 'Enable'}
                </button>
                <button type="button" onClick={() => setDeleteId(cat.id)}
                  className="flex h-9 items-center justify-center gap-1.5 rounded-md text-xs text-gray-600 hover:bg-red-50 hover:text-red-600">
                  <Trash2 size={13} /> Delete
                </button>
              </div>
            </div>
          ))}
        </div>
        {total > limit && <div className="mt-4 overflow-hidden rounded-lg border border-gray-100 bg-white"><Pagination page={page} limit={limit} total={total} onPageChange={setPage} /></div>}
        </>
      )}

      {/* Form modal */}
      <CategoryForm
        open={formOpen}
        onClose={() => { setFormOpen(false); setEditItem(null); }}
        onSubmit={handleFormSubmit}
        initial={editItem}
      />

      {/* Confirm delete */}
      <ConfirmDialog
        open={!!deleteId}
        title="Delete Category"
        message="Are you sure you want to delete this category? This action cannot be undone."
        confirmLabel="Delete"
        variant="danger"
        onConfirm={() => deleteId && deleteMutation.mutate(deleteId)}
        onCancel={() => setDeleteId(null)}
      />
    </div>
  );
};
