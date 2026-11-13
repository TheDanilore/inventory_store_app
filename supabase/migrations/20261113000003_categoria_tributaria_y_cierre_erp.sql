-- ============================================================================
-- MIGRACIÓN 4: CATEGORÍA TRIBUTARIA, CUADRE POR MÉTODO DE PAGO Y CIERRE ERP
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. CATEGORÍA TRIBUTARIA EN PRODUCTOS Y CATEGORÍAS (CATÁLOGO 07 SUNAT)
-- ============================================================================

ALTER TABLE public.categories
    ADD COLUMN IF NOT EXISTS default_tax_affectation_type text NOT NULL DEFAULT '10',
    ADD COLUMN IF NOT EXISTS default_tax_rate numeric(5,2) NOT NULL DEFAULT 18.00;

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS tax_affectation_type text NOT NULL DEFAULT '10',
    ADD COLUMN IF NOT EXISTS tax_rate numeric(5,2) NOT NULL DEFAULT 18.00,
    ADD COLUMN IF NOT EXISTS sunat_product_code text; -- Código UNSPSC / Catálogo SUNAT opcional

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'categories_tax_affectation_check'
    ) THEN
        ALTER TABLE public.categories
            ADD CONSTRAINT categories_tax_affectation_check
            CHECK (default_tax_affectation_type IN ('10', '20', '21', '30', '40'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'products_tax_affectation_check'
    ) THEN
        ALTER TABLE public.products
            ADD CONSTRAINT products_tax_affectation_check
            CHECK (tax_affectation_type IN ('10', '20', '21', '30', '40'));
    END IF;
END $$;


-- ============================================================================
-- 2. CUADRE DE CAJA POR MÉTODO DE PAGO (DESDE order_payments)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_shift_payment_breakdown(p_shift_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_shift record;
    v_by_method jsonb;
    v_total_expenses numeric;
    v_total_incomes numeric;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado';
    END IF;

    SELECT * INTO v_shift FROM public.cash_shifts WHERE id = p_shift_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Turno de caja no encontrado.';
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
    INTO v_by_method
    FROM (
        SELECT
            op.payment_method,
            COUNT(*) AS transactions,
            SUM(op.amount) AS total_amount,
            SUM(op.amount_base) AS total_amount_base
        FROM public.order_payments op
        JOIN public.orders o ON o.id = op.order_id
        WHERE op.shift_id = p_shift_id
          AND o.status <> 'CANCELLED'
        GROUP BY op.payment_method
        ORDER BY total_amount_base DESC
    ) t;

    SELECT
        COALESCE(SUM(CASE WHEN movement_type IN ('INCOME', 'TRANSFER_IN') THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN movement_type IN ('EXPENSE', 'TRANSFER_OUT') THEN amount ELSE 0 END), 0)
    INTO v_total_incomes, v_total_expenses
    FROM public.account_movements
    WHERE shift_id = p_shift_id;

    RETURN jsonb_build_object(
        'shift_id', p_shift_id,
        'account_id', v_shift.account_id,
        'status', v_shift.status,
        'opening_amount', v_shift.opening_amount,
        'total_incomes', v_total_incomes,
        'total_expenses', v_total_expenses,
        'expected_closing', v_shift.opening_amount + v_total_incomes - v_total_expenses,
        'sales_by_payment_method', v_by_method
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_get_shift_payment_breakdown(uuid) TO authenticated, service_role;


-- ============================================================================
-- 3. CONTABILIZACIÓN AUTOMÁTICA DE VENTA A ASIENTO CONTABLE (PCGE)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_post_order_to_journal(p_order_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_profile_id uuid;
    v_order record;
    v_existing_id uuid;
    v_entry_id uuid;
    v_total_cost numeric := 0;
BEGIN
    SELECT id INTO v_profile_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin perfil válido.';
    END IF;
    IF NOT public.user_has_permission('accounting.manage') THEN
        RAISE EXCEPTION 'Sin permiso contable (accounting.manage).' USING ERRCODE = '42501';
    END IF;

    SELECT id INTO v_existing_id
    FROM public.journal_entries
    WHERE reference_type = 'orders' AND reference_id = p_order_id AND status = 'POSTED'
    LIMIT 1;
    IF v_existing_id IS NOT NULL THEN
        RETURN v_existing_id;
    END IF;

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND OR v_order.status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Orden inválida o anulada.';
    END IF;

    SELECT COALESCE(SUM(unit_cost_base * quantity), 0)
    INTO v_total_cost
    FROM public.order_items
    WHERE order_id = p_order_id;

    INSERT INTO public.journal_entries (
        entry_number, entry_date, description, reference_type, reference_id, created_by
    ) VALUES (
        'VTA-' || COALESCE(v_order.document_number, substring(p_order_id::text, 1, 8)),
        COALESCE(v_order.document_date, CURRENT_DATE),
        'Provisión venta ' || COALESCE(v_order.document_number, p_order_id::text),
        'orders', p_order_id, v_profile_id
    ) RETURNING id INTO v_entry_id;

    -- 1212 Cuentas por cobrar (Debe)
    INSERT INTO public.journal_entry_lines (journal_entry_id, account_code, description, debit, credit)
    VALUES (v_entry_id, '1212', 'Venta al cliente', v_order.total_amount_base, 0);

    -- 4011 IGV por pagar (Haber) si hay impuesto
    IF COALESCE(v_order.tax_amount_base, 0) > 0 THEN
        INSERT INTO public.journal_entry_lines (journal_entry_id, account_code, description, debit, credit)
        VALUES (v_entry_id, '4011', 'IGV Venta', 0, v_order.tax_amount_base);
    END IF;

    -- 7011 Ventas (Haber)
    INSERT INTO public.journal_entry_lines (journal_entry_id, account_code, description, debit, credit)
    VALUES (v_entry_id, '7011', 'Ingreso por venta', 0, v_order.total_amount_base - COALESCE(v_order.tax_amount_base, 0));

    -- Costo de ventas (6911 Debe / 2011 Haber)
    IF v_total_cost > 0 THEN
        INSERT INTO public.journal_entry_lines (journal_entry_id, account_code, description, debit, credit)
        VALUES
            (v_entry_id, '6911', 'Costo de ventas', ROUND(v_total_cost, 2), 0),
            (v_entry_id, '2011', 'Salida de mercaderías', 0, ROUND(v_total_cost, 2));
    END IF;

    RETURN v_entry_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_post_order_to_journal(uuid) TO authenticated, service_role;


-- ============================================================================
-- 4. VALIDACIÓN DE CONSTRAINTS NOT VALID (SI LOS DATOS ESTÁN LIMPIOS)
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'wsb_available_quantity_non_negative' AND NOT convalidated) THEN
        IF NOT EXISTS (SELECT 1 FROM public.warehouse_stock_batches WHERE available_quantity < 0) THEN
            ALTER TABLE public.warehouse_stock_batches VALIDATE CONSTRAINT wsb_available_quantity_non_negative;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'account_movements_movement_type_check' AND NOT convalidated) THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.account_movements
            WHERE movement_type NOT IN ('INCOME', 'EXPENSE', 'TRANSFER_IN', 'TRANSFER_OUT', 'ADJUSTMENT')
        ) THEN
            ALTER TABLE public.account_movements VALIDATE CONSTRAINT account_movements_movement_type_check;
        END IF;
    END IF;
END $$;

COMMIT;

