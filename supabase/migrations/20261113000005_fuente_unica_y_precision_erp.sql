-- ============================================================================
-- MIGRACIÓN 5: FUENTE ÚNICA DE VERDAD, PRECISIÓN MONETARIA Y CONTABILIDAD MULTI-LÍNEA
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. COMPROBANTES: UNA SOLA DIRECCIÓN Y REFERENCIA SUNAT PARA NOTAS
-- ============================================================================

-- Eliminar referencia circular (electronic_documents.order_id es la fuente de verdad)
ALTER TABLE public.orders
    DROP COLUMN IF EXISTS electronic_document_id;

-- Referencia al documento modificado (obligatorio SUNAT para Nota de Crédito/Débito)
ALTER TABLE public.electronic_documents
    ADD COLUMN IF NOT EXISTS reference_document_id uuid REFERENCES public.electronic_documents(id),
    ADD COLUMN IF NOT EXISTS reference_document_type text,
    ADD COLUMN IF NOT EXISTS reference_series text,
    ADD COLUMN IF NOT EXISTS reference_correlative text;

CREATE INDEX IF NOT EXISTS idx_edocs_reference_doc_id
    ON public.electronic_documents(reference_document_id);

-- Limpiar NOTA_CREDITO / NOTA_DEBITO de orders si no hay registros usándolos
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.orders WHERE document_type IN ('NOTA_CREDITO', 'NOTA_DEBITO')
    ) THEN
        ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_document_type_check;
        ALTER TABLE public.orders
            ADD CONSTRAINT orders_document_type_check
            CHECK (document_type IN ('NOTA_VENTA', 'BOLETA', 'FACTURA', 'TICKET', 'NINGUNO'));
    END IF;
END $$;


-- ============================================================================
-- 2. CLIENTES / PUNTOS: TRAZABILIDAD EN wallet_movements Y SALDO A FAVOR
-- ============================================================================

ALTER TABLE public.wallet_movements
    ADD COLUMN IF NOT EXISTS customer_id uuid REFERENCES public.customers(id);

CREATE INDEX IF NOT EXISTS idx_wallet_movements_customer_id
    ON public.wallet_movements(customer_id);

UPDATE public.wallet_movements wm
SET customer_id = c.id
FROM public.customers c
WHERE wm.profile_id = c.profile_id
  AND wm.customer_id IS NULL;

-- Permitir REFUND y ADJUSTMENT en customer_credit_movements (para saldo a favor / notas de crédito)
ALTER TABLE public.customer_credit_movements
    DROP CONSTRAINT IF EXISTS credit_movements_movement_type_check;
ALTER TABLE public.customer_credit_movements
    ADD CONSTRAINT credit_movements_movement_type_check
    CHECK (movement_type IN ('CHARGE', 'PAYMENT', 'REFUND', 'ADJUSTMENT'));


-- ============================================================================
-- 3. MÉTODOS DE PAGO: NORMALIZACIÓN Y FK OBLIGATORIA EN order_payments
-- ============================================================================

INSERT INTO public.payment_methods (code, name, method_type, requires_reference) VALUES
    ('CASH',   'Efectivo (alias)', 'CASH',   false),
    ('CREDIT', 'Crédito (alias)',  'CREDIT', false)
ON CONFLICT (code) DO NOTHING;

UPDATE public.order_payments
SET payment_method_code = CASE
    WHEN upper(trim(payment_method)) IN ('EFECTIVO', 'CASH') THEN 'EFECTIVO'
    WHEN upper(trim(payment_method)) = 'YAPE' THEN 'YAPE'
    WHEN upper(trim(payment_method)) = 'PLIN' THEN 'PLIN'
    WHEN upper(trim(payment_method)) IN ('TARJETA', 'CARD') THEN 'TARJETA'
    WHEN upper(trim(payment_method)) IN ('TRANSFERENCIA', 'TRANSFER') THEN 'TRANSFERENCIA'
    WHEN upper(trim(payment_method)) IN ('CREDITO', 'CRÉDITO', 'CREDIT') THEN 'CREDITO'
    ELSE 'EFECTIVO'
END
WHERE payment_method_code IS NULL;

