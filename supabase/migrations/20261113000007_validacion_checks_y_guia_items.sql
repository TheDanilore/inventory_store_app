-- ============================================================================
-- MIGRACIÓN 7: CHECKS FINALES, DETALLE DE GUÍAS SUNAT Y PRECISIÓN DE VARIANTES
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. PUNTOS PARA CLIENTES SIN CUENTA (wallet_movements.profile_id NULLABLE)
-- ============================================================================

ALTER TABLE public.wallet_movements
    ALTER COLUMN profile_id DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'wallet_movements_owner_check') THEN
        ALTER TABLE public.wallet_movements
            ADD CONSTRAINT wallet_movements_owner_check
            CHECK (profile_id IS NOT NULL OR customer_id IS NOT NULL);
    END IF;
END $$;

COMMENT ON TABLE public.customers IS 'Entidad canónica de clientes ERP (personas y empresas RUC/DNI). profile_id es opcional para clientes con cuenta en tienda online.';
COMMENT ON COLUMN public.orders.customer_record_id IS 'FK canónica hacia public.customers (usar en nuevos flujos).';
COMMENT ON COLUMN public.orders.customer_id IS 'TRANSICIÓN: FK legado hacia public.profiles; sincronizado vía trigger con customer_record_id.';


-- ============================================================================
-- 2. CONTABILIDAD: CHECK EN REGLAS DE CONTABILIZACIÓN
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'accounting_posting_rules_mode_check') THEN
        ALTER TABLE public.accounting_posting_rules
            ADD CONSTRAINT accounting_posting_rules_mode_check
            CHECK (
                (debit_account_code IS NOT NULL AND credit_account_code IS NOT NULL)
                OR (debit_account_code IS NULL AND credit_account_code IS NULL)
            );
    END IF;
END $$;


-- ============================================================================
-- 3. GUÍAS DE REMISIÓN SUNAT: CHECK DE ORIGEN Y TABLA dispatch_guide_items
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'dispatch_guides_source_check') THEN
        ALTER TABLE public.dispatch_guides
            ADD CONSTRAINT dispatch_guides_source_check
            CHECK (electronic_document_id IS NOT NULL OR transfer_id IS NOT NULL OR order_id IS NOT NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'dispatch_guides_reason_check') THEN
        ALTER TABLE public.dispatch_guides
            ADD CONSTRAINT dispatch_guides_reason_check
            CHECK (transfer_reason_code IN ('01','02','03','04','05','06','07','08','09','13','14','17','18'));
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.dispatch_guide_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    dispatch_guide_id uuid NOT NULL REFERENCES public.dispatch_guides(id) ON DELETE CASCADE,
    variant_id uuid NOT NULL REFERENCES public.product_variants(id),
    unit_code text NOT NULL DEFAULT 'NIU' REFERENCES public.units_of_measure(code),
    quantity numeric(12,4) NOT NULL CHECK (quantity > 0),
    description text NOT NULL,
    gross_weight_kg numeric(12,3) DEFAULT 0.000
);

CREATE INDEX IF NOT EXISTS idx_dispatch_guide_items_guide_id ON public.dispatch_guide_items(dispatch_guide_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_guide_items_variant_id ON public.dispatch_guide_items(variant_id);

ALTER TABLE public.dispatch_guide_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Items guía remisión: Gestión por permiso" ON public.dispatch_guide_items;
CREATE POLICY "Items guía remisión: Gestión por permiso" ON public.dispatch_guide_items FOR ALL TO authenticated
    USING (public.user_has_permission('inventory.read') OR public.user_has_permission('orders.read'))
    WITH CHECK (public.user_has_permission('inventory.manage') OR public.user_has_permission('pos.sale'));


-- ============================================================================
-- 4. CHECKS FALTANTES EN ESTADOS, RAZONES Y COHERENCIA DE ÓRDENES
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_exits_reason_check') THEN
        ALTER TABLE public.inventory_exits
            ADD CONSTRAINT inventory_exits_reason_check
            CHECK (reason IN ('DAMAGED', 'EXPIRED', 'THEFT', 'INTERNAL_USE', 'SAMPLE', 'ADJUSTMENT', 'OTHER', 'MERMA', 'VENCIMIENTO', 'CONSUMO_INTERNO', 'OTRO')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'wallet_movements_type_check') THEN
        ALTER TABLE public.wallet_movements
            ADD CONSTRAINT wallet_movements_type_check
            CHECK (movement_type IN ('EARNED', 'REDEEMED', 'ADJUSTMENT', 'CHECKIN', 'EXPIRED', 'REFUND', 'BONUS')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'warehouses_type_check') THEN
        ALTER TABLE public.warehouses
            ADD CONSTRAINT warehouses_type_check
            CHECK (type IN ('STORE', 'WAREHOUSE', 'TIENDA', 'ALMACEN', 'PRINCIPAL', 'SUCURSAL')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_amount_paid_coherence') THEN
        ALTER TABLE public.orders
            ADD CONSTRAINT orders_amount_paid_coherence
            CHECK (amount_paid >= 0 AND amount_paid <= total_amount) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_sunat_totals_coherence') THEN
        ALTER TABLE public.orders
            ADD CONSTRAINT orders_sunat_totals_coherence
            CHECK (
                (total_gravado + total_exonerado + total_inafecto) = 0
                OR ABS((total_gravado + total_exonerado + total_inafecto + tax_amount + icbper_amount - discount_amount) - total_amount) <= 0.05
            ) NOT VALID;
    END IF;
END $$;


-- ============================================================================
-- 5. COMPRAS (currency_code NOT NULL + FK) Y PRECISIÓN EN product_variants
-- ============================================================================

UPDATE public.purchase_orders SET currency_code = 'PEN' WHERE currency_code IS NULL;
ALTER TABLE public.purchase_orders ALTER COLUMN currency_code SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'purchase_orders_currency_code_fkey') THEN
        ALTER TABLE public.purchase_orders
            ADD CONSTRAINT purchase_orders_currency_code_fkey
            FOREIGN KEY (currency_code) REFERENCES public.currencies(code) NOT VALID;
    END IF;
END $$;

ALTER TABLE public.purchase_orders DROP CONSTRAINT IF EXISTS purchase_orders_document_type_check;
ALTER TABLE public.purchase_orders
    ADD CONSTRAINT purchase_orders_document_type_check
    CHECK (document_type IN ('FACTURA', 'BOLETA', 'RECIBO_HONORARIOS', 'NOTA_CREDITO', 'NOTA_DEBITO', 'GUIA_REMISION', 'NINGUNO', 'OTRO')) NOT VALID;

ALTER TABLE public.product_variants
    ALTER COLUMN sale_price TYPE numeric(14,4),
    ALTER COLUMN wholesale_price TYPE numeric(14,4),
    ALTER COLUMN unit_cost TYPE numeric(14,4);

COMMIT;

