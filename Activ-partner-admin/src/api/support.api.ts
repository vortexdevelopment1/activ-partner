import api from './axios';

export const supportApi = {
  getCallbacks: (params?: { page?: number; limit?: number; status?: string; search?: string }) =>
    api.get('/support/callback', { params }),

  getCallbackById: (id: string) => api.get(`/support/callback/${id}`),

  updateCallback: (id: string, data: { status?: string; adminNotes?: string }) =>
    api.patch(`/support/callback/${id}`, data),

  deleteCallback: (id: string) => api.delete(`/support/callback/${id}`),
};
