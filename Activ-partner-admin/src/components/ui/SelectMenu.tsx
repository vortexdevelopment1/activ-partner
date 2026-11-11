import React, { useEffect, useRef, useState } from 'react';
import { Check, ChevronDown } from 'lucide-react';
import { createPortal } from 'react-dom';
import { floatingPanel } from '../../utils/floatingPanel';

export interface SelectOption {
  value: string;
  label: string;
  color?: string;
}

export const getStatusDotClass = (color?: string, text?: string): string | null => {
  if (color === 'emerald' || color === 'green') return 'bg-emerald-500';
  if (color === 'amber' || color === 'yellow') return 'bg-amber-500';
  if (color === 'red' || color === 'rose') return 'bg-rose-500';
  const lower = (text || '').toLowerCase().trim();
  if (lower === 'active' || lower === 'approved') return 'bg-emerald-500';
  if (lower === 'pending' || lower === 'under review' || lower === 'under_review') return 'bg-amber-500';
  if (lower === 'suspended' || lower === 'rejected' || lower === 'inactive') return 'bg-rose-500';
  return null;
};

export const formatStatusLabel = (status: string): string => {
  if (!status) return '';
  return status
    .toLowerCase()
    .split(/[_\s]+/)
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
};

interface SelectMenuProps {
  value: string;
  options: SelectOption[];
  placeholder: string;
  onChange: (value: string) => void;
  ariaLabel: string;
  className?: string;
  disabled?: boolean;
}

export const SelectMenu: React.FC<SelectMenuProps> = ({
  value, options, placeholder, onChange, ariaLabel, className = '', disabled = false,
}) => {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);
  const [position, setPosition] = useState<ReturnType<typeof floatingPanel> | null>(null);
  const selected = options.find(
    (option) =>
      option.value === value ||
      option.value.toUpperCase() === value?.toUpperCase() ||
      option.label.toLowerCase() === value?.toLowerCase()
  );
  const displayLabel = selected?.label ?? (value ? formatStatusLabel(value) : placeholder);
  const dotClass = getStatusDotClass(selected?.color, displayLabel);
  const isPlaceholder = !selected && !value;
  const ready = open && position !== null;

  useEffect(() => {
    if (disabled && open) setOpen(false);
  }, [disabled, open]);
  useEffect(() => {
    if (ready) {
      const option = panelRef.current?.querySelector<HTMLButtonElement>('[aria-selected="true"]')
        ?? panelRef.current?.querySelector<HTMLButtonElement>('[role="option"]');
      option?.focus({ preventScroll: true });
    }
  }, [ready]);

  useEffect(() => {
    if (!open) return;
    const update = () => {
      if (!buttonRef.current) return;
      const viewport = window.visualViewport;
      setPosition(floatingPanel(buttonRef.current.getBoundingClientRect(), {
        left: viewport?.offsetLeft ?? 0, top: viewport?.offsetTop ?? 0,
        width: viewport?.width ?? window.innerWidth, height: viewport?.height ?? window.innerHeight,
      }));
    };
    update();
    window.addEventListener('resize', update);
    window.addEventListener('scroll', update, true);
    window.visualViewport?.addEventListener('resize', update);
    const close = (event: MouseEvent) => {
      if (!rootRef.current?.contains(event.target as Node) && !panelRef.current?.contains(event.target as Node)) setOpen(false);
    };
    const escape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') { setOpen(false); buttonRef.current?.focus(); }
    };
    document.addEventListener('mousedown', close);
    document.addEventListener('keydown', escape);
    return () => {
      document.removeEventListener('mousedown', close);
      document.removeEventListener('keydown', escape);
      window.removeEventListener('resize', update);
      window.removeEventListener('scroll', update, true);
      window.visualViewport?.removeEventListener('resize', update);
    };
  }, [open]);

  return (
    <div ref={rootRef} className={`relative min-w-0 ${className}`}>
      <button ref={buttonRef} type="button" aria-label={ariaLabel} aria-haspopup="listbox" aria-expanded={open}
        disabled={disabled}
        onKeyDown={event => { if (!disabled && (event.key === 'ArrowDown' || event.key === 'ArrowUp')) { event.preventDefault(); setOpen(true); } }}
        onClick={() => { if (!disabled) setOpen((current) => !current); }}
        onChange={(event: any) => onChange(event?.target?.value ?? event)}
        className={`input flex w-full items-center justify-between gap-2 text-left text-sm font-normal disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-400 ${!isPlaceholder ? 'text-gray-900' : 'text-gray-500'}`}>
        <span className="flex min-w-0 items-center gap-2 truncate text-sm font-normal leading-normal">
          {dotClass && <span className={`inline-block h-2 w-2 shrink-0 rounded-full ${dotClass}`} aria-hidden="true" />}
          <span className="truncate">{displayLabel}</span>
        </span>
        <ChevronDown size={16} className={`shrink-0 text-gray-400 transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && position && createPortal(
        <div ref={panelRef} role="listbox" aria-label={ariaLabel}
          onKeyDown={(event) => {
            if (event.key === 'Escape') { event.stopPropagation(); setOpen(false); buttonRef.current?.focus(); }
            if (event.key === 'Tab') { setOpen(false); buttonRef.current?.focus(); }
            if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
              event.preventDefault();
              const items = Array.from(panelRef.current?.querySelectorAll<HTMLButtonElement>('[role="option"]') ?? []);
              const current = items.indexOf(document.activeElement as HTMLButtonElement);
              const next = event.key === 'Home' ? 0 : event.key === 'End' ? items.length - 1
                : event.key === 'ArrowDown' ? Math.min(current + 1, items.length - 1) : Math.max(current - 1, 0);
              items[next]?.focus();
            }
          }}
          style={{ position: 'fixed', left: position.left, top: position.top, width: position.width,
            maxHeight: position.maxHeight, transform: position.opensUp ? 'translateY(-100%)' : undefined }}
          className="admin-popover z-[80] overflow-y-auto overscroll-contain rounded-lg border border-gray-200 bg-white p-1 shadow-xl">
          {options.map((option) => {
            const isSelected = value === option.value ||
              option.value.toUpperCase() === value?.toUpperCase() ||
              option.label.toLowerCase() === value?.toLowerCase();
            const optDot = getStatusDotClass(option.color, option.label);
            return (
              <button key={option.value || '__empty'} type="button" role="option"
                aria-selected={isSelected}
                onClick={() => { onChange(option.value); setOpen(false); buttonRef.current?.focus(); }}
                className={`flex min-h-11 w-full items-center justify-between gap-2 rounded-md px-3 py-2 text-left text-sm transition-colors ${
                  isSelected ? 'bg-primary-50 font-medium text-primary-800' : 'text-gray-700 hover:bg-gray-50'
                }`}>
                <span className="flex items-center gap-2 min-w-0 break-words">
                  {optDot && <span className={`inline-block h-2 w-2 shrink-0 rounded-full ${optDot}`} aria-hidden="true" />}
                  <span>{option.label}</span>
                </span>
                {isSelected && <Check size={15} className="shrink-0 text-primary-700" />}
              </button>
            );
          })}
        </div>, document.body,
      )}
    </div>
  );
};
