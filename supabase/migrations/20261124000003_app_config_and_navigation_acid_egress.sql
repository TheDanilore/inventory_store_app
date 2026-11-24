-- ============================================================================
-- Migración: Blindaje Singleton ACID para business_info + Índices de Egress
-- Fecha: 2026-11-24
-- ============================================================================

-- 1. Deduplicar cualquier fila histórica extra en business_info (patrón Singleton)
--    Conserva únicamente el registro más reciente por updated_at / id.
WITH ranked AS (
    SELECT
        id,
        ROW_NUMBER() OVER (ORDER BY updated_at DESC NULLS LAST, id DESC) AS rn
    FROM public.business_info
)
DELETE FROM public.business_info bi
USING ranked r
WHERE bi.id = r.id
  AND r.rn > 1;

-- 2. Columna guardiana e índice único para garantizar unicidad física a nivel DB
ALTER TABLE public.business_info
    ADD COLUMN IF NOT EXISTS singleton_guard boolean NOT NULL DEFAULT true;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'business_info_singleton_guard_check'
          AND conrelid = 'public.business_info'::regclass
    ) THEN
        ALTER TABLE public.business_info
            ADD CONSTRAINT business_info_singleton_guard_check
            CHECK (singleton_guard = true);
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_business_info_singleton
    ON public.business_info (singleton_guard);

-- 3. RPC transaccional atómico (1 solo RTT, elimina check-then-insert en cliente)
CREATE OR REPLACE FUNCTION public.upsert_business_info_rpc(
    p_business_name text,
    p_tax_id text DEFAULT NULL,
    p_address text DEFAULT NULL,
    p_phone text DEFAULT NULL,
    p_logo_url text DEFAULT NULL,
    p_loyalty_global_enabled boolean DEFAULT false,
    p_loyalty_customer_visible boolean DEFAULT false,
    p_cash_register_mode text DEFAULT 'COUNTER'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_name text := trim(coalesce(p_business_name, ''));
    v_mode text := upper(trim(coalesce(p_cash_register_mode, 'COUNTER')));
    v_result jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT public.user_has_permission('settings.edit'::text) THEN
        RAISE EXCEPTION 'No tienes permisos para editar la configuración del negocio.'
            USING ERRCODE = '42501';
    END IF;

    IF v_name = '' THEN
        RAISE EXCEPTION 'El nombre del negocio es obligatorio.'
            USING ERRCODE = '22023';
    END IF;

    IF v_mode NOT IN ('COUNTER', 'INDIVIDUAL') THEN
        RAISE EXCEPTION 'Modo de caja inválido: %', p_cash_register_mode
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.business_info (
        singleton_guard,
        business_name,
        tax_id,
        address,
        phone,
        logo_url,
        loyalty_global_enabled,
        loyalty_customer_visible,
        cash_register_mode,
        updated_at
    )
    VALUES (
        true,
        v_name,
        NULLIF(trim(coalesce(p_tax_id, '')), ''),
        NULLIF(trim(coalesce(p_address, '')), ''),
        NULLIF(trim(coalesce(p_phone, '')), ''),
        NULLIF(trim(coalesce(p_logo_url, '')), ''),
        coalesce(p_loyalty_global_enabled, false),
        coalesce(p_loyalty_customer_visible, false),
        v_mode,
        now()
    )
    ON CONFLICT (singleton_guard) DO UPDATE SET
        business_name            = EXCLUDED.business_name,
        tax_id                   = EXCLUDED.tax_id,
        address                  = EXCLUDED.address,
        phone                    = EXCLUDED.phone,
        logo_url                 = EXCLUDED.logo_url,
        loyalty_global_enabled   = EXCLUDED.loyalty_global_enabled,
        loyalty_customer_visible = EXCLUDED.loyalty_customer_visible,
        cash_register_mode       = EXCLUDED.cash_register_mode,
        updated_at               = now()
    RETURNING jsonb_build_object(
        'id', id,
        'business_name', business_name,
        'tax_id', tax_id,
        'address', address,
        'phone', phone,
        'logo_url', logo_url,
        'loyalty_global_enabled', loyalty_global_enabled,
        'loyalty_customer_visible', loyalty_customer_visible,
        'cash_register_mode', cash_register_mode
    )
    INTO v_result;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_business_info_rpc(
    text, text, text, text, text, boolean, boolean, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.upsert_business_info_rpc(
    text, text, text, text, text, boolean, boolean, text
) TO authenticated, service_role;

-- 4. Índices parciales de rendimiento para navegación y alertas de inventario
CREATE INDEX IF NOT EXISTS idx_orders_pending_status
    ON public.orders (id)
    WHERE status = 'PENDING';

CREATE INDEX IF NOT EXISTS idx_wsb_active_expiry
    ON public.warehouse_stock_batches (expiry_date, variant_id)
    WHERE available_quantity > 0 AND expiry_date IS NOT NULL;
