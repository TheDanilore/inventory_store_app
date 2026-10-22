-- ==============================================================================
-- MIGRACIÓN: Sistema Multimoneda Dinámico, Configurable e Inmutable
-- Ámbitos: Configuración, Compras, Entradas/Salidas, Kárdex, Finanzas y POS
-- ==============================================================================

-- 1. TABLA DINÁMICA DE MONEDAS (Configurable por usuarios con permiso settings.edit)
CREATE TABLE IF NOT EXISTS public.currencies (
    code text PRIMARY KEY,                       -- 'PEN', 'USD', 'EUR', etc.
    name text NOT NULL,                          -- 'Soles Peruanos', 'Dólares Americanos'
    symbol text NOT NULL,                        -- 'S/ ', '$ ', '€ '
    suggested_exchange_rate numeric(12,4) DEFAULT 1.0000 NOT NULL, -- TC sugerido respecto a moneda base
    is_base boolean DEFAULT false NOT NULL,      -- Solo una moneda es la base contable (PEN)
    is_active boolean DEFAULT true NOT NULL,
    decimal_places int DEFAULT 2 NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Garantizar exactamente una sola moneda base en el sistema
CREATE UNIQUE INDEX IF NOT EXISTS idx_currencies_unique_base 
    ON public.currencies (is_base) 
    WHERE is_base = true;

-- RLS de Currencies estrictamente basada en permisos
ALTER TABLE public.currencies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura de monedas para personal autenticado" ON public.currencies;
DROP POLICY IF EXISTS "Administración de monedas por settings.edit" ON public.currencies;

CREATE POLICY "Lectura de monedas para personal autenticado"
    ON public.currencies FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Administración de monedas por settings.edit"
    ON public.currencies FOR ALL
    TO authenticated
    USING (public.user_has_permission('settings.edit'))
    WITH CHECK (public.user_has_permission('settings.edit'));

-- Insertar monedas iniciales
INSERT INTO public.currencies (code, name, symbol, suggested_exchange_rate, is_base, is_active, decimal_places)
VALUES 
    ('PEN', 'Soles Peruanos', 'S/ ', 1.0000, true, true, 2),
    ('USD', 'Dólares Americanos', '$ ', 3.7500, false, true, 2),
    ('EUR', 'Euros', '€ ', 4.1000, false, false, 2)
ON CONFLICT (code) DO UPDATE
SET suggested_exchange_rate = EXCLUDED.suggested_exchange_rate
WHERE currencies.code = 'USD' AND currencies.suggested_exchange_rate = 1.0000;

-- ==============================================================================
-- 2. CUENTAS FINANCIERAS Y MOVIMIENTOS DE CAJA / BANCOS
-- ==============================================================================
ALTER TABLE public.financial_accounts 
    ADD COLUMN IF NOT EXISTS currency_code text DEFAULT 'PEN' REFERENCES public.currencies(code);

ALTER TABLE public.account_movements 
    ADD COLUMN IF NOT EXISTS currency_code text DEFAULT 'PEN' REFERENCES public.currencies(code),
    ADD COLUMN IF NOT EXISTS exchange_rate numeric(12,4) DEFAULT 1.0000 NOT NULL,
    ADD COLUMN IF NOT EXISTS amount_base numeric DEFAULT 0.00 NOT NULL;

-- Backfill retroactivo seguro
UPDATE public.account_movements 
SET amount_base = amount 
WHERE amount_base = 0.00 AND amount > 0;

-- ==============================================================================
-- 3. COMPRAS A PROVEEDORES (purchase_orders y purchase_order_items)
-- ==============================================================================
ALTER TABLE public.purchase_orders 
    ADD COLUMN IF NOT EXISTS currency_code text DEFAULT 'PEN' REFERENCES public.currencies(code),
    ADD COLUMN IF NOT EXISTS exchange_rate numeric(12,4) DEFAULT 1.0000 NOT NULL,
    ADD COLUMN IF NOT EXISTS total_amount_base numeric DEFAULT 0.00 NOT NULL,
    ADD COLUMN IF NOT EXISTS subtotal_amount_base numeric DEFAULT 0.00 NOT NULL,
    ADD COLUMN IF NOT EXISTS tax_amount_base numeric DEFAULT 0.00 NOT NULL;

UPDATE public.purchase_orders 
SET total_amount_base = total_amount,
    subtotal_amount_base = COALESCE(subtotal_amount, total_amount),
    tax_amount_base = COALESCE(tax_amount, 0.00)
WHERE total_amount_base = 0.00 AND total_amount > 0;

ALTER TABLE public.purchase_order_items 
    ADD COLUMN IF NOT EXISTS unit_cost_base numeric DEFAULT 0.00 NOT NULL;

UPDATE public.purchase_order_items 
SET unit_cost_base = unit_cost 
WHERE unit_cost_base = 0.00 AND unit_cost > 0;

-- ==============================================================================
-- 4. ENTRADAS Y SALIDAS DE INVENTARIO (inventory_entries y items)
-- ==============================================================================
ALTER TABLE public.inventory_entries 
    ADD COLUMN IF NOT EXISTS currency_code text DEFAULT 'PEN' REFERENCES public.currencies(code),
    ADD COLUMN IF NOT EXISTS exchange_rate numeric(12,4) DEFAULT 1.0000 NOT NULL,
    ADD COLUMN IF NOT EXISTS total_amount_base numeric DEFAULT 0.00 NOT NULL;

UPDATE public.inventory_entries 
SET total_amount_base = total_amount 
WHERE total_amount_base = 0.00 AND total_amount > 0;

ALTER TABLE public.inventory_entry_items 
    ADD COLUMN IF NOT EXISTS unit_cost_base numeric DEFAULT 0.00 NOT NULL;

UPDATE public.inventory_entry_items 
SET unit_cost_base = unit_cost 
WHERE unit_cost_base = 0.00 AND unit_cost > 0;

-- ==============================================================================
-- 5. KÁRDEX VALORIZADO (Trazabilidad cambiaria y costo base)
-- ==============================================================================
ALTER TABLE public.kardex_movements 
    ADD COLUMN IF NOT EXISTS currency_code text DEFAULT 'PEN',
    ADD COLUMN IF NOT EXISTS exchange_rate numeric(12,4) DEFAULT 1.0000 NOT NULL;

-- ==============================================================================
-- 6. VENTAS Y FACTURACIÓN POS (orders y order_items)
-- ==============================================================================
ALTER TABLE public.orders 
    ADD COLUMN IF NOT EXISTS currency_code text DEFAULT 'PEN' REFERENCES public.currencies(code),
    ADD COLUMN IF NOT EXISTS exchange_rate numeric(12,4) DEFAULT 1.0000 NOT NULL,
    ADD COLUMN IF NOT EXISTS total_amount_base numeric DEFAULT 0.00 NOT NULL,
    ADD COLUMN IF NOT EXISTS subtotal_amount_base numeric DEFAULT 0.00 NOT NULL,
    ADD COLUMN IF NOT EXISTS tax_amount_base numeric DEFAULT 0.00 NOT NULL;

UPDATE public.orders 
SET total_amount_base = total_amount,
    subtotal_amount_base = subtotal_amount,
    tax_amount_base = tax_amount
WHERE total_amount_base = 0.00 AND total_amount > 0;

ALTER TABLE public.order_items 
    ADD COLUMN IF NOT EXISTS applied_price_base numeric DEFAULT 0.00 NOT NULL,
    ADD COLUMN IF NOT EXISTS unit_cost_base numeric DEFAULT 0.00 NOT NULL;

UPDATE public.order_items 
SET applied_price_base = applied_price, unit_cost_base = unit_cost 
WHERE applied_price_base = 0.00 AND applied_price > 0;

-- ==============================================================================
-- 7. RPC ATÓMICA DE ÓRDENES DE COMPRA MULTIMONEDA CON PERMISOS GRANULARES
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.create_purchase_order_rpc(
    p_supplier_id uuid,
    p_supplier_name text,
    p_warehouse_id uuid,
    p_total_amount numeric,
    p_payment_method text,
    p_payment_status text,
    p_account_id uuid,
    p_active_shift_id uuid,
    p_due_date date,
    p_document_date date,
    p_document_type text,
    p_document_number text,
    p_notes text,
    p_profile_id uuid,
    p_items jsonb,
    p_currency_code text DEFAULT 'PEN',
    p_exchange_rate numeric DEFAULT 1.0000
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
    v_po_id UUID;
    v_item JSONB;
    v_credit_id UUID;
    v_credit_limit NUMERIC;
    v_current_debt NUMERIC;
    v_credit_active BOOLEAN;
    v_acc_balance NUMERIC;
    v_acc_type TEXT;
    v_acc_name TEXT;
    v_acc_currency TEXT;
    v_shift_status TEXT;
    v_real_debt NUMERIC;
    v_po_debt NUMERIC;
    v_item_subtotal NUMERIC;
    v_rate NUMERIC;
    v_total_base NUMERIC;
    v_deduct_amount NUMERIC;
BEGIN
    -- 0. Verificación de permisos granulares (requiere purchases.create)
    IF NOT public.user_has_permission('purchases.create') THEN
        RETURN jsonb_build_object('success', false, 'error', 'No cuenta con el permiso requerido para registrar órdenes de compra (purchases.create).');
    END IF;

    -- Extraer Profile ID (Auditoría) si no se provee
    IF p_profile_id IS NULL THEN
        SELECT id INTO p_profile_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    END IF;

    v_rate := COALESCE(p_exchange_rate, 1.0000);
    IF v_rate <= 0 THEN
        v_rate := 1.0000;
    END IF;
    v_total_base := p_total_amount * v_rate;

    -- 1. Validar límite de crédito si la orden queda en Pago Pendiente o es CRÉDITO
    IF p_payment_method = 'CRÉDITO' OR p_payment_status = 'PENDING' THEN
        SELECT id, credit_limit, current_debt, is_active 
        INTO v_credit_id, v_credit_limit, v_current_debt, v_credit_active
        FROM public.supplier_credits
        WHERE supplier_id = p_supplier_id
        FOR UPDATE;

        IF NOT FOUND AND p_payment_method = 'CRÉDITO' THEN
            RETURN jsonb_build_object('success', false, 'error', 'El proveedor no tiene una línea de crédito habilitada.');
        END IF;

        IF v_credit_id IS NOT NULL THEN
            IF NOT v_credit_active AND p_payment_method = 'CRÉDITO' THEN
                RETURN jsonb_build_object('success', false, 'error', 'La línea de crédito con este proveedor se encuentra inactiva.');
            END IF;

            IF p_payment_method = 'CRÉDITO' AND v_credit_limit <= 0 THEN
                RETURN jsonb_build_object('success', false, 'error', 'El proveedor tiene un límite de crédito de S/ 0.00.');
            END IF;

            -- Calcular deuda real (sumando OCs pendientes valorizadas en moneda base)
            SELECT COALESCE(SUM(total_amount_base - (COALESCE(amount_paid, 0) * exchange_rate)), 0) INTO v_po_debt
            FROM public.purchase_orders
            WHERE supplier_id = p_supplier_id 
              AND payment_status IN ('PENDING', 'PARTIAL')
              AND status != 'CANCELLED';

            v_real_debt := GREATEST(v_current_debt, v_po_debt);

            IF v_credit_limit > 0 AND (v_real_debt + v_total_base) > v_credit_limit THEN
                RETURN jsonb_build_object(
                    'success', false, 
                    'error', 'Límite de crédito excedido. Disponible: S/ ' || ROUND((v_credit_limit - v_real_debt), 2) || ', Monto base orden: S/ ' || ROUND(v_total_base, 2)
                );
            END IF;
        END IF;
    END IF;

    -- 2. Validar saldo suficiente y turno de caja abierto si es PAID
    IF p_payment_status = 'PAID' THEN
        IF p_account_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Debe seleccionar una cuenta origen para registrar el pago.');
        END IF;

        SELECT name, type, balance, currency_code 
        INTO v_acc_name, v_acc_type, v_acc_balance, v_acc_currency
        FROM public.financial_accounts
        WHERE id = p_account_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'La cuenta financiera seleccionada no existe.');
        END IF;

        -- Calcular deducción según la moneda de la cuenta
        IF v_acc_currency = p_currency_code THEN
            v_deduct_amount := p_total_amount;
        ELSEIF v_acc_currency = 'PEN' THEN
            v_deduct_amount := v_total_base;
        ELSEIF p_currency_code = 'PEN' THEN
            v_deduct_amount := p_total_amount / v_rate;
        ELSE
            v_deduct_amount := v_total_base;
        END IF;

        IF v_acc_balance < v_deduct_amount THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Saldo insuficiente en la cuenta "' || v_acc_name || '". Saldo disponible: ' || COALESCE(v_acc_currency, 'PEN') || ' ' || ROUND(v_acc_balance, 2) || ', Requerido: ' || ROUND(v_deduct_amount, 2)
            );
        END IF;

        IF v_acc_type = 'CAJA' THEN
            IF p_active_shift_id IS NULL THEN
                SELECT id INTO p_active_shift_id 
                FROM public.cash_shifts 
                WHERE account_id = p_account_id AND status = 'OPEN' 
                LIMIT 1;
            END IF;

            IF p_active_shift_id IS NULL THEN
                RETURN jsonb_build_object('success', false, 'error', 'No hay un turno de caja abierto para la cuenta "' || v_acc_name || '".');
            END IF;

            SELECT status INTO v_shift_status FROM public.cash_shifts WHERE id = p_active_shift_id;
            IF v_shift_status != 'OPEN' THEN
                RETURN jsonb_build_object('success', false, 'error', 'El turno de caja especificado ya no está abierto.');
            END IF;
        END IF;
    END IF;

    -- 3. Inserción de la Orden de Compra
    INSERT INTO public.purchase_orders (
        supplier_id, supplier_name, warehouse_id, total_amount, 
        payment_method, payment_status, due_date, document_date, 
        document_type, document_number, notes, created_by, status,
        amount_paid, currency_code, exchange_rate, total_amount_base
    ) VALUES (
        p_supplier_id, p_supplier_name, p_warehouse_id, p_total_amount, 
        p_payment_method, p_payment_status, p_due_date, p_document_date, 
        p_document_type, p_document_number, p_notes, p_profile_id, 'PENDING',
        CASE WHEN p_payment_status = 'PAID' THEN p_total_amount ELSE 0 END,
        p_currency_code, v_rate, v_total_base
    ) RETURNING id INTO v_po_id;

    -- 4. Inserción de los Ítems
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_item_subtotal := ((v_item->>'quantity')::NUMERIC * (v_item->>'unit_cost')::NUMERIC);

        INSERT INTO public.purchase_order_items (
            purchase_order_id, 
            product_id, 
            variant_id, 
            quantity_ordered, 
            unit_cost, 
            net_cost,
            subtotal, 
            batch_number, 
            expiry_date,
            unit_cost_base
        ) VALUES (
            v_po_id, 
            (v_item->>'product_id')::UUID, 
            NULLIF(v_item->>'variant_id', '')::UUID, 
            (v_item->>'quantity')::NUMERIC, 
            (v_item->>'unit_cost')::NUMERIC, 
            (v_item->>'unit_cost')::NUMERIC,
            v_item_subtotal,
            COALESCE(v_item->>'batch_number', 'DEFAULT'), 
            CASE WHEN (v_item->>'expiry_date') IS NOT NULL AND (v_item->>'expiry_date') != ''
                 THEN (v_item->>'expiry_date')::DATE 
                 ELSE NULL END,
            ((v_item->>'unit_cost')::NUMERIC * v_rate)
        );
    END LOOP;

    -- 5. Operaciones Financieras / Movimientos
    IF p_payment_status = 'PAID' THEN
        UPDATE public.financial_accounts
        SET balance = balance - v_deduct_amount,
            updated_at = NOW()
        WHERE id = p_account_id;

        INSERT INTO public.account_movements (
            account_id, shift_id, movement_type, amount, description, reference_type, reference_id, created_by,
            currency_code, exchange_rate, amount_base
        ) VALUES (
            p_account_id, p_active_shift_id, 'EXPENSE', v_deduct_amount, 
            'Pago OC #' || left(v_po_id::text, 8), 
            'PURCHASE_ORDER', v_po_id, p_profile_id,
            v_acc_currency, v_rate, (v_deduct_amount * CASE WHEN v_acc_currency = 'PEN' THEN 1.0 ELSE v_rate END)
        );
    END IF;

    -- 6. Actualización de Deuda en Línea de Crédito
    IF p_payment_method = 'CRÉDITO' OR p_payment_status = 'PENDING' THEN
        IF v_credit_id IS NOT NULL THEN
            UPDATE public.supplier_credits
            SET current_debt = current_debt + v_total_base,
                updated_at = NOW()
            WHERE id = v_credit_id;

            INSERT INTO public.supplier_credit_movements (
                credit_id, movement_type, amount, reference_id, notes, created_by
            ) VALUES (
                v_credit_id, 'DEUDA', v_total_base, v_po_id, 'Generación de deuda por OC #' || left(v_po_id::text, 8), p_profile_id
            );
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'id', v_po_id);
END;
$$;
