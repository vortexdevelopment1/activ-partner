import api from './axios';

export interface AdminSearchItem {
  id: string;
  label: string;
  description: string;
  path: string;
}

export interface AdminSearchGroup {
  key: string;
  title: string;
  items: AdminSearchItem[];
}

export const adminSearchApi = {
  search: (q: string, signal?: AbortSignal) =>
    api.get<{ data: AdminSearchGroup[] }>('/admin/search', { params: { q }, signal }),
};
