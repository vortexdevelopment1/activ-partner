import React, { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  ArrowLeft,
  MapPin,
  Clock,
  Tag,
  User,
  Building2,
  Star,
  DollarSign,
  Image,
  ClipboardList,
  Calendar,
  Link2,
  CheckSquare,
  ShieldCheck,
  Trash2,
  RefreshCw,
  FileText,
} from 'lucide-react';
import { venuesApi } from '../../api/venues.api';
import { activityLogoUrl } from '../../utils/activityLogos';
import { Badge } from '../../components/ui/Badge';
import { ApproveModal } from './ApproveModal';
import { RejectModal } from './RejectModal';
import { RequestChangesModal } from './RequestChangesModal';
import { useToast } from '../../hooks/useToast';
import { ConfirmDialog } from '../../components/common/ConfirmDialog';
import type { Venue, VenueAnswer } from '../../types';
import { isPdfUrl, openPdfDocument, resolveAssetUrl } from '../../utils/documents';

const assetUrl = resolveAssetUrl;

const questionLabel = (answer: VenueAnswer) => {
  const question = typeof answer.question === 'object' ? (answer.question as any) : null;
  const label = question?.questionText ?? question?.question ?? question?.title ?? question?.label;
  return typeof label === 'string' && label.trim().length > 0 ? label.trim() : null;
};

const InfoRow: React.FC<{ label: string; value?: string | null }> = ({ label, value }) =>
  value ? (
    <div className="grid min-w-0 grid-cols-[minmax(0,7rem)_minmax(0,1fr)] gap-3 sm:grid-cols-[8rem_minmax(0,1fr)]">
      <span className="text-xs text-gray-400 pt-0.5">{label}</span>
      <span className="min-w-0 text-sm text-gray-800 [overflow-wrap:anywhere]">{value}</span>
    </div>
  ) : null;

const KycDocImage: React.FC<{ label: string; src?: string | null }> = ({ label, src }) => {
  const resolvedSrc = assetUrl(src);
  const isPdf = isPdfUrl(resolvedSrc);
  const [opening, setOpening] = useState(false);
  const [openError, setOpenError] = useState('');
  return resolvedSrc ? (
    <div>
      <p className="text-xs text-gray-400 mb-1.5">{label}</p>
      {isPdf ? (
        <button
          type="button"
          disabled={opening}
          onClick={async () => {
            setOpening(true); setOpenError('');
            try { await openPdfDocument(resolvedSrc); }
            catch (err: any) { setOpenError(err?.message || 'PDF could not be opened.'); }
            finally { setOpening(false); }
          }}
          className="flex w-full max-w-xs items-center gap-3 rounded-lg border border-gray-200 bg-gray-50 px-4 py-3 text-sm font-medium text-gray-700 hover:border-primary-300 hover:text-primary-600"
        >
          <FileText size={22} />
          {opening ? 'Opening PDF...' : 'Open PDF'}
        </button>
      ) : (
        <a href={resolvedSrc} target="_blank" rel="noreferrer">
        <img
          src={resolvedSrc}
          alt={label}
          className="w-full max-w-xs rounded-lg border border-gray-200 object-cover hover:opacity-90 transition-opacity cursor-zoom-in"
        />
        </a>
      )}
      {openError && <p className="mt-2 max-w-xs text-xs text-red-500">{openError}</p>}
    </div>
  ) : null;
};

