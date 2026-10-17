import React, { useEffect, useRef, useState } from 'react';
import { Check, ChevronDown } from 'lucide-react';

export interface SelectOption {
  value: string;
  label: string;
}

interface SelectMenuProps {
  value: string;
  options: SelectOption[];
  placeholder: string;
  onChange: (value: string) => void;
  ariaLabel: string;
  className?: string;
}

export const SelectMenu: React.FC<SelectMenuProps> = ({
  value, options, placeholder, onChange, ariaLabel, className = '',
}) => {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const selected = options.find((option) => option.value === value);

  useEffect(() => {
    if (!open) return;
    const close = (event: MouseEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    };
    const escape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', close);
    document.addEventListener('keydown', escape);
    return () => {
      document.removeEventListener('mousedown', close);
      document.removeEventListener('keydown', escape);
    };
  }, [open]);

  return (
    <div ref={rootRef} className={`relative min-w-0 ${className}`}>
      <button type="button" aria-label={ariaLabel} aria-haspopup="listbox" aria-expanded={open}
        onClick={() => setOpen((current) => !current)}
        className={`input flex w-full items-center justify-between gap-2 text-left ${selected ? 'text-gray-900' : 'text-gray-500'}`}>
        <span className="min-w-0 truncate">{selected?.label ?? placeholder}</span>
        <ChevronDown size={16} className={`shrink-0 text-gray-400 transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && (
        <div role="listbox" aria-label={ariaLabel}
          className="absolute left-0 right-0 top-full z-40 mt-1 max-h-[min(15rem,45dvh)] overflow-y-auto overscroll-contain rounded-lg border border-gray-200 bg-white p-1 shadow-xl">
          {options.map((option) => (
            <button key={option.value || '__empty'} type="button" role="option"
              aria-selected={value === option.value}
              onClick={() => { onChange(option.value); setOpen(false); }}
              className={`flex w-full items-center justify-between gap-2 rounded-md px-3 py-2 text-left text-sm transition-colors ${
                value === option.value ? 'bg-primary-50 font-medium text-primary-800' : 'text-gray-700 hover:bg-gray-50'
              }`}>
              <span className="min-w-0 break-words">{option.label}</span>
              {value === option.value && <Check size={15} className="shrink-0 text-primary-700" />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
};
