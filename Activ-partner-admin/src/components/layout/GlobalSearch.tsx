import React, { useEffect, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useLocation, useNavigate } from 'react-router-dom';
import { ArrowUpRight, Loader2, Search, X } from 'lucide-react';
import { adminSearchApi, type AdminSearchGroup, type AdminSearchItem } from '../../api/admin-search.api';
import { navItems } from './Sidebar';

export const GlobalSearch: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const containerRef = useRef<HTMLDivElement>(null);
  const mobileInputRef = useRef<HTMLInputElement>(null);
  const [open, setOpen] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [debounced, setDebounced] = useState('');
  const [activeIndex, setActiveIndex] = useState(0);

  useEffect(() => {
    const timer = window.setTimeout(() => setDebounced(query.trim()), 300);
    return () => window.clearTimeout(timer);
  }, [query]);

  useEffect(() => {
    setOpen(false);
    setMobileOpen(false);
    setQuery('');
  }, [location.pathname, location.search]);

  useEffect(() => {
    if (open && mobileOpen) mobileInputRef.current?.focus();
  }, [open, mobileOpen]);

  useEffect(() => {
    if (!open) return;
    const onOutside = (event: MouseEvent) => {
      if (!containerRef.current?.contains(event.target as Node)) setOpen(false);
    };
    const onEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onOutside);
    document.addEventListener('keydown', onEscape);
    return () => {
      document.removeEventListener('mousedown', onOutside);
      document.removeEventListener('keydown', onEscape);
    };
  }, [open]);

  const { data, isFetching, isError } = useQuery({
    queryKey: ['admin-search', debounced],
    queryFn: () => adminSearchApi.search(debounced).then((response) => response.data.data),
    enabled: open && debounced.length >= 2,
    staleTime: 30_000,
  });

  const term = query.trim().toLowerCase();
  const pageItems: AdminSearchItem[] = navItems
    .filter((item) => term ? item.label.toLowerCase().includes(term) :
      ['/dashboard', '/venues', '/users', '/partners', '/logs'].includes(item.to))
    .map((item) => ({ id: item.to, label: item.label, description: 'Admin page', path: item.to }));
  const groups: AdminSearchGroup[] = [
    ...(pageItems.length ? [{ key: 'pages', title: 'Pages', items: pageItems }] : []),
    ...(debounced.toLowerCase() === term ? data ?? [] : []),
  ];
  const results = groups.flatMap((group) => group.items);

  const select = (item: AdminSearchItem) => {
    setOpen(false);
    setMobileOpen(false);
    setQuery('');
    navigate(item.path);
  };

  const onInputKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      setActiveIndex((index) => Math.min(index + 1, results.length - 1));
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      setActiveIndex((index) => Math.max(0, index - 1));
    } else if (event.key === 'Enter' && results.length) {
      event.preventDefault();
      select(results[Math.max(0, activeIndex)]);
    } else if (event.key === 'Escape') {
      setOpen(false);
    }
  };

  return (
    <div className="relative md:w-full md:max-w-xl xl:max-w-2xl" ref={containerRef}>
      <div className="relative hidden md:block md:w-full">
        <Search size={16} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input type="search" value={query} onChange={(event) => { setQuery(event.target.value); setActiveIndex(0); }}
          onFocus={() => setOpen(true)} onKeyDown={onInputKeyDown}
          aria-label="Search admin panel" aria-expanded={open} aria-controls="admin-search-results"
          placeholder="Search..."
          className="w-full rounded-lg border border-gray-200 bg-[#f7f9f8] py-2.5 pl-10 pr-4 text-sm shadow-[inset_0_1px_1px_rgb(20_35_31/0.02)] focus:border-primary-500 focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary-500/20" />
      </div>
      <button type="button" aria-label="Search admin panel" onClick={() => { setMobileOpen(true); setOpen(true); }}
        className="rounded-lg p-2 text-gray-500 hover:bg-gray-50 md:hidden"><Search size={19} /></button>

      {open && (
        <div id="admin-search-results" className="fixed left-3 right-3 top-16 z-50 overflow-hidden rounded-lg border border-gray-200 bg-white shadow-xl md:absolute md:left-auto md:right-0 md:top-full md:mt-2 md:w-[min(34rem,calc(100vw-2rem))]">
          <div className="flex items-center gap-2 border-b border-gray-100 p-3 md:hidden">
            <Search size={18} className="shrink-0 text-gray-400" />
            <input ref={mobileInputRef} type="search" value={query}
              onChange={(event) => { setQuery(event.target.value); setActiveIndex(0); }}
              onKeyDown={onInputKeyDown} aria-label="Search admin panel" placeholder="Search..."
              className="min-w-0 flex-1 bg-transparent text-sm outline-none" />
            <button type="button" aria-label="Close search" onClick={() => setOpen(false)} className="p-1 text-gray-500"><X size={18} /></button>
          </div>
          <div className="max-h-[min(70dvh,34rem)] overflow-y-auto py-2">
            {groups.map((group) => (
              <div key={group.key} className="pb-1">
                <h3 className="px-4 pb-1 pt-2 text-xs font-semibold uppercase text-gray-400">{group.title}</h3>
                {group.items.map((item) => {
                  const index = results.indexOf(item);
                  return (
                    <button key={`${group.key}-${item.id}`} type="button" onClick={() => select(item)}
                      onMouseEnter={() => setActiveIndex(index)}
                      className={`flex w-full min-w-0 items-center gap-3 px-4 py-2.5 text-left ${activeIndex === index ? 'bg-primary-50' : 'hover:bg-gray-50'}`}>
                      <Search size={15} className="shrink-0 text-gray-400" />
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-medium text-gray-900">{item.label}</span>
                        <span className="block truncate text-xs text-gray-500">{item.description}</span>
                      </span>
                      <ArrowUpRight size={15} className="shrink-0 text-gray-400" />
                    </button>
                  );
                })}
              </div>
            ))}
            {(isFetching || (term.length >= 2 && term !== debounced.toLowerCase())) && (
              <div className="flex items-center gap-2 px-4 py-3 text-sm text-gray-500"><Loader2 size={15} className="animate-spin" /> Searching...</div>
            )}
            {isError && <p className="px-4 py-3 text-sm text-red-600">Search results are unavailable right now.</p>}
            {!isFetching && !isError && groups.length === 0 && term.length >= 2 && term === debounced.toLowerCase() && (
              <p className="px-4 py-5 text-sm text-gray-500">No results found.</p>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