export const VenueDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  const [approveOpen, setApproveOpen] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [changesOpen, setChangesOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);

  const { data, isLoading, isError, error: loadError, refetch, isFetching } = useQuery({
    queryKey: ['venue', id],
    queryFn: () => venuesApi.getById(id!),
    enabled: !!id,
    retry: (failureCount, err: any) =>
      ![401, 403, 404].includes(err?.response?.status) && failureCount < 2,
  });

  const venue: Venue | undefined = data?.data?.data;

  const approveMutation = useMutation({
    mutationFn: () => venuesApi.approve(id!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['venue', id] });
      queryClient.invalidateQueries({ queryKey: ['venues'] });
      success('Venue approved successfully!');
      setApproveOpen(false);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to approve'),
  });

  const rejectMutation = useMutation({
    mutationFn: (reason: string) => venuesApi.reject(id!, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['venue', id] });
      queryClient.invalidateQueries({ queryKey: ['venues'] });
      success('Venue rejected.');
      setRejectOpen(false);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to reject'),
  });

  const requestChangesMutation = useMutation({
    mutationFn: (reason: string) => venuesApi.requestChanges(id!, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['venue', id] });
      queryClient.invalidateQueries({ queryKey: ['venues'] });
      success('Change request sent to partner.');
      setChangesOpen(false);
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to send request'),
  });

  const deleteMutation = useMutation({
    mutationFn: () => venuesApi.delete(id!),
    onSuccess: (response) => {
      queryClient.invalidateQueries({ queryKey: ['venues'] });
      queryClient.invalidateQueries({ queryKey: ['venues-dashboard'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard-stats'] });
      queryClient.removeQueries({ queryKey: ['venue', id] });
      success(response.data.message);
      navigate('/venues');
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to delete venue'),
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-32 text-gray-400">
        Loading venue details...
      </div>
    );
  }

  if (isError) {
    const status = (loadError as any)?.response?.status;
    const message = status === 404 ? 'Venue not found.'
      : status === 401 ? 'Your session has expired. Please sign in again.'
      : status === 403 ? 'You do not have permission to view this venue.'
      : 'Unable to load venue details. Please try again.';
    return (
      <div className="flex flex-col items-center justify-center gap-4 py-32 text-gray-400" role="alert">
        <p>{message}</p>
        {![401, 403, 404].includes(status) && (
          <button type="button" onClick={() => void refetch()} disabled={isFetching}
            className="btn-primary flex items-center gap-2">
            <RefreshCw size={16} /> {isFetching ? 'Retrying...' : 'Retry'}
          </button>
        )}
      </div>
    );
  }

  if (!venue) {
    return (
      <div className="flex items-center justify-center py-32 text-gray-400">
        Venue details are unavailable.
      </div>
    );
  }

  // venue.partner is a flat merged user+partner object from the API
  const partner = typeof venue.partner === 'object' ? (venue.partner as any) : null;
  const partnerName = [partner?.firstName, partner?.lastName]
    .filter((part): part is string => typeof part === 'string' && part.trim().length > 0)
    .join(' ')
    .trim();
  const category = typeof venue.category === 'object' ? (venue.category as any) : null;
  const amenities: string[] = Array.isArray(venue.amenities) ? venue.amenities : [];

  // All categories (multi-category support)
  const listedCategories: any[] = Array.isArray(venue.categories) && venue.categories.length > 0
    ? venue.categories
    : category ? [category] : [];
  const selectedCategoryIds = new Set((venue.services ?? [])
    .filter((service) => String(service.status) !== 'archived')
    .map((service) => service.categoryId));
  const allCategories = listedCategories.filter((category, index, items) =>
    (!Array.isArray(venue.services) || selectedCategoryIds.has(category.id)) &&
    items.findIndex((item) => item.id === category.id) === index,
  );

  // Group answers by their question's categoryId, looked up from allCategories
  const answerGroups: { catId: string; catName: string; catIcon?: string; answers: VenueAnswer[] }[] = [];
  const catIndexMap: Record<string, number> = {};
  (venue.answers ?? []).forEach((ans) => {
    const q = typeof ans.question === 'object' ? (ans.question as any) : null;
    const catId: string = q?.categoryId ?? 'global';
    const cat = allCategories.find((c: any) => c.id === catId);
    const catName: string = cat?.name ?? 'General Questions';
    const catIcon: string | undefined = cat?.icon;
    if (catIndexMap[catId] === undefined) {
      catIndexMap[catId] = answerGroups.length;
      answerGroups.push({ catId, catName, catIcon, answers: [] });
    }
    answerGroups[catIndexMap[catId]].answers.push(ans);
  });

  // Availability is { [categoryId]: [{day, slots}] } — keyed by category ID
  const availGroups = Object.entries(venue.availability ?? {}).map(([catId, entries]) => {
    const cat = allCategories.find((c: any) => c.id === catId);
    return { catId, catName: cat?.name ?? catId, entries };
  });

  return (
    <div className="space-y-5 max-w-5xl">
      {/* Back + title */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate(-1)}
            className="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-lg"
          >
            <ArrowLeft size={18} />
          </button>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-bold text-gray-900">{venue.name}</h2>
              <Badge status={venue.status} />
              {!venue.isActive && (
                <span className="text-xs font-medium bg-gray-100 text-gray-500 px-2 py-0.5 rounded-full">
                  Inactive
                </span>
              )}
            </div>
            <p className="text-sm text-gray-500 mt-0.5">
              {venue.city}, {venue.state}
            </p>
          </div>
        </div>

        {/* Action buttons */}
        <div className="grid w-full grid-cols-2 gap-2 sm:flex sm:w-auto sm:items-center">
          <button
            onClick={() => setDeleteOpen(true)}
            className="flex min-h-10 items-center justify-center gap-1.5 rounded-lg border border-red-200 bg-red-50 px-2 py-2 text-sm font-medium text-red-700 transition-colors hover:bg-red-100 sm:px-4"
          >
            <Trash2 size={14} /> {venue.canPermanentlyDelete ? 'Permanently Delete' : 'Delete Venue'}
          </button>
          {venue.status === 'pending' || venue.status === 'draft' ? (
            <>
              <button
                onClick={() => setChangesOpen(true)}
                className="min-h-10 rounded-lg border border-amber-200 bg-amber-50 px-2 py-2 text-sm font-medium text-amber-700 transition-colors hover:bg-amber-100 sm:px-4"
              >
                Request Changes
              </button>
              <button
                onClick={() => setRejectOpen(true)}
                className="min-h-10 rounded-lg border border-red-200 bg-red-50 px-2 py-2 text-sm font-medium text-red-700 transition-colors hover:bg-red-100 sm:px-4"
              >
                Reject
              </button>
              <button
                onClick={() => setApproveOpen(true)}
                className="min-h-10 rounded-lg bg-emerald-600 px-2 py-2 text-sm font-medium text-white transition-colors hover:bg-emerald-700 sm:px-4"
              >
                Approve
              </button>
            </>
          ) : venue.status === 'approved' ? (
            <button
              onClick={() => setRejectOpen(true)}
              className="px-4 py-2 text-sm font-medium text-red-700 bg-red-50 border border-red-200 rounded-lg hover:bg-red-100 transition-colors"
            >
              Suspend / Reject
            </button>
          ) : venue.status === 'rejected' || venue.status === 'suspended' ? (
            <button
              onClick={() => setApproveOpen(true)}
              className="px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-lg hover:bg-emerald-700 transition-colors"
            >
              Re-approve
            </button>
          ) : null}
        </div>
      </div>

      {/* Rejection reason banner */}
      {venue.rejectionReason && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-4">
          <p className="text-sm font-medium text-red-700">Rejection Reason</p>
          <p className="text-sm text-red-600 mt-1">{venue.rejectionReason}</p>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {/* Left column — main info */}
        <div className="lg:col-span-2 space-y-5">
          {/* Venue Info */}
          <div className="bg-white rounded-xl border border-gray-100 p-5">
            <h3 className="text-sm font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <Building2 size={16} className="text-gray-400" /> Venue Information
            </h3>
            <div className="space-y-3">
              <InfoRow label="Description" value={venue.description} />
              <InfoRow label="Address" value={venue.address} />
              {(venue as any).flatBuilding && (
                <InfoRow label="Flat / Building" value={(venue as any).flatBuilding} />
              )}
              <InfoRow
                label="Location"
                value={`${venue.city}, ${venue.state}, ${venue.country}`}
              />
              {venue.zipCode && <InfoRow label="ZIP Code" value={venue.zipCode} />}
              <InfoRow label="Phone" value={venue.phone} />
              {(venue as any).venuePhone && (
                <InfoRow label="Venue Phone" value={(venue as any).venuePhone} />
              )}
              {(venue as any).locationUrl && (
                <div className="flex gap-3">
                  <span className="text-xs text-gray-400 w-32 shrink-0 pt-0.5">Location URL</span>
                  <a
                    href={(venue as any).locationUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="text-sm text-primary-600 hover:underline flex items-center gap-1"
                  >
                    <Link2 size={12} /> {(venue as any).locationUrl}
                  </a>
                </div>
              )}
              <InfoRow label="Opening Time" value={venue.openingTime} />
              <InfoRow label="Closing Time" value={venue.closingTime} />
              {venue.rules && <InfoRow label="Rules" value={venue.rules} />}
              {venue.latitude && (
                <InfoRow
                  label="Coordinates"
                  value={`${venue.latitude}, ${venue.longitude}`}
                />
              )}
            </div>
          </div>

          {/* Availability */}
          {availGroups.length > 0 && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-4 flex items-center gap-2">
                <Calendar size={16} className="text-gray-400" /> Availability Schedule
              </h3>
              <div className="space-y-5">
                {availGroups.map((group) => (
                  <div key={group.catId}>
                    {/* Show category header only when there are multiple category groups */}
                    {availGroups.length > 1 && (
                      <p className="text-xs font-semibold text-primary-700 bg-primary-50 px-2.5 py-1 rounded-md inline-block mb-2 capitalize">
                        {group.catName}
                      </p>
                    )}
                    <div className="space-y-2">
                      {group.entries.map((avail, idx) => (
                        <div key={idx} className="flex items-start gap-3">
                          <span className="text-xs font-medium text-gray-600 w-24 shrink-0 capitalize pt-1">
                            {avail.day}
                          </span>
                          <div className="flex flex-wrap gap-2">
                            {Array.isArray(avail.slots) && avail.slots.length > 0 ? (
                              avail.slots.map((slot, si) => (
                                <span
                                  key={si}
                                  className="text-xs bg-primary-50 text-primary-700 px-2.5 py-1 rounded-full font-medium"
                                >
                                  {slot.openTime} – {slot.closeTime}
                                </span>
                              ))
                            ) : (
                              <span className="text-xs text-gray-400">Closed</span>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Services */}
          {venue.services && venue.services.length > 0 && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-4 flex items-center gap-2">
                <DollarSign size={16} className="text-gray-400" /> Services &amp; Pricing
              </h3>
              <div className="space-y-3">
                {venue.services.map((svc) => (
                  <div
                    key={svc.id}
                    className="p-3 bg-gray-50 rounded-lg"
                  >
                    <div className="flex items-start gap-4">
                      {assetUrl((svc as any).coverImageUrl ?? svc.imageUrl) && (
                        <img
                          src={assetUrl((svc as any).coverImageUrl ?? svc.imageUrl)}
                          alt={svc.name}
                          className="w-14 h-14 object-cover rounded-lg shrink-0"
                        />
                      )}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between gap-2">
                          <p className="font-medium text-gray-900 text-sm">{svc.name}</p>
                          {svc.pricePerHour != null && (
                            <p className="text-sm font-semibold text-primary-700 shrink-0">
                              ₹{svc.pricePerHour}/hr
                            </p>
                          )}
                        </div>
                        {svc.description && (
                          <p className="text-xs text-gray-500 mt-0.5">{svc.description}</p>
                        )}
                        <div className="flex gap-3 mt-1 text-xs text-gray-400">
                          {svc.capacity && <span>Capacity: {svc.capacity}</span>}
                          <span>Min: {svc.minDuration} min</span>
                          {svc.maxDuration && <span>Max: {svc.maxDuration} min</span>}
                          {!svc.isActive && (
                            <span className="text-red-400 font-medium">Inactive</span>
                          )}
                        </div>
                      </div>
                    </div>
                    {/* Multiple service images */}
                    {Array.isArray((svc as any).imageUrls) && (svc as any).imageUrls.length > 1 && (
                      <div className="mt-2 grid grid-cols-4 gap-1.5">
                        {(svc as any).imageUrls.map((url: string, i: number) => (
                          <img
                            key={i}
                            src={assetUrl(url)}
                            alt={`${svc.name} ${i + 1}`}
                            className="w-full aspect-square object-cover rounded-md"
                          />
                        ))}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Amenities */}
          {amenities.length > 0 && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <Star size={16} className="text-gray-400" /> Amenities
              </h3>
              <div className="flex flex-wrap gap-2">
                {amenities.map((a, i) => (
                  <span
                    key={i}
                    className="text-xs bg-primary-50 text-primary-700 px-2.5 py-1 rounded-full font-medium"
                  >
                    {a}
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* Images */}
          {venue.images && venue.images.length > 0 && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <Image size={16} className="text-gray-400" /> Photos ({venue.images.length})
              </h3>
              <div className="grid grid-cols-3 gap-2">
                {venue.images.map((img) => (
                  <div
                    key={img.id}
                    className="relative aspect-video rounded-lg overflow-hidden bg-gray-100"
                  >
                    <img
                      src={assetUrl(img.imageUrl)}
                      alt={img.caption ?? 'Venue photo'}
                      className="w-full h-full object-cover"
                    />
                    {img.isPrimary && (
                      <span className="absolute top-1 left-1 text-xs bg-primary-600 text-white px-1.5 py-0.5 rounded font-medium">
                        Primary
                      </span>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Venue Answers — grouped by category */}
          {answerGroups.length > 0 && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-4 flex items-center gap-2">
                <ClipboardList size={16} className="text-gray-400" /> Q&amp;A Responses
              </h3>
              <div className="space-y-5">
                {answerGroups.map((group) => (
                  <div key={group.catId}>
                    {/* Category header — always show so admin knows which category each Q&A belongs to */}
                    <div className="flex items-center gap-2 mb-2.5 pb-2 border-b border-gray-100">
                      <img src={activityLogoUrl(group.catName)} alt="" className="w-7 h-7 object-contain" />
                      <span className="text-xs font-semibold text-gray-700 uppercase tracking-wide">
                        {group.catName}
                      </span>
                      <span className="text-xs text-gray-400 ml-auto">
                        {group.answers.length} answer{group.answers.length !== 1 ? 's' : ''}
                      </span>
                    </div>
                    <div className="space-y-3">
                      {group.answers.map((ans) => {
                        const label = questionLabel(ans);
                        if (!label) return null;
                        return (
                          <div key={ans.id} className="text-sm">
                            <p className="text-gray-500 text-xs">
                              {label}
                            </p>
                            <p className="text-gray-900 mt-0.5">
                              {Array.isArray(ans.answer)
                                ? ans.answer.join(', ')
                                : String(ans.answer)}
                            </p>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Right column — partner info */}
        <div className="space-y-5">
          {/* Partner */}
          {partner && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-4 flex items-center gap-2">
                <User size={16} className="text-gray-400" /> Partner Information
              </h3>
              <div className="space-y-2.5">
                <InfoRow label="Name" value={partnerName || 'Profile not completed'} />
                <InfoRow label="Email" value={partner.email?.trim() || 'Not provided'} />
                <InfoRow label="Phone" value={partner.phone} />
                <InfoRow label="Contact Phone" value={partner.contactPhone} />
                <InfoRow label="Business" value={partner.businessName} />
                <InfoRow label="Address" value={partner.businessAddress} />
                <InfoRow label="City / State" value={partner.city && partner.state ? `${partner.city}, ${partner.state}` : (partner.city ?? partner.state ?? null)} />
                <InfoRow label="GST No." value={partner.gstNumber} />
                <InfoRow label="PAN No." value={partner.panNumber} />
                <InfoRow label="Bank Account" value={partner.bankAccountNumber} />
                <InfoRow label="IFSC" value={partner.bankIfscCode} />
                <InfoRow label="Account Holder" value={partner.bankAccountHolderName} />
              </div>
            </div>
          )}

          {/* KYC Documents — data comes from venue.partner (flat object) */}
          {partner && (partner.aadhaarNumber || partner.panCardUrl || partner.aadhaarCardUrl || partner.gstinDocUrl) && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-4 flex items-center gap-2">
                <ShieldCheck size={16} className="text-gray-400" /> KYC Documents
              </h3>
              <div className="space-y-4">

                {/* ── Aadhar ── */}
                <InfoRow label="Aadhar Name" value={partner.aadhaarName} />
                <InfoRow label="Aadhar No." value={partner.aadhaarNumber} />
                <KycDocImage label="Aadhar Card" src={partner.aadhaarCardUrl} />

                {/* ── PAN ── */}
                <InfoRow label="PAN No." value={partner.panNumber} />
                <KycDocImage label="PAN Card" src={partner.panCardUrl} />

                {/* ── GST ── */}
                <InfoRow label="GST No." value={partner.gstNumber} />
                <KycDocImage label="GST Certificate" src={partner.gstinDocUrl} />

              </div>
            </div>
          )}

          {/* Categories (multi-category support) */}
          {allCategories.length > 0 && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <Tag size={16} className="text-gray-400" />
                {allCategories.length > 1 ? `Categories (${allCategories.length})` : 'Category'}
              </h3>
              <div className="space-y-2">
                {allCategories.map((cat: any, i: number) => (
                  <div key={cat.id ?? i} className="flex items-start gap-2">
                    <img src={activityLogoUrl(cat.name)} alt="" className="w-7 h-7 object-contain shrink-0" />
                    <div className="min-w-0">
                      <p className="font-medium text-gray-900 text-sm break-words">{cat.name}</p>
                      {cat.description && (
                        <p className="text-xs text-gray-500 break-words">{cat.description}</p>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Timeline */}
          <div className="bg-white rounded-xl border border-gray-100 p-5">
            <h3 className="text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
              <Clock size={16} className="text-gray-400" /> Timeline
            </h3>
            <div className="space-y-2 text-xs">
              <div className="flex justify-between">
                <span className="text-gray-400">Submitted</span>
                <span className="text-gray-700">
                  {new Date(venue.submittedAt ?? venue.createdAt).toLocaleDateString('en-IN', {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric',
                  })}
                </span>
              </div>
              {venue.approvedAt && (
                <div className="flex justify-between">
                  <span className="text-gray-400">Approved</span>
                  <span className="text-gray-700">
                    {new Date(venue.approvedAt).toLocaleDateString('en-IN', {
                      day: '2-digit',
                      month: 'short',
                      year: 'numeric',
                    })}
                  </span>
                </div>
              )}
              {venue.approvedBy && (
                <div className="flex justify-between items-start gap-3">
                  <span className="text-gray-400 shrink-0">Approved By</span>
                  <span className="text-gray-700 min-w-0 text-right break-words">{venue.approvedByName?.trim() || 'Admin'}</span>
                </div>
              )}
              <div className="flex justify-between">
                <span className="text-gray-400">Last Updated</span>
                <span className="text-gray-700">
                  {new Date(venue.updatedAt).toLocaleDateString('en-IN', {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric',
                  })}
                </span>
              </div>
            </div>
          </div>

          {/* Terms & Signature */}
          {((venue as any).termsAccepted || (venue as any).electronicSignature) && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <ShieldCheck size={16} className="text-gray-400" /> Terms &amp; Signature
              </h3>
              <div className="space-y-2 text-xs">
                <div className="flex justify-between items-center">
                  <span className="text-gray-400">Terms Accepted</span>
                  {(venue as any).termsAccepted ? (
                    <span className="flex items-center gap-1 text-emerald-600 font-medium">
                      <CheckSquare size={12} /> Yes
                    </span>
                  ) : (
                    <span className="text-gray-500">No</span>
                  )}
                </div>
                {(venue as any).termsAcceptedAt && (
                  <div className="flex justify-between">
                    <span className="text-gray-400">Accepted At</span>
                    <span className="text-gray-700">
                      {new Date((venue as any).termsAcceptedAt).toLocaleDateString('en-IN', {
                        day: '2-digit',
                        month: 'short',
                        year: 'numeric',
                      })}
                    </span>
                  </div>
                )}
                {(venue as any).electronicSignature && (
                  <div className="flex justify-between">
                    <span className="text-gray-400">E-Signature</span>
                    <span className="text-gray-700 font-mono">
                      {(venue as any).electronicSignature}
                    </span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Location map link */}
          {venue.latitude && venue.longitude && (
            <a
              href={`https://www.google.com/maps?q=${venue.latitude},${venue.longitude}`}
              target="_blank"
              rel="noreferrer"
              className="flex items-center gap-2 bg-white rounded-xl border border-gray-100 p-4 text-sm text-primary-600 font-medium hover:bg-primary-50 transition-colors"
            >
              <MapPin size={16} />
              View on Google Maps
            </a>
          )}
        </div>
      </div>

      {/* Modals */}
      <ApproveModal
        open={approveOpen}
        venueName={venue.name}
        loading={approveMutation.isPending}
        onConfirm={() => approveMutation.mutate()}
        onCancel={() => setApproveOpen(false)}
      />
      <RejectModal
        open={rejectOpen}
        venueName={venue.name}
        loading={rejectMutation.isPending}
        onConfirm={(reason) => rejectMutation.mutate(reason)}
        onCancel={() => setRejectOpen(false)}
      />
      <RequestChangesModal
        open={changesOpen}
        venueName={venue.name}
        loading={requestChangesMutation.isPending}
        onConfirm={(reason) => requestChangesMutation.mutate(reason)}
        onCancel={() => setChangesOpen(false)}
      />
      <ConfirmDialog
        open={deleteOpen}
        title={venue.canPermanentlyDelete ? 'Permanently Delete Venue' : 'Delete Venue'}
        message={venue.canPermanentlyDelete
          ? `Permanently delete "${venue.name}" and its associated venue data and booking history from the database? This cannot be undone. Active bookings must be cancelled or completed first.`
          : `Delete "${venue.name}"? This will archive the venue and disable new bookings. Deleting it again as an admin will permanently remove it from the database.`}
        confirmLabel={venue.canPermanentlyDelete ? 'Permanently Delete' : 'Delete'}
        variant="danger"
        loading={deleteMutation.isPending}
        onConfirm={() => deleteMutation.mutate()}
        onCancel={() => setDeleteOpen(false)}
      />
    </div>
  );
};
