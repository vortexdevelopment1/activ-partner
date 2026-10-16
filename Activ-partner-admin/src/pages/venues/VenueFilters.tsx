import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Search, RotateCcw, SlidersHorizontal, X } from 'lucide-react';
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
  const [mobileOpen, setMobileOpen] = useState(false);
  const { data, isError } = useQuery({
    queryKey: ['venue-filter-categories'],
    queryFn: () => categoriesApi.getAllActive(),
  });
  const categories: Category[] = data?.data?.data ?? [];
  const set = (key: keyof VenueFilterValues, next: string) => onChange({ ...value, [key]: next });
  const activeFilterCount = [value.categoryId, value.city, value.state, value.sort !== 'newest' ? value.sort : '']
    .filter(Boolean).length;

  return (
    <>
      <div className="border-b border-gray-100 p-3 md:hidden">
        <div className="flex gap-2">
          <label className="relative min-w-0 flex-1">
            <span className="sr-only">Search venues</span>
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input className="input pl-9" placeholder="Search venues..." value={value.search} onChange={(e) => set('search', e.target.value)} />
          </label>
          <button type="button" onClick={() => setMobileOpen((current) => !current)}
            aria-expanded={mobileOpen} aria-label="Venue filters"
            className={`relative flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border ${mobileOpen ? 'border-primary-300 bg-primary-50 text-primary-700' : 'border-gray-200 text-gray-600'}`}>
            {mobileOpen ? <X size={16} /> : <SlidersHorizontal size={16} />}
            {!mobileOpen && activeFilterCount > 0 && <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-primary-600 px-1 text-[10px] text-white">{activeFilterCount}</span>}
          </button>
        </div>
        {mobileOpen && (
          <div className="mt-3 grid grid-cols-2 gap-2">
            <select aria-label="Category" className="input col-span-2" value={value.categoryId} onChange={(e) => set('categoryId', e.target.value)}>
              <option value="">{isError ? 'Categories unavailable' : 'All categories'}</option>
              {categories.map((category) => <option key={category.id} value={category.id}>{category.name}</option>)}
            </select>
            <input aria-label="City" className="input min-w-0" placeholder="City" value={value.city} onChange={(e) => set('city', e.target.value)} />
            <input aria-label="State" className="input min-w-0" placeholder="State" value={value.state} onChange={(e) => set('state', e.target.value)} />
            <select aria-label="Sort venues" className="input col-span-2" value={value.sort} onChange={(e) => set('sort', e.target.value)}>
              <option value="newest">Newest first</option>
              <option value="oldest">Oldest first</option>
              <option value="updated">Recently updated</option>
            </select>
            <button type="button" onClick={() => { onReset(); setMobileOpen(false); }} className="btn-secondary col-span-2 flex items-center justify-center gap-2 text-sm">
              <RotateCcw size={15} /> Reset filters
            </button>
          </div>
        )}
      </div>
      <div className="hidden md:grid md:grid-cols-2 xl:grid-cols-[minmax(180px,1.5fr)_repeat(4,minmax(120px,1fr))_36px] gap-3 px-5 py-4 border-b border-gray-100">
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
    </>
  );
};
