import api from './axios';
import { PaginatedData, PendingActivity } from '../types';

export type ActivityReviewFilter = 'all' | 'pending' | 'approved' | 'rejected';

export const activitiesApi = {
  getPending: (params?: { page?: number; limit?: number; status?: ActivityReviewFilter }) =>
    api.get<{ data: PaginatedData<PendingActivity> }>('/venues/admin/activities/pending', { params }),

  approve: (serviceId: string) =>
    api.patch(`/venues/admin/activities/${serviceId}/approval`, { status: 'approved' }),

  reject: (serviceId: string, reason: string) =>
    api.patch(`/venues/admin/activities/${serviceId}/approval`, { status: 'rejected', reason }),
};
