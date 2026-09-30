import api from './axios';

export const bankAccountsApi = {
  submit: (data: {
    accountHolderName: string;
    bankName: string;
    accountNumber: string;
    ifscCode: string;
    accountType: string;
    branchName?: string;
    cancelledCheque?: File;
  }) => {
    const formData = new FormData();
    formData.append('accountHolderName', data.accountHolderName);
    formData.append('bankName', data.bankName);
    formData.append('accountNumber', data.accountNumber);
    formData.append('ifscCode', data.ifscCode);
    formData.append('accountType', data.accountType);
    if (data.branchName) formData.append('branchName', data.branchName);
    if (data.cancelledCheque) formData.append('cancelledCheque', data.cancelledCheque);
    return api.post('/bank-accounts', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },

  getMy: () => api.get('/bank-accounts/my'),

  getAll: (params?: { page?: number; limit?: number; status?: string }) =>
    api.get('/bank-accounts', { params }),

  getById: (id: string) => api.get(`/bank-accounts/${id}`),

  review: (id: string, data: { status: 'approved' | 'rejected'; rejectionReason?: string }) =>
    api.patch(`/bank-accounts/${id}/review`, data),
};
