import React from 'react';
import { Menu } from 'lucide-react';
import { useAuthStore } from '../../store/auth.store';
import { NotificationsDropdown } from './NotificationsDropdown';
import { GlobalSearch } from './GlobalSearch';

interface HeaderProps {
  title?: string;
  onOpenMenu: () => void;
}

export const Header: React.FC<HeaderProps> = ({ title, onOpenMenu }) => {
  const { user } = useAuthStore();

  return (
    <header className="h-16 shrink-0 bg-white border-b border-gray-100 flex items-center justify-between px-4 sm:px-6 sticky top-0 z-10">
      <div className="flex items-center gap-4">
        <button type="button" onClick={onOpenMenu} aria-label="Open navigation" aria-controls="admin-navigation" className="lg:hidden p-2 -ml-2 rounded-lg text-gray-600 hover:bg-gray-100"><Menu size={22} /></button>
        {title && (
          <h1 className="text-lg font-semibold text-gray-900">{title}</h1>
        )}
      </div>

      <div className="flex items-center gap-3">
        <GlobalSearch />

        {/* Notifications */}
        <NotificationsDropdown />

        {/* User avatar */}
        <div className="flex items-center gap-2.5 pl-2 border-l border-gray-100">
          <div className="w-8 h-8 bg-primary-100 rounded-full flex items-center justify-center">
            <span className="text-xs font-semibold text-primary-700">
              {user?.firstName?.[0]?.toUpperCase() ?? 'A'}
            </span>
          </div>
          <div className="hidden sm:block">
            <p className="text-sm font-medium text-gray-900 leading-none">
              {user?.firstName} {user?.lastName}
            </p>
            <p className="text-xs text-gray-400 mt-0.5 capitalize">{user?.role}</p>
          </div>
        </div>
      </div>
    </header>
  );
};
