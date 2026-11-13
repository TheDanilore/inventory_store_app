-- ============================================================================
-- MIGRACIÓN 8: CORRECCIONES DE DUMP, FISCAL PERÚ/SUNAT COMPLETO Y E-COMMERCE
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. CORRECCIONES CRÍTICAS DEL DUMP
-- ============================================================================

-- 1.1 electronic_documents: soportar Guías de Remisión de traslados
ALTER TABLE public.electronic_documents
    ADD COLUMN IF NOT EXISTS dispatch_guide_id uuid REFERENCES public.dispatch_guides(id);

CREATE INDEX IF NOT EXISTS idx_edocs_dispatch_guide_id
    ON public.electronic_documents(dispatch_guide_id);

DO $$
DECLARE
    v_con text;
BEGIN
    SELECT conname INTO v_con
    FROM pg_constraint
    WHERE conrelid = 'public.electronic_documents'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%order_id IS NOT NULL%'
    LIMIT 1;

    IF v_con IS NOT NULL THEN
        EXECUTE format('ALTER TABLE public.electronic_documents DROP CONSTRAINT %I', v_con);
    END IF;
END $$;

ALTER TABLE public.electronic_documents
    ADD CONSTRAINT electronic_documents_source_check
    CHECK (order_id IS NOT NULL OR sales_return_id IS NOT NULL OR dispatch_guide_id IS NOT NULL);

-- 1.2 purchase_orders.document_type: asegurar CHECK ampliado
ALTER TABLE public.purchase_orders DROP CONSTRAINT IF EXISTS purchase_orders_document_type_check;
ALTER TABLE public.purchase_orders
    ADD CONSTRAINT purchase_orders_document_type_check
    CHECK (document_type IN ('FACTURA', 'BOLETA', 'RECIBO_HONORARIOS', 'NOTA_CREDITO', 'NOTA_DEBITO', 'GUIA_REMISION', 'NINGUNO', 'OTRO')) NOT VALID;

-- 1.3 order_payments: eliminar payment_method duplicado, dejar solo payment_method_code
DROP TRIGGER IF EXISTS trg_order_payments_sync_method ON public.order_payments;
DROP FUNCTION IF EXISTS public.trg_sync_order_payment_method();
ALTER TABLE public.order_payments DROP COLUMN IF EXISTS payment_method;

-- 1.4 Defaults coherentes en orders y purchase_orders (PENDING en lugar de PAID con 0)
ALTER TABLE public.orders ALTER COLUMN payment_status SET DEFAULT 'PENDING';
ALTER TABLE public.purchase_orders ALTER COLUMN payment_status SET DEFAULT 'PENDING';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_payment_coherence_check') THEN
        ALTER TABLE public.orders
            ADD CONSTRAINT orders_payment_coherence_check
            CHECK (
                total_amount = 0
                OR (payment_status = 'PENDING' AND amount_paid = 0)
                OR (payment_status = 'PARTIAL' AND amount_paid > 0 AND amount_paid < total_amount)
                OR (payment_status = 'PAID' AND amount_paid >= total_amount)
            ) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'po_payment_coherence_check') THEN
        ALTER TABLE public.purchase_orders
            ADD CONSTRAINT po_payment_coherence_check
            CHECK (
                amount_paid >= 0 AND amount_paid <= total_amount
                AND (
                    total_amount = 0
                    OR (payment_status = 'PENDING' AND amount_paid = 0)
                    OR (payment_status = 'PARTIAL' AND amount_paid > 0 AND amount_paid < total_amount)
                    OR (payment_status = 'PAID' AND amount_paid >= total_amount)
                )
            ) NOT VALID;
    END IF;
END $$;

-- 1.5 app_settings.value nullable según value_type
ALTER TABLE public.app_settings ALTER COLUMN value DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'app_settings_value_by_type_check') THEN
        ALTER TABLE public.app_settings
            ADD CONSTRAINT app_settings_value_by_type_check
            CHECK (
                (value_type = 'NUMERIC' AND value IS NOT NULL)
                OR (value_type <> 'NUMERIC' AND value_text IS NOT NULL)
            ) NOT VALID;
    END IF;
END $$;


-- ============================================================================
-- 2. FISCAL PERÚ / SUNAT COMPLETO
-- ============================================================================

