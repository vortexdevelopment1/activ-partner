import api from './axios';

export const usersApi = {
  getAll: (params?: { page?: number; limit?: number; search?: string; role?: string }) =>
    api.get('/users', { params }),
  getById: (id: string) => api.get(`/users/${id}`),
  create: (data: object) => api.post('/users', data),
  update: (id: string, data: object) => api.patch(`/users/${id}`, data),
  toggleStatus: (id: string) => api.patch(`/users/${id}/toggle-status`),
  toggleActive: (id: string, isActive: boolean) =>
    api.patch(`/users/${id}`, { isActive }),
  delete: (id: string) => api.delete(`/users/${id}`),
};
