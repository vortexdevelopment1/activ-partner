import React from 'react';
import { AlertTriangle } from 'lucide-react';
import { Modal } from '../ui/Modal';

export interface ConfirmDialogProps {
  open: boolean;
  onCancel: () => void;
  onConfirm: () => void;
  title?: string;
  message: string;
  confirmLabel?: string;
  variant?: 'danger' | 'warning';
  loading?: boolean;
}

export const ConfirmDialog: React.FC<ConfirmDialogProps> = ({
  open, onCancel, onConfirm, title = 'Confirm Action',
  message, confirmLabel = 'Confirm', variant = 'danger', loading = false,
}) => (
  <Modal open={open} onClose={onCancel} title={title} size="sm">
    <div className="flex flex-col items-center text-center gap-4">
      <div className={`w-12 h-12 rounded-full flex items-center justify-center ${variant === 'danger' ? 'bg-red-100' : 'bg-amber-100'}`}>
        <AlertTriangle size={22} className={variant === 'danger' ? 'text-red-500' : 'text-amber-500'} />
      </div>
      <p className="text-gray-600 text-sm">{message}</p>
      <div className="flex gap-3 w-full">
        <button onClick={onCancel} className="flex-1 btn-secondary">Cancel</button>
        <button
          onClick={onConfirm}
          disabled={loading}
          className={`flex-1 ${variant === 'danger' ? 'btn-danger' : 'btn-primary'}`}
        >
          {loading ? 'Processing...' : confirmLabel}
        </button>
      </div>
    </div>
  </Modal>
);
