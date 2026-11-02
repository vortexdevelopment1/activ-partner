-- AlterEnum
ALTER TYPE "PartnerServiceQuestionType" ADD VALUE 'NUMBER_STEPPER';

-- AlterTable
ALTER TABLE "partner_service_questions" ADD COLUMN "unit" TEXT;

