import type { ApiResponse, PaginatedData } from '../types';
import api from './axios';

export type TransactionView = 'payments' | 'refunds' | 'commissions' | 'payouts';

export interface Transaction {
  id: string;
  reference: string;
  amount: number;
  currency: string;
  status: string;
  date: string;
  partner: string;
  customer?: string;
  venueId?: string;
  venueName?: string;
  bookingReference?: string;
  provider?: string;
  commission?: {
    commissionPercent: number;
    activCommission: number;
    gstOnCommission: number;
    netReceived: number;
  };
}

export const transactionsApi = {
  list: async (view: TransactionView, page: number, limit: number) => {
    const response = await api.get<ApiResponse<PaginatedData<Transaction>>>('/admin/transactions', {
      params: { view, page, limit },
    });
    return response.data.data;
  },
};
