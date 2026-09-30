import { useToastStore } from '../store/toast.store';

export type { ToastType } from '../store/toast.store';
export type { ToastItem as Toast } from '../store/toast.store';

export function useToast() {
  const { add } = useToastStore();
  return {
    success: (msg: string) => add('success', msg),
    error: (msg: string) => add('error', msg),
    warning: (msg: string) => add('warning', msg),
    info: (msg: string) => add('info', msg),
  };
}
