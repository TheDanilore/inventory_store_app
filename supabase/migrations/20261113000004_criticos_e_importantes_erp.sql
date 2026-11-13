-- ============================================================================
-- MIGRACIÓN 4: CORRECCIONES CRÍTICAS E IMPORTANTES DE AUDITORÍA ERP
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. SEGURIDAD: ELIMINAR VISTA EXPUESTA profiles_with_email
--    (Reemplazada por RPC protegido public.get_profiles_with_email())
-- ============================================================================

DROP VIEW IF EXISTS public.profiles_with_email;


-- ============================================================================
-- 2. TERMINAR MIGRACIÓN DE CLIENTES (customers vs profiles) SIN ROMPER FLUTTER
-- ============================================================================

-- Permitir clientes de negocio sin cuenta en auth.users (profile_id opcional)
ALTER TABLE public.customer_credits
    ALTER COLUMN profile_id DROP NOT NULL;

ALTER TABLE public.customer_locations
    ALTER COLUMN profile_id DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customer_credits_owner_check') THEN
        ALTER TABLE public.customer_credits
            ADD CONSTRAINT customer_credits_owner_check
            CHECK (profile_id IS NOT NULL OR customer_record_id IS NOT NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customer_locations_owner_check') THEN
        ALTER TABLE public.customer_locations
            ADD CONSTRAINT customer_locations_owner_check
            CHECK (profile_id IS NOT NULL OR customer_record_id IS NOT NULL);
    END IF;
END $$;

-- Trigger de sincronización bidireccional durante la transición
CREATE OR REPLACE FUNCTION public.trg_sync_customer_record_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cid uuid;
    v_pid uuid;
BEGIN
    IF TG_TABLE_NAME = 'orders' THEN
        IF NEW.customer_record_id IS NULL AND NEW.customer_id IS NOT NULL THEN
            SELECT id INTO v_cid FROM public.customers WHERE profile_id = NEW.customer_id LIMIT 1;
            NEW.customer_record_id := v_cid;
        ELSIF NEW.customer_id IS NULL AND NEW.customer_record_id IS NOT NULL THEN
            SELECT profile_id INTO v_pid FROM public.customers WHERE id = NEW.customer_record_id LIMIT 1;
            NEW.customer_id := v_pid;
        END IF;
    ELSE
        -- customer_credits, customer_locations
        IF NEW.customer_record_id IS NULL AND NEW.profile_id IS NOT NULL THEN
            SELECT id INTO v_cid FROM public.customers WHERE profile_id = NEW.profile_id LIMIT 1;
            NEW.customer_record_id := v_cid;
        ELSIF NEW.profile_id IS NULL AND NEW.customer_record_id IS NOT NULL THEN
            SELECT profile_id INTO v_pid FROM public.customers WHERE id = NEW.customer_record_id LIMIT 1;
            NEW.profile_id := v_pid;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_sync_customer ON public.orders;
CREATE TRIGGER trg_orders_sync_customer
    BEFORE INSERT OR UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.trg_sync_customer_record_id();

DROP TRIGGER IF EXISTS trg_customer_credits_sync_customer ON public.customer_credits;
CREATE TRIGGER trg_customer_credits_sync_customer
    BEFORE INSERT OR UPDATE ON public.customer_credits
    FOR EACH ROW EXECUTE FUNCTION public.trg_sync_customer_record_id();

DROP TRIGGER IF EXISTS trg_customer_locations_sync_customer ON public.customer_locations;
CREATE TRIGGER trg_customer_locations_sync_customer
    BEFORE INSERT OR UPDATE ON public.customer_locations
    FOR EACH ROW EXECUTE FUNCTION public.trg_sync_customer_record_id();

-- Actualizar partner_credit_summary para leer desde customers y fallback a profiles
CREATE OR REPLACE VIEW public.partner_credit_summary WITH (security_invoker = true) AS
SELECT
    cc.id AS credit_id,
    cc.profile_id,
    COALESCE(c.full_name, p.full_name) AS partner_name,
    COALESCE(c.document_number, p.document_number) AS partner_document,
    COALESCE(c.document_type, p.document_type) AS partner_document_type,
    COALESCE(c.phone, p.phone) AS partner_phone,
    cc.credit_limit,
    cc.current_debt,
    GREATEST(cc.credit_limit - cc.current_debt, 0::numeric) AS available_credit,
    cc.is_active,
    cc.customer_record_id
FROM public.customer_credits cc
LEFT JOIN public.customers c ON c.id = cc.customer_record_id
LEFT JOIN public.profiles p ON p.id = cc.profile_id;


-- ============================================================================
-- 3. UNIFICACIÓN DEL DOCUMENTO TRIBUTARIO (electronic_documents)
-- ============================================================================

ALTER TABLE public.electronic_documents
    ADD COLUMN IF NOT EXISTS issue_date timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS customer_snapshot jsonb,
    ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS electronic_document_id uuid REFERENCES public.electronic_documents(id);

-- Un único comprobante activo (BOLETA/FACTURA) por orden
CREATE UNIQUE INDEX IF NOT EXISTS uq_edoc_active_order_boleta_factura
    ON public.electronic_documents (order_id)
    WHERE order_id IS NOT NULL
      AND document_type IN ('BOLETA', 'FACTURA')
      AND is_active = true
      AND sunat_status <> 'VOIDED';


-- ============================================================================
-- 4. CONTABILIDAD: CUADRE OBLIGATORIO, PERIODOS Y REGLAS DE CONTABILIZACIÓN
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.accounting_periods (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    year integer NOT NULL CHECK (year BETWEEN 2020 AND 2100),
    month integer NOT NULL CHECK (month BETWEEN 1 AND 12),
    status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED')),
    closed_by uuid REFERENCES public.profiles(id),
    closed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (year, month)
);

CREATE TABLE IF NOT EXISTS public.accounting_posting_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    event_code text NOT NULL UNIQUE,
    description text NOT NULL,
    debit_account_code text NOT NULL REFERENCES public.chart_of_accounts(code),
    credit_account_code text NOT NULL REFERENCES public.chart_of_accounts(code),
    tax_account_code text REFERENCES public.chart_of_accounts(code),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.accounting_posting_rules (event_code, description, debit_account_code, credit_account_code, tax_account_code) VALUES
    ('POS_SALE', 'Venta POS / Comprobante', '1212', '7011', '4011'),
    ('POS_COGS', 'Costo de Ventas POS', '6911', '2011', NULL),
    ('PURCHASE_INVOICE', 'Factura de Compra', '6011', '4212', '4011'),
    ('OPERATING_EXPENSE', 'Gasto Operativo', '6399', '1011', NULL)
ON CONFLICT (event_code) DO NOTHING;

ALTER TABLE public.accounting_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounting_posting_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Periodos contables: Lectura por permiso" ON public.accounting_periods;
CREATE POLICY "Periodos contables: Lectura por permiso" ON public.accounting_periods FOR SELECT TO authenticated
    USING (public.user_has_permission('accounting.read'));
DROP POLICY IF EXISTS "Periodos contables: Gestión por permiso" ON public.accounting_periods;
CREATE POLICY "Periodos contables: Gestión por permiso" ON public.accounting_periods FOR ALL TO authenticated
    USING (public.user_has_permission('accounting.manage'))
    WITH CHECK (public.user_has_permission('accounting.manage'));

DROP POLICY IF EXISTS "Reglas contables: Lectura por permiso" ON public.accounting_posting_rules;
CREATE POLICY "Reglas contables: Lectura por permiso" ON public.accounting_posting_rules FOR SELECT TO authenticated
    USING (public.user_has_permission('accounting.read'));
DROP POLICY IF EXISTS "Reglas contables: Gestión por permiso" ON public.accounting_posting_rules;
CREATE POLICY "Reglas contables: Gestión por permiso" ON public.accounting_posting_rules FOR ALL TO authenticated
    USING (public.user_has_permission('accounting.manage'))
    WITH CHECK (public.user_has_permission('accounting.manage'));

-- Trigger que garantiza Debe == Haber al contabilizar (POSTED) y bloquea periodos cerrados
CREATE OR REPLACE FUNCTION public.trg_journal_balanced_and_period()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_debit numeric;
    v_credit numeric;
    v_period_status text;
BEGIN
    SELECT status INTO v_period_status
    FROM public.accounting_periods
    WHERE year = EXTRACT(YEAR FROM NEW.entry_date)::int
      AND month = EXTRACT(MONTH FROM NEW.entry_date)::int;

    IF v_period_status = 'CLOSED' THEN
        RAISE EXCEPTION 'El periodo contable %-% está CERRADO.', EXTRACT(YEAR FROM NEW.entry_date), EXTRACT(MONTH FROM NEW.entry_date);
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

DROP TRIGGER IF EXISTS trg_journal_entries_validate ON public.journal_entries;
CREATE TRIGGER trg_journal_entries_validate
    BEFORE INSERT OR UPDATE ON public.journal_entries
    FOR EACH ROW EXECUTE FUNCTION public.trg_journal_balanced_and_period();


-- ============================================================================
-- 5. CATÁLOGO DE MÉTODOS DE PAGO Y UNIDADES EN order_items
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.payment_methods (
    code text PRIMARY KEY,
    name text NOT NULL,
    method_type text NOT NULL CHECK (method_type IN ('CASH', 'DIGITAL', 'CARD', 'TRANSFER', 'CREDIT')),
    default_account_id uuid REFERENCES public.financial_accounts(id),
    requires_reference boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.payment_methods (code, name, method_type, requires_reference) VALUES
    ('EFECTIVO',      'Efectivo',             'CASH',     false),
    ('YAPE',          'Yape',                 'DIGITAL',  true),
    ('PLIN',          'Plin',                 'DIGITAL',  true),
    ('TARJETA',       'Tarjeta Crédito/Débito','CARD',    true),
    ('TRANSFERENCIA', 'Transferencia Bancaria','TRANSFER', true),
    ('CREDITO',       'Crédito Cliente',      'CREDIT',   false),
    ('MIXTO',         'Pago Mixto',           'CASH',     false)
ON CONFLICT (code) DO NOTHING;

ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Métodos de pago: Lectura autenticada" ON public.payment_methods;
CREATE POLICY "Métodos de pago: Lectura autenticada" ON public.payment_methods FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Métodos de pago: Gestión por permiso" ON public.payment_methods;
CREATE POLICY "Métodos de pago: Gestión por permiso" ON public.payment_methods FOR ALL TO authenticated
    USING (public.user_has_permission('finance.manage'))
    WITH CHECK (public.user_has_permission('finance.manage'));

ALTER TABLE public.order_payments
    ADD COLUMN IF NOT EXISTS payment_method_code text REFERENCES public.payment_methods(code);

-- Unidades y factor de conversión en order_items
ALTER TABLE public.order_items
    ADD COLUMN IF NOT EXISTS unit_code text NOT NULL DEFAULT 'NIU' REFERENCES public.units_of_measure(code),
    ADD COLUMN IF NOT EXISTS conversion_factor numeric(12,4) NOT NULL DEFAULT 1.0000 CHECK (conversion_factor > 0),
    ADD COLUMN IF NOT EXISTS quantity_base numeric(14,4) NOT NULL DEFAULT 0;

UPDATE public.order_items
SET quantity_base = quantity * conversion_factor
WHERE quantity_base = 0;


-- ============================================================================
-- 6. COSTEO PROMEDIO PONDERADO POR ALMACÉN (SIMPLIFICADO Y REAL)
-- ============================================================================

UPDATE public.product_variants
SET costing_method = 'WEIGHTED_AVG'
WHERE costing_method IN ('FIFO', 'FEFO');

ALTER TABLE public.product_variants DROP CONSTRAINT IF EXISTS product_variants_costing_method_check;
ALTER TABLE public.product_variants
    ADD CONSTRAINT product_variants_costing_method_check
    CHECK (costing_method IN ('WEIGHTED_AVG', 'STANDARD'));

CREATE TABLE IF NOT EXISTS public.warehouse_variant_costs (
    warehouse_id uuid NOT NULL REFERENCES public.warehouses(id) ON DELETE CASCADE,
    variant_id uuid NOT NULL REFERENCES public.product_variants(id) ON DELETE CASCADE,
    average_cost numeric(14,4) NOT NULL DEFAULT 0.0000 CHECK (average_cost >= 0),
    total_quantity numeric(14,4) NOT NULL DEFAULT 0.0000 CHECK (total_quantity >= 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (warehouse_id, variant_id)
);

ALTER TABLE public.warehouse_variant_costs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Costos por almacén: Lectura por permiso" ON public.warehouse_variant_costs;
CREATE POLICY "Costos por almacén: Lectura por permiso" ON public.warehouse_variant_costs FOR SELECT TO authenticated
    USING (public.user_has_permission('inventory.read') OR public.user_has_permission('pos.sale'));
DROP POLICY IF EXISTS "Costos por almacén: Gestión por permiso" ON public.warehouse_variant_costs;
CREATE POLICY "Costos por almacén: Gestión por permiso" ON public.warehouse_variant_costs FOR ALL TO authenticated
    USING (public.user_has_permission('inventory.manage'))
    WITH CHECK (public.user_has_permission('inventory.manage'));


-- ============================================================================
-- 7. FACTURAS DE COMPRA (purchase_invoices) SEPARADAS DE ORDEN DE COMPRA
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.purchase_invoices (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    purchase_order_id uuid REFERENCES public.purchase_orders(id),
    supplier_id uuid NOT NULL REFERENCES public.suppliers(id),
    document_type text NOT NULL CHECK (document_type IN ('FACTURA', 'BOLETA', 'RECIBO_HONORARIOS', 'NOTA_CREDITO', 'OTRO')),
    series text NOT NULL,
    document_number text NOT NULL,
    issue_date date NOT NULL,
    due_date date,
    currency_code text NOT NULL DEFAULT 'PEN',
    exchange_rate numeric(12,4) NOT NULL DEFAULT 1.0000,
    taxable_amount numeric(14,2) NOT NULL DEFAULT 0.00,
    tax_amount numeric(14,2) NOT NULL DEFAULT 0.00,
    exempt_amount numeric(14,2) NOT NULL DEFAULT 0.00,
    total_amount numeric(14,2) NOT NULL DEFAULT 0.00,
    amount_paid numeric(14,2) NOT NULL DEFAULT 0.00,
    payment_status text NOT NULL DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PARTIAL', 'PAID', 'CANCELLED')),
    created_by uuid REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (supplier_id, document_type, series, document_number)
);

CREATE TABLE IF NOT EXISTS public.purchase_invoice_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    purchase_invoice_id uuid NOT NULL REFERENCES public.purchase_invoices(id) ON DELETE CASCADE,
    variant_id uuid REFERENCES public.product_variants(id),
    description text NOT NULL,
    quantity numeric(12,4) NOT NULL CHECK (quantity > 0),
    unit_cost numeric(14,4) NOT NULL CHECK (unit_cost >= 0),
    tax_affectation_type text NOT NULL DEFAULT '10',
    tax_amount numeric(14,2) NOT NULL DEFAULT 0.00,
    subtotal numeric(14,2) NOT NULL DEFAULT 0.00
);

ALTER TABLE public.supplier_credit_movements
    ADD COLUMN IF NOT EXISTS purchase_invoice_id uuid REFERENCES public.purchase_invoices(id);

ALTER TABLE public.purchase_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_invoice_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Facturas compra: Gestión por permiso" ON public.purchase_invoices;
CREATE POLICY "Facturas compra: Gestión por permiso" ON public.purchase_invoices FOR ALL TO authenticated
    USING (public.user_has_permission('finance.read') OR public.user_has_permission('inventory.read'))
    WITH CHECK (public.user_has_permission('finance.manage') OR public.user_has_permission('inventory.manage'));

DROP POLICY IF EXISTS "Items factura compra: Gestión por permiso" ON public.purchase_invoice_items;
CREATE POLICY "Items factura compra: Gestión por permiso" ON public.purchase_invoice_items FOR ALL TO authenticated
    USING (public.user_has_permission('finance.read') OR public.user_has_permission('inventory.read'))
    WITH CHECK (public.user_has_permission('finance.manage') OR public.user_has_permission('inventory.manage'));


-- ============================================================================
-- 8. IMPUESTOS EN sales_return_items Y TRAZABILIDAD EN inventory_movements
-- ============================================================================

ALTER TABLE public.sales_return_items
    ADD COLUMN IF NOT EXISTS tax_affectation_type text NOT NULL DEFAULT '10',
    ADD COLUMN IF NOT EXISTS tax_rate numeric(5,2) NOT NULL DEFAULT 18.00,
    ADD COLUMN IF NOT EXISTS unit_value_without_tax numeric(14,4) NOT NULL DEFAULT 0.0000,
    ADD COLUMN IF NOT EXISTS tax_amount numeric(14,2) NOT NULL DEFAULT 0.00;

ALTER TABLE public.inventory_movements
    ADD COLUMN IF NOT EXISTS transfer_id uuid REFERENCES public.warehouse_transfers(id),
    ADD COLUMN IF NOT EXISTS sales_return_id uuid REFERENCES public.sales_returns(id);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_movements_reason_check') THEN
        ALTER TABLE public.inventory_movements
            ADD CONSTRAINT inventory_movements_reason_check
            CHECK (reason IN (
                'ENTRY', 'SALE', 'PURCHASE_ENTRY', 'MANUAL_EXIT', 'ADJUSTMENT',
                'RETURN', 'TRANSFER_OUT', 'TRANSFER_IN', 'INITIAL', 'CANCELLATION'
            )) NOT VALID;
    END IF;
END $$;


-- ============================================================================
-- 9. ÍNDICES EN TODAS LAS FKs Y CONSULTAS FRECUENTES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_inv_movements_var_wh_date ON public.inventory_movements(variant_id, warehouse_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inv_movements_transfer_id ON public.inventory_movements(transfer_id);
CREATE INDEX IF NOT EXISTS idx_inv_movements_return_id ON public.inventory_movements(sales_return_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_wh ON public.orders(created_at DESC, warehouse_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer_record_id ON public.orders(customer_record_id);
CREATE INDEX IF NOT EXISTS idx_orders_electronic_doc_id ON public.orders(electronic_document_id);

CREATE INDEX IF NOT EXISTS idx_quotations_customer_id ON public.quotations(customer_id);
CREATE INDEX IF NOT EXISTS idx_quotations_customer_record_id ON public.quotations(customer_record_id);
CREATE INDEX IF NOT EXISTS idx_quotations_warehouse_id ON public.quotations(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_quotation_items_quotation_id ON public.quotation_items(quotation_id);
CREATE INDEX IF NOT EXISTS idx_quotation_items_variant_id ON public.quotation_items(variant_id);

CREATE INDEX IF NOT EXISTS idx_sales_returns_order_id ON public.sales_returns(order_id);
CREATE INDEX IF NOT EXISTS idx_sales_returns_warehouse_id ON public.sales_returns(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_sales_return_items_return_id ON public.sales_return_items(sales_return_id);
CREATE INDEX IF NOT EXISTS idx_sales_return_items_variant_id ON public.sales_return_items(variant_id);

CREATE INDEX IF NOT EXISTS idx_wh_transfers_source ON public.warehouse_transfers(source_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_wh_transfers_dest ON public.warehouse_transfers(dest_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_wh_transfer_items_transfer ON public.warehouse_transfer_items(transfer_id);
CREATE INDEX IF NOT EXISTS idx_wh_transfer_items_variant ON public.warehouse_transfer_items(variant_id);

CREATE INDEX IF NOT EXISTS idx_expenses_account_id ON public.expenses(account_id);
CREATE INDEX IF NOT EXISTS idx_expenses_shift_id ON public.expenses(shift_id);
CREATE INDEX IF NOT EXISTS idx_expenses_category_id ON public.expenses(category_id);

CREATE INDEX IF NOT EXISTS idx_edocs_order_id ON public.electronic_documents(order_id);
CREATE INDEX IF NOT EXISTS idx_edocs_sales_return_id ON public.electronic_documents(sales_return_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON public.order_status_history(order_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_entry_id ON public.journal_entry_lines(journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_account_code ON public.journal_entry_lines(account_code);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_supplier_id ON public.purchase_invoices(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_po_id ON public.purchase_invoices(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_purchase_invoice_items_inv_id ON public.purchase_invoice_items(purchase_invoice_id);

COMMIT;

