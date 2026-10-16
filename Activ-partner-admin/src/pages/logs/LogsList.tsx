import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { ArrowUpRight, RefreshCw, Search, ScrollText } from 'lucide-react';
import { logsApi, type ActivityLog } from '../../api/logs.api';
import { Pagination } from '../../components/ui/Pagination';

const limit = 25;
const resources = ['venues', 'partners', 'users', 'categories', 'questions', 'commission', 'faqs', 'legal', 'bank-accounts', 'support'] as const;

const describeAction = (action: string) => {
  if (!/^(POST|PUT|PATCH|DELETE) /.test(action)) return action.replace(/[._]/g, ' ');
  const [method, ...pathParts] = action.split(' ');
  const route = pathParts.join(' ').split('/').filter(Boolean).filter((part) => part !== 'api' && !/^v\d+$/.test(part) && part !== 'admin' && !part.startsWith(':'));
  const verb = { POST: 'Created', PUT: 'Updated', PATCH: 'Updated', DELETE: 'Deleted' }[method] || method;
  return `${verb} ${route.join(' / ').replace(/-/g, ' ') || 'record'}`;
};

export const LogsList: React.FC = () => {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [resource, setResource] = useState('');
  const [outcome, setOutcome] = useState('');
  const [page, setPage] = useState(1);

  const { data, isLoading, isError, isFetching, refetch } = useQuery({
    queryKey: ['admin-logs', search, resource, outcome, page],
    queryFn: () => logsApi.getAll({ page, limit, search: search.trim() || undefined, resource: resource || undefined, outcome: outcome || undefined }),
    refetchInterval: 30000,
  });
  const logs: ActivityLog[] = data?.data?.data?.items ?? [];
  const total: number = data?.data?.data?.total ?? 0;

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Activity Logs</h2>
          <p className="text-sm text-gray-500 mt-0.5">Recent account and platform changes</p>
        </div>
        <button type="button" onClick={() => void refetch()} disabled={isFetching}
          title="Refresh logs" aria-label="Refresh logs"
          className="h-9 w-9 flex items-center justify-center rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={16} className={isFetching ? 'animate-spin' : ''} />
        </button>
      </div>

      <div className="bg-white border border-gray-100 rounded-lg overflow-hidden">
        <div className="flex flex-wrap gap-3 p-4 border-b border-gray-100">
          <label className="relative flex-1 min-w-52">
            <span className="sr-only">Search logs</span>
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input className="input pl-9 w-full" placeholder="Search actions, people or IDs..." value={search}
              onChange={(event) => { setSearch(event.target.value); setPage(1); }} />
          </label>
          <select aria-label="Resource" className="input w-44" value={resource}
            onChange={(event) => { setResource(event.target.value); setPage(1); }}>
            <option value="">All resources</option>
            {resources.map((item) => <option key={item} value={item}>{item.replace(/-/g, ' ')}</option>)}
          </select>
          <select aria-label="Result" className="input w-36" value={outcome}
            onChange={(event) => { setOutcome(event.target.value); setPage(1); }}>
            <option value="">All results</option>
            <option value="success">Success</option>
            <option value="failed">Failed</option>
          </select>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                {['When', 'Action', 'Actor', 'Resource', 'Result', 'Target'].map((heading) =>
                  <th key={heading} className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase">{heading}</th>)}
              </tr>
            </thead>
            <tbody>
              {isLoading ? <tr><td colSpan={6} className="text-center py-14 text-gray-400">Loading logs...</td></tr>
                : isError ? <tr><td colSpan={6} className="text-center py-14 text-red-500">Unable to load logs. Try refreshing.</td></tr>
                : logs.length === 0 ? <tr><td colSpan={6} className="text-center py-14 text-gray-400">
                  <ScrollText size={28} className="mx-auto mb-2 text-gray-300" />No activity found
                </td></tr>
                : logs.map((log) => {
                  const canOpenVenue = log.resource === 'venues' && /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(log.targetId);
                  return <tr key={log.id} className="border-b border-gray-50 hover:bg-gray-50/50">
                    <td className="px-5 py-3.5 text-gray-500 whitespace-nowrap" title={new Date(log.createdAt).toLocaleString('en-IN')}>
                      {new Date(log.createdAt).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' })}
                    </td>
                    <td className="px-5 py-3.5 font-medium text-gray-900" title={log.action}>{describeAction(log.action)}</td>
                    <td className="px-5 py-3.5 text-gray-600">{log.actor || 'System / unknown'}</td>
                    <td className="px-5 py-3.5 text-gray-600 capitalize">{log.resource.replace(/-/g, ' ')}</td>
                    <td className="px-5 py-3.5">
                      <span className={`text-xs px-2 py-0.5 rounded-full ${log.details?.outcome === 'failed'
                        ? 'bg-red-50 text-red-600' : 'bg-emerald-50 text-emerald-700'}`}>
                        {log.details?.outcome === 'failed' ? 'Failed' : 'Success'}
                      </span>
                    </td>
                    <td className="px-5 py-3.5 text-gray-500">
                      {canOpenVenue ? <button type="button" onClick={() => navigate(`/venues/${log.targetId}`)}
                        className="inline-flex items-center gap-1 text-primary-600 hover:underline" title={log.targetId}>
                        View venue <ArrowUpRight size={13} />
                      </button> : <span title={log.targetId}>{!log.targetId ? '—' : log.targetId.length > 16 ? `${log.targetId.slice(0, 8)}...` : log.targetId}</span>}
                    </td>
                  </tr>;
                })}
            </tbody>
          </table>
        </div>
        {total > limit && <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />}
      </div>
    </div>
  );
};
