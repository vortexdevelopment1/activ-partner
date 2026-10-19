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
    <header className="h-[68px] min-w-0 shrink-0 bg-brand-top/95 border-b border-[#dce4c7] grid grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-2 px-3 sm:gap-3 sm:px-6 sticky top-0 z-20">
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
          <div className="w-9 h-9 bg-brand-ink rounded-full flex items-center justify-center ring-2 ring-brand-bottom">
            <span className="text-xs font-semibold text-brand-lime">
              {user?.firstName?.[0]?.toUpperCase() ?? 'A'}
            </span>
          </div>
          <div className="hidden min-w-0 max-w-[8rem] xl:max-w-[12rem] sm:block">
            <p className="truncate text-sm font-medium text-gray-900 leading-none">
              {user?.firstName} {user?.lastName}
            </p>
            <p className="text-xs text-gray-400 mt-0.5 capitalize">{user?.role}</p>
          </div>
        </div>
      </div>
    </header>
  );
};
