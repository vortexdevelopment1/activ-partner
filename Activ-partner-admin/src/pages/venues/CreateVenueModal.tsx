import React, { useState, useRef, useMemo, useEffect, useCallback } from 'react';
import { useMutation, useQuery, useQueries, useQueryClient } from '@tanstack/react-query';
import {
  X, ChevronRight, ChevronLeft, Plus, Search, User, Check, UserPlus,
  Upload, MapPin, Loader2,
} from 'lucide-react';
import api from '../../api/axios';
import { venuesApi } from '../../api/venues.api';
import { categoriesApi } from '../../api/categories.api';
import { partnersApi } from '../../api/partners.api';
import { questionsApi } from '../../api/questions.api';
import { useToast } from '../../hooks/useToast';
import type { Category, Partner } from '../../types';

// ─── Constants ────────────────────────────────────────────────────────────────

const GOOGLE_API_KEY = 'AIzaSyB8CL4cLELFreHWPY_NnmjwCo_mWS7T6Ng';

const AMENITIES = [
  'Parking', 'First Aid', 'WiFi', 'Air Conditioning',
  'Locker Room', 'Lounge', 'Trainer', 'Flood Lighting',
  'Fencing', 'Shower Room', 'Sound System', 'Child Care',
  'CCTV Security', 'Equipment Rental',
];

const STEPS = [
  'Partner & Basics',
  'Location & Details',
  'Amenities',
  'Categories',
  'Category Questions',
  'Legal Information',
  'Images',
];

// ─── Types ────────────────────────────────────────────────────────────────────

type QuestionType = 'TEXT' | 'TEXTAREA' | 'NUMBER' | 'SELECT' | 'RADIO' | 'MULTISELECT' | 'CHECKBOX' | 'DATE';

interface Question {
  id: string;
  questionText: string;
  questionType: QuestionType;
  options?: string[];
  isRequired: boolean;
  order: number;
  placeholder?: string;
  helperText?: string;
  categoryId?: string | null;
}


interface PlaceSuggestion {
  placeId: string;
  description: string;
}

interface FormState {
  partnerId: string;
  partnerLabel: string;
  name: string;
  venuePhone: string;
  description: string;
  flatBuilding: string;
  address: string;
  city: string;
  state: string;
  zipCode: string;
  latitude: number | '';
  longitude: number | '';
  commission: number | string;
  categoryIds: string[];
  amenities: string[];
  answers: Record<string, any>;
  fullName: string;
  aadhaarNumber: string;
  aadhaarFile: File | null;
  panNumber: string;
  panFile: File | null;
  gstin: string;
  gstinFile: File | null;
  images: File[];
}

