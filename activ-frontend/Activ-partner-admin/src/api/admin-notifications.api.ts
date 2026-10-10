import api from './axios';

export const adminNotificationsApi = {
  list: () => api.get('/admin/notifications'),
  unreadCount: () => api.get('/admin/notifications/unread-count'),
  markRead: (id: string) => api.patch(`/admin/notifications/${id}/read`),
  markAllRead: () => api.patch('/admin/notifications/read-all'),
};
