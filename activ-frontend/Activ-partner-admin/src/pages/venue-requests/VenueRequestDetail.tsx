import React, { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  ArrowLeft,
  Building2,
  ClipboardList,
  CheckCircle2,
  XCircle,
  CalendarClock,
  ArrowRight,
} from 'lucide-react';
import { venueRequestsApi } from '../../api/venue-requests.api';
import { venuesApi } from '../../api/venues.api';
import { Badge } from '../../components/ui/Badge';
import { Modal } from '../../components/ui/Modal';
import { ConfirmDialog } from '../../components/common/ConfirmDialog';
import { useToast } from '../../hooks/useToast';
import { VENUE_REQUEST_FIELD_KEYS, type Venue, type VenueUpdateRequest } from '../../types';

const InfoRow: React.FC<{ label: string; value?: string | null }> = ({ label, value }) =>
  value ? (
    <div className="flex gap-3">
      <span className="text-xs text-gray-400 w-36 shrink-0 pt-0.5">{label}</span>
      <span className="text-sm text-gray-800">{value}</span>
    </div>
  ) : null;

function toLabel(key: string): string {
  return key
    .replace(/([A-Z])/g, ' $1')
    .replace(/^./, (c) => c.toUpperCase())
    .trim();
}

function formatValue(value: unknown): string {
  if (value === null || value === undefined) return '—';
  if (Array.isArray(value)) return value.join(', ') || '—';
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}

