-- ==============================================================================
-- MIGRACIÓN: Comprobantes de Pago POS (Nota de Venta, Boleta, Factura), Series y Correlativos
-- ==============================================================================

-- 1. Actualizar check constraint de tipo de comprobante en orders
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_document_type_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_document_type_check 
    CHECK (document_type = ANY (ARRAY['NOTA_VENTA'::text, 'BOLETA'::text, 'FACTURA'::text, 'TICKET'::text, 'NINGUNO'::text]));

-- 2. Agregar columnas fiscales y de comprobante a la tabla orders
ALTER TABLE public.orders 
    ADD COLUMN IF NOT EXISTS document_series text,
    ADD COLUMN IF NOT EXISTS tax_amount numeric DEFAULT 0.00 NOT NULL,
    ADD COLUMN IF NOT EXISTS subtotal_amount numeric DEFAULT 0.00 NOT NULL,
    ADD COLUMN IF NOT EXISTS customer_document_type text,   -- 'DNI', 'RUC', 'CE'
    ADD COLUMN IF NOT EXISTS customer_document_number text, -- '10723456789'
    ADD COLUMN IF NOT EXISTS customer_address text,         -- Dirección fiscal para facturas
    ADD COLUMN IF NOT EXISTS payment_reference text;        -- Nº Op / Ref (Yape, Plin, Tarjeta)

-- 3. Crear tabla de Series y Correlativos de Comprobantes
CREATE TABLE IF NOT EXISTS public.document_series (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_type text NOT NULL,                    -- 'NOTA_VENTA', 'BOLETA', 'FACTURA'
    series text NOT NULL,                           -- 'NV01', 'B001', 'F001'
    current_correlative int NOT NULL DEFAULT 0,
    correlative_padding int NOT NULL DEFAULT 8,     -- Formato: 00000001
    is_default boolean DEFAULT true,
    is_active boolean DEFAULT true,
    warehouse_id uuid REFERENCES public.warehouses(id) ON DELETE SET NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT document_series_type_check CHECK (document_type = ANY (ARRAY['NOTA_VENTA'::text, 'BOLETA'::text, 'FACTURA'::text])),
    CONSTRAINT document_series_unique UNIQUE (warehouse_id, document_type, series)
);

-- RLS para document_series basado estrictamente en permisos
ALTER TABLE public.document_series ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Series legibles por usuarios autenticados" ON public.document_series;
DROP POLICY IF EXISTS "Series administrables por personal autorizado" ON public.document_series;

CREATE POLICY "Series legibles por personal con acceso"
    ON public.document_series FOR SELECT
    TO authenticated
    USING (
      public.user_has_permission('pos.view') 
      OR public.user_has_permission('pos.sale') 
      OR public.user_has_permission('settings.view')
      OR public.user_has_permission('settings.edit')
    );

CREATE POLICY "Series administrables por personal con permiso de configuración"
    ON public.document_series FOR ALL
    TO authenticated
    USING (
      public.user_has_permission('settings.edit')
    )
    WITH CHECK (
      public.user_has_permission('settings.edit')
    );

-- 4. Insertar series por defecto si no existen
INSERT INTO public.document_series (document_type, series, current_correlative, is_default, is_active)
VALUES 
    ('NOTA_VENTA', 'NV01', 0, true, true),
    ('BOLETA',     'B001', 0, true, true),
    ('FACTURA',    'F001', 0, true, true)
ON CONFLICT DO NOTHING;

