-- Allows partner check-in/no-show management to use the shared booking table.
-- This migration is intentionally not executed automatically by the audit/fix.
ALTER TYPE "BookingStatus" ADD VALUE IF NOT EXISTS 'NO_SHOW';
