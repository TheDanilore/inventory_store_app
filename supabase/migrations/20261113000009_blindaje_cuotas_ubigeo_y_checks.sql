-- ============================================================================
-- MIGRACIÓN 9: CUADRATURA DE CUOTAS, CACHE DE PAGOS, UBIGEO SUNAT Y CHECKS
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ORDER_INSTALLMENTS: CUADRE CON ORDERS Y ESTADO SIN OVERDUE ALMACENADO
-- ============================================================================

UPDATE public.order_installments SET status = 'PENDING' WHERE status = 'OVERDUE';

ALTER TABLE public.order_installments DROP CONSTRAINT IF EXISTS order_installments_status_check;
ALTER TABLE public.order_installments
    ADD CONSTRAINT order_installments_status_check
    CHECK (status IN ('PENDING', 'PAID', 'CANCELLED'));

-- Vista con estado derivado (calcula OVERDUE en tiempo real sin cron)
CREATE OR REPLACE VIEW public.v_order_installments_status WITH (security_invoker = true) AS
SELECT
    id,
    order_id,
    installment_number,
    due_date,
    amount,
    CASE
        WHEN status = 'PENDING' AND due_date < CURRENT_DATE THEN 'OVERDUE'
        ELSE status
    END AS effective_status,
    status AS stored_status,
    paid_at
FROM public.order_installments;

-- Constraint trigger DEFERRABLE: la suma de cuotas debe igualar el saldo pendiente/total de la orden
CREATE OR REPLACE FUNCTION public.trg_check_installments_sum()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id uuid := COALESCE(NEW.order_id, OLD.order_id);
    v_sum_installments numeric;
    v_order_total numeric;
    v_order_paid numeric;
    v_count int;
BEGIN
    SELECT COUNT(*), COALESCE(SUM(amount), 0)
    INTO v_count, v_sum_installments
    FROM public.order_installments
    WHERE order_id = v_order_id AND status <> 'CANCELLED';

    IF v_count > 0 THEN
        SELECT total_amount, amount_paid
        INTO v_order_total, v_order_paid
        FROM public.orders
        WHERE id = v_order_id;

        IF ABS(v_sum_installments - (v_order_total - v_order_paid)) > 0.05
           AND ABS(v_sum_installments - v_order_total) > 0.05 THEN
            RAISE EXCEPTION 'La suma de cuotas (%) no cuadra con la orden % (Total: %, Pagado: %).',
                v_sum_installments, v_order_id, v_order_total, v_order_paid;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_installments_sum_deferred ON public.order_installments;
CREATE CONSTRAINT TRIGGER trg_order_installments_sum_deferred
    AFTER INSERT OR UPDATE OR DELETE ON public.order_installments
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION public.trg_check_installments_sum();


-- ============================================================================
-- 2. ORDERS: SINCRONIZACIÓN AUTOMÁTICA DE PAGOS DESDE order_payments Y TOTALES
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_sync_order_payment_cache()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order_id uuid := COALESCE(NEW.order_id, OLD.order_id);
    v_paid numeric(14,2);
    v_total numeric(14,2);
BEGIN
    SELECT COALESCE(SUM(amount_base), 0)
    INTO v_paid
    FROM public.order_payments
    WHERE order_id = v_order_id;

    SELECT total_amount_base INTO v_total FROM public.orders WHERE id = v_order_id;
    IF v_total IS NULL OR v_total = 0 THEN
        SELECT total_amount INTO v_total FROM public.orders WHERE id = v_order_id;
    END IF;

    UPDATE public.orders
    SET
        amount_paid = v_paid,
        payment_status = CASE
            WHEN v_paid <= 0 THEN 'PENDING'
            WHEN v_paid < COALESCE(v_total, 0) THEN 'PARTIAL'
            ELSE 'PAID'
        END
    WHERE id = v_order_id;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_payments_sync_cache ON public.order_payments;
CREATE TRIGGER trg_order_payments_sync_cache
    AFTER INSERT OR UPDATE OR DELETE ON public.order_payments
    FOR EACH ROW EXECUTE FUNCTION public.trg_sync_order_payment_cache();

-- Incluir shipping_cost en el CHECK de coherencia de totales SUNAT
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_sunat_totals_coherence;
ALTER TABLE public.orders
    ADD CONSTRAINT orders_sunat_totals_coherence
    CHECK (
        (total_gravado + total_exonerado + total_inafecto) = 0
        OR ABS((total_gravado + total_exonerado + total_inafecto + tax_amount + icbper_amount + shipping_cost - discount_amount) - total_amount) <= 0.05
    ) NOT VALID;


-- ============================================================================
-- 3. DISPATCH_GUIDES: UBIGEO OBLIGATORIO (6 DÍGITOS SUNAT)
-- ============================================================================

UPDATE public.dispatch_guides SET origin_ubigeo = '150101' WHERE origin_ubigeo IS NULL;
UPDATE public.dispatch_guides SET dest_ubigeo = '150101' WHERE dest_ubigeo IS NULL;

