import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { transactionsApi, type TransactionView } from '../../api/transactions.api';
import { Badge } from '../../components/ui/Badge';
import { Pagination } from '../../components/ui/Pagination';
import { formatIndiaDateTime } from '../../utils/indiaDate';

const views: { value: TransactionView; label: string }[] = [
  { value: 'payments', label: 'Booking payments' },
  { value: 'refunds', label: 'Refunds' },
  { value: 'commissions', label: 'Commission estimates' },
  { value: 'payouts', label: 'Partner payouts' },
];
const limit = 25;
const formatAmount = (amount: number, currency: string) =>
  amount.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' ' + currency;

export function TransactionsList() {
  const [view, setView] = useState<TransactionView>('payments');
  const [page, setPage] = useState(1);
  const { data, isPending, isError, refetch } = useQuery({
    queryKey: ['admin-transactions', view, page],
    queryFn: () => transactionsApi.list(view, page, limit),
  });
  const showCommission = view === 'commissions';

  return (
    <div className="space-y-5">
      <h2 className="text-xl font-bold text-gray-900">Transactions</h2>
      <div className="rounded-xl border border-gray-100 bg-white">
        <div role="group" aria-label="Transaction type" className="flex flex-wrap gap-2 border-b border-gray-100 p-4">
          {views.map(({ value, label }) => (
            <button key={value} type="button" aria-pressed={view === value}
              className={view === value ? 'btn-primary' : 'btn-secondary'}
              onClick={() => { if (view !== value) { setView(value); setPage(1); } }}>
              {label}
            </button>
          ))}
        </div>
        {showCommission && (
          <p className="border-b border-gray-100 px-4 py-3 text-sm text-gray-600">
            Estimates for captured payments use the current venue rate and exclude refund adjustments.
          </p>
        )}
        {isPending ? (
          <p role="status" className="p-6 text-sm text-gray-500">Loading transactions…</p>
        ) : isError ? (
          <div className="flex flex-wrap items-center gap-3 p-6">
            <p role="alert" className="text-sm text-red-600">Could not load transactions.</p>
            <button type="button" className="btn-secondary" onClick={() => void refetch()}>Retry</button>
          </div>
        ) : (
          <>
            <div className="overflow-x-auto" role="region" aria-label="Transaction records" tabIndex={0}>
              <table className="w-full min-w-[48rem] text-left text-sm">
                <thead className="border-b border-gray-100 bg-gray-50 text-gray-600">
                  <tr>
                    {['Date (IST)', 'Reference', 'Parties', 'Amount', ...(showCommission ? ['Commission breakdown'] : []), 'Status'].map(label => (
                      <th key={label} scope="col" className="px-4 py-3 font-medium">{label}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 text-gray-900">
                  {data.items.map(row => (
                    <tr key={row.id}>
                      <td className="whitespace-nowrap px-4 py-3">{formatIndiaDateTime(row.date)}</td>
                      <td className="px-4 py-3">
                        <div className="break-all font-medium">{row.reference}</div>
                        <div className="text-xs text-gray-500">{[row.bookingReference, row.provider].filter(Boolean).join(' · ')}</div>
                      </td>
                      <td className="px-4 py-3">
                        {row.customer && <div className="text-gray-600">Customer · {row.customer}</div>}
                        <div>Partner · {row.partner}</div>
                        {row.venueId && <Link className="text-sm underline" to={`/venues/${row.venueId}`}>{row.venueName}</Link>}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 font-medium tabular-nums">{formatAmount(row.amount, row.currency)}</td>
                      {showCommission && (
                        <td className="whitespace-nowrap px-4 py-3 text-xs">
                          {row.commission && (
                            <>
                              <div>ACTIV ({row.commission.commissionPercent}%) · {formatAmount(row.commission.activCommission, row.currency)}</div>
                              <div>GST · {formatAmount(row.commission.gstOnCommission, row.currency)}</div>
                              <div>Partner net · {formatAmount(row.commission.netReceived, row.currency)}</div>
                            </>
                          )}
                        </td>
                      )}
                      <td className="px-4 py-3"><Badge status={row.status.toLowerCase().replace(/_/g, ' ')} /></td>
                    </tr>
                  ))}
                  {!data.items.length && (
                    <tr><td colSpan={showCommission ? 6 : 5} className="p-6 text-center text-gray-500">No transactions found.</td></tr>
                  )}
                </tbody>
              </table>
            </div>
            {data.total > 0 && <Pagination page={page} total={data.total} limit={limit} onPageChange={setPage} />}
          </>
        )}
      </div>
    </div>
  );
}
