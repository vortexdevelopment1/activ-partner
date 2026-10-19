import type { AdminNotification } from '../types';

type NotificationLink = Pick<AdminNotification, 'type' | 'data'>;

export function notificationDestination(notification: NotificationLink): string {
  const data = notification.data ?? {};
  const id = (key: string): string | undefined => {
    const value = data[key];
    return typeof value === 'string' && value.trim() ? encodeURIComponent(value.trim()) : undefined;
  };

  // Specific review requests take precedence over their parent venue.
  const requests = [
    ['venueRequestId', '/venue-requests'],
    ['bankAccountId', '/bank-accounts'],
    ['gstVerificationId', '/gst-verification'],
    ['callbackId', '/support/callback'],
    ['supportRequestId', '/support/requests'],
  ] as const;
  for (const [key, route] of requests) {
    const target = id(key);
    if (target) return `${route}/${target}`;
  }

  if (notification.type === 'activity_added' || notification.type === 'activity_submitted') return '/activity-approvals';
  if (notification.type === 'partner_profile_updated') return '/partners';
  const venueId = id('venueId');
  if (venueId) return `/venues/${venueId}`;

  // Older notifications may predate stored deep-link IDs. Open the relevant list.
  const type = String(notification.type);
  if (type.startsWith('venue_request_')) return '/venue-requests';
  if (type === 'support_requested') return '/support/requests';
  if (type === 'activity_removed' || type.startsWith('venue_')) return '/venues';
  if (type.startsWith('bank_')) return '/bank-accounts';
  if (type.startsWith('gst_')) return '/gst-verification';
  if (type.startsWith('callback_')) return '/support/callback';
  if (type.startsWith('partner_')) return '/partners';
  return '/dashboard';
}

interface NavigationActions {
  navigate: (destination: string) => void;
  markRead: (id: string) => Promise<unknown>;
  onRead: () => void;
  onReadError: () => void;
}

export function openAdminNotification(notification: AdminNotification, actions: NavigationActions): void {
  actions.navigate(notificationDestination(notification));
  if (!notification.isRead) {
    // Read status must never delay or prevent opening the notification target.
    void actions.markRead(notification.id).then(actions.onRead).catch(actions.onReadError);
  }
}
