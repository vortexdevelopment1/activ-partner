export type PartnerDocumentKind = 'avatar' | 'pan' | 'gst' | 'cancelled-cheque' | 'aadhaar';
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
  uploadDocument: (id: string, kind: PartnerDocumentKind, file: File) => {
    const form = new FormData();
    form.append('file', file);
    return api.post(`/partners/${id}/documents/${kind}`, form, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
  getById: (id: string) => api.get(`/partners/${id}`),
  update: (id: string, data: object) => api.patch(`/partners/${id}`, data),
  toggleStatus: (id: string) => api.patch(`/partners/${id}/toggle-status`),
  toggleActive: (id: string, isActive: boolean) =>
    api.patch(`/partners/${id}`, { isActive }),
  delete: (id: string) => api.delete(`/partners/${id}`),
};
