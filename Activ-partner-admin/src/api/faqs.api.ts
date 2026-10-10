import api from './axios';

export const faqsApi = {
  getAll: (params?: { page?: number; limit?: number; search?: string }) =>
    api.get('/faqs', { params }),
  getById: (id: string) => api.get(`/faqs/${id}`),
  create: (data: { question: string; answer: string; isActive?: boolean }) =>
    api.post('/faqs', data),
  update: (id: string, data: { question?: string; answer?: string; isActive?: boolean }) =>
    api.patch(`/faqs/${id}`, data),
  delete: (id: string) => api.delete(`/faqs/${id}`),
};
