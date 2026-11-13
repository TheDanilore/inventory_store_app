-- ============================================================================
-- MIGRACIÓN DE MEJORAS, CORRECCIONES DE SEGURIDAD Y MÓDULOS ERP
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- Estrategia: Incremental e idempotente (sin pérdida de datos de prueba)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. SEGURIDAD (VISTAS Y PERMISOS)
-- ============================================================================

-- 1.1 Revocar acceso público a profiles_with_email (evita fuga de emails via PostgREST)
REVOKE ALL ON TABLE public.profiles_with_email FROM anon;
REVOKE ALL ON TABLE public.profiles_with_email FROM authenticated;

-- Reemplazar con función RPC segura que respeta permisos RBAC
CREATE OR REPLACE FUNCTION public.get_profiles_with_email()
RETURNS TABLE (
    id uuid,
    auth_user_id uuid,
    full_name text,
    avatar_url text,
    role text,
    phone text,
    document_type text,
    document_number text,
    created_at timestamptz,
    is_active boolean,
    wallet_balance integer,
    email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado';
    END IF;

    IF public.user_has_permission('users.read') OR public.user_has_permission('customers.read') THEN
        RETURN QUERY
        SELECT
            p.id,
            p.auth_user_id,
            p.full_name,
            p.avatar_url,
            COALESCE((
                SELECT r.name
                FROM public.user_roles ur
                JOIN public.roles r ON r.id = ur.role_id
                WHERE ur.profile_id = p.id
                LIMIT 1
            ), 'customer'::text) AS role,
            p.phone,
            p.document_type,
            p.document_number,
            p.created_at,
            p.is_active,
            p.wallet_balance,
            u.email::text
        FROM public.profiles p
        LEFT JOIN auth.users u ON p.auth_user_id = u.id;
    ELSE
        RETURN QUERY
        SELECT
            p.id,
            p.auth_user_id,
            p.full_name,
            p.avatar_url,
            COALESCE((
                SELECT r.name
                FROM public.user_roles ur
                JOIN public.roles r ON r.id = ur.role_id
                WHERE ur.profile_id = p.id
                LIMIT 1
            ), 'customer'::text) AS role,
            p.phone,
            p.document_type,
            p.document_number,
            p.created_at,
            p.is_active,
            p.wallet_balance,
            u.email::text
        FROM public.profiles p
        LEFT JOIN auth.users u ON p.auth_user_id = u.id
        WHERE p.auth_user_id = auth.uid();
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_profiles_with_email() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_profiles_with_email() TO authenticated, service_role;

-- 1.2 Activar security_invoker en user_effective_permissions
ALTER VIEW public.user_effective_permissions SET (security_invoker = true);


-- ============================================================================
-- 2. INTEGRIDAD: ÍNDICES ÚNICOS Y CHECK CONSTRAINTS FALTANTES
-- ============================================================================

-- 2.1 Un lote único por variante + almacén + número de lote
CREATE UNIQUE INDEX IF NOT EXISTS idx_wsb_variant_warehouse_batch_unique
    ON public.warehouse_stock_batches (variant_id, warehouse_id, batch_number);

-- 2.2 Correlativo fiscal único en órdenes emitidas (no anuladas)
CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_document_unique
    ON public.orders (document_type, document_series, document_number)
    WHERE document_number IS NOT NULL
      AND document_type IS NOT NULL
      AND document_type <> 'NINGUNO'
      AND status <> 'CANCELLED';

-- 2.3 Código de barras único cuando no es nulo ni vacío
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_variants_barcode_unique
    ON public.product_variants (barcode)
    WHERE barcode IS NOT NULL AND trim(barcode) <> '';

-- 2.4 Solo un turno OPEN por cuenta financiera
CREATE UNIQUE INDEX IF NOT EXISTS idx_cash_shifts_one_open_per_account
    ON public.cash_shifts (account_id)
    WHERE status = 'OPEN';

-- 2.5 Solo una serie por defecto por tipo de documento y almacén (y global)
CREATE UNIQUE INDEX IF NOT EXISTS idx_document_series_one_default_warehouse
    ON public.document_series (warehouse_id, document_type)
    WHERE is_default = true AND warehouse_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_document_series_one_default_global
    ON public.document_series (document_type)
    WHERE is_default = true AND warehouse_id IS NULL;

-- 2.6 Evitar stock negativo en lotes
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'wsb_available_quantity_non_negative'
    ) THEN
        ALTER TABLE public.warehouse_stock_batches
            ADD CONSTRAINT wsb_available_quantity_non_negative
            CHECK (available_quantity >= 0) NOT VALID;
    END IF;
