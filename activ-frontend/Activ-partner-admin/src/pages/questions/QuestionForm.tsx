import React, { useEffect } from 'react';
import { useForm, useFieldArray } from 'react-hook-form';
import { Plus, Trash2 } from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import { Modal } from '../../components/ui/Modal';
import { categoriesApi } from '../../api/categories.api';
import type { Question } from '../../types';

const QUESTION_TYPES = [
  { value: 'text', label: 'Text' },
  { value: 'textarea', label: 'Text Area' },
  { value: 'number', label: 'Number' },
  { value: 'select', label: 'Dropdown (single)' },
  { value: 'multiselect', label: 'Dropdown (multi)' },
  { value: 'radio', label: 'Radio buttons' },
  { value: 'checkbox', label: 'Checkboxes' },
  { value: 'file', label: 'File Upload' },
  { value: 'date', label: 'Date' },
] as const;

const OPTION_TYPES = ['select', 'multiselect', 'radio', 'checkbox'];

interface QuestionFormData {
  questionText: string;
  questionType: string;
  categoryId: string;
  isRequired: boolean;
  isActive: boolean;
  order: number;
  placeholder: string;
  helperText: string;
  options: { value: string }[];
  minLength: number | null;
  maxLength: number | null;
}

interface QuestionFormProps {
  open: boolean;
  onClose: () => void;
  onSubmit: (data: QuestionFormData) => Promise<void>;
  initial?: Question | null;
}

