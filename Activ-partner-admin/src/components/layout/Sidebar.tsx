import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  Tag,
  HelpCircle,
  Building2,
  Users,
  Briefcase,
  Percent,
  ScrollText,
  LogOut,
  Landmark,
  PhoneCall,
  MessageCircleQuestion,
  FileCheck,
  ClipboardList,
  ListChecks,
  History,
} from 'lucide-react';
import { useAuthStore } from '../../store/auth.store';

export const navItems = [
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/categories', icon: Tag, label: 'Categories' },
  { to: '/questions', icon: HelpCircle, label: 'Questions' },
  { to: '/venues', icon: Building2, label: 'Venues' },
  { to: '/users', icon: Users, label: 'Users' },
  { to: '/partners', icon: Briefcase, label: 'Partners' },
  { to: '/commissions', icon: Percent, label: 'Commissions' },
  { to: '/faqs', icon: MessageCircleQuestion, label: 'FAQs' },
  { to: '/gst-verification', icon: FileCheck, label: 'GST Verification' },
  { to: '/venue-requests', icon: ClipboardList, label: 'Venue Requests' },
  { to: '/activity-approvals', icon: ListChecks, label: 'Activity Approvals' },
  { to: '/legal', icon: ScrollText, label: 'Legal' },
  { to: '/bank-accounts', icon: Landmark, label: 'Bank Accounts' },
  { to: '/support/callback', icon: PhoneCall, label: 'Support' },
  { to: '/support/requests', icon: MessageCircleQuestion, label: 'Support Requests' },
  { to: '/logs', icon: History, label: 'Logs' },
];

export const Sidebar: React.FC<{ mobileOpen: boolean; onClose: () => void }> = ({ mobileOpen, onClose }) => {
  const { logout } = useAuthStore();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <aside id="admin-navigation" className={`fixed inset-y-0 left-0 z-40 w-64 max-w-[85vw] bg-brand-top border-r border-[#dce4c7] flex flex-col transition-transform duration-200 lg:static lg:h-full lg:shrink-0 lg:translate-x-0 ${mobileOpen ? 'translate-x-0' : '-translate-x-full'}`}>
      {/* Logo */}
      <div className="px-6 py-6 border-b border-[#dce4c7]">
        <img src="/activ-partner-logo.png" alt="ACTIV Partner" className="w-32 h-auto" />
        <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-primary-700 mt-3">Admin workspace</p>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto [scrollbar-width:thin] [scrollbar-color:#c5cda9_transparent]">
        {navItems.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            onClick={onClose}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all ${
                isActive
                  ? 'bg-brand-ink text-brand-lime shadow-sm'
                  : 'text-gray-600 hover:bg-brand-bottom hover:text-black'
              }`
            }
          >
            {({ isActive }) => (
              <>
                <Icon
                  size={18}
                  className={isActive ? 'text-brand-lime' : 'text-gray-500'}
                />
                {label}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Logout */}
      <div className="px-3 py-4 border-t border-[#dce4c7] bg-brand-cream/50">
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-gray-600 hover:bg-red-50 hover:text-red-700 transition-all"
        >
          <LogOut size={18} className="text-gray-500" />
          Logout
        </button>
      </div>
    </aside>
  );
};
