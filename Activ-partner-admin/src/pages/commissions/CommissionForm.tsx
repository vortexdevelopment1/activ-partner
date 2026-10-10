import React, { useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { Modal } from '../../components/ui/Modal';
import type { Commission } from '../../types';

interface Props {
  open: boolean;
  initial: Commission | null;
  loading: boolean;
  onSubmit: (data: { city: string; commissionPercentage: number }) => void;
  onClose: () => void;
}

interface FormValues {
  city: string;
  commissionPercentage: number;
}

export const CommissionForm: React.FC<Props> = ({ open, initial, loading, onSubmit, onClose }) => {
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<FormValues>({
    defaultValues: { city: '', commissionPercentage: 0 },
  });

  useEffect(() => {
    if (open) {
      reset(
        initial
          ? { city: initial.city, commissionPercentage: initial.commissionPercentage }
          : { city: '', commissionPercentage: 0 },
      );
    }
  }, [open, initial, reset]);

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={initial ? 'Edit Commission' : 'Add Commission'}
      size="sm"
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        {/* City */}
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">
            City <span className="text-red-500">*</span>
          </label>
          <input
            {...register('city', { required: 'City is required' })}
            placeholder="e.g. Mumbai"
            className="input w-full"
          />
          {errors.city && (
            <p className="text-xs text-red-500 mt-1">{errors.city.message}</p>
          )}
        </div>

        {/* Commission % */}
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">
            Commission Percentage (%) <span className="text-red-500">*</span>
          </label>
          <input
            type="number"
            step="0.01"
            min="0"
            max="100"
            {...register('commissionPercentage', {
              required: 'Commission percentage is required',
              valueAsNumber: true,
              min: { value: 0, message: 'Must be at least 0%' },
              max: { value: 100, message: 'Cannot exceed 100%' },
            })}
            placeholder="e.g. 18"
            className="input w-full"
          />
          {errors.commissionPercentage && (
            <p className="text-xs text-red-500 mt-1">{errors.commissionPercentage.message}</p>
          )}
        </div>

        {/* Actions */}
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={onClose} className="btn-secondary">
            Cancel
          </button>
          <button type="submit" disabled={loading} className="btn-primary">
            {loading ? 'Saving...' : initial ? 'Update' : 'Create'}
          </button>
        </div>
      </form>
    </Modal>
  );
};
