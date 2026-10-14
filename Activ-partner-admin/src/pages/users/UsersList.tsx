import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Search, ToggleLeft, ToggleRight, Users } from 'lucide-react';
import { usersApi } from '../../api/users.api';
import { Pagination } from '../../components/ui/Pagination';
import { useToast } from '../../hooks/useToast';
import type { User } from '../../types';

const ROLES = ['All', 'user', 'partner', 'admin'] as const;
type RoleFilter = (typeof ROLES)[number];

export const UsersList: React.FC = () => {
  const queryClient = useQueryClient();
  const { success, error } = useToast();
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState<RoleFilter>('All');
  const [page, setPage] = useState(1);
  const limit = 20;

  const { data, isLoading } = useQuery({
    queryKey: ['users', search, page],
    queryFn: () =>
      usersApi.getAll({
        search: search || undefined,
        page,
        limit,
      }),
  });

  const allUsers: User[] = data?.data?.data?.items ?? [];
  const users: User[] = roleFilter === 'All'
    ? allUsers
    : allUsers.filter((u) => u.role === roleFilter);
  const total: number = data?.data?.data?.total ?? 0;

  const toggleMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      usersApi.toggleActive(id, !isActive),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      success('User status updated');
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed'),
  });

  const ROLE_COLORS: Record<string, string> = {
    admin: 'bg-purple-100 text-purple-700',
    partner: 'bg-blue-100 text-blue-700',
    user: 'bg-gray-100 text-gray-600',
  };

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Users</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            Manage all registered users
          </p>
        </div>
        <div className="flex items-center gap-3">
          <select
            value={roleFilter}
            onChange={(e) => { setRoleFilter(e.target.value as RoleFilter); setPage(1); }}
            className="input w-36"
          >
            {ROLES.map((r) => (
              <option key={r} value={r}>
                {r === 'All' ? 'All roles' : r.charAt(0).toUpperCase() + r.slice(1)}
              </option>
            ))}
          </select>
          <div className="relative">
            <Search
              size={15}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
            />
            <input
              type="text"
              placeholder="Search users..."
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
              className="input pl-9 w-52"
            />
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100">
              {['User', 'Email', 'Phone', 'Role', 'Joined', 'Status', ''].map((h) => (
                <th
                  key={h}
                  className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase tracking-wide"
                >
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={7} className="text-center py-16 text-gray-400">
                  Loading...
                </td>
              </tr>
            ) : users.length === 0 ? (
              <tr>
                <td colSpan={7} className="text-center py-16">
                  <Users size={32} className="mx-auto text-gray-200 mb-2" />
                  <p className="text-gray-400 text-sm">No users found</p>
                </td>
              </tr>
            ) : (
              users.map((user) => (
                <tr key={user.id} className="border-b border-gray-50 hover:bg-gray-50/50">
                  <td className="px-5 py-3.5">
                    <div className="flex items-center gap-2.5">
                      <div className="w-8 h-8 bg-primary-100 rounded-full flex items-center justify-center text-xs font-semibold text-primary-700 shrink-0">
                        {user.firstName?.[0]?.toUpperCase()}
                      </div>
                      <p className="font-medium text-gray-900">
                        {user.firstName} {user.lastName}
                      </p>
                    </div>
                  </td>
                  <td className="px-5 py-3.5 text-gray-600">{user.email}</td>
                  <td className="px-5 py-3.5 text-gray-500">{user.phone ?? '—'}</td>
                  <td className="px-5 py-3.5">
                    <span
                      className={`text-xs font-medium px-2.5 py-0.5 rounded-full capitalize ${ROLE_COLORS[user.role] ?? 'bg-gray-100 text-gray-600'}`}
                    >
                      {user.role}
                    </span>
                  </td>
                  <td className="px-5 py-3.5 text-gray-400 text-xs">
                    {new Date(user.createdAt).toLocaleDateString('en-IN', {
                      day: '2-digit',
                      month: 'short',
                      year: 'numeric',
                    })}
                  </td>
                  <td className="px-5 py-3.5">
                    <span
                      className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                        user.isActive
                          ? 'bg-emerald-50 text-emerald-600'
                          : 'bg-red-50 text-red-600'
                      }`}
                    >
                      {user.isActive ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td className="px-5 py-3.5">
                    <button
                      onClick={() =>
                        toggleMutation.mutate({ id: user.id, isActive: user.isActive })
                      }
                      className={`p-1.5 rounded-lg transition-colors ${
                        user.isActive
                          ? 'text-emerald-500 hover:bg-red-50 hover:text-red-500'
                          : 'text-gray-400 hover:bg-emerald-50 hover:text-emerald-500'
                      }`}
                      title={user.isActive ? 'Deactivate' : 'Activate'}
                    >
                      {user.isActive ? (
                        <ToggleRight size={18} />
                      ) : (
                        <ToggleLeft size={18} />
                      )}
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>

        {total > limit && (
          <div className="px-5 py-4 border-t border-gray-50">
            <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
          </div>
        )}
      </div>
    </div>
  );
};
