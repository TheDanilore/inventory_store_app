


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "unaccent" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."user_role" AS ENUM (
    'customer',
    'admin',
    'employee'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_ingredients_unaccent"("search_term" "text") RETURNS TABLE("id" "text")
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'extensions'
    AS $$
begin
  return query
  select ai.id::text
  from active_ingredients ai
  where unaccent(lower(ai.name)) ilike unaccent(lower('%' || search_term || '%'));
end;
$$;


ALTER FUNCTION "public"."search_ingredients_unaccent"("search_term" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_default_location"("p_profile_id" "uuid", "p_location_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'extensions'
    AS $$
BEGIN
  -- 1. Quitar el flag is_default a todas las ubicaciones de este perfil
  UPDATE customer_locations
  SET is_default = false
  WHERE profile_id = p_profile_id;

  -- 2. Establecer el flag is_default solo a la ubicación deseada
  UPDATE customer_locations
  SET is_default = true
  WHERE id = p_location_id;
END;
$$;


ALTER FUNCTION "public"."set_default_location"("p_profile_id" "uuid", "p_location_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."account_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "account_id" "uuid" NOT NULL,
    "movement_type" "text" NOT NULL,
    "amount" numeric NOT NULL,
    "description" "text" NOT NULL,
    "reference_type" "text",
    "reference_id" "uuid",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "shift_id" "uuid"
);


ALTER TABLE "public"."account_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."active_ingredients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "search_vector" "tsvector" GENERATED ALWAYS AS ("to_tsvector"('"spanish"'::"regconfig", "name")) STORED
);


ALTER TABLE "public"."active_ingredients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."app_settings" (
    "key" "text" NOT NULL,
    "value" numeric NOT NULL,
    "description" "text"
);


ALTER TABLE "public"."app_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."attribute_values" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "attribute_id" "uuid" NOT NULL,
    "value" "text" NOT NULL
);


ALTER TABLE "public"."attribute_values" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."attributes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text"
);


ALTER TABLE "public"."attributes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."business_info" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "business_name" "text" NOT NULL,
    "tax_id" "text",
    "address" "text",
    "phone" "text",
    "logo_url" "text",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "loyalty_global_enabled" boolean DEFAULT true,
    "loyalty_customer_visible" boolean DEFAULT true,
    "raffles_global_enabled" boolean DEFAULT false,
    "raffles_customer_visible" boolean DEFAULT false
);


ALTER TABLE "public"."business_info" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cart_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cart_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "variant_id" "uuid",
    "quantity" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_selected" boolean DEFAULT true,
    CONSTRAINT "cart_items_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."cart_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cash_shifts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "account_id" "uuid" NOT NULL,
    "opened_by" "uuid" NOT NULL,
    "closed_by" "uuid",
    "opened_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "closed_at" timestamp with time zone,
    "opening_amount" numeric DEFAULT 0.00 NOT NULL,
    "expected_amount" numeric,
    "actual_amount" numeric,
    "difference_amount" numeric,
    "status" "text" DEFAULT 'OPEN'::"text" NOT NULL,
    "notes" "text",
    CONSTRAINT "cash_shifts_status_check" CHECK (("status" = ANY (ARRAY['OPEN'::"text", 'CLOSED'::"text"])))
);


ALTER TABLE "public"."cash_shifts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_credit_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "customer_credit_id" "uuid" NOT NULL,
    "order_id" "uuid",
    "movement_type" "text" NOT NULL,
    "amount" numeric NOT NULL,
    "payment_method" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    CONSTRAINT "credit_movements_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "credit_movements_movement_type_check" CHECK (("movement_type" = ANY (ARRAY['CHARGE'::"text", 'PAYMENT'::"text"])))
);


ALTER TABLE "public"."customer_credit_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "customer_id" "uuid",
    "total_amount" numeric DEFAULT 0 NOT NULL,
    "total_profit" numeric DEFAULT 0 NOT NULL,
    "payment_method" "text" DEFAULT 'EFECTIVO'::"text" NOT NULL,
    "status" "text" DEFAULT 'COMPLETED'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "warehouse_id" "uuid",
    "points_used" integer DEFAULT 0 NOT NULL,
    "points_earned" integer DEFAULT 0 NOT NULL,
    "customer_name" "text" DEFAULT ''::"text",
    "payment_status" "text" DEFAULT 'PAID'::"text" NOT NULL,
    "amount_paid" numeric DEFAULT 0.00 NOT NULL,
    "due_date" timestamp with time zone,
    "created_by" "uuid",
    "discount_amount" numeric DEFAULT 0.00 NOT NULL,
    "document_type" "text" DEFAULT 'NINGUNO'::"text",
    "document_number" "text",
    "document_date" "date",
    "updated_by" "uuid",
    "updated_at" timestamp with time zone,
    CONSTRAINT "orders_document_type_check" CHECK (("document_type" = ANY (ARRAY['BOLETA'::"text", 'FACTURA'::"text", 'TICKET'::"text", 'NINGUNO'::"text"]))),
    CONSTRAINT "orders_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['PAID'::"text", 'PENDING'::"text", 'PARTIAL'::"text"])))
);


ALTER TABLE "public"."orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "auth_user_id" "uuid",
    "full_name" "text" NOT NULL,
    "avatar_url" "text",
    "role" "public"."user_role" DEFAULT 'customer'::"public"."user_role" NOT NULL,
    "phone" "text",
    "document_type" "text" DEFAULT 'DNI'::"text",
    "document_number" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_active" boolean DEFAULT true NOT NULL,
    "wallet_balance" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."customer_credit_movements_summary" WITH ("security_invoker"='true') AS
 SELECT "cm"."id",
    "cm"."customer_credit_id",
    "cm"."order_id",
    "cm"."movement_type",
    "cm"."amount",
    "cm"."payment_method",
    "cm"."notes",
    "cm"."created_at",
    "cm"."created_by",
    "p"."full_name" AS "created_by_name",
    "o"."customer_name",
    "o"."payment_method" AS "order_payment_method",
    "o"."total_amount" AS "order_total_amount",
    ("o"."id")::"text" AS "order_number"
   FROM (("public"."customer_credit_movements" "cm"
     LEFT JOIN "public"."profiles" "p" ON (("p"."id" = "cm"."created_by")))
     LEFT JOIN "public"."orders" "o" ON (("o"."id" = "cm"."order_id")));


