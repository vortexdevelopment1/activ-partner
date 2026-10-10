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
} from 'lucide-react';
import { useAuthStore } from '../../store/auth.store';

const navItems = [
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
];

export const Sidebar: React.FC = () => {
  const { logout } = useAuthStore();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <aside className="w-64 bg-white border-r border-gray-100 flex flex-col h-screen sticky top-0">
      {/* Logo */}
      <div className="px-6 py-5 border-b border-gray-100">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 bg-primary-600 rounded-lg flex items-center justify-center">
            <Zap size={16} className="text-white" />
          </div>
          <span className="text-lg font-bold text-gray-900">ActivProduct</span>
        </div>
        <p className="text-xs text-gray-400 mt-0.5 ml-10">Admin Panel</p>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
        {navItems.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all ${
                isActive
                  ? 'bg-primary-50 text-primary-700'
                  : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
              }`
            }
          >
            {({ isActive }) => (
              <>
                <Icon
                  size={18}
                  className={isActive ? 'text-primary-600' : 'text-gray-400'}
                />
                {label}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Logout */}
      <div className="px-3 py-4 border-t border-gray-100">
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-gray-600 hover:bg-red-50 hover:text-red-600 transition-all"
        >
          <LogOut size={18} className="text-gray-400" />
          Logout
        </button>
      </div>
    </aside>
  );
};
