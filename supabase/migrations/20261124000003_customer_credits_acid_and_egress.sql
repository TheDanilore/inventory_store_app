-- ============================================================================
-- MIGRACIÓN: BLINDAJE ACID, RBAC, IDEMPOTENCIA Y SINGLE-RTT PARA CRÉDITOS CLIENTES
-- Fecha: 2026-11-24
-- ============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 1. Constraints e índices de rendimiento
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'customer_credits_credit_limit_check'
          AND conrelid = 'public.customer_credits'::regclass
    ) THEN
        ALTER TABLE public.customer_credits
            ADD CONSTRAINT customer_credits_credit_limit_check CHECK (credit_limit >= 0);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_customer_credits_debt_id
    ON public.customer_credits (current_debt DESC, id ASC);

CREATE INDEX IF NOT EXISTS idx_customer_credits_active_debt
    ON public.customer_credits (is_active, current_debt DESC, id ASC);

CREATE INDEX IF NOT EXISTS idx_customer_credits_customer_record_id
    ON public.customer_credits (customer_record_id);

CREATE INDEX IF NOT EXISTS idx_customer_credit_movements_credit_created
    ON public.customer_credit_movements (customer_credit_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_customers_full_name_trgm
    ON public.customers USING gin (full_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_customers_document_number_trgm
    ON public.customers USING gin (document_number gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_customers_phone_trgm
    ON public.customers USING gin (phone gin_trgm_ops);

-- 2. Tabla de idempotencia para pagos de crédito (previene doble cobro)
CREATE TABLE IF NOT EXISTS public.customer_credit_payment_idempotency (
    idempotency_key uuid PRIMARY KEY,
    credit_id uuid NOT NULL,
    response jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON TABLE public.customer_credit_payment_idempotency FROM PUBLIC, anon, authenticated;

-- 3. Principio de mínimo privilegio: revocar acceso anónimo directo sobre tablas/vistas
-- (Los privilegios de las RPC se revocan y reasignan tras cada CREATE OR REPLACE)
REVOKE ALL ON TABLE public.customer_credits FROM anon;
REVOKE ALL ON TABLE public.customer_credit_movements FROM anon;
DO $$
BEGIN
    IF to_regclass('public.customer_credit_movements_summary') IS NOT NULL THEN
        REVOKE ALL ON TABLE public.customer_credit_movements_summary FROM anon;
    END IF;
END $$;

-- 4. RPC Single-RTT: Página de créditos + cliente canónico + KPIs globales
CREATE OR REPLACE FUNCTION public.get_customer_credits_page_rpc(
    p_search_query text DEFAULT ''::text,
    p_with_debt_only boolean DEFAULT false,
    p_limit integer DEFAULT 15,
    p_offset integer DEFAULT 0,
    p_include_stats boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_q text := trim(coalesce(p_search_query, ''));
    v_limit integer := LEAST(GREATEST(coalesce(p_limit, 15), 1), 100);
    v_offset integer := GREATEST(coalesce(p_offset, 0), 0);
    v_only_debt boolean := coalesce(p_with_debt_only, false);
    v_items jsonb := '[]'::jsonb;
    v_total_count bigint := 0;
    v_stats jsonb := NULL;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('credits.manage'::text)
        OR public.user_has_permission('reports.financial'::text)
        OR public.user_has_permission('pos.sale'::text)
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para consultar créditos de clientes.' USING ERRCODE = '42501';
    END IF;

    WITH resolved AS (
        SELECT
            cc.id,
            coalesce(cc.customer_record_id, c.id) AS customer_record_id,
            cc.profile_id,
            cc.credit_limit,
            cc.current_debt,
            cc.is_active,
            cc.created_at,
            cc.updated_at,
            coalesce(c.full_name, p.full_name, 'Cliente desconocido') AS customer_name,
            coalesce(c.document_number, p.document_number) AS customer_document,
            coalesce(c.document_type, p.document_type) AS customer_document_type,
            coalesce(c.phone, p.phone) AS customer_phone
        FROM public.customer_credits cc
        LEFT JOIN public.customers c
          ON c.id = cc.customer_record_id
          OR (cc.customer_record_id IS NULL AND cc.profile_id IS NOT NULL AND c.profile_id = cc.profile_id)
        LEFT JOIN public.profiles p
          ON p.id = cc.profile_id
        WHERE (c.id IS NOT NULL OR p.id IS NOT NULL)
    ),
    searched AS (
        SELECT *
        FROM resolved r
        WHERE v_q = ''
           OR r.customer_name ILIKE '%' || v_q || '%'
           OR coalesce(r.customer_document, '') ILIKE '%' || v_q || '%'
           OR coalesce(r.customer_phone, '') ILIKE '%' || v_q || '%'
    ),
    filtered AS (
        SELECT *
        FROM searched s
        WHERE (NOT v_only_debt OR s.current_debt > 0)
    ),
    paged AS (
        SELECT
            f.*,
            COUNT(*) OVER() AS total_count
        FROM filtered f
        ORDER BY f.current_debt DESC, f.id ASC
        LIMIT v_limit
        OFFSET v_offset
    )
    SELECT
        coalesce(
            jsonb_agg(
                jsonb_build_object(
                    'id', pg.id,
                    'customer_record_id', pg.customer_record_id,
                    'profile_id', pg.profile_id,
                    'credit_limit', pg.credit_limit,
                    'current_debt', pg.current_debt,
                    'is_active', pg.is_active,
                    'created_at', pg.created_at,
                    'updated_at', pg.updated_at,
                    'customer_name', pg.customer_name,
                    'customer_document', pg.customer_document,
                    'customer_document_type', pg.customer_document_type,
                    'customer_phone', pg.customer_phone
                )
                ORDER BY pg.current_debt DESC, pg.id ASC
            ),
            '[]'::jsonb
        ),
        coalesce(MAX(pg.total_count), 0)
    INTO v_items, v_total_count
    FROM paged pg;

    IF v_total_count = 0 AND v_offset > 0 THEN
        SELECT COUNT(*)
        INTO v_total_count
        FROM public.customer_credits cc
        LEFT JOIN public.customers c
          ON c.id = cc.customer_record_id
          OR (cc.customer_record_id IS NULL AND cc.profile_id IS NOT NULL AND c.profile_id = cc.profile_id)
        LEFT JOIN public.profiles p
          ON p.id = cc.profile_id
        WHERE (c.id IS NOT NULL OR p.id IS NOT NULL)
          AND (
              v_q = ''
              OR coalesce(c.full_name, p.full_name, '') ILIKE '%' || v_q || '%'
              OR coalesce(c.document_number, p.document_number, '') ILIKE '%' || v_q || '%'
              OR coalesce(c.phone, p.phone, '') ILIKE '%' || v_q || '%'
          )
          AND (NOT v_only_debt OR cc.current_debt > 0);
    END IF;

    IF p_include_stats THEN
        SELECT jsonb_build_object(
            'totalDebt', coalesce(SUM(cc.current_debt), 0),
            'activeAccounts', COUNT(*) FILTER (WHERE cc.is_active = true),
            'suspendedAccounts', COUNT(*) FILTER (WHERE cc.is_active = false),
            'maxedOutAccounts', COUNT(*) FILTER (
                WHERE cc.is_active = true
                  AND cc.credit_limit > 0
                  AND cc.current_debt >= cc.credit_limit
            ),
            'debtCount', COUNT(*) FILTER (
                WHERE cc.is_active = true
                  AND cc.current_debt > 0
            )
        )
        INTO v_stats
        FROM public.customer_credits cc
        LEFT JOIN public.customers c
          ON c.id = cc.customer_record_id
          OR (cc.customer_record_id IS NULL AND cc.profile_id IS NOT NULL AND c.profile_id = cc.profile_id)
        LEFT JOIN public.profiles p
          ON p.id = cc.profile_id
        WHERE (c.id IS NOT NULL OR p.id IS NOT NULL)
          AND (
              v_q = ''
              OR coalesce(c.full_name, p.full_name, '') ILIKE '%' || v_q || '%'
              OR coalesce(c.document_number, p.document_number, '') ILIKE '%' || v_q || '%'
              OR coalesce(c.phone, p.phone, '') ILIKE '%' || v_q || '%'
          );
    END IF;

    RETURN jsonb_build_object(
        'items', v_items,
        'totalCount', v_total_count,
        'stats', v_stats
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_credits_page_rpc(text, boolean, integer, integer, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_credits_page_rpc(text, boolean, integer, integer, boolean) TO authenticated, service_role;

-- 5. Estadísticas globales blindadas sobre public.customers (+ profiles fallback)
CREATE OR REPLACE FUNCTION public.get_customer_credits_stats_rpc(
    p_search_query text DEFAULT ''::text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_q text := trim(coalesce(p_search_query, ''));
    v_result jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('credits.manage'::text)
        OR public.user_has_permission('reports.financial'::text)
        OR public.user_has_permission('pos.sale'::text)
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para consultar estadísticas de créditos.' USING ERRCODE = '42501';
    END IF;

    SELECT jsonb_build_object(
        'totalDebt', coalesce(SUM(cc.current_debt), 0),
        'activeAccounts', COUNT(*) FILTER (WHERE cc.is_active = true),
        'suspendedAccounts', COUNT(*) FILTER (WHERE cc.is_active = false),
        'maxedOutAccounts', COUNT(*) FILTER (
            WHERE cc.is_active = true
              AND cc.credit_limit > 0
              AND cc.current_debt >= cc.credit_limit
        ),
        'debtCount', COUNT(*) FILTER (
            WHERE cc.is_active = true
              AND cc.current_debt > 0
        )
    )
    INTO v_result
    FROM public.customer_credits cc
    LEFT JOIN public.customers c
      ON c.id = cc.customer_record_id
      OR (cc.customer_record_id IS NULL AND cc.profile_id IS NOT NULL AND c.profile_id = cc.profile_id)
    LEFT JOIN public.profiles p
      ON p.id = cc.profile_id
    WHERE (c.id IS NOT NULL OR p.id IS NOT NULL)
      AND (
          v_q = ''
          OR coalesce(c.full_name, p.full_name, '') ILIKE '%' || v_q || '%'
          OR coalesce(c.document_number, p.document_number, '') ILIKE '%' || v_q || '%'
          OR coalesce(c.phone, p.phone, '') ILIKE '%' || v_q || '%'
      );

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_credits_stats_rpc(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_credits_stats_rpc(text) TO authenticated, service_role;

-- 6. Búsqueda ligera de clientes elegibles para nueva línea de crédito
CREATE OR REPLACE FUNCTION public.search_customers_without_credit_rpc(
    p_query text DEFAULT ''::text,
    p_limit integer DEFAULT 8
) RETURNS TABLE(
    id uuid,
    full_name text,
    document_number text,
    document_type text,
    phone text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_q text := trim(coalesce(p_query, ''));
    v_limit integer := LEAST(GREATEST(coalesce(p_limit, 8), 1), 25);
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('credits.manage'::text)
        OR public.user_has_permission('pos.sale'::text)
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para buscar clientes.' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.full_name,
        c.document_number,
        c.document_type,
        c.phone
    FROM public.customers c
    WHERE c.is_active = true
      AND (
          v_q = ''
          OR c.full_name ILIKE '%' || v_q || '%'
          OR coalesce(c.document_number, '') ILIKE '%' || v_q || '%'
          OR coalesce(c.phone, '') ILIKE '%' || v_q || '%'
      )
      AND NOT EXISTS (
          SELECT 1
          FROM public.customer_credits cc
          WHERE (
              cc.customer_record_id = c.id
              OR (c.profile_id IS NOT NULL AND cc.profile_id = c.profile_id)
          )
          AND cc.is_active = true
      )
    ORDER BY c.full_name ASC
    LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.search_customers_without_credit_rpc(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_customers_without_credit_rpc(text, integer) TO authenticated, service_role;

-- 7. RPCs atómicos de gestión de cuentas de crédito (FOR UPDATE + reglas ACID)
CREATE OR REPLACE FUNCTION public.rpc_create_customer_credit(
    p_customer_id uuid,
    p_credit_limit numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_actor_id uuid;
    v_cust public.customers%ROWTYPE;
    v_existing public.customer_credits%ROWTYPE;
    v_credit_id uuid;
    v_limit numeric(14,2) := coalesce(p_credit_limit, 0.00);
    v_profile_name text;
    v_profile_doc text;
    v_profile_doc_type text;
    v_profile_phone text;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('credits.manage'::text)
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para aprobar líneas de crédito.' USING ERRCODE = '42501';
    END IF;

    IF v_limit < 0 THEN
        RAISE EXCEPTION 'El límite de crédito no puede ser negativo.' USING ERRCODE = 'P0001';
    END IF;

    SELECT id INTO v_actor_id
    FROM public.profiles
    WHERE auth_user_id = auth.uid()
    LIMIT 1;

    SELECT * INTO v_cust
    FROM public.customers
    WHERE id = p_customer_id OR profile_id = p_customer_id
    ORDER BY (id = p_customer_id) DESC
    LIMIT 1;

    IF v_cust.id IS NULL THEN
        SELECT full_name, document_number, document_type, phone
        INTO v_profile_name, v_profile_doc, v_profile_doc_type, v_profile_phone
        FROM public.profiles
        WHERE id = p_customer_id
        LIMIT 1;

        IF v_profile_name IS NULL THEN
            RAISE EXCEPTION 'Cliente no encontrado.' USING ERRCODE = 'P0002';
        END IF;
    END IF;

    SELECT * INTO v_existing
    FROM public.customer_credits cc
    WHERE (v_cust.id IS NOT NULL AND cc.customer_record_id = v_cust.id)
       OR (v_cust.profile_id IS NOT NULL AND cc.profile_id = v_cust.profile_id)
       OR cc.profile_id = p_customer_id
    LIMIT 1
    FOR UPDATE;

    IF v_existing.id IS NOT NULL THEN
        IF v_limit > 0 AND v_limit < v_existing.current_debt THEN
            RAISE EXCEPTION 'El límite de crédito (S/ %) no puede ser menor a la deuda actual (S/ %).', v_limit, v_existing.current_debt
                USING ERRCODE = 'P0001';
        END IF;

        UPDATE public.customer_credits
        SET
            customer_record_id = coalesce(customer_record_id, v_cust.id),
            profile_id = coalesce(profile_id, v_cust.profile_id),
            credit_limit = v_limit,
            is_active = true,
            updated_at = now()
        WHERE id = v_existing.id
        RETURNING * INTO v_existing;

        v_credit_id := v_existing.id;
    ELSE
        INSERT INTO public.customer_credits (
            customer_record_id,
            profile_id,
            credit_limit,
            current_debt,
            is_active,
            created_by,
            updated_at
        ) VALUES (
            v_cust.id,
            coalesce(v_cust.profile_id, CASE WHEN v_cust.id IS NULL THEN p_customer_id ELSE NULL END),
            v_limit,
            0.00,
            true,
            v_actor_id,
            now()
        )
        RETURNING * INTO v_existing;

        v_credit_id := v_existing.id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'account', jsonb_build_object(
            'id', v_existing.id,
            'customer_record_id', v_existing.customer_record_id,
            'profile_id', v_existing.profile_id,
            'credit_limit', v_existing.credit_limit,
            'current_debt', v_existing.current_debt,
            'is_active', v_existing.is_active,
            'created_at', v_existing.created_at,
            'updated_at', v_existing.updated_at,
            'customer_name', coalesce(v_cust.full_name, v_profile_name, 'Cliente desconocido'),
            'customer_document', coalesce(v_cust.document_number, v_profile_doc),
            'customer_document_type', coalesce(v_cust.document_type, v_profile_doc_type),
            'customer_phone', coalesce(v_cust.phone, v_profile_phone)
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_create_customer_credit(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_customer_credit(uuid, numeric) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_update_customer_credit_limit(
    p_credit_id uuid,
    p_credit_limit numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_row public.customer_credits%ROWTYPE;
    v_cust public.customers%ROWTYPE;
    v_profile public.profiles%ROWTYPE;
    v_limit numeric(14,2) := coalesce(p_credit_limit, 0.00);
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('credits.manage'::text)
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para modificar límites de crédito.' USING ERRCODE = '42501';
    END IF;

    IF v_limit < 0 THEN
        RAISE EXCEPTION 'El límite de crédito no puede ser negativo.' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_row
    FROM public.customer_credits
    WHERE id = p_credit_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuenta de crédito no encontrada.' USING ERRCODE = 'P0002';
    END IF;

    IF v_limit > 0 AND v_limit < v_row.current_debt THEN
        RAISE EXCEPTION 'El nuevo límite (S/ %) no puede ser menor a la deuda actual (S/ %).', v_limit, v_row.current_debt
            USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.customer_credits
    SET
        credit_limit = v_limit,
        updated_at = now()
    WHERE id = p_credit_id
    RETURNING * INTO v_row;

    SELECT * INTO v_cust FROM public.customers WHERE id = v_row.customer_record_id LIMIT 1;
    IF v_row.profile_id IS NOT NULL THEN
        SELECT * INTO v_profile FROM public.profiles WHERE id = v_row.profile_id LIMIT 1;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'account', jsonb_build_object(
            'id', v_row.id,
            'customer_record_id', v_row.customer_record_id,
            'profile_id', v_row.profile_id,
            'credit_limit', v_row.credit_limit,
            'current_debt', v_row.current_debt,
            'is_active', v_row.is_active,
            'created_at', v_row.created_at,
            'updated_at', v_row.updated_at,
            'customer_name', coalesce(v_cust.full_name, v_profile.full_name, 'Cliente desconocido'),
            'customer_document', coalesce(v_cust.document_number, v_profile.document_number),
            'customer_document_type', coalesce(v_cust.document_type, v_profile.document_type),
            'customer_phone', coalesce(v_cust.phone, v_profile.phone)
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_update_customer_credit_limit(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_update_customer_credit_limit(uuid, numeric) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_toggle_customer_credit_status(
    p_credit_id uuid,
    p_is_active boolean
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_row public.customer_credits%ROWTYPE;
    v_cust public.customers%ROWTYPE;
    v_profile public.profiles%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('credits.manage'::text)
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para suspender o reactivar líneas de crédito.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_row
    FROM public.customer_credits
    WHERE id = p_credit_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuenta de crédito no encontrada.' USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.customer_credits
    SET
        is_active = p_is_active,
        updated_at = now()
    WHERE id = p_credit_id
    RETURNING * INTO v_row;

    SELECT * INTO v_cust FROM public.customers WHERE id = v_row.customer_record_id LIMIT 1;
    IF v_row.profile_id IS NOT NULL THEN
        SELECT * INTO v_profile FROM public.profiles WHERE id = v_row.profile_id LIMIT 1;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'account', jsonb_build_object(
            'id', v_row.id,
            'customer_record_id', v_row.customer_record_id,
            'profile_id', v_row.profile_id,
            'credit_limit', v_row.credit_limit,
            'current_debt', v_row.current_debt,
            'is_active', v_row.is_active,
            'created_at', v_row.created_at,
            'updated_at', v_row.updated_at,
            'customer_name', coalesce(v_cust.full_name, v_profile.full_name, 'Cliente desconocido'),
            'customer_document', coalesce(v_cust.document_number, v_profile.document_number),
            'customer_document_type', coalesce(v_cust.document_type, v_profile.document_type),
            'customer_phone', coalesce(v_cust.phone, v_profile.phone)
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_toggle_customer_credit_status(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_toggle_customer_credit_status(uuid, boolean) TO authenticated, service_role;

-- 8. Endurecimiento de get_credit_movements_totals_rpc (RBAC + search_path)
CREATE OR REPLACE FUNCTION public.get_credit_movements_totals_rpc(
    p_credit_id uuid,
    p_date_filter text DEFAULT NULL::text
) RETURNS TABLE(
    total_charged numeric,
    total_paid numeric,
    charge_count bigint,
    payment_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_start_date timestamptz := NULL;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('credits.manage'::text)
        OR public.user_has_permission('reports.financial'::text)
        OR public.user_has_permission('pos.sale'::text)
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para consultar totales de movimientos.' USING ERRCODE = '42501';
    END IF;

    IF p_date_filter = '30_days' THEN
        v_start_date := now() - interval '30 days';
    ELSIF p_date_filter = 'this_month' THEN
        v_start_date := date_trunc('month', now());
    END IF;

    RETURN QUERY
    SELECT
        coalesce(SUM(amount) FILTER (WHERE movement_type = 'CHARGE'), 0) AS total_charged,
        coalesce(SUM(amount) FILTER (WHERE movement_type != 'CHARGE'), 0) AS total_paid,
        COUNT(*) FILTER (WHERE movement_type = 'CHARGE') AS charge_count,
        COUNT(*) FILTER (WHERE movement_type != 'CHARGE') AS payment_count
    FROM public.customer_credit_movements
    WHERE customer_credit_id = p_credit_id
      AND (v_start_date IS NULL OR created_at >= v_start_date);
END;
$$;

REVOKE ALL ON FUNCTION public.get_credit_movements_totals_rpc(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_credit_movements_totals_rpc(uuid, text) TO authenticated, service_role;

-- 9. Hardening ACID de register_credit_payment_rpc (Idempotencia + Lock Ordering + RBAC)
DROP FUNCTION IF EXISTS public.register_credit_payment_rpc(uuid, uuid, numeric, uuid, uuid, text, uuid);

CREATE OR REPLACE FUNCTION public.register_credit_payment_rpc(
    p_customer_id uuid,
    p_credit_id uuid,
    p_amount numeric,
    p_account_id uuid,
    p_order_id uuid DEFAULT NULL,
    p_notes text DEFAULT 'Abono registrado a crédito',
    p_shift_id uuid DEFAULT NULL,
    p_idempotency_key uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_remaining        NUMERIC := p_amount;
    v_order            RECORD;
    v_pending_of_order NUMERIC;
    v_to_apply         NUMERIC;
    v_new_paid         NUMERIC;
    v_new_status       TEXT;
    v_points_earned    INT;
    v_account          RECORD;
    v_shift_status     TEXT;
    v_current_debt     NUMERIC;
    v_new_debt         NUMERIC;
    v_now              TIMESTAMPTZ;
    v_created_by       UUID;
    v_customer_record_id UUID;
    v_customer_profile_id UUID;
    v_existing_resp    JSONB;
    v_result           JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No autenticado.', 'detail', '42501');
    END IF;

    IF NOT (
        public.user_has_permission('credits.manage'::text)
        OR public.user_has_permission('pos.sale'::text)
        OR public.is_admin()
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'No tienes permisos para registrar abonos de crédito.', 'detail', '42501');
    END IF;

    -- 1. Verificación idempotente antes de mutar cualquier registro
    IF p_idempotency_key IS NOT NULL THEN
        SELECT response INTO v_existing_resp
        FROM public.customer_credit_payment_idempotency
        WHERE idempotency_key = p_idempotency_key;

        IF FOUND THEN
            RETURN v_existing_resp;
        END IF;
    END IF;

    v_now := NOW() AT TIME ZONE 'America/Lima';

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'El monto debe ser mayor a 0.', 'detail', 'P0001');
    END IF;

    IF p_credit_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Identificador de línea de crédito obligatorio.', 'detail', 'P0001');
    END IF;

    SELECT id INTO v_created_by
      FROM public.profiles
     WHERE auth_user_id = auth.uid() OR id = auth.uid()
     LIMIT 1;

    -- 2. Lock pesimista TEMPRANO sobre customer_credits (previene race conditions multi-caja)
    SELECT current_debt, customer_record_id, profile_id
      INTO v_current_debt, v_customer_record_id, v_customer_profile_id
      FROM public.customer_credits
     WHERE id = p_credit_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Línea de crédito no encontrada.', 'detail', 'P0002');
    END IF;

    IF p_amount > v_current_debt THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'El monto (S/ ' || p_amount || ') sobrepasa la deuda pendiente (S/ ' || v_current_debt || ').',
            'detail', 'P0001'
        );
    END IF;

    -- Resolver cliente si faltase en customer_credits
    IF v_customer_record_id IS NULL THEN
        SELECT id, coalesce(v_customer_profile_id, profile_id)
          INTO v_customer_record_id, v_customer_profile_id
          FROM public.customers
         WHERE id = p_customer_id OR profile_id = p_customer_id
         LIMIT 1;
    END IF;

    IF v_customer_record_id IS NULL AND v_customer_profile_id IS NULL THEN
        v_customer_profile_id := p_customer_id;
    END IF;

    -- 3. Lock pesimista sobre financial_accounts y validación de turno de caja
    SELECT type, name INTO v_account
      FROM public.financial_accounts
     WHERE id = p_account_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cuenta financiera no encontrada.', 'detail', 'P0002');
    END IF;

    IF v_account.type = 'CAJA' THEN
        IF p_shift_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'El pago es por Caja pero no se proporcionó un turno de caja.', 'detail', 'P0001');
        END IF;

        SELECT status INTO v_shift_status
          FROM public.cash_shifts
         WHERE id = p_shift_id
         FOR UPDATE;

        IF NOT FOUND OR v_shift_status != 'OPEN' THEN
            RETURN jsonb_build_object('success', false, 'error', 'El turno de caja está cerrado o no existe.', 'detail', 'P0001');
        END IF;
    END IF;

    -- 4. Aplicar abono FIFO a órdenes pendientes con FOR UPDATE
    FOR v_order IN
        SELECT id, total_amount, amount_paid, payment_status
          FROM public.orders
         WHERE (
                (v_customer_record_id IS NOT NULL AND customer_record_id = v_customer_record_id)
                OR (v_customer_profile_id IS NOT NULL AND customer_id = v_customer_profile_id)
               )
           AND (p_order_id IS NULL OR id = p_order_id)
           AND payment_status IN ('PENDING', 'PARTIAL')
           AND status = 'COMPLETED'
         ORDER BY created_at ASC
         FOR UPDATE
    LOOP
        EXIT WHEN v_remaining <= 0;

        v_pending_of_order := GREATEST(0, (v_order.total_amount - v_order.amount_paid));
        v_to_apply         := LEAST(v_remaining, v_pending_of_order);
        v_new_paid         := v_order.amount_paid + v_to_apply;
        v_remaining        := v_remaining - v_to_apply;

        IF v_new_paid >= v_order.total_amount THEN
            v_new_status    := 'PAID';
            v_points_earned := FLOOR(v_order.total_amount * 0.03 / 0.01);
        ELSE
            v_new_status    := 'PARTIAL';
            v_points_earned := 0;
        END IF;

        UPDATE public.orders
           SET amount_paid   = v_new_paid,
               payment_status = v_new_status,
               points_earned  = CASE WHEN v_points_earned > 0 THEN v_points_earned ELSE points_earned END,
               updated_at    = v_now
         WHERE id = v_order.id;

        IF v_to_apply > 0 THEN
            INSERT INTO public.customer_credit_movements (
                customer_credit_id, order_id, movement_type, amount, payment_method, notes, created_by, created_at
            ) VALUES (
                p_credit_id, v_order.id, 'PAYMENT', v_to_apply, v_account.name, p_notes, v_created_by, v_now
            );

            INSERT INTO public.account_movements (
                account_id, movement_type, amount, description, reference_type, reference_id, shift_id, created_by, created_at
            ) VALUES (
                p_account_id, 'INCOME', v_to_apply,
                'Cobro de crédito — Pedido #' || UPPER(SUBSTRING(v_order.id::text, 1, 8)),
                'orders', v_order.id, p_shift_id, v_created_by, v_now
            );

            UPDATE public.financial_accounts
               SET balance = balance + v_to_apply
             WHERE id = p_account_id;
        END IF;

        IF v_points_earned > 0 THEN
            IF v_customer_record_id IS NOT NULL THEN
                UPDATE public.customers
                   SET wallet_balance = wallet_balance + v_points_earned
                 WHERE id = v_customer_record_id;
            END IF;

            IF v_customer_profile_id IS NOT NULL THEN
                UPDATE public.profiles
                   SET wallet_balance = COALESCE(wallet_balance, 0) + v_points_earned
                 WHERE id = v_customer_profile_id;
            END IF;

            INSERT INTO public.wallet_movements (
                profile_id, customer_id, order_id, points, movement_type, description, created_at
            ) VALUES (
                v_customer_profile_id, v_customer_record_id, v_order.id, v_points_earned,
                'EARNED', 'Monedas ganadas al saldar pedido a crédito', v_now
            );
        END IF;
    END LOOP;

    IF v_remaining > 0 THEN
        INSERT INTO public.account_movements (
            account_id, movement_type, amount, description, reference_type, reference_id, shift_id, created_by, created_at
        ) VALUES (
            p_account_id, 'INCOME', v_remaining,
            COALESCE(p_notes, 'Abono registrado a cuenta de crédito'),
            'customer_credits', p_credit_id, p_shift_id, v_created_by, v_now
        );

        UPDATE public.financial_accounts
           SET balance = balance + v_remaining
         WHERE id = p_account_id;

        INSERT INTO public.customer_credit_movements (
            customer_credit_id, order_id, movement_type, amount, payment_method, notes, created_by, created_at
        ) VALUES (
            p_credit_id, NULL, 'PAYMENT', v_remaining, v_account.name, p_notes, v_created_by, v_now
        );
    END IF;

    v_new_debt := GREATEST(0, v_current_debt - p_amount);

    UPDATE public.customer_credits
       SET current_debt = v_new_debt,
           updated_at   = v_now
     WHERE id = p_credit_id;

    v_result := jsonb_build_object(
        'success', true,
        'amount_paid', p_amount,
        'new_debt', v_new_debt
    );

    IF p_idempotency_key IS NOT NULL THEN
        INSERT INTO public.customer_credit_payment_idempotency (idempotency_key, credit_id, response)
        VALUES (p_idempotency_key, p_credit_id, v_result)
        ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'detail', SQLSTATE
        );
END;
$$;

REVOKE ALL ON FUNCTION public.register_credit_payment_rpc(uuid, uuid, numeric, uuid, uuid, text, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_credit_payment_rpc(uuid, uuid, numeric, uuid, uuid, text, uuid, uuid) TO authenticated, service_role;

COMMIT;