ALTER VIEW "public"."customer_credit_movements_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_credits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "credit_limit" numeric DEFAULT 0.00 NOT NULL,
    "current_debt" numeric DEFAULT 0.00 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    CONSTRAINT "customer_credits_current_debt_check" CHECK (("current_debt" >= (0)::numeric))
);


ALTER TABLE "public"."customer_credits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_locations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "location_type" "text" DEFAULT 'otro'::"text" NOT NULL,
    "latitude" double precision NOT NULL,
    "longitude" double precision NOT NULL,
    "address_line" "text",
    "reference" "text",
    "notes" "text",
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    CONSTRAINT "customer_locations_type_check" CHECK (("location_type" = ANY (ARRAY['casa'::"text", 'chacra'::"text", 'fundo'::"text", 'local'::"text", 'otro'::"text"])))
);


ALTER TABLE "public"."customer_locations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_checkins" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "checkin_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "points_received" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "streak_day" integer DEFAULT 1
);


ALTER TABLE "public"."daily_checkins" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."financial_accounts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "type" "text" NOT NULL,
    "balance" numeric DEFAULT 0.00 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."financial_accounts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_entries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "supplier_id" "uuid",
    "purchase_order_id" "uuid",
    "document_type" "text" DEFAULT 'NINGUNO'::"text",
    "document_number" "text",
    "document_date" "date",
    "total_amount" numeric DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."inventory_entries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_entry_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entry_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "quantity" numeric NOT NULL,
    "unit_cost" numeric NOT NULL,
    "batch_number" "text" DEFAULT 'DEFAULT'::"text",
    "expiry_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "inventory_entry_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "inventory_entry_items_unit_cost_check" CHECK (("unit_cost" >= (0)::numeric))
);


ALTER TABLE "public"."inventory_entry_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_exit_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "exit_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "quantity" numeric NOT NULL,
    "batch_number" "text" DEFAULT 'DEFAULT'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "unit_cost" numeric DEFAULT 0,
    CONSTRAINT "inventory_exit_items_quantity_check" CHECK (("quantity" > (0)::numeric))
);


ALTER TABLE "public"."inventory_exit_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_exits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "reason" "text",
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventory_exits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "stock_batch_id" "uuid",
    "order_id" "uuid",
    "inventory_entry_id" "uuid",
    "inventory_exit_id" "uuid",
    "physical_inventory_id" "uuid",
    "quantity" numeric NOT NULL,
    "previous_stock" numeric NOT NULL,
    "new_stock" numeric NOT NULL,
    "unit_cost" numeric,
    "total_cost" numeric,
    "reason" "text" NOT NULL,
    "notes" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventory_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "quantity" integer DEFAULT 1 NOT NULL,
    "unit_cost" numeric NOT NULL,
    "applied_price" numeric NOT NULL,
    "net_profit" numeric NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "variant_id" "uuid" NOT NULL
);


ALTER TABLE "public"."order_items" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."partner_credit_summary" WITH ("security_invoker"='true') AS
 SELECT "cc"."id" AS "credit_id",
    "cc"."profile_id",
    "p"."full_name" AS "partner_name",
    "p"."document_number" AS "partner_document",
    "p"."document_type" AS "partner_document_type",
    "p"."phone" AS "partner_phone",
    "cc"."credit_limit",
    "cc"."current_debt",
    GREATEST(("cc"."credit_limit" - "cc"."current_debt"), (0)::numeric) AS "available_credit",
    "cc"."is_active"
   FROM ("public"."customer_credits" "cc"
     JOIN "public"."profiles" "p" ON (("p"."id" = "cc"."profile_id")));


ALTER VIEW "public"."partner_credit_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."physical_inventories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone,
    CONSTRAINT "physical_inventories_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'COMPLETED'::"text", 'CANCELLED'::"text"])))
);


ALTER TABLE "public"."physical_inventories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."physical_inventory_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "physical_inventory_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "batch_number" "text",
    "expiry_date" "date",
    "system_quantity" numeric NOT NULL,
    "counted_quantity" numeric,
    "difference" numeric,
    "unit_cost" numeric,
    "total_difference_cost" numeric,
    "notes" "text",
    "counted_by" "uuid",
    "counted_at" timestamp with time zone
);


ALTER TABLE "public"."physical_inventory_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_active_ingredients" (
    "product_id" "uuid" NOT NULL,
    "ingredient_id" "uuid" NOT NULL,
    "concentration" numeric,
    "unit" "text"
);


ALTER TABLE "public"."product_active_ingredients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_images" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "variant_id" "uuid",
    "image_url" "text" NOT NULL,
    "display_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_main" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."product_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "profile_id" "uuid",
    "user_name" "text" DEFAULT 'Usuario Anónimo'::"text" NOT NULL,
    "rating" integer NOT NULL,
    "comment" "text",
    "images" "text"[] DEFAULT '{}'::"text"[],
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "product_reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."product_reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_variants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "sku" "text",
    "sale_price" numeric,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "reorder_point" integer DEFAULT 3 NOT NULL,
    "wholesale_price" numeric,
    "wholesale_min_quantity" integer,
    "created_by" "uuid",
    "updated_by" "uuid",
    "unit_cost" numeric DEFAULT 0 NOT NULL,
    "barcode" "text"
);


ALTER TABLE "public"."product_variants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."warehouse_stock_batches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "batch_number" "text" DEFAULT 'DEFAULT'::"text" NOT NULL,
    "expiry_date" "date",
    "available_quantity" numeric DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid",
    "product_id" "uuid" NOT NULL,
    "supplier_id" "uuid"
);


