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
    <header className="h-[68px] shrink-0 bg-white/95 border-b border-gray-200 grid grid-cols-[auto_1fr_auto] md:grid-cols-[1fr_minmax(20rem,42rem)_1fr] items-center gap-3 px-4 sm:px-6 sticky top-0 z-10 backdrop-blur-md">
      <div className="flex items-center gap-4 justify-self-start">
        <button type="button" onClick={onOpenMenu} aria-label="Open navigation" aria-controls="admin-navigation" className="lg:hidden p-2 -ml-2 rounded-lg text-gray-600 hover:bg-gray-100"><Menu size={22} /></button>
        {title && (
          <h1 className="text-lg font-semibold text-gray-900">{title}</h1>
        )}
      </div>

      <div className="flex min-w-0 w-full justify-center px-2 sm:px-4">
        <GlobalSearch />
      </div>

      <div className="flex items-center gap-3 justify-self-end">
        {/* Notifications */}
        <NotificationsDropdown />

        {/* User avatar */}
        <div className="flex items-center gap-2.5 pl-3 border-l border-gray-200">
          <div className="w-9 h-9 bg-[#17211f] rounded-full flex items-center justify-center ring-2 ring-gray-100">
            <span className="text-xs font-semibold text-white">
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