-- 2.1 dispatch_guides: remitente, destinatario y checks condicionales por modalidad
ALTER TABLE public.dispatch_guides
    ADD COLUMN IF NOT EXISTS sender_document_type text DEFAULT 'RUC',
    ADD COLUMN IF NOT EXISTS sender_document_number text,
    ADD COLUMN IF NOT EXISTS sender_name text,
    ADD COLUMN IF NOT EXISTS recipient_document_type text,
    ADD COLUMN IF NOT EXISTS recipient_document_number text,
    ADD COLUMN IF NOT EXISTS recipient_name text;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'dispatch_guides_transport_mode_check') THEN
        ALTER TABLE public.dispatch_guides
            ADD CONSTRAINT dispatch_guides_transport_mode_check
            CHECK (
                (transport_mode = '01' AND carrier_ruc IS NOT NULL AND carrier_name IS NOT NULL)
                OR (transport_mode = '02' AND vehicle_plate IS NOT NULL AND driver_document_number IS NOT NULL)
            ) NOT VALID;
    END IF;
END $$;

-- 2.2 Resumen Diario de Boletas (RC) y Comunicación de Baja (RA)
CREATE TABLE IF NOT EXISTS public.sunat_daily_summaries (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    summary_type text NOT NULL CHECK (summary_type IN ('RC', 'RA')), -- RC: Resumen Boletas, RA: Baja
    summary_date date NOT NULL,
    correlative text NOT NULL,
    ticket_number text,
    sunat_status text NOT NULL DEFAULT 'PENDING' CHECK (sunat_status IN ('PENDING', 'SENT', 'ACCEPTED', 'REJECTED')),
    xml_url text,
    cdr_url text,
    response_message text,
    created_by uuid REFERENCES public.profiles(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (summary_type, summary_date, correlative)
);

CREATE TABLE IF NOT EXISTS public.sunat_daily_summary_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    summary_id uuid NOT NULL REFERENCES public.sunat_daily_summaries(id) ON DELETE CASCADE,
    electronic_document_id uuid NOT NULL REFERENCES public.electronic_documents(id),
    condition_code text NOT NULL DEFAULT '1' CHECK (condition_code IN ('1', '2', '3')), -- 1: Adicionar, 2: Modificar, 3: Anular
    reason text
);

CREATE INDEX IF NOT EXISTS idx_sunat_summary_items_summary ON public.sunat_daily_summary_items(summary_id);
CREATE INDEX IF NOT EXISTS idx_sunat_summary_items_edoc ON public.sunat_daily_summary_items(electronic_document_id);

ALTER TABLE public.sunat_daily_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sunat_daily_summary_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "SUNAT resúmenes: Gestión por permiso" ON public.sunat_daily_summaries;
CREATE POLICY "SUNAT resúmenes: Gestión por permiso" ON public.sunat_daily_summaries FOR ALL TO authenticated
    USING (public.user_has_permission('orders.read'))
    WITH CHECK (public.user_has_permission('pos.sale'));

DROP POLICY IF EXISTS "SUNAT resumen items: Gestión por permiso" ON public.sunat_daily_summary_items;
CREATE POLICY "SUNAT resumen items: Gestión por permiso" ON public.sunat_daily_summary_items FOR ALL TO authenticated
    USING (public.user_has_permission('orders.read'))
    WITH CHECK (public.user_has_permission('pos.sale'));

-- 2.3 Cronograma de cuotas para facturas al crédito (SUNAT UBL 2.1)
CREATE TABLE IF NOT EXISTS public.order_installments (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    installment_number integer NOT NULL CHECK (installment_number > 0),
    due_date date NOT NULL,
    amount numeric(14,2) NOT NULL CHECK (amount > 0),
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'OVERDUE')),
    paid_at timestamptz,
    UNIQUE (order_id, installment_number)
);

CREATE INDEX IF NOT EXISTS idx_order_installments_order_id ON public.order_installments(order_id);
ALTER TABLE public.order_installments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Cuotas orden: Gestión por permiso" ON public.order_installments;
CREATE POLICY "Cuotas orden: Gestión por permiso" ON public.order_installments FOR ALL TO authenticated
    USING (public.user_has_permission('orders.read'))
    WITH CHECK (public.user_has_permission('pos.sale'));

-- 2.4 Detracción completa en orders
ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS detraction_percentage numeric(5,2) NOT NULL DEFAULT 0.00 CHECK (detraction_percentage BETWEEN 0 AND 100),
    ADD COLUMN IF NOT EXISTS detraction_account_number text;

-- 2.5 Historial de tipo de cambio por fecha
CREATE TABLE IF NOT EXISTS public.exchange_rates (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    currency_code text NOT NULL REFERENCES public.currencies(code),
    rate_date date NOT NULL,
    buy_rate numeric(12,4) NOT NULL CHECK (buy_rate > 0),
    sell_rate numeric(12,4) NOT NULL CHECK (sell_rate > 0),
    source text NOT NULL DEFAULT 'SUNAT',
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (currency_code, rate_date)
);

