-- ============================================================================
-- MIGRACIÓN 10: CONSOLIDACIÓN DE CLIENTES EN RPCs Y SOPORTE SIN PROFILE_ID
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- ============================================================================

BEGIN;

-- 1. Agregar avatar_url a customers y sincronizar desde profiles
ALTER TABLE public.customers
    ADD COLUMN IF NOT EXISTS avatar_url text;

UPDATE public.customers c
SET avatar_url = p.avatar_url
FROM public.profiles p
WHERE c.profile_id = p.id
  AND c.avatar_url IS NULL
  AND p.avatar_url IS NOT NULL;

-- 2. Actualizar get_customers_global_stats_rpc para leer desde public.customers
CREATE OR REPLACE FUNCTION public.get_customers_global_stats_rpc()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total int;
    v_active int;
    v_inactive int;
    v_total_revenue numeric;
    v_total_debt numeric;
    v_debt_count int;
BEGIN
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE is_active = true),
        COUNT(*) FILTER (WHERE is_active = false)
    INTO v_total, v_active, v_inactive
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
        'totalRevenue', v_total_revenue,
        'totalDebt', v_total_debt,
        'debtCustomersCount', v_debt_count
    );
END;
$$;

-- 3. Actualizar save_customer_full_profile_rpc para guardar en public.customers
--    (No requiere cuenta en auth.users ni profiles)
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
    v_doc_type text := COALESCE(NULLIF(trim(p_document_type), ''), 'DNI');
    v_doc_num text := NULLIF(trim(p_document_number), '');
    v_cust_type text := CASE WHEN v_doc_type = 'RUC' THEN 'COMPANY' ELSE 'PERSON' END;
BEGIN
    SELECT id INTO v_actor_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;

    IF p_customer_id IS NOT NULL THEN
        -- Puede llegar customers.id o profiles.id
        SELECT id, profile_id INTO v_cust_id, v_profile_id
        FROM public.customers
        WHERE id = p_customer_id OR profile_id = p_customer_id
        LIMIT 1;
    END IF;

    IF v_cust_id IS NULL THEN
        INSERT INTO public.customers (
            customer_type, document_type, document_number, full_name, phone,
            is_active, wallet_balance, created_by, updated_by
        ) VALUES (
            v_cust_type,
            CASE WHEN v_doc_type IN ('DNI','RUC','CE','PASAPORTE') THEN v_doc_type ELSE 'OTRO' END,
            v_doc_num,
            COALESCE(NULLIF(trim(p_full_name), ''), 'Cliente'),
            NULLIF(trim(p_phone), ''),
            COALESCE(p_is_active, true),
            GREATEST(COALESCE(p_wallet_delta, 0), 0),
            v_actor_id,
            v_actor_id
        ) RETURNING id INTO v_cust_id;
    ELSE
        UPDATE public.customers
        SET
            customer_type = v_cust_type,
            document_type = CASE WHEN v_doc_type IN ('DNI','RUC','CE','PASAPORTE') THEN v_doc_type ELSE 'OTRO' END,
            document_number = v_doc_num,
            full_name = COALESCE(NULLIF(trim(p_full_name), ''), full_name),
            phone = NULLIF(trim(p_phone), ''),
            is_active = COALESCE(p_is_active, is_active),
            wallet_balance = GREATEST(wallet_balance + COALESCE(p_wallet_delta, 0), 0),
            updated_by = v_actor_id,
            updated_at = now()
        WHERE id = v_cust_id;
    END IF;

    -- Línea de crédito vinculada por customer_record_id (y profile_id si existe)
    IF p_has_credit THEN
        INSERT INTO public.customer_credits (
            customer_record_id, profile_id, credit_limit, is_active, created_by
        ) VALUES (
            v_cust_id, v_profile_id, COALESCE(p_credit_limit, 0.00), true, v_actor_id
        )
        ON CONFLICT (customer_record_id)
        DO UPDATE SET
            credit_limit = COALESCE(p_credit_limit, public.customer_credits.credit_limit),
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
        'profile_id', v_profile_id
    );
END;
$$;

COMMIT;