ALTER TABLE public.order_payments
    ALTER COLUMN payment_method_code SET DEFAULT 'EFECTIVO',
    ALTER COLUMN payment_method_code SET NOT NULL;

CREATE OR REPLACE FUNCTION public.trg_sync_order_payment_method()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.payment_method_code IS NULL AND NEW.payment_method IS NOT NULL THEN
        NEW.payment_method_code := CASE
            WHEN upper(trim(NEW.payment_method)) IN ('EFECTIVO', 'CASH') THEN 'EFECTIVO'
            WHEN upper(trim(NEW.payment_method)) = 'YAPE' THEN 'YAPE'
            WHEN upper(trim(NEW.payment_method)) = 'PLIN' THEN 'PLIN'
            WHEN upper(trim(NEW.payment_method)) IN ('TARJETA', 'CARD') THEN 'TARJETA'
            WHEN upper(trim(NEW.payment_method)) IN ('TRANSFERENCIA', 'TRANSFER') THEN 'TRANSFERENCIA'
            WHEN upper(trim(NEW.payment_method)) IN ('CREDITO', 'CRÉDITO', 'CREDIT') THEN 'CREDITO'
            ELSE 'EFECTIVO'
        END;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_payments_sync_method ON public.order_payments;
CREATE TRIGGER trg_order_payments_sync_method
    BEFORE INSERT OR UPDATE ON public.order_payments
    FOR EACH ROW EXECUTE FUNCTION public.trg_sync_order_payment_method();


