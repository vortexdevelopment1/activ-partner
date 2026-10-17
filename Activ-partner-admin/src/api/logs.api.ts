import api from './axios';

export interface ActivityLog {
  id: string;
  action: string;
  resource: string;
  targetId: string;
  actor: string | null;
  details: { outcome: 'success' | 'failed'; statusCode: number | null; decision: string | null };
  createdAt: string;
}

export const logsApi = {
  getAll: (params: { page: number; limit: number; search?: string; resource?: string; outcome?: string; from?: string; to?: string }) =>
    api.get('/admin/logs', { params }),
  getResources: () => api.get('/admin/logs/resources'),
};
