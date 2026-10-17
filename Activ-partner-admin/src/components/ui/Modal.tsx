import React, { useEffect } from 'react';
import { X } from 'lucide-react';

export interface ModalProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  size?: 'sm' | 'md' | 'lg' | 'xl';
}

const sizes = { sm: 'max-w-sm', md: 'max-w-md', lg: 'max-w-lg', xl: 'max-w-2xl' };

export const Modal: React.FC<ModalProps> = ({ open, onClose, title, children, size = 'md' }) => {
  useEffect(() => {
    if (open) document.body.style.overflow = 'hidden';
    else document.body.style.overflow = '';
    return () => { document.body.style.overflow = ''; };
  }, [open]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center px-2 pb-2 pt-[max(0.75rem,env(safe-area-inset-top))] sm:items-center sm:p-4">
      <div className="absolute inset-0 bg-black/55 backdrop-blur-sm" onClick={onClose} />
      <div className={`relative flex flex-col overflow-hidden bg-white rounded-lg shadow-[0_24px_70px_rgb(8_20_17/0.24)] ring-1 ring-black/5 w-full ${sizes[size]} max-h-[calc(100dvh-1.5rem)] sm:max-h-[90vh]`}>
        <div className="flex shrink-0 items-center justify-between gap-2 p-4 sm:p-5 border-b border-gray-100">
          <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
          <button onClick={onClose} aria-label="Close dialog" className="p-1.5 rounded-lg hover:bg-gray-100 transition-colors">
            <X size={18} className="text-gray-500" />
          </button>
        </div>
        <div className="modal-scroll-body min-h-0 overflow-y-auto overscroll-contain p-4 sm:p-5">{children}</div>
      </div>
    </div>
  );
};
