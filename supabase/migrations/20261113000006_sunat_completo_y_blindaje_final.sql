-- ============================================================================
-- MIGRACIÓN 6: SUNAT COMPLETO, BLINDAJE CONTABLE DEFERRABLE Y ESTANDARIZACIÓN
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. CONTABILIDAD: CONSTRAINT TRIGGER DEFERRABLE PARA CUADRE EN COMMIT
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_check_journal_entry_lines_balanced()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_entry_id uuid := COALESCE(NEW.journal_entry_id, OLD.journal_entry_id);
    v_status text;
    v_debit numeric;
    v_credit numeric;
BEGIN
    SELECT status INTO v_status FROM public.journal_entries WHERE id = v_entry_id;
    IF v_status = 'POSTED' THEN
        SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
        INTO v_debit, v_credit
        FROM public.journal_entry_lines
        WHERE journal_entry_id = v_entry_id;

        IF v_debit <= 0 OR ABS(v_debit - v_credit) > 0.01 THEN
            RAISE EXCEPTION 'Asiento contable % descuadrado al confirmar: Debe (%) <> Haber (%)', v_entry_id, v_debit, v_credit;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_journal_lines_balanced_deferred ON public.journal_entry_lines;
CREATE CONSTRAINT TRIGGER trg_journal_lines_balanced_deferred
    AFTER INSERT OR UPDATE OR DELETE ON public.journal_entry_lines
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION public.trg_check_journal_entry_lines_balanced();

-- Hacer opcionales las columnas de cabecera en accounting_posting_rules (la fuente es accounting_posting_rule_lines)
ALTER TABLE public.accounting_posting_rules
    ALTER COLUMN debit_account_code DROP NOT NULL,
    ALTER COLUMN credit_account_code DROP NOT NULL;


-- ============================================================================
-- 2. ESTANDARIZACIÓN DE PRECISIÓN MONETARIA Y SALDO A FAVOR
-- ============================================================================

ALTER TABLE public.customer_credits
    ADD COLUMN IF NOT EXISTS credit_balance numeric(14,2) NOT NULL DEFAULT 0.00 CHECK (credit_balance >= 0);

DROP VIEW IF EXISTS public.partner_credit_summary;

ALTER TABLE public.customer_credits
    ALTER COLUMN current_debt TYPE numeric(14,2),
    ALTER COLUMN credit_limit TYPE numeric(14,2);

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
    cc.customer_record_id,
    cc.credit_balance
FROM public.customer_credits cc
LEFT JOIN public.customers c ON c.id = cc.customer_record_id
LEFT JOIN public.profiles p ON p.id = cc.profile_id;

ALTER TABLE public.cash_shifts
    ALTER COLUMN opening_amount TYPE numeric(14,2),
    ALTER COLUMN expected_amount TYPE numeric(14,2),
    ALTER COLUMN actual_amount TYPE numeric(14,2),
    ALTER COLUMN difference_amount TYPE numeric(14,2);

ALTER TABLE public.supplier_credits
    ALTER COLUMN current_debt TYPE numeric(14,2),
    ALTER COLUMN credit_limit TYPE numeric(14,2);

ALTER TABLE public.purchase_orders
    ALTER COLUMN total_amount TYPE numeric(14,2),
    ALTER COLUMN amount_paid TYPE numeric(14,2),
    ALTER COLUMN discount_amount TYPE numeric(14,2),
    ALTER COLUMN tax_amount TYPE numeric(14,2);

ALTER TABLE public.inventory_entries
    ALTER COLUMN total_amount TYPE numeric(14,2),
    ALTER COLUMN total_amount_base TYPE numeric(14,2);

-- Permitir cantidades decimales en el carrito de compras (peso/volumen)
ALTER TABLE public.cart_items
    ALTER COLUMN quantity TYPE numeric(12,4) USING quantity::numeric(12,4);


-- ============================================================================
-- 3. INTEGRIDAD DE MONEDA (FK A currencies.code) Y CHECKS EN ESTADOS
-- ============================================================================

UPDATE public.orders SET currency_code = 'PEN' WHERE currency_code IS NULL;
UPDATE public.account_movements SET currency_code = 'PEN' WHERE currency_code IS NULL;
UPDATE public.financial_accounts SET currency_code = 'PEN' WHERE currency_code IS NULL;
UPDATE public.inventory_movements SET currency_code = 'PEN' WHERE currency_code IS NULL;
UPDATE public.inventory_entries SET currency_code = 'PEN' WHERE currency_code IS NULL;

