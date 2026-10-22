import React, { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Pencil, Trash2, GripVertical, ChevronUp, ChevronDown, Search } from 'lucide-react';
import { questionsApi } from '../../api/questions.api';
import { SelectMenu } from '../../components/ui/SelectMenu';
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
  const [searchParams, setSearchParams] = useSearchParams();
  const search = searchParams.get('search') ?? '';
  const categoryParam = searchParams.get('categoryId') ?? '';
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  const [formOpen, setFormOpen] = useState(false);
  const [editItem, setEditItem] = useState<Question | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [filterCat, setFilterCat] = useState(categoryParam);

  useEffect(() => { setFilterCat(categoryParam); }, [categoryParam]);
  const [orderedQuestions, setOrderedQuestions] = useState<Question[]>([]);
  const [draggingId, setDraggingId] = useState<string | null>(null);
  const [dropTargetId, setDropTargetId] = useState<string | null>(null);

  const { data: questionsData, isLoading, isError, refetch } = useQuery({
    queryKey: ['questions'],
    queryFn: async (): Promise<Question[]> => {
      const items: Question[] = [];
      let page = 1;
      let total = 0;
      do {
        const response = await questionsApi.getAll({ page, limit: 200 });
        const batch: Question[] = response.data.data.items;
        total = response.data.data.total;
        items.push(...batch);
        if (batch.length === 0) break;
        page += 1;
      } while (items.length < total);
      return items;
    },
  });

  useEffect(() => {
    if (questionsData) setOrderedQuestions(questionsData);
  }, [questionsData]);

  const { data: categoriesData } = useQuery({
    queryKey: ['categories'],
    queryFn: () => categoriesApi.getAll({ limit: 100 }),
  });

  const allQuestions = orderedQuestions.length ? orderedQuestions : questionsData ?? [];
  const questions: Question[] =
    filterCat === ''
      ? allQuestions
      : filterCat === 'global'
      ? allQuestions.filter((q) => !q.categoryId)
      : allQuestions.filter((q) => q.categoryId === filterCat);
  const visibleQuestions = questions.filter((q) => q.questionText.toLowerCase().includes(search.toLowerCase()));
  const categories = categoriesData?.data?.data?.items ?? [];

  const reorderMutation = useMutation({
    mutationFn: (items: Question[]) =>
      questionsApi.reorder(items.map((q, order) => ({ id: q.id, order }))),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['questions'] });
      success('Question order saved');
    },
    onError: (err: any, _items, previous) => {
      if (previous) setOrderedQuestions(previous);
      queryClient.invalidateQueries({ queryKey: ['questions'] });
      error(err?.response?.data?.message ?? 'Could not save question order');
    },
    onMutate: () => allQuestions,
  });

  const moveQuestion = (sourceId: string, targetId: string) => {
    if (reorderMutation.isPending || sourceId === targetId) return;
    const visible = [...visibleQuestions];
    const sourceIndex = visible.findIndex((q) => q.id === sourceId);
    const targetIndex = visible.findIndex((q) => q.id === targetId);
    if (sourceIndex < 0 || targetIndex < 0) return;
    [visible[sourceIndex], visible[targetIndex]] = [visible[targetIndex], visible[sourceIndex]];

    const moved = visible[Symbol.iterator]();
    const next = allQuestions.map((q, index) => {
      const inCategory = filterCat === '' ||
        (filterCat === 'global' ? !q.categoryId : q.categoryId === filterCat);
      const inFilter = inCategory && q.questionText.toLowerCase().includes(search.toLowerCase());
      return { ...(inFilter ? moved.next().value! : q), order: index };
    });
    setOrderedQuestions(next);
    reorderMutation.mutate(next);
  };

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
        <div className="flex w-full flex-wrap items-center gap-3 sm:w-auto">
          <label className="relative w-full sm:w-44">
            <span className="sr-only">Search questions</span>
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input className="input pl-9" value={search} placeholder="Search questions..."
              onChange={(event) => setSearchParams({ ...(event.target.value ? { search: event.target.value } : {}), ...(filterCat ? { categoryId: filterCat } : {}) }, { replace: true })} />
          </label>
          <SelectMenu
            value={filterCat}
            onChange={(value) => {
              setFilterCat(value);
              setSearchParams({ ...(search ? { search } : {}), ...(value ? { categoryId: value } : {}) }, { replace: true });
            }}
            className="w-full sm:w-48" ariaLabel="Filter questions by category" placeholder="All categories"
            options={[{ value: '', label: 'All categories' }, { value: 'global', label: 'Global only' },
              ...categories.map((cat: any) => ({ value: cat.id, label: cat.name }))]}
          />
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
        ) : isError ? (
          <div className="text-center py-16 text-sm text-gray-500">
            <p>Could not load questions.</p>
            <button type="button" onClick={() => refetch()} className="mt-3 text-primary-600 hover:underline">Try again</button>
          </div>
        ) : visibleQuestions.length === 0 ? (
          <div className="text-center py-20 text-gray-400">No questions found.</div>
        ) : (
          <div className="overflow-x-auto" role="region" aria-label="Scrollable table" tabIndex={0}><table className="w-full text-sm">
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
              {visibleQuestions.map((q, index) => (
                <tr key={q.id}
                  className={`border-b border-gray-50 hover:bg-gray-50/50 ${draggingId === q.id ? 'opacity-50' : ''} ${dropTargetId === q.id ? 'bg-primary-50' : ''}`}
                  onDragOver={(event) => {
                    if (!draggingId || draggingId === q.id) return;
                    event.preventDefault();
                    event.dataTransfer.dropEffect = 'move';
                    if (dropTargetId !== q.id) setDropTargetId(q.id);
                  }}
                  onDragLeave={() => { if (dropTargetId === q.id) setDropTargetId(null); }}
                  onDrop={(event) => {
                    event.preventDefault();
                    const sourceId = event.dataTransfer.getData('text/plain') || draggingId;
                    setDraggingId(null);
                    setDropTargetId(null);
                    if (sourceId) moveQuestion(sourceId, q.id);
                  }}>
                  <td className="px-4 py-3 text-gray-300">
                    <button type="button" draggable={!reorderMutation.isPending}
                      aria-label={`Reorder ${q.questionText}`}
                      title="Drag onto another question to swap positions; use arrow keys to move"
                      disabled={reorderMutation.isPending}
                      className="hidden sm:inline-flex cursor-grab rounded p-1 hover:bg-gray-100 hover:text-primary-600 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary-600 active:cursor-grabbing disabled:cursor-not-allowed"
                      onDragStart={(event) => {
                        event.dataTransfer.setData('text/plain', q.id);
                        event.dataTransfer.effectAllowed = 'move';
                        setDraggingId(q.id);
                      }}
                      onDragEnd={() => { setDraggingId(null); setDropTargetId(null); }}
                      onKeyDown={(event) => {
                        if (event.key === 'ArrowUp' && index > 0) {
                          event.preventDefault();
                          moveQuestion(q.id, visibleQuestions[index - 1].id);
                        } else if (event.key === 'ArrowDown' && index < visibleQuestions.length - 1) {
                          event.preventDefault();
                          moveQuestion(q.id, visibleQuestions[index + 1].id);
                        }
                      }}>
                      <GripVertical size={14} />
                    </button>
                    <div className="flex sm:hidden flex-col">
                      <button type="button" aria-label={`Move ${q.questionText} up`}
                        disabled={index === 0 || reorderMutation.isPending}
                        onClick={() => moveQuestion(q.id, visibleQuestions[index - 1].id)}
                        className="p-1 text-gray-500 disabled:opacity-30"><ChevronUp size={16} /></button>
                      <button type="button" aria-label={`Move ${q.questionText} down`}
                        disabled={index === visibleQuestions.length - 1 || reorderMutation.isPending}
                        onClick={() => moveQuestion(q.id, visibleQuestions[index + 1].id)}
                        className="p-1 text-gray-500 disabled:opacity-30"><ChevronDown size={16} /></button>
                    </div>
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
          </table></div>
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