-- ============================================================================
-- 4. COMPRAS: PAGOS DE FACTURA Y CRUCE 3-WAY (OC <-> RECEPCIÓN <-> FACTURA)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.purchase_invoice_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    purchase_invoice_id uuid NOT NULL REFERENCES public.purchase_invoices(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES public.financial_accounts(id),
    shift_id uuid REFERENCES public.cash_shifts(id),
    payment_method_code text NOT NULL DEFAULT 'TRANSFERENCIA' REFERENCES public.payment_methods(code),
    amount numeric(14,2) NOT NULL CHECK (amount > 0),
    currency_code text NOT NULL DEFAULT 'PEN',
    exchange_rate numeric(12,4) NOT NULL DEFAULT 1.0000,
    amount_base numeric(14,2) NOT NULL DEFAULT 0.00,
    reference_number text,
    paid_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pi_payments_invoice_id ON public.purchase_invoice_payments(purchase_invoice_id);
CREATE INDEX IF NOT EXISTS idx_pi_payments_account_id ON public.purchase_invoice_payments(account_id);

ALTER TABLE public.purchase_invoice_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Pagos factura compra: Gestión por permiso" ON public.purchase_invoice_payments;
CREATE POLICY "Pagos factura compra: Gestión por permiso" ON public.purchase_invoice_payments FOR ALL TO authenticated
    USING (public.user_has_permission('finance.read'))
    WITH CHECK (public.user_has_permission('finance.manage'));

ALTER TABLE public.purchase_invoice_items
    ADD COLUMN IF NOT EXISTS purchase_order_item_id uuid REFERENCES public.purchase_order_items(id),
    ADD COLUMN IF NOT EXISTS inventory_entry_item_id uuid REFERENCES public.inventory_entry_items(id);

CREATE INDEX IF NOT EXISTS idx_pii_po_item_id ON public.purchase_invoice_items(purchase_order_item_id);
CREATE INDEX IF NOT EXISTS idx_pii_entry_item_id ON public.purchase_invoice_items(inventory_entry_item_id);


-- ============================================================================
-- 5. STOCK: SINCRONIZACIÓN AUTOMÁTICA DESDE LOTES (FUENTE ÚNICA DE VERDAD)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_sync_warehouse_variant_qty()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_wh_id uuid := COALESCE(NEW.warehouse_id, OLD.warehouse_id);
    v_var_id uuid := COALESCE(NEW.variant_id, OLD.variant_id);
    v_sum numeric(14,4);
BEGIN
    SELECT COALESCE(SUM(available_quantity), 0)
    INTO v_sum
    FROM public.warehouse_stock_batches
    WHERE warehouse_id = v_wh_id AND variant_id = v_var_id;

    INSERT INTO public.warehouse_variant_costs (warehouse_id, variant_id, total_quantity, updated_at)
    VALUES (v_wh_id, v_var_id, v_sum, now())
    ON CONFLICT (warehouse_id, variant_id)
    DO UPDATE SET total_quantity = v_sum, updated_at = now();

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_wsb_sync_variant_qty ON public.warehouse_stock_batches;
CREATE TRIGGER trg_wsb_sync_variant_qty
    AFTER INSERT OR UPDATE OR DELETE ON public.warehouse_stock_batches
    FOR EACH ROW EXECUTE FUNCTION public.trg_sync_warehouse_variant_qty();


-- ============================================================================
-- 6. RIESGOS SILENCIOSOS: COLUMNA GENERADA Y PRECISIÓN MONETARIA ESTANDARIZADA
-- ============================================================================

-- 6.1 Convertir order_items.quantity_base en columna GENERATED ALWAYS
ALTER TABLE public.order_items DROP COLUMN IF EXISTS quantity_base;
ALTER TABLE public.order_items
    ADD COLUMN quantity_base numeric(14,4) GENERATED ALWAYS AS (quantity * conversion_factor) STORED;

-- 6.2 Estandarizar precisión monetaria: (14,2) importes, (14,4) unitarios
DROP VIEW IF EXISTS public.customer_credit_movements_summary;

ALTER TABLE public.orders
    ALTER COLUMN total_amount TYPE numeric(14,2),
    ALTER COLUMN total_profit TYPE numeric(14,2),
    ALTER COLUMN discount_amount TYPE numeric(14,2),
    ALTER COLUMN amount_paid TYPE numeric(14,2),
    ALTER COLUMN tax_amount TYPE numeric(14,2),
    ALTER COLUMN subtotal_amount TYPE numeric(14,2),
    ALTER COLUMN total_amount_base TYPE numeric(14,2),
    ALTER COLUMN subtotal_amount_base TYPE numeric(14,2),
    ALTER COLUMN tax_amount_base TYPE numeric(14,2);

ALTER TABLE public.order_items
    ALTER COLUMN unit_cost TYPE numeric(14,4),
    ALTER COLUMN applied_price TYPE numeric(14,4),
    ALTER COLUMN unit_cost_base TYPE numeric(14,4),
    ALTER COLUMN applied_price_base TYPE numeric(14,4),
    ALTER COLUMN net_profit TYPE numeric(14,2);

ALTER TABLE public.order_payments
    ALTER COLUMN amount TYPE numeric(14,2),
    ALTER COLUMN amount_base TYPE numeric(14,2);

ALTER TABLE public.financial_accounts
    ALTER COLUMN balance TYPE numeric(14,2);

ALTER TABLE public.account_movements
    ALTER COLUMN amount TYPE numeric(14,2),
    ALTER COLUMN amount_base TYPE numeric(14,2);

-- Recrear vista dependiente
CREATE OR REPLACE VIEW public.customer_credit_movements_summary WITH (security_invoker = true) AS
SELECT
    cm.id,
    cm.customer_credit_id,
    cm.order_id,
    cm.movement_type,
    cm.amount,
    cm.payment_method,
    cm.notes,
    cm.created_at,
    cm.created_by,
    p.full_name AS created_by_name,
    o.customer_name,
    o.payment_method AS order_payment_method,
    o.total_amount AS order_total_amount,
    o.id::text AS order_number
FROM public.customer_credit_movements cm
LEFT JOIN public.profiles p ON p.id = cm.created_by
LEFT JOIN public.orders o ON o.id = cm.order_id;


-- ============================================================================
-- 7. CONTABILIDAD: REGLAS MULTI-LÍNEA (posting_rule_lines) Y period_id
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.accounting_posting_rule_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    rule_id uuid NOT NULL REFERENCES public.accounting_posting_rules(id) ON DELETE CASCADE,
    line_order integer NOT NULL DEFAULT 1,
    account_code text NOT NULL REFERENCES public.chart_of_accounts(code),
    side text NOT NULL CHECK (side IN ('DEBIT', 'CREDIT')),
    amount_source text NOT NULL CHECK (amount_source IN ('TOTAL', 'SUBTOTAL', 'TAX', 'COGS', 'DISCOUNT')),
    description_template text,
    UNIQUE (rule_id, line_order)
);