ALTER TABLE public.orders ALTER COLUMN currency_code SET NOT NULL;
ALTER TABLE public.account_movements ALTER COLUMN currency_code SET NOT NULL;
ALTER TABLE public.financial_accounts ALTER COLUMN currency_code SET NOT NULL;
ALTER TABLE public.inventory_movements ALTER COLUMN currency_code SET NOT NULL;
ALTER TABLE public.inventory_entries ALTER COLUMN currency_code SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_currency_code_fkey') THEN
        ALTER TABLE public.orders ADD CONSTRAINT orders_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES public.currencies(code) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'account_movements_currency_code_fkey') THEN
        ALTER TABLE public.account_movements ADD CONSTRAINT account_movements_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES public.currencies(code) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'financial_accounts_currency_code_fkey') THEN
        ALTER TABLE public.financial_accounts ADD CONSTRAINT financial_accounts_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES public.currencies(code) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'order_payments_currency_code_fkey') THEN
        ALTER TABLE public.order_payments ADD CONSTRAINT order_payments_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES public.currencies(code) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'expenses_currency_code_fkey') THEN
        ALTER TABLE public.expenses ADD CONSTRAINT expenses_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES public.currencies(code) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'quotations_currency_code_fkey') THEN
        ALTER TABLE public.quotations ADD CONSTRAINT quotations_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES public.currencies(code) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'purchase_invoices_currency_code_fkey') THEN
        ALTER TABLE public.purchase_invoices ADD CONSTRAINT purchase_invoices_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES public.currencies(code) NOT VALID;
    END IF;

    -- CHECKs de estados faltantes
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_status_check') THEN
        ALTER TABLE public.orders ADD CONSTRAINT orders_status_check
            CHECK (status IN ('PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'COMPLETED', 'CANCELLED')) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_entries_status_check') THEN
        ALTER TABLE public.inventory_entries ADD CONSTRAINT inventory_entries_status_check
            CHECK (status IN ('PENDING', 'COMPLETED', 'CANCELLED')) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'financial_accounts_type_check') THEN
        ALTER TABLE public.financial_accounts ADD CONSTRAINT financial_accounts_type_check
            CHECK (type IN ('CAJA', 'BANCO', 'BILLETERA_DIGITAL', 'OTRO')) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_info_cash_mode_check') THEN
        ALTER TABLE public.business_info ADD CONSTRAINT business_info_cash_mode_check
            CHECK (cash_register_mode IN ('COUNTER', 'INDIVIDUAL')) NOT VALID;
    END IF;
END $$;


-- ============================================================================
-- 4. PERÚ / SUNAT COMPLETO: CATÁLOGO 07, ICBPER, TOTALES CPE Y GUÍA REMISIÓN
-- ============================================================================

-- Ampliar Catálogo 07 SUNAT completo
ALTER TABLE public.order_items DROP CONSTRAINT IF EXISTS order_items_tax_affectation_check;
ALTER TABLE public.order_items ADD CONSTRAINT order_items_tax_affectation_check
    CHECK (tax_affectation_type IN ('10','11','12','13','14','15','16','17','20','21','30','31','32','33','34','35','36','37','40'));

ALTER TABLE public.categories DROP CONSTRAINT IF EXISTS categories_tax_affectation_check;
ALTER TABLE public.categories ADD CONSTRAINT categories_tax_affectation_check
    CHECK (default_tax_affectation_type IN ('10','11','12','13','14','15','16','17','20','21','30','31','32','33','34','35','36','37','40'));

ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_tax_affectation_check;
ALTER TABLE public.products ADD CONSTRAINT products_tax_affectation_check
    CHECK (tax_affectation_type IN ('10','11','12','13','14','15','16','17','20','21','30','31','32','33','34','35','36','37','40'));

