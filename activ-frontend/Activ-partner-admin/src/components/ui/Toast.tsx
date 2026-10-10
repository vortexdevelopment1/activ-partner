import React from 'react';
import { CheckCircle, XCircle, AlertCircle, Info, X } from 'lucide-react';
import { useToastStore } from '../../store/toast.store';

const icons = {
  success: <CheckCircle size={18} className="text-emerald-500" />,
  error:   <XCircle size={18} className="text-red-500" />,
  warning: <AlertCircle size={18} className="text-amber-500" />,
  info:    <Info size={18} className="text-blue-500" />,
};

const colors = {
  success: 'border-emerald-200 bg-emerald-50',
  error:   'border-red-200 bg-red-50',
  warning: 'border-amber-200 bg-amber-50',
  info:    'border-blue-200 bg-blue-50',
};

/** Global toast container — renders all toasts from the global store */
export const Toast: React.FC = () => {
  const { toasts, remove } = useToastStore();
  return (
    <div className="fixed top-4 right-4 z-[100] flex flex-col gap-2 w-80">
      {toasts.map((toast) => (
        <div key={toast.id} className={`flex items-start gap-3 p-3 rounded-xl border shadow-lg ${colors[toast.type]}`}>
          {icons[toast.type]}
          <p className="flex-1 text-sm text-gray-800">{toast.message}</p>
          <button onClick={() => remove(toast.id)} className="text-gray-400 hover:text-gray-600">
            <X size={14} />
          </button>
        </div>
      ))}
    </div>
  );
};