END $$;

-- 2.7 Restringir movement_type en account_movements
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'account_movements_movement_type_check'
    ) THEN
        ALTER TABLE public.account_movements
            ADD CONSTRAINT account_movements_movement_type_check
            CHECK (movement_type IN ('INCOME', 'EXPENSE', 'TRANSFER_IN', 'TRANSFER_OUT', 'ADJUSTMENT')) NOT VALID;
    END IF;
END $$;

-- 2.8 Ampliar tipos de comprobante en document_series y orders para soportar Notas de Crédito/Débito
ALTER TABLE public.document_series DROP CONSTRAINT IF EXISTS document_series_type_check;
ALTER TABLE public.document_series
    ADD CONSTRAINT document_series_type_check
    CHECK (document_type IN ('NOTA_VENTA', 'BOLETA', 'FACTURA', 'TICKET', 'NOTA_CREDITO', 'NOTA_DEBITO', 'COTIZACION', 'GUIA_REMISION'));

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_document_type_check;
ALTER TABLE public.orders
    ADD CONSTRAINT orders_document_type_check
    CHECK (document_type IN ('NOTA_VENTA', 'BOLETA', 'FACTURA', 'TICKET', 'NOTA_CREDITO', 'NOTA_DEBITO', 'NINGUNO'));


-- ============================================================================
-- 3. CORRECCIONES DE MODELO POS / INVENTARIO / SUNAT
-- ============================================================================

-- 3.1 Cambiar order_items.quantity de integer a numeric(12,4) para ventas por peso/volumen
ALTER TABLE public.order_items
    ALTER COLUMN quantity TYPE numeric(12,4) USING quantity::numeric(12,4);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'order_items_quantity_positive'
    ) THEN
        ALTER TABLE public.order_items
            ADD CONSTRAINT order_items_quantity_positive CHECK (quantity > 0);
    END IF;
END $$;

-- 3.2 Impuestos y descuentos por línea en order_items (Catálogo 07 SUNAT)
ALTER TABLE public.order_items
    ADD COLUMN IF NOT EXISTS tax_affectation_type text NOT NULL DEFAULT '10',
    ADD COLUMN IF NOT EXISTS discount_amount numeric(12,2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS unit_value_without_tax numeric(12,4) NOT NULL DEFAULT 0.0000,
    ADD COLUMN IF NOT EXISTS tax_rate numeric(5,2) NOT NULL DEFAULT 18.00,
    ADD COLUMN IF NOT EXISTS tax_amount numeric(12,2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS tax_amount_base numeric(12,2) NOT NULL DEFAULT 0.00;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'order_items_tax_affectation_check'
    ) THEN
        -- 10: Gravado, 20: Exonerado, 30: Inafecto, 21: Gratuito, 40: Exportación
        ALTER TABLE public.order_items
            ADD CONSTRAINT order_items_tax_affectation_check
            CHECK (tax_affectation_type IN ('10', '20', '21', '30', '40'));
    END IF;
END $$;

-- 3.3 Método de costeo explícito en variantes
ALTER TABLE public.product_variants
    ADD COLUMN IF NOT EXISTS costing_method text NOT NULL DEFAULT 'WEIGHTED_AVG';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'product_variants_costing_method_check'
    ) THEN
        ALTER TABLE public.product_variants
            ADD CONSTRAINT product_variants_costing_method_check
            CHECK (costing_method IN ('WEIGHTED_AVG', 'FIFO', 'FEFO', 'STANDARD'));
    END IF;
END $$;

-- 3.4 Tabla order_payments para pagos mixtos (Efectivo + Yape + Tarjeta + Crédito)
CREATE TABLE IF NOT EXISTS public.order_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    account_id uuid REFERENCES public.financial_accounts(id),
    shift_id uuid REFERENCES public.cash_shifts(id),
    payment_method text NOT NULL,
    amount numeric(12,2) NOT NULL CHECK (amount > 0),
    currency_code text NOT NULL DEFAULT 'PEN',
    exchange_rate numeric(12,4) NOT NULL DEFAULT 1.0000,
    amount_base numeric(12,2) NOT NULL DEFAULT 0.00,
    reference_number text,
    notes text,
    created_by uuid REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_payments_order_id ON public.order_payments(order_id);
