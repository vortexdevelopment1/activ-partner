import api from './axios';

export const categoriesApi = {
  getAll: (params?: { page?: number; limit?: number; search?: string }) =>
    api.get('/categories', { params }),
  getAllActive: () => api.get('/categories/active'),
  getById: (id: string) => api.get(`/categories/${id}`),
  create: (data: FormData | object) =>
    api.post('/categories', data, {
      headers: data instanceof FormData ? { 'Content-Type': 'multipart/form-data' } : {},
    }),
  update: (id: string, data: FormData | object) =>
    api.patch(`/categories/${id}`, data, {
      headers: data instanceof FormData ? { 'Content-Type': 'multipart/form-data' } : {},
    }),
  toggleStatus: (id: string) => api.patch(`/categories/${id}/toggle-status`),
  delete: (id: string) => api.delete(`/categories/${id}`),
};
