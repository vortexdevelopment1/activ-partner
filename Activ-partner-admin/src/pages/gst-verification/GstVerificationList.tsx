import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Search, ArrowRight, FileCheck } from 'lucide-react';
import { gstVerificationApi } from '../../api/gst-verification.api';
import { Badge } from '../../components/ui/Badge';
import { Pagination } from '../../components/ui/Pagination';
import type { GstVerification } from '../../types';

const TABS = ['All', 'Pending', 'Approved', 'Rejected'] as const;
type Tab = (typeof TABS)[number];

const tabStatus: Record<Tab, string | undefined> = {
  All: undefined,
  Pending: 'pending',
  Approved: 'approved',
  Rejected: 'rejected',
};

export const GstVerificationList: React.FC = () => {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<Tab>('All');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const limit = 15;

  const { data, isLoading } = useQuery({
    queryKey: ['gst-verification', tabStatus[activeTab], page],
    queryFn: () =>
      gstVerificationApi.getAll({ status: tabStatus[activeTab], page, limit }),
  });

  const requests: GstVerification[] = data?.data?.data?.items ?? [];
  const total: number = data?.data?.data?.total ?? 0;

  const filtered = search
    ? requests.filter(
        (r) =>
          r.gstNumber.toLowerCase().includes(search.toLowerCase()) ||
          r.partner?.businessName?.toLowerCase().includes(search.toLowerCase()) ||
          r.partner?.user?.email?.toLowerCase().includes(search.toLowerCase()),
      )
    : requests;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">GST Verification</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            Review and approve partner GST registration requests
          </p>
        </div>
        <div className="relative">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search by GST or business..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="input pl-9 w-64"
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
                {['Business', 'Partner', 'GST Number', 'Status', 'Submitted', ''].map((h) => (
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
                  <td colSpan={6} className="text-center py-16 text-gray-400">
                    Loading...
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center py-16">
                    <FileCheck size={32} className="mx-auto text-gray-200 mb-2" />
                    <p className="text-gray-400 text-sm">No GST verification requests found</p>
                  </td>
                </tr>
              ) : (
                filtered.map((req) => (
                  <tr
                    key={req.id}
                    className="border-b border-gray-50 hover:bg-gray-50/50 cursor-pointer"
                    onClick={() => navigate(`/gst-verification/${req.id}`)}
                  >
                    <td className="px-5 py-3.5">
                      <p className="font-medium text-gray-900">
                        {req.partner?.businessName ?? '—'}
                      </p>
                    </td>
                    <td className="px-5 py-3.5 text-gray-600">
                      {req.partner?.user
                        ? `${req.partner.user.firstName} ${req.partner.user.lastName}`.trim()
                        : '—'}
                      {req.partner?.user?.email && (
                        <p className="text-xs text-gray-400 mt-0.5">{req.partner.user.email}</p>
                      )}
                    </td>
                    <td className="px-5 py-3.5 font-mono text-xs text-gray-700">
                      {req.gstNumber}
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
