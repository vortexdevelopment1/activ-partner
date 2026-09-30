import api from './axios';

export const commissionsApi = {
  getAll: (params?: { page?: number; limit?: number }) =>
    api.get('/commissions', { params }),
  getById: (id: string) => api.get(`/commissions/${id}`),
  create: (data: { city: string; commissionPercentage: number }) =>
    api.post('/commissions', data),
  update: (id: string, data: { city?: string; commissionPercentage?: number }) =>
    api.patch(`/commissions/${id}`, data),
  delete: (id: string) => api.delete(`/commissions/${id}`),
};
