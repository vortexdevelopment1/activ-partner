import api from './axios';

export const venueRequestsApi = {
  // The API rejects a `status` query param (400: "property status should not exist"),
  // so status filtering is done client-side against the fetched page.
  getAll: (params?: { page?: number; limit?: number }) =>
    api.get('/venues/update-requests', { params }),
  getById: (requestId: string) => api.get(`/venues/update-requests/${requestId}`),
  approve: (requestId: string) => api.patch(`/venues/update-requests/${requestId}/approve`),
  reject: (requestId: string, data: { adminNotes: string }) =>
    api.patch(`/venues/update-requests/${requestId}/reject`, data),
};
