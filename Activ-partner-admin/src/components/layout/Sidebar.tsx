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
  Zap,
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
    <aside id="admin-navigation" className={`fixed inset-y-0 left-0 z-40 w-64 max-w-[85vw] bg-[#17211f] border-r border-white/5 flex flex-col transition-transform duration-200 lg:static lg:h-full lg:shrink-0 lg:translate-x-0 ${mobileOpen ? 'translate-x-0' : '-translate-x-full'}`}>
      {/* Logo */}
      <div className="px-5 py-5 border-b border-white/10">
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 bg-primary-500 rounded-lg flex items-center justify-center shadow-lg shadow-primary-900/30">
            <Zap size={16} className="text-white" />
          </div>
          <span className="text-lg font-bold text-white">ActivProduct</span>
        </div>
        <p className="text-[11px] font-medium uppercase tracking-[0.14em] text-gray-400 mt-1 ml-11">Admin workspace</p>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto [scrollbar-width:thin] [scrollbar-color:#3b4744_transparent]">
        {navItems.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            onClick={onClose}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all ${
                isActive
                  ? 'bg-primary-500 text-white shadow-sm'
                  : 'text-gray-300 hover:bg-white/[0.07] hover:text-white'
              }`
            }
          >
            {({ isActive }) => (
              <>
                <Icon
                  size={18}
                  className={isActive ? 'text-white' : 'text-gray-500'}
                />
                {label}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Logout */}
      <div className="px-3 py-4 border-t border-white/10">
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-gray-300 hover:bg-red-500/10 hover:text-red-300 transition-all"
        >
          <LogOut size={18} className="text-gray-500" />
          Logout
        </button>
      </div>
    </aside>
  );
};