ALTER TABLE "public"."warehouse_stock_batches" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."product_stock_summary" WITH ("security_invoker"='true') AS
 SELECT "pv"."product_id",
    "pv"."id" AS "variant_id",
    COALESCE("sum"("wsb"."available_quantity"), (0)::numeric) AS "total_stock"
   FROM ("public"."product_variants" "pv"
     LEFT JOIN "public"."warehouse_stock_batches" "wsb" ON (("pv"."id" = "wsb"."variant_id")))
  GROUP BY "pv"."product_id", "pv"."id";


ALTER VIEW "public"."product_stock_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "unit_cost" numeric,
    "sale_price" numeric,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "category_id" "uuid",
    "description" "text",
    "wholesale_price" numeric,
    "wholesale_min_quantity" integer DEFAULT 3,
    "updated_at" timestamp with time zone,
    "details" "jsonb" DEFAULT '{}'::"jsonb",
    "created_by" "uuid",
    "updated_by" "uuid",
    "stock_control" boolean DEFAULT true NOT NULL,
    "uses_batches" boolean DEFAULT false NOT NULL,
    "product_type" "text" DEFAULT 'good'::"text" NOT NULL,
    CONSTRAINT "products_product_type_check" CHECK (("product_type" = ANY (ARRAY['good'::"text", 'service'::"text", 'digital'::"text"])))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."profiles_with_email" WITH ("security_invoker"='true') AS
 SELECT "p"."id",
    "p"."auth_user_id",
    "p"."full_name",
    "p"."avatar_url",
    "p"."role",
    "p"."phone",
    "p"."document_type",
    "p"."document_number",
    "p"."created_at",
    "p"."is_active",
    "p"."wallet_balance",
    "u"."email"
   FROM ("public"."profiles" "p"
     LEFT JOIN "auth"."users" "u" ON (("p"."auth_user_id" = "u"."id")));


ALTER VIEW "public"."profiles_with_email" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purchase_order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "purchase_order_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "variant_id" "uuid" NOT NULL,
    "quantity_ordered" numeric NOT NULL,
    "quantity_received" numeric DEFAULT 0 NOT NULL,
    "unit_cost" numeric NOT NULL,
    "net_cost" numeric DEFAULT 0 NOT NULL,
    "batch_number" "text" DEFAULT 'DEFAULT'::"text",
    "expiry_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "purchase_order_items_quantity_ordered_check" CHECK (("quantity_ordered" > (0)::numeric)),
    CONSTRAINT "purchase_order_items_unit_cost_check" CHECK (("unit_cost" >= (0)::numeric))
);


ALTER TABLE "public"."purchase_order_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purchase_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "supplier_id" "uuid",
    "supplier_name" "text" DEFAULT ''::"text" NOT NULL,
    "warehouse_id" "uuid",
    "status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "total_amount" numeric DEFAULT 0 NOT NULL,
    "payment_method" "text" DEFAULT 'EFECTIVO'::"text" NOT NULL,
    "payment_status" "text" DEFAULT 'PAID'::"text" NOT NULL,
    "amount_paid" numeric DEFAULT 0 NOT NULL,
    "due_date" timestamp with time zone,
    "discount_amount" numeric DEFAULT 0 NOT NULL,
    "document_type" "text" DEFAULT 'NINGUNO'::"text",
    "document_number" "text",
    "document_date" "date",
    "tax_amount" numeric DEFAULT 0 NOT NULL,
    "notes" "text",
    "created_by" "uuid",
    "updated_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "purchase_orders_document_type_check" CHECK (("document_type" = ANY (ARRAY['FACTURA'::"text", 'BOLETA'::"text", 'GUIA_REMISION'::"text", 'TICKET'::"text", 'NINGUNO'::"text"]))),
    CONSTRAINT "purchase_orders_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['PAID'::"text", 'PENDING'::"text", 'PARTIAL'::"text"]))),
    CONSTRAINT "purchase_orders_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'SENT'::"text", 'PARTIAL'::"text", 'RECEIVED'::"text", 'CANCELLED'::"text"])))
);


ALTER TABLE "public"."purchase_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shopping_carts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shopping_carts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."supplier_credit_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "supplier_credit_id" "uuid" NOT NULL,
    "purchase_order_id" "uuid",
    "movement_type" "text" NOT NULL,
    "amount" numeric NOT NULL,
    "payment_method" "text",
    "due_date" "date",
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "supplier_credit_movements_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "supplier_credit_movements_movement_type_check" CHECK (("movement_type" = ANY (ARRAY['CHARGE'::"text", 'PAYMENT'::"text"])))
);


ALTER TABLE "public"."supplier_credit_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."supplier_credits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "supplier_id" "uuid" NOT NULL,
    "current_debt" numeric DEFAULT 0 NOT NULL,
    "credit_limit" numeric DEFAULT 0 NOT NULL,
    "payment_terms_days" integer DEFAULT 30 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    CONSTRAINT "supplier_credits_current_debt_check" CHECK (("current_debt" >= (0)::numeric))
);


ALTER TABLE "public"."supplier_credits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."suppliers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "tax_id" "text",
    "contact_name" "text",
    "phone" "text",
    "email" "text",
    "address" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."suppliers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."variant_attribute_values" (
    "variant_id" "uuid" NOT NULL,
    "attribute_value_id" "uuid" NOT NULL
);


ALTER TABLE "public"."variant_attribute_values" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wallet_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "order_id" "uuid",
    "points" integer NOT NULL,
    "movement_type" "text" NOT NULL,
    "description" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."wallet_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."warehouses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "address" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."warehouses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wishlist" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."wishlist" OWNER TO "postgres";


ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."active_ingredients"
    ADD CONSTRAINT "active_ingredients_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."active_ingredients"
    ADD CONSTRAINT "active_ingredients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_settings"
    ADD CONSTRAINT "app_settings_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."attribute_values"
    ADD CONSTRAINT "attribute_values_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attributes"
    ADD CONSTRAINT "attributes_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."attributes"
    ADD CONSTRAINT "attributes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attribute_values"
    ADD CONSTRAINT "av_unique_value_per_attribute" UNIQUE ("attribute_id", "value");



ALTER TABLE ONLY "public"."business_info"
    ADD CONSTRAINT "business_info_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "credit_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_profile_id_key" UNIQUE ("profile_id");



