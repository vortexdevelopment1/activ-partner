import api from './axios';

export type LegalType = 'terms_and_conditions' | 'privacy_policy' | 'partner_agreement' | 'refund_policy';

export const legalApi = {
  getAll: () => api.get('/legal'),
  getByType: (type: LegalType) => api.get(`/legal/${type}`),
  upsert: (type: LegalType, content: string) =>
    api.put(`/legal/${type}`, { content }),
};
