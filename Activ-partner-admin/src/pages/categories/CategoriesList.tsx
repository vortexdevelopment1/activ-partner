import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Pencil, Trash2, ToggleLeft, ToggleRight } from 'lucide-react';
import { categoriesApi } from '../../api/categories.api';
import { CategoryForm } from './CategoryForm';
import { ConfirmDialog } from '../../components/common/ConfirmDialog';
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
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  const [formOpen, setFormOpen] = useState(false);
  const [editItem, setEditItem] = useState<Category | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['categories'],
    queryFn: () => categoriesApi.getAll({ limit: 100 }),
  });

  const categories: Category[] = data?.data?.data?.items ?? [];

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
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) => {
      const fd = new FormData();
      fd.append('isActive', String(!isActive));
      return categoriesApi.update(id, fd);
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['categories'] }),
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed'),
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
      <div className="flex items-center justify-between">
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

      {/* Grid */}
      {isLoading ? (
        <div className="text-center py-20 text-gray-400">Loading...</div>
      ) : categories.length === 0 ? (
        <div className="text-center py-20 text-gray-400">
          No categories yet. Add your first one!
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {categories.map((cat) => (
            <div
              key={cat.id}
              className="bg-white rounded-xl border border-gray-100 overflow-hidden hover:shadow-sm transition-shadow"
            >
              {/* Image */}
              <div className="h-36 bg-gray-50 relative">
                {cat.imageUrl ? (
                  <img
                    src={cat.imageUrl}
                    alt={cat.name}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-4xl">
                    {cat.icon ?? '🏷️'}
                  </div>
                )}
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