CREATE INDEX IF NOT EXISTS idx_order_payments_shift_id ON public.order_payments(shift_id);
CREATE INDEX IF NOT EXISTS idx_order_payments_account_id ON public.order_payments(account_id);

ALTER TABLE public.order_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Pagos orden: Lectura por permiso o cliente propio" ON public.order_payments;
CREATE POLICY "Pagos orden: Lectura por permiso o cliente propio"
    ON public.order_payments FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.orders o
            WHERE o.id = order_payments.order_id AND o.customer_id = auth.uid()
        )
        OR public.user_has_permission('orders.read')
        OR public.user_has_permission('pos.sell')
    );

DROP POLICY IF EXISTS "Pagos orden: Inserción por permiso" ON public.order_payments;
CREATE POLICY "Pagos orden: Inserción por permiso"
    ON public.order_payments FOR INSERT TO authenticated
    WITH CHECK (
        public.user_has_permission('orders.create')
        OR public.user_has_permission('pos.sell')
    );


-- ============================================================================
-- 4. UNIDADES DE MEDIDA, CONVERSIONES Y LISTAS DE PRECIOS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.units_of_measure (
    code text PRIMARY KEY, -- Código SUNAT: NIU, KGM, LTR, BX, etc.
    name text NOT NULL,
    symbol text NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.units_of_measure (code, name, symbol) VALUES
    ('NIU', 'Unidad (Bienes)', 'und'),
    ('KGM', 'Kilogramo', 'kg'),
    ('GRM', 'Gramo', 'g'),
    ('LTR', 'Litro', 'L'),
    ('MLT', 'Mililitro', 'mL'),
    ('BX',  'Caja', 'cja'),
    ('PK',  'Paquete', 'paq'),
    ('BG',  'Bolsa / Saco', 'bls'),
    ('MTR', 'Metro', 'm'),
    ('ZZ',  'Servicio', 'srv')
ON CONFLICT (code) DO NOTHING;

ALTER TABLE public.units_of_measure ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "UOM: Lectura autenticada" ON public.units_of_measure;
CREATE POLICY "UOM: Lectura autenticada" ON public.units_of_measure FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "UOM: Gestión por permiso" ON public.units_of_measure;
CREATE POLICY "UOM: Gestión por permiso" ON public.units_of_measure FOR ALL TO authenticated
    USING (public.user_has_permission('products.manage'))
    WITH CHECK (public.user_has_permission('products.manage'));

ALTER TABLE public.product_variants
    ADD COLUMN IF NOT EXISTS base_unit_code text NOT NULL DEFAULT 'NIU' REFERENCES public.units_of_measure(code);

CREATE TABLE IF NOT EXISTS public.product_unit_conversions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    variant_id uuid NOT NULL REFERENCES public.product_variants(id) ON DELETE CASCADE,
    unit_code text NOT NULL REFERENCES public.units_of_measure(code),
    conversion_factor numeric(12,4) NOT NULL CHECK (conversion_factor > 0), -- Cuántas unidades base equivale
    barcode text,
    sale_price numeric(12,2),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (variant_id, unit_code)
);

ALTER TABLE public.product_unit_conversions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Conversiones UOM: Lectura autenticada" ON public.product_unit_conversions;
CREATE POLICY "Conversiones UOM: Lectura autenticada" ON public.product_unit_conversions FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Conversiones UOM: Gestión por permiso" ON public.product_unit_conversions;
CREATE POLICY "Conversiones UOM: Gestión por permiso" ON public.product_unit_conversions FOR ALL TO authenticated
    USING (public.user_has_permission('products.manage'))
    WITH CHECK (public.user_has_permission('products.manage'));

