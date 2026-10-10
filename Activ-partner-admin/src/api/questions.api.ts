import api from './axios';

export const questionsApi = {
  getAll: (params?: { page?: number; limit?: number; search?: string; categoryId?: string }) =>
    api.get('/questions', { params }),
  getByCategory: (categoryId: string) => api.get(`/questions/category/${categoryId}`),
  getById: (id: string) => api.get(`/questions/${id}`),
  create: (data: object) => api.post('/questions', data),
  update: (id: string, data: object) => api.patch(`/questions/${id}`, data),
  toggleStatus: (id: string) => api.patch(`/questions/${id}/toggle-status`),
  delete: (id: string) => api.delete(`/questions/${id}`),
  reorder: (orders: { id: string; order: number }[]) => api.patch('/questions/reorder', orders),
};