export const QuestionForm: React.FC<QuestionFormProps> = ({
  open,
  onClose,
  onSubmit,
  initial,
}) => {
  const { data: categoriesData } = useQuery({
    queryKey: ['categories'],
    queryFn: () => categoriesApi.getAll({ limit: 100 }),
  });

  const categories = categoriesData?.data?.data?.items ?? [];

  const {
    register,
    handleSubmit,
    reset,
    watch,
    control,
    formState: { errors, isSubmitting },
  } = useForm<QuestionFormData>({
    defaultValues: { options: [], isActive: true, isRequired: false, order: 0 },
  });

  const { fields, append, remove } = useFieldArray({ control, name: 'options' });
  const questionType = watch('questionType');
  const needsOptions = OPTION_TYPES.includes(questionType);
  const hasLengthLimit = ['text', 'textarea', 'number'].includes(questionType);

  useEffect(() => {
    if (open) {
      // API stores options as string[] — map each string to { value }
      const initialOptions = Array.isArray(initial?.options)
        ? (initial.options as unknown as string[]).map((s) => ({ value: String(s) }))
        : [];
      reset({
        questionText: initial?.questionText ?? '',
        questionType: initial?.questionType ?? 'text',
        categoryId: initial?.categoryId ?? '',
        isRequired: initial?.isRequired ?? false,
        isActive: initial?.isActive ?? true,
        order: initial?.order ?? 0,
        placeholder: initial?.placeholder ?? '',
        helperText: initial?.helperText ?? '',
        options: initialOptions,
        minLength: initial?.minLength ?? null,
        maxLength: initial?.maxLength ?? null,
      });
    }
  }, [open, initial, reset]);

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={initial ? 'Edit Question' : 'Add Question'}
      size="lg"
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        {/* Question text */}
        <div>
          <label className="label">Question Text *</label>
          <input
            className={`input ${errors.questionText ? 'border-red-400' : ''}`}
            placeholder="e.g. What is your gym capacity?"
            {...register('questionText', { required: 'Question text is required' })}
          />
          {errors.questionText && (
            <p className="mt-1 text-xs text-red-500">{errors.questionText.message}</p>
          )}
        </div>

        {/* Type + Category */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="label">Question Type *</label>
            <select className="input" {...register('questionType', { required: true })}>
              {QUESTION_TYPES.map((t) => (
                <option key={t.value} value={t.value}>
                  {t.label}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="label">Category</label>
            <select className="input" {...register('categoryId')}>
              <option value="">Global (all categories)</option>
              {categories.map((cat: any) => (
                <option key={cat.id} value={cat.id}>
                  {cat.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Placeholder + Helper */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="label">Placeholder</label>
            <input className="input" placeholder="Input placeholder" {...register('placeholder')} />
          </div>
          <div>
            <label className="label">Helper Text</label>
            <input className="input" placeholder="Hint shown below field" {...register('helperText')} />
          </div>
        </div>

        {/* Length limits (for text / textarea / number) */}
        {hasLengthLimit && (
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="label">Min Length / Value</label>
              <input
                type="number"
                className={`input ${errors.minLength ? 'border-red-400' : ''}`}
                placeholder="e.g. 1"
                {...register('minLength', {
                  setValueAs: (v) => (v === '' || v === null ? null : Number(v)),
                  validate: (val, formValues) => {
                    if (val === null || val === undefined) return true;
                    if (val < 0) return 'Must be ≥ 0';
                    const max = formValues.maxLength;
                    if (max !== null && max !== undefined && val > max)
                      return 'Min must be ≤ Max';
                    return true;
                  },
                })}
              />
              {errors.minLength && (
                <p className="mt-1 text-xs text-red-500">{errors.minLength.message}</p>
              )}
            </div>
            <div>
              <label className="label">Max Length / Value</label>
              <input
                type="number"
                className={`input ${errors.maxLength ? 'border-red-400' : ''}`}
                placeholder="e.g. 500"
                {...register('maxLength', {
                  setValueAs: (v) => (v === '' || v === null ? null : Number(v)),
                  validate: (val, formValues) => {
                    if (val === null || val === undefined) return true;
                    if (val < 0) return 'Must be ≥ 0';
                    const min = formValues.minLength;
                    if (min !== null && min !== undefined && val < min)
                      return 'Max must be ≥ Min';
                    return true;
                  },
                })}
              />
              {errors.maxLength && (
                <p className="mt-1 text-xs text-red-500">{errors.maxLength.message}</p>
              )}
            </div>
          </div>
        )}

        {/* Options (for select / radio / checkbox) */}
        {needsOptions && (
          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="label mb-0">
                Options *
                <span className="text-xs font-normal text-gray-400 ml-1">(each option is a string)</span>
              </label>
              <button
                type="button"
                onClick={() => append({ value: '' })}
                className="text-xs text-primary-600 font-medium flex items-center gap-1 hover:underline"
              >
                <Plus size={12} /> Add option
              </button>
            </div>
            <div className="space-y-2">
              {fields.map((field, idx) => (
                <div key={field.id} className="flex gap-2">
                  <input
                    className="input flex-1"
                    placeholder={`Option ${idx + 1}`}
                    {...register(`options.${idx}.value`, { required: true })}
                  />
                  <button
                    type="button"
                    onClick={() => remove(idx)}
                    className="p-2 text-red-400 hover:text-red-600"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              ))}
              {fields.length === 0 && (
                <p className="text-xs text-red-400">At least one option is required for this question type.</p>
              )}
            </div>
          </div>
        )}

        {/* Order + Flags */}
        <div className="flex items-center gap-6 flex-wrap">
          <div className="w-28">
            <label className="label">Order</label>
            <input
              type="number"
              className="input"
              {...register('order', { valueAsNumber: true })}
            />
          </div>
          <div className="flex items-center gap-2 mt-5">
            <input
              id="q-required"
              type="checkbox"
              className="w-4 h-4 rounded text-primary-600 border-gray-300"
              {...register('isRequired')}
            />
            <label htmlFor="q-required" className="text-sm text-gray-700">Required</label>
          </div>
          <div className="flex items-center gap-2 mt-5">
            <input
              id="q-active"
              type="checkbox"
              className="w-4 h-4 rounded text-primary-600 border-gray-300"
              {...register('isActive')}
            />
            <label htmlFor="q-active" className="text-sm text-gray-700">Active</label>
          </div>
        </div>

        {/* Actions */}
        <div className="flex justify-end gap-3 pt-2">
          <button type="button" onClick={onClose} className="btn-secondary">
            Cancel
          </button>
          <button type="submit" disabled={isSubmitting} className="btn-primary">
            {isSubmitting ? 'Saving...' : initial ? 'Save Changes' : 'Add Question'}
          </button>
        </div>
      </form>
    </Modal>
  );
};