ALTER TABLE public.dispatch_guides
    ALTER COLUMN origin_ubigeo SET DEFAULT '150101',
    ALTER COLUMN origin_ubigeo SET NOT NULL,
    ALTER COLUMN dest_ubigeo SET DEFAULT '150101',
    ALTER COLUMN dest_ubigeo SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'dispatch_guides_ubigeo_format_check') THEN
        ALTER TABLE public.dispatch_guides
            ADD CONSTRAINT dispatch_guides_ubigeo_format_check
            CHECK (origin_ubigeo ~ '^[0-9]{6}$' AND dest_ubigeo ~ '^[0-9]{6}$');
    END IF;
END $$;


-- ============================================================================
-- 4. SORTEOS (SOLO customers), EXCHANGE_RATES Y SUNAT COMMENTS
-- ============================================================================

-- Usar solo customer_id -> customers en raffle_tickets (sin profile_id duplicado)
DROP POLICY IF EXISTS "Tickets sorteo: Lectura propia o permiso" ON public.raffle_tickets;
ALTER TABLE public.raffle_tickets DROP COLUMN IF EXISTS profile_id;
CREATE POLICY "Tickets sorteo: Lectura propia o permiso" ON public.raffle_tickets FOR SELECT TO authenticated
    USING (
        customer_id IN (
            SELECT c.id
            FROM public.customers c
            JOIN public.profiles p ON p.id = c.profile_id
            WHERE p.auth_user_id = auth.uid()
        )
        OR public.user_has_permission('customers.read')
    );

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.raffle_tickets WHERE customer_id IS NULL) THEN
        ALTER TABLE public.raffle_tickets ALTER COLUMN customer_id SET NOT NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'raffles_dates_check') THEN
        ALTER TABLE public.raffles
            ADD CONSTRAINT raffles_dates_check
            CHECK (start_date < end_date AND end_date <= draw_date);
    END IF;
END $$;

-- exchange_rates: UNIQUE (currency_code, rate_date, source) y sell >= buy
ALTER TABLE public.exchange_rates DROP CONSTRAINT IF EXISTS exchange_rates_currency_code_rate_date_key;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'exchange_rates_unique_source') THEN
        ALTER TABLE public.exchange_rates
            ADD CONSTRAINT exchange_rates_unique_source UNIQUE (currency_code, rate_date, source);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'exchange_rates_buy_sell_check') THEN
        ALTER TABLE public.exchange_rates
            ADD CONSTRAINT exchange_rates_buy_sell_check CHECK (buy_rate > 0 AND sell_rate >= buy_rate);
    END IF;
END $$;

COMMENT ON COLUMN public.sunat_daily_summary_items.condition_code IS 'Catálogo 19 SUNAT: 1=Adicionar, 2=Modificar, 3=Anular.';


-- ============================================================================
-- 5. CHECKS RESTANTES (exchange_rate, tax_rate, expenses, price_lists)
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'expenses_exchange_rate_pos') THEN
        ALTER TABLE public.expenses ADD CONSTRAINT expenses_exchange_rate_pos CHECK (exchange_rate > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_entries_exchange_rate_pos') THEN
        ALTER TABLE public.inventory_entries ADD CONSTRAINT inventory_entries_exchange_rate_pos CHECK (exchange_rate > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'purchase_orders_exchange_rate_pos') THEN
        ALTER TABLE public.purchase_orders ADD CONSTRAINT purchase_orders_exchange_rate_pos CHECK (exchange_rate > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'purchase_invoices_exchange_rate_pos') THEN
        ALTER TABLE public.purchase_invoices ADD CONSTRAINT purchase_invoices_exchange_rate_pos CHECK (exchange_rate > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pi_payments_exchange_rate_pos') THEN
        ALTER TABLE public.purchase_invoice_payments ADD CONSTRAINT pi_payments_exchange_rate_pos CHECK (exchange_rate > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'quotations_exchange_rate_pos') THEN
        ALTER TABLE public.quotations ADD CONSTRAINT quotations_exchange_rate_pos CHECK (exchange_rate > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'expenses_document_type_check') THEN
        ALTER TABLE public.expenses ADD CONSTRAINT expenses_document_type_check
            CHECK (document_type IS NULL OR document_type IN ('FACTURA', 'BOLETA', 'RECIBO_HONORARIOS', 'TICKET', 'NOTA_VENTA', 'NINGUNO', 'OTRO')) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'price_lists_dates_check') THEN
        ALTER TABLE public.price_lists ADD CONSTRAINT price_lists_dates_check
            CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to > valid_from);
    END IF;
END $$;

ALTER TABLE public.quotation_items
    ADD COLUMN IF NOT EXISTS tax_rate numeric(5,2) NOT NULL DEFAULT 18.00 CHECK (tax_rate BETWEEN 0 AND 100);


-- ============================================================================
-- 6. PRECISIÓN NUMÉRICA RESTANTE
-- ============================================================================

ALTER TABLE public.physical_inventory_items
    ALTER COLUMN system_quantity TYPE numeric(14,4),
    ALTER COLUMN counted_quantity TYPE numeric(14,4),
    ALTER COLUMN difference TYPE numeric(14,4);

ALTER TABLE public.purchase_order_items
    ALTER COLUMN net_cost TYPE numeric(14,4),
    ALTER COLUMN subtotal TYPE numeric(14,2);

ALTER TABLE public.inventory_movements
    ALTER COLUMN unit_cost TYPE numeric(14,4),
    ALTER COLUMN total_cost TYPE numeric(14,2);

COMMIT;

