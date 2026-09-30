import React, { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  ArrowLeft,
  FileCheck,
  User,
  Building2,
  CheckCircle2,
  XCircle,
  CalendarClock,
  FileImage,
} from 'lucide-react';
import { gstVerificationApi } from '../../api/gst-verification.api';
import { Badge } from '../../components/ui/Badge';
import { Modal } from '../../components/ui/Modal';
import { ConfirmDialog } from '../../components/common/ConfirmDialog';
import { useToast } from '../../hooks/useToast';
import type { GstVerification } from '../../types';

const InfoRow: React.FC<{ label: string; value?: string | null }> = ({ label, value }) =>
  value ? (
    <div className="flex gap-3">
      <span className="text-xs text-gray-400 w-36 shrink-0 pt-0.5">{label}</span>
      <span className="text-sm text-gray-800">{value}</span>
    </div>
  ) : null;

export const GstVerificationDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  const [approveOpen, setApproveOpen] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [adminNotes, setAdminNotes] = useState('');
  const [notesError, setNotesError] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['gst-verification', id],
    queryFn: () => gstVerificationApi.getById(id!),
    enabled: !!id,
  });

  const request: GstVerification | undefined = data?.data?.data;

  const approveMutation = useMutation({
    mutationFn: () => gstVerificationApi.approve(id!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gst-verification'] });
      success('GST verification approved successfully!');
      setApproveOpen(false);
      navigate('/gst-verification');
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to approve'),
  });

  const rejectMutation = useMutation({
    mutationFn: (notes: string) => gstVerificationApi.reject(id!, { adminNotes: notes }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gst-verification'] });
      success('GST verification rejected.');
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

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-32 text-gray-400">
        Loading GST verification details...
      </div>
    );
  }

  if (!request) {
    return (
      <div className="flex items-center justify-center py-32 text-gray-400">
        GST verification request not found.
      </div>
    );
  }

  const isPending = request.status === 'pending';

  return (
    <div className="space-y-5 max-w-3xl">
      {/* Back + header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate('/gst-verification')}
            className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <ArrowLeft size={18} className="text-gray-500" />
          </button>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-bold text-gray-900">
                {request.partner?.businessName ?? 'GST Verification'}
              </h2>
              <Badge status={request.status} size="md" />
            </div>
            <p className="text-sm text-gray-500 mt-0.5 font-mono">{request.gstNumber}</p>
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

      {/* GST details */}
      <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-4">
        <div className="flex items-center gap-2 mb-1">
          <FileCheck size={16} className="text-primary-600" />
          <h3 className="text-sm font-semibold text-gray-700">GST Details</h3>
        </div>
        <div className="space-y-2.5">
          <InfoRow label="GST Number" value={request.gstNumber} />
          <InfoRow
            label="Submitted On"
            value={new Date(request.createdAt).toLocaleString('en-IN', {
              day: '2-digit',
              month: 'short',
              year: 'numeric',
              hour: '2-digit',
              minute: '2-digit',
            })}
          />
          {request.status === 'approved' && (
            <InfoRow
              label="Approved On"
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
      </div>

      {/* Partner info */}
      {request.partner && (
        <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-4">
          <div className="flex items-center gap-2 mb-1">
            <Building2 size={16} className="text-primary-600" />
            <h3 className="text-sm font-semibold text-gray-700">Business Info</h3>
          </div>
          <div className="space-y-2.5">
            <InfoRow label="Business Name" value={request.partner.businessName} />
            <InfoRow label="City" value={request.partner.city} />
            <InfoRow label="State" value={request.partner.state} />
            <InfoRow label="Address" value={request.partner.businessAddress} />
          </div>
        </div>
      )}

      {request.partner?.user && (
        <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-4">
          <div className="flex items-center gap-2 mb-1">
            <User size={16} className="text-primary-600" />
            <h3 className="text-sm font-semibold text-gray-700">Partner Contact</h3>
          </div>
          <div className="space-y-2.5">
            <InfoRow
              label="Name"
              value={`${request.partner.user.firstName} ${request.partner.user.lastName}`.trim()}
            />
            <InfoRow label="Email" value={request.partner.user.email} />
            <InfoRow label="Phone" value={request.partner.user.phone} />
          </div>
        </div>
      )}

      {/* GST document */}
      {request.gstinDocUrl && (
        <div className="bg-white rounded-xl border border-gray-100 p-5">
          <div className="flex items-center gap-2 mb-3">
            <FileImage size={16} className="text-primary-600" />
            <h3 className="text-sm font-semibold text-gray-700">GST Certificate / Document</h3>
          </div>
          <a href={request.gstinDocUrl} target="_blank" rel="noreferrer">
            <img
              src={request.gstinDocUrl}
              alt="GST document"
              className="w-full max-w-md rounded-lg border border-gray-200 object-cover hover:opacity-90 transition-opacity cursor-zoom-in"
            />
          </a>
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
        title="Approve GST Verification"
        message={`Approve GST number "${request.gstNumber}" for ${request.partner?.businessName ?? 'this partner'}? The GST details will be written to the partner profile.`}
        confirmLabel="Approve"
        variant="warning"
        loading={approveMutation.isPending}
      />

      {/* Reject modal */}
      <Modal open={rejectOpen} onClose={handleRejectClose} title="Reject GST Verification" size="md">
        <div className="space-y-4">
          <div className="flex gap-3">
            <div className="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center shrink-0">
              <XCircle size={20} className="text-red-600" />
            </div>
            <p className="text-sm text-gray-700 pt-2">
              Rejecting GST verification for{' '}
              <span className="font-semibold text-gray-900">
                {request.partner?.businessName ?? 'this partner'}
              </span>
              . The partner will be notified with the reason below.
            </p>
          </div>

          <div>
            <label className="label">Reason for Rejection *</label>
            <textarea
              rows={3}
              value={adminNotes}
              onChange={(e) => { setAdminNotes(e.target.value); setNotesError(''); }}
              placeholder="Explain why this GST submission is being rejected..."
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
