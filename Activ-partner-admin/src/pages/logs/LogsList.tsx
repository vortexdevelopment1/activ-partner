import React, { useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { ArrowUpRight, Eye, RefreshCw, RotateCcw, Search, ScrollText, X } from 'lucide-react';
import { logsApi, type ActivityLog } from '../../api/logs.api';
import { Pagination } from '../../components/ui/Pagination';
import { actionLabel, localDateBoundary, resourceLabel } from './logPresentation';

const limit = 25;

export const LogsList: React.FC = () => {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [resource, setResource] = useState('');
  const [outcome, setOutcome] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [page, setPage] = useState(1);
  const [selectedLog, setSelectedLog] = useState<ActivityLog | null>(null);

  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => window.clearTimeout(timer);
  }, [search]);

  useEffect(() => {
    if (!selectedLog) return;
    const closeOnEscape = (event: KeyboardEvent) => { if (event.key === 'Escape') setSelectedLog(null); };
    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [selectedLog]);

  const { data: resourcesData } = useQuery({
    queryKey: ['admin-log-resources'],
    queryFn: logsApi.getResources,
  });
  const resources: string[] = resourcesData?.data?.data ?? [];

  const { data, isLoading, isError, isFetching, refetch } = useQuery({
    queryKey: ['admin-logs', debouncedSearch, resource, outcome, from, to, page],
    queryFn: () => logsApi.getAll({ page, limit, search: debouncedSearch || undefined,
      resource: resource || undefined, outcome: outcome || undefined,
      from: localDateBoundary(from), to: localDateBoundary(to, true) }),
    refetchInterval: 30000,
  });
  const logs: ActivityLog[] = data?.data?.data?.items ?? [];
  const total: number = data?.data?.data?.total ?? 0;
  const isVenueTarget = (log: ActivityLog) => log.resource === 'venues' && Boolean(log.targetId);
  const openVenue = (targetId: string) => navigate(`/venues/${encodeURIComponent(targetId)}`);

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Activity Logs</h2>
          <p className="text-sm text-gray-500 mt-0.5">{total.toLocaleString('en-IN')} recorded events, newest first</p>
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
            {resources.map((item) => <option key={item} value={item}>{resourceLabel(item)}</option>)}
          </select>
          <select aria-label="Result" className="input w-36" value={outcome}
            onChange={(event) => { setOutcome(event.target.value); setPage(1); }}>
            <option value="">All results</option>
            <option value="success">Success</option>
            <option value="failed">Failed</option>
          </select>
          <label className="flex items-center gap-2 text-xs text-gray-500">
            From
            <input type="date" aria-label="From date" className="input w-36" value={from} max={to || undefined}
              onChange={(event) => { setFrom(event.target.value); setPage(1); }} />
          </label>
          <label className="flex items-center gap-2 text-xs text-gray-500">
            To
            <input type="date" aria-label="To date" className="input w-36" value={to} min={from || undefined}
              onChange={(event) => { setTo(event.target.value); setPage(1); }} />
          </label>
          <button type="button" title="Reset filters" aria-label="Reset filters"
            onClick={() => { setSearch(''); setDebouncedSearch(''); setResource(''); setOutcome(''); setFrom(''); setTo(''); setPage(1); }}
            className="h-9 w-9 flex items-center justify-center rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50">
            <RotateCcw size={16} />
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                {['When', 'Action', 'Actor', 'Resource', 'Result', 'Target', ''].map((heading, index) =>
                  <th key={`${heading}-${index}`} className="text-left px-5 py-3 text-xs font-medium text-gray-400 uppercase">{heading}</th>)}
              </tr>
            </thead>
            <tbody>
              {isLoading ? <tr><td colSpan={7} className="text-center py-14 text-gray-400">Loading logs...</td></tr>
                : isError ? <tr><td colSpan={7} className="text-center py-14 text-red-500">Unable to load logs. Try refreshing.</td></tr>
                : logs.length === 0 ? <tr><td colSpan={7} className="text-center py-14 text-gray-400">
                  <ScrollText size={28} className="mx-auto mb-2 text-gray-300" />No activity found
                </td></tr>
                : logs.map((log) => {
                  const canOpenVenue = isVenueTarget(log);
                  return <tr key={log.id} className="border-b border-gray-50 hover:bg-gray-50/50">
                    <td className="px-5 py-3.5 text-gray-500 whitespace-nowrap" title={new Date(log.createdAt).toLocaleString('en-IN')}>
                      {new Date(log.createdAt).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' })}
                    </td>
                    <td className="px-5 py-3.5 font-medium text-gray-900 min-w-48">{actionLabel(log)}</td>
                    <td className="px-5 py-3.5 text-gray-600">{log.actor || 'System / unknown'}</td>
                    <td className="px-5 py-3.5 text-gray-600 capitalize">{resourceLabel(log.resource)}</td>
                    <td className="px-5 py-3.5">
                      <span className={`text-xs px-2 py-0.5 rounded-full ${log.details?.outcome === 'failed'
                        ? 'bg-red-50 text-red-600' : 'bg-emerald-50 text-emerald-700'}`}>
                        {log.details?.outcome === 'failed' ? 'Failed' : 'Success'}
                      </span>
                    </td>
                    <td className="px-5 py-3.5 text-gray-500">
                      {canOpenVenue ? <button type="button" onClick={() => openVenue(log.targetId)}
                        className="inline-flex items-center gap-1 text-primary-600 hover:underline" title={log.targetId}>
                        View venue <ArrowUpRight size={13} />
                      </button> : <span title={log.targetId}>{!log.targetId ? '—' : log.targetId.length > 16 ? `${log.targetId.slice(0, 8)}...` : log.targetId}</span>}
                    </td>
                    <td className="px-5 py-3.5">
                      <button type="button" onClick={() => setSelectedLog(log)} title="View event details"
                        aria-label={`View details for ${actionLabel(log)}`}
                        className="p-1.5 rounded-lg text-gray-500 hover:bg-gray-100 hover:text-gray-900">
                        <Eye size={17} />
                      </button>
                    </td>
                  </tr>;
                })}
            </tbody>
          </table>
        </div>
        {total > limit && <Pagination page={page} limit={limit} total={total} onPageChange={setPage} />}
      </div>

      {selectedLog && <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4"
        onMouseDown={(event) => { if (event.target === event.currentTarget) setSelectedLog(null); }}>
        <div role="dialog" aria-modal="true" aria-label="Event details"
          className="bg-white rounded-lg w-full max-w-lg shadow-xl p-5 space-y-4">
          <div className="flex items-start justify-between gap-3">
            <div>
              <h3 className="text-base font-semibold text-gray-900">{actionLabel(selectedLog)}</h3>
              <p className="text-sm text-gray-500 mt-1">{new Date(selectedLog.createdAt).toLocaleString('en-IN', { dateStyle: 'full', timeStyle: 'medium' })}</p>
            </div>
            <button type="button" onClick={() => setSelectedLog(null)} title="Close" aria-label="Close event details"
              className="p-1.5 rounded-lg text-gray-500 hover:bg-gray-100"><X size={18} /></button>
          </div>
          <dl className="grid grid-cols-[100px_minmax(0,1fr)] gap-x-4 gap-y-3 text-sm border-t border-gray-100 pt-4">
            <dt className="text-gray-500">Result</dt><dd className="text-gray-900">{selectedLog.details.outcome === 'failed' ? 'Failed' : 'Success'}{selectedLog.details.statusCode ? ` (HTTP ${selectedLog.details.statusCode})` : ''}</dd>
            <dt className="text-gray-500">Actor</dt><dd className="text-gray-900 break-words">{selectedLog.actor || 'System / unknown'}</dd>
            <dt className="text-gray-500">Resource</dt><dd className="text-gray-900 capitalize">{resourceLabel(selectedLog.resource)}</dd>
            {selectedLog.details.decision && <><dt className="text-gray-500">Decision</dt><dd className="text-gray-900 capitalize">{selectedLog.details.decision}</dd></>}
            <dt className="text-gray-500">Target</dt>
            <dd className="text-gray-900 break-all">
              {isVenueTarget(selectedLog) ? (
                <button
                  type="button"
                  onClick={() => openVenue(selectedLog.targetId)}
                  className="inline-flex items-center gap-1 text-primary-600 hover:underline"
                  title={selectedLog.targetId}
                >
                  View venue <ArrowUpRight size={13} />
                </button>
              ) : selectedLog.targetId || 'Not available'}
            </dd>
            <dt className="text-gray-500">Source</dt><dd className="text-gray-600 break-all font-mono text-xs">{selectedLog.action}</dd>
          </dl>
        </div>
      </div>}
    </div>
  );
};
