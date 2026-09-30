import React, { useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { Modal } from '../../components/ui/Modal';
import type { FAQ } from '../../types';

interface Props {
  open: boolean;
  initial: FAQ | null;
  loading: boolean;
  onSubmit: (data: FormValues) => void;
  onClose: () => void;
}

interface FormValues {
  question: string;
  answer: string;
  isActive: boolean;
}

export const FAQForm: React.FC<Props> = ({ open, initial, loading, onSubmit, onClose }) => {
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<FormValues>({
    defaultValues: { question: '', answer: '', isActive: true },
  });

  useEffect(() => {
    if (open) {
      reset(
        initial
          ? { question: initial.question, answer: initial.answer, isActive: initial.isActive }
          : { question: '', answer: '', isActive: true },
      );
    }
  }, [open, initial, reset]);

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={initial ? 'Edit FAQ' : 'Add FAQ'}
      size="md"
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        {/* Question */}
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">
            Question <span className="text-red-500">*</span>
          </label>
          <input
            {...register('question', { required: 'Question is required' })}
            placeholder="e.g. How do I book a venue?"
            className="input w-full"
          />
          {errors.question && (
            <p className="text-xs text-red-500 mt-1">{errors.question.message}</p>
          )}
        </div>

        {/* Answer */}
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">
            Answer <span className="text-red-500">*</span>
          </label>
          <textarea
            {...register('answer', { required: 'Answer is required' })}
            placeholder="Enter the answer..."
            rows={5}
            className="input w-full resize-y"
          />
          {errors.answer && (
            <p className="text-xs text-red-500 mt-1">{errors.answer.message}</p>
          )}
        </div>

        {/* Active toggle */}
        <div className="flex items-center gap-2">
          <input
            type="checkbox"
            id="faq-active"
            {...register('isActive')}
            className="w-4 h-4 accent-primary-600"
          />
          <label htmlFor="faq-active" className="text-sm text-gray-700">
            Active (visible to users)
          </label>
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
