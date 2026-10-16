import type { ActivityLog } from '../../api/logs.api';

const resourceNames: Record<string, string> = {
  amenities: 'amenity',
  'bank-accounts': 'bank account',
  bookings: 'booking',
  categories: 'category',
  commission: 'commission rate',
  faqs: 'FAQ',
  legal: 'legal document',
  notifications: 'notification',
  'notification-preferences': 'notification preference',
  partners: 'partner',
  payments: 'payment',
  payouts: 'payout',
  questions: 'question',
  reviews: 'review',
  support: 'support request',
  team: 'team member',
  users: 'user',
  venues: 'venue',
};

export const resourceLabel = (resource: string) => resourceNames[resource] || resource.replace(/-/g, ' ');

export const actionLabel = (log: ActivityLog) => {
  if (log.action === 'partner.registered') return 'Create partner account';
  if (log.action === 'legal_content.published') return 'Publish legal document';

  const match = /^(GET|POST|PUT|PATCH|DELETE) (.+)$/.exec(log.action);
  if (!match) return log.action.replace(/[._]/g, ' ');
  const [, method, route] = match;
  const path = route.replace(/^\/api\/v\d+/, '');
  const decision = log.details?.decision;

  if (/\/venues\/admin\/:id\/approval$/.test(path)) {
    return decision === 'approved' ? 'Approve venue' : decision === 'rejected' ? 'Reject venue'
      : decision === 'pending' ? 'Request venue changes' : 'Review venue approval';
  }
  if (/\/venues\/admin\/activities\/:serviceId\/approval$/.test(path)) {
    return decision === 'approved' ? 'Approve activity' : decision === 'rejected' ? 'Reject activity' : 'Review activity approval';
  }
  if (/\/bank-accounts\/:id\/review$/.test(path)) {
    return decision === 'approved' ? 'Approve bank account' : decision === 'rejected' ? 'Reject bank account' : 'Review bank account';
  }
  if (/\/gst-verification\/:id\/(approve|reject)$/.test(path)) return path.endsWith('/approve') ? 'Approve GST verification' : 'Reject GST verification';
  if (/\/update-requests\/:requestId\/(approve|reject)$/.test(path)) return path.endsWith('/approve') ? 'Approve venue update' : 'Reject venue update';
  if (/\/bookings\/:id\/(cancel|confirm|complete|check-in|no-show)$/.test(path)) {
    const task = path.split('/').pop();
    return ({ cancel: 'Cancel booking', confirm: 'Confirm booking', complete: 'Complete booking',
      'check-in': 'Check in booking', 'no-show': 'Mark booking as no-show' } as Record<string, string>)[task || ''];
  }
  if (path.endsWith('/save-draft')) return 'Save activity draft';
  if (/\/activities\/:serviceId\/images$/.test(path)) return method === 'DELETE' ? 'Remove activity photos' : 'Upload activity photos';
  if (path.endsWith('/services/images')) return 'Upload service photos';
  if (path.endsWith('/answers')) return path.includes('/activities/') ? 'Save activity answers' : 'Save venue answers';
  if (path.endsWith('/amenities')) return 'Update activity amenities';
  if (path.endsWith('/management')) return method === 'DELETE' ? 'Remove activity management details' : 'Update activity management details';
  if (path.endsWith('/availability')) return 'Update venue availability';
  if (path.endsWith('/terms')) return 'Accept venue terms';
  if (path.endsWith('/legal')) return log.resource === 'venues' ? 'Update venue legal documents' : 'Update partner legal documents';
  if (path.endsWith('/update-request')) return 'Request venue update';
  if (path.endsWith('/gst-verification')) return 'Submit GST verification';
  if (path.endsWith('/avatar')) return 'Update partner photo';
  if (path.endsWith('/profile')) return 'Update partner profile';
  if (path.endsWith('/cover')) return 'Update service cover photo';
  if (path.endsWith('/set-primary')) return 'Set primary venue photo';
  if (path.endsWith('/walk-in')) return 'Create walk-in reservation';
  if (path.includes('/walk-in/') && method === 'DELETE') return 'Cancel walk-in reservation';
  if (path.endsWith('/activities/full') || path.endsWith('/activities')) return 'Add venue activity';
  if (path.endsWith('/create-order')) return 'Create payment order';
  if (path.endsWith('/verify') && log.resource === 'payments') return 'Verify payment';
  if (path.endsWith('/verify') && log.resource === 'partners') return 'Verify partner';
  if (path.endsWith('/callback')) return method === 'POST' ? 'Request support callback' : 'Update support callback';
  if (path.endsWith('/email')) return method === 'POST' ? 'Send support email' : 'Update support email';
  if (path.endsWith('/toggle-status')) return `Change ${resourceLabel(log.resource)} status`;
  if (path.endsWith('/toggle-active')) return 'Change activity availability';
  if (path.endsWith('/read-all') || path.endsWith('/read')) return 'Mark notifications as read';
  if (path.endsWith('/submit')) return path.includes('/activities/') ? 'Submit activity for review' : 'Submit venue for review';
  if (path.endsWith('/pause-bookings')) return 'Change booking availability';
  if (path.endsWith('/complete-profile')) return 'Complete partner profile';
  if (path.endsWith('/change-password')) return 'Change password';
  if (path.endsWith('/mark-welcome-seen') || path.endsWith('/mark-verified-seen')) return 'Mark notice as seen';
  if (path.endsWith('/reorder')) return 'Reorder questions';

  const segments = path.split('/').filter(Boolean).filter((part) => part !== 'admin' && !part.startsWith(':'));
  const primary = segments[0] === 'auth' ? 'account' : resourceLabel(log.resource);
  const suffix = segments.slice(1).filter((part) => part !== 'create' && part !== 'account')
    .map((part) => part.replace(/-/g, ' ')).join(' ');
  const verb = method === 'GET' ? 'Load' : method === 'POST' ? 'Create' : method === 'DELETE' ? 'Delete' : 'Update';
  return `${verb} ${primary}${suffix ? ` ${suffix}` : ''}`;
};

export const localDateBoundary = (date: string, nextDay = false) => {
  if (!date) return undefined;
  const [year, month, day] = date.split('-').map(Number);
  return new Date(year, month - 1, day + (nextDay ? 1 : 0)).toISOString();
};
