-- ============================================================================
-- Migración: Blindaje ACID, Seguridad, Índices y Single-RTT para Créditos de Proveedores
-- Fecha: 2026-11-24
-- ============================================================================

-- 1. Extensión para búsquedas rápidas ILIKE '%texto%' sin Seq Scan
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Constraints de integridad y columna de idempotencia
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'supplier_credits_credit_limit_check'
          AND conrelid = 'public.supplier_credits'::regclass
    ) THEN
        ALTER TABLE public.supplier_credits
            ADD CONSTRAINT supplier_credits_credit_limit_check CHECK (credit_limit >= 0);
    END IF;
END $$;

ALTER TABLE public.supplier_credit_movements
    ADD COLUMN IF NOT EXISTS idempotency_key uuid;

CREATE UNIQUE INDEX IF NOT EXISTS idx_supplier_credit_movements_idempotency
    ON public.supplier_credit_movements (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- 3. Índices de rendimiento para paginación, filtros y búsquedas de proveedores
CREATE INDEX IF NOT EXISTS idx_supplier_credits_debt_desc
    ON public.supplier_credits (current_debt DESC, id);

CREATE INDEX IF NOT EXISTS idx_supplier_credits_active_debt
    ON public.supplier_credits (current_debt DESC, id)
    WHERE is_active = true AND current_debt > 0;

CREATE INDEX IF NOT EXISTS idx_suppliers_name_trgm
    ON public.suppliers USING gin (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_suppliers_tax_id_trgm
    ON public.suppliers USING gin (tax_id gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_suppliers_phone_trgm
    ON public.suppliers USING gin (phone gin_trgm_ops);

-- 4. Políticas RLS explícitas para supplier_credits
DROP POLICY IF EXISTS "Créditos proveedor: Inserción por permiso" ON public.supplier_credits;
CREATE POLICY "Créditos proveedor: Inserción por permiso"
    ON public.supplier_credits
    FOR INSERT
    TO authenticated
    WITH CHECK (public.user_has_permission('purchases.create'::text));

DROP POLICY IF EXISTS "Créditos proveedor: Actualización por permiso" ON public.supplier_credits;
CREATE POLICY "Créditos proveedor: Actualización por permiso"
    ON public.supplier_credits
    FOR UPDATE
    TO authenticated
    USING (public.user_has_permission('purchases.create'::text))
    WITH CHECK (public.user_has_permission('purchases.create'::text));

-- 5. RPC Single-RTT: Página + Conteo + Stats opcionales
CREATE OR REPLACE FUNCTION public.get_supplier_credits_page_rpc(
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
    v_items jsonb := '[]'::jsonb;
    v_total_count bigint := 0;
    v_stats jsonb := NULL;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('purchases.view'::text)
        OR public.user_has_permission('reports.financial'::text)
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para ver créditos de proveedores.' USING ERRCODE = '42501';
    END IF;

    WITH filtered AS (
        SELECT
            sc.id,
            sc.supplier_id,
            sc.credit_limit,
            sc.current_debt,
            sc.is_active,
            s.name AS supplier_name,
            s.tax_id AS supplier_tax_id,
            s.phone AS supplier_phone
        FROM public.supplier_credits sc
        INNER JOIN public.suppliers s ON s.id = sc.supplier_id
        WHERE (
            v_q = ''
            OR s.name ILIKE '%' || v_q || '%'
            OR coalesce(s.tax_id, '') ILIKE '%' || v_q || '%'
            OR coalesce(s.phone, '') ILIKE '%' || v_q || '%'
        )
        AND (
            NOT p_with_debt_only
            OR (sc.is_active = true AND sc.current_debt > 0)
        )
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
                    'id', p.id,
                    'supplier_id', p.supplier_id,
                    'credit_limit', p.credit_limit,
                    'current_debt', p.current_debt,
                    'is_active', p.is_active,
                    'supplier_name', p.supplier_name,
                    'supplier_tax_id', p.supplier_tax_id,
                    'supplier_phone', p.supplier_phone
                )
            ),
            '[]'::jsonb
        ),
        coalesce(MAX(p.total_count), 0)
    INTO v_items, v_total_count
    FROM paged p;

    -- Si offset cayó fuera de rango tras un filtro o borrado, obtener total real
    IF v_total_count = 0 AND v_offset > 0 THEN
        SELECT COUNT(*)
        INTO v_total_count
        FROM public.supplier_credits sc
        INNER JOIN public.suppliers s ON s.id = sc.supplier_id
        WHERE (
            v_q = ''
            OR s.name ILIKE '%' || v_q || '%'
            OR coalesce(s.tax_id, '') ILIKE '%' || v_q || '%'
            OR coalesce(s.phone, '') ILIKE '%' || v_q || '%'
        )
        AND (
            NOT p_with_debt_only
            OR (sc.is_active = true AND sc.current_debt > 0)
        );
    END IF;

    IF p_include_stats THEN
        SELECT jsonb_build_object(
            'totalDebt', coalesce(SUM(sc.current_debt), 0),
            'activeAccounts', COUNT(*) FILTER (WHERE sc.is_active = true),
            'suspendedAccounts', COUNT(*) FILTER (WHERE sc.is_active = false),
            'maxedOutAccounts', COUNT(*) FILTER (
                WHERE sc.is_active = true
                  AND sc.current_debt >= sc.credit_limit
                  AND sc.credit_limit > 0
            ),
            'debtCount', COUNT(*) FILTER (WHERE sc.is_active = true AND sc.current_debt > 0)
        )
        INTO v_stats
        FROM public.supplier_credits sc
        INNER JOIN public.suppliers s ON s.id = sc.supplier_id
        WHERE v_q = ''
           OR s.name ILIKE '%' || v_q || '%'
           OR coalesce(s.tax_id, '') ILIKE '%' || v_q || '%'
           OR coalesce(s.phone, '') ILIKE '%' || v_q || '%';
    END IF;

    RETURN jsonb_build_object(
        'items', v_items,
        'totalCount', v_total_count,
        'stats', v_stats
    );
END;
$$;

-- 6. Endurecimiento de get_supplier_credits_stats_rpc
CREATE OR REPLACE FUNCTION public.get_supplier_credits_stats_rpc(
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
        public.user_has_permission('purchases.view'::text)
        OR public.user_has_permission('reports.financial'::text)
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para ver estadísticas de créditos.' USING ERRCODE = '42501';
    END IF;

    SELECT jsonb_build_object(
        'totalDebt', coalesce(SUM(sc.current_debt), 0),
        'activeAccounts', COUNT(*) FILTER (WHERE sc.is_active = true),
        'suspendedAccounts', COUNT(*) FILTER (WHERE sc.is_active = false),
        'maxedOutAccounts', COUNT(*) FILTER (
            WHERE sc.is_active = true
              AND sc.current_debt >= sc.credit_limit
              AND sc.credit_limit > 0
        ),
        'debtCount', COUNT(*) FILTER (WHERE sc.is_active = true AND sc.current_debt > 0)
    )
    INTO v_result
    FROM public.supplier_credits sc
    INNER JOIN public.suppliers s ON s.id = sc.supplier_id
    WHERE v_q = ''
       OR s.name ILIKE '%' || v_q || '%'
       OR coalesce(s.tax_id, '') ILIKE '%' || v_q || '%'
       OR coalesce(s.phone, '') ILIKE '%' || v_q || '%';

    RETURN v_result;
END;
$$;

-- 7. RPC de búsqueda sin full-table scan (anti-join NOT EXISTS)
CREATE OR REPLACE FUNCTION public.search_suppliers_without_credit_rpc(
    p_query text,
    p_limit integer DEFAULT 6
) RETURNS TABLE (
    id uuid,
    name text,
    tax_id text,
    phone text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_q text := trim(coalesce(p_query, ''));
    v_limit integer := LEAST(GREATEST(coalesce(p_limit, 6), 1), 20);
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.user_has_permission('purchases.view'::text)
        OR public.user_has_permission('purchases.create'::text)
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para buscar proveedores.' USING ERRCODE = '42501';
    END IF;

    IF v_q = '' THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT s.id, s.name, s.tax_id, s.phone
    FROM public.suppliers s
    WHERE s.is_active = true
      AND NOT EXISTS (
          SELECT 1
          FROM public.supplier_credits sc
          WHERE sc.supplier_id = s.id
      )
      AND (
          s.name ILIKE '%' || v_q || '%'
          OR coalesce(s.tax_id, '') ILIKE '%' || v_q || '%'
          OR coalesce(s.phone, '') ILIKE '%' || v_q || '%'
      )
    ORDER BY s.name ASC
    LIMIT v_limit;
END;
$$;

-- 8. RPC de creación atómica endurecida
CREATE OR REPLACE FUNCTION public.rpc_create_supplier_credit(
    p_supplier_id uuid,
    p_credit_limit numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_initial_debt numeric := 0;
    v_new_credit_id uuid;
    v_profile_id uuid;
    v_supplier_exists boolean := false;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No autenticado.');
    END IF;

    IF NOT public.user_has_permission('purchases.create'::text) THEN
        RETURN jsonb_build_object('success', false, 'error', 'No tienes permisos para crear líneas de crédito.');
    END IF;

    IF p_credit_limit IS NULL OR p_credit_limit < 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'El límite de crédito debe ser mayor o igual a 0.');
    END IF;

    -- Bloqueo pesimista sobre el proveedor para evitar carreras con compras concurrentes
    SELECT true INTO v_supplier_exists
    FROM public.suppliers
    WHERE id = p_supplier_id
    FOR UPDATE;

    IF NOT coalesce(v_supplier_exists, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Proveedor no encontrado.');
    END IF;

    SELECT coalesce(SUM(GREATEST(0, total_amount - amount_paid)), 0)
    INTO v_initial_debt
    FROM public.purchase_orders
    WHERE supplier_id = p_supplier_id
      AND payment_status IN ('PENDING', 'PARTIAL')
      AND status <> 'CANCELLED';

    IF p_credit_limit < v_initial_debt THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'El límite no puede ser menor a la deuda pendiente actual (S/ ' || round(v_initial_debt, 2) || ').'
        );
    END IF;

    SELECT id INTO v_profile_id
    FROM public.profiles
    WHERE auth_user_id = auth.uid()
    LIMIT 1;

    INSERT INTO public.supplier_credits (
        supplier_id,
        credit_limit,
        current_debt,
        is_active,
        created_by
    ) VALUES (
        p_supplier_id,
        p_credit_limit,
        v_initial_debt,
        true,
        v_profile_id
    )
    RETURNING id INTO v_new_credit_id;

    RETURN jsonb_build_object('success', true, 'credit_id', v_new_credit_id);
EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object('success', false, 'error', 'Este proveedor ya cuenta con una línea de crédito registrada.');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- 9. RPC atómica para actualizar límite de crédito con validación de deuda
CREATE OR REPLACE FUNCTION public.rpc_update_supplier_credit_limit(
    p_credit_id uuid,
    p_credit_limit numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_credit record;
    v_payload jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No autenticado.');
    END IF;

    IF NOT public.user_has_permission('purchases.create'::text) THEN
        RETURN jsonb_build_object('success', false, 'error', 'No tienes permisos para editar líneas de crédito.');
    END IF;

    IF p_credit_limit IS NULL OR p_credit_limit < 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'El límite de crédito debe ser mayor o igual a 0.');
    END IF;

    SELECT * INTO v_credit
    FROM public.supplier_credits
    WHERE id = p_credit_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Línea de crédito no encontrada.');
    END IF;

    IF p_credit_limit < v_credit.current_debt THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'El límite no puede ser menor a la deuda actual (S/ ' || round(v_credit.current_debt, 2) || ').'
        );
    END IF;

    UPDATE public.supplier_credits
    SET credit_limit = p_credit_limit,
        updated_at = NOW()
    WHERE id = p_credit_id;

    SELECT jsonb_build_object(
        'id', sc.id,
        'supplier_id', sc.supplier_id,
        'credit_limit', sc.credit_limit,
        'current_debt', sc.current_debt,
        'is_active', sc.is_active,
        'supplier_name', s.name,
        'supplier_tax_id', s.tax_id,
        'supplier_phone', s.phone
    )
    INTO v_payload
    FROM public.supplier_credits sc
    INNER JOIN public.suppliers s ON s.id = sc.supplier_id
    WHERE sc.id = p_credit_id;

    RETURN jsonb_build_object('success', true, 'credit', v_payload);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- 10. RPC atómica para suspender / reactivar línea de crédito
CREATE OR REPLACE FUNCTION public.rpc_toggle_supplier_credit_status(
    p_credit_id uuid,
    p_is_active boolean
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_payload jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No autenticado.');
    END IF;

    IF NOT public.user_has_permission('purchases.create'::text) THEN
        RETURN jsonb_build_object('success', false, 'error', 'No tienes permisos para modificar el estado del crédito.');
    END IF;

    UPDATE public.supplier_credits
    SET is_active = p_is_active,
        updated_at = NOW()
    WHERE id = p_credit_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Línea de crédito no encontrada.');
    END IF;

    SELECT jsonb_build_object(
        'id', sc.id,
        'supplier_id', sc.supplier_id,
        'credit_limit', sc.credit_limit,
        'current_debt', sc.current_debt,
        'is_active', sc.is_active,
        'supplier_name', s.name,
        'supplier_tax_id', s.tax_id,
        'supplier_phone', s.phone
    )
    INTO v_payload
    FROM public.supplier_credits sc
    INNER JOIN public.suppliers s ON s.id = sc.supplier_id
    WHERE sc.id = p_credit_id;

    RETURN jsonb_build_object('success', true, 'credit', v_payload);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- 11. RPC de pago ACID con bloqueo pesimista FOR UPDATE, idempotencia y doble partida completa
CREATE OR REPLACE FUNCTION public.register_supplier_credit_payment_rpc(
    p_supplier_id uuid,
    p_credit_id uuid,
    p_amount numeric,
    p_account_id uuid,
    p_order_id uuid DEFAULT NULL::uuid,
    p_notes text DEFAULT 'Pago a proveedor registrado'::text,
    p_shift_id uuid DEFAULT NULL::uuid,
    p_profile_id uuid DEFAULT NULL::uuid,
    p_idempotency_key uuid DEFAULT NULL::uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_remaining        numeric := p_amount;
    v_order            record;
    v_pending_of_order numeric;
    v_to_apply         numeric;
    v_new_paid         numeric;
    v_new_status       text;
    v_account          record;
    v_shift            record;
    v_credit           record;
    v_now              timestamptz := NOW();
    v_real_profile_id  uuid;
    v_credit_id        uuid := p_credit_id;
    v_updated_credit   jsonb := NULL;
    v_existing_mov     uuid;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No autenticado.');
    END IF;

    IF NOT (
        public.user_has_permission('purchases.create'::text)
        OR public.user_has_permission('financial.movements.create'::text)
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'No tienes permisos para registrar pagos a proveedores.');
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'El monto debe ser mayor a 0.');
    END IF;

    IF p_account_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Debes seleccionar una cuenta financiera de salida.');
    END IF;

    -- Idempotencia ante reintentos por red lenta
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_existing_mov
        FROM public.supplier_credit_movements
        WHERE idempotency_key = p_idempotency_key
        LIMIT 1;

        IF v_existing_mov IS NOT NULL THEN
            IF v_credit_id IS NOT NULL THEN
                SELECT jsonb_build_object(
                    'id', sc.id,
                    'supplier_id', sc.supplier_id,
                    'credit_limit', sc.credit_limit,
                    'current_debt', sc.current_debt,
                    'is_active', sc.is_active,
                    'supplier_name', s.name,
                    'supplier_tax_id', s.tax_id,
                    'supplier_phone', s.phone
                )
                INTO v_updated_credit
                FROM public.supplier_credits sc
                INNER JOIN public.suppliers s ON s.id = sc.supplier_id
                WHERE sc.id = v_credit_id;
            END IF;

            RETURN jsonb_build_object(
                'success', true,
                'idempotent', true,
                'amount_paid', p_amount,
                'updated_credit', v_updated_credit
            );
        END IF;
    END IF;

    -- Resolver perfil del operador autenticado
    SELECT id INTO v_real_profile_id
    FROM public.profiles
    WHERE auth_user_id = auth.uid()
    LIMIT 1;

    IF v_real_profile_id IS NULL AND p_profile_id IS NOT NULL THEN
        SELECT id INTO v_real_profile_id
        FROM public.profiles
        WHERE auth_user_id = p_profile_id OR id = p_profile_id
        LIMIT 1;
    END IF;

    -- Orden determinista de bloqueo FOR UPDATE:
    -- 1) financial_accounts
    SELECT id, name, type, balance, is_active
    INTO v_account
    FROM public.financial_accounts
    WHERE id = p_account_id
    FOR UPDATE;

    IF NOT FOUND OR NOT v_account.is_active THEN
        RETURN jsonb_build_object('success', false, 'error', 'La cuenta financiera seleccionada no existe o está inactiva.');
    END IF;

    IF v_account.balance < p_amount THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Saldo insuficiente en ' || v_account.name || ' (disponible: S/ ' || round(v_account.balance, 2) || ').'
        );
    END IF;

    -- 2) cash_shifts si la cuenta es CAJA
    IF v_account.type = 'CAJA' THEN
        IF p_shift_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'La cuenta CAJA requiere un turno de caja abierto.');
        END IF;

        SELECT id, status
        INTO v_shift
        FROM public.cash_shifts
        WHERE id = p_shift_id
          AND account_id = p_account_id
          AND status = 'OPEN'
        FOR UPDATE;

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'El turno de caja seleccionado no está abierto o no pertenece a esta caja.');
        END IF;
    END IF;

    -- 3) supplier_credits
    IF v_credit_id IS NULL AND p_supplier_id IS NOT NULL THEN
        SELECT id INTO v_credit_id
        FROM public.supplier_credits
        WHERE supplier_id = p_supplier_id
        LIMIT 1;
    END IF;

    IF v_credit_id IS NOT NULL THEN
        SELECT id, current_debt, is_active
        INTO v_credit
        FROM public.supplier_credits
        WHERE id = v_credit_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'Línea de crédito de proveedor no encontrada.');
        END IF;

        IF NOT v_credit.is_active THEN
            RETURN jsonb_build_object('success', false, 'error', 'La línea de crédito está suspendida.');
        END IF;

        IF p_amount > v_credit.current_debt THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'El monto supera la deuda actual del proveedor (S/ ' || round(v_credit.current_debt, 2) || ').'
            );
        END IF;
    END IF;

    -- 4) purchase_orders bloqueadas en orden determinista
    FOR v_order IN
        SELECT id, total_amount, amount_paid, payment_status, status
        FROM public.purchase_orders
        WHERE supplier_id = p_supplier_id
          AND (p_order_id IS NULL OR id = p_order_id)
          AND payment_status IN ('PENDING', 'PARTIAL')
          AND status <> 'CANCELLED'
        ORDER BY created_at ASC, id ASC
        FOR UPDATE
    LOOP
        EXIT WHEN v_remaining <= 0;

        v_pending_of_order := GREATEST(0, v_order.total_amount - v_order.amount_paid);
        IF v_pending_of_order <= 0 THEN
            CONTINUE;
        END IF;

        v_to_apply   := LEAST(v_remaining, v_pending_of_order);
        v_new_paid   := v_order.amount_paid + v_to_apply;
        v_remaining  := v_remaining - v_to_apply;
        v_new_status := CASE WHEN v_new_paid >= v_order.total_amount THEN 'PAID' ELSE 'PARTIAL' END;

        IF p_order_id IS NOT NULL AND p_amount > v_pending_of_order THEN
            RAISE EXCEPTION 'El monto supera la deuda pendiente del pedido (S/ %)', round(v_pending_of_order, 2);
        END IF;

        UPDATE public.purchase_orders
        SET amount_paid    = v_new_paid,
            payment_status = v_new_status,
            status         = CASE WHEN status = 'PENDING' THEN 'SENT' ELSE status END,
            updated_at     = v_now
        WHERE id = v_order.id;

        IF v_to_apply > 0 THEN
            INSERT INTO public.account_movements (
                account_id, movement_type, amount, description,
                reference_type, reference_id, shift_id,
                created_by, created_at
            ) VALUES (
                p_account_id, 'EXPENSE', v_to_apply,
                'Pago a proveedor — Orden #' || UPPER(SUBSTRING(v_order.id::text, 1, 8)),
                'purchase_orders', v_order.id, p_shift_id,
                v_real_profile_id, v_now
            );
        END IF;
    END LOOP;

    -- Si se especificó una orden específica pero ya no tenía saldo pendiente
    IF p_order_id IS NOT NULL AND v_remaining = p_amount THEN
        RAISE EXCEPTION 'El pedido seleccionado no tiene deuda pendiente o fue cancelado.';
    END IF;

    -- Cierre de brecha contable: si hubo remanente aplicado a deuda general sin órdenes pendientes
    IF v_remaining > 0 THEN
        INSERT INTO public.account_movements (
            account_id, movement_type, amount, description,
            reference_type, reference_id, shift_id,
            created_by, created_at
        ) VALUES (
            p_account_id, 'EXPENSE', v_remaining,
            coalesce(NULLIF(trim(p_notes), ''), 'Pago a deuda general de proveedor'),
            'supplier_credits', coalesce(v_credit_id, p_supplier_id), p_shift_id,
            v_real_profile_id, v_now
        );
    END IF;

    IF v_credit_id IS NOT NULL THEN
        INSERT INTO public.supplier_credit_movements (
            supplier_credit_id, purchase_order_id, movement_type,
            amount, payment_method, notes, created_by, created_at, idempotency_key
        ) VALUES (
            v_credit_id, p_order_id, 'PAYMENT',
            p_amount, v_account.name, p_notes, v_real_profile_id, v_now, p_idempotency_key
        );

        UPDATE public.supplier_credits
        SET current_debt = GREATEST(0, current_debt - p_amount),
            updated_at   = v_now
        WHERE id = v_credit_id;

        SELECT jsonb_build_object(
            'id', sc.id,
            'supplier_id', sc.supplier_id,
            'credit_limit', sc.credit_limit,
            'current_debt', sc.current_debt,
            'is_active', sc.is_active,
            'supplier_name', s.name,
            'supplier_tax_id', s.tax_id,
            'supplier_phone', s.phone
        )
        INTO v_updated_credit
        FROM public.supplier_credits sc
        INNER JOIN public.suppliers s ON s.id = sc.supplier_id
        WHERE sc.id = v_credit_id;
    END IF;

    UPDATE public.financial_accounts
    SET balance    = balance - p_amount,
        updated_at = v_now
    WHERE id = p_account_id;

    RETURN jsonb_build_object(
        'success', true,
        'amount_paid', p_amount,
        'updated_credit', v_updated_credit
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- 12. Revocación estricta de privilegios anónimos en todas las RPCs del módulo
REVOKE ALL ON FUNCTION public.get_supplier_credits_page_rpc(text, boolean, integer, integer, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_supplier_credits_page_rpc(text, boolean, integer, integer, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_supplier_credits_stats_rpc(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_supplier_credits_stats_rpc(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.search_suppliers_without_credit_rpc(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_suppliers_without_credit_rpc(text, integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_create_supplier_credit(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_supplier_credit(uuid, numeric) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_update_supplier_credit_limit(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_update_supplier_credit_limit(uuid, numeric) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_toggle_supplier_credit_status(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_toggle_supplier_credit_status(uuid, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.register_supplier_credit_payment_rpc(uuid, uuid, numeric, uuid, uuid, text, uuid, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_supplier_credit_payment_rpc(uuid, uuid, numeric, uuid, uuid, text, uuid, uuid, uuid) TO authenticated, service_role;
