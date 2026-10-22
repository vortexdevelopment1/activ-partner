import React, { useEffect, useId } from 'react';
import { useForm } from 'react-hook-form';
import { Modal } from '../../components/ui/Modal';
import { SelectMenu } from '../../components/ui/SelectMenu';
import { ImageUpload } from '../../components/common/ImageUpload';
import type { Category, CategoryType } from '../../types';

const CATEGORY_TYPES: { value: CategoryType; label: string }[] = [
  { value: 'single_booking', label: 'Single Booking' },
  { value: 'court_booking', label: 'Court Booking' },
  { value: 'turf_booking', label: 'Turf Booking' },
  { value: 'table_booking', label: 'Table Booking' },
  { value: 'cricket_nets_booking', label: 'Cricket Nets Booking' },
];

interface CategoryFormData {
  name: string;
  description: string;
  icon: string;
  type: CategoryType | '';
  order: number;
  isActive: boolean;
}

interface CategoryFormProps {
  open: boolean;
  onClose: () => void;
  onSubmit: (data: CategoryFormData, imageFile: File | null) => Promise<void>;
  initial?: Category | null;
}

export const CategoryForm: React.FC<CategoryFormProps> = ({
  open,
  onClose,
  onSubmit,
  initial,
}) => {
  const formId = useId();
  const [imageFile, setImageFile] = React.useState<File | null>(null);
  const [imagePreview, setImagePreview] = React.useState<string | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<CategoryFormData>();

  useEffect(() => {
    if (open) {
      reset({
        name: initial?.name ?? '',
        description: initial?.description ?? '',
        icon: initial?.icon ?? '',
        type: initial?.type ?? '',
        order: initial?.order ?? 0,
        isActive: initial?.isActive ?? true,
      });
      setImageFile(null);
      setImagePreview(initial?.imageUrl ?? null);
    }
  }, [open, initial, reset]);

  const handleFormSubmit = async (data: CategoryFormData) => {
    await onSubmit(data, imageFile);
  };

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={initial ? 'Edit Category' : 'Add Category'}
      size="md"
      footer={<div className="flex flex-wrap justify-end gap-3">
        <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
        <button type="submit" form={formId} disabled={isSubmitting} className="btn-primary">
          {isSubmitting ? 'Saving...' : initial ? 'Save Changes' : 'Add Category'}
        </button>
      </div>}
    >
      <form id={formId} onSubmit={handleSubmit(handleFormSubmit)} className="space-y-4">
        {/* Name */}
        <div>
          <label className="label">Name *</label>
          <input
            className={`input ${errors.name ? 'border-red-400' : ''}`}
            placeholder="e.g. Swimming Pool"
            {...register('name', { required: 'Name is required' })}
          />
          {errors.name && (
            <p className="mt-1 text-xs text-red-500">{errors.name.message}</p>
          )}
        </div>

        {/* Description */}
        <div>
          <label className="label">Description</label>
          <textarea
            rows={3}
            className="input resize-none"
            placeholder="Brief description of this category"
            {...register('description')}
          />
        </div>

        {/* Type */}
        <div>
          <label className="label">Type *</label>
          <input type="hidden" {...register('type', { required: 'Type is required' })} />
          <SelectMenu value={watch('type') ?? ''} options={CATEGORY_TYPES}
            ariaLabel="Category type" placeholder="Select a type"
            onChange={value => setValue('type', value as CategoryType, { shouldDirty: true, shouldValidate: true })} />
          {errors.type && (
            <p className="mt-1 text-xs text-red-500">{errors.type.message}</p>
          )}
        </div>

        {/* Image */}
        <div>
          <ImageUpload
            label="Category Image"
            value={imagePreview ?? undefined}
            onChange={(file, preview) => {
              setImageFile(file);
              setImagePreview(preview);
            }}
          />
        </div>

        {/* Icon + Order row */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="label">Icon (emoji or name)</label>
            <input
              className="input"
              placeholder="🏊 or swimming"
              {...register('icon')}
            />
          </div>
          <div>
            <label className="label">Display Order</label>
            <input
              type="number"
              className="input"
              {...register('order', { valueAsNumber: true })}
            />
          </div>
        </div>

        {/* Active toggle */}
        <div className="flex items-center gap-3">
          <input
            id="cat-active"
            type="checkbox"
            className="w-4 h-4 rounded text-primary-600 border-gray-300 focus:ring-primary-500"
            {...register('isActive')}
          />
          <label htmlFor="cat-active" className="text-sm text-gray-700">
            Active (visible to users)
          </label>
        </div>

      </form>
    </Modal>
  );
};