ALTER TABLE public.exchange_rates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Tipo cambio: Lectura autenticada" ON public.exchange_rates;
CREATE POLICY "Tipo cambio: Lectura autenticada" ON public.exchange_rates FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Tipo cambio: Gestión por permiso" ON public.exchange_rates;
CREATE POLICY "Tipo cambio: Gestión por permiso" ON public.exchange_rates FOR ALL TO authenticated
    USING (public.user_has_permission('finance.manage'))
    WITH CHECK (public.user_has_permission('finance.manage'));


-- ============================================================================
-- 3. INTEGRIDAD DE DATOS, PRECISIONES Y VALIDACIONES
-- ============================================================================

-- 3.1 exchange_rate > 0 y tax_rate BETWEEN 0 AND 100
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_exchange_rate_pos') THEN
        ALTER TABLE public.orders ADD CONSTRAINT orders_exchange_rate_pos CHECK (exchange_rate > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'order_payments_exchange_rate_pos') THEN
        ALTER TABLE public.order_payments ADD CONSTRAINT order_payments_exchange_rate_pos CHECK (exchange_rate > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'account_movements_exchange_rate_pos') THEN
        ALTER TABLE public.account_movements ADD CONSTRAINT account_movements_exchange_rate_pos CHECK (exchange_rate > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_movements_exchange_rate_pos') THEN
        ALTER TABLE public.inventory_movements ADD CONSTRAINT inventory_movements_exchange_rate_pos CHECK (exchange_rate > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'order_items_tax_rate_range') THEN
        ALTER TABLE public.order_items ADD CONSTRAINT order_items_tax_rate_range CHECK (tax_rate BETWEEN 0 AND 100);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'sales_return_items_tax_rate_range') THEN
        ALTER TABLE public.sales_return_items ADD CONSTRAINT sales_return_items_tax_rate_range CHECK (tax_rate BETWEEN 0 AND 100);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'products_tax_rate_range') THEN
        ALTER TABLE public.products ADD CONSTRAINT products_tax_rate_range CHECK (tax_rate BETWEEN 0 AND 100);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'categories_tax_rate_range') THEN
        ALTER TABLE public.categories ADD CONSTRAINT categories_tax_rate_range CHECK (default_tax_rate BETWEEN 0 AND 100);
    END IF;
END $$;

-- 3.2 Precisión monetaria restante
DROP VIEW IF EXISTS public.customer_credit_movements_summary;

ALTER TABLE public.customer_credit_movements
    ALTER COLUMN amount TYPE numeric(14,2);

ALTER TABLE public.supplier_credit_movements
    ALTER COLUMN amount TYPE numeric(14,2);

ALTER TABLE public.inventory_entry_items
    ALTER COLUMN unit_cost TYPE numeric(14,4);

ALTER TABLE public.purchase_order_items
    ALTER COLUMN unit_cost TYPE numeric(14,4);

ALTER TABLE public.inventory_exit_items
    ALTER COLUMN unit_cost TYPE numeric(14,4);

COMMENT ON COLUMN public.quotations.customer_id IS 'TRANSICIÓN: FK legado hacia public.profiles; usar customer_record_id hacia public.customers.';


-- ============================================================================
-- 4. FUNCIONALIDAD: SORTEOS, E-COMMERCE EN ORDERS Y VISTA CORREGIDA
-- ============================================================================

