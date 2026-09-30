import React from 'react';
import { VenueStatus } from '../../types';

interface BadgeProps {
  status: VenueStatus | 'active' | 'inactive' | string;
  size?: 'sm' | 'md';
}

const config: Record<string, string> = {
  pending:      'bg-amber-100 text-amber-700',
  approved:     'bg-emerald-100 text-emerald-700',
  rejected:     'bg-red-100 text-red-600',
  suspended:    'bg-orange-100 text-orange-700',
  draft:        'bg-gray-100 text-gray-600',
  active:       'bg-emerald-100 text-emerald-700',
  inactive:     'bg-gray-100 text-gray-500',
  confirmed:    'bg-emerald-100 text-emerald-700',
  cancelled:    'bg-red-100 text-red-600',
  completed:    'bg-blue-100 text-blue-700',
  'on-hold':    'bg-gray-100 text-gray-600',
  'on_hold':    'bg-gray-100 text-gray-600',
  under_review: 'bg-amber-100 text-amber-700',
  in_progress:  'bg-blue-100 text-blue-700',
  resolved:     'bg-emerald-100 text-emerald-700',
};

export const Badge: React.FC<BadgeProps> = ({ status, size = 'sm' }) => {
  const cls = config[status?.toLowerCase()] ?? 'bg-gray-100 text-gray-600';
  return (
    <span className={`inline-flex items-center rounded-full font-medium capitalize ${size === 'sm' ? 'px-2.5 py-0.5 text-xs' : 'px-3 py-1 text-sm'} ${cls}`}>
      {status?.replace('_', ' ')}
    </span>
  );
};
