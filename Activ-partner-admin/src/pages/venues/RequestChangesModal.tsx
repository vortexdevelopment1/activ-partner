import React, { useState } from 'react';
import { MessageSquare } from 'lucide-react';
import { Modal } from '../../components/ui/Modal';

const CHANGE_REASONS = [
  'Please upload clearer photos',
  'Business description is too short',
  'Please add operating hours',
  'GST/PAN number verification needed',
  'Please provide valid address',
  'Please add at least one service with pricing',
  'Additional documents required',
  'Phone number needs to be verified',
  'Other',
];

interface RequestChangesModalProps {
  open: boolean;
  venueName: string;
  onConfirm: (reason: string) => void;
  onCancel: () => void;
  loading?: boolean;
}

export const RequestChangesModal: React.FC<RequestChangesModalProps> = ({
  open,
  venueName,
  onConfirm,
  onCancel,
  loading,
}) => {
  const [reason, setReason] = useState('');
  const [notes, setNotes] = useState('');
  const [error, setError] = useState('');

  const handleConfirm = () => {
    if (!reason) {
      setError('Please select what changes are needed.');
      return;
    }
    setError('');
    const full = notes ? `${reason}. ${notes}` : reason;
    onConfirm(full);
  };

  const handleClose = () => {
    setReason('');
    setNotes('');
    setError('');
    onCancel();
  };

  return (
    <Modal open={open} onClose={handleClose} title="Request Changes" size="md">
      <div className="space-y-4">
        <div className="flex gap-3">
          <div className="w-10 h-10 bg-amber-100 rounded-full flex items-center justify-center shrink-0">
            <MessageSquare size={20} className="text-amber-600" />
          </div>
          <p className="text-sm text-gray-700 pt-2">
            Requesting changes for{' '}
            <span className="font-semibold text-gray-900">"{venueName}"</span>.
            The partner will need to update and resubmit.
          </p>
        </div>

        <div>
          <label className="label">Changes Required *</label>
          <select
            value={reason}
            onChange={(e) => { setReason(e.target.value); setError(''); }}
            className="input"
          >
            <option value="">Select what needs to change...</option>
            {CHANGE_REASONS.map((r) => (
              <option key={r} value={r}>
                {r}
              </option>
            ))}
          </select>
          {error && <p className="mt-1 text-xs text-red-500">{error}</p>}
        </div>

        <div>
          <label className="label">Detailed Instructions (optional)</label>
          <textarea
            rows={3}
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Give the partner specific guidance on what to fix..."
            className="input resize-none"
          />
        </div>

        <div className="flex justify-end gap-3 pt-1">
          <button type="button" onClick={handleClose} className="btn-secondary">
            Cancel
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            disabled={loading}
            className="bg-amber-500 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-amber-600 disabled:opacity-60 transition-colors"
          >
            {loading ? 'Sending...' : 'Request Changes'}
          </button>
        </div>
      </div>
    </Modal>
  );
};