-- Totales por tipo de operación SUNAT, ICBPER y Detracción en orders y order_items
ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS total_gravado numeric(14,2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS total_exonerado numeric(14,2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS total_inafecto numeric(14,2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS total_gratuito numeric(14,2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS icbper_amount numeric(14,2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS detraction_code text,
    ADD COLUMN IF NOT EXISTS detraction_amount numeric(14,2) NOT NULL DEFAULT 0.00;

ALTER TABLE public.order_items
    ADD COLUMN IF NOT EXISTS icbper_amount numeric(14,2) NOT NULL DEFAULT 0.00;

-- Tabla de Transporte y Guías de Remisión (SUNAT GRE)
CREATE TABLE IF NOT EXISTS public.dispatch_guides (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    electronic_document_id uuid REFERENCES public.electronic_documents(id),
    transfer_id uuid REFERENCES public.warehouse_transfers(id),
    order_id uuid REFERENCES public.orders(id),
    series text NOT NULL,
    correlative text NOT NULL,
    issue_date date NOT NULL DEFAULT CURRENT_DATE,
    start_date date NOT NULL DEFAULT CURRENT_DATE,
    transfer_reason_code text NOT NULL DEFAULT '01', -- 01: Venta, 04: Traslado entre establecimientos
    transport_mode text NOT NULL DEFAULT '02' CHECK (transport_mode IN ('01', '02')), -- 01: Público, 02: Privado
    gross_weight_kg numeric(12,3) NOT NULL DEFAULT 0.000,
    packages_count integer NOT NULL DEFAULT 1,
    carrier_ruc text,
    carrier_name text,
    driver_document_number text,
    driver_license_number text,
    vehicle_plate text,
    origin_ubigeo text,
    origin_address text NOT NULL,
    dest_ubigeo text,
    dest_address text NOT NULL,
    created_by uuid REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (series, correlative)
);

CREATE INDEX IF NOT EXISTS idx_dispatch_guides_transfer_id ON public.dispatch_guides(transfer_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_guides_order_id ON public.dispatch_guides(order_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_guides_edoc_id ON public.dispatch_guides(electronic_document_id);

ALTER TABLE public.dispatch_guides ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Guías remisión: Gestión por permiso" ON public.dispatch_guides;
CREATE POLICY "Guías remisión: Gestión por permiso" ON public.dispatch_guides FOR ALL TO authenticated
    USING (public.user_has_permission('inventory.read') OR public.user_has_permission('orders.read'))
    WITH CHECK (public.user_has_permission('inventory.manage') OR public.user_has_permission('pos.sale'));


-- ============================================================================
-- 5. APP_SETTINGS MULTI-TIPO, TRIGGERS updated_at, ÍNDICES Y PRECIO OFICIAL
-- ============================================================================

ALTER TABLE public.app_settings
    ADD COLUMN IF NOT EXISTS value_text text,
    ADD COLUMN IF NOT EXISTS value_type text NOT NULL DEFAULT 'NUMERIC' CHECK (value_type IN ('NUMERIC', 'TEXT', 'BOOLEAN', 'JSON'));

-- Trigger genérico updated_at
CREATE OR REPLACE FUNCTION public.trg_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'orders', 'products', 'product_variants', 'customers',
        'quotations', 'warehouse_transfers', 'electronic_documents',
        'financial_accounts', 'suppliers', 'price_lists'
    ]
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_updated_at ON public.%I;', t, t);
        EXECUTE format('CREATE TRIGGER trg_%I_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.trg_set_updated_at();', t, t);
    END LOOP;
END $$;

-- Índices faltantes en orders
CREATE INDEX IF NOT EXISTS idx_orders_created_at_desc ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON public.orders(customer_id);

-- Función oficial de precedencia de precios (Lista de precios -> Conversión UOM -> Mayorista -> Precio base variante)
CREATE OR REPLACE FUNCTION public.rpc_resolve_variant_price(
    p_variant_id uuid,
    p_price_list_id uuid DEFAULT NULL,
    p_unit_code text DEFAULT 'NIU',
    p_quantity numeric DEFAULT 1
)
RETURNS numeric(14,4)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_price numeric(14,4);
    v_var record;
BEGIN
    -- 1. Lista de precios explícita (si aplica y está vigente)
    IF p_price_list_id IS NOT NULL THEN
        SELECT pli.price INTO v_price
        FROM public.price_list_items pli
        JOIN public.price_lists pl ON pl.id = pli.price_list_id
        WHERE pli.price_list_id = p_price_list_id
          AND pli.variant_id = p_variant_id
          AND pli.unit_code = p_unit_code
          AND pli.min_quantity <= p_quantity
          AND pl.is_active = true
          AND (pl.valid_from IS NULL OR pl.valid_from <= now())
          AND (pl.valid_to IS NULL OR pl.valid_to >= now())
        ORDER BY pli.min_quantity DESC
        LIMIT 1;

        IF v_price IS NOT NULL THEN RETURN v_price; END IF;
    END IF;

    -- 2. Precio específico por unidad de conversión (ej. Caja)
    SELECT sale_price INTO v_price
    FROM public.product_unit_conversions
    WHERE variant_id = p_variant_id
      AND unit_code = p_unit_code
      AND is_active = true
      AND sale_price IS NOT NULL
    LIMIT 1;

    IF v_price IS NOT NULL THEN RETURN v_price; END IF;

    -- 3. Precio mayorista / base de la variante
    SELECT sale_price, wholesale_price, wholesale_min_quantity
    INTO v_var
    FROM public.product_variants
    WHERE id = p_variant_id;

    IF v_var.wholesale_price IS NOT NULL
       AND v_var.wholesale_min_quantity IS NOT NULL
       AND p_quantity >= v_var.wholesale_min_quantity THEN
        RETURN v_var.wholesale_price;
    END IF;

    RETURN COALESCE(v_var.sale_price, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_resolve_variant_price(uuid, uuid, text, numeric) TO authenticated, service_role;

COMMIT;

