import React, { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  ArrowLeft,
  Landmark,
  User,
  CheckCircle2,
  XCircle,
  CalendarClock,
  FileImage,
} from 'lucide-react';
import { bankAccountsApi } from '../../api/bank-accounts.api';
import { Badge } from '../../components/ui/Badge';
import { Modal } from '../../components/ui/Modal';
import { ConfirmDialog } from '../../components/common/ConfirmDialog';
import { useToast } from '../../hooks/useToast';
import type { BankAccount } from '../../types';

const InfoRow: React.FC<{ label: string; value?: string | null }> = ({ label, value }) =>
  value ? (
    <div className="flex gap-3">
      <span className="text-xs text-gray-400 w-36 shrink-0 pt-0.5">{label}</span>
      <span className="text-sm text-gray-800">{value}</span>
    </div>
  ) : null;

export const BankAccountDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  const [approveOpen, setApproveOpen] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [rejectionReason, setRejectionReason] = useState('');
  const [reasonError, setReasonError] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['bank-account', id],
    queryFn: () => bankAccountsApi.getById(id!),
    enabled: !!id,
  });

  const account: BankAccount | undefined = data?.data?.data;

  const approveMutation = useMutation({
    mutationFn: () => bankAccountsApi.review(id!, { status: 'approved' }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['bank-account', id] });
      queryClient.invalidateQueries({ queryKey: ['bank-accounts'] });
      success('Bank account approved successfully!');
      setApproveOpen(false);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to approve'),
  });

  const rejectMutation = useMutation({
    mutationFn: (reason: string) =>
      bankAccountsApi.review(id!, { status: 'rejected', rejectionReason: reason }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['bank-account', id] });
      queryClient.invalidateQueries({ queryKey: ['bank-accounts'] });
      success('Bank account rejected.');
      setRejectOpen(false);
      setRejectionReason('');
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to reject'),
  });

  const handleRejectConfirm = () => {
    if (!rejectionReason.trim()) {
      setReasonError('Please provide a rejection reason.');
      return;
    }
    setReasonError('');
    rejectMutation.mutate(rejectionReason.trim());
  };

  const handleRejectClose = () => {
    setRejectOpen(false);
    setRejectionReason('');
    setReasonError('');
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-32 text-gray-400">
        Loading bank account details...
      </div>
    );
  }

  if (!account) {
    return (
      <div className="flex items-center justify-center py-32 text-gray-400">
        Bank account not found.
      </div>
    );
  }

  const isUnderReview = account.status === 'under_review';

  return (
    <div className="space-y-5 max-w-3xl">
      {/* Back + header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate('/bank-accounts')}
            className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <ArrowLeft size={18} className="text-gray-500" />
          </button>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-bold text-gray-900">{account.accountHolderName}</h2>
              <Badge status={account.status} size="md" />
            </div>
            <p className="text-sm text-gray-500 mt-0.5">{account.bankName}</p>
          </div>
        </div>

        {isUnderReview && (
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

      {/* Rejection reason banner */}
      {account.status === 'rejected' && account.rejectionReason && (
        <div className="bg-red-50 border border-red-100 rounded-xl px-5 py-4 flex gap-3">
          <XCircle size={18} className="text-red-500 shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-medium text-red-700">Rejection Reason</p>
            <p className="text-sm text-red-600 mt-0.5">{account.rejectionReason}</p>
          </div>
        </div>
      )}

      {/* Bank details */}
      <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-4">
        <div className="flex items-center gap-2 mb-1">
          <Landmark size={16} className="text-primary-600" />
          <h3 className="text-sm font-semibold text-gray-700">Bank Details</h3>
        </div>
        <div className="space-y-2.5">
          <InfoRow label="Account Holder" value={account.accountHolderName} />
          <InfoRow label="Bank Name" value={account.bankName} />
          <InfoRow label="Account Number" value={account.accountNumber} />
          <InfoRow label="IFSC Code" value={account.ifscCode} />
          <InfoRow label="Account Type" value={account.accountType} />
          <InfoRow label="Branch Name" value={account.branchName} />
        </div>
      </div>

      {/* Partner info */}
      {account.partner && (
        <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-4">
          <div className="flex items-center gap-2 mb-1">
            <User size={16} className="text-primary-600" />
            <h3 className="text-sm font-semibold text-gray-700">Partner</h3>
          </div>
          <div className="space-y-2.5">
            <InfoRow
              label="Name"
              value={
                `${(account.partner as any).firstName ?? account.partner.user?.firstName ?? ''} ${(account.partner as any).lastName ?? account.partner.user?.lastName ?? ''}`.trim() || undefined
              }
            />
            <InfoRow
              label="Email"
              value={(account.partner as any).email ?? account.partner.user?.email}
            />
            <InfoRow label="Business" value={(account.partner as any).businessName ?? account.partner.businessName} />
            <InfoRow
              label="Phone"
              value={(account.partner as any).phone ?? account.partner.user?.phone}
            />
          </div>
        </div>
      )}

      {/* Cancelled cheque */}
      {account.cancelledChequeUrl && (
        <div className="bg-white rounded-xl border border-gray-100 p-5">
          <div className="flex items-center gap-2 mb-3">
            <FileImage size={16} className="text-primary-600" />
            <h3 className="text-sm font-semibold text-gray-700">Cancelled Cheque</h3>
          </div>
          <a href={account.cancelledChequeUrl} target="_blank" rel="noreferrer">
            <img
              src={account.cancelledChequeUrl}
              alt="Cancelled cheque"
              className="w-full max-w-md rounded-lg border border-gray-200 object-cover hover:opacity-90 transition-opacity cursor-zoom-in"
            />
          </a>
        </div>
      )}

      {/* Review info */}
      {(account.reviewedAt || account.reviewedBy) && (
        <div className="bg-white rounded-xl border border-gray-100 p-5 space-y-2.5">
          <div className="flex items-center gap-2 mb-1">
            <CalendarClock size={16} className="text-primary-600" />
            <h3 className="text-sm font-semibold text-gray-700">Review Info</h3>
          </div>
          <InfoRow label="Reviewed By" value={account.reviewedBy} />
          <InfoRow
            label="Reviewed At"
            value={
              account.reviewedAt
                ? new Date(account.reviewedAt).toLocaleString('en-IN', {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                  })
                : undefined
            }
          />
          <InfoRow
            label="Submitted At"
            value={new Date(account.createdAt).toLocaleString('en-IN', {
              day: '2-digit',
              month: 'short',
              year: 'numeric',
              hour: '2-digit',
              minute: '2-digit',
            })}
          />
        </div>
      )}

      {/* Approve confirm */}
      <ConfirmDialog
        open={approveOpen}
        onCancel={() => setApproveOpen(false)}
        onConfirm={() => approveMutation.mutate()}
        title="Approve Bank Account"
        message={`Approve bank account for "${account.accountHolderName}" at ${account.bankName}? The partner will be notified.`}
        confirmLabel="Approve"
        variant="warning"
        loading={approveMutation.isPending}
      />

      {/* Reject modal */}
      <Modal open={rejectOpen} onClose={handleRejectClose} title="Reject Bank Account" size="md">
        <div className="space-y-4">
          <div className="flex gap-3">
            <div className="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center shrink-0">
              <XCircle size={20} className="text-red-600" />
            </div>
            <p className="text-sm text-gray-700 pt-2">
              Rejecting bank account for{' '}
              <span className="font-semibold text-gray-900">"{account.accountHolderName}"</span>.
              The partner will be notified with the reason below.
            </p>
          </div>

          <div>
            <label className="label">Rejection Reason *</label>
            <textarea
              rows={3}
              value={rejectionReason}
              onChange={(e) => { setRejectionReason(e.target.value); setReasonError(''); }}
              placeholder="Explain why this bank account submission is being rejected..."
              className="input resize-none"
            />
            {reasonError && <p className="mt-1 text-xs text-red-500">{reasonError}</p>}
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