ALTER TABLE ONLY "public"."customer_locations"
    ADD CONSTRAINT "customer_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_checkins"
    ADD CONSTRAINT "daily_checkins_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."financial_accounts"
    ADD CONSTRAINT "financial_accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_entry_items"
    ADD CONSTRAINT "inventory_entry_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_exit_items"
    ADD CONSTRAINT "inventory_exit_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_exits"
    ADD CONSTRAINT "inventory_exits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "inventory_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."physical_inventories"
    ADD CONSTRAINT "physical_inventories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."physical_inventory_items"
    ADD CONSTRAINT "physical_inventory_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_active_ingredients"
    ADD CONSTRAINT "product_active_ingredients_pkey" PRIMARY KEY ("product_id", "ingredient_id");



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_reviews"
    ADD CONSTRAINT "product_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_sku_key" UNIQUE ("sku");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_auth_user_id_key" UNIQUE ("auth_user_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shopping_carts"
    ADD CONSTRAINT "shopping_carts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shopping_carts"
    ADD CONSTRAINT "shopping_carts_profile_id_key" UNIQUE ("profile_id");



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."supplier_credits"
    ADD CONSTRAINT "supplier_credits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."supplier_credits"
    ADD CONSTRAINT "supplier_credits_supplier_id_key" UNIQUE ("supplier_id");



ALTER TABLE ONLY "public"."suppliers"
    ADD CONSTRAINT "suppliers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."suppliers"
    ADD CONSTRAINT "suppliers_tax_id_key" UNIQUE ("tax_id");



ALTER TABLE ONLY "public"."variant_attribute_values"
    ADD CONSTRAINT "variant_attribute_values_pkey" PRIMARY KEY ("variant_id", "attribute_value_id");



ALTER TABLE ONLY "public"."wallet_movements"
    ADD CONSTRAINT "wallet_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "warehouse_stock_batches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."warehouses"
    ADD CONSTRAINT "warehouses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_pkey" PRIMARY KEY ("id");



CREATE INDEX "account_movements_account_id_idx" ON "public"."account_movements" USING "btree" ("account_id");



CREATE INDEX "account_movements_created_by_idx" ON "public"."account_movements" USING "btree" ("created_by");



CREATE INDEX "account_movements_shift_id_idx" ON "public"."account_movements" USING "btree" ("shift_id");



CREATE INDEX "cart_items_cart_id_idx" ON "public"."cart_items" USING "btree" ("cart_id");



CREATE INDEX "cart_items_product_id_idx" ON "public"."cart_items" USING "btree" ("product_id");



CREATE INDEX "cart_items_variant_id_idx" ON "public"."cart_items" USING "btree" ("variant_id");



CREATE INDEX "cash_shifts_account_id_idx" ON "public"."cash_shifts" USING "btree" ("account_id");



CREATE INDEX "cash_shifts_closed_by_idx" ON "public"."cash_shifts" USING "btree" ("closed_by");



CREATE INDEX "cash_shifts_opened_by_idx" ON "public"."cash_shifts" USING "btree" ("opened_by");



CREATE INDEX "categories_created_by_idx" ON "public"."categories" USING "btree" ("created_by");



CREATE INDEX "categories_updated_by_idx" ON "public"."categories" USING "btree" ("updated_by");



CREATE INDEX "customer_credits_created_by_idx" ON "public"."customer_credits" USING "btree" ("created_by");



CREATE INDEX "daily_checkins_profile_id_idx" ON "public"."daily_checkins" USING "btree" ("profile_id");



CREATE INDEX "idx_customer_credit_movements_created_by" ON "public"."customer_credit_movements" USING "btree" ("created_by");



CREATE INDEX "idx_customer_credit_movements_customer_credit_id" ON "public"."customer_credit_movements" USING "btree" ("customer_credit_id");



CREATE INDEX "idx_customer_credit_movements_order_id" ON "public"."customer_credit_movements" USING "btree" ("order_id");



CREATE INDEX "idx_customer_locations_profile_id" ON "public"."customer_locations" USING "btree" ("profile_id");



CREATE INDEX "idx_inventory_movements_created_by" ON "public"."inventory_movements" USING "btree" ("created_by");



CREATE INDEX "idx_inventory_movements_variant_id" ON "public"."inventory_movements" USING "btree" ("variant_id");



CREATE INDEX "idx_inventory_movements_warehouse_id" ON "public"."inventory_movements" USING "btree" ("warehouse_id");



CREATE INDEX "idx_order_items_order_id" ON "public"."order_items" USING "btree" ("order_id");



CREATE INDEX "idx_order_items_product_id" ON "public"."order_items" USING "btree" ("product_id");



CREATE INDEX "idx_orders_created_by" ON "public"."orders" USING "btree" ("created_by");



CREATE INDEX "idx_orders_customer_id" ON "public"."orders" USING "btree" ("customer_id");



CREATE INDEX "idx_orders_warehouse_id" ON "public"."orders" USING "btree" ("warehouse_id");



CREATE INDEX "idx_product_images_product_id" ON "public"."product_images" USING "btree" ("product_id");



CREATE INDEX "idx_product_variants_barcode" ON "public"."product_variants" USING "btree" ("barcode");



CREATE INDEX "idx_product_variants_product_id" ON "public"."product_variants" USING "btree" ("product_id");



CREATE INDEX "idx_products_category_id" ON "public"."products" USING "btree" ("category_id");



CREATE INDEX "idx_purchase_order_items_po_id" ON "public"."purchase_order_items" USING "btree" ("purchase_order_id");



CREATE INDEX "idx_purchase_orders_supplier_id" ON "public"."purchase_orders" USING "btree" ("supplier_id");



CREATE INDEX "idx_supplier_credit_movements_created_by" ON "public"."supplier_credit_movements" USING "btree" ("created_by");



CREATE INDEX "idx_supplier_credit_movements_credit_id" ON "public"."supplier_credit_movements" USING "btree" ("supplier_credit_id");