-- 4.1 Sorteos (respalda business_info.raffles_global_enabled)
CREATE TABLE IF NOT EXISTS public.raffles (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    title text NOT NULL,
    description text,
    prize_description text NOT NULL,
    start_date timestamptz NOT NULL,
    end_date timestamptz NOT NULL,
    draw_date timestamptz NOT NULL,
    ticket_points_cost integer NOT NULL DEFAULT 0 CHECK (ticket_points_cost >= 0),
    status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'ACTIVE', 'DRAWN', 'CANCELLED')),
    winner_customer_id uuid REFERENCES public.customers(id),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.raffle_tickets (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    raffle_id uuid NOT NULL REFERENCES public.raffles(id) ON DELETE CASCADE,
    customer_id uuid REFERENCES public.customers(id),
    profile_id uuid REFERENCES public.profiles(id),
    ticket_number text NOT NULL,
    order_id uuid REFERENCES public.orders(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (raffle_id, ticket_number),
    CHECK (customer_id IS NOT NULL OR profile_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_raffle_tickets_raffle ON public.raffle_tickets(raffle_id);
CREATE INDEX IF NOT EXISTS idx_raffle_tickets_customer ON public.raffle_tickets(customer_id);

ALTER TABLE public.raffles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.raffle_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Sorteos: Lectura autenticada" ON public.raffles;
CREATE POLICY "Sorteos: Lectura autenticada" ON public.raffles FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Tickets sorteo: Lectura propia o permiso" ON public.raffle_tickets;
CREATE POLICY "Tickets sorteo: Lectura propia o permiso" ON public.raffle_tickets FOR SELECT TO authenticated
    USING (profile_id IN (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid()) OR public.user_has_permission('customers.read'));

-- 4.2 Campos de entrega y envío e-commerce en orders
ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS shipping_cost numeric(14,2) NOT NULL DEFAULT 0.00 CHECK (shipping_cost >= 0),
    ADD COLUMN IF NOT EXISTS delivery_location_id uuid REFERENCES public.customer_locations(id),
    ADD COLUMN IF NOT EXISTS delivery_address_snapshot text,
    ADD COLUMN IF NOT EXISTS fulfillment_status text NOT NULL DEFAULT 'PENDING'
        CHECK (fulfillment_status IN ('PENDING', 'PACKING', 'READY', 'DISPATCHED', 'DELIVERED', 'CANCELLED'));

CREATE INDEX IF NOT EXISTS idx_orders_delivery_location ON public.orders(delivery_location_id);

-- 4.3 Vista customer_credit_movements_summary con serie y número de documento real
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
    COALESCE(
        NULLIF(o.document_number, ''),
        CASE WHEN o.document_series IS NOT NULL THEN o.document_series || '-' || left(o.id::text, 8) ELSE '#' || left(o.id::text, 8) END
    ) AS order_number
FROM public.customer_credit_movements cm
LEFT JOIN public.profiles p ON p.id = cm.created_by
LEFT JOIN public.orders o ON o.id = cm.order_id;


-- ============================================================================
-- 5. ACTUALIZAR process_pos_sale PARA USAR SOLO payment_method_code EN order_payments
-- ============================================================================

CREATE OR REPLACE FUNCTION public.process_pos_sale(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_auth_user_id uuid := auth.uid();
  v_created_by uuid;
  v_order_id uuid;
  v_order_status text;
  v_is_draft boolean := COALESCE((payload->>'isDraft')::boolean, false);
  v_is_credit boolean := COALESCE((payload->>'isCredit')::boolean, false);
  v_amount_paid numeric := COALESCE((payload->>'amountPaid')::numeric, 0.00);
  v_total_amount numeric := COALESCE((payload->>'totalAmount')::numeric, 0.00);
  v_points_used int := COALESCE((payload->>'pointsUsed')::int, 0);
  v_points_earned int := COALESCE((payload->>'pointsEarned')::int, 0);
  v_customer_id uuid;
  v_account_id uuid;
  v_shift_id uuid;
  v_warehouse_id uuid := (payload->>'warehouseId')::uuid;

  v_doc_type text := COALESCE(payload->>'documentType', 'NOTA_VENTA');
  v_doc_series text := payload->>'documentSeries';
  v_doc_number text := payload->>'documentNumber';
  v_tax_amount numeric := COALESCE((payload->>'taxAmount')::numeric, 0.00);
  v_subtotal_amount numeric := COALESCE((payload->>'subtotalAmount')::numeric, (v_total_amount - v_tax_amount));
  v_payment_reference text := payload->>'paymentReference';
  v_customer_doc_type text := payload->>'customerDocumentType';
  v_customer_doc_num text := payload->>'customerDocumentNumber';
  v_customer_address text := payload->>'customerAddress';

  v_currency_code text := COALESCE(payload->>'currencyCode', 'PEN');
  v_exchange_rate numeric := COALESCE((payload->>'exchangeRate')::numeric, 1.0000);
  v_total_amount_base numeric := COALESCE((payload->>'totalAmountBase')::numeric, (v_total_amount * COALESCE((payload->>'exchangeRate')::numeric, 1.0000)));
  v_subtotal_amount_base numeric := COALESCE((payload->>'subtotalAmountBase')::numeric, (v_subtotal_amount * COALESCE((payload->>'exchangeRate')::numeric, 1.0000)));
  v_tax_amount_base numeric := COALESCE((payload->>'taxAmountBase')::numeric, (v_tax_amount * COALESCE((payload->>'exchangeRate')::numeric, 1.0000)));

  v_series_row record;
  v_next_correlative int;

  item jsonb;
  v_variant_id uuid;
  v_quantity numeric;
  v_remaining_qty numeric;

  v_tax_affectation text;
  v_item_discount numeric;
  v_item_tax_rate numeric;
  v_item_tax_amount numeric;
  v_item_unit_val_no_tax numeric;

  v_unit_cost numeric;
  v_applied_price numeric;
  v_total_cost numeric := 0;
  v_total_profit numeric := 0;

  batch_assign jsonb;
  batch_row record;
  v_take numeric;
  v_batch_number text;
  v_old_qty numeric;

  pay_item jsonb;
  v_pay_account_id uuid;
  v_pay_amount numeric;
  v_pay_method_code text;
  v_pay_ref text;
  v_pay_shift_id uuid;
  v_account_type text;
  v_current_balance numeric;

  v_credit_id uuid;
  v_current_debt numeric;
  v_credit_limit numeric;
  v_credit_active boolean;
  v_credit_disponible numeric;
BEGIN
  SELECT id INTO v_created_by FROM public.profiles WHERE auth_user_id = v_auth_user_id LIMIT 1;
  IF v_created_by IS NULL THEN
    RAISE EXCEPTION 'Usuario autenticado no posee un perfil válido en el sistema.';
  END IF;

  IF NOT public.user_has_permission('pos.sale') THEN
    RAISE EXCEPTION 'No cuenta con el permiso requerido para registrar ventas en el POS (pos.sale).' USING ERRCODE = '42501';
  END IF;

  IF payload->>'customerId' IS NOT NULL AND payload->>'customerId' != '' THEN v_customer_id := (payload->>'customerId')::uuid; END IF;
  IF payload->>'accountId' IS NOT NULL AND payload->>'accountId' != '' THEN v_account_id := (payload->>'accountId')::uuid; END IF;

  IF payload ? 'payments' AND jsonb_array_length(payload->'payments') > 0 AND v_amount_paid = 0 THEN
    SELECT COALESCE(SUM((p->>'amount')::numeric), 0)
    INTO v_amount_paid
    FROM jsonb_array_elements(payload->'payments') AS p;
  END IF;

  IF NOT v_is_draft AND v_is_credit AND v_customer_id IS NOT NULL THEN
    SELECT id, current_debt, credit_limit, is_active
      INTO v_credit_id, v_current_debt, v_credit_limit, v_credit_active
    FROM public.customer_credits
    WHERE profile_id = v_customer_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'El cliente no tiene línea de crédito registrada.' USING ERRCODE = 'P0010';
    END IF;
    IF NOT v_credit_active THEN
      RAISE EXCEPTION 'La línea de crédito del cliente no está activa.' USING ERRCODE = 'P0011';
    END IF;

    IF v_credit_limit > 0 THEN
      v_credit_disponible := v_credit_limit - v_current_debt;
      IF v_credit_disponible < (v_total_amount - v_amount_paid) THEN
        RAISE EXCEPTION 'Crédito insuficiente para esta venta. Disponible: %, Requerido: %',
          v_credit_disponible, (v_total_amount - v_amount_paid)
          USING ERRCODE = 'P0012';
      END IF;
    END IF;
  END IF;

  IF NOT v_is_draft AND v_doc_type IS NOT NULL AND v_doc_type != 'NINGUNO' THEN
    IF v_doc_series IS NULL OR trim(v_doc_series) = '' THEN
      SELECT * INTO v_series_row
      FROM public.document_series
      WHERE document_type = v_doc_type
        AND (warehouse_id = v_warehouse_id OR warehouse_id IS NULL)
        AND is_active = true
      ORDER BY (warehouse_id IS NOT NULL) DESC, is_default DESC
      LIMIT 1
      FOR UPDATE;
    ELSE
      SELECT * INTO v_series_row
      FROM public.document_series
      WHERE document_type = v_doc_type
        AND series = v_doc_series
        AND (warehouse_id = v_warehouse_id OR warehouse_id IS NULL)
        AND is_active = true
      ORDER BY (warehouse_id IS NOT NULL) DESC
      LIMIT 1
      FOR UPDATE;
    END IF;

    IF FOUND THEN
      v_next_correlative := v_series_row.current_correlative + 1;
      v_doc_series := v_series_row.series;
      v_doc_number := v_series_row.series || '-' || LPAD(v_next_correlative::text, v_series_row.correlative_padding, '0');

      UPDATE public.document_series
      SET current_correlative = v_next_correlative,
          updated_at = now()
      WHERE id = v_series_row.id;
    END IF;
  END IF;

  FOR item IN SELECT * FROM jsonb_array_elements(payload->'items')
  LOOP
    SELECT unit_cost INTO v_unit_cost
    FROM public.product_variants
    WHERE id = (item->>'variantId')::uuid;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variante no encontrada: %', item->>'variantId';
    END IF;

    v_total_cost := v_total_cost + COALESCE(v_unit_cost, 0) * (item->>'quantity')::numeric;
  END LOOP;

  v_total_profit := v_total_amount - v_total_cost;
  v_order_status := CASE WHEN v_is_draft THEN 'PENDING' ELSE 'COMPLETED' END;

  INSERT INTO public.orders (
    customer_id, customer_name, warehouse_id, total_amount, total_profit, discount_amount,
    payment_method, payment_status, amount_paid, status, points_used, points_earned, created_by,
    document_type, document_series, document_number, document_date,
    tax_amount, subtotal_amount, payment_reference,
    customer_document_type, customer_document_number, customer_address,
    currency_code, exchange_rate, total_amount_base, subtotal_amount_base, tax_amount_base
  ) VALUES (
    v_customer_id, NULLIF(payload->>'customerName', ''), v_warehouse_id, v_total_amount, v_total_profit,
    COALESCE((payload->>'discountAmount')::numeric, 0.00),
    COALESCE(payload->>'paymentMethod', CASE WHEN payload ? 'payments' AND jsonb_array_length(payload->'payments') > 1 THEN 'MIXTO' ELSE 'EFECTIVO' END),
    COALESCE(payload->>'paymentStatus', CASE WHEN v_is_draft THEN 'PENDING' ELSE 'PAID' END),
    v_amount_paid, v_order_status,
    CASE WHEN v_is_draft THEN 0 ELSE v_points_used END,
    CASE WHEN v_is_draft THEN 0 ELSE v_points_earned END,
    v_created_by,
    v_doc_type, v_doc_series, v_doc_number, CURRENT_DATE,
    v_tax_amount, v_subtotal_amount, v_payment_reference,
    v_customer_doc_type, v_customer_doc_num, v_customer_address,
    v_currency_code, v_exchange_rate, v_total_amount_base, v_subtotal_amount_base, v_tax_amount_base
  ) RETURNING id INTO v_order_id;

  INSERT INTO public.order_status_history (order_id, previous_status, new_status, notes, changed_by)
  VALUES (v_order_id, NULL, v_order_status, 'Creación desde POS', v_created_by);

  FOR item IN SELECT * FROM jsonb_array_elements(payload->'items')
  LOOP
    v_variant_id := (item->>'variantId')::uuid;
    v_quantity := (item->>'quantity')::numeric;

    SELECT COALESCE(unit_cost, 0) INTO v_unit_cost
    FROM public.product_variants WHERE id = v_variant_id;
    v_applied_price := (item->>'appliedPrice')::numeric;

    v_tax_affectation := COALESCE(item->>'taxAffectationType', '10');
    v_item_discount := COALESCE((item->>'discountAmount')::numeric, 0.00);
    v_item_tax_rate := COALESCE((item->>'taxRate')::numeric, CASE WHEN v_tax_affectation = '10' THEN 18.00 ELSE 0.00 END);
    v_item_unit_val_no_tax := COALESCE(
      (item->>'unitValueWithoutTax')::numeric,
      CASE WHEN v_tax_affectation = '10' AND v_item_tax_rate > 0 THEN ROUND(v_applied_price / (1 + v_item_tax_rate / 100.0), 4) ELSE v_applied_price END
    );
    v_item_tax_amount := COALESCE(
      (item->>'taxAmount')::numeric,
      ROUND(((v_applied_price * v_quantity) - v_item_discount) - (((v_applied_price * v_quantity) - v_item_discount) / (1 + v_item_tax_rate / 100.0)), 2)
    );

    INSERT INTO public.order_items (
      order_id, product_id, variant_id, quantity, unit_cost, applied_price, net_profit,
      applied_price_base, unit_cost_base,
      tax_affectation_type, discount_amount, unit_value_without_tax, tax_rate, tax_amount, tax_amount_base
    ) VALUES (
      v_order_id, (item->>'productId')::uuid, v_variant_id, v_quantity,
      v_unit_cost, v_applied_price, (v_applied_price - v_unit_cost) * v_quantity,
      (v_applied_price * v_exchange_rate), (v_unit_cost * v_exchange_rate),
      v_tax_affectation, v_item_discount, v_item_unit_val_no_tax, v_item_tax_rate,
      v_item_tax_amount, ROUND(v_item_tax_amount * v_exchange_rate, 2)
    );

    IF NOT v_is_draft THEN
      v_remaining_qty := v_quantity;

      IF item ? 'batchAssignments' AND jsonb_array_length(item->'batchAssignments') > 0 THEN
        FOR batch_assign IN SELECT * FROM jsonb_array_elements(item->'batchAssignments')
        LOOP
          v_take := (batch_assign->>'take')::numeric;
          v_batch_number := batch_assign->>'batchNumber';

          SELECT available_quantity INTO v_old_qty
          FROM public.warehouse_stock_batches
          WHERE id = (batch_assign->>'batchId')::uuid FOR UPDATE;

          IF v_old_qty < v_take THEN
            RAISE EXCEPTION 'Stock insuficiente en el lote manual % para la variante %. Disponible: %, Solicitado: %',
              v_batch_number, v_variant_id, v_old_qty, v_take;
          END IF;

          UPDATE public.warehouse_stock_batches
          SET available_quantity = available_quantity - v_take
          WHERE id = (batch_assign->>'batchId')::uuid;

          INSERT INTO public.inventory_movements (
            variant_id, warehouse_id, stock_batch_id, order_id, quantity, previous_stock, new_stock, unit_cost, reason, notes, created_by
          ) VALUES (
            v_variant_id, v_warehouse_id, (batch_assign->>'batchId')::uuid, v_order_id, -v_take, v_old_qty, v_old_qty - v_take, v_unit_cost, 'SALE',
            'Venta POS ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)) || ' • Lote: ' || v_batch_number, v_created_by
          );
        END LOOP;
      ELSE
        FOR batch_row IN
          SELECT id, available_quantity, batch_number
          FROM public.warehouse_stock_batches
          WHERE variant_id = v_variant_id AND warehouse_id = v_warehouse_id AND available_quantity > 0
          ORDER BY expiry_date ASC NULLS LAST
          FOR UPDATE
        LOOP
          IF v_remaining_qty <= 0 THEN EXIT; END IF;

          IF v_remaining_qty > batch_row.available_quantity THEN
            v_take := batch_row.available_quantity;
          ELSE
            v_take := v_remaining_qty;
          END IF;

          UPDATE public.warehouse_stock_batches
          SET available_quantity = available_quantity - v_take
          WHERE id = batch_row.id;

          INSERT INTO public.inventory_movements (
            variant_id, warehouse_id, stock_batch_id, order_id, quantity, previous_stock, new_stock, unit_cost, reason, notes, created_by
          ) VALUES (
            v_variant_id, v_warehouse_id, batch_row.id, v_order_id, -v_take, batch_row.available_quantity, batch_row.available_quantity - v_take, v_unit_cost, 'SALE',
            'Venta POS ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)) || ' • Lote: ' || batch_row.batch_number, v_created_by
          );

          v_remaining_qty := v_remaining_qty - v_take;
        END LOOP;

        IF v_remaining_qty > 0 THEN
          RAISE EXCEPTION 'Stock insuficiente global en almacén para el ítem variante %', v_variant_id;
        END IF;
      END IF;
    END IF;
  END LOOP;

  IF NOT v_is_draft THEN
    IF payload ? 'payments' AND jsonb_array_length(payload->'payments') > 0 THEN
      FOR pay_item IN SELECT * FROM jsonb_array_elements(payload->'payments')
      LOOP
        v_pay_account_id := NULLIF(pay_item->>'accountId', '')::uuid;
        v_pay_amount := (pay_item->>'amount')::numeric;
        v_pay_method_code := COALESCE(NULLIF(pay_item->>'paymentMethodCode', ''), NULLIF(pay_item->>'paymentMethod', ''), 'EFECTIVO');
        v_pay_ref := pay_item->>'referenceNumber';
        v_pay_shift_id := NULL;

        IF v_pay_amount > 0 THEN
          IF v_pay_account_id IS NOT NULL THEN
            SELECT type, balance INTO v_account_type, v_current_balance
            FROM public.financial_accounts
            WHERE id = v_pay_account_id FOR UPDATE;

            IF NOT FOUND THEN
              RAISE EXCEPTION 'Cuenta financiera no encontrada: %', v_pay_account_id;
            END IF;

            IF v_account_type = 'CAJA' THEN
              SELECT id INTO v_pay_shift_id
              FROM public.cash_shifts
              WHERE account_id = v_pay_account_id AND status = 'OPEN'
              FOR UPDATE;

              IF NOT FOUND THEN
                RAISE EXCEPTION 'No hay un turno de caja abierto para la cuenta seleccionada.';
              END IF;
            END IF;

            INSERT INTO public.account_movements (
              account_id, shift_id, movement_type, amount, description, reference_id, reference_type, created_by,
              currency_code, exchange_rate, amount_base
            ) VALUES (
              v_pay_account_id, v_pay_shift_id, 'INCOME', v_pay_amount,
              'Venta POS (' || v_pay_method_code || ') ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)),
              v_order_id, 'ORDER', v_created_by,
              v_currency_code, v_exchange_rate, ROUND(v_pay_amount * v_exchange_rate, 2)
            );

            UPDATE public.financial_accounts
            SET balance = balance + v_pay_amount
            WHERE id = v_pay_account_id;
          END IF;

          INSERT INTO public.order_payments (
            order_id, account_id, shift_id, payment_method_code, amount, currency_code, exchange_rate, amount_base, reference_number, created_by
          ) VALUES (
            v_order_id, v_pay_account_id, v_pay_shift_id, v_pay_method_code, v_pay_amount,
            v_currency_code, v_exchange_rate, ROUND(v_pay_amount * v_exchange_rate, 2), v_pay_ref, v_created_by
          );
        END IF;
      END LOOP;

    ELSIF v_account_id IS NOT NULL AND v_amount_paid > 0 THEN
      SELECT type, balance INTO v_account_type, v_current_balance
      FROM public.financial_accounts
      WHERE id = v_account_id FOR UPDATE;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuenta financiera no encontrada.';
      END IF;

      IF v_account_type = 'CAJA' THEN
        SELECT id INTO v_shift_id
        FROM public.cash_shifts
        WHERE account_id = v_account_id AND status = 'OPEN'
        FOR UPDATE;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'No hay un turno de caja abierto para procesar esta venta en efectivo.';
        END IF;
      ELSE
        v_shift_id := NULL;
      END IF;

      v_pay_method_code := COALESCE(NULLIF(payload->>'paymentMethod', ''), 'EFECTIVO');

      INSERT INTO public.account_movements (
        account_id, shift_id, movement_type, amount, description, reference_id, reference_type, created_by,
        currency_code, exchange_rate, amount_base
      ) VALUES (
        v_account_id, v_shift_id, 'INCOME', v_amount_paid,
        'Venta POS ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)),
        v_order_id, 'ORDER', v_created_by,
        v_currency_code, v_exchange_rate, (v_amount_paid * v_exchange_rate)
      );

      UPDATE public.financial_accounts
      SET balance = balance + v_amount_paid
      WHERE id = v_account_id;

      INSERT INTO public.order_payments (
        order_id, account_id, shift_id, payment_method_code, amount, currency_code, exchange_rate, amount_base, reference_number, created_by
      ) VALUES (
        v_order_id, v_account_id, v_shift_id, v_pay_method_code, v_amount_paid,
        v_currency_code, v_exchange_rate, ROUND(v_amount_paid * v_exchange_rate, 2), v_payment_reference, v_created_by
      );
    END IF;

    IF (v_points_earned > 0 OR v_points_used > 0) AND v_customer_id IS NOT NULL THEN
      UPDATE public.profiles
      SET wallet_balance = wallet_balance + v_points_earned - v_points_used
      WHERE id = v_customer_id;

      IF v_points_earned > 0 THEN
        INSERT INTO public.wallet_movements (profile_id, order_id, points, movement_type, description)
        VALUES (v_customer_id, v_order_id, v_points_earned, 'EARNED',
          'Puntos ganados por Venta ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)));
      END IF;

      IF v_points_used > 0 THEN
        INSERT INTO public.wallet_movements (profile_id, order_id, points, movement_type, description)
        VALUES (v_customer_id, v_order_id, v_points_used, 'REDEEMED',
          'Puntos canjeados en Venta ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)));
      END IF;
    END IF;

    IF v_is_credit AND v_customer_id IS NOT NULL AND (v_total_amount - v_amount_paid) > 0 THEN
      UPDATE public.customer_credits
      SET current_debt = current_debt + (v_total_amount - v_amount_paid)
      WHERE id = v_credit_id;

      INSERT INTO public.customer_credit_movements (
        customer_credit_id, order_id, movement_type, amount, notes, created_by
      ) VALUES (
        v_credit_id, v_order_id, 'CHARGE', (v_total_amount - v_amount_paid),
        'Venta al crédito - ' || COALESCE(v_doc_number, 'POS #' || substring(v_order_id::text, 1, 8)),
        v_created_by
      );
    END IF;
  END IF;

  RETURN v_order_id;
END;
$$;

COMMIT;