-- 5. Función RPC optimizada para procesar venta con comprobante y correlativo atómico
CREATE OR REPLACE FUNCTION "public"."process_pos_sale"("payload" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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

  -- Comprobante y facturación
  v_doc_type text := COALESCE(payload->>'documentType', 'NOTA_VENTA');
  v_doc_series text := payload->>'documentSeries';
  v_doc_number text := payload->>'documentNumber';
  v_tax_amount numeric := COALESCE((payload->>'taxAmount')::numeric, 0.00);
  v_subtotal_amount numeric := COALESCE((payload->>'subtotalAmount')::numeric, (v_total_amount - v_tax_amount));
  v_payment_reference text := payload->>'paymentReference';
  v_customer_doc_type text := payload->>'customerDocumentType';
  v_customer_doc_num text := payload->>'customerDocumentNumber';
  v_customer_address text := payload->>'customerAddress';

  -- Multimoneda
  v_currency_code text := COALESCE(payload->>'currencyCode', 'PEN');
  v_exchange_rate numeric := COALESCE((payload->>'exchangeRate')::numeric, 1.0000);
  v_total_amount_base numeric := COALESCE((payload->>'totalAmountBase')::numeric, (v_total_amount * COALESCE((payload->>'exchangeRate')::numeric, 1.0000)));
  v_subtotal_amount_base numeric := COALESCE((payload->>'subtotalAmountBase')::numeric, (v_subtotal_amount * COALESCE((payload->>'exchangeRate')::numeric, 1.0000)));
  v_tax_amount_base numeric := COALESCE((payload->>'taxAmountBase')::numeric, (v_tax_amount * COALESCE((payload->>'exchangeRate')::numeric, 1.0000)));

  v_series_row record;
  v_next_correlative int;
  
  item jsonb;
  v_variant_id uuid;
  v_quantity int;
  v_remaining_qty int;

  -- Costo y ganancia calculados EN EL SERVIDOR
  v_unit_cost numeric;
  v_applied_price numeric;
  v_total_cost numeric := 0;
  v_total_profit numeric := 0;
  
  batch_assign jsonb;
  batch_row record;
  v_take int;
  v_batch_number text;
  v_old_qty int;
  
  v_credit_id uuid;
  v_current_balance numeric;
  v_current_debt numeric;
  v_credit_limit numeric;
  v_credit_active boolean;
  v_credit_disponible numeric;
BEGIN
  -- 1. BLINDAJE DE SEGURIDAD: Resolver perfil del usuario autenticado
  SELECT id INTO v_created_by FROM profiles WHERE auth_user_id = v_auth_user_id LIMIT 1;
  IF v_created_by IS NULL THEN
    RAISE EXCEPTION 'Usuario autenticado no posee un perfil válido en el sistema.';
  END IF;

  -- 1.1 Verificación de permisos granulares: requiere permiso pos.sale
  IF NOT public.user_has_permission('pos.sale') THEN
    RAISE EXCEPTION 'No cuenta con el permiso requerido para registrar ventas en el POS (pos.sale).' USING ERRCODE = '42501';
  END IF;

  -- Handle optional UUIDs
  IF payload->>'customerId' IS NOT NULL AND payload->>'customerId' != '' THEN v_customer_id := (payload->>'customerId')::uuid; END IF;
  IF payload->>'accountId' IS NOT NULL AND payload->>'accountId' != '' THEN v_account_id := (payload->>'accountId')::uuid; END IF;

  -- VALIDACIÓN ATÓMICA DE CRÉDITO
  IF NOT v_is_draft AND v_is_credit AND v_customer_id IS NOT NULL THEN
    SELECT id, current_debt, credit_limit, is_active 
      INTO v_credit_id, v_current_debt, v_credit_limit, v_credit_active
    FROM customer_credits
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

  -- ASIGNACIÓN ATÓMICA DE SERIE Y CORRELATIVO FISCAL (Si no es borrador y tiene tipo)
  IF NOT v_is_draft AND v_doc_type IS NOT NULL AND v_doc_type != 'NINGUNO' THEN
    -- Si no especificó serie, buscar la serie por defecto para este tipo y almacén
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

  -- Costo real desde product_variants.unit_cost
  FOR item IN SELECT * FROM jsonb_array_elements(payload->'items')
  LOOP
    SELECT unit_cost INTO v_unit_cost
    FROM product_variants
    WHERE id = (item->>'variantId')::uuid;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variante no encontrada: %', item->>'variantId';
    END IF;

    v_total_cost := v_total_cost + COALESCE(v_unit_cost, 0) * (item->>'quantity')::int;
  END LOOP;

  v_total_profit := v_total_amount - v_total_cost;
  v_order_status := CASE WHEN v_is_draft THEN 'PENDING' ELSE 'COMPLETED' END;

  -- 2. INSERTAR ORDEN PRINCIPAL CON COMPROBANTE
  INSERT INTO orders (
    customer_id,
    customer_name,
    warehouse_id,
    total_amount,
    total_profit,
    discount_amount,
    payment_method,
    payment_status,
    amount_paid,
    status,
    points_used,
    points_earned,
    created_by,
    document_type,
    document_series,
    document_number,
    document_date,
    tax_amount,
    subtotal_amount,
    payment_reference,
    customer_document_type,
    customer_document_number,
    customer_address,
    currency_code,
    exchange_rate,
    total_amount_base,
    subtotal_amount_base,
    tax_amount_base
  ) VALUES (
    v_customer_id,
    NULLIF(payload->>'customerName', ''),
    v_warehouse_id,
    v_total_amount,
    v_total_profit,
    COALESCE((payload->>'discountAmount')::numeric, 0.00),
    payload->>'paymentMethod',
    payload->>'paymentStatus',
    v_amount_paid,
    v_order_status,
    CASE WHEN v_is_draft THEN 0 ELSE v_points_used END,
    CASE WHEN v_is_draft THEN 0 ELSE v_points_earned END,
    v_created_by,
    v_doc_type,
    v_doc_series,
    v_doc_number,
    CURRENT_DATE,
    v_tax_amount,
    v_subtotal_amount,
    v_payment_reference,
    v_customer_doc_type,
    v_customer_doc_num,
    v_customer_address,
    v_currency_code,
    v_exchange_rate,
    v_total_amount_base,
    v_subtotal_amount_base,
    v_tax_amount_base
  ) RETURNING id INTO v_order_id;

  -- 3. PROCESAMIENTO ATÓMICO DE ITEMS
  FOR item IN SELECT * FROM jsonb_array_elements(payload->'items')
  LOOP
    v_variant_id := (item->>'variantId')::uuid;
    v_quantity := (item->>'quantity')::int;

    SELECT COALESCE(unit_cost, 0) INTO v_unit_cost
    FROM product_variants WHERE id = v_variant_id;
    v_applied_price := (item->>'appliedPrice')::numeric;

    INSERT INTO order_items (
      order_id, product_id, variant_id, quantity, unit_cost, applied_price, net_profit
    ) VALUES (
      v_order_id, (item->>'productId')::uuid, v_variant_id, v_quantity,
      v_unit_cost, v_applied_price, (v_applied_price - v_unit_cost) * v_quantity
    );

    IF NOT v_is_draft THEN
      v_remaining_qty := v_quantity;
      
      -- Escenario A: Asignación Manual de Lotes desde Flutter
      IF item ? 'batchAssignments' AND jsonb_array_length(item->'batchAssignments') > 0 THEN
        FOR batch_assign IN SELECT * FROM jsonb_array_elements(item->'batchAssignments')
        LOOP
          v_take := (batch_assign->>'take')::int;
          v_batch_number := batch_assign->>'batchNumber';
          
          SELECT available_quantity INTO v_old_qty 
          FROM warehouse_stock_batches 
          WHERE id = (batch_assign->>'batchId')::uuid FOR UPDATE;
          
          IF v_old_qty < v_take THEN
            RAISE EXCEPTION 'Stock insuficiente en el lote manual % para la variante %. Disponible: %, Solicitado: %', 
              v_batch_number, v_variant_id, v_old_qty, v_take;
          END IF;
          
          UPDATE warehouse_stock_batches
          SET available_quantity = available_quantity - v_take
          WHERE id = (batch_assign->>'batchId')::uuid;
          
          INSERT INTO inventory_movements (
            variant_id, warehouse_id, stock_batch_id, order_id, quantity, previous_stock, new_stock, unit_cost, reason, notes, created_by
          ) VALUES (
            v_variant_id, v_warehouse_id, (batch_assign->>'batchId')::uuid, v_order_id, -v_take, v_old_qty, v_old_qty - v_take, v_unit_cost, 'SALE', 
            'Venta POS ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)) || ' • Lote: ' || v_batch_number, v_created_by
          );
        END LOOP;
        
      -- Escenario B: Auto FEFO por Servidor
      ELSE
        FOR batch_row IN 
          SELECT id, available_quantity, batch_number 
          FROM warehouse_stock_batches 
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
          
          UPDATE warehouse_stock_batches
          SET available_quantity = available_quantity - v_take
          WHERE id = batch_row.id;
          
          INSERT INTO inventory_movements (
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

  -- 4. FLUJOS FINANCIEROS Y DE CAJA
  IF NOT v_is_draft THEN
    IF v_account_id IS NOT NULL THEN
      DECLARE
        v_account_type text;
      BEGIN
        SELECT type, balance INTO v_account_type, v_current_balance 
        FROM financial_accounts 
        WHERE id = v_account_id FOR UPDATE;
        
        IF NOT FOUND THEN
          RAISE EXCEPTION 'Cuenta financiera no encontrada.';
        END IF;

        IF v_account_type = 'CAJA' THEN
          SELECT id INTO v_shift_id
          FROM cash_shifts
          WHERE account_id = v_account_id AND status = 'OPEN'
          FOR UPDATE;
          
          IF NOT FOUND THEN
            RAISE EXCEPTION 'No hay un turno de caja abierto para procesar esta venta en efectivo.';
          END IF;
        ELSE
          v_shift_id := NULL;
        END IF;

        INSERT INTO account_movements (
          account_id, shift_id, movement_type, amount, description, reference_id, reference_type, created_by,
          currency_code, exchange_rate, amount_base
        ) VALUES (
          v_account_id, v_shift_id, 'INCOME', v_amount_paid, 
          'Venta POS ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)), 
          v_order_id, 'ORDER', v_created_by,
          v_currency_code, v_exchange_rate, (v_amount_paid * v_exchange_rate)
        );
        
        UPDATE financial_accounts
        SET balance = balance + v_amount_paid
        WHERE id = v_account_id;
      END;
    END IF;

    -- Actualización de puntos
    IF (v_points_earned > 0 OR v_points_used > 0) AND v_customer_id IS NOT NULL THEN
      UPDATE profiles
      SET wallet_balance = wallet_balance + v_points_earned - v_points_used
      WHERE id = v_customer_id;
      
      IF v_points_earned > 0 THEN
        INSERT INTO wallet_movements (profile_id, order_id, points, movement_type, description)
        VALUES (v_customer_id, v_order_id, v_points_earned, 'EARNED', 
          'Puntos ganados por Venta ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)));
      END IF;

      IF v_points_used > 0 THEN
        INSERT INTO wallet_movements (profile_id, order_id, points, movement_type, description)
        VALUES (v_customer_id, v_order_id, v_points_used, 'REDEEMED', 
          'Puntos canjeados en Venta ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)));
      END IF;
    END IF;

    -- Crédito a clientes
    IF v_is_credit AND v_customer_id IS NOT NULL THEN
      UPDATE customer_credits
      SET current_debt = current_debt + (v_total_amount - v_amount_paid)
      WHERE id = v_credit_id;
      
      INSERT INTO customer_credit_movements (
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

GRANT ALL ON FUNCTION "public"."process_pos_sale"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."process_pos_sale"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_pos_sale"("payload" "jsonb") TO "service_role";