CREATE INDEX "idx_supplier_credit_movements_po_id" ON "public"."supplier_credit_movements" USING "btree" ("purchase_order_id");



CREATE INDEX "iei_entry_id__idx" ON "public"."inventory_entry_items" USING "btree" ("entry_id");



CREATE INDEX "iei_product_id_idx" ON "public"."inventory_entry_items" USING "btree" ("product_id");



CREATE INDEX "iei_variant_id_idx" ON "public"."inventory_entry_items" USING "btree" ("variant_id");



CREATE INDEX "iexi_exit_id_idx" ON "public"."inventory_exit_items" USING "btree" ("exit_id");



CREATE INDEX "iexi_product_id_idx" ON "public"."inventory_exit_items" USING "btree" ("product_id");



CREATE INDEX "iexi_variant_id_idx" ON "public"."inventory_exit_items" USING "btree" ("variant_id");



CREATE INDEX "im_entry_id_idx" ON "public"."inventory_movements" USING "btree" ("inventory_entry_id");



CREATE INDEX "im_exit_id_idx" ON "public"."inventory_movements" USING "btree" ("inventory_exit_id");



CREATE INDEX "im_order_id_idx" ON "public"."inventory_movements" USING "btree" ("order_id");



CREATE INDEX "im_physical_inv_id_idx" ON "public"."inventory_movements" USING "btree" ("physical_inventory_id");



CREATE INDEX "im_stock_batch_id_idx" ON "public"."inventory_movements" USING "btree" ("stock_batch_id");



CREATE INDEX "inventory_entries_created_by_idx" ON "public"."inventory_entries" USING "btree" ("created_by");



CREATE INDEX "inventory_entries_purchase_order_id_idx" ON "public"."inventory_entries" USING "btree" ("purchase_order_id");



CREATE INDEX "inventory_entries_supplier_id_idx" ON "public"."inventory_entries" USING "btree" ("supplier_id");



CREATE INDEX "inventory_entries_warehouse_id_idx" ON "public"."inventory_entries" USING "btree" ("warehouse_id");



CREATE INDEX "inventory_exits_created_by_idx" ON "public"."inventory_exits" USING "btree" ("created_by");



CREATE INDEX "inventory_exits_store_id_idx" ON "public"."inventory_exits" USING "btree" ("warehouse_id");



CREATE INDEX "order_items_variant_id_idx" ON "public"."order_items" USING "btree" ("variant_id");



CREATE INDEX "orders_updated_by_idx" ON "public"."orders" USING "btree" ("updated_by");



CREATE INDEX "p_variants_created_by_idx" ON "public"."product_variants" USING "btree" ("created_by");



CREATE INDEX "pai_ingredient_id_idx" ON "public"."product_active_ingredients" USING "btree" ("ingredient_id");



CREATE INDEX "pi_created_by_idx" ON "public"."physical_inventories" USING "btree" ("created_by");



CREATE INDEX "pi_warehouse_id_idx" ON "public"."physical_inventories" USING "btree" ("warehouse_id");



CREATE INDEX "pii_counted_by_idx" ON "public"."physical_inventory_items" USING "btree" ("counted_by");



CREATE INDEX "pii_inventory_id_idx" ON "public"."physical_inventory_items" USING "btree" ("physical_inventory_id");



CREATE INDEX "pii_variant_id_idx" ON "public"."physical_inventory_items" USING "btree" ("variant_id");



CREATE INDEX "po_items_product_id_idx" ON "public"."purchase_order_items" USING "btree" ("product_id");



CREATE INDEX "po_items_variant_id_idx" ON "public"."purchase_order_items" USING "btree" ("variant_id");



CREATE INDEX "product_images_variant_id_idx" ON "public"."product_images" USING "btree" ("variant_id");



CREATE INDEX "product_reviews_product_id_idx" ON "public"."product_reviews" USING "btree" ("product_id");



CREATE INDEX "product_reviews_profile_id_idx" ON "public"."product_reviews" USING "btree" ("profile_id");



CREATE INDEX "product_updated_by_idx" ON "public"."products" USING "btree" ("updated_by");



CREATE INDEX "product_variants_updated_by_idx" ON "public"."product_variants" USING "btree" ("updated_by");



CREATE INDEX "products_created_by_idx" ON "public"."products" USING "btree" ("created_by");



CREATE INDEX "purchase_orders_created_by_idx" ON "public"."purchase_orders" USING "btree" ("created_by");



CREATE INDEX "purchase_orders_updated_by_idx" ON "public"."purchase_orders" USING "btree" ("updated_by");



CREATE INDEX "purchase_orders_warehouse_id_idx" ON "public"."purchase_orders" USING "btree" ("warehouse_id");



CREATE INDEX "supplier_credits_created_by_fidx" ON "public"."supplier_credits" USING "btree" ("created_by");



CREATE INDEX "vav_attribute_value_id_fidx" ON "public"."variant_attribute_values" USING "btree" ("attribute_value_id");



CREATE INDEX "wallet_movements_order_id_idx" ON "public"."wallet_movements" USING "btree" ("order_id");



CREATE INDEX "wallet_movements_profile_id_idx" ON "public"."wallet_movements" USING "btree" ("profile_id");



CREATE INDEX "warehouse_stock_batches_supplier_id_idx" ON "public"."warehouse_stock_batches" USING "btree" ("supplier_id");



CREATE INDEX "warehouses_created_by_idx" ON "public"."warehouses" USING "btree" ("created_by");



CREATE INDEX "warehouses_updated_by_idx" ON "public"."warehouses" USING "btree" ("updated_by");



CREATE INDEX "wishlist_product_id_idx" ON "public"."wishlist" USING "btree" ("product_id");



CREATE INDEX "wishlist_profile_id_idx" ON "public"."wishlist" USING "btree" ("profile_id");



CREATE INDEX "wsb_created_by_idx" ON "public"."warehouse_stock_batches" USING "btree" ("created_by");



CREATE INDEX "wsb_product_id_idx" ON "public"."warehouse_stock_batches" USING "btree" ("product_id");



CREATE INDEX "wsb_updated_by_idx" ON "public"."warehouse_stock_batches" USING "btree" ("updated_by");



