import api from './axios';

export const gstVerificationApi = {
  getAll: (params?: { page?: number; limit?: number; status?: string }) =>
    api.get('/partners/gst-verification', { params }),
  getById: (id: string) => api.get(`/partners/gst-verification/${id}`),
  approve: (id: string) => api.patch(`/partners/gst-verification/${id}/approve`),
  reject: (id: string, data: { adminNotes: string }) =>
    api.patch(`/partners/gst-verification/${id}/reject`, data),
};
