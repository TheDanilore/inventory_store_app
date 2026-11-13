-- ============================================================================
-- MIGRACIÓN 3: SEPARACIÓN DE CLIENTES, RECEPCIÓN PURA Y CONTABILIDAD ERP
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. SEPARACIÓN DE CLIENTES DE NEGOCIO (customers) VS USUARIOS (profiles)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    profile_id uuid UNIQUE REFERENCES public.profiles(id) ON DELETE SET NULL, -- Solo si tiene cuenta de login
    customer_type text NOT NULL DEFAULT 'PERSON' CHECK (customer_type IN ('PERSON', 'COMPANY')),
    document_type text DEFAULT 'DNI' CHECK (document_type IN ('DNI', 'RUC', 'CE', 'PASAPORTE', 'OTRO')),
    document_number text,
    full_name text NOT NULL,
    trade_name text,
    email text,
    phone text,
    address text,
    tax_condition text DEFAULT 'HABIDO',
    is_active boolean NOT NULL DEFAULT true,
    wallet_balance integer NOT NULL DEFAULT 0,
    created_by uuid REFERENCES public.profiles(id),
    updated_by uuid REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_document_unique
    ON public.customers (document_type, document_number)
    WHERE document_number IS NOT NULL AND trim(document_number) <> '';

CREATE INDEX IF NOT EXISTS idx_customers_full_name ON public.customers (full_name);

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Clientes: Lectura por permiso o propio" ON public.customers;
CREATE POLICY "Clientes: Lectura por permiso o propio"
    ON public.customers FOR SELECT TO authenticated
    USING (
        profile_id IN (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
        OR public.user_has_permission('customers.read')
        OR public.user_has_permission('pos.sale')
        OR public.user_has_permission('orders.read')
    );

DROP POLICY IF EXISTS "Clientes: Gestión por permiso" ON public.customers;
CREATE POLICY "Clientes: Gestión por permiso"
    ON public.customers FOR ALL TO authenticated
    USING (
        public.user_has_permission('customers.manage')
        OR public.user_has_permission('pos.sale')
    )
    WITH CHECK (
        public.user_has_permission('customers.manage')
        OR public.user_has_permission('pos.sale')
    );

-- Enlaces de transición (mantiene customer_id/profile_id actuales sin romper Flutter)
ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS customer_record_id uuid REFERENCES public.customers(id);

ALTER TABLE public.quotations
    ADD COLUMN IF NOT EXISTS customer_record_id uuid REFERENCES public.customers(id);

ALTER TABLE public.customer_credits
    ADD COLUMN IF NOT EXISTS customer_record_id uuid UNIQUE REFERENCES public.customers(id);

ALTER TABLE public.customer_locations
    ADD COLUMN IF NOT EXISTS customer_record_id uuid REFERENCES public.customers(id);

-- Backfill automático desde profiles (clientes con órdenes, créditos o rol customer)
INSERT INTO public.customers (
    profile_id, customer_type, document_type, document_number, full_name, phone, is_active, wallet_balance, created_at
)
SELECT
    p.id,
    CASE WHEN p.document_type = 'RUC' THEN 'COMPANY' ELSE 'PERSON' END,
    CASE WHEN p.document_type IN ('DNI', 'RUC', 'CE', 'PASAPORTE') THEN p.document_type ELSE 'OTRO' END,
    NULLIF(trim(p.document_number), ''),
    COALESCE(NULLIF(trim(p.full_name), ''), 'Cliente sin nombre'),
    p.phone,
    COALESCE(p.is_active, true),
    COALESCE(p.wallet_balance, 0),
    COALESCE(p.created_at, now())
FROM public.profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.profile_id = p.id AND r.name <> 'customer'
)
ON CONFLICT (profile_id) DO NOTHING;

-- Sincronizar enlaces de transición
UPDATE public.orders o
SET customer_record_id = c.id
FROM public.customers c
WHERE o.customer_id = c.profile_id AND o.customer_record_id IS NULL;

