import React, { useState } from 'react';
import { Check, ChevronDown, XCircle } from 'lucide-react';
import { Modal } from '../../components/ui/Modal';

const REJECTION_REASONS = [
  'Insufficient images (minimum 4 required)',
  'Missing required amenities',
  'Incomplete Q&A answers',
  'Activity description too brief',
  'Invalid pricing information',
  'Timing/slots not configured',
  'Does not meet quality standards',
  'Duplicate activity',
  'Other',
];

interface Props {
  open: boolean;
  activityName: string;
  onConfirm: (reason: string) => void;
  onCancel: () => void;
  loading?: boolean;
}

export const RejectActivityModal: React.FC<Props> = ({
  open, activityName, onConfirm, onCancel, loading,
}) => {
  const [reason, setReason] = useState('');
  const [notes, setNotes] = useState('');
  const [error, setError] = useState('');
  const [reasonsOpen, setReasonsOpen] = useState(false);

  const handleConfirm = () => {
    if (!reason) {
      setError('Please select a rejection reason.');
      return;
    }
    setError('');
    onConfirm(notes ? `${reason}: ${notes}` : reason);
  };

  const handleClose = () => {
    setReason('');
    setNotes('');
    setError('');
    setReasonsOpen(false);
    onCancel();
  };

  return (
    <Modal open={open} onClose={handleClose} title="Reject Activity" size="md">
      <div className="space-y-4">
        <div className="flex gap-3">
          <div className="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center shrink-0">
            <XCircle size={20} className="text-red-600" />
          </div>
          <p className="text-sm text-gray-700 pt-2">
            Rejecting{' '}
            <span className="font-semibold text-gray-900">"{activityName}"</span>.
            The partner will be notified with the reason below.
          </p>
        </div>

        <div>
          <label className="label">Rejection Reason *</label>
          <button
            type="button"
            aria-haspopup="listbox"
            aria-expanded={reasonsOpen}
            onClick={() => setReasonsOpen((current) => !current)}
            className={`input flex items-center justify-between gap-3 text-left ${reason ? 'text-gray-900' : 'text-gray-500'}`}
          >
            <span className="min-w-0 truncate">{reason || 'Select a reason...'}</span>
            <ChevronDown size={17} className={`shrink-0 text-gray-400 transition-transform ${reasonsOpen ? 'rotate-180' : ''}`} />
          </button>
          {reasonsOpen && (
            <div role="listbox" aria-label="Rejection reason" className="mt-1 max-h-52 overflow-y-auto overscroll-contain rounded-lg border border-gray-200 bg-white p-1 shadow-sm">
              {REJECTION_REASONS.map((item) => (
                <button
                  key={item}
                  type="button"
                  role="option"
                  aria-selected={reason === item}
                  onClick={() => {
                    setReason(item);
                    setError('');
                    setReasonsOpen(false);
                  }}
                  className={`flex w-full items-center justify-between gap-3 rounded-md px-3 py-2 text-left text-sm transition-colors ${
                    reason === item
                      ? 'bg-primary-50 font-medium text-primary-800'
                      : 'text-gray-700 hover:bg-gray-50'
                  }`}
                >
                  <span>{item}</span>
                  {reason === item && <Check size={16} className="shrink-0 text-primary-700" />}
                </button>
              ))}
            </div>
          )}
          {error && <p className="mt-1 text-xs text-red-500">{error}</p>}
        </div>

        <div>
          <label className="label">Additional Notes (optional)</label>
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
            className="bg-red-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-red-700 disabled:opacity-60 transition-colors"
          >
            {loading ? 'Rejecting...' : 'Reject Activity'}
          </button>
        </div>
      </div>
    </Modal>
  );
};
