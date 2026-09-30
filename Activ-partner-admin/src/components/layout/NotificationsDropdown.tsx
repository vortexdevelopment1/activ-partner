import React, { useEffect, useRef, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Bell, CheckCheck, Radio } from 'lucide-react';
import { formatDistanceToNowStrict } from 'date-fns';
import { adminNotificationsApi } from '../../api/admin-notifications.api';
import type { AdminNotification } from '../../types';

const POLL_INTERVAL = 30_000;

export const NotificationsDropdown: React.FC = () => {
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const queryClient = useQueryClient();

  const { data: countData } = useQuery({
    queryKey: ['admin-notifications-unread-count'],
    queryFn: () => adminNotificationsApi.unreadCount(),
    refetchInterval: POLL_INTERVAL,
  });
  const unreadCount: number = countData?.data?.data?.count ?? 0;

  const { data: listData, isLoading } = useQuery({
    queryKey: ['admin-notifications-list'],
    queryFn: () => adminNotificationsApi.list(),
    refetchInterval: open ? POLL_INTERVAL : false,
    enabled: open,
  });
  const notifications: AdminNotification[] = listData?.data?.data ?? [];

  useEffect(() => {
    const onClickOutside = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener('mousedown', onClickOutside);
    return () => document.removeEventListener('mousedown', onClickOutside);
  }, []);

  const handleMarkAllRead = async () => {
    await adminNotificationsApi.markAllRead();
    queryClient.invalidateQueries({ queryKey: ['admin-notifications-unread-count'] });
    queryClient.invalidateQueries({ queryKey: ['admin-notifications-list'] });
  };

  const handleItemClick = async (n: AdminNotification) => {
    if (!n.isRead) {
      await adminNotificationsApi.markRead(n.id);
      queryClient.invalidateQueries({ queryKey: ['admin-notifications-unread-count'] });
      queryClient.invalidateQueries({ queryKey: ['admin-notifications-list'] });
    }
  };

  return (
    <div className="relative" ref={containerRef}>
      <button
        onClick={() => setOpen((v) => !v)}
        className="relative p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-50 rounded-lg"
      >
        <Bell size={18} />
        {unreadCount > 0 && (
          <span className="absolute top-0.5 right-0.5 min-w-[16px] h-4 px-1 bg-red-500 rounded-full text-[10px] leading-4 text-white text-center font-medium">
            {unreadCount > 99 ? '99+' : unreadCount}
          </span>
        )}
      </button>

      {open && (
        <div className="absolute right-0 mt-2 w-96 bg-white rounded-xl shadow-xl border border-gray-100 z-20 overflow-hidden">
          <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100">
            <h4 className="text-sm font-semibold text-gray-900">Notifications</h4>
            {unreadCount > 0 && (
              <button
                onClick={handleMarkAllRead}
                className="flex items-center gap-1 text-xs font-medium text-primary-600 hover:text-primary-700"
              >
                <CheckCheck size={13} />
                Mark all read
              </button>
            )}
          </div>

          <div className="max-h-96 overflow-y-auto">
            {isLoading ? (
              <p className="text-center text-sm text-gray-400 py-10">Loading...</p>
            ) : notifications.length === 0 ? (
              <div className="text-center py-10">
                <Radio size={24} className="mx-auto text-gray-200 mb-2" />
                <p className="text-sm text-gray-400">No notifications yet</p>
              </div>
            ) : (
              notifications.map((n) => (
                <button
                  key={n.id}
                  onClick={() => handleItemClick(n)}
                  className={`w-full text-left px-4 py-3 border-b border-gray-50 last:border-0 hover:bg-gray-50/70 transition-colors ${
                    !n.isRead ? 'bg-primary-50/40' : ''
                  }`}
                >
                  <div className="flex items-start gap-2.5">
                    {!n.isRead && (
                      <span className="w-1.5 h-1.5 rounded-full bg-primary-500 mt-1.5 shrink-0" />
                    )}
                    <div className={n.isRead ? 'pl-4' : ''}>
                      <p className="text-sm font-medium text-gray-900">{n.title}</p>
                      <p className="text-xs text-gray-500 mt-0.5">{n.body}</p>
                      <p className="text-[11px] text-gray-400 mt-1">
                        {formatDistanceToNowStrict(new Date(n.createdAt), { addSuffix: true })}
                      </p>
                    </div>
                  </div>
                </button>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
};
