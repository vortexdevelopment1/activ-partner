import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Search, ArrowRight, PhoneCall } from 'lucide-react';
import { supportApi } from '../../api/support.api';
import { Badge } from '../../components/ui/Badge';
import { Pagination } from '../../components/ui/Pagination';
import type { CallbackRequest } from '../../types';

const TABS = ['All', 'Pending', 'In Progress', 'Resolved', 'Cancelled'] as const;
type Tab = (typeof TABS)[number];

const tabStatus: Record<Tab, string | undefined> = {
  All: undefined,
  Pending: 'pending',
  'In Progress': 'in_progress',
  Resolved: 'resolved',
  Cancelled: 'cancelled',
};

export const CallbackList: React.FC = () => {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<Tab>('All');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const limit = 15;

  const { data, isLoading } = useQuery({
    queryKey: ['support-callbacks', tabStatus[activeTab], page],
    queryFn: () =>
      supportApi.getCallbacks({ status: tabStatus[activeTab], page, limit }),
  });

  const requests: CallbackRequest[] = data?.data?.data?.items ?? [];
  const total: number = data?.data?.data?.total ?? 0;

  const filtered = search
    ? requests.filter(
        (r) =>
          r.partnerName.toLowerCase().includes(search.toLowerCase()) ||
          r.phone.includes(search) ||
          r.email.toLowerCase().includes(search.toLowerCase()) ||
          (r.venueName ?? '').toLowerCase().includes(search.toLowerCase()),
      )
    : requests;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Callback Requests</h2>
          <p className="text-sm text-gray-500 mt-0.5">Manage support callback submissions from partners</p>
        </div>
        <div className="relative">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search by name, phone or venue..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="input pl-9 w-72"
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
                {['Partner', 'Phone', 'Venue', 'Callback Date', 'Query', 'Status', 'Submitted', ''].map((h) => (
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
                  <td colSpan={8} className="text-center py-16 text-gray-400">
                    Loading...
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-16">
                    <PhoneCall size={32} className="mx-auto text-gray-200 mb-2" />
                    <p className="text-gray-400 text-sm">No callback requests found</p>
                  </td>
                </tr>
              ) : (
                filtered.map((req) => (
                  <tr
                    key={req.id}
                    className="border-b border-gray-50 hover:bg-gray-50/50 cursor-pointer"
                    onClick={() => navigate(`/support/callback/${req.id}`)}
                  >
                    <td className="px-5 py-3.5">
                      <p className="font-medium text-gray-900">{req.partnerName}</p>
                      <p className="text-xs text-gray-400">{req.email}</p>
                    </td>
                    <td className="px-5 py-3.5 text-gray-600">{req.phone}</td>
                    <td className="px-5 py-3.5 text-gray-600">
                      <p>{req.venueName ?? '—'}</p>
                      {req.city && <p className="text-xs text-gray-400">{req.city}</p>}
                    </td>
                    <td className="px-5 py-3.5 text-gray-600 text-xs">
                      {req.callbackDate ? (
                        <>
                          <p>{req.callbackDate}</p>
                          <p className="text-gray-400">{req.callbackTime}</p>
                        </>
                      ) : '—'}
                    </td>
                    <td className="px-5 py-3.5 text-gray-500 max-w-[200px]">
                      <p className="truncate">{req.query ?? '—'}</p>
                    </td>
                    <td className="px-5 py-3.5">
                      <Badge status={req.status} />
                    </td>
                    <td className="px-5 py-3.5 text-gray-400 text-xs">
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

        {/* Pagination */}
        {total > limit && (
          <div className="px-5 py-4 border-t border-gray-50">
            <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
          </div>
        )}
      </div>
    </div>
  );
};
