import React from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

interface PaginationProps {
  page: number;
  totalPages?: number;
  total: number;
  limit: number;
  onPageChange: (page: number) => void;
}

export const Pagination: React.FC<PaginationProps> = ({ page, totalPages: totalPagesProp, total, limit, onPageChange }) => {
  const totalPages = totalPagesProp ?? Math.ceil(total / limit);
  const from = (page - 1) * limit + 1;
  const to = Math.min(page * limit, total);
  const visibleCount = Math.min(totalPages, 5);
  const firstPage = Math.max(1, Math.min(page - 2, totalPages - visibleCount + 1));
  const pageNumbers = Array.from({ length: visibleCount }, (_, index) => firstPage + index);

  return (
    <div className="flex flex-wrap items-center justify-between gap-2 px-4 py-3 border-t border-gray-100">
      <p className="text-sm text-gray-500">
        Showing <span className="font-medium">{total ? from : 0}</span> to <span className="font-medium">{to}</span> of{' '}
        <span className="font-medium">{total}</span> results
      </p>
      <div className="flex items-center gap-1">
        <button
          type="button" aria-label="Previous page"
          onClick={() => onPageChange(page - 1)}
          disabled={page <= 1}
          className="flex h-10 w-10 items-center justify-center rounded-lg hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <ChevronLeft size={16} />
        </button>
        <span className="px-2 text-xs font-medium text-gray-500 sm:hidden">Page {page} of {totalPages}</span>
        {pageNumbers.map((pageNum) => (
            <button
              key={pageNum}
              onClick={() => onPageChange(pageNum)}
              className={`hidden sm:block w-8 h-8 rounded-lg text-sm font-medium transition-colors ${
                page === pageNum ? 'bg-brand-ink text-brand-lime' : 'hover:bg-brand-bottom text-gray-600'
              }`}
            >
              {pageNum}
            </button>
        ))}
        <button
          type="button" aria-label="Next page"
          onClick={() => onPageChange(page + 1)}
          disabled={page >= totalPages}
          className="flex h-10 w-10 items-center justify-center rounded-lg hover:bg-gray-100 disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <ChevronRight size={16} />
        </button>
      </div>
    </div>
  );
};
