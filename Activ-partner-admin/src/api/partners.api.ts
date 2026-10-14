import api from './axios';

export const partnersApi = {
  getAll: (params?: { page?: number; limit?: number; search?: string }) =>
    api.get('/partners', { params }),
  create: (data: {
    phone?: string;
    firstName?: string;
    lastName?: string;
    email?: string;
  }) => api.post('/partners', data),
  getById: (id: string) => api.get(`/partners/${id}`),
  update: (id: string, data: object) => api.patch(`/partners/${id}`, data),
  verify: (id: string) => api.patch(`/partners/${id}/verify`),
  toggleStatus: (id: string) => api.patch(`/partners/${id}/toggle-status`),
  toggleActive: (id: string, isActive: boolean) =>
    api.patch(`/partners/${id}`, { isActive }),
  delete: (id: string) => api.delete(`/partners/${id}`),
};
