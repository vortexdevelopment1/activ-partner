import api from '../api/axios';

const API_URL =
  import.meta.env.VITE_LOCAL_API_URL?.trim().replace(/\/+$/, '') ||
  import.meta.env.VITE_API_URL?.trim().replace(/\/+$/, '') || '';
const ASSET_BASE_URL = API_URL.replace(/\/api\/v\d+$/i, '');

export const resolveAssetUrl = (src?: string | null) => {
  const value = src?.trim();
  if (!value) return '';
  return /^(https?:|data:|blob:)/i.test(value)
    ? value
    : `${ASSET_BASE_URL}/${value.replace(/^\/+/, '')}`;
};

export const isPdfUrl = (url: string) => /\.pdf(?:[?#].*)?$/i.test(url);

export const openPdfDocument = async (src?: string | null): Promise<void> => {
  const url = resolveAssetUrl(src);
  if (!url) throw new Error('Document URL is missing.');
  const popup = window.open('', '_blank');
  if (popup) popup.opener = null;

  try {
    const cloudinary = /^https:\/\/res\.cloudinary\.com\//i.test(url);
    const response = cloudinary
      ? await api.get('/admin/documents/pdf', { params: { url }, responseType: 'blob' })
      : await fetch(url).then(async (result) => {
          if (!result.ok) throw new Error('Document could not be downloaded.');
          return { data: await result.blob() };
        });
    const blob = response.data instanceof Blob
      ? response.data
      : new Blob([response.data], { type: 'application/pdf' });
    if (!blob.size) throw new Error('The PDF file is empty.');
    const objectUrl = URL.createObjectURL(new Blob([blob], { type: 'application/pdf' }));
    if (popup) popup.location.href = objectUrl;
    else window.open(objectUrl, '_blank', 'noopener,noreferrer');
    window.setTimeout(() => URL.revokeObjectURL(objectUrl), 120_000);
  } catch (error: any) {
    popup?.close();
    const errorBlob = error?.response?.data;
    if (errorBlob instanceof Blob && /json/i.test(errorBlob.type)) {
      try {
        const body = JSON.parse(await errorBlob.text());
        throw new Error(body.message || body.error || 'PDF could not be opened.');
      } catch (parsed: any) {
        if (parsed instanceof SyntaxError) throw new Error('PDF could not be opened.');
        throw parsed;
      }
    }
    throw error instanceof Error ? error : new Error('PDF could not be opened.');
  }
};
