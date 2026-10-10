import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Search, ArrowRight, ClipboardList } from 'lucide-react';
import { venueRequestsApi } from '../../api/venue-requests.api';
import { Badge } from '../../components/ui/Badge';
import { Pagination } from '../../components/ui/Pagination';
import type { VenueUpdateRequest } from '../../types';

const TABS = ['All', 'Pending', 'Approved', 'Rejected'] as const;
type Tab = (typeof TABS)[number];

const tabStatus: Record<Tab, string | undefined> = {
  All: undefined,
  Pending: 'pending',
  Approved: 'approved',
  Rejected: 'rejected',
};

export const VenueRequestsList: React.FC = () => {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<Tab>('Pending');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const limit = 15;

  const { data, isLoading } = useQuery({
    queryKey: ['venue-requests', page],
    queryFn: () => venueRequestsApi.getAll({ page, limit }),
  });

  const requests: VenueUpdateRequest[] = data?.data?.data?.items ?? [];
  const total: number = data?.data?.data?.total ?? 0;

  // Status filtering happens client-side against the fetched page (see venue-requests.api.ts).
  const statusFiltered = tabStatus[activeTab]
    ? requests.filter((r) => r.status === tabStatus[activeTab])
    : requests;

  const filtered = search
    ? statusFiltered.filter(
        (r) =>
          r.name?.toLowerCase().includes(search.toLowerCase()) ||
          r.venueId.toLowerCase().includes(search.toLowerCase()),
      )
    : statusFiltered;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Venue Update Requests</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            Review and approve partner venue change submissions
          </p>
        </div>
        <div className="relative">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search by venue name..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="input pl-9 w-60"
          />
        </div>
      </div>

      {/* Card */}
      <div className="bg-white rounded-xl border border-gray-100">
        {/* Tabs */}
        <div className="flex gap-1 px-5 border-b border-gray-100 overflow-x-auto">
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

        {/* Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-50">
                {['Venue', 'Location', 'Status', 'Submitted', ''].map((h) => (
                  <th
                    key={h}
                    className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={5} className="text-center py-16 text-gray-400">
                    Loading...
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={5} className="text-center py-16">
                    <ClipboardList size={32} className="mx-auto text-gray-200 mb-2" />
                    <p className="text-gray-400 text-sm">No venue update requests found</p>
                  </td>
                </tr>
              ) : (
                filtered.map((req) => (
                  <tr
                    key={req.id}
                    className="border-b border-gray-50 hover:bg-gray-50/50 cursor-pointer"
                    onClick={() => navigate(`/venue-requests/${req.id}`)}
                  >
                    <td className="px-5 py-3.5">
                      <p className="font-medium text-gray-900">
                        {req.name ?? '—'}
                      </p>
                      <p className="text-xs text-gray-400 mt-0.5">ID: {req.venueId}</p>
                    </td>
                    <td className="px-5 py-3.5 text-gray-600">
                      {req.city && req.state ? `${req.city}, ${req.state}` : '—'}
                    </td>
                    <td className="px-5 py-3.5">
                      <Badge status={req.status} />
                    </td>
                    <td className="px-5 py-3.5 text-gray-400 text-xs whitespace-nowrap">
                      {new Date(req.createdAt).toLocaleDateString('en-IN', {
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

        {total > limit && (
          <div className="px-5 py-4 border-t border-gray-50">
            <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
          </div>
        )}
      </div>
    </div>
  );
};
