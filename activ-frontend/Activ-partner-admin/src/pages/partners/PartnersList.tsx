import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Search, Briefcase, ToggleLeft, ToggleRight, ExternalLink, Trash2 } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { partnersApi } from '../../api/partners.api';
import { Pagination } from '../../components/ui/Pagination';
import { ConfirmDialog } from '../../components/common/ConfirmDialog';
import { useToast } from '../../hooks/useToast';
import type { Partner } from '../../types';

export const PartnersList: React.FC = () => {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { success, error } = useToast();
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [deleteLabel, setDeleteLabel] = useState('');
  const limit = 20;

  const { data, isLoading } = useQuery({
    queryKey: ['partners', page],
    queryFn: () => partnersApi.getAll({ page, limit }),
  });

  const allPartners: Partner[] = data?.data?.data?.items ?? [];
  const partners: Partner[] = search
    ? allPartners.filter((p) => {
        const term = search.toLowerCase();
        const flat = p as any;
        return (
          flat.firstName?.toLowerCase().includes(term) ||
          flat.lastName?.toLowerCase().includes(term) ||
          flat.email?.toLowerCase().includes(term) ||
          flat.phone?.toLowerCase().includes(term) ||
          p.businessName?.toLowerCase().includes(term)
        );
      })
    : allPartners;
  const total: number = data?.data?.data?.total ?? 0;

  const deleteMutation = useMutation({
    mutationFn: (id: string) => partnersApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['partners'] });
      success('Partner and all associated venues deleted');
      setDeleteId(null);
      setDeleteLabel('');
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to delete partner'),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      partnersApi.toggleActive(id, !isActive),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['partners'] });
      success('Partner status updated');
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed'),
  });

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Partners</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            Manage venue partners and their business details
          </p>
        </div>
        <div className="relative">
          <Search
            size={15}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
          />
          <input
            type="text"
            placeholder="Search partners..."
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            className="input pl-9 w-52"
          />
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100">
              {['Partner', 'Email', 'Phone', 'Verified', 'Status', 'Venues', ''].map((h) => (
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
            ) : partners.length === 0 ? (
              <tr>
                <td colSpan={7} className="text-center py-16">
                  <Briefcase size={32} className="mx-auto text-gray-200 mb-2" />
                  <p className="text-gray-400 text-sm">No partners found</p>
                </td>
              </tr>
            ) : (
              partners.map((partner) => {
                const p = partner as any;
                const firstName: string = p.firstName ?? partner.user?.firstName ?? '';
                const lastName: string = p.lastName ?? partner.user?.lastName ?? '';
                const email: string = p.email ?? partner.user?.email ?? '';
                const phone: string = p.phone ?? partner.user?.phone ?? '';
                const initials = firstName?.[0]?.toUpperCase() ?? 'P';
                return (
                  <tr
                    key={partner.id}
                    className="border-b border-gray-50 hover:bg-gray-50/50"
                  >
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-2.5">
                        <div className="w-8 h-8 bg-primary-100 rounded-full flex items-center justify-center text-xs font-semibold text-primary-700 shrink-0">
                          {initials}
                        </div>
                        <div>
                          <p className="font-medium text-gray-900">
                            {firstName || lastName ? `${firstName} ${lastName}`.trim() : '—'}
                          </p>
                          {partner.businessName && (
                            <p className="text-xs text-gray-400">{partner.businessName}</p>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-3.5 text-gray-600 text-sm">
                      {email || <span className="text-gray-300">—</span>}
                    </td>
                    <td className="px-5 py-3.5 text-gray-600 text-sm">
                      {phone || <span className="text-gray-300">—</span>}
                    </td>
                    <td className="px-5 py-3.5">
                      <span
                        className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                          partner.isVerified
                            ? 'bg-emerald-50 text-emerald-600'
                            : 'bg-amber-50 text-amber-600'
                        }`}
                      >
                        {partner.isVerified ? 'Verified' : 'Pending'}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      <span
                        className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                          partner.isActive
                            ? 'bg-emerald-50 text-emerald-600'
                            : 'bg-red-50 text-red-600'
                        }`}
                      >
                        {partner.isActive ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      <button
                        onClick={() => navigate(`/venues?partnerId=${partner.id}`)}
                        className="text-xs text-primary-600 font-medium flex items-center gap-1 hover:underline"
                      >
                        <ExternalLink size={11} /> View venues
                      </button>
                    </td>
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-1">
                        <button
                          onClick={() =>
                            toggleMutation.mutate({
                              id: partner.id,
                              isActive: partner.isActive,
                            })
                          }
                          className={`p-1.5 rounded-lg transition-colors ${
                            partner.isActive
                              ? 'text-emerald-500 hover:bg-red-50 hover:text-red-500'
                              : 'text-gray-400 hover:bg-emerald-50 hover:text-emerald-500'
                          }`}
                          title={partner.isActive ? 'Deactivate' : 'Activate'}
                        >
                          {partner.isActive ? (
                            <ToggleRight size={18} />
                          ) : (
                            <ToggleLeft size={18} />
                          )}
                        </button>
                        <button
                          onClick={() => {
                            setDeleteId(partner.id);
                            const label = `${firstName} ${lastName}`.trim() || phone || partner.id;
                            setDeleteLabel(label);
                          }}
                          className="p-1.5 rounded-lg text-gray-300 hover:text-red-500 hover:bg-red-50 transition-colors"
                          title="Delete partner"
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>

        {total > limit && (
          <div className="px-5 py-4 border-t border-gray-50">
            <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />
          </div>
        )}
      </div>

      <ConfirmDialog
        open={!!deleteId}
        title="Delete Partner"
        message={`Deleting "${deleteLabel}" will permanently remove the partner, all their venues, and all associated data (services, images, answers). Team members will also be deleted. This cannot be undone.`}
        confirmLabel="Delete"
        variant="danger"
        loading={deleteMutation.isPending}
        onConfirm={() => deleteId && deleteMutation.mutate(deleteId)}
        onCancel={() => { setDeleteId(null); setDeleteLabel(''); }}
      />
    </div>
  );
};
