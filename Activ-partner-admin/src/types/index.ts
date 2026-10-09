export interface ApiResponse<T> {
  success: boolean;
  statusCode: number;
  message: string;
  data: T;
  timestamp: string;
}

export interface PaginatedData<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface User {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  phone?: string;
  role: 'admin' | 'partner' | 'user';
  isActive: boolean;
  isEmailVerified: boolean;
  profileImage?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Partner {
  id: string;
  userId: string;
  user: User;
  businessName: string;
  businessDescription?: string;
  businessAddress: string;
  city: string;
  state: string;
  country?: string;
  zipCode?: string;
  contactPhone?: string;
  gstNumber?: string;
  gstinDocUrl?: string;
  panNumber?: string;
  panCardUrl?: string;
  aadhaarName?: string;
  aadhaarNumber?: string;
  aadhaarCardUrl?: string;
  bankAccountNumber?: string;
  bankIfscCode?: string;
  bankAccountHolderName?: string;
  isVerified: boolean;
  isActive: boolean;
  logoUrl?: string;
  documents?: string[];
  createdAt: string;
  updatedAt: string;
}

export type CategoryType =
  | 'single_booking'
  | 'court_booking'
  | 'turf_booking'
  | 'table_booking'
  | 'cricket_nets_booking';

export interface Category {
  id: string;
  name: string;
  description?: string;
  icon?: string;
  imageUrl?: string;
  type: CategoryType;
  isActive: boolean;
  order: number;
  createdAt: string;
  updatedAt: string;
}

export type QuestionType = 'text' | 'textarea' | 'number' | 'select' | 'multiselect' | 'radio' | 'checkbox' | 'file' | 'date';

export interface Question {
  id: string;
  categoryId?: string;
  category?: Category;
  questionText: string;
  questionType: QuestionType;
  options?: string[] | { label: string; value: string }[];
  isRequired: boolean;
  isActive: boolean;
  order: number;
  placeholder?: string;
  helperText?: string;
  minLength?: number | null;
  maxLength?: number | null;
  createdAt: string;
  updatedAt: string;
}

export type VenueStatus = 'pending' | 'approved' | 'rejected' | 'suspended' | 'draft';

export interface VenueImage {
  id: string;
  venueId: string;
  imageUrl: string;
  isPrimary: boolean;
  caption?: string;
  createdAt: string;
}

export type ActivityStatus = 'draft' | 'pending' | 'approved' | 'rejected';

export interface VenueService {
  id: string;
  venueId: string;
  name: string;
  description?: string;
  pricePerHour: number;
  minDuration: number;
  maxDuration?: number;
  capacity?: number;
  imageUrl?: string;
  isActive: boolean;
  categoryId?: string;
  category?: Category;
  status?: ActivityStatus;
  amenities?: string[];
  rejectionReason?: string;
  submittedAt?: string;
  approvedAt?: string;
  approvedBy?: string;
}

export interface PendingActivity {
  id: string;
  venueId: string;
  venue: { id: string; name: string; city: string; state: string };
  name: string;
  categoryId?: string;
  category?: Category;
  status: ActivityStatus;
  amenities?: string[];
  submittedAt?: string;
  approvedAt?: string;
  approvedBy?: string;
  rejectionReason?: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface VenueAnswer {
  id: string;
  venueId: string;
  questionId: string;
  question?: Question;
  answer: unknown;
}

export interface VenueAvailabilityEntry {
  day: string;
  slots: { openTime: string; closeTime: string }[];
}

export interface Venue {
  id: string;
  partnerId: string;
  partner: User;
  categoryId: string;
  category: Category;
  categories?: Category[];
  name: string;
  description?: string;
  address: string;
  city: string;
  state: string;
  country: string;
  zipCode?: string;
  latitude?: number;
  longitude?: number;
  openingTime?: string;
  closingTime?: string;
  amenities?: string[];
  rules?: string;
  phone?: string;
  status: VenueStatus;
  rejectionReason?: string;
  submittedAt?: string | null;
  approvedAt?: string;
  approvedBy?: string;
  isActive: boolean;
  images: VenueImage[];
  services: VenueService[];
  answers: VenueAnswer[];
  availability?: { [categoryId: string]: VenueAvailabilityEntry[] };
  createdAt: string;
  updatedAt: string;
}

export interface Booking {
  id: string;
  userId: string;
  user: User;
  venueId: string;
  venue: Venue;
  serviceId: string;
  service: VenueService;
  bookingDate: string;
  startTime: string;
  endTime: string;
  durationMinutes: number;
  totalAmount: number;
  status: 'pending' | 'confirmed' | 'cancelled' | 'completed' | 'no_show';
  bookingReference: string;
  createdAt: string;
  updatedAt: string;
}

export interface Commission {
  id: string;
  city: string;
  commissionPercentage: number;
  createdAt: string;
  updatedAt: string;
}

export type LegalType = 'terms_and_conditions' | 'privacy_policy' | 'partner_agreement' | 'refund_policy';

export interface LegalDocument {
  id: string;
  type: LegalType;
  content: string;
  createdAt: string;
  updatedAt: string;
}

export type VenueUpdateRequestStatus = 'pending' | 'approved' | 'rejected';

// The API returns a flat snapshot of the requested venue values (not a diff/relation) —
// these are the field names that can appear on a request and be compared against the venue.
export const VENUE_REQUEST_FIELD_KEYS = [
  'name',
  'description',
  'address',
  'city',
  'state',
  'zipCode',
  'flatBuilding',
  'latitude',
  'longitude',
  'locationUrl',
  'venuePhone',
] as const;

export interface VenueUpdateRequest {
  id: string;
  venueId: string;
  partnerId: string;
  name?: string;
  description?: string;
  address?: string;
  city?: string;
  state?: string;
  zipCode?: string;
  flatBuilding?: string;
  latitude?: number | string | null;
  longitude?: number | string | null;
  locationUrl?: string;
  venuePhone?: string;
  status: VenueUpdateRequestStatus;
  adminNotes?: string | null;
  createdAt: string;
  updatedAt: string;
}

export type GstVerificationStatus = 'pending' | 'approved' | 'rejected';

export interface GstVerification {
  id: string;
  partnerId: string;
  partner?: Partner;
  gstNumber: string;
  gstinDocUrl?: string;
  status: GstVerificationStatus;
  adminNotes?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface FAQ {
  id: string;
  question: string;
  answer: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface DashboardStats {
  total: number;
  pending: number;
  approved: number;
  rejected: number;
}

export type CallbackStatus = 'pending' | 'in_progress' | 'resolved' | 'cancelled';

export interface CallbackRequest {
  id: string;
  partnerId: string;
  partnerName: string;
  email: string;
  phone: string;
  venueName?: string;
  city?: string;
  callbackDate?: string;
  callbackTime?: string;
  query?: string;
  status: CallbackStatus;
  adminNotes?: string | null;
  createdAt: string;
  updatedAt: string;
}

export type AdminNotificationType =
  | 'venue_auto_deactivated'
  | 'activity_added'
  | 'activity_removed'
  | 'venue_updated'
  | 'partner_profile_updated'
  | 'venue_bookings_paused'
  | 'venue_bookings_resumed';

export interface AdminNotification {
  id: string;
  type: AdminNotificationType;
  title: string;
  body: string;
  data: Record<string, any> | null;
  isRead: boolean;
  createdAt: string;
}

export type BankAccountStatus = 'under_review' | 'approved' | 'rejected';

export interface BankAccount {
  id: string;
  partnerId: string;
  partner?: Partner;
  accountHolderName: string;
  bankName: string;
  accountNumber: string;
  ifscCode: string;
  accountType: string;
  branchName?: string;
  cancelledChequeUrl?: string;
  status: BankAccountStatus;
  rejectionReason?: string;
  reviewedBy?: string;
  reviewedAt?: string;
  createdAt: string;
  updatedAt: string;
}
