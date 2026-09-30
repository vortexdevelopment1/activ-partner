import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Pencil, Trash2, GripVertical } from 'lucide-react';
import { questionsApi } from '../../api/questions.api';
import { categoriesApi } from '../../api/categories.api';
import { QuestionForm } from './QuestionForm';
import { ConfirmDialog } from '../../components/common/ConfirmDialog';
import { useToast } from '../../hooks/useToast';
import type { Question } from '../../types';

const TYPE_LABELS: Record<string, string> = {
  text: 'Text',
  textarea: 'Text Area',
  number: 'Number',
  select: 'Dropdown',
  multiselect: 'Multi-select',
  radio: 'Radio',
  checkbox: 'Checkbox',
  file: 'File',
  date: 'Date',
};

export const QuestionsList: React.FC = () => {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  const [formOpen, setFormOpen] = useState(false);
  const [editItem, setEditItem] = useState<Question | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [filterCat, setFilterCat] = useState('');

  const { data: questionsData, isLoading } = useQuery({
    queryKey: ['questions'],
    queryFn: () => questionsApi.getAll({ limit: 200 }),
  });

  const { data: categoriesData } = useQuery({
    queryKey: ['categories'],
    queryFn: () => categoriesApi.getAll({ limit: 100 }),
  });

  const allQuestions: Question[] = questionsData?.data?.data?.items ?? [];
  const questions: Question[] =
    filterCat === ''
      ? allQuestions
      : filterCat === 'global'
      ? allQuestions.filter((q) => !q.categoryId)
      : allQuestions.filter((q) => q.categoryId === filterCat);
  const categories = categoriesData?.data?.data?.items ?? [];

  const createMutation = useMutation({
    mutationFn: questionsApi.create,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['questions'] });
      success('Question created');
      setFormOpen(false);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed'),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: any }) =>
      questionsApi.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['questions'] });
      success('Question updated');
      setFormOpen(false);
      setEditItem(null);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed'),
  });

  const deleteMutation = useMutation({
    mutationFn: questionsApi.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['questions'] });
      success('Question deleted');
      setDeleteId(null);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed'),
  });

  const handleFormSubmit = async (data: any) => {
    const payload = {
      questionText: data.questionText,
      questionType: data.questionType,
      categoryId: data.categoryId || null,
      isRequired: data.isRequired,
      isActive: data.isActive,
      order: data.order,
      placeholder: data.placeholder || null,
      helperText: data.helperText || null,
      minLength: data.minLength ?? null,
      maxLength: data.maxLength ?? null,
      // API expects string[] not object[] — extract the value from each option
      options: data.options?.length
        ? data.options.map((o: { value: string }) => o.value).filter(Boolean)
        : null,
    };

    if (editItem) {
      updateMutation.mutate({ id: editItem.id, data: payload });
    } else {
      createMutation.mutate(payload);
    }
  };

  const getCategoryName = (catId: string | null | undefined) => {
    if (!catId) return 'Global';
    const cat = categories.find((c: any) => c.id === catId);
    return cat?.name ?? 'Unknown';
  };

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Questions</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            Questions shown to partners during venue creation
          </p>
        </div>
        <div className="flex items-center gap-3">
          <select
            value={filterCat}
            onChange={(e) => setFilterCat(e.target.value)}
            className="input w-48"
          >
            <option value="">All categories</option>
            <option value="global">Global only</option>
            {categories.map((cat: any) => (
              <option key={cat.id} value={cat.id}>
                {cat.name}
              </option>
            ))}
          </select>
          <button
            onClick={() => { setEditItem(null); setFormOpen(true); }}
            className="btn-primary flex items-center gap-2"
          >
            <Plus size={16} /> Add Question
          </button>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
        {isLoading ? (
          <div className="text-center py-20 text-gray-400">Loading...</div>
        ) : questions.length === 0 ? (
          <div className="text-center py-20 text-gray-400">No questions found.</div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="w-8 px-4 py-3" />
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Question
                </th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Type
                </th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Category
                </th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Required
                </th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Status
                </th>
                <th className="px-4 py-3 w-24" />
              </tr>
            </thead>
            <tbody>
              {questions.map((q) => (
                <tr key={q.id} className="border-b border-gray-50 hover:bg-gray-50/50">
                  <td className="px-4 py-3 text-gray-300">
                    <GripVertical size={14} />
                  </td>
                  <td className="px-4 py-3">
                    <p className="font-medium text-gray-900">{q.questionText}</p>
                    {q.helperText && (
                      <p className="text-xs text-gray-400 mt-0.5">{q.helperText}</p>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full font-medium">
                      {TYPE_LABELS[q.questionType] ?? q.questionType}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-gray-600">
                    {getCategoryName(q.categoryId)}
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                        q.isRequired
                          ? 'bg-red-50 text-red-600'
                          : 'bg-gray-100 text-gray-500'
                      }`}
                    >
                      {q.isRequired ? 'Required' : 'Optional'}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                        q.isActive
                          ? 'bg-emerald-50 text-emerald-600'
                          : 'bg-gray-100 text-gray-500'
                      }`}
                    >
                      {q.isActive ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => { setEditItem(q); setFormOpen(true); }}
                        className="p-1.5 text-gray-400 hover:text-primary-600 hover:bg-primary-50 rounded-lg"
                      >
                        <Pencil size={13} />
                      </button>
                      <button
                        onClick={() => setDeleteId(q.id)}
                        className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg"
                      >
                        <Trash2 size={13} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <QuestionForm
        open={formOpen}
        onClose={() => { setFormOpen(false); setEditItem(null); }}
        onSubmit={handleFormSubmit}
        initial={editItem}
      />

      <ConfirmDialog
        open={!!deleteId}
        title="Delete Question"
        message="Are you sure you want to delete this question? It will also remove any answers stored for it."
        confirmLabel="Delete"
        variant="danger"
        onConfirm={() => deleteId && deleteMutation.mutate(deleteId)}
        onCancel={() => setDeleteId(null)}
      />
    </div>
  );
};