-- Listas de Precios
CREATE TABLE IF NOT EXISTS public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL UNIQUE,
    description text,
    currency_code text NOT NULL DEFAULT 'PEN',
    is_default boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    valid_from timestamptz,
    valid_to timestamptz,
    created_by uuid REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.price_list_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    variant_id uuid NOT NULL REFERENCES public.product_variants(id) ON DELETE CASCADE,
    unit_code text NOT NULL DEFAULT 'NIU' REFERENCES public.units_of_measure(code),
    min_quantity numeric(12,4) NOT NULL DEFAULT 1 CHECK (min_quantity > 0),
    price numeric(12,2) NOT NULL CHECK (price >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (price_list_id, variant_id, unit_code, min_quantity)
);

ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Listas de precios: Lectura autenticada" ON public.price_lists;
CREATE POLICY "Listas de precios: Lectura autenticada" ON public.price_lists FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Listas de precios: Gestión por permiso" ON public.price_lists;
CREATE POLICY "Listas de precios: Gestión por permiso" ON public.price_lists FOR ALL TO authenticated
    USING (public.user_has_permission('products.manage'))
    WITH CHECK (public.user_has_permission('products.manage'));

DROP POLICY IF EXISTS "Items lista precios: Lectura autenticada" ON public.price_list_items;
CREATE POLICY "Items lista precios: Lectura autenticada" ON public.price_list_items FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Items lista precios: Gestión por permiso" ON public.price_list_items;
CREATE POLICY "Items lista precios: Gestión por permiso" ON public.price_list_items FOR ALL TO authenticated
    USING (public.user_has_permission('products.manage'))
    WITH CHECK (public.user_has_permission('products.manage'));


-- ============================================================================
-- 5. TRIGGERS PARA CAMPOS _base Y RECONCILIACIÓN DE SALDOS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_compute_base_amounts()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_rate numeric(12,4);
BEGIN
    v_rate := COALESCE(NULLIF(NEW.exchange_rate, 0), 1.0000);

    IF TG_TABLE_NAME = 'orders' THEN
        IF COALESCE(NEW.total_amount_base, 0) = 0 AND COALESCE(NEW.total_amount, 0) <> 0 THEN
            NEW.total_amount_base := ROUND(NEW.total_amount * v_rate, 2);
        END IF;
        IF COALESCE(NEW.subtotal_amount_base, 0) = 0 AND COALESCE(NEW.subtotal_amount, 0) <> 0 THEN
            NEW.subtotal_amount_base := ROUND(NEW.subtotal_amount * v_rate, 2);
        END IF;
        IF COALESCE(NEW.tax_amount_base, 0) = 0 AND COALESCE(NEW.tax_amount, 0) <> 0 THEN
            NEW.tax_amount_base := ROUND(NEW.tax_amount * v_rate, 2);
        END IF;
    ELSIF TG_TABLE_NAME IN ('account_movements', 'order_payments') THEN
        IF COALESCE(NEW.amount_base, 0) = 0 AND COALESCE(NEW.amount, 0) <> 0 THEN
            NEW.amount_base := ROUND(NEW.amount * v_rate, 2);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_compute_base ON public.orders;
CREATE TRIGGER trg_orders_compute_base
    BEFORE INSERT OR UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.trg_compute_base_amounts();

DROP TRIGGER IF EXISTS trg_account_movements_compute_base ON public.account_movements;
CREATE TRIGGER trg_account_movements_compute_base
    BEFORE INSERT OR UPDATE ON public.account_movements
    FOR EACH ROW EXECUTE FUNCTION public.trg_compute_base_amounts();

DROP TRIGGER IF EXISTS trg_order_payments_compute_base ON public.order_payments;
CREATE TRIGGER trg_order_payments_compute_base
    BEFORE INSERT OR UPDATE ON public.order_payments
    FOR EACH ROW EXECUTE FUNCTION public.trg_compute_base_amounts();

