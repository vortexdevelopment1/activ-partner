import React, { useRef, useState } from 'react';
import { partnersApi, type PartnerDocumentKind } from '../../api/partners.api';

export const PartnerDocumentUpload: React.FC<{
  partnerId: string;
  kind: PartnerDocumentKind;
  label: string;
  onUploaded: (url: string) => void;
  onBusyChange: (busy: boolean) => void;
}> = ({ partnerId, kind, label, onUploaded, onBusyChange }) => {
  const [uploading, setUploading] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const inFlight = useRef(false);
  const imageOnly = kind === 'avatar';
  return <div className="mt-2 space-y-1">
    <label className="block text-xs font-medium text-primary-700">
      Upload {label}
      <input type="file" className="block w-full mt-1 cursor-pointer text-xs text-gray-600 file:mr-2 file:cursor-pointer file:rounded-md file:border-0 file:bg-primary-50 file:px-3 file:py-2 file:text-primary-700 disabled:cursor-not-allowed disabled:file:cursor-not-allowed" disabled={uploading}
        accept={imageOnly ? '.jpg,.jpeg,.png,.webp' : '.jpg,.jpeg,.png,.webp,.pdf'}
        onChange={async event => {
          const file = event.target.files?.[0];
          event.target.value = '';
          if (!file || inFlight.current) return;
          setError(''); setMessage('');
          const extension = file.name.split('.').pop()?.toLowerCase();
          if (!extension || !(imageOnly ? ['jpg', 'jpeg', 'png', 'webp'] : ['jpg', 'jpeg', 'png', 'webp', 'pdf']).includes(extension)) {
            setError(imageOnly ? 'Choose a JPG, PNG or WebP image.' : 'Choose a JPG, PNG, WebP image or PDF.'); return;
          }
          if (!file.size || file.size > 10 * 1024 * 1024) { setError('Choose a non-empty file of 10 MB or smaller.'); return; }
          inFlight.current = true; setUploading(true); onBusyChange(true);
          try {
            const response = await partnersApi.uploadDocument(partnerId, kind, file);
            const url = response.data?.data?.url;
            if (!url) throw new Error('The upload did not return a document URL. Please retry.');
            onUploaded(url); setMessage(file.name + ' uploaded. Save changes to apply it.');
          } catch (err: any) {
            const message = err?.response?.data?.message ?? err?.message;
            setError(Array.isArray(message) ? message.join(', ') : message || 'Upload failed. Please try again.');
          } finally {
            inFlight.current = false; setUploading(false); onBusyChange(false);
          }
        }} />
    </label>
    <p className="text-xs text-gray-400">{imageOnly ? 'JPG, PNG or WebP' : 'JPG, PNG, WebP or PDF'}; up to 10 MB.</p>
    {uploading && <p role="status" className="text-xs text-primary-600">Uploading {label}...</p>}
    {message && <p role="status" className="text-xs text-emerald-700">{message}</p>}
    {error && <p role="alert" className="text-xs text-red-600">{error}</p>}
  </div>;
};
