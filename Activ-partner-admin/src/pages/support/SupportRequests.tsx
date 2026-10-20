import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { ArrowLeft, ArrowRight, Mail, Paperclip } from 'lucide-react';
import { supportApi } from '../../api/support.api';
import { Pagination } from '../../components/ui/Pagination';
import { resolveAssetUrl } from '../../utils/documents';

export const SupportRequests: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const [page, setPage] = useState(1);
  const limit = 15;
  const list = useQuery({
    queryKey: ['support-requests', page],
    queryFn: () => supportApi.getRequests({ page, limit }),
    enabled: !id,
  });
  const detail = useQuery({
    queryKey: ['support-request', id],
    queryFn: () => supportApi.getRequestById(id!),
    enabled: !!id,
    retry: false,
  });
  const query = id ? detail : list;
  const request = detail.data?.data.data;
  const requests = list.data?.data.data;

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div>
          {id && <Link to="/support/requests" className="mb-3 inline-flex items-center gap-2 text-sm text-primary-700"><ArrowLeft size={16} /> All support requests</Link>}
          <h2 className="text-xl font-bold text-gray-900">{id ? 'Support Request' : 'Support Requests'}</h2>
          <p className="text-sm text-gray-500 mt-1">Messages submitted by partners</p>
        </div>
        <Link to="/support/callback" className="btn-secondary">Callback requests</Link>
      </div>

      {query.isLoading ? <p className="py-12 text-center text-gray-500">Loading...</p> : query.isError ? (
        <div role="alert" className="card p-6 text-center">
          <p className="text-gray-600">Could not load this {id ? 'request. It may have been deleted.' : 'list.'}</p>
          <button type="button" onClick={() => query.refetch()} className="btn-secondary mt-3">Try again</button>
        </div>
      ) : id && request ? (
        <article className="card p-5 sm:p-7 space-y-5">
          <div className="flex justify-between gap-4 flex-wrap">
            <h3 className="text-lg font-semibold text-gray-900 break-words"><Mail size={18} className="inline mr-2" />{request.subject}</h3>
            <span className="text-xs font-medium bg-primary-50 text-primary-700 rounded-full px-3 py-1 self-start">{request.status.replace(/_/g, ' ').toLowerCase()}</span>
          </div>
          <p className="text-xs text-gray-500">Submitted {new Date(request.created_at).toLocaleString('en-IN')}</p>
          <p className="whitespace-pre-wrap break-words text-sm text-gray-800">{request.message}</p>
          {Array.isArray(request.attachments) && request.attachments.length > 0 && (
            <div className="space-y-2 border-t border-gray-100 pt-4">
              <h4 className="text-sm font-semibold">Attachments</h4>
              {request.attachments.map((attachment, index) => (
                <a key={index} href={resolveAssetUrl(attachment.url)} target="_blank" rel="noreferrer" className="flex items-center gap-2 text-sm text-primary-700 underline break-all"><Paperclip size={14} />{attachment.originalName || `Attachment ${index + 1}`}</a>
              ))}
            </div>
          )}
        </article>
      ) : !id ? (
        <div className="card overflow-hidden">
          {(requests?.items ?? []).length === 0 ? <p className="py-12 text-center text-sm text-gray-500">No support requests yet.</p> : (
            <ul className="divide-y divide-gray-100">
              {requests!.items.map(item => (
                <li key={item.id}><Link to={`/support/requests/${encodeURIComponent(item.id)}`} className="flex items-center justify-between gap-4 p-5 hover:bg-primary-50/40">
                  <div className="min-w-0"><p className="font-medium text-gray-900 truncate">{item.subject}</p><p className="text-xs text-gray-500 mt-1">{item.status.replace(/_/g, ' ').toLowerCase()} · {new Date(item.created_at).toLocaleString('en-IN')}</p></div>
                  <ArrowRight size={16} className="shrink-0 text-primary-700" />
                </Link></li>
              ))}
            </ul>
          )}
          {(requests?.total ?? 0) > limit && <div className="border-t p-4"><Pagination page={page} limit={limit} total={requests!.total} onPageChange={setPage} /></div>}
        </div>
      ) : null}
    </div>
  );
};