-- Función de Reconciliación de Saldos contra Libros de Movimientos
CREATE OR REPLACE FUNCTION public.reconcile_balances_report()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_account_diffs jsonb;
    v_credit_diffs jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
    INTO v_account_diffs
    FROM (
        SELECT
            fa.id,
            fa.name,
            fa.balance AS stored_balance,
            COALESCE(SUM(
                CASE
                    WHEN am.movement_type IN ('INCOME', 'TRANSFER_IN') THEN am.amount
                    WHEN am.movement_type IN ('EXPENSE', 'TRANSFER_OUT') THEN -am.amount
                    ELSE 0
                END
            ), 0) AS ledger_balance
        FROM public.financial_accounts fa
        LEFT JOIN public.account_movements am ON am.account_id = fa.id
        GROUP BY fa.id, fa.name, fa.balance
        HAVING ABS(fa.balance - COALESCE(SUM(
            CASE
                WHEN am.movement_type IN ('INCOME', 'TRANSFER_IN') THEN am.amount
                WHEN am.movement_type IN ('EXPENSE', 'TRANSFER_OUT') THEN -am.amount
                ELSE 0
            END
        ), 0)) > 0.01
    ) t;

    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
    INTO v_credit_diffs
    FROM (
        SELECT
            cc.id,
            cc.profile_id,
            cc.current_debt AS stored_debt,
            COALESCE(SUM(
                CASE
                    WHEN ccm.movement_type = 'CHARGE' THEN ccm.amount
                    WHEN ccm.movement_type = 'PAYMENT' THEN -ccm.amount
                    ELSE 0
                END
            ), 0) AS ledger_debt
        FROM public.customer_credits cc
        LEFT JOIN public.customer_credit_movements ccm ON ccm.credit_id = cc.id
        GROUP BY cc.id, cc.profile_id, cc.current_debt
        HAVING ABS(cc.current_debt - COALESCE(SUM(
            CASE
                WHEN ccm.movement_type = 'CHARGE' THEN ccm.amount
                WHEN ccm.movement_type = 'PAYMENT' THEN -ccm.amount
                ELSE 0
            END
        ), 0)) > 0.01
    ) t;

    RETURN jsonb_build_object(
        'checked_at', now(),
        'account_discrepancies', v_account_diffs,
        'customer_credit_discrepancies', v_credit_diffs
    );
END;
$$;


-- ============================================================================
-- 6. MÓDULOS ERP FALTANTES
-- ============================================================================

-- 6.1 Cotizaciones
CREATE TABLE IF NOT EXISTS public.quotations (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    quotation_number text UNIQUE,
    customer_id uuid REFERENCES public.profiles(id),
    customer_name text,
    customer_document_number text,
    warehouse_id uuid REFERENCES public.warehouses(id),
    status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CONVERTED')),
    valid_until date,
    currency_code text NOT NULL DEFAULT 'PEN',
    exchange_rate numeric(12,4) NOT NULL DEFAULT 1.0000,
    subtotal_amount numeric(12,2) NOT NULL DEFAULT 0.00,
    tax_amount numeric(12,2) NOT NULL DEFAULT 0.00,
    discount_amount numeric(12,2) NOT NULL DEFAULT 0.00,
    total_amount numeric(12,2) NOT NULL DEFAULT 0.00,
    notes text,
    converted_order_id uuid REFERENCES public.orders(id),
    created_by uuid REFERENCES public.profiles(id),
    updated_by uuid REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.quotation_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    quotation_id uuid NOT NULL REFERENCES public.quotations(id) ON DELETE CASCADE,
    variant_id uuid NOT NULL REFERENCES public.product_variants(id),
    unit_code text NOT NULL DEFAULT 'NIU' REFERENCES public.units_of_measure(code),
    quantity numeric(12,4) NOT NULL CHECK (quantity > 0),
    unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
    discount_amount numeric(12,2) NOT NULL DEFAULT 0.00,
    tax_affectation_type text NOT NULL DEFAULT '10',
    tax_amount numeric(12,2) NOT NULL DEFAULT 0.00,
    subtotal numeric(12,2) NOT NULL DEFAULT 0.00
);

-- 6.2 Devoluciones y Notas de Crédito
CREATE TABLE IF NOT EXISTS public.sales_returns (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id),
    warehouse_id uuid NOT NULL REFERENCES public.warehouses(id),
    document_type text NOT NULL DEFAULT 'NOTA_CREDITO' CHECK (document_type IN ('NOTA_CREDITO', 'DEVOLUCION_INTERNA')),
    document_series text,
    document_number text,
    reason_code text NOT NULL DEFAULT '01', -- Catálogo 09 SUNAT
    reason_description text NOT NULL,
    refund_method text NOT NULL DEFAULT 'CASH' CHECK (refund_method IN ('CASH', 'ACCOUNT_TRANSFER', 'CREDIT_BALANCE', 'NONE')),
    account_id uuid REFERENCES public.financial_accounts(id),
    shift_id uuid REFERENCES public.cash_shifts(id),
    total_refund_amount numeric(12,2) NOT NULL DEFAULT 0.00,
    status text NOT NULL DEFAULT 'COMPLETED' CHECK (status IN ('PENDING', 'COMPLETED', 'CANCELLED')),
    created_by uuid NOT NULL REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales_return_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    sales_return_id uuid NOT NULL REFERENCES public.sales_returns(id) ON DELETE CASCADE,
    order_item_id uuid REFERENCES public.order_items(id),
    variant_id uuid NOT NULL REFERENCES public.product_variants(id),
    stock_batch_id uuid REFERENCES public.warehouse_stock_batches(id),
    quantity numeric(12,4) NOT NULL CHECK (quantity > 0),
    unit_price numeric(12,2) NOT NULL,
    refund_subtotal numeric(12,2) NOT NULL,
    restock boolean NOT NULL DEFAULT true
);

