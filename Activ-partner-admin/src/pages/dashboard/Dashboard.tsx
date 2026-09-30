import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import {
  Building2,
  CheckCircle,
  Clock,
  XCircle,
  TrendingUp,
  Users,
  Briefcase,
  ArrowRight,
} from 'lucide-react';
import { venuesApi } from '../../api/venues.api';
import { partnersApi } from '../../api/partners.api';
import { usersApi } from '../../api/users.api';
import { Badge } from '../../components/ui/Badge';
import type { Venue } from '../../types';

const TABS = ['All', 'Pending', 'Approved', 'Rejected'] as const;
type Tab = (typeof TABS)[number];

const tabStatus: Record<Tab, string | undefined> = {
  All: undefined,
  Pending: 'pending',
  Approved: 'approved',
  Rejected: 'rejected',
};

export const Dashboard: React.FC = () => {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<Tab>('Pending');

  const { data: statsData } = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: () => venuesApi.getStats(),
  });

  const { data: partnersData } = useQuery({
    queryKey: ['dashboard-partners-count'],
    queryFn: () => partnersApi.getAll({ limit: 1 }),
  });

  const { data: usersData } = useQuery({
    queryKey: ['dashboard-users-count'],
    queryFn: () => usersApi.getAll({ limit: 1 }),
  });

  const { data: venuesData, isLoading } = useQuery({
    queryKey: ['venues-dashboard'],
    queryFn: () => venuesApi.getAll({ limit: 50, page: 1 }),
  });

  const stats = statsData?.data?.data ?? { total: 0, pending: 0, approved: 0, rejected: 0 };
  const totalPartners: number = partnersData?.data?.data?.total ?? 0;
  const totalUsers: number = usersData?.data?.data?.total ?? 0;
  const approvalRate: number = stats.total > 0
    ? Math.round((stats.approved / stats.total) * 100)
    : 0;

  const statCards = [
    {
      label: 'Pending Approvals',
      value: stats.pending,
      icon: Clock,
      color: 'bg-amber-50 text-amber-600',
      border: 'border-amber-100',
    },
    {
      label: 'Approved Venues',
      value: stats.approved,
      icon: CheckCircle,
      color: 'bg-emerald-50 text-emerald-600',
      border: 'border-emerald-100',
    },
    {
      label: 'Rejected Venues',
      value: stats.rejected,
      icon: XCircle,
      color: 'bg-red-50 text-red-600',
      border: 'border-red-100',
    },
    {
      label: 'Approval Rate',
      value: `${approvalRate}%`,
      icon: TrendingUp,
      color: 'bg-primary-50 text-primary-600',
      border: 'border-primary-100',
    },
    {
      label: 'Total Partners',
      value: totalPartners,
      icon: Briefcase,
      color: 'bg-violet-50 text-violet-600',
      border: 'border-violet-100',
    },
    {
      label: 'Total Users',
      value: totalUsers,
      icon: Users,
      color: 'bg-blue-50 text-blue-600',
      border: 'border-blue-100',
    },
  ];

  const allVenues: Venue[] = venuesData?.data?.data?.items ?? [];
  const venues: Venue[] = activeTab === 'All'
    ? allVenues.slice(0, 10)
    : allVenues.filter((v) => v.status === tabStatus[activeTab]).slice(0, 10);

  return (
    <div className="space-y-6">
      {/* Page title */}
      <div>
        <h2 className="text-xl font-bold text-gray-900">Dashboard</h2>
        <p className="text-sm text-gray-500 mt-0.5">
          Overview of venue approvals and platform activity
        </p>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
        {statCards.map((card) => (
          <div
            key={card.label}
            className={`bg-white rounded-xl border ${card.border} p-4`}
          >
            <div
              className={`w-9 h-9 rounded-lg ${card.color} flex items-center justify-center mb-3`}
            >
              <card.icon size={18} />
            </div>
            <p className="text-2xl font-bold text-gray-900">{card.value}</p>
            <p className="text-xs text-gray-500 mt-0.5">{card.label}</p>
          </div>
        ))}
      </div>

      {/* Venues table */}
      <div className="bg-white rounded-xl border border-gray-100">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-5 pb-3">
          <div className="flex items-center gap-2">
            <Building2 size={18} className="text-gray-400" />
            <h3 className="text-sm font-semibold text-gray-900">Venue Approvals</h3>
          </div>
          <button
            onClick={() => navigate('/venues')}
            className="text-xs text-primary-600 font-medium flex items-center gap-1 hover:underline"
          >
            View all <ArrowRight size={12} />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 px-5 border-b border-gray-100">
          {TABS.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-3 py-2 text-sm font-medium border-b-2 transition-colors ${
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
                <th className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Venue
                </th>
                <th className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Partner
                </th>
                <th className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Category
                </th>
                <th className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Location
                </th>
                <th className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Status
                </th>
                <th className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Submitted
                </th>
                <th className="px-5 py-3" />
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="text-center py-10 text-gray-400">
                    Loading...
                  </td>
                </tr>
              ) : venues.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-10 text-gray-400">
                    No venues found
                  </td>
                </tr>
              ) : (
                venues.map((venue) => (
                  <tr
                    key={venue.id}
                    className="border-b border-gray-50 hover:bg-gray-50/50 cursor-pointer"
                    onClick={() => navigate(`/venues/${venue.id}`)}
                  >
                    <td className="px-5 py-3.5 font-medium text-gray-900">
                      {venue.name}
                    </td>
                    <td className="px-5 py-3.5 text-gray-600">
                      {typeof venue.partner === 'object'
                        ? `${(venue.partner as any)?.firstName} ${(venue.partner as any)?.lastName}`
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
                    <td className="px-5 py-3.5">
                      <Badge status={venue.status} />
                    </td>
                    <td className="px-5 py-3.5 text-gray-400">
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
      </div>
    </div>
  );
};
