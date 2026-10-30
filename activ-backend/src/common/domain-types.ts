export enum NotificationType {
  BOOKING_RECEIVED = 'booking_received',
  PAYMENT_RECEIVED = 'payment_received',
  ACTIVITY_APPROVED = 'activity_approved',
  ACTIVITY_REJECTED = 'activity_rejected',
  ACTIVITY_UNDER_REVIEW = 'activity_under_review',
  ADMIN_UPDATE = 'admin_update',
  VENUE_APPROVED = 'venue_approved',
}

export enum AdminNotificationType {
  PARTNER_REGISTERED = 'partner_registered',
  VENUE_SUBMITTED = 'venue_submitted',
  ACTIVITY_SUBMITTED = 'activity_submitted',
  VENUE_REQUEST_SUBMITTED = 'venue_request_submitted',
  GST_VERIFICATION_SUBMITTED = 'gst_verification_submitted',
  BANK_ACCOUNT_SUBMITTED = 'bank_account_submitted',
  CALLBACK_REQUESTED = 'callback_requested',
  SUPPORT_REQUESTED = 'support_requested',
  VENUE_AUTO_DEACTIVATED = 'venue_auto_deactivated',
  ACTIVITY_ADDED = 'activity_added',
  ACTIVITY_REMOVED = 'activity_removed',
  VENUE_UPDATED = 'venue_updated',
  PARTNER_PROFILE_UPDATED = 'partner_profile_updated',
  VENUE_BOOKINGS_PAUSED = 'venue_bookings_paused',
  VENUE_BOOKINGS_RESUMED = 'venue_bookings_resumed',
}

export enum TeamMemberStatus {
  INVITE_PENDING = 'invite_pending',
  INVITE_SENT = 'invite_sent',
  ACTIVE = 'active',
}

export enum BankAccountStatus {
  UNDER_REVIEW = 'under_review',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

export enum LegalContentType {
  TERMS_AND_CONDITIONS = 'terms_and_conditions',
  PRIVACY_POLICY = 'privacy_policy',
  PARTNER_AGREEMENT = 'partner_agreement',
  REFUND_POLICY = 'refund_policy',
}

export enum GstVerificationStatus { PENDING = 'pending', APPROVED = 'approved', REJECTED = 'rejected' }
export enum VenueUpdateRequestStatus { PENDING = 'pending', APPROVED = 'approved', REJECTED = 'rejected' }

export interface TeamMemberRecord {
    invitationDelivery?: { emailSent: boolean; smsSent: boolean };
  id: string; partnerId: string; fullName: string; email?: string | null;
  phone?: string | null; avatarUrl?: string; role: string;
  status: TeamMemberStatus; isActive: boolean; permissions: Record<string, boolean>;
  createdAt: Date; updatedAt: Date; password?: never;
}

export interface GstVerificationRequestRecord {
  id: string; partnerId: string; gstNumber: string; status: GstVerificationStatus;
  documentUrl?: string | null; rejectionReason?: string | null;
  createdAt: Date; updatedAt: Date;
}

export interface UserRecord { id: string; role: string; [key: string]: any; }
export type PartnerRecord = Record<string, any>;
export type VenueRecord = Record<string, any>;
export type VenueImageRecord = Record<string, any>;
export type VenueServiceRecord = Record<string, any>;
export type VenueAnswerRecord = Record<string, any>;
export type CategoryRecord = Record<string, any>;
export type VenueUpdateRequestRecord = Record<string, any>;
export type CityCommissionRecord = Record<string, any>;
export type FaqRecord = Record<string, any>;

export interface NotificationRecord {
  id: string; partnerId?: string; type: NotificationType | string;
  title: string; body: string; data: Record<string, any> | null;
  isRead: boolean; createdAt: Date;
}

export interface AdminNotificationRecord {
  id: string; type: AdminNotificationType | string;
  title: string; body: string; data: Record<string, any> | null;
  isRead: boolean; createdAt: Date;
}

export interface LegalContentRecord {
  id: string; type: LegalContentType; title: string; content: string;
  version: number; updatedBy: string | null; createdAt: Date; updatedAt: Date;
}
