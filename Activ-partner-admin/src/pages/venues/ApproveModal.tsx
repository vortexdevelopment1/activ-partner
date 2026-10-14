import React from 'react';
import { CheckCircle } from 'lucide-react';
import { Modal } from '../../components/ui/Modal';

interface ApproveModalProps {
  open: boolean;
  venueName: string;
  onConfirm: () => void;
  onCancel: () => void;
  loading?: boolean;
}

export const ApproveModal: React.FC<ApproveModalProps> = ({
  open,
  venueName,
  onConfirm,
  onCancel,
  loading,
}) => {
  return (
    <Modal open={open} onClose={onCancel} title="Approve Venue" size="sm">
      <div className="space-y-4">
        <div className="flex gap-3">
          <div className="w-10 h-10 bg-emerald-100 rounded-full flex items-center justify-center shrink-0">
            <CheckCircle size={20} className="text-emerald-600" />
          </div>
          <div>
            <p className="text-sm text-gray-700">
              You are about to approve{' '}
              <span className="font-semibold text-gray-900">"{venueName}"</span>.
            </p>
            <p className="text-sm text-gray-500 mt-1">
              The venue will become visible to users and the partner will be
              notified.
            </p>
          </div>
        </div>

        <div className="flex justify-end gap-3 pt-2">
          <button type="button" onClick={onCancel} className="btn-secondary">
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={loading}
            className="bg-emerald-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-emerald-700 disabled:opacity-60 transition-colors"
          >
            {loading ? 'Approving...' : 'Approve Venue'}
          </button>
        </div>
      </div>
    </Modal>
  );
};
