import { MigrationInterface, QueryRunner } from 'typeorm';

export class InitialSchema1771168802993 implements MigrationInterface {
  name = 'InitialSchema1771168802993';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Enable uuid extension
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

    // ─── USERS ───────────────────────────────────────────────────────────────
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "public"."users_role_enum" AS ENUM('admin', 'partner', 'user');
      EXCEPTION WHEN duplicate_object THEN NULL;
      END $$
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "users" (
        "id"                UUID              NOT NULL DEFAULT uuid_generate_v4(),
        "first_name"        VARCHAR           NOT NULL,
        "last_name"         VARCHAR           NOT NULL,
        "email"             VARCHAR           NOT NULL,
        "password"          VARCHAR           NOT NULL,
        "phone"             VARCHAR,
        "role"              "public"."users_role_enum" NOT NULL DEFAULT 'user',
        "is_active"         BOOLEAN           NOT NULL DEFAULT true,
        "is_email_verified" BOOLEAN           NOT NULL DEFAULT false,
        "profile_image"     VARCHAR,
        "device_token"      VARCHAR,
        "created_at"        TIMESTAMP         NOT NULL DEFAULT now(),
        "updated_at"        TIMESTAMP         NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_users_email" UNIQUE ("email"),
        CONSTRAINT "PK_users"       PRIMARY KEY ("id")
      )
    `);

    // ─── PARTNERS ────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "partners" (
        "id"                        UUID    NOT NULL DEFAULT uuid_generate_v4(),
        "user_id"                   UUID    NOT NULL,
        "business_name"             VARCHAR NOT NULL,
        "business_description"      TEXT,
        "business_address"          VARCHAR NOT NULL,
        "city"                      VARCHAR NOT NULL,
        "state"                     VARCHAR NOT NULL,
        "country"                   VARCHAR,
        "zip_code"                  VARCHAR,
        "gst_number"                VARCHAR,
        "pan_number"                VARCHAR,
        "bank_account_number"       VARCHAR,
        "bank_ifsc_code"            VARCHAR,
        "bank_account_holder_name"  VARCHAR,
        "is_verified"               BOOLEAN NOT NULL DEFAULT false,
        "is_active"                 BOOLEAN NOT NULL DEFAULT true,
        "documents"                 JSON,
        "logo_url"                  VARCHAR,
        "created_at"                TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at"                TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_partners" PRIMARY KEY ("id"),
        CONSTRAINT "FK_partners_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    // ─── CATEGORIES ──────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "categories" (
        "id"          UUID    NOT NULL DEFAULT uuid_generate_v4(),
        "name"        VARCHAR NOT NULL,
        "description" TEXT,
        "icon"        VARCHAR,
        "image_url"   VARCHAR,
        "is_active"   BOOLEAN NOT NULL DEFAULT true,
        "order"       INTEGER NOT NULL DEFAULT 0,
        "created_at"  TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at"  TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_categories_name" UNIQUE ("name"),
        CONSTRAINT "PK_categories"      PRIMARY KEY ("id")
      )
    `);

    // ─── QUESTIONS ───────────────────────────────────────────────────────────
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "public"."questions_question_type_enum"
          AS ENUM('text','textarea','number','select','multiselect','radio','checkbox','file','date');
      EXCEPTION WHEN duplicate_object THEN NULL;
      END $$
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "questions" (
        "id"            UUID    NOT NULL DEFAULT uuid_generate_v4(),
        "category_id"   UUID,
        "question_text" VARCHAR NOT NULL,
        "question_type" "public"."questions_question_type_enum" NOT NULL DEFAULT 'text',
        "options"       JSON,
        "is_required"   BOOLEAN NOT NULL DEFAULT false,
        "is_active"     BOOLEAN NOT NULL DEFAULT true,
        "order"         INTEGER NOT NULL DEFAULT 0,
        "placeholder"   VARCHAR,
        "helper_text"   VARCHAR,
        "created_at"    TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at"    TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_questions" PRIMARY KEY ("id"),
        CONSTRAINT "FK_questions_category" FOREIGN KEY ("category_id")
          REFERENCES "categories"("id") ON DELETE SET NULL
      )
    `);

    // ─── VENUES ──────────────────────────────────────────────────────────────
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "public"."venues_status_enum"
          AS ENUM('pending','approved','rejected','suspended','draft');
      EXCEPTION WHEN duplicate_object THEN NULL;
      END $$
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "venues" (
        "id"               UUID    NOT NULL DEFAULT uuid_generate_v4(),
        "partner_id"       UUID    NOT NULL,
        "category_id"      UUID    NOT NULL,
        "name"             VARCHAR NOT NULL,
        "description"      TEXT,
        "address"          VARCHAR NOT NULL,
        "city"             VARCHAR NOT NULL,
        "state"            VARCHAR NOT NULL,
        "country"          VARCHAR NOT NULL DEFAULT 'India',
        "zip_code"         VARCHAR,
        "latitude"         DECIMAL(10,7),
        "longitude"        DECIMAL(10,7),
        "opening_time"     VARCHAR,
        "closing_time"     VARCHAR,
        "amenities"        JSON,
        "rules"            TEXT,
        "phone"            VARCHAR,
        "status"           "public"."venues_status_enum" NOT NULL DEFAULT 'pending',
        "rejection_reason" TEXT,
        "approved_at"      TIMESTAMP,
        "approved_by"      UUID,
        "is_active"        BOOLEAN NOT NULL DEFAULT true,
        "created_at"       TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at"       TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_venues" PRIMARY KEY ("id"),
        CONSTRAINT "FK_venues_partner"  FOREIGN KEY ("partner_id") REFERENCES "users"("id"),
        CONSTRAINT "FK_venues_category" FOREIGN KEY ("category_id") REFERENCES "categories"("id")
      )
    `);

    // ─── VENUE IMAGES ────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "venue_images" (
        "id"         UUID    NOT NULL DEFAULT uuid_generate_v4(),
        "venue_id"   UUID    NOT NULL,
        "image_url"  VARCHAR NOT NULL,
        "is_primary" BOOLEAN NOT NULL DEFAULT false,
        "caption"    VARCHAR,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_venue_images" PRIMARY KEY ("id"),
        CONSTRAINT "FK_venue_images_venue" FOREIGN KEY ("venue_id")
          REFERENCES "venues"("id") ON DELETE CASCADE
      )
    `);

    // ─── VENUE SERVICES ──────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "venue_services" (
        "id"             UUID          NOT NULL DEFAULT uuid_generate_v4(),
        "venue_id"       UUID          NOT NULL,
        "name"           VARCHAR       NOT NULL,
        "description"    TEXT,
        "price_per_hour" DECIMAL(10,2) NOT NULL,
        "min_duration"   INTEGER       NOT NULL DEFAULT 60,
        "max_duration"   INTEGER,
        "capacity"       INTEGER,
        "image_url"      VARCHAR,
        "is_active"      BOOLEAN       NOT NULL DEFAULT true,
        "created_at"     TIMESTAMP     NOT NULL DEFAULT now(),
        "updated_at"     TIMESTAMP     NOT NULL DEFAULT now(),
        CONSTRAINT "PK_venue_services" PRIMARY KEY ("id"),
        CONSTRAINT "FK_venue_services_venue" FOREIGN KEY ("venue_id")
          REFERENCES "venues"("id") ON DELETE CASCADE
      )
    `);

    // ─── VENUE ANSWERS ───────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "venue_answers" (
        "id"          UUID      NOT NULL DEFAULT uuid_generate_v4(),
        "venue_id"    UUID      NOT NULL,
        "question_id" UUID      NOT NULL,
        "answer"      JSON      NOT NULL,
        "created_at"  TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at"  TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_venue_answers" PRIMARY KEY ("id"),
        CONSTRAINT "FK_venue_answers_venue"    FOREIGN KEY ("venue_id")
          REFERENCES "venues"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_venue_answers_question" FOREIGN KEY ("question_id")
          REFERENCES "questions"("id")
      )
    `);

    // ─── BOOKINGS ────────────────────────────────────────────────────────────
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "public"."bookings_status_enum"
          AS ENUM('pending','confirmed','cancelled','completed','no_show');
      EXCEPTION WHEN duplicate_object THEN NULL;
      END $$
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "bookings" (
        "id"                  UUID          NOT NULL DEFAULT uuid_generate_v4(),
        "user_id"             UUID          NOT NULL,
        "venue_id"            UUID          NOT NULL,
        "service_id"          UUID          NOT NULL,
        "booking_date"        DATE          NOT NULL,
        "start_time"          VARCHAR       NOT NULL,
        "end_time"            VARCHAR       NOT NULL,
        "duration_minutes"    INTEGER       NOT NULL,
        "total_amount"        DECIMAL(10,2) NOT NULL,
        "status"              "public"."bookings_status_enum" NOT NULL DEFAULT 'pending',
        "cancellation_reason" TEXT,
        "notes"               TEXT,
        "booking_reference"   VARCHAR       NOT NULL,
        "created_at"          TIMESTAMP     NOT NULL DEFAULT now(),
        "updated_at"          TIMESTAMP     NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_bookings_reference" UNIQUE ("booking_reference"),
        CONSTRAINT "PK_bookings"           PRIMARY KEY ("id"),
        CONSTRAINT "FK_bookings_user"    FOREIGN KEY ("user_id")    REFERENCES "users"("id"),
        CONSTRAINT "FK_bookings_venue"   FOREIGN KEY ("venue_id")   REFERENCES "venues"("id"),
        CONSTRAINT "FK_bookings_service" FOREIGN KEY ("service_id") REFERENCES "venue_services"("id")
      )
    `);

    // ─── PAYMENTS ────────────────────────────────────────────────────────────
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "public"."payments_status_enum"
          AS ENUM('pending','processing','success','failed','refunded','partially_refunded');
      EXCEPTION WHEN duplicate_object THEN NULL;
      END $$
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "payments" (
        "id"                  UUID          NOT NULL DEFAULT uuid_generate_v4(),
        "booking_id"          UUID          NOT NULL,
        "user_id"             UUID          NOT NULL,
        "amount"              DECIMAL(10,2) NOT NULL,
        "currency"            VARCHAR       NOT NULL DEFAULT 'INR',
        "payment_method"      VARCHAR,
        "payment_gateway"     VARCHAR       DEFAULT 'razorpay',
        "transaction_id"      VARCHAR,
        "gateway_order_id"    VARCHAR,
        "gateway_payment_id"  VARCHAR,
        "gateway_signature"   VARCHAR,
        "status"              "public"."payments_status_enum" NOT NULL DEFAULT 'pending',
        "refund_amount"       DECIMAL(10,2),
        "refund_status"       VARCHAR,
        "refund_id"           VARCHAR,
        "metadata"            JSON,
        "failure_reason"      VARCHAR,
        "created_at"          TIMESTAMP     NOT NULL DEFAULT now(),
        "updated_at"          TIMESTAMP     NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_payments_transaction_id" UNIQUE ("transaction_id"),
        CONSTRAINT "PK_payments"               PRIMARY KEY ("id"),
        CONSTRAINT "FK_payments_booking" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id"),
        CONSTRAINT "FK_payments_user"    FOREIGN KEY ("user_id")    REFERENCES "users"("id")
      )
    `);

    // ─── INDEXES ─────────────────────────────────────────────────────────────
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_users_email"         ON "users"    ("email")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_users_role"          ON "users"    ("role")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_partners_user_id"    ON "partners" ("user_id")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_venues_partner_id"   ON "venues"   ("partner_id")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_venues_category_id"  ON "venues"   ("category_id")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_venues_status"       ON "venues"   ("status")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_venues_city"         ON "venues"   ("city")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_bookings_user_id"    ON "bookings" ("user_id")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_bookings_venue_id"   ON "bookings" ("venue_id")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_bookings_date"       ON "bookings" ("booking_date")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_bookings_status"     ON "bookings" ("status")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_payments_booking_id" ON "payments" ("booking_id")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_payments_user_id"    ON "payments" ("user_id")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_payments_status"     ON "payments" ("status")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_payments_status"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_payments_user_id"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_payments_booking_id"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_bookings_status"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_bookings_date"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_bookings_venue_id"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_bookings_user_id"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_venues_city"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_venues_status"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_venues_category_id"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_venues_partner_id"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_partners_user_id"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_users_role"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_users_email"`);

    await queryRunner.query(`DROP TABLE IF EXISTS "payments"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "bookings"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "venue_answers"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "venue_services"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "venue_images"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "venues"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "questions"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "categories"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "partners"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "users"`);

    await queryRunner.query(`DROP TYPE IF EXISTS "public"."payments_status_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "public"."bookings_status_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "public"."venues_status_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "public"."questions_question_type_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "public"."users_role_enum"`);
  }
}