export const VenueRequestDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  const [approveOpen, setApproveOpen] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [adminNotes, setAdminNotes] = useState('');
  const [notesError, setNotesError] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['venue-request', id],
    queryFn: () => venueRequestsApi.getById(id!),
    enabled: !!id,
  });

  const request: VenueUpdateRequest | undefined = data?.data?.data;

  // The request only carries the requested new values; fetch the venue for its current values.
  const { data: venueData, isLoading: isVenueLoading } = useQuery({
    queryKey: ['venue', request?.venueId],
    queryFn: () => venuesApi.getById(request!.venueId),
    enabled: !!request?.venueId,
  });

  const venue: Venue | undefined = venueData?.data?.data;

  const approveMutation = useMutation({
    mutationFn: () => venueRequestsApi.approve(id!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['venue-requests'] });
      success('Venue update request approved. Changes applied to the venue.');
      setApproveOpen(false);
      navigate('/venue-requests');
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to approve'),
  });

  const rejectMutation = useMutation({
    mutationFn: (notes: string) => venueRequestsApi.reject(id!, { adminNotes: notes }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['venue-request', id] });
      queryClient.invalidateQueries({ queryKey: ['venue-requests'] });
      success('Venue update request rejected.');
      setRejectOpen(false);
      setAdminNotes('');
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to reject'),
  });

  const handleRejectConfirm = () => {
    if (!adminNotes.trim()) {
      setNotesError('Please provide a reason for rejection.');
      return;
    }
    setNotesError('');
    rejectMutation.mutate(adminNotes.trim());
  };

  const handleRejectClose = () => {
    setRejectOpen(false);
    setAdminNotes('');
    setNotesError('');
  };

  if (isLoading || (!!request?.venueId && isVenueLoading)) {
    return (
      <div className="flex items-center justify-center py-32 text-gray-400">
        Loading request details...
      </div>
    );
  }

  if (!request) {
    return (
      <div className="flex items-center justify-center py-32 text-gray-400">
        Venue update request not found.
      </div>
    );
  }

  const isPending = request.status === 'pending';

  // The request holds the requested new values; diff against the venue's current values.
  const changedFields = venue
    ? VENUE_REQUEST_FIELD_KEYS.filter((key) => {
        const requestedValue = request[key];
        if (requestedValue === undefined) return false;
        const currentValue = (venue as unknown as Record<string, unknown>)[key];
        return String(currentValue ?? '') !== String(requestedValue ?? '');
      }).map(
        (key) =>
          [key, (venue as unknown as Record<string, unknown>)[key], request[key]] as const,
      )
    : [];

  return (
    <div className="space-y-5 max-w-3xl">
      {/* Back + header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate('/venue-requests')}
            className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <ArrowLeft size={18} className="text-gray-500" />
          </button>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-bold text-gray-900">
                {venue?.name ?? request.name ?? 'Venue Update Request'}
              </h2>
              <Badge status={request.status} size="md" />
            </div>
            <p className="text-sm text-gray-500 mt-0.5">
              {changedFields.length} field{changedFields.length !== 1 ? 's' : ''} requested to change
            </p>
          </div>
        </div>

        {isPending && (
          <div className="flex gap-2">
            <button
              onClick={() => setRejectOpen(true)}
              className="flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-medium text-red-600 bg-red-50 hover:bg-red-100 transition-colors"
            >
              <XCircle size={15} />
              Reject
            </button>
            <button
              onClick={() => setApproveOpen(true)}
              className="flex items-center gap-1.5 btn-primary text-sm"
            >
              <CheckCircle2 size={15} />
              Approve
            </button>
          </div>
        )}
      </div>

      {/* Admin notes banner (rejection) */}
      {request.status === 'rejected' && request.adminNotes && (
        <div className="bg-red-50 border border-red-100 rounded-xl px-5 py-4 flex gap-3">
          <XCircle size={18} className="text-red-500 shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-medium text-red-700">Rejection Reason</p>
            <p className="text-sm text-red-600 mt-0.5">{request.adminNotes}</p>
          </div>
        </div>
      )}

      {/* Requested changes */}
      <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <div className="flex items-center gap-2 px-5 py-4 border-b border-gray-50">
          <ClipboardList size={16} className="text-primary-600" />
          <h3 className="text-sm font-semibold text-gray-700">Requested Changes</h3>
        </div>
        {changedFields.length === 0 ? (
          <p className="px-5 py-6 text-sm text-gray-400">No change data available.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-50">
                <th className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide w-44">
                  Field
                </th>
                <th className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Current Value
                </th>
                <th className="px-3 py-3 w-8" />
                <th className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide">
                  Requested Value
                </th>
              </tr>
            </thead>
            <tbody>
              {changedFields.map(([key, currentValue, newValue]) => {
                return (
                  <tr key={key} className="border-b border-gray-50 last:border-0">
                    <td className="px-5 py-3 text-xs font-medium text-gray-500 whitespace-nowrap">
                      {toLabel(key)}
                    </td>
                    <td className="px-5 py-3 text-gray-400 text-xs max-w-xs">
                      <span className="line-clamp-2">{formatValue(currentValue)}</span>
                    </td>
                    <td className="px-3 py-3">
                      <ArrowRight size={12} className="text-gray-300" />
                    </td>
                    <td className="px-5 py-3 text-gray-900 text-xs font-medium max-w-xs">
                      <span className="line-clamp-2">{formatValue(newValue)}</span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Venue info */}
      {venue && (
        <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-4">
          <div className="flex items-center gap-2 mb-1">
            <Building2 size={16} className="text-primary-600" />
            <h3 className="text-sm font-semibold text-gray-700">Venue Info</h3>
          </div>
          <div className="space-y-2.5">
            <InfoRow label="Venue Name" value={venue.name} />
            <InfoRow label="City" value={venue.city} />
            <InfoRow label="State" value={venue.state} />
            <InfoRow label="Address" value={venue.address} />
            <InfoRow label="Current Status" value={venue.status} />
          </div>
        </div>
      )}

      {/* Timeline */}
      <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-2.5">
        <div className="flex items-center gap-2 mb-1">
          <CalendarClock size={16} className="text-primary-600" />
          <h3 className="text-sm font-semibold text-gray-700">Timeline</h3>
        </div>
        <InfoRow
          label="Submitted"
          value={new Date(request.createdAt).toLocaleString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
          })}
        />
        {request.updatedAt !== request.createdAt && (
          <InfoRow
            label="Last Updated"
            value={new Date(request.updatedAt).toLocaleString('en-IN', {
              day: '2-digit',
              month: 'short',
              year: 'numeric',
              hour: '2-digit',
              minute: '2-digit',
            })}
          />
        )}
      </div>

      {/* Approve confirm */}
      <ConfirmDialog
        open={approveOpen}
        onCancel={() => setApproveOpen(false)}
        onConfirm={() => approveMutation.mutate()}
        title="Approve Venue Update"
        message={`Approve ${changedFields.length} change${changedFields.length !== 1 ? 's' : ''} for "${venue?.name ?? request.name ?? 'this venue'}"? Only the submitted fields will be updated; all other venue data stays as-is.`}
        confirmLabel="Approve"
        variant="warning"
        loading={approveMutation.isPending}
      />

      {/* Reject modal */}
      <Modal open={rejectOpen} onClose={handleRejectClose} title="Reject Venue Update" size="md">
        <div className="space-y-4">
          <div className="flex gap-3">
            <div className="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center shrink-0">
              <XCircle size={20} className="text-red-600" />
            </div>
            <p className="text-sm text-gray-700 pt-2">
              Rejecting venue update for{' '}
              <span className="font-semibold text-gray-900">
                {venue?.name ?? request.name ?? 'this venue'}
              </span>
              . The partner will be notified and can resubmit.
            </p>
          </div>

          <div>
            <label className="label">Reason for Rejection *</label>
            <textarea
              rows={3}
              value={adminNotes}
              onChange={(e) => { setAdminNotes(e.target.value); setNotesError(''); }}
              placeholder="Explain what needs to be corrected before resubmitting..."
              className="input resize-none"
            />
            {notesError && <p className="mt-1 text-xs text-red-500">{notesError}</p>}
          </div>

          <div className="flex justify-end gap-3 pt-1">
            <button type="button" onClick={handleRejectClose} className="btn-secondary">
              Cancel
            </button>
            <button
              type="button"
              onClick={handleRejectConfirm}
              disabled={rejectMutation.isPending}
              className="bg-red-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-red-700 disabled:opacity-60 transition-colors"
            >
              {rejectMutation.isPending ? 'Rejecting...' : 'Reject'}
            </button>
          </div>
        </div>
      </Modal>
    </div>
  );
};