interface NewPartnerForm {
  phone: string;
  firstName: string;
  lastName: string;
  email: string;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const emptyNewPartner = (): NewPartnerForm => ({ phone: '', firstName: '', lastName: '', email: '' });

const initialState = (): FormState => ({
  partnerId: '', partnerLabel: '', name: '', venuePhone: '',
  description: '', flatBuilding: '', address: '',
  city: '', state: '', zipCode: '', latitude: '', longitude: '', commission: '',
  categoryIds: [], amenities: [],
  answers: {},
  fullName: '', aadhaarNumber: '', aadhaarFile: null,
  panNumber: '', panFile: null,
  gstin: '', gstinFile: null,
  images: [],
});

// Load Google Maps JS API (with Places library) exactly once
const loadGoogleMapsScript = (): Promise<void> => {
  if ((window as any).google?.maps?.places) return Promise.resolve();
  return new Promise((resolve) => {
    const existing = document.getElementById('gmaps-admin-script');
    if (existing) {
      const poll = setInterval(() => {
        if ((window as any).google?.maps?.places) { clearInterval(poll); resolve(); }
      }, 200);
      return;
    }
    const s = document.createElement('script');
    s.id = 'gmaps-admin-script';
    // &libraries=places enables AutocompleteService + PlacesService (no CORS issues)
    s.src = `https://maps.googleapis.com/maps/api/js?key=${GOOGLE_API_KEY}&libraries=places`;
    s.async = true;
    s.onload = () => resolve();
    document.head.appendChild(s);
  });
};

// ─── Sub-components ───────────────────────────────────────────────────────────

const FileUploadZone: React.FC<{
  field: 'aadhaarFile' | 'panFile' | 'gstinFile';
  file: File | null;
  label: string;
  required: boolean;
  showError: boolean;
  onChange: (field: 'aadhaarFile' | 'panFile' | 'gstinFile', files: FileList | null) => void;
}> = ({ field, file, label, required, showError, onChange }) => (
  <div className={`border-2 border-dashed rounded-xl p-5 text-center transition-colors ${
    showError && required && !file ? 'border-red-300 bg-red-50/30' : 'border-gray-200'
  }`}>
    <Upload size={22} className="mx-auto text-gray-300 mb-1.5" />
    {file ? (
      <p className="text-sm font-medium text-emerald-600 flex items-center justify-center gap-1">
        <Check size={14} /> {file.name}
      </p>
    ) : (
      <>
        <p className="text-sm font-medium text-gray-600">
          {label}{required && <span className="text-red-500 ml-0.5">*</span>}
        </p>
        <p className="text-xs text-gray-400 mt-0.5 mb-3">PDF, JPG, JPEG, PNG · Max 5 MB</p>
        {/* Visible label-wrapped input — most reliable cross-browser file trigger */}
        <label className="inline-flex items-center gap-1.5 px-4 py-2 bg-primary-600 text-white text-sm font-medium rounded-lg cursor-pointer hover:bg-primary-700 transition-colors select-none">
          <input
            type="file"
            accept=".pdf,.jpg,.jpeg,.png"
            className="sr-only"
            onChange={e => { onChange(field, e.target.files); e.target.value = ''; }}
          />
          Browse File
        </label>
      </>
    )}
    {showError && required && !file && (
      <p className="text-xs text-red-500 mt-2">Please upload this document</p>
    )}
  </div>
);

const Label: React.FC<{ children: React.ReactNode; required?: boolean }> = ({ children, required }) => (
  <label className="label">
    {children}{required && <span className="text-red-500 ml-0.5">*</span>}
  </label>
);

const QuestionField: React.FC<{
  q: Question;
  value: any;
  onChange: (v: any) => void;
}> = ({ q, value, onChange }) => {
  const hint = q.helperText ? (
    <p className="text-xs text-gray-400 mt-1">{q.helperText}</p>
  ) : null;

  if (q.questionType === 'TEXTAREA') {
    return (
      <div>
        <Label required={q.isRequired}>{q.questionText}</Label>
        <textarea className="input resize-none" rows={3} placeholder={q.placeholder ?? ''}
          value={value ?? ''} onChange={e => onChange(e.target.value)} />
        {hint}
      </div>
    );
  }

  if (q.questionType === 'NUMBER') {
    return (
      <div>
        <Label required={q.isRequired}>{q.questionText}</Label>
        <input className="input" type="number" placeholder={q.placeholder ?? ''}
          value={value ?? ''}
          onChange={e => onChange(e.target.value === '' ? '' : Number(e.target.value))} />
        {hint}
      </div>
    );
  }

  if (q.questionType === 'DATE') {
    return (
      <div>
        <Label required={q.isRequired}>{q.questionText}</Label>
        <input className="input" type="date" value={value ?? ''} onChange={e => onChange(e.target.value)} />
        {hint}
      </div>
    );
  }

  if (q.questionType === 'SELECT' || q.questionType === 'RADIO') {
    return (
      <div>
        <Label required={q.isRequired}>{q.questionText}</Label>
        <div className="flex flex-wrap gap-2 mt-1.5">
          {(q.options ?? []).map(opt => (
            <button key={opt} type="button" onClick={() => onChange(opt)}
              className={`px-3 py-1.5 rounded-lg border text-sm transition-colors ${
                value === opt
                  ? 'border-primary-500 bg-primary-50 text-primary-700 font-medium'
                  : 'border-gray-200 text-gray-600 hover:bg-gray-50'
              }`}>
              {opt}
            </button>
          ))}
        </div>
        {hint}
      </div>
    );
  }

  if (q.questionType === 'MULTISELECT' || q.questionType === 'CHECKBOX') {
    const selected: string[] = Array.isArray(value) ? value : [];
    return (
      <div>
        <Label required={q.isRequired}>{q.questionText}</Label>
        <div className="flex flex-wrap gap-2 mt-1.5">
          {(q.options ?? []).map(opt => {
            const active = selected.includes(opt);
            return (
              <button key={opt} type="button"
                onClick={() => onChange(active ? selected.filter(x => x !== opt) : [...selected, opt])}
                className={`px-3 py-1.5 rounded-lg border text-sm transition-colors flex items-center gap-1.5 ${
                  active
                    ? 'border-primary-500 bg-primary-50 text-primary-700 font-medium'
                    : 'border-gray-200 text-gray-600 hover:bg-gray-50'
                }`}>
                {active && <Check size={11} />}
                {opt}
              </button>
            );
          })}
        </div>
        {hint}
      </div>
    );
  }

  // Default: TEXT
  return (
    <div>
      <Label required={q.isRequired}>{q.questionText}</Label>
      <input className="input" placeholder={q.placeholder ?? ''}
        value={value ?? ''} onChange={e => onChange(e.target.value)} />
      {hint}
    </div>
  );
};

// ─── Main Component ───────────────────────────────────────────────────────────

interface Props {
  open: boolean;
  onClose: () => void;
}

export const CreateVenueModal: React.FC<Props> = ({ open, onClose }) => {
  const queryClient = useQueryClient();
  const { success, error } = useToast();
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Form & step
  const [step, setStep] = useState(0);
  const [form, setForm] = useState<FormState>(initialState());

  // Partner search state
  const [partnerSearch, setPartnerSearch] = useState('');
  const [showPartnerDropdown, setShowPartnerDropdown] = useState(false);
  const [showNewPartnerForm, setShowNewPartnerForm] = useState(false);
  const [newPartner, setNewPartner] = useState<NewPartnerForm>(emptyNewPartner());
  const [newPartnerSubmitted, setNewPartnerSubmitted] = useState(false);
  const [step1Submitted, setStep1Submitted] = useState(false);
  const [step4Submitted, setStep4Submitted] = useState(false);

  // Address autocomplete state
  const [addressSearch, setAddressSearch] = useState('');
  const [addressSuggestions, setAddressSuggestions] = useState<PlaceSuggestion[]>([]);
  const [isAddressLoading, setIsAddressLoading] = useState(false);
  const [showMap, setShowMap] = useState(false);
  const addressDebounceRef = useRef<ReturnType<typeof setTimeout>>();

  // Google Maps refs
  const mapDivRef = useRef<HTMLDivElement>(null);
  const googleMapRef = useRef<any>(null);
  const markerRef = useRef<any>(null);

  // Preload Google Maps SDK (with Places library) as soon as the modal opens
  useEffect(() => {
    if (open) loadGoogleMapsScript().catch(() => {});
  }, [open]);

  // ── Queries ──────────────────────────────────────────────────────────────────

  const { data: partnersData } = useQuery({
    queryKey: ['partners-search', partnerSearch],
    queryFn: () => partnersApi.getAll({ search: partnerSearch || undefined, limit: 20 }),
    enabled: open,
  });

  const { data: categoriesData } = useQuery({
    queryKey: ['categories-active'],
    queryFn: () => categoriesApi.getAllActive(),
    enabled: open,
  });

  const categoryQuestionsResults = useQueries({
    queries: form.categoryIds.map(categoryId => ({
      queryKey: ['questions', 'category', categoryId],
      queryFn: () => questionsApi.getByCategory(categoryId),
      enabled: open && form.categoryIds.length > 0,
    })),
  });

  const partners: Partner[] = partnersData?.data?.data?.items ?? [];
  const categories: Category[] = categoriesData?.data?.data ?? [];

  // ── Derived state ─────────────────────────────────────────────────────────────

  const questionGroups = useMemo(() => {
    const seenIds = new Set<string>();
    const globalQuestions: Question[] = [];
    const byCategory: Array<{ categoryId: string; categoryName: string; questions: Question[] }> = [];

    categoryQuestionsResults.forEach((res, idx) => {
      const categoryId = form.categoryIds[idx];
      if (!categoryId) return;
      const categoryName = categories.find(c => c.id === categoryId)?.name ?? '';
      const questions: Question[] = (res.data?.data?.data ?? res.data?.data ?? []) as Question[];
      const catQ: Question[] = [];

      questions.forEach(q => {
        if (seenIds.has(q.id)) return;
        seenIds.add(q.id);
        if (!q.categoryId) {
          globalQuestions.push(q);
        } else {
          catQ.push(q);
        }
      });

      if (catQ.length > 0) byCategory.push({ categoryId, categoryName, questions: catQ });
    });

    return { globalQuestions, byCategory };
  }, [categoryQuestionsResults, form.categoryIds, categories]);

  const flatRequiredQuestions = useMemo(() =>
    [
      ...questionGroups.globalQuestions,
      ...questionGroups.byCategory.flatMap(g => g.questions),
    ].filter(q => q.isRequired),
    [questionGroups],
  );

  const isQuestionsLoading = categoryQuestionsResults.some(r => r.isLoading);
  const hasQuestions = questionGroups.globalQuestions.length > 0 || questionGroups.byCategory.length > 0;

  // ── Google Maps – initialize ──────────────────────────────────────────────────

  useEffect(() => {
    if (step !== 1 || !showMap) return;

    const timer = setTimeout(async () => {
      if (!mapDivRef.current || googleMapRef.current) return;

      try {
        await loadGoogleMapsScript();

        if (!mapDivRef.current) return;

        const lat = typeof form.latitude === 'number' ? form.latitude : 20.5937;
        const lng = typeof form.longitude === 'number' ? form.longitude : 78.9629;
        const G = (window as any).google.maps;

        const map = new G.Map(mapDivRef.current, {
          center: { lat, lng },
          zoom: typeof form.latitude === 'number' ? 15 : 5,
          mapTypeControl: false,
          streetViewControl: false,
          fullscreenControl: false,
        });

        const marker = new G.Marker({
          position: { lat, lng },
          map,
          draggable: true,
          title: 'Drag to set exact venue location',
        });

        marker.addListener('dragend', () => {
          const pos = marker.getPosition();
          if (pos) {
            setForm(prev => ({ ...prev, latitude: pos.lat(), longitude: pos.lng() }));
          }
        });

        googleMapRef.current = map;
        markerRef.current = marker;
      } catch {
        // Maps JS failed to load — map section stays hidden gracefully
      }
    }, 150);

    return () => clearTimeout(timer);
  }, [step, showMap]); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Google Maps – sync marker when coordinates update from autocomplete ────────

  useEffect(() => {
    if (!markerRef.current || !googleMapRef.current) return;
    if (typeof form.latitude !== 'number' || typeof form.longitude !== 'number') return;

    const pos = { lat: form.latitude, lng: form.longitude };
    markerRef.current.setPosition(pos);
    googleMapRef.current.panTo(pos);
    googleMapRef.current.setZoom(15);
  }, [form.latitude, form.longitude]);

  // ── Handlers ──────────────────────────────────────────────────────────────────

  const set = <K extends keyof FormState>(key: K, value: FormState[K]) =>
    setForm(prev => ({ ...prev, [key]: value }));

  const setAnswer = (questionId: string, value: any) =>
    setForm(prev => ({ ...prev, answers: { ...prev.answers, [questionId]: value } }));

  const toggleAmenity = (a: string) =>
    set('amenities', form.amenities.includes(a)
      ? form.amenities.filter(x => x !== a) : [...form.amenities, a]);

  const toggleCategory = (id: string) =>
    set('categoryIds', form.categoryIds.includes(id)
      ? form.categoryIds.filter(x => x !== id) : [...form.categoryIds, id]);

  const updateLegalFile = (field: 'aadhaarFile' | 'panFile' | 'gstinFile', files: FileList | null) => {
    const file = files?.[0];
    if (!file) return;
    setForm(prev => ({ ...prev, [field]: file }));
  };


  const selectPartner = (p: Partner) => {
    const firstName = (p as any).firstName ?? p.user?.firstName ?? '';
    const lastName = (p as any).lastName ?? p.user?.lastName ?? '';
    const name = `${firstName} ${lastName}`.trim();
    set('partnerId', p.id);
    set('partnerLabel', name || p.businessName || p.id);
    setShowPartnerDropdown(false);
    setPartnerSearch('');
  };

  const addImages = (files: FileList | null) => {
    if (!files) return;
    set('images', [...form.images, ...Array.from(files)].slice(0, 12));
  };

  // ── Google Places — SDK-based autocomplete (no CORS issues) ─────────────────

  const fetchSuggestions = useCallback((input: string) => {
    const G = (window as any).google;
    if (!G?.maps?.places) return;
    setIsAddressLoading(true);
    const svc = new G.maps.places.AutocompleteService();
    svc.getPlacePredictions(
      { input, componentRestrictions: { country: 'in' } },
      (predictions: any[], status: string) => {
        setIsAddressLoading(false);
        if (status !== G.maps.places.PlacesServiceStatus.OK || !predictions) {
          setAddressSuggestions([]);
          return;
        }
        setAddressSuggestions(
          predictions.map((p: any) => ({ placeId: p.place_id, description: p.description })),
        );
      },
    );
  }, []);

  const handleAddressInput = (value: string) => {
    setAddressSearch(value);
    if (form.address && value !== form.address) {
      setForm(prev => ({ ...prev, address: '', latitude: '', longitude: '' }));
      setShowMap(false);
      googleMapRef.current = null;
      markerRef.current = null;
    }
    clearTimeout(addressDebounceRef.current);
    if (value.length < 3) { setAddressSuggestions([]); return; }
    addressDebounceRef.current = setTimeout(() => {
      const G = (window as any).google;
      if (G?.maps?.places) {
        fetchSuggestions(value);
      } else {
        // SDK not yet loaded — load it then fetch
        loadGoogleMapsScript().then(() => fetchSuggestions(value));
      }
    }, 500);
  };

  const fetchPlaceDetails = (placeId: string, description: string) => {
    setAddressSuggestions([]);
    setAddressSearch(description);
    setIsAddressLoading(true);

    const G = (window as any).google;
    if (!G?.maps?.places) { setIsAddressLoading(false); return; }

    // PlacesService requires a DOM element or map instance
    const dummy = document.createElement('div');
    const svc = new G.maps.places.PlacesService(dummy);

    svc.getDetails(
      { placeId, fields: ['address_components', 'geometry', 'formatted_address'] },
      (place: any, status: string) => {
        setIsAddressLoading(false);
        if (status !== G.maps.places.PlacesServiceStatus.OK || !place) {
          error('Could not fetch address details. Please fill the fields manually.');
          return;
        }

        const components: any[] = place.address_components ?? [];
        const get = (type: string) =>
          components.find((c: any) => c.types.includes(type))?.long_name ?? '';

        const streetNumber = get('street_number');
        const route = get('route');
        const sublocality = get('sublocality_level_1') || get('sublocality');
        const city = get('locality') || get('administrative_area_level_2');
        const state = get('administrative_area_level_1');
        const zipCode = get('postal_code');
        const lat: number | '' = place.geometry?.location?.lat() ?? '';
        const lng: number | '' = place.geometry?.location?.lng() ?? '';

        const addressParts = [streetNumber, route, sublocality].filter(Boolean);
        const address = addressParts.length > 0
          ? addressParts.join(', ')
          : (place.formatted_address ?? description);

        setAddressSearch(place.formatted_address ?? description);
        setForm(prev => ({
          ...prev,
          address,
          city: city || prev.city,
          state: state || prev.state,
          zipCode: zipCode || prev.zipCode,
          latitude: lat,
          longitude: lng,
        }));

        googleMapRef.current = null;
        markerRef.current = null;
        setShowMap(true);
      },
    );
  };

  // Auto-fill city & state from pincode via backend
  const lookupPincode = async (pin: string) => {
    if (!/^\d{6}$/.test(pin)) return;
    try {
      const res = await api.get(`/location/pincode/${pin}`);
      const data = res.data?.data;
      if (data?.city) setForm(prev => ({ ...prev, city: data.city }));
      if (data?.state) setForm(prev => ({ ...prev, state: data.state }));
    } catch {
      // silently ignore — user can fill manually
    }
  };

  const canNext = () => {
    if (step === 0) return !!form.partnerId && !!form.name.trim() && /^\d{10}$/.test(form.venuePhone);
    if (step === 1) return !!(form.address || addressSearch) && !!form.city.trim() && !!form.state.trim() && /^\d{6}$/.test(form.zipCode);
    if (step === 2) return true; // Amenities are optional
    if (step === 3) return form.categoryIds.length > 0;
    if (step === 4) {
      return flatRequiredQuestions.every(q => {
        const val = form.answers[q.id];
        if (val === undefined || val === null || val === '') return false;
        if (Array.isArray(val) && val.length === 0) return false;
        return true;
      });
    }
    if (step === 5) {
      return (
        !!form.fullName.trim() &&
        /^\d{12}$/.test(form.aadhaarNumber) &&
        !!form.aadhaarFile &&
        /^[A-Z]{5}[0-9]{4}[A-Z]$/.test(form.panNumber) &&
        !!form.panFile
      );
    }
    return true;
  };

  const handleClose = () => {
    setStep(0);
    setForm(initialState());
    setPartnerSearch('');
    setShowPartnerDropdown(false);
    setShowNewPartnerForm(false);
    setNewPartner(emptyNewPartner());
    setNewPartnerSubmitted(false);
    setStep1Submitted(false);
    setStep4Submitted(false);
    setAddressSearch('');
    setAddressSuggestions([]);
    setShowMap(false);
    googleMapRef.current = null;
    markerRef.current = null;
    onClose();
  };

  // ── Mutations ─────────────────────────────────────────────────────────────────

  const mutation = useMutation({
    mutationFn: async () => {
      const answers = Object.entries(form.answers)
        .filter(([, v]) => v !== undefined && v !== '' && !(Array.isArray(v) && v.length === 0))
        .map(([questionId, answer]) => ({ questionId, answer }));

      const venueRes = await venuesApi.adminCreate({
        partnerId: form.partnerId,
        categoryIds: form.categoryIds,
        name: form.name.trim(),
        description: form.description || undefined,
        venuePhone: form.venuePhone || undefined,
        flatBuilding: form.flatBuilding || undefined,
        address: form.address || addressSearch || undefined,
        city: form.city || undefined,
        state: form.state || undefined,
        zipCode: form.zipCode || undefined,
        latitude: typeof form.latitude === 'number' ? form.latitude : undefined,
        longitude: typeof form.longitude === 'number' ? form.longitude : undefined,
        commission: form.commission !== '' ? Number(form.commission) : undefined,
        amenities: form.amenities.length > 0 ? form.amenities : undefined,
        answers: answers.length > 0 ? answers : undefined,
      });

      const venueId = venueRes?.data?.data?.id;
      const warnings: string[] = [];

      // Upload venue images — partner-scoped endpoint; skip gracefully if admin lacks permission
      if (form.images.length > 0 && venueId) {
        try {
          await venuesApi.uploadImages(venueId, form.images, form.name.trim());
        } catch {
          warnings.push('Images could not be uploaded (partner permission required).');
        }
      }

      // Submit legal information
      if (venueId && form.aadhaarFile && form.panFile) {
        try {
          await venuesApi.submitLegal(venueId, {
            aadhaarName: form.fullName.trim(),
            aadhaarNumber: form.aadhaarNumber.trim(),
            panNumber: form.panNumber.trim(),
            aadhaarCard: form.aadhaarFile,
            panCard: form.panFile,
            gstNumber: form.gstin.trim() || undefined,
            gstinDoc: form.gstinFile ?? undefined,
          });
        } catch {
          warnings.push('Legal documents could not be submitted (partner permission required).');
        }
      }

      return { venueRes, warnings };
    },
    onSuccess: ({ warnings }) => {
      queryClient.invalidateQueries({ queryKey: ['venues'] });
      success('Venue created successfully!');
      warnings.forEach(w => error(w));
      handleClose();
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to create venue'),
  });

  const createPartnerMutation = useMutation({
    mutationFn: () => partnersApi.create({
      phone: newPartner.phone.trim() || undefined,
      firstName: newPartner.firstName.trim() || undefined,
      lastName: newPartner.lastName.trim() || undefined,
      email: newPartner.email.trim() || undefined,
    }),
    onSuccess: (res: any) => {
      const p = res?.data?.data;
      if (p) {
        set('partnerId', p.id);
        const name = `${p.firstName ?? ''} ${p.lastName ?? ''}`.trim();
        set('partnerLabel', name || p.businessName || 'New Partner');
      }
      setShowNewPartnerForm(false);
      setShowPartnerDropdown(false);
      setNewPartner(emptyNewPartner());
      setNewPartnerSubmitted(false);
      queryClient.invalidateQueries({ queryKey: ['partners-search'] });
      success('Partner created and selected!');
    },
    onError: (err: any) => error(err?.response?.data?.message ?? 'Failed to create partner'),
  });

  if (!open) return null;

  // ── Render ────────────────────────────────────────────────────────────────────

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={handleClose} />
      <div className="relative bg-white rounded-2xl shadow-xl w-full max-w-2xl max-h-[90vh] flex flex-col">

        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 shrink-0">
          <div>
            <h3 className="text-lg font-semibold text-gray-900">Create Venue</h3>
            <p className="text-xs text-gray-400 mt-0.5">
              Step {step + 1} of {STEPS.length} — {STEPS[step]}
            </p>
          </div>
          <button onClick={handleClose} className="p-1.5 rounded-lg hover:bg-gray-100 transition-colors">
            <X size={18} className="text-gray-500" />
          </button>
        </div>

        {/* Progress bar */}
        <div className="px-6 pt-3 pb-1 shrink-0">
          <div className="flex gap-1.5">
            {STEPS.map((_, i) => (
              <div key={i}
                className={`h-1 flex-1 rounded-full transition-colors ${i <= step ? 'bg-primary-600' : 'bg-gray-100'}`}
              />
            ))}
          </div>
        </div>


        {/* Body */}
        <div className="flex-1 overflow-y-auto px-6 py-4 space-y-4">

          {/* ── Step 1: Partner & Basics ── */}
          {step === 0 && (
            <>
              {/* Partner search */}
              <div className="relative">
                <Label required>Partner</Label>
                <div className="relative">
                  <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                  <input
                    className="input pl-8"
                    placeholder="Search partner by name or phone…"
                    value={form.partnerId ? form.partnerLabel : partnerSearch}
                    readOnly={!!form.partnerId}
                    onChange={e => {
                      setPartnerSearch(e.target.value);
                      setShowPartnerDropdown(true);
                      setShowNewPartnerForm(false);
                    }}
                    onFocus={() => { if (!form.partnerId) setShowPartnerDropdown(true); }}
                  />
                  {form.partnerId && (
                    <button type="button"
                      onClick={() => { set('partnerId', ''); set('partnerLabel', ''); setShowPartnerDropdown(false); setShowNewPartnerForm(false); }}
                      className="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-gray-400 hover:text-gray-700 px-1.5 py-0.5 rounded hover:bg-gray-100"
                    >
                      Change
                    </button>
                  )}
                </div>

                {showPartnerDropdown && !form.partnerId && !showNewPartnerForm && (
                  <div className="absolute z-20 w-full mt-1 bg-white border border-gray-200 rounded-xl shadow-lg overflow-hidden">
                    <div className="max-h-44 overflow-y-auto">
                      {partners.length === 0 ? (
                        <p className="px-4 py-3 text-sm text-gray-400">No partners found</p>
                      ) : (
                        partners.map(p => {
                          const firstName = (p as any).firstName ?? p.user?.firstName ?? '';
                          const lastName = (p as any).lastName ?? p.user?.lastName ?? '';
                          const phone = (p as any).phone ?? '';
                          const displayName = `${firstName} ${lastName}`.trim();
                          return (
                            <button key={p.id} type="button"
                              className="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 flex items-center gap-2.5 transition-colors"
                              onMouseDown={() => selectPartner(p)}
                            >
                              <div className="w-7 h-7 rounded-full bg-primary-100 flex items-center justify-center shrink-0">
                                <User size={13} className="text-primary-600" />
                              </div>
                              <div className="min-w-0">
                                <p className="font-medium text-gray-900 truncate">{displayName || phone || '—'}</p>
                                {p.businessName && <p className="text-xs text-gray-400 truncate">{p.businessName}</p>}
                              </div>
                            </button>
                          );
                        })
                      )}
                    </div>
                    <div className="border-t border-gray-100">
                      <button type="button"
                        className="w-full text-left px-4 py-2.5 text-sm text-primary-600 hover:bg-primary-50 flex items-center gap-2.5 transition-colors font-medium"
                        onMouseDown={() => { setShowNewPartnerForm(true); setShowPartnerDropdown(false); }}
                      >
                        <UserPlus size={14} /> Create New Partner
                      </button>
                    </div>
                  </div>
                )}

                {form.partnerId && (
                  <p className="mt-1 text-xs text-emerald-600 flex items-center gap-1">
                    <Check size={11} /> {form.partnerLabel} selected
                  </p>
                )}
              </div>

              {/* Inline new partner form */}
              {showNewPartnerForm && !form.partnerId && (
                <div className="border border-primary-200 bg-primary-50/40 rounded-xl p-4 space-y-3">
                  <div className="flex items-center justify-between">
                    <p className="text-sm font-semibold text-primary-800 flex items-center gap-1.5">
                      <UserPlus size={14} /> Create New Partner
                    </p>
                    <button type="button"
                      onClick={() => { setShowNewPartnerForm(false); setNewPartner(emptyNewPartner()); setNewPartnerSubmitted(false); }}
                      className="text-gray-400 hover:text-gray-600"
                    >
                      <X size={14} />
                    </button>
                  </div>

                  {(() => {
                    const phoneValid = /^\d{10}$/.test(newPartner.phone);
                    const firstNameValid = !!newPartner.firstName.trim();
                    const lastNameValid = !!newPartner.lastName.trim();
                    const emailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newPartner.email);
                    const formValid = phoneValid && firstNameValid && lastNameValid && emailValid;
                    const err = (msg: string) => (
                      <p className="text-xs text-red-500 mt-1">{msg}</p>
                    );
                    return (
                      <>
                        <div>
                          <label className="label">Mobile Number <span className="text-red-500">*</span></label>
                          <div className="flex gap-2">
                            <span className="input w-auto px-3 bg-gray-50 text-gray-500 shrink-0 flex items-center text-sm">IND (+91)</span>
                            <input
                              className={`input flex-1 ${newPartnerSubmitted && !phoneValid ? 'border-red-400 focus:ring-red-300' : ''}`}
                              placeholder="9801234567"
                              maxLength={10}
                              value={newPartner.phone}
                              onChange={e => setNewPartner(p => ({ ...p, phone: e.target.value.replace(/\D/g, '').slice(0, 10) }))}
                            />
                          </div>
                          {newPartnerSubmitted && !phoneValid && err('Enter a valid 10-digit mobile number')}
                          {!newPartnerSubmitted && <p className="text-xs text-gray-400 mt-1">Partner logs in via OTP using this number on the mobile app</p>}
                        </div>

                        <div className="grid grid-cols-2 gap-3">
                          <div>
                            <label className="label">First Name <span className="text-red-500">*</span></label>
                            <input
                              className={`input ${newPartnerSubmitted && !firstNameValid ? 'border-red-400 focus:ring-red-300' : ''}`}
                              placeholder="Virat"
                              value={newPartner.firstName}
                              onChange={e => setNewPartner(p => ({ ...p, firstName: e.target.value }))}
                            />
                            {newPartnerSubmitted && !firstNameValid && err('First name is required')}
                          </div>
                          <div>
                            <label className="label">Last Name <span className="text-red-500">*</span></label>
                            <input
                              className={`input ${newPartnerSubmitted && !lastNameValid ? 'border-red-400 focus:ring-red-300' : ''}`}
                              placeholder="Kohli"
                              value={newPartner.lastName}
                              onChange={e => setNewPartner(p => ({ ...p, lastName: e.target.value }))}
                            />
                            {newPartnerSubmitted && !lastNameValid && err('Last name is required')}
                          </div>
                        </div>

                        <div>
                          <label className="label">Email Address <span className="text-red-500">*</span></label>
                          <input
                            className={`input ${newPartnerSubmitted && !emailValid ? 'border-red-400 focus:ring-red-300' : ''}`}
                            type="email"
                            placeholder="partner@email.com"
                            value={newPartner.email}
                            onChange={e => setNewPartner(p => ({ ...p, email: e.target.value }))}
                          />
                          {newPartnerSubmitted && !emailValid && err('Enter a valid email address')}
                        </div>

                        <button
                          type="button"
                          onClick={() => {
                            setNewPartnerSubmitted(true);
                            if (formValid) createPartnerMutation.mutate();
                          }}
                          disabled={createPartnerMutation.isPending}
                          className="btn-primary text-sm w-full"
                        >
                          {createPartnerMutation.isPending ? 'Creating Partner…' : 'Create & Select Partner'}
                        </button>
                      </>
                    );
                  })()}
                </div>
              )}

              <div>
                <Label required>Venue Name</Label>
                <input className="input" placeholder="Gold Star Gym" value={form.name}
                  onChange={e => set('name', e.target.value)} />
              </div>

              <div>
                <Label required>Venue Contact Number</Label>
                <div className="flex gap-2">
                  <span className="input w-auto px-3 bg-gray-50 text-gray-500 shrink-0 flex items-center text-sm">IND (+91)</span>
                  <input
                    className={`input flex-1 ${form.venuePhone && !/^\d{10}$/.test(form.venuePhone) ? 'border-red-400 focus:ring-red-300' : ''}`}
                    placeholder="9876543210"
                    maxLength={10}
                    value={form.venuePhone}
                    onChange={e => set('venuePhone', e.target.value.replace(/\D/g, '').slice(0, 10))}
                  />
                </div>
                {form.venuePhone && !/^\d{10}$/.test(form.venuePhone)
                  ? <p className="text-xs text-red-500 mt-1">Enter a valid 10-digit contact number</p>
                  : <p className="text-xs text-gray-400 mt-1">Members &amp; ACTIV may call this number for booking support</p>
                }
              </div>
            </>
          )}

          {/* ── Step 2: Location & Details ── */}
          {step === 1 && (
            <>
              <div>
                <Label>Description</Label>
                <textarea className="input resize-none" rows={3}
                  placeholder="Briefly describe your venue…"
                  value={form.description} onChange={e => set('description', e.target.value)} />
              </div>

              {/* ── Google Places Address Search ── */}
              <div className="relative">
                <Label required>Venue Address</Label>
                <div className="relative">
                  <MapPin size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                  <input
                    className={`input pl-8 pr-8 ${step1Submitted && !(form.address || addressSearch) ? 'border-red-400 focus:ring-red-300' : ''}`}
                    placeholder="Search address (e.g. Indiranagar, Bengaluru)…"
                    value={addressSearch}
                    onChange={e => handleAddressInput(e.target.value)}
                    onBlur={() => setTimeout(() => setAddressSuggestions([]), 150)}
                  />
                  {isAddressLoading && (
                    <Loader2 size={14} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 animate-spin" />
                  )}
                </div>

                {/* Suggestions dropdown */}
                {addressSuggestions.length > 0 && (
                  <div className="absolute z-20 w-full mt-1 bg-white border border-gray-200 rounded-xl shadow-lg overflow-hidden max-h-52 overflow-y-auto">
                    {addressSuggestions.map(s => (
                      <button key={s.placeId} type="button"
                        className="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 flex items-start gap-2.5 transition-colors"
                        onMouseDown={() => fetchPlaceDetails(s.placeId, s.description)}
                      >
                        <MapPin size={13} className="text-gray-400 mt-0.5 shrink-0" />
                        <span className="text-gray-700 leading-snug">{s.description}</span>
                      </button>
                    ))}
                  </div>
                )}

                {typeof form.latitude === 'number' ? (
                  <p className="mt-1 text-xs text-emerald-600 flex items-center gap-1">
                    <Check size={11} /> Location confirmed · {form.latitude.toFixed(5)}, {typeof form.longitude === 'number' ? form.longitude.toFixed(5) : form.longitude}
                  </p>
                ) : step1Submitted && !(form.address || addressSearch) ? (
                  <p className="mt-1 text-xs text-red-500">Venue address is required</p>
                ) : null}
              </div>

              {/* ── Google Maps Picker ── */}
              {showMap && (
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <p className="text-xs font-medium text-gray-600">Confirm venue location — drag the pin to refine</p>
                  </div>
                  <div
                    ref={mapDivRef}
                    className="w-full h-52 rounded-xl overflow-hidden border border-gray-200 bg-gray-100"
                  />
                </div>
              )}

              {/* Manual address fields — always visible for editing */}
              <div>
                <Label>Flat / Building / Floor</Label>
                <input className="input" placeholder="JK Plaza, 2nd Floor" value={form.flatBuilding}
                  onChange={e => set('flatBuilding', e.target.value)} />
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <Label required>City / Town</Label>
                  <input
                    className={`input ${step1Submitted && !form.city.trim() ? 'border-red-400 focus:ring-red-300' : ''}`}
                    placeholder="Bengaluru" value={form.city}
                    onChange={e => set('city', e.target.value)} />
                  {step1Submitted && !form.city.trim() && (
                    <p className="text-xs text-red-500 mt-1">City is required</p>
                  )}
                </div>
                <div>
                  <Label required>State</Label>
                  <input
                    className={`input ${step1Submitted && !form.state.trim() ? 'border-red-400 focus:ring-red-300' : ''}`}
                    placeholder="Karnataka" value={form.state}
                    onChange={e => set('state', e.target.value)} />
                  {step1Submitted && !form.state.trim() && (
                    <p className="text-xs text-red-500 mt-1">State is required</p>
                  )}
                </div>
                <div>
                  <Label required>Pin Code</Label>
                  <input
                    className={`input ${step1Submitted && !/^\d{6}$/.test(form.zipCode) ? 'border-red-400 focus:ring-red-300' : ''}`}
                    placeholder="560008" value={form.zipCode}
                    maxLength={6}
                    onChange={e => {
                      const val = e.target.value.replace(/\D/g, '');
                      set('zipCode', val);
                      if (val.length === 6) lookupPincode(val);
                    }} />
                  {step1Submitted && !/^\d{6}$/.test(form.zipCode) && (
                    <p className="text-xs text-red-500 mt-1">Enter a valid 6-digit pin code</p>
                  )}
                </div>
              </div>


              <div>
                <Label>Commission (%)</Label>
                <input className="input" type="number" min={0} max={100} step={0.01} placeholder="10"
                  value={form.commission}
                  onChange={e => set('commission', e.target.value === '' ? '' : Number(e.target.value))} />
                <p className="text-xs text-gray-400 mt-1">Leave blank to use the system default (10%)</p>
              </div>
            </>
          )}

          {/* ── Step 3: Amenities ── */}
          {step === 2 && (
            <div>
              <Label>Amenities</Label>
              <p className="text-xs text-gray-400 mb-2.5">Select all facilities available at this venue</p>
              <div className="grid grid-cols-2 gap-2">
                {AMENITIES.map(a => {
                  const selected = form.amenities.includes(a);
                  return (
                    <button key={a} type="button" onClick={() => toggleAmenity(a)}
                      className={`flex items-center gap-2.5 px-3 py-2.5 rounded-lg border text-sm transition-colors text-left ${
                        selected
                          ? 'border-primary-500 bg-primary-50 text-primary-700 font-medium'
                          : 'border-gray-200 bg-white text-gray-600 hover:bg-gray-50'
                      }`}>
                      <div className={`w-4 h-4 rounded border flex items-center justify-center shrink-0 ${
                        selected ? 'bg-primary-600 border-primary-600' : 'border-gray-300'
                      }`}>
                        {selected && <Check size={10} className="text-white" />}
                      </div>
                      {a}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* ── Step 4: Categories ── */}
          {step === 3 && (
            <div>
              <Label required>Sport Categories</Label>
              <p className="text-xs text-gray-400 mb-2.5">Select one or more activity categories for this venue</p>
              {categories.length === 0 ? (
                <p className="text-sm text-gray-400">Loading categories…</p>
              ) : (
                <div className="grid grid-cols-2 gap-2">
                  {categories.map(cat => {
                    const selected = form.categoryIds.includes(cat.id);
                    return (
                      <button key={cat.id} type="button" onClick={() => toggleCategory(cat.id)}
                        className={`flex items-center gap-2 px-3 py-2.5 rounded-lg border text-sm font-medium transition-colors text-left ${
                          selected
                            ? 'border-primary-500 bg-primary-50 text-primary-700'
                            : 'border-gray-200 bg-white text-gray-700 hover:bg-gray-50'
                        }`}>
                        {cat.icon && <span className="text-base leading-none">{cat.icon}</span>}
                        {cat.imageUrl && !cat.icon && (
                          <img src={cat.imageUrl} alt={cat.name} className="w-5 h-5 rounded object-cover" />
                        )}
                        <span className="flex-1 truncate">{cat.name}</span>
                        {selected && <Check size={13} className="text-primary-600 shrink-0" />}
                      </button>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* ── Step 5: Category Questions ── */}
          {step === 4 && (
            <>
              {isQuestionsLoading ? (
                <div className="py-16 text-center text-gray-400 text-sm flex flex-col items-center gap-2">
                  <Loader2 size={24} className="animate-spin text-gray-300" />
                  Loading questions…
                </div>
              ) : !hasQuestions ? (
                <div className="py-16 text-center">
                  <p className="text-gray-400 text-sm">No questions configured for the selected categories.</p>
                  <p className="text-xs text-gray-300 mt-1">Click Next to continue.</p>
                </div>
              ) : (
                <div className="space-y-6">
                  {questionGroups.globalQuestions.length > 0 && (
                    <div className="space-y-4">
                      <p className="text-xs font-semibold text-gray-400 uppercase tracking-widest">General</p>
                      {questionGroups.globalQuestions.map(q => (
                        <QuestionField key={q.id} q={q}
                          value={form.answers[q.id]} onChange={v => setAnswer(q.id, v)} />
                      ))}
                    </div>
                  )}
                  {questionGroups.byCategory.map(group => (
                    <div key={group.categoryId} className="space-y-4">
                      <p className="text-xs font-semibold text-gray-400 uppercase tracking-widest">{group.categoryName}</p>
                      {group.questions.map(q => (
                        <QuestionField key={q.id} q={q}
                          value={form.answers[q.id]} onChange={v => setAnswer(q.id, v)} />
                      ))}
                    </div>
                  ))}
                </div>
              )}
            </>
          )}

          {/* ── Step 6: Legal Information ── */}
          {step === 5 && (() => {
            const aadhaarValid = /^\d{12}$/.test(form.aadhaarNumber);
            const panValid = /^[A-Z]{5}[0-9]{4}[A-Z]$/.test(form.panNumber);
            const s = step4Submitted;
            return (
              <>
                <p className="text-sm text-gray-500">
                  We will use these details to verify the venue's legitimacy.
                </p>
                <div className="space-y-5">
                  {/* Full Name */}
                  <div>
                    <Label required>Full Name As Per Aadhaar</Label>
                    <input
                      className={`input ${s && !form.fullName.trim() ? 'border-red-400 focus:ring-red-300' : ''}`}
                      placeholder="Enter Full Name" value={form.fullName}
                      onChange={e => set('fullName', e.target.value)} />
                    {s && !form.fullName.trim() && <p className="text-xs text-red-500 mt-1">Full name is required</p>}
                  </div>

                  {/* Aadhaar */}
                  <div className="space-y-2">
                    <div>
                      <Label required>Aadhaar Number</Label>
                      <input
                        className={`input ${s && !aadhaarValid ? 'border-red-400 focus:ring-red-300' : ''}`}
                        placeholder="Enter 12-digit Aadhaar Number"
                        maxLength={12}
                        value={form.aadhaarNumber}
                        onChange={e => set('aadhaarNumber', e.target.value.replace(/\D/g, '').slice(0, 12))} />
                      {s && !aadhaarValid && <p className="text-xs text-red-500 mt-1">Enter a valid 12-digit Aadhaar number</p>}
                    </div>
                    <FileUploadZone field="aadhaarFile" file={form.aadhaarFile} label="Upload your Aadhaar Card" required showError={s} onChange={updateLegalFile} />
                  </div>

                  {/* PAN */}
                  <div className="space-y-2">
                    <div>
                      <Label required>PAN Number</Label>
                      <input
                        className={`input uppercase ${s && !panValid ? 'border-red-400 focus:ring-red-300' : ''}`}
                        placeholder="ABCDE1234F"
                        maxLength={10}
                        value={form.panNumber}
                        onChange={e => set('panNumber', e.target.value.toUpperCase().slice(0, 10))} />
                      {s && !panValid
                        ? <p className="text-xs text-red-500 mt-1">PAN must be in format ABCDE1234F (5 letters, 4 digits, 1 letter)</p>
                        : <p className="text-xs text-gray-400 mt-1">Format: ABCDE1234F</p>
                      }
                    </div>
                    <FileUploadZone field="panFile" file={form.panFile} label="Upload your PAN Card" required showError={s} onChange={updateLegalFile} />
                  </div>

                  {/* GSTIN (optional) */}
                  <div className="space-y-2">
                    <div>
                      <label className="label">GSTIN <span className="text-gray-400 font-normal">(Optional)</span></label>
                      <p className="text-xs text-gray-400 mb-1">Should be linked to the Aadhaar provided above</p>
                      <input className="input" placeholder="Enter GSTIN Number" value={form.gstin}
                        onChange={e => set('gstin', e.target.value.toUpperCase())} />
                    </div>
                    {form.gstin.trim() && <FileUploadZone field="gstinFile" file={form.gstinFile} label="Upload your GSTIN Document" required={false} showError={s} onChange={updateLegalFile} />}
                  </div>
                </div>
              </>
            );
          })()}

          {/* ── Step 7: Images ── */}
          {step === 6 && (
            <>
              <p className="text-sm text-gray-500">
                Upload venue photos shown to members. The first image becomes the cover photo.
              </p>

              <div className="relative border-2 border-dashed border-gray-200 rounded-xl p-10 text-center hover:border-primary-300 hover:bg-primary-50/30 transition-colors">
                <input
                  ref={fileInputRef}
                  type="file"
                  multiple
                  accept="image/*"
                  className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                  onChange={e => { addImages(e.target.files); e.target.value = ''; }}
                />
                <Upload size={28} className="mx-auto text-gray-300 mb-2 pointer-events-none" />
                <p className="text-sm font-medium text-gray-600 pointer-events-none">Click to browse photos</p>
                <p className="text-xs text-gray-400 mt-1 pointer-events-none">PNG, JPG up to 5 MB each &nbsp;·&nbsp; Maximum 12 photos</p>
              </div>


              {form.images.length > 0 && (
                <div className="grid grid-cols-3 gap-2.5">
                  {form.images.map((file, idx) => (
                    <div key={idx} className="relative aspect-video rounded-lg overflow-hidden bg-gray-100 group">
                      <img src={URL.createObjectURL(file)} alt={`preview-${idx}`}
                        className="w-full h-full object-cover" />
                      {idx === 0 && (
                        <span className="absolute bottom-1.5 left-1.5 bg-black/60 text-white text-[10px] font-semibold px-1.5 py-0.5 rounded">
                          Cover
                        </span>
                      )}
                      <button type="button"
                        onClick={() => setForm(p => ({ ...p, images: p.images.filter((_, i) => i !== idx) }))}
                        className="absolute top-1.5 right-1.5 bg-black/60 rounded-full p-0.5 opacity-0 group-hover:opacity-100 transition-opacity"
                      >
                        <X size={12} className="text-white" />
                      </button>
                    </div>
                  ))}
                  {form.images.length < 12 && (
                    <div className="relative aspect-video rounded-lg border-2 border-dashed border-gray-200 flex flex-col items-center justify-center text-gray-400 hover:border-primary-300 hover:text-primary-500 transition-colors">
                      <input
                        type="file"
                        multiple
                        accept="image/*"
                        className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                        onChange={e => { addImages(e.target.files); e.target.value = ''; }}
                      />
                      <Plus size={20} className="pointer-events-none" />
                      <span className="text-xs mt-1 pointer-events-none">Add more</span>
                    </div>
                  )}
                </div>
              )}

              <p className="text-xs text-gray-400">
                {form.images.length} / 12 photos selected
                {form.images.length === 0 && ' — images are optional'}
              </p>
            </>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-6 py-4 border-t border-gray-100 shrink-0">
          <button
            onClick={step === 0 ? handleClose : () => setStep(s => s - 1)}
            className="btn-secondary flex items-center gap-1.5 text-sm"
            disabled={mutation.isPending}
          >
            <ChevronLeft size={14} />
            {step === 0 ? 'Cancel' : 'Back'}
          </button>

          {step < STEPS.length - 1 ? (
            <button
              onClick={() => {
                if (step === 1) setStep1Submitted(true);
                if (step === 5) setStep4Submitted(true);
                if (canNext()) setStep(s => s + 1);
              }}
              disabled={step !== 1 && step !== 5 && !canNext()}
              className="btn-primary flex items-center gap-1.5 text-sm"
            >
              Next <ChevronRight size={14} />
            </button>
          ) : (
            <button onClick={() => mutation.mutate()} disabled={mutation.isPending}
              className="btn-primary text-sm min-w-[120px]"
            >
              {mutation.isPending ? 'Creating…' : 'Create Venue'}
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
