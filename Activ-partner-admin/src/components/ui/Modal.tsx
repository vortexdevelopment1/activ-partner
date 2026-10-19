import React, { useEffect, useId, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';

export interface ModalProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  subtitle?: React.ReactNode;
  footer?: React.ReactNode;
}

const sizes = { sm: 'max-w-sm', md: 'max-w-md', lg: 'max-w-lg', xl: 'max-w-2xl' };
let openDialogs = 0;
let previousOverflow = '';

export const Modal: React.FC<ModalProps> = ({ open, onClose, title, children, size = 'md', subtitle, footer }) => {
  const titleId = useId();
  const dialogRef = useRef<HTMLDivElement>(null);
  const closeRef = useRef(onClose);
  closeRef.current = onClose;
  const [viewport, setViewport] = useState({ height: window.innerHeight, top: 0 });
  useEffect(() => {
    if (!open) return;
    if (openDialogs++ === 0) {
      previousOverflow = document.body.style.overflow;
      document.body.style.overflow = 'hidden';
    }
    const priorFocus = document.activeElement as HTMLElement | null;
    const updateViewport = () => setViewport({
      height: window.visualViewport?.height ?? window.innerHeight,
      top: window.visualViewport?.offsetTop ?? 0,
    });
    updateViewport();
    window.visualViewport?.addEventListener('resize', updateViewport);
    window.visualViewport?.addEventListener('scroll', updateViewport);
    window.addEventListener('resize', updateViewport);
    dialogRef.current?.focus();
    const keydown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !document.querySelector('[role="listbox"]')) closeRef.current();
      if (event.key !== 'Tab') return;
      const controls = dialogRef.current?.querySelectorAll<HTMLElement>('button:not(:disabled), a[href], input:not(:disabled):not([type="hidden"]), select:not(:disabled), textarea:not(:disabled), [tabindex="0"]');
      const visible = Array.from(controls ?? []).filter(control => control.getClientRects().length > 0);
      const first = visible[0];
      const last = visible[visible.length - 1];
      if (!first) { event.preventDefault(); dialogRef.current?.focus(); }
      else if (event.shiftKey && (document.activeElement === first || document.activeElement === dialogRef.current)) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && (document.activeElement === last || document.activeElement === dialogRef.current)) { event.preventDefault(); first.focus(); }
    };
    document.addEventListener('keydown', keydown);
    return () => {
      if (--openDialogs === 0) document.body.style.overflow = previousOverflow;
      window.visualViewport?.removeEventListener('resize', updateViewport);
      window.visualViewport?.removeEventListener('scroll', updateViewport);
      window.removeEventListener('resize', updateViewport);
      document.removeEventListener('keydown', keydown);
      if (priorFocus?.isConnected) priorFocus.focus();
    };
  }, [open]);

  if (!open) return null;

  return createPortal(
    <div className="fixed inset-x-0 z-50 flex items-center justify-center p-3 sm:p-5" style={{ top: viewport.top, height: viewport.height, paddingBottom: 'max(.75rem, env(safe-area-inset-bottom))' }}>
      <div className="absolute inset-0 bg-black/55 backdrop-blur-sm" onClick={onClose} />
      <div ref={dialogRef} role="dialog" aria-modal="true" aria-labelledby={titleId} tabIndex={-1} className={`relative min-w-0 flex flex-col overflow-hidden bg-white rounded-xl shadow-[0_24px_70px_rgb(8_20_17/0.24)] ring-1 ring-black/5 w-full ${sizes[size]} max-h-full outline-none`}>
        <div className="flex shrink-0 items-center justify-between gap-2 p-4 sm:p-5 border-b border-gray-100">
          <div className="min-w-0"><h3 id={titleId} className="text-lg font-semibold text-gray-900 [overflow-wrap:anywhere]">{title}</h3>{subtitle && <p className="mt-1 text-xs text-gray-500 [overflow-wrap:anywhere]">{subtitle}</p>}</div>
          <button type="button" onClick={onClose} aria-label="Close dialog" className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg hover:bg-gray-100 transition-colors">
            <X size={18} className="text-gray-500" />
          </button>
        </div>
        <div className="modal-scroll-body min-h-0 min-w-0 overflow-y-auto overscroll-contain p-4 sm:p-5">{children}</div>
        {footer && <div className="min-w-0 shrink-0 border-t border-gray-100 p-4 sm:p-5 [overflow-wrap:anywhere]">{footer}</div>}
      </div>
    </div>, document.body,
  );
};
