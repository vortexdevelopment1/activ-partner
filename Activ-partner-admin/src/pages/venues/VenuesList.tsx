import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { ArrowRight, Building2, Plus } from 'lucide-react';
import { venuesApi } from '../../api/venues.api';
import { Badge } from '../../components/ui/Badge';
import { Pagination } from '../../components/ui/Pagination';
import { CreateVenueModal } from './CreateVenueModal';
import { VenueFilters, defaultVenueFilters, type VenueFilterValues } from './VenueFilters';
import type { Venue } from '../../types';

const TABS = ['All', 'Pending', 'Approved', 'Rejected', 'Suspended'] as const;
type Tab = (typeof TABS)[number];

const tabStatus: Record<Tab, string | undefined> = {
  All: undefined,
  Pending: 'pending',
  Approved: 'approved',
  Rejected: 'rejected',
  Suspended: 'suspended',
};

export const VenuesList: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const partnerId = searchParams.get('partnerId') || undefined;
  const [activeTab, setActiveTab] = useState<Tab>(() => TABS.find((tab) => tabStatus[tab] === searchParams.get('status')) ?? 'All');
  const [filters, setFilters] = useState<VenueFilterValues>(() => ({
    ...defaultVenueFilters,
    search: searchParams.get('search') ?? '',
    categoryId: searchParams.get('categoryId') ?? '',
    city: searchParams.get('city') ?? '',
    state: searchParams.get('state') ?? '',
    sort: searchParams.get('sort') === 'oldest' ? 'oldest' : searchParams.get('sort') === 'updated' ? 'updated' : 'newest',
  }));
  const [page, setPage] = useState(1);
  const [createOpen, setCreateOpen] = useState(false);
  const limit = 15;

  const { data, isLoading, isError } = useQuery({
    queryKey: ['venues', filters, activeTab, page, partnerId],
    queryFn: () =>
      venuesApi.getAll({
        ...filters,
        categoryId: filters.categoryId || undefined,
        status: tabStatus[activeTab],
        page,
        limit,
        partnerId,
      }),
  });

  const venues: Venue[] = data?.data?.data?.items ?? [];
  const total: number = data?.data?.data?.total ?? 0;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Venues</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            {partnerId
              ? 'Viewing venues for the selected partner'
              : 'Review and approve partner venue submissions'}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setCreateOpen(true)}
            className="btn-primary flex items-center gap-1.5 text-sm whitespace-nowrap"
          >
            <Plus size={15} /> Create Venue
          </button>
        </div>
      </div>

      {/* Card */}
      <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <VenueFilters value={filters} onChange={(next) => { setFilters(next); setPage(1); }} onReset={() => {
          setFilters(defaultVenueFilters); setActiveTab('All'); setPage(1);
        }} />
        {/* Tabs */}
        <div className="flex gap-1 px-3 sm:px-5 border-b border-gray-100 overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          {TABS.map((tab) => (
            <button
              key={tab}
              onClick={() => { setActiveTab(tab); setPage(1); }}
              className={`px-3 py-3 text-sm font-medium border-b-2 whitespace-nowrap transition-colors ${
                activeTab === tab
                  ? 'border-primary-600 text-primary-700'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              {tab}
            </button>
          ))}
        </div>

        {/* Mobile venue list */}
        <div className="divide-y divide-gray-100 md:hidden">
          {isLoading ? (
            <div className="py-14 text-center text-sm text-gray-400">Loading...</div>
          ) : isError ? (
            <div className="py-14 text-center text-sm text-red-500">Unable to load venues. Please try again.</div>
          ) : venues.length === 0 ? (
            <div className="py-14 text-center">
              <Building2 size={30} className="mx-auto mb-2 text-gray-200" />
              <p className="text-sm text-gray-400">No venues found</p>
            </div>
          ) : venues.map((venue) => {
            const partnerName = typeof venue.partner === 'object'
              ? `${(venue.partner as any)?.firstName ?? ''} ${(venue.partner as any)?.lastName ?? ''}`.trim()
              : '';
            const categoryName = typeof venue.category === 'object' ? (venue.category as any)?.name : '';
            return (
              <button key={venue.id} type="button" onClick={() => navigate(`/venues/${venue.id}`)}
                className="flex w-full items-start gap-3 px-4 py-4 text-left hover:bg-gray-50">
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
                  <Building2 size={18} />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-2">
                    <p className="min-w-0 break-words text-sm font-semibold text-gray-900">{venue.name}</p>
                    <Badge status={venue.status} />
                  </div>
                  <p className="mt-1 truncate text-xs text-gray-500">{partnerName || 'Partner unavailable'}</p>
                  <p className="mt-1 text-xs text-gray-400">{venue.venueReference ?? 'Venue ID unavailable'}</p>
                  <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-xs text-gray-500">
                    {categoryName && <span>{categoryName}</span>}
                    {(venue.city || venue.state) && <span>{[venue.city, venue.state].filter(Boolean).join(', ')}</span>}
                    <span>{venue.services?.length ?? 0} services</span>
                  </div>
                </div>
                <ArrowRight size={15} className="mt-3 shrink-0 text-gray-300" />
              </button>
            );
          })}
        </div>

        {/* Table */}
        <div className="hidden overflow-x-auto md:block">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-50">
                {['Venue', 'Partner', 'Category', 'Location', 'Services', 'Status', 'Created', ''].map(
                  (h) => (
                    <th
                      key={h}
                      className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide"
                    >
                      {h}
                    </th>
                  ),
                )}
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={8} className="text-center py-16 text-gray-400">
                    Loading...
                  </td>
                </tr>
              ) : isError ? (
                <tr><td colSpan={8} className="text-center py-16 text-red-500">Unable to load venues. Please try again.</td></tr>
              ) : venues.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-16">
                    <Building2 size={32} className="mx-auto text-gray-200 mb-2" />
                    <p className="text-gray-400 text-sm">No venues found</p>
                  </td>
                </tr>
              ) : (
                venues.map((venue) => (
                  <tr
                    key={venue.id}
                    className="border-b border-gray-50 hover:bg-gray-50/50 cursor-pointer"
                    onClick={() => navigate(`/venues/${venue.id}`)}
                  >
                    <td className="px-5 py-3.5">
                      <p className="font-medium text-gray-900">{venue.name}</p>
                      <p className="text-xs text-gray-400">{venue.venueReference ?? 'Venue ID unavailable'}</p>
                      {venue.phone && (
                        <p className="text-xs text-gray-400">{venue.phone}</p>
                      )}
                    </td>
                    <td className="px-5 py-3.5 text-gray-600">
                      {typeof venue.partner === 'object'
                        ? `${(venue.partner as any)?.firstName ?? ''} ${(venue.partner as any)?.lastName ?? ''}`
                        : '—'}
                    </td>
                    <td className="px-5 py-3.5 text-gray-600">
                      {typeof venue.category === 'object'
                        ? (venue.category as any)?.name
                        : '—'}
                    </td>
                    <td className="px-5 py-3.5 text-gray-600">
                      {venue.city}, {venue.state}
                    </td>
                    <td className="px-5 py-3.5 text-gray-600">
                      {venue.services?.length ?? 0}
                    </td>
                    <td className="px-5 py-3.5">
                      <Badge status={venue.status} />
                    </td>
                    <td className="px-5 py-3.5 text-gray-400 text-xs">
                      {new Date(venue.createdAt).toLocaleDateString('en-IN', {
                        day: '2-digit',
                        month: 'short',
                        year: 'numeric',
                      })}
                    </td>
                    <td className="px-5 py-3.5">
                      <ArrowRight size={14} className="text-gray-300" />
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {total > limit && (
          <div className="px-5 py-4 border-t border-gray-50">
            <Pagination
              page={page}
              limit={limit}
              total={total}
              onPageChange={setPage}
            />
          </div>
        )}
      </div>

      <CreateVenueModal open={createOpen} onClose={() => setCreateOpen(false)} />
    </div>
  );
};
