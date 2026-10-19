import api from './axios';

export interface SupportRequest {
  id: string;
  partner_id: string | null;
  subject: string;
  message: string;
  status: string;
  attachments: Array<{ url: string; originalName?: string | null }>;
  created_at: string;
}

export const supportApi = {
  getRequests: (params: { page: number; limit: number }) =>
    api.get<{ data: { items: SupportRequest[]; total: number } }>('/support/email', { params }),
  getRequestById: (id: string) => api.get<{ data: SupportRequest }>(`/support/email/${encodeURIComponent(id)}`),
  getCallbacks: (params?: { page?: number; limit?: number; status?: string; search?: string }) =>
    api.get('/support/callback', { params }),

  getCallbackById: (id: string) => api.get(`/support/callback/${id}`),

  updateCallback: (id: string, data: { status?: string; adminNotes?: string }) =>
    api.patch(`/support/callback/${id}`, data),

  deleteCallback: (id: string) => api.delete(`/support/callback/${id}`),
};