ALTER TABLE public.accounting_posting_rule_lines ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Líneas reglas contables: Lectura por permiso" ON public.accounting_posting_rule_lines;
CREATE POLICY "Líneas reglas contables: Lectura por permiso" ON public.accounting_posting_rule_lines FOR SELECT TO authenticated
    USING (public.user_has_permission('accounting.read'));
DROP POLICY IF EXISTS "Líneas reglas contables: Gestión por permiso" ON public.accounting_posting_rule_lines;
CREATE POLICY "Líneas reglas contables: Gestión por permiso" ON public.accounting_posting_rule_lines FOR ALL TO authenticated
    USING (public.user_has_permission('accounting.manage'))
    WITH CHECK (public.user_has_permission('accounting.manage'));

-- Poblar líneas multi-cuenta para reglas existentes
INSERT INTO public.accounting_posting_rule_lines (rule_id, line_order, account_code, side, amount_source, description_template)
SELECT r.id, v.line_order, v.account_code, v.side, v.amount_source, v.descr
FROM public.accounting_posting_rules r
JOIN (VALUES
    ('POS_SALE', 1, '1212', 'DEBIT',  'TOTAL',    'Cuenta por cobrar venta'),
    ('POS_SALE', 2, '4011', 'CREDIT', 'TAX',      'IGV por pagar'),
    ('POS_SALE', 3, '7011', 'CREDIT', 'SUBTOTAL', 'Ingreso por ventas'),
    ('POS_COGS', 1, '6911', 'DEBIT',  'COGS',     'Costo de ventas'),
    ('POS_COGS', 2, '2011', 'CREDIT', 'COGS',     'Salida de mercaderías'),
    ('PURCHASE_INVOICE', 1, '6011', 'DEBIT',  'SUBTOTAL', 'Compra de mercaderías'),
    ('PURCHASE_INVOICE', 2, '4011', 'DEBIT',  'TAX',      'IGV crédito fiscal'),
    ('PURCHASE_INVOICE', 3, '4212', 'CREDIT', 'TOTAL',    'Factura por pagar proveedor'),
    ('OPERATING_EXPENSE', 1, '6399', 'DEBIT',  'TOTAL',   'Gasto operativo'),
    ('OPERATING_EXPENSE', 2, '1011', 'CREDIT', 'TOTAL',   'Salida de efectivo/banco')
) AS v(event_code, line_order, account_code, side, amount_source, descr)
ON r.event_code = v.event_code
ON CONFLICT (rule_id, line_order) DO NOTHING;

-- Agregar period_id a journal_entries y enlazarlo automáticamente en el trigger
ALTER TABLE public.journal_entries
    ADD COLUMN IF NOT EXISTS period_id uuid REFERENCES public.accounting_periods(id);

CREATE INDEX IF NOT EXISTS idx_journal_entries_period_id ON public.journal_entries(period_id);

CREATE OR REPLACE FUNCTION public.trg_journal_balanced_and_period()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_debit numeric;
    v_credit numeric;
    v_period_id uuid;
    v_period_status text;
BEGIN
    SELECT id, status INTO v_period_id, v_period_status
    FROM public.accounting_periods
    WHERE year = EXTRACT(YEAR FROM NEW.entry_date)::int
      AND month = EXTRACT(MONTH FROM NEW.entry_date)::int;

    IF v_period_status = 'CLOSED' THEN
        RAISE EXCEPTION 'El periodo contable %-% está CERRADO.', EXTRACT(YEAR FROM NEW.entry_date), EXTRACT(MONTH FROM NEW.entry_date);
    END IF;

    IF NEW.period_id IS NULL AND v_period_id IS NOT NULL THEN
        NEW.period_id := v_period_id;
    END IF;

    IF NEW.status = 'POSTED' AND (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM 'POSTED') THEN
        SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
        INTO v_debit, v_credit
        FROM public.journal_entry_lines
        WHERE journal_entry_id = NEW.id;

        IF v_debit <= 0 OR ABS(v_debit - v_credit) > 0.01 THEN
            RAISE EXCEPTION 'Asiento % descuadrado: Debe (%) <> Haber (%)', NEW.id, v_debit, v_credit;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

COMMIT;

