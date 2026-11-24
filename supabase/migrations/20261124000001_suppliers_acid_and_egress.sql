-- ============================================================================
-- Migración: Blindaje ACID, Seguridad, Índices y Single-RTT para Proveedores
-- Fecha: 2026-11-24
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 1. Columna updated_at, normalización de tax_id e integridad de nombre
ALTER TABLE public.suppliers
    ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

UPDATE public.suppliers
SET tax_id = NULLIF(trim(tax_id), '')
WHERE tax_id IS NOT NULL
  AND (tax_id <> trim(tax_id) OR trim(tax_id) = '');

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'suppliers_name_not_blank'
          AND conrelid = 'public.suppliers'::regclass
    ) THEN
        ALTER TABLE public.suppliers
            ADD CONSTRAINT suppliers_name_not_blank CHECK (length(trim(name)) > 0);
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_suppliers_tax_id_normalized
    ON public.suppliers (trim(tax_id))
    WHERE tax_id IS NOT NULL AND trim(tax_id) <> '';

-- 2. Índices de rendimiento para paginación, filtro is_active y búsqueda multi-campo
CREATE INDEX IF NOT EXISTS idx_suppliers_active_name
    ON public.suppliers (is_active, name ASC, id);

CREATE INDEX IF NOT EXISTS idx_suppliers_name_trgm
    ON public.suppliers USING gin (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_suppliers_tax_id_trgm
    ON public.suppliers USING gin (tax_id gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_suppliers_phone_trgm
    ON public.suppliers USING gin (phone gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_suppliers_contact_name_trgm
    ON public.suppliers USING gin (contact_name gin_trgm_ops);

-- 3. Principio de mínimo privilegio: revocar acceso anónimo directo sobre la tabla
REVOKE ALL ON TABLE public.suppliers FROM anon;

-- 4. RPC Single-RTT: Página + Filtro is_active en servidor + Conteo + KPIs globales
CREATE OR REPLACE FUNCTION public.get_suppliers_page_rpc(
    p_search_query text DEFAULT ''::text,
    p_is_active boolean DEFAULT NULL::boolean,
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
    v_items jsonb := '[]'::jsonb;
    v_total_count bigint := 0;
    v_stats jsonb := NULL;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('suppliers.view'::text)
        OR public.user_has_permission('suppliers.manage'::text)
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para ver proveedores.' USING ERRCODE = '42501';
    END IF;

    WITH filtered AS (
        SELECT
            s.id,
            s.name,
            s.tax_id,
            s.contact_name,
            s.phone,
            s.email,
            s.address,
            s.is_active,
            s.created_at
        FROM public.suppliers s
        WHERE (
            v_q = ''
            OR s.name ILIKE '%' || v_q || '%'
            OR coalesce(s.tax_id, '') ILIKE '%' || v_q || '%'
            OR coalesce(s.contact_name, '') ILIKE '%' || v_q || '%'
            OR coalesce(s.phone, '') ILIKE '%' || v_q || '%'
        )
        AND (p_is_active IS NULL OR s.is_active = p_is_active)
    ),
    paged AS (
        SELECT
            f.*,
            COUNT(*) OVER() AS total_count
        FROM filtered f
        ORDER BY f.name ASC, f.id ASC
        LIMIT v_limit
        OFFSET v_offset
    )
    SELECT
        coalesce(
            jsonb_agg(
                jsonb_build_object(
                    'id', p.id,
                    'name', p.name,
                    'tax_id', p.tax_id,
                    'contact_name', p.contact_name,
                    'phone', p.phone,
                    'email', p.email,
                    'address', p.address,
                    'is_active', p.is_active,
                    'created_at', p.created_at
                )
            ),
            '[]'::jsonb
        ),
        coalesce(MAX(p.total_count), 0)
    INTO v_items, v_total_count
    FROM paged p;

    IF v_total_count = 0 AND v_offset > 0 THEN
        SELECT COUNT(*)
        INTO v_total_count
        FROM public.suppliers s
        WHERE (
            v_q = ''
            OR s.name ILIKE '%' || v_q || '%'
            OR coalesce(s.tax_id, '') ILIKE '%' || v_q || '%'
            OR coalesce(s.contact_name, '') ILIKE '%' || v_q || '%'
            OR coalesce(s.phone, '') ILIKE '%' || v_q || '%'
        )
        AND (p_is_active IS NULL OR s.is_active = p_is_active);
    END IF;

    IF p_include_stats THEN
        SELECT jsonb_build_object(
            'totalSuppliers', COUNT(*),
            'activeSuppliers', COUNT(*) FILTER (WHERE s.is_active = true),
            'inactiveSuppliers', COUNT(*) FILTER (WHERE s.is_active = false),
            'withTaxIdCount', COUNT(*) FILTER (WHERE s.tax_id IS NOT NULL AND trim(s.tax_id) <> '')
        )
        INTO v_stats
        FROM public.suppliers s
        WHERE v_q = ''
           OR s.name ILIKE '%' || v_q || '%'
           OR coalesce(s.tax_id, '') ILIKE '%' || v_q || '%'
           OR coalesce(s.contact_name, '') ILIKE '%' || v_q || '%'
           OR coalesce(s.phone, '') ILIKE '%' || v_q || '%';
    END IF;

    RETURN jsonb_build_object(
        'items', v_items,
        'totalCount', v_total_count,
        'stats', v_stats
    );
END;
$$;

-- 5. RPC atómica para crear / actualizar proveedor con normalización
CREATE OR REPLACE FUNCTION public.rpc_upsert_supplier(
    p_id uuid DEFAULT NULL::uuid,
    p_name text DEFAULT ''::text,
    p_tax_id text DEFAULT NULL::text,
    p_contact_name text DEFAULT NULL::text,
    p_phone text DEFAULT NULL::text,
    p_email text DEFAULT NULL::text,
    p_address text DEFAULT NULL::text,
    p_is_active boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_name text := trim(coalesce(p_name, ''));
    v_tax_id text := NULLIF(trim(coalesce(p_tax_id, '')), '');
    v_contact text := NULLIF(trim(coalesce(p_contact_name, '')), '');
    v_phone text := NULLIF(trim(coalesce(p_phone, '')), '');
    v_email text := NULLIF(trim(coalesce(p_email, '')), '');
    v_address text := NULLIF(trim(coalesce(p_address, '')), '');
    v_row public.suppliers%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No autenticado.', 'detail', '42501');
    END IF;

    IF NOT public.user_has_permission('suppliers.manage'::text) THEN
        RETURN jsonb_build_object('success', false, 'error', 'No tienes permisos para gestionar proveedores.', 'detail', '42501');
    END IF;

    IF v_name = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'El nombre o razón social es obligatorio.', 'detail', 'P0001');
    END IF;

    IF p_id IS NULL THEN
        INSERT INTO public.suppliers (
            name, tax_id, contact_name, phone, email, address, is_active, updated_at
        ) VALUES (
            v_name, v_tax_id, v_contact, v_phone, v_email, v_address, coalesce(p_is_active, true), NOW()
        )
        RETURNING * INTO v_row;
    ELSE
        UPDATE public.suppliers
        SET name         = v_name,
            tax_id       = v_tax_id,
            contact_name = v_contact,
            phone        = v_phone,
            email        = v_email,
            address      = v_address,
            is_active    = coalesce(p_is_active, is_active),
            updated_at   = NOW()
        WHERE id = p_id
        RETURNING * INTO v_row;

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'Proveedor no encontrado.', 'detail', 'P0002');
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'supplier', jsonb_build_object(
            'id', v_row.id,
            'name', v_row.name,
            'tax_id', v_row.tax_id,
            'contact_name', v_row.contact_name,
            'phone', v_row.phone,
            'email', v_row.email,
            'address', v_row.address,
            'is_active', v_row.is_active,
            'created_at', v_row.created_at
        )
    );
EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Ya existe un proveedor con ese número de RUC/ID fiscal.',
            'detail', '23505'
        );
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- 6. RPC atómica para alternar estado individual de proveedor
CREATE OR REPLACE FUNCTION public.rpc_toggle_supplier_status(
    p_supplier_id uuid,
    p_is_active boolean
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_row public.suppliers%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No autenticado.', 'detail', '42501');
    END IF;

    IF NOT public.user_has_permission('suppliers.manage'::text) THEN
        RETURN jsonb_build_object('success', false, 'error', 'No tienes permisos para modificar proveedores.', 'detail', '42501');
    END IF;

    SELECT * INTO v_row
    FROM public.suppliers
    WHERE id = p_supplier_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Proveedor no encontrado.', 'detail', 'P0002');
    END IF;

    UPDATE public.suppliers
    SET is_active  = p_is_active,
        updated_at = NOW()
    WHERE id = p_supplier_id
    RETURNING * INTO v_row;

    RETURN jsonb_build_object(
        'success', true,
        'supplier', jsonb_build_object(
            'id', v_row.id,
            'name', v_row.name,
            'tax_id', v_row.tax_id,
            'contact_name', v_row.contact_name,
            'phone', v_row.phone,
            'email', v_row.email,
            'address', v_row.address,
            'is_active', v_row.is_active,
            'created_at', v_row.created_at
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- 7. RPC atómica para alternar estado masivo (Bulk Toggle) sin N+1 ni Lost Updates
CREATE OR REPLACE FUNCTION public.rpc_bulk_toggle_suppliers_status(
    p_supplier_ids uuid[]
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_count integer;
    v_updated jsonb := '[]'::jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No autenticado.', 'detail', '42501');
    END IF;

    IF NOT public.user_has_permission('suppliers.manage'::text) THEN
        RETURN jsonb_build_object('success', false, 'error', 'No tienes permisos para modificar proveedores.', 'detail', '42501');
    END IF;

    v_count := coalesce(array_length(p_supplier_ids, 1), 0);
    IF v_count = 0 OR v_count > 100 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cantidad inválida de proveedores seleccionados (1–100).', 'detail', 'P0001');
    END IF;

    -- Bloqueo ordenado por id para prevenir deadlocks
    PERFORM id
    FROM public.suppliers
    WHERE id = ANY(p_supplier_ids)
    ORDER BY id ASC
    FOR UPDATE;

    WITH updated AS (
        UPDATE public.suppliers
        SET is_active  = NOT is_active,
            updated_at = NOW()
        WHERE id = ANY(p_supplier_ids)
        RETURNING id, name, tax_id, contact_name, phone, email, address, is_active, created_at
    )
    SELECT
        coalesce(
            jsonb_agg(
                jsonb_build_object(
                    'id', u.id,
                    'name', u.name,
                    'tax_id', u.tax_id,
                    'contact_name', u.contact_name,
                    'phone', u.phone,
                    'email', u.email,
                    'address', u.address,
                    'is_active', u.is_active,
                    'created_at', u.created_at
                )
            ),
            '[]'::jsonb
        ),
        COUNT(*)
    INTO v_updated, v_count
    FROM updated u;

    RETURN jsonb_build_object(
        'success', true,
        'updatedCount', v_count,
        'updatedSuppliers', v_updated
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- 8. Revocación estricta de privilegios anónimos en RPCs de proveedores
REVOKE ALL ON FUNCTION public.get_suppliers_page_rpc(text, boolean, integer, integer, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_suppliers_page_rpc(text, boolean, integer, integer, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_upsert_supplier(uuid, text, text, text, text, text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_upsert_supplier(uuid, text, text, text, text, text, text, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_toggle_supplier_status(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_toggle_supplier_status(uuid, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_bulk_toggle_suppliers_status(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_bulk_toggle_suppliers_status(uuid[]) TO authenticated, service_role;