-- 6.3 Transferencias entre Almacenes (Origen -> Destino)
CREATE TABLE IF NOT EXISTS public.warehouse_transfers (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    transfer_number text UNIQUE,
    source_warehouse_id uuid NOT NULL REFERENCES public.warehouses(id),
    dest_warehouse_id uuid NOT NULL REFERENCES public.warehouses(id),
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'IN_TRANSIT', 'RECEIVED', 'CANCELLED')),
    notes text,
    shipped_at timestamptz,
    received_at timestamptz,
    created_by uuid NOT NULL REFERENCES public.profiles(id),
    received_by uuid REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (source_warehouse_id <> dest_warehouse_id)
);

CREATE TABLE IF NOT EXISTS public.warehouse_transfer_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    transfer_id uuid NOT NULL REFERENCES public.warehouse_transfers(id) ON DELETE CASCADE,
    variant_id uuid NOT NULL REFERENCES public.product_variants(id),
    source_batch_id uuid REFERENCES public.warehouse_stock_batches(id),
    quantity_sent numeric(12,4) NOT NULL CHECK (quantity_sent > 0),
    quantity_received numeric(12,4) DEFAULT 0 CHECK (quantity_received >= 0),
    unit_cost numeric(12,4) DEFAULT 0
);

-- 6.4 Gastos Operativos
CREATE TABLE IF NOT EXISTS public.expense_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL UNIQUE,
    description text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.expenses (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    category_id uuid REFERENCES public.expense_categories(id),
    warehouse_id uuid REFERENCES public.warehouses(id),
    supplier_id uuid REFERENCES public.suppliers(id),
    account_id uuid NOT NULL REFERENCES public.financial_accounts(id),
    shift_id uuid REFERENCES public.cash_shifts(id),
    description text NOT NULL,
    document_type text,
    document_number text,
    expense_date date NOT NULL DEFAULT CURRENT_DATE,
    currency_code text NOT NULL DEFAULT 'PEN',
    exchange_rate numeric(12,4) NOT NULL DEFAULT 1.0000,
    amount numeric(12,2) NOT NULL CHECK (amount > 0),
    amount_base numeric(12,2) NOT NULL DEFAULT 0.00,
    status text NOT NULL DEFAULT 'PAID' CHECK (status IN ('PAID', 'CANCELLED')),
    created_by uuid NOT NULL REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now()
);

-- 6.5 Comprobantes Electrónicos SUNAT
CREATE TABLE IF NOT EXISTS public.electronic_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    order_id uuid REFERENCES public.orders(id),
    sales_return_id uuid REFERENCES public.sales_returns(id),
    document_type text NOT NULL CHECK (document_type IN ('BOLETA', 'FACTURA', 'NOTA_CREDITO', 'NOTA_DEBITO', 'GUIA_REMISION')),
    series text NOT NULL,
    correlative text NOT NULL,
    sunat_status text NOT NULL DEFAULT 'PENDING' CHECK (sunat_status IN ('PENDING', 'SENT', 'ACCEPTED', 'OBSERVED', 'REJECTED', 'VOIDED')),
    hash_cpe text,
    xml_url text,
    cdr_url text,
    pdf_url text,
    sunat_response_code text,
    sunat_response_message text,
    sent_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (document_type, series, correlative),
    CHECK (order_id IS NOT NULL OR sales_return_id IS NOT NULL)
);

-- 6.6 Historial de Estados y Auditoría Global
CREATE TABLE IF NOT EXISTS public.order_status_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    previous_status text,
    new_status text NOT NULL,
    notes text,
    changed_by uuid REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    table_name text NOT NULL,
    record_id uuid,
    action text NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data jsonb,
    new_data jsonb,
    changed_by uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_table_record ON public.audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);

