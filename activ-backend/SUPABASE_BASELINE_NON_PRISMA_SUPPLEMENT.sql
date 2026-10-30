-- CANDIDATE BASELINE SUPPLEMENT / DO NOT APPLY TO PRODUCTION
-- These objects are present in production but are not represented by the
-- current Prisma datamodel. Include only in a reviewed baseline artifact.

CREATE TABLE public._prisma_migrations (
    id varchar(36) NOT NULL,
    checksum varchar(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name varchar(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id)
);

CREATE SEQUENCE public.migrations_id_seq
    AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

CREATE TABLE public.migrations (
    id integer NOT NULL DEFAULT nextval('public.migrations_id_seq'::regclass),
    "timestamp" bigint NOT NULL,
    name varchar NOT NULL,
    CONSTRAINT "PK_8c82d7f526340ab734260ea46be" PRIMARY KEY (id)
);

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;

CREATE TABLE public.partner_schema_migrations (
    name text NOT NULL,
    checksum text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);
