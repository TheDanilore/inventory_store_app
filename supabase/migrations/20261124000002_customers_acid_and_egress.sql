-- ============================================================================
-- MIGRACIÓN: BLINDAJE ACID, RBAC, ÍNDICES pg_trgm Y SINGLE-RTT PARA CLIENTES
-- Fecha: 2026-11-24
-- ============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 1. Índices de rendimiento y búsqueda multi-campo (pg_trgm + btree paginado)
CREATE INDEX IF NOT EXISTS idx_customers_created_id
    ON public.customers (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_customers_active_created
    ON public.customers (is_active, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_customers_full_name_trgm
    ON public.customers USING gin (full_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_customers_document_number_trgm
    ON public.customers USING gin (document_number gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_customers_phone_trgm
    ON public.customers USING gin (phone gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_orders_customer_record_completed
    ON public.orders (customer_record_id, created_at DESC)
    WHERE status = 'COMPLETED';

CREATE INDEX IF NOT EXISTS idx_customer_locations_customer_record
    ON public.customer_locations (customer_record_id);

CREATE INDEX IF NOT EXISTS idx_customer_credits_customer_record_debt
    ON public.customer_credits (customer_record_id)
    WHERE current_debt > 0;

-- 2. Principio de mínimo privilegio: revocar acceso anónimo directo sobre tabla
-- (Los privilegios de las RPC se revocan y reasignan tras cada CREATE OR REPLACE)
REVOKE ALL ON TABLE public.customers FROM anon;

-- 3. RPC Single-RTT: Página de clientes + Deuda + Agregados de órdenes/ubicaciones + Conteo
CREATE OR REPLACE FUNCTION public.get_customers_page_rpc(
    p_search_query text DEFAULT ''::text,
    p_only_with_debt boolean DEFAULT false,
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_q text := trim(coalesce(p_search_query, ''));
    v_limit integer := LEAST(GREATEST(coalesce(p_limit, 20), 1), 100);
    v_offset integer := GREATEST(coalesce(p_offset, 0), 0);
    v_only_debt boolean := coalesce(p_only_with_debt, false);
    v_items jsonb := '[]'::jsonb;
    v_total_count bigint := 0;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('customers.read'::text)
        OR public.user_has_permission('customers.manage'::text)
        OR public.user_has_permission('pos.sale'::text)
        OR public.user_has_permission('orders.read'::text)
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para consultar clientes.' USING ERRCODE = '42501';
    END IF;

    WITH filtered AS (
        SELECT
            c.id,
            c.profile_id,
            c.full_name,
            c.phone,
            c.document_number,
            c.document_type,
            c.avatar_url,
            c.wallet_balance,
            c.is_active,
            c.created_at,
            coalesce(cc.current_debt, 0)::numeric(14,2) AS current_debt,
            coalesce(cc.credit_limit, 0)::numeric(14,2) AS credit_limit
        FROM public.customers c
        LEFT JOIN LATERAL (
            SELECT
                cred.current_debt,
                cred.credit_limit
            FROM public.customer_credits cred
            WHERE cred.customer_record_id = c.id
               OR (c.profile_id IS NOT NULL AND cred.profile_id = c.profile_id)
            ORDER BY (cred.customer_record_id = c.id) DESC
            LIMIT 1
        ) cc ON true
        WHERE (
            v_q = ''
            OR c.full_name ILIKE '%' || v_q || '%'
            OR coalesce(c.document_number, '') ILIKE '%' || v_q || '%'
            OR coalesce(c.phone, '') ILIKE '%' || v_q || '%'
        )
        AND (NOT v_only_debt OR coalesce(cc.current_debt, 0) > 0)
    ),
    paged AS (
        SELECT
            f.*,
            COUNT(*) OVER() AS total_count
        FROM filtered f
        ORDER BY f.created_at DESC, f.id DESC
        LIMIT v_limit
        OFFSET v_offset
    ),
    enriched AS (
        SELECT
            p.*,
            coalesce(ord.total_revenue, 0)::numeric(14,2) AS total_revenue,
            coalesce(ord.order_count, 0)::bigint AS order_count,
            ord.last_order_at,
            coalesce(loc.locations_count, 0)::bigint AS locations_count
        FROM paged p
        LEFT JOIN LATERAL (
            SELECT
                coalesce(SUM(o.total_amount), 0) AS total_revenue,
                COUNT(o.id) AS order_count,
                MAX(o.created_at) AS last_order_at
            FROM public.orders o
            WHERE o.status = 'COMPLETED'
              AND (
                  o.customer_record_id = p.id
                  OR (p.profile_id IS NOT NULL AND o.customer_id = p.profile_id)
              )
        ) ord ON true
        LEFT JOIN LATERAL (
            SELECT COUNT(cl.id) AS locations_count
            FROM public.customer_locations cl
            WHERE cl.customer_record_id = p.id
               OR (p.profile_id IS NOT NULL AND cl.profile_id = p.profile_id)
        ) loc ON true
    )
    SELECT
        coalesce(
            jsonb_agg(
                jsonb_build_object(
                    'id', e.id,
                    'full_name', e.full_name,
                    'phone', e.phone,
                    'document_number', e.document_number,
                    'document_type', e.document_type,
                    'avatar_url', e.avatar_url,
                    'wallet_balance', e.wallet_balance,
                    'is_active', e.is_active,
                    'created_at', e.created_at,
                    'current_debt', e.current_debt,
                    'credit_limit', e.credit_limit,
                    'total_revenue', e.total_revenue,
                    'order_count', e.order_count,
                    'last_order_at', e.last_order_at,
                    'locations_count', e.locations_count
                )
                ORDER BY e.created_at DESC, e.id DESC
            ),
            '[]'::jsonb
        ),
        coalesce(MAX(e.total_count), 0)
    INTO v_items, v_total_count
    FROM enriched e;

    IF v_total_count = 0 AND v_offset > 0 THEN
        SELECT COUNT(*)
        INTO v_total_count
        FROM public.customers c
        LEFT JOIN LATERAL (
            SELECT cred.current_debt
            FROM public.customer_credits cred
            WHERE cred.customer_record_id = c.id
               OR (c.profile_id IS NOT NULL AND cred.profile_id = c.profile_id)
            ORDER BY (cred.customer_record_id = c.id) DESC
            LIMIT 1
        ) cc ON true
        WHERE (
            v_q = ''
            OR c.full_name ILIKE '%' || v_q || '%'
            OR coalesce(c.document_number, '') ILIKE '%' || v_q || '%'
            OR coalesce(c.phone, '') ILIKE '%' || v_q || '%'
        )
        AND (NOT v_only_debt OR coalesce(cc.current_debt, 0) > 0);
    END IF;

    RETURN jsonb_build_object(
        'items', v_items,
        'totalCount', v_total_count
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_customers_page_rpc(text, boolean, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customers_page_rpc(text, boolean, integer, integer) TO authenticated, service_role;

-- 4. RPC de estadísticas globales blindada con Auth + RBAC + saldo de billetera
CREATE OR REPLACE FUNCTION public.get_customers_global_stats_rpc()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_total int;
    v_active int;
    v_inactive int;
    v_total_wallet numeric;
    v_total_revenue numeric;
    v_total_debt numeric;
    v_debt_count int;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('customers.read'::text)
        OR public.user_has_permission('customers.manage'::text)
        OR public.user_has_permission('pos.sale'::text)
        OR public.user_has_permission('orders.read'::text)
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para consultar estadísticas de clientes.' USING ERRCODE = '42501';
    END IF;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE is_active = true),
        COUNT(*) FILTER (WHERE is_active = false),
        COALESCE(SUM(wallet_balance), 0)
    INTO v_total, v_active, v_inactive, v_total_wallet
    FROM public.customers;

    SELECT COALESCE(SUM(total_amount), 0)
    INTO v_total_revenue
    FROM public.orders
    WHERE status = 'COMPLETED';

    SELECT
        COALESCE(SUM(current_debt), 0),
        COUNT(*) FILTER (WHERE current_debt > 0)
    INTO v_total_debt, v_debt_count
    FROM public.customer_credits;

    RETURN jsonb_build_object(
        'totalCount', v_total,
        'activeCount', v_active,
        'inactiveCount', v_inactive,
        'totalWalletBalance', v_total_wallet,
        'totalRevenue', v_total_revenue,
        'totalDebt', v_total_debt,
        'debtCustomersCount', v_debt_count
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_customers_global_stats_rpc() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customers_global_stats_rpc() TO authenticated, service_role;

-- 5. RPC de Top Clientes canónico sobre public.customers + soporte rango de fechas + Auth/RBAC
DROP FUNCTION IF EXISTS public.get_top_customers_rpc(integer);
DROP FUNCTION IF EXISTS public.get_top_customers_rpc(integer, timestamptz, timestamptz);

CREATE OR REPLACE FUNCTION public.get_top_customers_rpc(
    p_limit integer DEFAULT 5,
    p_start_date timestamptz DEFAULT NULL,
    p_end_date timestamptz DEFAULT NULL
)
RETURNS TABLE(
    id uuid,
    full_name text,
    phone text,
    document_number text,
    document_type text,
    avatar_url text,
    wallet_balance numeric,
    is_active boolean,
    created_at timestamp with time zone,
    total_revenue numeric,
    order_count bigint,
    last_order_at timestamp with time zone,
    current_debt numeric,
    credit_limit numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_limit integer := LEAST(GREATEST(coalesce(p_limit, 5), 1), 100);
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('customers.read'::text)
        OR public.user_has_permission('customers.manage'::text)
        OR public.user_has_permission('pos.sale'::text)
        OR public.user_has_permission('orders.read'::text)
        OR public.user_has_permission('reports.financial'::text)
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para consultar el ranking de clientes.' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.full_name,
        c.phone,
        c.document_number,
        c.document_type,
        c.avatar_url,
        c.wallet_balance::numeric,
        c.is_active,
        c.created_at,
        COALESCE(SUM(o.total_amount), 0)::numeric AS total_revenue,
        COUNT(o.id)::bigint AS order_count,
        MAX(o.created_at) AS last_order_at,
        COALESCE(MAX(cc.current_debt), 0)::numeric AS current_debt,
        COALESCE(MAX(cc.credit_limit), 0)::numeric AS credit_limit
    FROM public.customers c
    JOIN public.orders o
      ON o.status = 'COMPLETED'
     AND (
         o.customer_record_id = c.id
         OR (c.profile_id IS NOT NULL AND o.customer_id = c.profile_id)
     )
    LEFT JOIN public.customer_credits cc
      ON cc.customer_record_id = c.id
         OR (c.profile_id IS NOT NULL AND cc.profile_id = c.profile_id)
    WHERE (p_start_date IS NULL OR o.created_at >= p_start_date)
      AND (p_end_date IS NULL OR o.created_at <= p_end_date)
      AND (
          c.profile_id IS NULL
          OR NOT EXISTS (
              SELECT 1
              FROM public.user_roles ur
              JOIN public.roles ro ON ro.id = ur.role_id
              WHERE ur.profile_id = c.profile_id
                AND ro.name IN ('admin', 'employee')
          )
      )
    GROUP BY c.id
    ORDER BY total_revenue DESC, order_count DESC
    LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.get_top_customers_rpc(integer, timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_top_customers_rpc(integer, timestamptz, timestamptz) TO authenticated, service_role;

-- 6. RPC atómico save_customer_full_profile_rpc con FOR UPDATE, validaciones ACID y ledger en wallet_movements
CREATE OR REPLACE FUNCTION public.save_customer_full_profile_rpc(
    p_customer_id uuid DEFAULT NULL,
    p_full_name text DEFAULT '',
    p_phone text DEFAULT NULL,
    p_document_number text DEFAULT NULL,
    p_document_type text DEFAULT 'DNI',
    p_is_active boolean DEFAULT true,
    p_wallet_delta integer DEFAULT 0,
    p_has_credit boolean DEFAULT true,
    p_credit_limit numeric DEFAULT 0.00
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_actor_id uuid;
    v_cust_id uuid;
    v_profile_id uuid;
    v_old_wallet integer := 0;
    v_new_wallet integer := 0;
    v_actual_delta integer := 0;
    v_current_debt numeric(14,2) := 0.00;
    v_clean_name text := NULLIF(trim(coalesce(p_full_name, '')), '');
    v_clean_phone text := NULLIF(trim(coalesce(p_phone, '')), '');
    v_doc_type text := COALESCE(NULLIF(trim(p_document_type), ''), 'DNI');
    v_doc_num text := NULLIF(trim(p_document_number), '');
    v_cust_type text := CASE WHEN v_doc_type = 'RUC' THEN 'COMPANY' ELSE 'PERSON' END;
    v_norm_doc_type text := CASE WHEN v_doc_type IN ('DNI','RUC','CE','PASAPORTE') THEN v_doc_type ELSE 'OTRO' END;
    v_credit_limit numeric(14,2) := COALESCE(p_credit_limit, 0.00);
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('customers.manage'::text)
        OR (p_customer_id IS NULL AND public.user_has_permission('pos.sale'::text))
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para guardar o editar clientes.' USING ERRCODE = '42501';
    END IF;

    IF v_clean_name IS NULL THEN
        RAISE EXCEPTION 'El nombre completo del cliente es obligatorio.' USING ERRCODE = 'P0001';
    END IF;

    IF v_credit_limit < 0 THEN
        RAISE EXCEPTION 'El límite de crédito no puede ser negativo.' USING ERRCODE = 'P0001';
    END IF;

    SELECT id INTO v_actor_id
    FROM public.profiles
    WHERE auth_user_id = auth.uid()
    LIMIT 1;

    IF p_customer_id IS NOT NULL THEN
        SELECT id, profile_id, wallet_balance
        INTO v_cust_id, v_profile_id, v_old_wallet
        FROM public.customers
        WHERE id = p_customer_id OR profile_id = p_customer_id
        ORDER BY (id = p_customer_id) DESC
        LIMIT 1
        FOR UPDATE;
    END IF;

    IF v_cust_id IS NULL THEN
        v_new_wallet := GREATEST(COALESCE(p_wallet_delta, 0), 0);
        v_actual_delta := v_new_wallet;

        INSERT INTO public.customers (
            customer_type, document_type, document_number, full_name, phone,
            is_active, wallet_balance, created_by, updated_by
        ) VALUES (
            v_cust_type,
            v_norm_doc_type,
            v_doc_num,
            v_clean_name,
            v_clean_phone,
            COALESCE(p_is_active, true),
            v_new_wallet,
            v_actor_id,
            v_actor_id
        ) RETURNING id INTO v_cust_id;
    ELSE
        v_new_wallet := GREATEST(COALESCE(v_old_wallet, 0) + COALESCE(p_wallet_delta, 0), 0);
        v_actual_delta := v_new_wallet - COALESCE(v_old_wallet, 0);

        UPDATE public.customers
        SET
            customer_type = v_cust_type,
            document_type = v_norm_doc_type,
            document_number = v_doc_num,
            full_name = v_clean_name,
            phone = v_clean_phone,
            is_active = COALESCE(p_is_active, is_active),
            wallet_balance = v_new_wallet,
            updated_by = v_actor_id,
            updated_at = now()
        WHERE id = v_cust_id;
    END IF;

    -- Registro obligatorio en el libro mayor de billetera cuando hay variación real
    IF v_actual_delta <> 0 THEN
        INSERT INTO public.wallet_movements (
            customer_id,
            profile_id,
            points,
            movement_type,
            description
        ) VALUES (
            v_cust_id,
            v_profile_id,
            v_actual_delta,
            'ADJUSTMENT',
            CASE
                WHEN v_actual_delta > 0 THEN 'Ajuste administrativo de billetera (+' || v_actual_delta || ')'
                ELSE 'Ajuste administrativo de billetera (' || v_actual_delta || ')'
            END
        );
    END IF;

    -- Lock pesimista sobre la cuenta de crédito asociada
    SELECT COALESCE(cc.current_debt, 0.00)
    INTO v_current_debt
    FROM public.customer_credits cc
    WHERE cc.customer_record_id = v_cust_id
    FOR UPDATE;

    v_current_debt := COALESCE(v_current_debt, 0.00);

    IF NOT COALESCE(p_has_credit, true) AND v_current_debt > 0 THEN
        RAISE EXCEPTION 'No se puede desactivar el crédito mientras exista deuda pendiente (S/ %).', v_current_debt
            USING ERRCODE = 'P0001';
    END IF;

    IF COALESCE(p_has_credit, true) AND v_credit_limit > 0 AND v_credit_limit < v_current_debt THEN
        RAISE EXCEPTION 'El límite de crédito (S/ %) no puede ser menor a la deuda actual (S/ %).', v_credit_limit, v_current_debt
            USING ERRCODE = 'P0001';
    END IF;

    IF COALESCE(p_has_credit, true) THEN
        INSERT INTO public.customer_credits (
            customer_record_id, profile_id, credit_limit, is_active, created_by
        ) VALUES (
            v_cust_id, v_profile_id, v_credit_limit, true, v_actor_id
        )
        ON CONFLICT (customer_record_id)
        DO UPDATE SET
            credit_limit = v_credit_limit,
            is_active = true,
            updated_at = now();
    ELSE
        UPDATE public.customer_credits
        SET is_active = false, updated_at = now()
        WHERE customer_record_id = v_cust_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'customer_id', v_cust_id,
        'profile_id', v_profile_id,
        'wallet_balance', v_new_wallet
    );
END;
$$;

REVOKE ALL ON FUNCTION public.save_customer_full_profile_rpc(
    uuid, text, text, text, text, boolean, integer, boolean, numeric
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_customer_full_profile_rpc(
    uuid, text, text, text, text, boolean, integer, boolean, numeric
) TO authenticated, service_role;

-- 7. RPC atómico para alternar estado activo de cliente
CREATE OR REPLACE FUNCTION public.toggle_customer_status_rpc(
    p_customer_id uuid,
    p_is_active boolean
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_actor_id uuid;
    v_cust_id uuid;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('customers.manage'::text)
        OR public.is_admin()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para cambiar el estado de clientes.' USING ERRCODE = '42501';
    END IF;

    SELECT id INTO v_actor_id
    FROM public.profiles
    WHERE auth_user_id = auth.uid()
    LIMIT 1;

    SELECT id INTO v_cust_id
    FROM public.customers
    WHERE id = p_customer_id OR profile_id = p_customer_id
    ORDER BY (id = p_customer_id) DESC
    LIMIT 1
    FOR UPDATE;

    IF v_cust_id IS NULL THEN
        RAISE EXCEPTION 'Cliente no encontrado.' USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.customers
    SET
        is_active = p_is_active,
        updated_by = v_actor_id,
        updated_at = now()
    WHERE id = v_cust_id;

    RETURN jsonb_build_object(
        'success', true,
        'customer_id', v_cust_id,
        'is_active', p_is_active
    );
END;
$$;

REVOKE ALL ON FUNCTION public.toggle_customer_status_rpc(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.toggle_customer_status_rpc(uuid, boolean) TO authenticated, service_role;

COMMIT;