-- Habilitar RLS en todas las tablas nuevas
ALTER TABLE public.quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotation_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_return_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_transfer_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.electronic_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Políticas RLS base para tablas nuevas
DROP POLICY IF EXISTS "Cotizaciones: Gestión por permiso" ON public.quotations;
CREATE POLICY "Cotizaciones: Gestión por permiso" ON public.quotations FOR ALL TO authenticated
    USING (public.user_has_permission('orders.read') OR public.user_has_permission('pos.sell'))
    WITH CHECK (public.user_has_permission('orders.create') OR public.user_has_permission('pos.sell'));

DROP POLICY IF EXISTS "Items cotización: Gestión por permiso" ON public.quotation_items;
CREATE POLICY "Items cotización: Gestión por permiso" ON public.quotation_items FOR ALL TO authenticated
    USING (public.user_has_permission('orders.read') OR public.user_has_permission('pos.sell'))
    WITH CHECK (public.user_has_permission('orders.create') OR public.user_has_permission('pos.sell'));

DROP POLICY IF EXISTS "Devoluciones: Gestión por permiso" ON public.sales_returns;
CREATE POLICY "Devoluciones: Gestión por permiso" ON public.sales_returns FOR ALL TO authenticated
    USING (public.user_has_permission('orders.read') OR public.user_has_permission('pos.sell'))
    WITH CHECK (public.user_has_permission('orders.cancel') OR public.user_has_permission('pos.sell'));

DROP POLICY IF EXISTS "Items devolución: Gestión por permiso" ON public.sales_return_items;
CREATE POLICY "Items devolución: Gestión por permiso" ON public.sales_return_items FOR ALL TO authenticated
    USING (public.user_has_permission('orders.read') OR public.user_has_permission('pos.sell'))
    WITH CHECK (public.user_has_permission('orders.cancel') OR public.user_has_permission('pos.sell'));

DROP POLICY IF EXISTS "Transferencias: Gestión por permiso" ON public.warehouse_transfers;
CREATE POLICY "Transferencias: Gestión por permiso" ON public.warehouse_transfers FOR ALL TO authenticated
    USING (public.user_has_permission('inventory.read'))
    WITH CHECK (public.user_has_permission('inventory.manage'));

DROP POLICY IF EXISTS "Items transferencia: Gestión por permiso" ON public.warehouse_transfer_items;
CREATE POLICY "Items transferencia: Gestión por permiso" ON public.warehouse_transfer_items FOR ALL TO authenticated
    USING (public.user_has_permission('inventory.read'))
    WITH CHECK (public.user_has_permission('inventory.manage'));

DROP POLICY IF EXISTS "Categorías gastos: Gestión por permiso" ON public.expense_categories;
CREATE POLICY "Categorías gastos: Gestión por permiso" ON public.expense_categories FOR ALL TO authenticated
    USING (public.user_has_permission('finance.read'))
    WITH CHECK (public.user_has_permission('finance.manage'));

DROP POLICY IF EXISTS "Gastos: Gestión por permiso" ON public.expenses;
CREATE POLICY "Gastos: Gestión por permiso" ON public.expenses FOR ALL TO authenticated
    USING (public.user_has_permission('finance.read'))
    WITH CHECK (public.user_has_permission('finance.manage'));

DROP POLICY IF EXISTS "Comprobantes electrónicos: Gestión por permiso" ON public.electronic_documents;
CREATE POLICY "Comprobantes electrónicos: Gestión por permiso" ON public.electronic_documents FOR ALL TO authenticated
    USING (public.user_has_permission('orders.read'))
    WITH CHECK (public.user_has_permission('pos.sell'));

DROP POLICY IF EXISTS "Historial estados orden: Lectura por permiso" ON public.order_status_history;
CREATE POLICY "Historial estados orden: Lectura por permiso" ON public.order_status_history FOR SELECT TO authenticated
    USING (public.user_has_permission('orders.read'));

DROP POLICY IF EXISTS "Audit logs: Solo administradores" ON public.audit_logs;
CREATE POLICY "Audit logs: Solo administradores" ON public.audit_logs FOR SELECT TO authenticated
    USING (public.user_has_permission('users.manage'));

COMMIT;

