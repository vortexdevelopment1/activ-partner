import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Search, ArrowRight, Landmark } from 'lucide-react';
import { bankAccountsApi } from '../../api/bank-accounts.api';
import { Badge } from '../../components/ui/Badge';
import { Pagination } from '../../components/ui/Pagination';
import type { BankAccount } from '../../types';

const TABS = ['All', 'Under Review', 'Approved', 'Rejected'] as const;
type Tab = (typeof TABS)[number];

const tabStatus: Record<Tab, string | undefined> = {
  All: undefined,
  'Under Review': 'under_review',
  Approved: 'approved',
  Rejected: 'rejected',
};

export const BankAccountsList: React.FC = () => {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<Tab>('All');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const limit = 15;

  const { data, isLoading } = useQuery({
    queryKey: ['bank-accounts', tabStatus[activeTab], page],
    queryFn: () =>
      bankAccountsApi.getAll({
        status: tabStatus[activeTab],
        page,
        limit,
      }),
  });

  const accounts: BankAccount[] = data?.data?.data?.items ?? [];
  const total: number = data?.data?.data?.total ?? 0;

  const filtered = search
    ? accounts.filter(
        (a) =>
          a.accountHolderName.toLowerCase().includes(search.toLowerCase()) ||
          a.bankName.toLowerCase().includes(search.toLowerCase()) ||
          a.accountNumber.includes(search) ||
          a.ifscCode.toLowerCase().includes(search.toLowerCase()),
      )
    : accounts;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Bank Accounts</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            Review and approve partner bank account submissions
          </p>
        </div>
        <div className="relative">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search accounts..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="input pl-9 w-56"
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
                {['Account Holder', 'Bank Name', 'Account Number', 'IFSC Code', 'Account Type', 'Partner', 'Status', 'Submitted', ''].map(
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
                  <td colSpan={9} className="text-center py-16 text-gray-400">
                    Loading...
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={9} className="text-center py-16">
                    <Landmark size={32} className="mx-auto text-gray-200 mb-2" />
                    <p className="text-gray-400 text-sm">No bank accounts found</p>
                  </td>
                </tr>
              ) : (
                filtered.map((account) => (
                  <tr
                    key={account.id}
                    className="border-b border-gray-50 hover:bg-gray-50/50 cursor-pointer"
                    onClick={() => navigate(`/bank-accounts/${account.id}`)}
                  >
                    <td className="px-5 py-3.5">
                      <p className="font-medium text-gray-900">{account.accountHolderName}</p>
                    </td>
                    <td className="px-5 py-3.5 text-gray-600">{account.bankName}</td>
                    <td className="px-5 py-3.5 text-gray-600 font-mono text-xs">
                      {account.accountNumber}
                    </td>
                    <td className="px-5 py-3.5 text-gray-600 font-mono text-xs">
                      {account.ifscCode}
                    </td>
                    <td className="px-5 py-3.5 text-gray-600">{account.accountType}</td>
                    <td className="px-5 py-3.5 text-gray-600">
                      {account.partner
                        ? `${account.partner.user?.firstName ?? ''} ${account.partner.user?.lastName ?? ''}`.trim() ||
                          '—'
                        : '—'}
                    </td>
                    <td className="px-5 py-3.5">
                      <Badge status={account.status} />
                    </td>
                    <td className="px-5 py-3.5 text-gray-400 text-xs">
                      {new Date(account.createdAt).toLocaleDateString('en-IN', {
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
