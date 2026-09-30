import api from './axios';

export const venuesApi = {
  adminCreate: (data: {
    partnerId: string;
    categoryIds: string[];
    name: string;
    description?: string;
    phone?: string;
    venuePhone?: string;
    locationUrl?: string;
    flatBuilding?: string;
    address?: string;
    city?: string;
    state?: string;
    zipCode?: string;
    latitude?: number;
    longitude?: number;
    commission?: number;
    amenities?: string[];
    answers?: Array<{ questionId: string; answer: any }>;
  }) => api.post('/venues/admin/create', data),
  uploadImages: (venueId: string, files: File[], serviceName: string) => {
    const formData = new FormData();
    formData.append('serviceName', serviceName);
    files.forEach(f => formData.append('images', f));
    return api.post(`/venues/${venueId}/services/images`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
  getAll: (params?: { page?: number; limit?: number; search?: string; status?: string; categoryId?: string }) =>
    api.get('/venues/admin/all', { params }),
  getPending: (params?: { page?: number; limit?: number }) =>
    api.get('/venues/admin/pending', { params }),
  getStats: () => api.get('/venues/admin/stats'),
  getById: (id: string) => api.get(`/venues/${id}`),
  processApproval: (id: string, data: { status: string; reason?: string }) =>
    api.patch(`/venues/admin/${id}/approval`, data),
  approve: (id: string) =>
    api.patch(`/venues/admin/${id}/approval`, { status: 'approved' }),
  reject: (id: string, reason: string) =>
    api.patch(`/venues/admin/${id}/approval`, { status: 'rejected', reason }),
  requestChanges: (id: string, reason: string) =>
    api.patch(`/venues/admin/${id}/approval`, { status: 'pending', reason }),
  submitLegal: (venueId: string, data: {
    aadhaarName: string;
    aadhaarNumber: string;
    panNumber: string;
    aadhaarCard: File;
    panCard: File;
    gstNumber?: string;
    gstinDoc?: File;
  }) => {
    const formData = new FormData();
    formData.append('aadhaarName', data.aadhaarName);
    formData.append('aadhaarNumber', data.aadhaarNumber);
    formData.append('panNumber', data.panNumber);
    formData.append('aadhaarCard', data.aadhaarCard);
    formData.append('panCard', data.panCard);
    if (data.gstNumber) formData.append('gstNumber', data.gstNumber);
    if (data.gstinDoc) formData.append('gstinDoc', data.gstinDoc);
    return api.patch(`/venues/${venueId}/legal`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
  delete: (id: string) => api.delete(`/venues/${id}`),
};
