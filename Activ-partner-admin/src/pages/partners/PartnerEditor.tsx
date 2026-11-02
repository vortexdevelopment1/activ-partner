import React, { useRef, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { PartnerDocumentUpload } from './PartnerDocumentUpload';
import { partnersApi, type PartnerDocumentKind } from '../../api/partners.api';
import { Modal } from '../../components/ui/Modal';
import { useToast } from '../../hooks/useToast';

type Bank = { id?: string; accountHolderName: string; bankName: string; accountNumber: string; ifscCode: string; accountType: string; branchName: string; cancelledChequeUrl: string; upiId: string; status: string; isPrimary: boolean; rejectionReason: string };
const groups = [
  { title: 'Owner and login', fields: [['firstName', 'First name'], ['lastName', 'Last name'], ['email', 'Login email'], ['phone', 'Login phone'], ['avatarUrl', 'Profile photo URL']] },
  { title: 'Business details', fields: [['legalName', 'Legal name'], ['businessName', 'Business name'], ['ownerName', 'Business owner name'], ['businessEmail', 'Business email'], ['contactPhone', 'Business contact phone'], ['businessAddress', 'Address line 1'], ['addressLine2', 'Address line 2'], ['city', 'City'], ['state', 'State'], ['zipCode', 'Postal code']] },
  { title: 'Documents and verification', fields: [['panNumber', 'PAN number'], ['panCardUrl', 'PAN document URL'], ['gstNumber', 'GST number'], ['gstinDocUrl', 'GST document URL'], ['rejectionReason', 'Verification rejection reason']] },
];
const bankFields = [['accountHolderName', 'Account holder'], ['bankName', 'Bank name'], ['accountNumber', 'Account number'], ['ifscCode', 'IFSC code'], ['accountType', 'Account type'], ['branchName', 'Branch'], ['cancelledChequeUrl', 'Cancelled cheque URL'], ['upiId', 'UPI ID'], ['rejectionReason', 'Rejection reason']] as const;

export const PartnerEditor: React.FC<{ id: string; onClose: () => void }> = ({ id, onClose }) => {
  const submitting = useRef(false);
  const uploadingRef = useRef(false);
  const [uploading, setUploading] = useState(false);
  const onUploadBusyChange = (busy: boolean) => { uploadingRef.current = busy; setUploading(busy); };
  const queryClient = useQueryClient();
  const { success, error } = useToast();
  const [changes, setChanges] = useState<Record<string, string>>({});
  const [banks, setBanks] = useState<Bank[] | null>(null);
  const query = useQuery({ queryKey: ['partner', id], queryFn: () => partnersApi.getById(id) });
  const partner = query.data?.data?.data;
  const mutation = useMutation({
    mutationFn: () => partnersApi.update(id, { ...changes, ...(banks ? { bankAccounts: banks } : {}) }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['partners'] });
      queryClient.invalidateQueries({ queryKey: ['venue'] });
      queryClient.invalidateQueries({ queryKey: ['venues'] });
      queryClient.invalidateQueries({ queryKey: ['partner', id] });
      queryClient.invalidateQueries({ queryKey: ['bank-accounts'] });
      queryClient.invalidateQueries({ queryKey: ['bank-account'] });
      success('Partner details saved'); onClose();
    },
    onSettled: () => { submitting.current = false; },
    onError: (err: any) => {
      const message = err?.response?.data?.message;
      error(Array.isArray(message) ? message.join(', ') : message ?? 'Failed to save partner');
    },
  });
  const value = (key: string) => changes[key] ?? (key === 'status' ? partner?.status?.toUpperCase() : partner?.[key]) ?? '';
  const accounts: Bank[] = banks ?? partner?.bankAccounts ?? [];
  const updateBank = (index: number, field: string, value: string | boolean) => {
    setBanks(accounts.map((bank, i) => ({ ...bank, ...(i === index ? { [field]: value } : field === 'isPrimary' && value ? { isPrimary: false } : {}) })));
  };
  const close = () => { if (!mutation.isPending && !uploadingRef.current) onClose(); };
  const documentFields: Record<string, { kind: PartnerDocumentKind; label: string }> = {
    avatarUrl: { kind: 'avatar', label: 'profile photo' },
    panCardUrl: { kind: 'pan', label: 'PAN document' },
    gstinDocUrl: { kind: 'gst', label: 'GST document' },
  };
  return <Modal open onClose={close} title="Partner details" size="xl" subtitle={id}>
    {query.isLoading ? <p role="status">Loading partner details...</p> : query.isError ? <div role="alert">Could not load partner details. <button className="btn-secondary" onClick={() => query.refetch()}>Retry</button></div> : partner ?
      <form className="space-y-6" onSubmit={event => { event.preventDefault(); if (submitting.current || uploadingRef.current) return; submitting.current = true; mutation.mutate(); }}>
        <fieldset disabled={mutation.isPending || uploading} className="space-y-6">
          <p className="text-xs text-gray-500">Created: {new Date(partner.createdAt).toLocaleString()} | Updated: {new Date(partner.updatedAt).toLocaleString()} | Venues: {partner.venueCount ?? 0}</p>
          {groups.map(group => <section key={group.title} className="space-y-3">
            <h4 className="font-semibold text-gray-900">{group.title}</h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">{group.fields.map(([key, label]) => <div key={key}><label className="block text-sm text-gray-600 space-y-1">
              <span>{label}</span><input className="input w-full" value={value(key)} required={key === 'phone' || key === 'legalName'} type={key.toLowerCase().includes('email') ? 'email' : 'text'} onChange={event => setChanges(previous => ({ ...previous, [key]: event.target.value }))} />
            </label>
              {documentFields[key] && <PartnerDocumentUpload partnerId={id} {...documentFields[key]} onBusyChange={onUploadBusyChange} onUploaded={url => setChanges(previous => ({ ...previous, [key]: url }))} />}
            </div>)}</div>
          </section>)}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {[['status', 'Account status', ['PENDING', 'ACTIVE', 'SUSPENDED']], ['kycStatus', 'Verification status', ['PENDING', 'APPROVED', 'REJECTED']]].map(([key, label, options]) => <label key={key as string} className="text-sm text-gray-600 space-y-1"><span>{label}</span>
              <select className="input w-full cursor-pointer disabled:cursor-not-allowed" value={value(key as string)} onChange={event => setChanges(previous => ({ ...previous, [key as string]: event.target.value }))}>{(options as string[]).map(option => <option key={option}>{option}</option>)}</select>
            </label>)}
          </div>
          <section className="space-y-3"><h4 className="font-semibold text-gray-900">Bank accounts</h4>
            {accounts.length === 0 && <p className="text-sm text-gray-500">No bank accounts added.</p>}
            {accounts.map((bank, index) => <div key={bank.id ?? index} className="border rounded-lg p-3 space-y-3">
              <h5 className="text-sm font-medium">Account {index + 1}</h5>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">{bankFields.map(([key, label]) => <label key={key} className="text-sm text-gray-600 space-y-1"><span>{label}</span><input className="input w-full" required={['accountHolderName', 'bankName', 'accountNumber', 'ifscCode'].includes(key)} value={bank[key] ?? ''} onChange={event => updateBank(index, key, event.target.value)} /></label>)}</div>
              <PartnerDocumentUpload partnerId={id} kind="cancelled-cheque" label={`cancelled cheque for account ${index + 1}`} onBusyChange={onUploadBusyChange} onUploaded={url => updateBank(index, 'cancelledChequeUrl', url)} />
              <label className="block text-sm">Status<select className="input w-full cursor-pointer disabled:cursor-not-allowed" value={bank.status} onChange={event => updateBank(index, 'status', event.target.value)}>{['UNDER_REVIEW', 'APPROVED', 'REJECTED'].map(status => <option key={status}>{status}</option>)}</select></label>
              <label className="flex items-center gap-2 text-sm"><input type="checkbox" className="cursor-pointer disabled:cursor-not-allowed" checked={bank.isPrimary} onChange={event => updateBank(index, 'isPrimary', event.target.checked)} />Primary account</label>
            </div>)}
            <button type="button" className="btn-secondary" onClick={() => setBanks([...accounts, { accountHolderName: '', bankName: '', accountNumber: '', ifscCode: '', accountType: '', branchName: '', cancelledChequeUrl: '', upiId: '', status: 'UNDER_REVIEW', isPrimary: false, rejectionReason: '' }])}>Add bank account</button>
          </section>
        </fieldset>
        <div className="flex justify-end gap-2"><button type="button" className="btn-secondary" disabled={mutation.isPending || uploading} onClick={close}>Cancel</button><button type="submit" className="btn-primary" disabled={mutation.isPending || uploading || (!Object.keys(changes).length && !banks)}>{mutation.isPending ? 'Saving...' : 'Save changes'}</button></div>
      </form> : <p>Partner not found.</p>}
  </Modal>;
};
