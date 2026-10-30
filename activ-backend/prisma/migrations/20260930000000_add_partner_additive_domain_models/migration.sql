-- CreateEnum
CREATE TYPE "PartnerBankAccountStatus" AS ENUM ('UNDER_REVIEW', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "PartnerKycStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "PartnerVenueServiceStatus" AS ENUM ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "PartnerUpdateRequestStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "PartnerWalkInReservationStatus" AS ENUM ('RESERVED', 'COMPLETED', 'CANCELLED', 'NO_SHOW');

-- CreateEnum
CREATE TYPE "PartnerRequestStatus" AS ENUM ('PENDING', 'IN_PROGRESS', 'CONTACTED', 'RESOLVED', 'CLOSED');

-- CreateEnum
CREATE TYPE "PartnerServiceQuestionType" AS ENUM ('TEXT', 'TEXTAREA', 'NUMBER', 'SELECT', 'MULTISELECT', 'RADIO', 'CHECKBOX', 'FILE', 'DATE');

-- CreateTable
CREATE TABLE "partner_business_profiles" (
    "id" UUID NOT NULL,
    "partner_id" UUID NOT NULL,
    "business_name" TEXT,
    "owner_name" TEXT,
    "phone_e164" TEXT,
    "email" TEXT,
    "pan_number" TEXT,
    "gst_number" TEXT,
    "pan_document_url" TEXT,
    "gst_document_url" TEXT,
    "address_line_1" TEXT,
    "address_line_2" TEXT,
    "city" TEXT,
    "state" TEXT,
    "postal_code" TEXT,
    "kyc_status" "PartnerKycStatus" NOT NULL DEFAULT 'PENDING',
    "reviewed_by" UUID,
    "reviewed_at" TIMESTAMP(3),
    "rejection_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_business_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_staff_profiles" (
    "id" UUID NOT NULL,
    "partner_user_id" UUID NOT NULL,
    "display_name" TEXT,
    "designation" TEXT,
    "contact_phone_e164" TEXT,
    "permissions" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_staff_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_bank_accounts" (
    "id" UUID NOT NULL,
    "partner_id" UUID NOT NULL,
    "account_holder_name" TEXT NOT NULL,
    "bank_name" TEXT NOT NULL,
    "account_number" TEXT NOT NULL,
    "ifsc_code" TEXT NOT NULL,
    "upi_id" TEXT,
    "status" "PartnerBankAccountStatus" NOT NULL DEFAULT 'UNDER_REVIEW',
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "reviewed_by" UUID,
    "reviewed_at" TIMESTAMP(3),
    "rejection_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_bank_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_notification_preferences" (
    "id" UUID NOT NULL,
    "partner_id" UUID NOT NULL,
    "booking_updates" BOOLEAN NOT NULL DEFAULT true,
    "payment_updates" BOOLEAN NOT NULL DEFAULT true,
    "support_updates" BOOLEAN NOT NULL DEFAULT true,
    "marketing_updates" BOOLEAN NOT NULL DEFAULT false,
    "channel_preferences" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_notification_preferences_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_callback_requests" (
    "id" UUID NOT NULL,
    "partner_id" UUID,
    "partner_user_id" UUID,
    "subject" TEXT NOT NULL,
    "notes" TEXT,
    "status" "PartnerRequestStatus" NOT NULL DEFAULT 'PENDING',
    "preferred_at" TIMESTAMP(3),
    "resolved_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_callback_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_support_requests" (
    "id" UUID NOT NULL,
    "partner_id" UUID,
    "partner_user_id" UUID,
    "subject" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "attachments" JSONB NOT NULL DEFAULT '[]',
    "status" "PartnerRequestStatus" NOT NULL DEFAULT 'PENDING',
    "resolved_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_support_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_gst_verification_requests" (
    "id" UUID NOT NULL,
    "partner_id" UUID NOT NULL,
    "gst_number" TEXT NOT NULL,
    "legal_name" TEXT,
    "document_url" TEXT,
    "status" "PartnerKycStatus" NOT NULL DEFAULT 'PENDING',
    "reviewed_by" UUID,
    "reviewed_at" TIMESTAMP(3),
    "rejection_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_gst_verification_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_venue_profiles" (
    "id" UUID NOT NULL,
    "partner_id" UUID NOT NULL,
    "venue_id" UUID NOT NULL,
    "display_name" TEXT,
    "description" TEXT,
    "contact_phone_e164" TEXT,
    "contact_email" TEXT,
    "address_line_1" TEXT,
    "address_line_2" TEXT,
    "city" TEXT,
    "state" TEXT,
    "postal_code" TEXT,
    "amenities" JSONB NOT NULL DEFAULT '[]',
    "operating_hours" JSONB NOT NULL DEFAULT '{}',
    "onboarding_status" "PartnerKycStatus" NOT NULL DEFAULT 'PENDING',
    "terms_accepted_at" TIMESTAMP(3),
    "terms_accepted_by" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_venue_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_venue_images" (
    "id" UUID NOT NULL,
    "venue_id" UUID NOT NULL,
    "uploaded_by_partner_user_id" UUID,
    "url" TEXT NOT NULL,
    "caption" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_venue_images_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_service_categories" (
    "id" UUID NOT NULL,
    "slug" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "status" "PartnerVenueServiceStatus" NOT NULL DEFAULT 'PENDING',
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_service_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_venue_services" (
    "id" UUID NOT NULL,
    "venue_id" UUID NOT NULL,
    "facility_id" UUID,
    "service_category_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "duration_minutes" INTEGER,
    "price_per_hour_paise" BIGINT,
    "status" "PartnerVenueServiceStatus" NOT NULL DEFAULT 'DRAFT',
    "onboarding_data" JSONB NOT NULL DEFAULT '{}',
    "reviewed_by" UUID,
    "approved_by" UUID,
    "approved_at" TIMESTAMP(3),
    "rejection_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_venue_services_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_service_questions" (
    "id" UUID NOT NULL,
    "service_category_id" UUID,
    "venue_service_id" UUID,
    "question" TEXT NOT NULL,
    "type" "PartnerServiceQuestionType" NOT NULL,
    "options" JSONB NOT NULL DEFAULT '[]',
    "is_required" BOOLEAN NOT NULL DEFAULT false,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_service_questions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_venue_answers" (
    "id" UUID NOT NULL,
    "venue_id" UUID NOT NULL,
    "venue_service_id" UUID,
    "question_id" UUID NOT NULL,
    "answered_by_partner_user_id" UUID,
    "answer" JSONB NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_venue_answers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_venue_update_requests" (
    "id" UUID NOT NULL,
    "partner_id" UUID NOT NULL,
    "venue_id" UUID NOT NULL,
    "requested_by_partner_user_id" UUID,
    "status" "PartnerUpdateRequestStatus" NOT NULL DEFAULT 'PENDING',
    "requested_changes" JSONB NOT NULL,
    "reviewed_by" UUID,
    "reviewed_at" TIMESTAMP(3),
    "rejection_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_venue_update_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_walk_in_reservations" (
    "id" UUID NOT NULL,
    "partner_id" UUID NOT NULL,
    "venue_id" UUID NOT NULL,
    "facility_id" UUID,
    "venue_service_id" UUID,
    "booking_id" UUID,
    "participant_name" TEXT,
    "participant_phone_e164" TEXT,
    "participant_count" INTEGER NOT NULL DEFAULT 1,
    "starts_at" TIMESTAMP(3) NOT NULL,
    "ends_at" TIMESTAMP(3) NOT NULL,
    "amount_paise" BIGINT,
    "fees_paise" BIGINT,
    "tax_paise" BIGINT,
    "status" "PartnerWalkInReservationStatus" NOT NULL DEFAULT 'RESERVED',
    "notes" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_walk_in_reservations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_city_commissions" (
    "id" UUID NOT NULL,
    "partner_id" UUID,
    "city_code" TEXT NOT NULL,
    "commission_bps" INTEGER NOT NULL,
    "effective_from" TIMESTAMP(3) NOT NULL,
    "effective_to" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_city_commissions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "partner_business_profiles_partner_id_key" ON "partner_business_profiles"("partner_id");

-- CreateIndex
CREATE INDEX "partner_business_profiles_kyc_status_updated_at_idx" ON "partner_business_profiles"("kyc_status", "updated_at");

-- CreateIndex
CREATE UNIQUE INDEX "partner_staff_profiles_partner_user_id_key" ON "partner_staff_profiles"("partner_user_id");

-- CreateIndex
CREATE INDEX "partner_bank_accounts_partner_id_status_idx" ON "partner_bank_accounts"("partner_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "partner_notification_preferences_partner_id_key" ON "partner_notification_preferences"("partner_id");

-- CreateIndex
CREATE INDEX "partner_callback_requests_partner_id_status_created_at_idx" ON "partner_callback_requests"("partner_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "partner_callback_requests_partner_user_id_created_at_idx" ON "partner_callback_requests"("partner_user_id", "created_at");

-- CreateIndex
CREATE INDEX "partner_support_requests_partner_id_status_created_at_idx" ON "partner_support_requests"("partner_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "partner_support_requests_partner_user_id_created_at_idx" ON "partner_support_requests"("partner_user_id", "created_at");

-- CreateIndex
CREATE INDEX "partner_gst_verification_requests_partner_id_status_created_idx" ON "partner_gst_verification_requests"("partner_id", "status", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "partner_venue_profiles_venue_id_key" ON "partner_venue_profiles"("venue_id");

-- CreateIndex
CREATE INDEX "partner_venue_profiles_partner_id_onboarding_status_idx" ON "partner_venue_profiles"("partner_id", "onboarding_status");

-- CreateIndex
CREATE INDEX "partner_venue_images_venue_id_sort_order_idx" ON "partner_venue_images"("venue_id", "sort_order");

-- CreateIndex
CREATE UNIQUE INDEX "partner_service_categories_slug_key" ON "partner_service_categories"("slug");

-- CreateIndex
CREATE INDEX "partner_service_categories_status_sort_order_idx" ON "partner_service_categories"("status", "sort_order");

-- CreateIndex
CREATE INDEX "partner_venue_services_venue_id_status_idx" ON "partner_venue_services"("venue_id", "status");

-- CreateIndex
CREATE INDEX "partner_venue_services_facility_id_status_idx" ON "partner_venue_services"("facility_id", "status");

-- CreateIndex
CREATE INDEX "partner_venue_services_service_category_id_status_idx" ON "partner_venue_services"("service_category_id", "status");

-- CreateIndex
CREATE INDEX "partner_service_questions_service_category_id_sort_order_idx" ON "partner_service_questions"("service_category_id", "sort_order");

-- CreateIndex
CREATE INDEX "partner_service_questions_venue_service_id_sort_order_idx" ON "partner_service_questions"("venue_service_id", "sort_order");

-- CreateIndex
CREATE INDEX "partner_venue_answers_venue_id_question_id_idx" ON "partner_venue_answers"("venue_id", "question_id");

-- CreateIndex
CREATE INDEX "partner_venue_answers_venue_service_id_question_id_idx" ON "partner_venue_answers"("venue_service_id", "question_id");

-- CreateIndex
CREATE INDEX "partner_venue_answers_answered_by_partner_user_id_created_a_idx" ON "partner_venue_answers"("answered_by_partner_user_id", "created_at");

-- CreateIndex
CREATE INDEX "partner_venue_update_requests_partner_id_status_created_at_idx" ON "partner_venue_update_requests"("partner_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "partner_venue_update_requests_venue_id_status_created_at_idx" ON "partner_venue_update_requests"("venue_id", "status", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "partner_walk_in_reservations_booking_id_key" ON "partner_walk_in_reservations"("booking_id");

-- CreateIndex
CREATE INDEX "partner_walk_in_reservations_partner_id_status_starts_at_idx" ON "partner_walk_in_reservations"("partner_id", "status", "starts_at");

-- CreateIndex
CREATE INDEX "partner_walk_in_reservations_venue_id_status_starts_at_idx" ON "partner_walk_in_reservations"("venue_id", "status", "starts_at");

-- CreateIndex
CREATE INDEX "partner_walk_in_reservations_facility_id_status_starts_at_idx" ON "partner_walk_in_reservations"("facility_id", "status", "starts_at");

-- CreateIndex
CREATE INDEX "partner_city_commissions_city_code_effective_from_effective_idx" ON "partner_city_commissions"("city_code", "effective_from", "effective_to");

-- CreateIndex
CREATE INDEX "partner_city_commissions_partner_id_effective_from_idx" ON "partner_city_commissions"("partner_id", "effective_from");

-- CreateIndex
CREATE UNIQUE INDEX "partner_city_commissions_city_code_partner_id_effective_fro_key" ON "partner_city_commissions"("city_code", "partner_id", "effective_from");

-- AddForeignKey
ALTER TABLE "partner_business_profiles" ADD CONSTRAINT "partner_business_profiles_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "partners"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_staff_profiles" ADD CONSTRAINT "partner_staff_profiles_partner_user_id_fkey" FOREIGN KEY ("partner_user_id") REFERENCES "partner_users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_bank_accounts" ADD CONSTRAINT "partner_bank_accounts_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "partners"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_notification_preferences" ADD CONSTRAINT "partner_notification_preferences_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "partners"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_callback_requests" ADD CONSTRAINT "partner_callback_requests_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "partners"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_callback_requests" ADD CONSTRAINT "partner_callback_requests_partner_user_id_fkey" FOREIGN KEY ("partner_user_id") REFERENCES "partner_users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_support_requests" ADD CONSTRAINT "partner_support_requests_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "partners"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_support_requests" ADD CONSTRAINT "partner_support_requests_partner_user_id_fkey" FOREIGN KEY ("partner_user_id") REFERENCES "partner_users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_gst_verification_requests" ADD CONSTRAINT "partner_gst_verification_requests_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "partners"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_profiles" ADD CONSTRAINT "partner_venue_profiles_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "partners"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_profiles" ADD CONSTRAINT "partner_venue_profiles_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "venues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_images" ADD CONSTRAINT "partner_venue_images_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "venues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_images" ADD CONSTRAINT "partner_venue_images_uploaded_by_partner_user_id_fkey" FOREIGN KEY ("uploaded_by_partner_user_id") REFERENCES "partner_users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_services" ADD CONSTRAINT "partner_venue_services_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "venues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_services" ADD CONSTRAINT "partner_venue_services_facility_id_fkey" FOREIGN KEY ("facility_id") REFERENCES "facilities"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_services" ADD CONSTRAINT "partner_venue_services_service_category_id_fkey" FOREIGN KEY ("service_category_id") REFERENCES "partner_service_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_service_questions" ADD CONSTRAINT "partner_service_questions_service_category_id_fkey" FOREIGN KEY ("service_category_id") REFERENCES "partner_service_categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_service_questions" ADD CONSTRAINT "partner_service_questions_venue_service_id_fkey" FOREIGN KEY ("venue_service_id") REFERENCES "partner_venue_services"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_answers" ADD CONSTRAINT "partner_venue_answers_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "venues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_answers" ADD CONSTRAINT "partner_venue_answers_venue_service_id_fkey" FOREIGN KEY ("venue_service_id") REFERENCES "partner_venue_services"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_answers" ADD CONSTRAINT "partner_venue_answers_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "partner_service_questions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_answers" ADD CONSTRAINT "partner_venue_answers_answered_by_partner_user_id_fkey" FOREIGN KEY ("answered_by_partner_user_id") REFERENCES "partner_users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_update_requests" ADD CONSTRAINT "partner_venue_update_requests_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "partners"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_update_requests" ADD CONSTRAINT "partner_venue_update_requests_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "venues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_update_requests" ADD CONSTRAINT "partner_venue_update_requests_requested_by_partner_user_id_fkey" FOREIGN KEY ("requested_by_partner_user_id") REFERENCES "partner_users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_walk_in_reservations" ADD CONSTRAINT "partner_walk_in_reservations_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "partners"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_walk_in_reservations" ADD CONSTRAINT "partner_walk_in_reservations_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "venues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_walk_in_reservations" ADD CONSTRAINT "partner_walk_in_reservations_facility_id_fkey" FOREIGN KEY ("facility_id") REFERENCES "facilities"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_walk_in_reservations" ADD CONSTRAINT "partner_walk_in_reservations_venue_service_id_fkey" FOREIGN KEY ("venue_service_id") REFERENCES "partner_venue_services"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_walk_in_reservations" ADD CONSTRAINT "partner_walk_in_reservations_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_city_commissions" ADD CONSTRAINT "partner_city_commissions_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "partners"("id") ON DELETE SET NULL ON UPDATE CASCADE;