CREATE INDEX "wsb_variant_id_idx" ON "public"."warehouse_stock_batches" USING "btree" ("variant_id");



CREATE INDEX "wsb_warehouse_id_idx" ON "public"."warehouse_stock_batches" USING "btree" ("warehouse_id");



ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."financial_accounts"("id");



ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."cash_shifts"("id");



ALTER TABLE ONLY "public"."attribute_values"
    ADD CONSTRAINT "av_attribute_id_fkey" FOREIGN KEY ("attribute_id") REFERENCES "public"."attributes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "public"."shopping_carts"("id");



ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."financial_accounts"("id");



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_closed_by_fkey" FOREIGN KEY ("closed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_opened_by_fkey" FOREIGN KEY ("opened_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "customer_credit_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "customer_credit_movements_customer_credit_id_fkey" FOREIGN KEY ("customer_credit_id") REFERENCES "public"."customer_credits"("id");



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "customer_credit_movements_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."customer_locations"
    ADD CONSTRAINT "customer_locations_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_checkins"
    ADD CONSTRAINT "daily_checkins_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."inventory_entry_items"
    ADD CONSTRAINT "iei_entry_id_fkey" FOREIGN KEY ("entry_id") REFERENCES "public"."inventory_entries"("id");



ALTER TABLE ONLY "public"."inventory_entry_items"
    ADD CONSTRAINT "iei_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."inventory_entry_items"
    ADD CONSTRAINT "iei_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."inventory_exit_items"
    ADD CONSTRAINT "iexi_exit_id_fkey" FOREIGN KEY ("exit_id") REFERENCES "public"."inventory_exits"("id");



ALTER TABLE ONLY "public"."inventory_exit_items"
    ADD CONSTRAINT "iexi_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."inventory_exit_items"
    ADD CONSTRAINT "iexi_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_entry_id_fkey" FOREIGN KEY ("inventory_entry_id") REFERENCES "public"."inventory_entries"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_exit_id_fkey" FOREIGN KEY ("inventory_exit_id") REFERENCES "public"."inventory_exits"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_physical_inv_id_fkey" FOREIGN KEY ("physical_inventory_id") REFERENCES "public"."physical_inventories"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_stock_batch_id_fkey" FOREIGN KEY ("stock_batch_id") REFERENCES "public"."warehouse_stock_batches"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."purchase_orders"("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_store_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."inventory_exits"
    ADD CONSTRAINT "inventory_exits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."inventory_exits"
    ADD CONSTRAINT "inventory_exits_store_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_store_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."product_active_ingredients"
    ADD CONSTRAINT "pai_ingredient_id_fkey" FOREIGN KEY ("ingredient_id") REFERENCES "public"."active_ingredients"("id");



