import React, { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { ScrollText, Save, RefreshCw } from 'lucide-react';
import { legalApi, type LegalType } from '../../api/legal.api';
import { useToast } from '../../hooks/useToast';
import type { LegalDocument } from '../../types';

const TABS: { type: LegalType; label: string }[] = [
  { type: 'terms_and_conditions', label: 'Terms & Conditions' },
  { type: 'privacy_policy', label: 'Privacy Policy' },
  { type: 'partner_agreement', label: 'Partner Agreement' },
  { type: 'refund_policy', label: 'Refund Policy' },
];

export const LegalPage: React.FC = () => {
  const queryClient = useQueryClient();
  const { success, error } = useToast();
  const [activeTab, setActiveTab] = useState<LegalType>('terms_and_conditions');
  const [contentMap, setContentMap] = useState<Record<LegalType, string>>({
    terms_and_conditions: '',
    privacy_policy: '',
    partner_agreement: '',
    refund_policy: '',
  });

  const { data, isLoading } = useQuery({
    queryKey: ['legal'],
    queryFn: () => legalApi.getAll(),
  });

  const docs: LegalDocument[] = data?.data?.data ?? [];

  useEffect(() => {
    if (docs.length > 0) {
      const map = { terms_and_conditions: '', privacy_policy: '', partner_agreement: '', refund_policy: '' } as Record<LegalType, string>;
      docs.forEach((doc) => {
        if (doc.type in map) {
          map[doc.type as LegalType] = doc.content;
        }
      });
      setContentMap(map);
    }
  }, [data]);

  const upsertMutation = useMutation({
    mutationFn: ({ type, content }: { type: LegalType; content: string }) =>
      legalApi.upsert(type, content),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['legal'] });
      success('Saved successfully');
    },
    onError: (err: any) => {
      const message = err?.response?.data?.message;
      error(Array.isArray(message) ? message.join('\n') : message ?? 'Failed to save');
    },
  });

  const handleSave = () => {
    const content = contentMap[activeTab].trim();
    if (content.length < 10) {
      error('Enter at least 10 characters before saving.');
      return;
    }
    upsertMutation.mutate({ type: activeTab, content });
  };

  const activeDoc = docs.find((d) => d.type === activeTab);

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Legal</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            Manage Terms &amp; Conditions and Privacy Policy
          </p>
        </div>
        <button
          onClick={handleSave}
          disabled={upsertMutation.isPending}
          className="btn-primary flex items-center gap-2"
        >
          {upsertMutation.isPending ? (
            <RefreshCw size={16} className="animate-spin" />
          ) : (
            <Save size={16} />
          )}
          Save
        </button>
      </div>

      {/* Card */}
      <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
        {/* Tabs */}
        <div className="flex border-b border-gray-100">
          {TABS.map((tab) => (
            <button
              key={tab.type}
              onClick={() => setActiveTab(tab.type)}
              className={`px-6 py-3.5 text-sm font-medium transition-colors ${
                activeTab === tab.type
                  ? 'border-b-2 border-primary-600 text-primary-700'
                  : 'text-gray-500 hover:text-gray-800'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="p-6">
          {isLoading ? (
            <div className="flex items-center justify-center py-24 text-gray-400 text-sm">
              Loading...
            </div>
          ) : (
            <>
              {activeDoc && (
                <p className="text-xs text-gray-400 mb-3">
                  Last updated:{' '}
                  {new Date(activeDoc.updatedAt).toLocaleDateString('en-IN', {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                  })}
                </p>
              )}
              <textarea
                className="w-full min-h-[500px] border border-gray-200 rounded-lg p-4 text-sm text-gray-800 font-mono resize-y focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                placeholder={`Enter ${TABS.find((t) => t.type === activeTab)?.label ?? ''} content here...`}
                value={contentMap[activeTab]}
                onChange={(e) =>
                  setContentMap((prev) => ({ ...prev, [activeTab]: e.target.value }))
                }
              />
            </>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-gray-50 flex justify-end">
          <button
            onClick={handleSave}
            disabled={upsertMutation.isPending}
            className="btn-primary flex items-center gap-2"
          >
            {upsertMutation.isPending ? (
              <RefreshCw size={16} className="animate-spin" />
            ) : (
              <Save size={16} />
            )}
            Save {TABS.find((t) => t.type === activeTab)?.label}
          </button>
        </div>
      </div>

      {/* Empty state hint */}
      {!isLoading && docs.length === 0 && (
        <div className="flex flex-col items-center py-8 text-gray-400">
          <ScrollText size={36} className="mb-2 text-gray-200" />
          <p className="text-sm">No legal documents yet. Start by adding content above.</p>
        </div>
      )}
    </div>
  );
};
