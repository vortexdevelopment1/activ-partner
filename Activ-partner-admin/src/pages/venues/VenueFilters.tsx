import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { Search, RotateCcw } from 'lucide-react';
import { categoriesApi } from '../../api/categories.api';
import type { Category } from '../../types';

export interface VenueFilterValues {
  search: string;
  categoryId: string;
  city: string;
  state: string;
  sort: 'newest' | 'oldest' | 'updated';
}

export const defaultVenueFilters: VenueFilterValues = {
  search: '', categoryId: '', city: '', state: '', sort: 'newest',
};

export const VenueFilters: React.FC<{
  value: VenueFilterValues;
  onChange: (value: VenueFilterValues) => void;
  onReset: () => void;
}> = ({ value, onChange, onReset }) => {
  const { data, isError } = useQuery({
    queryKey: ['venue-filter-categories'],
    queryFn: () => categoriesApi.getAllActive(),
  });
  const categories: Category[] = data?.data?.data ?? [];
  const set = (key: keyof VenueFilterValues, next: string) => onChange({ ...value, [key]: next });

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-[minmax(180px,1.5fr)_repeat(4,minmax(120px,1fr))_36px] gap-3 px-5 py-4 border-b border-gray-100">
      <label className="relative min-w-0">
        <span className="sr-only">Search venues</span>
        <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input className="input pl-9 w-full" placeholder="Search venues..." value={value.search} onChange={(e) => set('search', e.target.value)} />
      </label>
      <select aria-label="Category" className="input w-full min-w-0" value={value.categoryId} onChange={(e) => set('categoryId', e.target.value)}>
        <option value="">{isError ? 'Categories unavailable' : 'All categories'}</option>
        {categories.map((category) => <option key={category.id} value={category.id}>{category.name}</option>)}
      </select>
      <input aria-label="City" className="input w-full min-w-0" placeholder="City" value={value.city} onChange={(e) => set('city', e.target.value)} />
      <input aria-label="State" className="input w-full min-w-0" placeholder="State" value={value.state} onChange={(e) => set('state', e.target.value)} />
      <select aria-label="Sort venues" className="input w-full min-w-0" value={value.sort} onChange={(e) => set('sort', e.target.value)}>
        <option value="newest">Newest first</option>
        <option value="oldest">Oldest first</option>
        <option value="updated">Recently updated</option>
      </select>
      <button type="button" onClick={onReset} title="Reset filters" aria-label="Reset filters" className="h-9 w-9 flex items-center justify-center rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50">
        <RotateCcw size={16} />
      </button>
    </div>
  );
};