ALTER TABLE ONLY "public"."product_active_ingredients"
    ADD CONSTRAINT "pai_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."physical_inventories"
    ADD CONSTRAINT "pi_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."physical_inventories"
    ADD CONSTRAINT "pi_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."physical_inventory_items"
    ADD CONSTRAINT "pii_counted_by_fkey" FOREIGN KEY ("counted_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."physical_inventory_items"
    ADD CONSTRAINT "pii_inventory_id_fkey" FOREIGN KEY ("physical_inventory_id") REFERENCES "public"."physical_inventories"("id");



ALTER TABLE ONLY "public"."physical_inventory_items"
    ADD CONSTRAINT "pii_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."product_reviews"
    ADD CONSTRAINT "product_reviews_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."product_reviews"
    ADD CONSTRAINT "product_reviews_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_auth_user_id_fkey" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."purchase_orders"("id");



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."shopping_carts"
    ADD CONSTRAINT "shopping_carts_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."purchase_orders"("id");



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_supplier_credit_id_fkey" FOREIGN KEY ("supplier_credit_id") REFERENCES "public"."supplier_credits"("id");



ALTER TABLE ONLY "public"."supplier_credits"
    ADD CONSTRAINT "supplier_credits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."supplier_credits"
    ADD CONSTRAINT "supplier_credits_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."variant_attribute_values"
    ADD CONSTRAINT "vav_attribute_value_id_fkey" FOREIGN KEY ("attribute_value_id") REFERENCES "public"."attribute_values"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."variant_attribute_values"
    ADD CONSTRAINT "vav_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wallet_movements"
    ADD CONSTRAINT "wallet_movements_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."wallet_movements"
    ADD CONSTRAINT "wallet_movements_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "warehouse_stock_batches_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."warehouses"
    ADD CONSTRAINT "warehouses_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."warehouses"
    ADD CONSTRAINT "warehouses_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "wsb_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "wsb_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "wsb_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "wsb_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "wsb_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



CREATE POLICY "Acceso a cart_items propios" ON "public"."cart_items" USING ((("cart_id" IN ( SELECT "shopping_carts"."id"
   FROM "public"."shopping_carts"
  WHERE ("shopping_carts"."profile_id" = "extensions"."auth_profile_id"()))) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Acceso propio CRUD" ON "public"."shopping_carts" USING ((("profile_id" = "extensions"."auth_profile_id"()) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Acceso propio CRUD" ON "public"."wishlist" USING ((("profile_id" = "extensions"."auth_profile_id"()) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Acceso selectivo a créditos por rol o propietario" ON "public"."customer_credits" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "profile_id") OR (( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Acceso total admin y empleado" ON "public"."account_movements" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."financial_accounts" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."physical_inventories" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."physical_inventory_items" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."supplier_credits" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."suppliers" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."warehouse_stock_batches" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."warehouses" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Actualizacion de reviews" ON "public"."product_reviews" FOR UPDATE USING ((("profile_id" = "extensions"."auth_profile_id"()) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Actualizacion de turno" ON "public"."cash_shifts" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Actualización del propio perfil" ON "public"."profiles" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Borrado admin checkins" ON "public"."daily_checkins" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."active_ingredients" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."app_settings" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."attribute_values" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."attributes" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."categories" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."product_active_ingredients" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."product_images" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."product_variants" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."products" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."variant_attribute_values" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado de reviews" ON "public"."product_reviews" FOR DELETE USING ((("profile_id" = "extensions"."auth_profile_id"()) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Gestión selectiva de ubicaciones por rol o propietario" ON "public"."customer_locations" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "profile_id") OR (( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."active_ingredients" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."app_settings" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."attribute_values" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."attributes" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."categories" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."product_active_ingredients" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."product_images" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."product_variants" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."products" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."variant_attribute_values" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion de reviews" ON "public"."product_reviews" FOR INSERT WITH CHECK (("profile_id" = "extensions"."auth_profile_id"()));



CREATE POLICY "Insercion propia de checkins" ON "public"."daily_checkins" FOR INSERT WITH CHECK (("profile_id" = "extensions"."auth_profile_id"()));



CREATE POLICY "Insercion validada e inmutable" ON "public"."cash_shifts" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("opened_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."customer_credit_movements" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."inventory_entries" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."inventory_entry_items" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion validada e inmutable" ON "public"."inventory_exit_items" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion validada e inmutable" ON "public"."inventory_exits" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."inventory_movements" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."purchase_order_items" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion validada e inmutable" ON "public"."purchase_orders" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."supplier_credit_movements" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Inserción unificada de artículos de orden" ON "public"."order_items" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) OR (EXISTS ( SELECT 1
   FROM "public"."orders" "o"
  WHERE (("o"."id" = "order_items"."order_id") AND ("o"."customer_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "Inserción unificada de órdenes" ON "public"."orders" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) OR (( SELECT "auth"."uid"() AS "uid") = "customer_id")));



CREATE POLICY "Lectura admin/empleado" ON "public"."cash_shifts" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."customer_credit_movements" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."inventory_entries" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."inventory_entry_items" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."inventory_exit_items" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."inventory_exits" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."inventory_movements" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."purchase_order_items" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."purchase_orders" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."supplier_credit_movements" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura propia de checkins" ON "public"."daily_checkins" FOR SELECT USING ((("profile_id" = "extensions"."auth_profile_id"()) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Lectura publica" ON "public"."active_ingredients" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."app_settings" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."attribute_values" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."attributes" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."categories" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."product_active_ingredients" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."product_images" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."product_variants" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."products" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."variant_attribute_values" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de business_info" ON "public"."business_info" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de reviews" ON "public"."product_reviews" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de stock" ON "public"."warehouse_stock_batches" FOR SELECT USING (true);



CREATE POLICY "Lectura selectiva de movimientos de billetera por rol o propiet" ON "public"."wallet_movements" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "profile_id") OR (( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Lectura selectiva de perfiles por rol o propietario" ON "public"."profiles" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "id") OR (( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Lectura unificada de artículos de orden" ON "public"."order_items" FOR SELECT TO "authenticated" USING (((( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) OR (EXISTS ( SELECT 1
   FROM "public"."orders" "o"
  WHERE (("o"."id" = "order_items"."order_id") AND ("o"."customer_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "Lectura unificada de órdenes" ON "public"."orders" FOR SELECT TO "authenticated" USING (((( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) OR (( SELECT "auth"."uid"() AS "uid") = "customer_id")));



CREATE POLICY "Modificacion admin business_info" ON "public"."business_info" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin checkins" ON "public"."daily_checkins" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."active_ingredients" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."app_settings" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."attribute_values" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."attributes" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."categories" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."product_active_ingredients" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."product_images" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."product_variants" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."products" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."variant_attribute_values" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



ALTER TABLE "public"."account_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."active_ingredients" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."app_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."attribute_values" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."attributes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."business_info" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cart_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cash_shifts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_credit_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_credits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_locations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."daily_checkins" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."financial_accounts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_entry_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_exit_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_exits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."physical_inventories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."physical_inventory_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_active_ingredients" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_images" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_variants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."purchase_order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."purchase_orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shopping_carts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."supplier_credit_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."supplier_credits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."suppliers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."variant_attribute_values" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wallet_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouse_stock_batches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wishlist" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";























































































































































































REVOKE ALL ON FUNCTION "public"."search_ingredients_unaccent"("search_term" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."search_ingredients_unaccent"("search_term" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_ingredients_unaccent"("search_term" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_default_location"("p_profile_id" "uuid", "p_location_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_default_location"("p_profile_id" "uuid", "p_location_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_default_location"("p_profile_id" "uuid", "p_location_id" "uuid") TO "service_role";
























GRANT ALL ON TABLE "public"."account_movements" TO "anon";
GRANT ALL ON TABLE "public"."account_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."account_movements" TO "service_role";



GRANT ALL ON TABLE "public"."active_ingredients" TO "anon";
GRANT ALL ON TABLE "public"."active_ingredients" TO "authenticated";
GRANT ALL ON TABLE "public"."active_ingredients" TO "service_role";



GRANT ALL ON TABLE "public"."app_settings" TO "anon";
GRANT ALL ON TABLE "public"."app_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."app_settings" TO "service_role";



GRANT ALL ON TABLE "public"."attribute_values" TO "anon";
GRANT ALL ON TABLE "public"."attribute_values" TO "authenticated";
GRANT ALL ON TABLE "public"."attribute_values" TO "service_role";



GRANT ALL ON TABLE "public"."attributes" TO "anon";
GRANT ALL ON TABLE "public"."attributes" TO "authenticated";
GRANT ALL ON TABLE "public"."attributes" TO "service_role";



GRANT ALL ON TABLE "public"."business_info" TO "anon";
GRANT ALL ON TABLE "public"."business_info" TO "authenticated";
GRANT ALL ON TABLE "public"."business_info" TO "service_role";



GRANT ALL ON TABLE "public"."cart_items" TO "anon";
GRANT ALL ON TABLE "public"."cart_items" TO "authenticated";
GRANT ALL ON TABLE "public"."cart_items" TO "service_role";



GRANT ALL ON TABLE "public"."cash_shifts" TO "anon";
GRANT ALL ON TABLE "public"."cash_shifts" TO "authenticated";
GRANT ALL ON TABLE "public"."cash_shifts" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."customer_credit_movements" TO "anon";
GRANT ALL ON TABLE "public"."customer_credit_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_credit_movements" TO "service_role";



GRANT ALL ON TABLE "public"."orders" TO "anon";
GRANT ALL ON TABLE "public"."orders" TO "authenticated";
GRANT ALL ON TABLE "public"."orders" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."customer_credit_movements_summary" TO "anon";
GRANT ALL ON TABLE "public"."customer_credit_movements_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_credit_movements_summary" TO "service_role";



GRANT ALL ON TABLE "public"."customer_credits" TO "anon";
GRANT ALL ON TABLE "public"."customer_credits" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_credits" TO "service_role";



GRANT ALL ON TABLE "public"."customer_locations" TO "anon";
GRANT ALL ON TABLE "public"."customer_locations" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_locations" TO "service_role";



GRANT ALL ON TABLE "public"."daily_checkins" TO "anon";
GRANT ALL ON TABLE "public"."daily_checkins" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_checkins" TO "service_role";



GRANT ALL ON TABLE "public"."financial_accounts" TO "anon";
GRANT ALL ON TABLE "public"."financial_accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."financial_accounts" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_entries" TO "anon";
GRANT ALL ON TABLE "public"."inventory_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_entries" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_entry_items" TO "anon";
GRANT ALL ON TABLE "public"."inventory_entry_items" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_entry_items" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_exit_items" TO "anon";
GRANT ALL ON TABLE "public"."inventory_exit_items" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_exit_items" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_exits" TO "anon";
GRANT ALL ON TABLE "public"."inventory_exits" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_exits" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_movements" TO "anon";
GRANT ALL ON TABLE "public"."inventory_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_movements" TO "service_role";



GRANT ALL ON TABLE "public"."order_items" TO "anon";
GRANT ALL ON TABLE "public"."order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."order_items" TO "service_role";



GRANT ALL ON TABLE "public"."partner_credit_summary" TO "anon";
GRANT ALL ON TABLE "public"."partner_credit_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."partner_credit_summary" TO "service_role";



GRANT ALL ON TABLE "public"."physical_inventories" TO "anon";
GRANT ALL ON TABLE "public"."physical_inventories" TO "authenticated";
GRANT ALL ON TABLE "public"."physical_inventories" TO "service_role";



GRANT ALL ON TABLE "public"."physical_inventory_items" TO "anon";
GRANT ALL ON TABLE "public"."physical_inventory_items" TO "authenticated";
GRANT ALL ON TABLE "public"."physical_inventory_items" TO "service_role";



GRANT ALL ON TABLE "public"."product_active_ingredients" TO "anon";
GRANT ALL ON TABLE "public"."product_active_ingredients" TO "authenticated";
GRANT ALL ON TABLE "public"."product_active_ingredients" TO "service_role";



GRANT ALL ON TABLE "public"."product_images" TO "anon";
GRANT ALL ON TABLE "public"."product_images" TO "authenticated";
GRANT ALL ON TABLE "public"."product_images" TO "service_role";



GRANT ALL ON TABLE "public"."product_reviews" TO "anon";
GRANT ALL ON TABLE "public"."product_reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."product_reviews" TO "service_role";



GRANT ALL ON TABLE "public"."product_variants" TO "anon";
GRANT ALL ON TABLE "public"."product_variants" TO "authenticated";
GRANT ALL ON TABLE "public"."product_variants" TO "service_role";



GRANT ALL ON TABLE "public"."warehouse_stock_batches" TO "anon";
GRANT ALL ON TABLE "public"."warehouse_stock_batches" TO "authenticated";
GRANT ALL ON TABLE "public"."warehouse_stock_batches" TO "service_role";



GRANT ALL ON TABLE "public"."product_stock_summary" TO "anon";
GRANT ALL ON TABLE "public"."product_stock_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."product_stock_summary" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."profiles_with_email" TO "anon";
GRANT ALL ON TABLE "public"."profiles_with_email" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_with_email" TO "service_role";



GRANT ALL ON TABLE "public"."purchase_order_items" TO "anon";
GRANT ALL ON TABLE "public"."purchase_order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."purchase_order_items" TO "service_role";



GRANT ALL ON TABLE "public"."purchase_orders" TO "anon";
GRANT ALL ON TABLE "public"."purchase_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."purchase_orders" TO "service_role";



GRANT ALL ON TABLE "public"."shopping_carts" TO "anon";
GRANT ALL ON TABLE "public"."shopping_carts" TO "authenticated";
GRANT ALL ON TABLE "public"."shopping_carts" TO "service_role";



GRANT ALL ON TABLE "public"."supplier_credit_movements" TO "anon";
GRANT ALL ON TABLE "public"."supplier_credit_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."supplier_credit_movements" TO "service_role";



GRANT ALL ON TABLE "public"."supplier_credits" TO "anon";
GRANT ALL ON TABLE "public"."supplier_credits" TO "authenticated";
GRANT ALL ON TABLE "public"."supplier_credits" TO "service_role";



GRANT ALL ON TABLE "public"."suppliers" TO "anon";
GRANT ALL ON TABLE "public"."suppliers" TO "authenticated";
GRANT ALL ON TABLE "public"."suppliers" TO "service_role";



GRANT ALL ON TABLE "public"."variant_attribute_values" TO "anon";
GRANT ALL ON TABLE "public"."variant_attribute_values" TO "authenticated";
GRANT ALL ON TABLE "public"."variant_attribute_values" TO "service_role";



GRANT ALL ON TABLE "public"."wallet_movements" TO "anon";
GRANT ALL ON TABLE "public"."wallet_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."wallet_movements" TO "service_role";



GRANT ALL ON TABLE "public"."warehouses" TO "anon";
GRANT ALL ON TABLE "public"."warehouses" TO "authenticated";
GRANT ALL ON TABLE "public"."warehouses" TO "service_role";



GRANT ALL ON TABLE "public"."wishlist" TO "anon";
GRANT ALL ON TABLE "public"."wishlist" TO "authenticated";
GRANT ALL ON TABLE "public"."wishlist" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































