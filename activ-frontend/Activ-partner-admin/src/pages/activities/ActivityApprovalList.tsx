import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { CheckCircle, XCircle, Eye, Clock, Building2, Tag } from 'lucide-react';
import { activitiesApi } from '../../api/activities.api';
import { Pagination } from '../../components/ui/Pagination';
import { Badge } from '../../components/ui/Badge';
import { Modal } from '../../components/ui/Modal';
import { ApproveActivityModal } from './ApproveActivityModal';
import { RejectActivityModal } from './RejectActivityModal';
import { useToast } from '../../hooks/useToast';
import { PendingActivity } from '../../types';

const LIMIT = 15;

export const ActivityApprovalList: React.FC = () => {
  const queryClient = useQueryClient();
  const toast = useToast();

  const [page, setPage] = useState(1);
  const [approveTarget, setApproveTarget] = useState<PendingActivity | null>(null);
  const [rejectTarget, setRejectTarget] = useState<PendingActivity | null>(null);
  const [detailTarget, setDetailTarget] = useState<PendingActivity | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['pending-activities', page],
    queryFn: () => activitiesApi.getPending({ page, limit: LIMIT }),
    select: (res) => res.data.data,
  });

  const approveMutation = useMutation({
    mutationFn: (serviceId: string) => activitiesApi.approve(serviceId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pending-activities'] });
      toast.success('Activity approved successfully');
      setApproveTarget(null);
    },
    onError: (err: any) => {
      toast.error(err?.response?.data?.message ?? 'Failed to approve activity');
    },
  });

  const rejectMutation = useMutation({
    mutationFn: ({ serviceId, reason }: { serviceId: string; reason: string }) =>
      activitiesApi.reject(serviceId, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pending-activities'] });
      toast.success('Activity rejected');
      setRejectTarget(null);
    },
    onError: (err: any) => {
      toast.error(err?.response?.data?.message ?? 'Failed to reject activity');
    },
  });

  const items = data?.items ?? [];
  const total = data?.total ?? 0;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Activity Approvals</h1>
          <p className="text-sm text-gray-500 mt-0.5">Review and approve partner-submitted activities</p>
        </div>
        {total > 0 && (
          <span className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-amber-50 text-amber-700 text-sm font-semibold rounded-full border border-amber-200">
            <Clock size={14} />
            {total} pending
          </span>
        )}
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center py-20 text-gray-400">
            Loading...
          </div>
        ) : items.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 gap-3 text-gray-400">
            <CheckCircle size={36} className="text-emerald-300" />
            <p className="text-sm font-medium">No pending activities</p>
            <p className="text-xs">All caught up!</p>
          </div>
        ) : (
          <>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100 bg-gray-50/60">
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                    Activity
                  </th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                    Venue
                  </th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                    Category
                  </th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                    Amenities
                  </th>
                  <th className="text-left px-5 py-3.5 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                    Submitted
                  </th>
                  <th className="text-right px-5 py-3.5 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {items.map((activity) => (
                  <tr key={activity.id} className="hover:bg-gray-50/50 transition-colors">
                    <td className="px-5 py-4">
                      <p className="font-medium text-gray-900">{activity.name}</p>
                      <Badge status="pending" size="sm" />
                    </td>
                    <td className="px-5 py-4">
                      <div className="flex items-center gap-2">
                        <Building2 size={14} className="text-gray-400 shrink-0" />
                        <div>
                          <p className="text-gray-800 font-medium">{activity.venue?.name ?? '—'}</p>
                          <p className="text-xs text-gray-400">{activity.venue?.city}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-4">
                      <div className="flex items-center gap-1.5">
                        <Tag size={13} className="text-gray-400" />
                        <span className="text-gray-700">{activity.category?.name ?? '—'}</span>
                      </div>
                    </td>
                    <td className="px-5 py-4">
                      {activity.amenities?.length ? (
                        <span className="text-gray-700">{activity.amenities.length} items</span>
                      ) : (
                        <span className="text-gray-400">—</span>
                      )}
                    </td>
                    <td className="px-5 py-4 text-gray-500">
                      {activity.submittedAt
                        ? new Date(activity.submittedAt).toLocaleDateString('en-IN', {
                            day: 'numeric',
                            month: 'short',
                            year: 'numeric',
                          })
                        : '—'}
                    </td>
                    <td className="px-5 py-4">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={() => setDetailTarget(activity)}
                          title="View details"
                          className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-400 hover:text-gray-700 transition-colors"
                        >
                          <Eye size={16} />
                        </button>
                        <button
                          onClick={() => setApproveTarget(activity)}
                          title="Approve"
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-50 text-emerald-700 hover:bg-emerald-100 rounded-lg text-xs font-medium transition-colors"
                        >
                          <CheckCircle size={13} />
                          Approve
                        </button>
                        <button
                          onClick={() => setRejectTarget(activity)}
                          title="Reject"
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-red-50 text-red-600 hover:bg-red-100 rounded-lg text-xs font-medium transition-colors"
                        >
                          <XCircle size={13} />
                          Reject
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {total > LIMIT && (
              <Pagination
                page={page}
                total={total}
                limit={LIMIT}
                onPageChange={setPage}
              />
            )}
          </>
        )}
      </div>

      {/* Detail Modal */}
      <Modal
        open={!!detailTarget}
        onClose={() => setDetailTarget(null)}
        title="Activity Details"
        size="lg"
      >
        {detailTarget && (
          <div className="space-y-5">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1">Activity Name</p>
                <p className="text-gray-900 font-medium">{detailTarget.name}</p>
              </div>
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1">Status</p>
                <Badge status={detailTarget.status} />
              </div>
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1">Venue</p>
                <p className="text-gray-900">{detailTarget.venue?.name ?? '—'}</p>
                <p className="text-xs text-gray-500">{detailTarget.venue?.city}, {detailTarget.venue?.state}</p>
              </div>
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1">Category</p>
                <p className="text-gray-900">{detailTarget.category?.name ?? '—'}</p>
              </div>
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1">Submitted On</p>
                <p className="text-gray-900">
                  {detailTarget.submittedAt
                    ? new Date(detailTarget.submittedAt).toLocaleString('en-IN')
                    : '—'}
                </p>
              </div>
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1">Created On</p>
                <p className="text-gray-900">{new Date(detailTarget.createdAt).toLocaleDateString('en-IN')}</p>
              </div>
            </div>

            {detailTarget.amenities && detailTarget.amenities.length > 0 && (
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">Amenities</p>
                <div className="flex flex-wrap gap-2">
                  {detailTarget.amenities.map((a) => (
                    <span
                      key={a}
                      className="px-2.5 py-1 bg-primary-50 text-primary-700 text-xs rounded-full font-medium"
                    >
                      {a}
                    </span>
                  ))}
                </div>
              </div>
            )}

            <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
              <button
                onClick={() => { setDetailTarget(null); setRejectTarget(detailTarget); }}
                className="flex items-center gap-1.5 px-4 py-2 bg-red-50 text-red-600 hover:bg-red-100 rounded-lg text-sm font-medium transition-colors"
              >
                <XCircle size={15} />
                Reject
              </button>
              <button
                onClick={() => { setDetailTarget(null); setApproveTarget(detailTarget); }}
                className="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 text-white hover:bg-emerald-700 rounded-lg text-sm font-medium transition-colors"
              >
                <CheckCircle size={15} />
                Approve
              </button>
            </div>
          </div>
        )}
      </Modal>

      {/* Approve Modal */}
      <ApproveActivityModal
        open={!!approveTarget}
        activityName={approveTarget?.name ?? ''}
        venueName={approveTarget?.venue?.name ?? ''}
        loading={approveMutation.isPending}
        onConfirm={() => approveTarget && approveMutation.mutate(approveTarget.id)}
        onCancel={() => setApproveTarget(null)}
      />

      {/* Reject Modal */}
      <RejectActivityModal
        open={!!rejectTarget}
        activityName={rejectTarget?.name ?? ''}
        loading={rejectMutation.isPending}
        onConfirm={(reason) => rejectTarget && rejectMutation.mutate({ serviceId: rejectTarget.id, reason })}
        onCancel={() => setRejectTarget(null)}
      />
    </div>
  );
};