UPDATE public.customer_credits cc
SET customer_record_id = c.id
FROM public.customers c
WHERE cc.profile_id = c.profile_id AND cc.customer_record_id IS NULL;

UPDATE public.customer_locations cl
SET customer_record_id = c.id
FROM public.customers c
WHERE cl.profile_id = c.profile_id AND cl.customer_record_id IS NULL;

-- RPC para crear/actualizar clientes de negocio sin requerir cuenta en auth.users
CREATE OR REPLACE FUNCTION public.rpc_upsert_customer(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_actor_id uuid;
    v_customer_id uuid := NULLIF(payload->>'id', '')::uuid;
    v_doc_type text := COALESCE(NULLIF(payload->>'documentType', ''), 'DNI');
    v_doc_num text := NULLIF(trim(payload->>'documentNumber'), '');
BEGIN
    SELECT id INTO v_actor_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin perfil válido.';
    END IF;

    IF v_customer_id IS NULL THEN
        INSERT INTO public.customers (
            customer_type, document_type, document_number, full_name, trade_name,
            email, phone, address, is_active, created_by, updated_by
        ) VALUES (
            COALESCE(payload->>'customerType', CASE WHEN v_doc_type = 'RUC' THEN 'COMPANY' ELSE 'PERSON' END),
            v_doc_type,
            v_doc_num,
            payload->>'fullName',
            NULLIF(payload->>'tradeName', ''),
            NULLIF(payload->>'email', ''),
            NULLIF(payload->>'phone', ''),
            NULLIF(payload->>'address', ''),
            COALESCE((payload->>'isActive')::boolean, true),
            v_actor_id,
            v_actor_id
        ) RETURNING id INTO v_customer_id;
    ELSE
        UPDATE public.customers
        SET
            customer_type = COALESCE(payload->>'customerType', customer_type),
            document_type = COALESCE(v_doc_type, document_type),
            document_number = COALESCE(v_doc_num, document_number),
            full_name = COALESCE(payload->>'fullName', full_name),
            trade_name = COALESCE(NULLIF(payload->>'tradeName', ''), trade_name),
            email = COALESCE(NULLIF(payload->>'email', ''), email),
            phone = COALESCE(NULLIF(payload->>'phone', ''), phone),
            address = COALESCE(NULLIF(payload->>'address', ''), address),
            is_active = COALESCE((payload->>'isActive')::boolean, is_active),
            updated_by = v_actor_id,
            updated_at = now()
        WHERE id = v_customer_id;
    END IF;

    RETURN v_customer_id;
END;
$$;


-- ============================================================================
-- 2. DESACOPLE DE RECEPCIÓN FÍSICA DE INVENTARIO (SIN PAGOS MEZCLADOS)
-- ============================================================================

ALTER TABLE public.inventory_entries
    ALTER COLUMN payment_mode DROP DEFAULT,
    ADD COLUMN IF NOT EXISTS guide_number text,
    ADD COLUMN IF NOT EXISTS received_at timestamptz DEFAULT now();

COMMENT ON COLUMN public.inventory_entries.payment_mode IS 'DEPRECATED: Los pagos deben gestionarse en purchase_orders y cuentas por pagar.';
COMMENT ON COLUMN public.inventory_entries.account_id IS 'DEPRECATED: La recepción física no debe mover cuentas financieras.';
COMMENT ON COLUMN public.inventory_entries.shift_id IS 'DEPRECATED: La recepción física no depende de turnos de caja.';

-- RPC puro de recepción física de inventario (no toca cajas ni cuentas financieras)
CREATE OR REPLACE FUNCTION public.rpc_receive_inventory_only(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_profile_id uuid;
    v_warehouse_id uuid := (payload->>'warehouseId')::uuid;
    v_entry_id uuid;
    v_item jsonb;
    v_variant_id uuid;
    v_product_id uuid;
    v_qty numeric;
    v_unit_cost numeric;
    v_batch text;
    v_expiry date;
    v_old_qty numeric;
    v_batch_id uuid;
    v_total numeric := 0;
BEGIN
    SELECT id INTO v_profile_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin perfil válido.';
    END IF;
    IF NOT public.user_has_permission('inventory.manage') THEN
        RAISE EXCEPTION 'Sin permiso para recibir inventario (inventory.manage).' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.inventory_entries (
        warehouse_id, supplier_id, purchase_order_id, document_type, document_number, document_date,
        guide_number, notes, status, payment_mode, created_by, received_at
    ) VALUES (
        v_warehouse_id,
        NULLIF(payload->>'supplierId', '')::uuid,
        NULLIF(payload->>'purchaseOrderId', '')::uuid,
        COALESCE(payload->>'documentType', 'GUIA_REMISION'),
        payload->>'documentNumber',
        COALESCE((payload->>'documentDate')::date, CURRENT_DATE),
        payload->>'guideNumber',
        payload->>'notes',
        'COMPLETED',
        NULL,
        v_profile_id,
        now()
    ) RETURNING id INTO v_entry_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(payload->'items')
    LOOP
        v_variant_id := (v_item->>'variantId')::uuid;
        v_qty := (v_item->>'quantity')::numeric;
        v_unit_cost := COALESCE((v_item->>'unitCost')::numeric, 0);
        v_batch := COALESCE(NULLIF(trim(v_item->>'batchNumber'), ''), 'DEFAULT');
        v_expiry := NULLIF(v_item->>'expiryDate', '')::date;

        SELECT product_id INTO v_product_id FROM public.product_variants WHERE id = v_variant_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Variante no encontrada: %', v_variant_id;
        END IF;

        INSERT INTO public.inventory_entry_items (
            entry_id, product_id, variant_id, quantity, unit_cost, batch_number, expiry_date
        ) VALUES (
            v_entry_id, v_product_id, v_variant_id, v_qty, v_unit_cost, v_batch, v_expiry
        );

        SELECT available_quantity INTO v_old_qty
        FROM public.warehouse_stock_batches
        WHERE variant_id = v_variant_id AND warehouse_id = v_warehouse_id AND batch_number = v_batch
        FOR UPDATE;
        v_old_qty := COALESCE(v_old_qty, 0);

        INSERT INTO public.warehouse_stock_batches (
            variant_id, warehouse_id, product_id, batch_number, expiry_date, available_quantity,
            supplier_id, created_by, updated_by
        ) VALUES (
            v_variant_id, v_warehouse_id, v_product_id, v_batch, v_expiry, v_qty,
            NULLIF(payload->>'supplierId', '')::uuid, v_profile_id, v_profile_id
        )
        ON CONFLICT (variant_id, warehouse_id, batch_number)
        DO UPDATE SET
            available_quantity = public.warehouse_stock_batches.available_quantity + EXCLUDED.available_quantity,
            expiry_date = COALESCE(EXCLUDED.expiry_date, public.warehouse_stock_batches.expiry_date),
            updated_at = now(),
            updated_by = v_profile_id
        RETURNING id INTO v_batch_id;

        INSERT INTO public.inventory_movements (
            variant_id, warehouse_id, stock_batch_id, inventory_entry_id,
            quantity, previous_stock, new_stock, unit_cost, total_cost, reason, notes, created_by
        ) VALUES (
            v_variant_id, v_warehouse_id, v_batch_id, v_entry_id,
            v_qty, v_old_qty, v_old_qty + v_qty, v_unit_cost, ROUND(v_qty * v_unit_cost, 2),
            'PURCHASE_ENTRY', 'Recepción física #' || COALESCE(payload->>'documentNumber', substring(v_entry_id::text, 1, 8)), v_profile_id
        );

        v_total := v_total + (v_qty * v_unit_cost);
    END LOOP;

    UPDATE public.inventory_entries SET total_amount = v_total WHERE id = v_entry_id;
    RETURN v_entry_id;
END;
$$;


-- ============================================================================
-- 3. CONTABILIDAD BASE (PLAN DE CUENTAS PCGE + ASIENTOS DE PARTIDA DOBLE)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.chart_of_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    account_type text NOT NULL CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
    parent_code text REFERENCES public.chart_of_accounts(code),
    is_postable boolean NOT NULL DEFAULT true,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.chart_of_accounts (code, name, account_type, parent_code, is_postable) VALUES
    ('10', 'Efectivo y equivalentes de efectivo', 'ASSET', NULL, false),
    ('1011', 'Caja', 'ASSET', '10', true),
    ('1041', 'Cuentas corrientes operativas', 'ASSET', '10', true),
    ('12', 'Cuentas por cobrar comerciales', 'ASSET', NULL, false),
    ('1212', 'Facturas y boletas por cobrar', 'ASSET', '12', true),
    ('20', 'Mercaderías', 'ASSET', NULL, false),
    ('2011', 'Mercaderías manufacturadas', 'ASSET', '20', true),
    ('40', 'Tributos por pagar', 'LIABILITY', NULL, false),
    ('4011', 'IGV - Cuenta propia', 'LIABILITY', '40', true),
    ('42', 'Cuentas por pagar comerciales', 'LIABILITY', NULL, false),
    ('4212', 'Facturas por pagar', 'LIABILITY', '42', true),
    ('60', 'Compras', 'EXPENSE', NULL, false),
    ('6011', 'Mercaderías', 'EXPENSE', '60', true),
    ('63', 'Gastos de servicios prestados por terceros', 'EXPENSE', NULL, false),
    ('6399', 'Otros gastos operativos', 'EXPENSE', '63', true),
    ('69', 'Costo de ventas', 'EXPENSE', NULL, false),
    ('6911', 'Costo de ventas - Mercaderías', 'EXPENSE', '69', true),
    ('70', 'Ventas', 'REVENUE', NULL, false),
    ('7011', 'Ventas de mercaderías', 'REVENUE', '70', true)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.journal_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    entry_number text UNIQUE,
    entry_date date NOT NULL DEFAULT CURRENT_DATE,
    description text NOT NULL,
    reference_type text,
    reference_id uuid,
    status text NOT NULL DEFAULT 'POSTED' CHECK (status IN ('DRAFT', 'POSTED', 'VOIDED')),
    created_by uuid NOT NULL REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.journal_entry_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    journal_entry_id uuid NOT NULL REFERENCES public.journal_entries(id) ON DELETE CASCADE,
    account_code text NOT NULL REFERENCES public.chart_of_accounts(code),
    description text,
    debit numeric(14,2) NOT NULL DEFAULT 0.00 CHECK (debit >= 0),
    credit numeric(14,2) NOT NULL DEFAULT 0.00 CHECK (credit >= 0),
    CHECK ((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0))
);

ALTER TABLE public.chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entry_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "PCGE: Lectura autenticada" ON public.chart_of_accounts;
CREATE POLICY "PCGE: Lectura autenticada" ON public.chart_of_accounts FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "PCGE: Gestión por permiso" ON public.chart_of_accounts;
CREATE POLICY "PCGE: Gestión por permiso" ON public.chart_of_accounts FOR ALL TO authenticated
    USING (public.user_has_permission('accounting.manage'))
    WITH CHECK (public.user_has_permission('accounting.manage'));

DROP POLICY IF EXISTS "Asientos: Lectura por permiso" ON public.journal_entries;
CREATE POLICY "Asientos: Lectura por permiso" ON public.journal_entries FOR SELECT TO authenticated
    USING (public.user_has_permission('accounting.read'));
DROP POLICY IF EXISTS "Asientos: Gestión por permiso" ON public.journal_entries;
CREATE POLICY "Asientos: Gestión por permiso" ON public.journal_entries FOR ALL TO authenticated
    USING (public.user_has_permission('accounting.manage'))
    WITH CHECK (public.user_has_permission('accounting.manage'));

DROP POLICY IF EXISTS "Líneas asiento: Lectura por permiso" ON public.journal_entry_lines;
CREATE POLICY "Líneas asiento: Lectura por permiso" ON public.journal_entry_lines FOR SELECT TO authenticated
    USING (public.user_has_permission('accounting.read'));
DROP POLICY IF EXISTS "Líneas asiento: Gestión por permiso" ON public.journal_entry_lines;
CREATE POLICY "Líneas asiento: Gestión por permiso" ON public.journal_entry_lines FOR ALL TO authenticated
    USING (public.user_has_permission('accounting.manage'))
    WITH CHECK (public.user_has_permission('accounting.manage'));

-- RPC transaccional de asiento contable (exige Debe == Haber)
CREATE OR REPLACE FUNCTION public.rpc_create_journal_entry(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_profile_id uuid;
    v_entry_id uuid;
    v_total_debit numeric := 0;
    v_total_credit numeric := 0;
    v_line jsonb;
BEGIN
    SELECT id INTO v_profile_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin perfil válido.';
    END IF;
    IF NOT public.user_has_permission('accounting.manage') THEN
        RAISE EXCEPTION 'Sin permiso contable (accounting.manage).' USING ERRCODE = '42501';
    END IF;

    SELECT
        COALESCE(SUM((l->>'debit')::numeric), 0),
        COALESCE(SUM((l->>'credit')::numeric), 0)
    INTO v_total_debit, v_total_credit
    FROM jsonb_array_elements(payload->'lines') AS l;

    IF v_total_debit <= 0 OR ABS(v_total_debit - v_total_credit) > 0.01 THEN
        RAISE EXCEPTION 'El asiento no cuadra: Debe (%) <> Haber (%).', v_total_debit, v_total_credit;
    END IF;

    INSERT INTO public.journal_entries (
        entry_number, entry_date, description, reference_type, reference_id, created_by
    ) VALUES (
        COALESCE(NULLIF(payload->>'entryNumber', ''), 'ASI-' || to_char(now(), 'YYYYMMDD-HH24MISS') || '-' || substr(gen_random_uuid()::text, 1, 4)),
        COALESCE((payload->>'entryDate')::date, CURRENT_DATE),
        payload->>'description',
        payload->>'referenceType',
        NULLIF(payload->>'referenceId', '')::uuid,
        v_profile_id
    ) RETURNING id INTO v_entry_id;

    FOR v_line IN SELECT * FROM jsonb_array_elements(payload->'lines')
    LOOP
        INSERT INTO public.journal_entry_lines (
            journal_entry_id, account_code, description, debit, credit
        ) VALUES (
            v_entry_id,
            v_line->>'accountCode',
            v_line->>'description',
            COALESCE((v_line->>'debit')::numeric, 0),
            COALESCE((v_line->>'credit')::numeric, 0)
        );
    END LOOP;

    RETURN v_entry_id;
END;
$$;


-- ============================================================================
-- 4. REGISTRO DE NUEVOS PERMISOS RBAC
-- ============================================================================

INSERT INTO public.permissions (code, name, module) VALUES
    ('customers.read',    'Ver clientes',                 'customers'),
    ('customers.manage',  'Gestionar clientes',           'customers'),
    ('inventory.read',    'Ver inventario y transferencias', 'inventory'),
    ('inventory.manage',  'Gestionar inventario y transferencias', 'inventory'),
    ('finance.read',      'Ver finanzas y gastos',        'finance'),
    ('finance.manage',    'Registrar gastos y ajustes',   'finance'),
    ('accounting.read',   'Ver plan contable y asientos', 'accounting'),
    ('accounting.manage', 'Registrar asientos contables', 'accounting')
ON CONFLICT (code) DO NOTHING;

GRANT EXECUTE ON FUNCTION public.rpc_upsert_customer(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_receive_inventory_only(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_create_journal_entry(jsonb) TO authenticated, service_role;

COMMIT;

