import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  ArrowLeft,
  PhoneCall,
  User,
  MessageSquare,
  StickyNote,
  Trash2,
  Save,
  Building2,
  CalendarClock,
} from 'lucide-react';
import { supportApi } from '../../api/support.api';
import { Badge } from '../../components/ui/Badge';
import { ConfirmDialog } from '../../components/common/ConfirmDialog';
import { useToast } from '../../hooks/useToast';
import type { CallbackRequest, CallbackStatus } from '../../types';

const InfoRow: React.FC<{ label: string; value?: string | null }> = ({ label, value }) =>
  value ? (
    <div className="flex gap-3">
      <span className="text-xs text-gray-400 w-32 shrink-0 pt-0.5">{label}</span>
      <span className="text-sm text-gray-800">{value}</span>
    </div>
  ) : null;

const STATUS_OPTIONS: { value: CallbackStatus; label: string }[] = [
  { value: 'pending', label: 'Pending' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'cancelled', label: 'Cancelled' },
];

export const CallbackDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  const [adminNotes, setAdminNotes] = useState('');
  const [selectedStatus, setSelectedStatus] = useState<CallbackStatus>('pending');
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [hasChanges, setHasChanges] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ['support-callback', id],
    queryFn: () => supportApi.getCallbackById(id!),
    enabled: !!id,
  });

  const request: CallbackRequest | undefined = data?.data?.data;

  useEffect(() => {
    if (request) {
      setAdminNotes(request.adminNotes ?? '');
      setSelectedStatus(request.status);
    }
  }, [request]);

  useEffect(() => {
    if (request) {
      setHasChanges(
        adminNotes !== (request.adminNotes ?? '') || selectedStatus !== request.status,
      );
    }
  }, [adminNotes, selectedStatus, request]);

  const updateMutation = useMutation({
    mutationFn: (payload: { status?: string; adminNotes?: string }) =>
      supportApi.updateCallback(id!, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['support-callback', id] });
      queryClient.invalidateQueries({ queryKey: ['support-callbacks'] });
      success('Callback request updated successfully.');
      setHasChanges(false);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to update'),
  });

  const deleteMutation = useMutation({
    mutationFn: () => supportApi.deleteCallback(id!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['support-callbacks'] });
      success('Callback request deleted.');
      navigate('/support/callback');
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to delete'),
  });

  const handleSave = () => {
    updateMutation.mutate({ status: selectedStatus, adminNotes });
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-32 text-gray-400">
        Loading callback request...
      </div>
    );
  }

  if (!request) {
    return (
      <div className="flex items-center justify-center py-32 text-gray-400">
        Callback request not found.
      </div>
    );
  }

  return (
    <div className="space-y-5 max-w-3xl">
      {/* Back + header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate(-1)}
            className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <ArrowLeft size={18} className="text-gray-500" />
          </button>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-bold text-gray-900">{request.partnerName}</h2>
              <Badge status={request.status} size="md" />
            </div>
            <p className="text-sm text-gray-500 mt-0.5">{request.phone}</p>
          </div>
        </div>

        <div className="flex gap-2">
          <button
            onClick={() => setDeleteOpen(true)}
            className="flex items-center gap-1.5 px-3 py-2 rounded-lg text-sm font-medium text-red-600 bg-red-50 hover:bg-red-100 transition-colors"
          >
            <Trash2 size={14} />
            Delete
          </button>
          {hasChanges && (
            <button
              onClick={handleSave}
              disabled={updateMutation.isPending}
              className="flex items-center gap-1.5 btn-primary text-sm"
            >
              <Save size={14} />
              {updateMutation.isPending ? 'Saving...' : 'Save Changes'}
            </button>
          )}
        </div>
      </div>

      {/* Contact info */}
      <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-4">
        <div className="flex items-center gap-2 mb-1">
          <User size={16} className="text-primary-600" />
          <h3 className="text-sm font-semibold text-gray-700">Contact Info</h3>
        </div>
        <div className="space-y-2.5">
          <InfoRow label="Partner Name" value={request.partnerName} />
          <InfoRow label="Phone" value={request.phone} />
          <InfoRow label="Email" value={request.email} />
          <InfoRow
            label="Submitted At"
            value={new Date(request.createdAt).toLocaleString('en-IN', {
              day: '2-digit',
              month: 'short',
              year: 'numeric',
              hour: '2-digit',
              minute: '2-digit',
            })}
          />
        </div>
      </div>

      {/* Venue & Callback schedule */}
      {(request.venueName || request.callbackDate) && (
        <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-4">
          <div className="flex items-center gap-2 mb-1">
            <Building2 size={16} className="text-primary-600" />
            <h3 className="text-sm font-semibold text-gray-700">Venue & Schedule</h3>
          </div>
          <div className="space-y-2.5">
            <InfoRow label="Venue" value={request.venueName} />
            <InfoRow label="City" value={request.city} />
            <InfoRow label="Callback Date" value={request.callbackDate} />
            <InfoRow label="Callback Time" value={request.callbackTime} />
          </div>
        </div>
      )}

      {/* Query */}
      {request.query && (
        <div className="bg-white rounded-xl border border-gray-100 p-5">
          <div className="flex items-center gap-2 mb-3">
            <MessageSquare size={16} className="text-primary-600" />
            <h3 className="text-sm font-semibold text-gray-700">Query</h3>
          </div>
          <p className="text-sm text-gray-700 leading-relaxed whitespace-pre-line">{request.query}</p>
        </div>
      )}

      {/* Status update */}
      <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-4">
        <div className="flex items-center gap-2 mb-1">
          <CalendarClock size={16} className="text-primary-600" />
          <h3 className="text-sm font-semibold text-gray-700">Update Status</h3>
        </div>
        <div>
          <label className="label">Status</label>
          <select
            value={selectedStatus}
            onChange={(e) => setSelectedStatus(e.target.value as CallbackStatus)}
            className="input"
          >
            {STATUS_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Admin notes */}
      <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-4">
        <div className="flex items-center gap-2 mb-1">
          <StickyNote size={16} className="text-primary-600" />
          <h3 className="text-sm font-semibold text-gray-700">Admin Notes</h3>
        </div>
        <textarea
          rows={4}
          value={adminNotes}
          onChange={(e) => setAdminNotes(e.target.value)}
          placeholder="Add internal notes about this callback request..."
          className="input resize-none"
        />
        {hasChanges && (
          <div className="flex justify-end">
            <button
              onClick={handleSave}
              disabled={updateMutation.isPending}
              className="flex items-center gap-1.5 btn-primary text-sm"
            >
              <Save size={14} />
              {updateMutation.isPending ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        )}
      </div>

      {/* Delete confirm */}
      <ConfirmDialog
        open={deleteOpen}
        onCancel={() => setDeleteOpen(false)}
        onConfirm={() => deleteMutation.mutate()}
        title="Delete Callback Request"
        message={`Are you sure you want to delete the callback request from "${request.partnerName}"? This action cannot be undone.`}
        confirmLabel="Delete"
        variant="danger"
        loading={deleteMutation.isPending}
      />
    </div>
  );
};
