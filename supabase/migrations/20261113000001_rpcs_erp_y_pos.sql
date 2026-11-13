-- ============================================================================
-- MIGRACIÓN 2: RPCs TRANSACCIONALES ERP, POS MIXTO/DECIMAL Y AUDITORÍA
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. CORRECCIÓN DE RECONCILIACIÓN DE SALDOS (ccm.customer_credit_id)
-- ============================================================================

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
        LEFT JOIN public.customer_credit_movements ccm ON ccm.customer_credit_id = cc.id
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
-- 2. POS UPGRADE: CANTIDADES DECIMALES, PAGOS MIXTOS E IMPUESTOS POR LÍNEA
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
  v_quantity numeric;
  v_remaining_qty numeric;

  -- Impuestos por línea
  v_tax_affectation text;
  v_item_discount numeric;
  v_item_tax_rate numeric;
  v_item_tax_amount numeric;
  v_item_unit_val_no_tax numeric;

  -- Costo y ganancia calculados EN EL SERVIDOR
  v_unit_cost numeric;
  v_applied_price numeric;
  v_total_cost numeric := 0;
  v_total_profit numeric := 0;

  batch_assign jsonb;
  batch_row record;
  v_take numeric;
  v_batch_number text;
  v_old_qty numeric;

  -- Pagos mixtos
  pay_item jsonb;
  v_pay_account_id uuid;
  v_pay_amount numeric;
  v_pay_method text;
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
  -- 1. BLINDAJE DE SEGURIDAD
  SELECT id INTO v_created_by FROM public.profiles WHERE auth_user_id = v_auth_user_id LIMIT 1;
  IF v_created_by IS NULL THEN
    RAISE EXCEPTION 'Usuario autenticado no posee un perfil válido en el sistema.';
  END IF;

  IF NOT public.user_has_permission('pos.sale') THEN
    RAISE EXCEPTION 'No cuenta con el permiso requerido para registrar ventas en el POS (pos.sale).' USING ERRCODE = '42501';
  END IF;

  IF payload->>'customerId' IS NOT NULL AND payload->>'customerId' != '' THEN v_customer_id := (payload->>'customerId')::uuid; END IF;
  IF payload->>'accountId' IS NOT NULL AND payload->>'accountId' != '' THEN v_account_id := (payload->>'accountId')::uuid; END IF;

  -- Si vienen pagos mixtos, calcular v_amount_paid total desde el arreglo si no vino explícito
  IF payload ? 'payments' AND jsonb_array_length(payload->'payments') > 0 AND v_amount_paid = 0 THEN
    SELECT COALESCE(SUM((p->>'amount')::numeric), 0)
    INTO v_amount_paid
    FROM jsonb_array_elements(payload->'payments') AS p;
  END IF;

  -- VALIDACIÓN ATÓMICA DE CRÉDITO
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

  -- ASIGNACIÓN ATÓMICA DE SERIE Y CORRELATIVO FISCAL
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

  -- Costo real desde product_variants.unit_cost
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

  -- 2. INSERTAR ORDEN PRINCIPAL
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
    COALESCE(payload->>'paymentStatus', 'PAID'),
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

  -- 3. PROCESAMIENTO ATÓMICO DE ITEMS (Soporta decimales + impuestos por línea)
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

  -- 4. FLUJOS FINANCIEROS Y DE CAJA (Soporta pagos mixtos o pago único)
  IF NOT v_is_draft THEN
    IF payload ? 'payments' AND jsonb_array_length(payload->'payments') > 0 THEN
      FOR pay_item IN SELECT * FROM jsonb_array_elements(payload->'payments')
      LOOP
        v_pay_account_id := NULLIF(pay_item->>'accountId', '')::uuid;
        v_pay_amount := (pay_item->>'amount')::numeric;
        v_pay_method := COALESCE(pay_item->>'paymentMethod', 'EFECTIVO');
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
              'Venta POS (' || v_pay_method || ') ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)),
              v_order_id, 'ORDER', v_created_by,
              v_currency_code, v_exchange_rate, ROUND(v_pay_amount * v_exchange_rate, 2)
            );

            UPDATE public.financial_accounts
            SET balance = balance + v_pay_amount
            WHERE id = v_pay_account_id;
          END IF;

          INSERT INTO public.order_payments (
            order_id, account_id, shift_id, payment_method, amount, currency_code, exchange_rate, amount_base, reference_number, created_by
          ) VALUES (
            v_order_id, v_pay_account_id, v_pay_shift_id, v_pay_method, v_pay_amount,
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
        order_id, account_id, shift_id, payment_method, amount, currency_code, exchange_rate, amount_base, reference_number, created_by
      ) VALUES (
        v_order_id, v_account_id, v_shift_id, COALESCE(payload->>'paymentMethod', 'EFECTIVO'), v_amount_paid,
        v_currency_code, v_exchange_rate, ROUND(v_amount_paid * v_exchange_rate, 2), v_payment_reference, v_created_by
      );
    END IF;

    -- Actualización de puntos
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

    -- Crédito a clientes
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


-- ============================================================================
-- 3. RPC TRANSFERENCIA ATÓMICA ENTRE ALMACENES
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_transfer_warehouse_stock(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_profile_id uuid;
    v_source_wh uuid := (payload->>'sourceWarehouseId')::uuid;
    v_dest_wh uuid := (payload->>'destWarehouseId')::uuid;
    v_notes text := payload->>'notes';
    v_transfer_id uuid;
    v_transfer_number text;
    v_item jsonb;
    v_variant_id uuid;
    v_qty numeric;
    v_remaining numeric;
    v_take numeric;
    v_batch record;
    v_product_id uuid;
    v_unit_cost numeric;
    v_dest_old_qty numeric;
BEGIN
    SELECT id INTO v_profile_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin perfil válido.';
    END IF;
    IF NOT public.user_has_permission('inventory.manage') THEN
        RAISE EXCEPTION 'Sin permiso para transferir inventario (inventory.manage).' USING ERRCODE = '42501';
    END IF;
    IF v_source_wh = v_dest_wh THEN
        RAISE EXCEPTION 'El almacén origen y destino deben ser distintos.';
    END IF;

    v_transfer_number := 'TRF-' || to_char(now(), 'YYYYMMDD-HH24MISS') || '-' || substr(gen_random_uuid()::text, 1, 4);

    INSERT INTO public.warehouse_transfers (
        transfer_number, source_warehouse_id, dest_warehouse_id, status, notes, shipped_at, received_at, created_by, received_by
    ) VALUES (
        v_transfer_number, v_source_wh, v_dest_wh, 'RECEIVED', v_notes, now(), now(), v_profile_id, v_profile_id
    ) RETURNING id INTO v_transfer_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(payload->'items')
    LOOP
        v_variant_id := (v_item->>'variantId')::uuid;
        v_qty := (v_item->>'quantity')::numeric;

        SELECT product_id, COALESCE(unit_cost, 0) INTO v_product_id, v_unit_cost
        FROM public.product_variants WHERE id = v_variant_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Variante no encontrada: %', v_variant_id;
        END IF;

        v_remaining := v_qty;

        FOR v_batch IN
            SELECT id, batch_number, expiry_date, available_quantity, supplier_id
            FROM public.warehouse_stock_batches
            WHERE variant_id = v_variant_id AND warehouse_id = v_source_wh AND available_quantity > 0
            ORDER BY expiry_date ASC NULLS LAST
            FOR UPDATE
        LOOP
            IF v_remaining <= 0 THEN EXIT; END IF;
            v_take := LEAST(v_remaining, v_batch.available_quantity);

            -- Descontar en origen
            UPDATE public.warehouse_stock_batches
            SET available_quantity = available_quantity - v_take, updated_at = now(), updated_by = v_profile_id
            WHERE id = v_batch.id;

            INSERT INTO public.inventory_movements (
                variant_id, warehouse_id, stock_batch_id, quantity, previous_stock, new_stock, unit_cost, reason, notes, created_by
            ) VALUES (
                v_variant_id, v_source_wh, v_batch.id, -v_take, v_batch.available_quantity, v_batch.available_quantity - v_take,
                v_unit_cost, 'TRANSFER_OUT', 'Transferencia ' || v_transfer_number || ' hacia almacén destino', v_profile_id
            );

            -- Sumar en destino (mismo lote)
            SELECT available_quantity INTO v_dest_old_qty
            FROM public.warehouse_stock_batches
            WHERE variant_id = v_variant_id AND warehouse_id = v_dest_wh AND batch_number = v_batch.batch_number
            FOR UPDATE;

            v_dest_old_qty := COALESCE(v_dest_old_qty, 0);

            INSERT INTO public.warehouse_stock_batches (
                variant_id, warehouse_id, product_id, batch_number, expiry_date, available_quantity, supplier_id, created_by, updated_by
            ) VALUES (
                v_variant_id, v_dest_wh, v_product_id, v_batch.batch_number, v_batch.expiry_date, v_take, v_batch.supplier_id, v_profile_id, v_profile_id
            )
            ON CONFLICT (variant_id, warehouse_id, batch_number)
            DO UPDATE SET
                available_quantity = public.warehouse_stock_batches.available_quantity + EXCLUDED.available_quantity,
                updated_at = now(),
                updated_by = v_profile_id;

            INSERT INTO public.inventory_movements (
                variant_id, warehouse_id, quantity, previous_stock, new_stock, unit_cost, reason, notes, created_by
            ) VALUES (
                v_variant_id, v_dest_wh, v_take, v_dest_old_qty, v_dest_old_qty + v_take,
                v_unit_cost, 'TRANSFER_IN', 'Recepción transferencia ' || v_transfer_number || ' • Lote: ' || v_batch.batch_number, v_profile_id
            );

            INSERT INTO public.warehouse_transfer_items (
                transfer_id, variant_id, source_batch_id, quantity_sent, quantity_received, unit_cost
            ) VALUES (
                v_transfer_id, v_variant_id, v_batch.id, v_take, v_take, v_unit_cost
            );

            v_remaining := v_remaining - v_take;
        END LOOP;

        IF v_remaining > 0 THEN
            RAISE EXCEPTION 'Stock insuficiente en almacén origen para variante %', v_variant_id;
        END IF;
    END LOOP;

    RETURN v_transfer_id;
END;
$$;


-- ============================================================================
-- 4. RPC DEVOLUCIÓN / NOTA DE CRÉDITO
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_process_sales_return(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_profile_id uuid;
    v_order_id uuid := (payload->>'orderId')::uuid;
    v_order record;
    v_return_id uuid;
    v_doc_type text := COALESCE(payload->>'documentType', 'NOTA_CREDITO');
    v_doc_series text := payload->>'documentSeries';
    v_doc_number text;
    v_series_row record;
    v_next_corr int;
    v_refund_method text := COALESCE(payload->>'refundMethod', 'CASH');
    v_account_id uuid := NULLIF(payload->>'accountId', '')::uuid;
    v_shift_id uuid := NULL;
    v_acc_type text;
    v_total_refund numeric := 0;
    v_item jsonb;
    v_variant_id uuid;
    v_product_id uuid;
    v_qty numeric;
    v_unit_price numeric;
    v_subtotal numeric;
    v_restock boolean;
    v_old_qty numeric;
BEGIN
    SELECT id INTO v_profile_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin perfil válido.';
    END IF;
    IF NOT (public.user_has_permission('orders.cancel') OR public.user_has_permission('pos.sale')) THEN
        RAISE EXCEPTION 'Sin permiso para procesar devoluciones.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_order FROM public.orders WHERE id = v_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden no encontrada.';
    END IF;

    -- Correlativo si es NOTA_CREDITO
    IF v_doc_type = 'NOTA_CREDITO' THEN
        SELECT * INTO v_series_row
        FROM public.document_series
        WHERE document_type = 'NOTA_CREDITO'
          AND (v_doc_series IS NULL OR series = v_doc_series)
          AND (warehouse_id = v_order.warehouse_id OR warehouse_id IS NULL)
          AND is_active = true
        ORDER BY (warehouse_id IS NOT NULL) DESC, is_default DESC
        LIMIT 1
        FOR UPDATE;

        IF FOUND THEN
            v_next_corr := v_series_row.current_correlative + 1;
            v_doc_series := v_series_row.series;
            v_doc_number := v_series_row.series || '-' || LPAD(v_next_corr::text, v_series_row.correlative_padding, '0');
            UPDATE public.document_series SET current_correlative = v_next_corr, updated_at = now() WHERE id = v_series_row.id;
        END IF;
    END IF;

    INSERT INTO public.sales_returns (
        order_id, warehouse_id, document_type, document_series, document_number,
        reason_code, reason_description, refund_method, account_id, total_refund_amount, status, created_by
    ) VALUES (
        v_order_id, v_order.warehouse_id, v_doc_type, v_doc_series, v_doc_number,
        COALESCE(payload->>'reasonCode', '01'),
        COALESCE(payload->>'reasonDescription', 'Devolución de mercadería'),
        v_refund_method, v_account_id, 0, 'COMPLETED', v_profile_id
    ) RETURNING id INTO v_return_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(payload->'items')
    LOOP
        v_variant_id := (v_item->>'variantId')::uuid;
        v_qty := (v_item->>'quantity')::numeric;
        v_unit_price := (v_item->>'unitPrice')::numeric;
        v_subtotal := ROUND(v_qty * v_unit_price, 2);
        v_restock := COALESCE((v_item->>'restock')::boolean, true);

        INSERT INTO public.sales_return_items (
            sales_return_id, order_item_id, variant_id, quantity, unit_price, refund_subtotal, restock
        ) VALUES (
            v_return_id, NULLIF(v_item->>'orderItemId', '')::uuid, v_variant_id, v_qty, v_unit_price, v_subtotal, v_restock
        );

        IF v_restock THEN
            SELECT product_id INTO v_product_id FROM public.product_variants WHERE id = v_variant_id;
            SELECT available_quantity INTO v_old_qty
            FROM public.warehouse_stock_batches
            WHERE variant_id = v_variant_id AND warehouse_id = v_order.warehouse_id AND batch_number = 'DEFAULT'
            FOR UPDATE;
            v_old_qty := COALESCE(v_old_qty, 0);

            INSERT INTO public.warehouse_stock_batches (
                variant_id, warehouse_id, product_id, batch_number, available_quantity, created_by, updated_by
            ) VALUES (
                v_variant_id, v_order.warehouse_id, v_product_id, 'DEFAULT', v_qty, v_profile_id, v_profile_id
            )
            ON CONFLICT (variant_id, warehouse_id, batch_number)
            DO UPDATE SET
                available_quantity = public.warehouse_stock_batches.available_quantity + EXCLUDED.available_quantity,
                updated_at = now(), updated_by = v_profile_id;

            INSERT INTO public.inventory_movements (
                variant_id, warehouse_id, order_id, quantity, previous_stock, new_stock, reason, notes, created_by
            ) VALUES (
                v_variant_id, v_order.warehouse_id, v_order_id, v_qty, v_old_qty, v_old_qty + v_qty,
                'RETURN', 'Devolución ' || COALESCE(v_doc_number, v_return_id::text), v_profile_id
            );
        END IF;

        v_total_refund := v_total_refund + v_subtotal;
    END LOOP;

    UPDATE public.sales_returns SET total_refund_amount = v_total_refund WHERE id = v_return_id;

    -- Reembolso financiero
    IF v_total_refund > 0 AND v_refund_method IN ('CASH', 'ACCOUNT_TRANSFER') AND v_account_id IS NOT NULL THEN
        SELECT type INTO v_acc_type FROM public.financial_accounts WHERE id = v_account_id FOR UPDATE;
        IF v_acc_type = 'CAJA' THEN
            SELECT id INTO v_shift_id FROM public.cash_shifts WHERE account_id = v_account_id AND status = 'OPEN' FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'No hay turno de caja abierto para efectuar el reembolso en efectivo.';
            END IF;
        END IF;

        UPDATE public.sales_returns SET shift_id = v_shift_id WHERE id = v_return_id;

        INSERT INTO public.account_movements (
            account_id, shift_id, movement_type, amount, description, reference_type, reference_id, created_by
        ) VALUES (
            v_account_id, v_shift_id, 'EXPENSE', v_total_refund,
            'Reembolso devolución ' || COALESCE(v_doc_number, '#' || substring(v_return_id::text, 1, 8)),
            'sales_returns', v_return_id, v_profile_id
        );

        UPDATE public.financial_accounts SET balance = balance - v_total_refund WHERE id = v_account_id;
    END IF;

    RETURN v_return_id;
END;
$$;


-- ============================================================================
-- 5. RPC GASTO OPERATIVO Y CONVERSIÓN DE COTIZACIÓN
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_record_expense(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_profile_id uuid;
    v_account_id uuid := (payload->>'accountId')::uuid;
    v_amount numeric := (payload->>'amount')::numeric;
    v_currency text := COALESCE(payload->>'currencyCode', 'PEN');
    v_rate numeric := COALESCE((payload->>'exchangeRate')::numeric, 1.0000);
    v_acc_type text;
    v_shift_id uuid := NULL;
    v_expense_id uuid;
BEGIN
    SELECT id INTO v_profile_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin perfil válido.';
    END IF;
    IF NOT public.user_has_permission('finance.manage') THEN
        RAISE EXCEPTION 'Sin permiso para registrar gastos (finance.manage).' USING ERRCODE = '42501';
    END IF;

    SELECT type INTO v_acc_type FROM public.financial_accounts WHERE id = v_account_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuenta financiera no encontrada.';
    END IF;

    IF v_acc_type = 'CAJA' THEN
        SELECT id INTO v_shift_id FROM public.cash_shifts WHERE account_id = v_account_id AND status = 'OPEN' FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'No hay turno de caja abierto para registrar gasto en efectivo.';
        END IF;
    END IF;

    INSERT INTO public.expenses (
        category_id, warehouse_id, supplier_id, account_id, shift_id,
        description, document_type, document_number, expense_date,
        currency_code, exchange_rate, amount, amount_base, created_by
    ) VALUES (
        NULLIF(payload->>'categoryId', '')::uuid,
        NULLIF(payload->>'warehouseId', '')::uuid,
        NULLIF(payload->>'supplierId', '')::uuid,
        v_account_id, v_shift_id,
        payload->>'description',
        payload->>'documentType',
        payload->>'documentNumber',
        COALESCE((payload->>'expenseDate')::date, CURRENT_DATE),
        v_currency, v_rate, v_amount, ROUND(v_amount * v_rate, 2), v_profile_id
    ) RETURNING id INTO v_expense_id;

    INSERT INTO public.account_movements (
        account_id, shift_id, movement_type, amount, description, reference_type, reference_id, created_by,
        currency_code, exchange_rate, amount_base
    ) VALUES (
        v_account_id, v_shift_id, 'EXPENSE', v_amount,
        'Gasto: ' || (payload->>'description'),
        'expenses', v_expense_id, v_profile_id,
        v_currency, v_rate, ROUND(v_amount * v_rate, 2)
    );

    UPDATE public.financial_accounts SET balance = balance - v_amount WHERE id = v_account_id;

    RETURN v_expense_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_convert_quotation_to_order(p_quotation_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_profile_id uuid;
    v_q record;
    v_order_id uuid;
BEGIN
    SELECT id INTO v_profile_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin perfil válido.';
    END IF;

    SELECT * INTO v_q FROM public.quotations WHERE id = p_quotation_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cotización no encontrada.';
    END IF;
    IF v_q.status = 'CONVERTED' THEN
        RETURN v_q.converted_order_id;
    END IF;

    INSERT INTO public.orders (
        customer_id, customer_name, customer_document_number, warehouse_id,
        total_amount, subtotal_amount, tax_amount, discount_amount,
        currency_code, exchange_rate, status, payment_status, created_by
    ) VALUES (
        v_q.customer_id, v_q.customer_name, v_q.customer_document_number, v_q.warehouse_id,
        v_q.total_amount, v_q.subtotal_amount, v_q.tax_amount, v_q.discount_amount,
        v_q.currency_code, v_q.exchange_rate, 'PENDING', 'PENDING', v_profile_id
    ) RETURNING id INTO v_order_id;

    INSERT INTO public.order_items (
        order_id, product_id, variant_id, quantity, unit_cost, applied_price, net_profit,
        tax_affectation_type, discount_amount, tax_amount
    )
    SELECT
        v_order_id, pv.product_id, qi.variant_id, qi.quantity, pv.unit_cost, qi.unit_price,
        (qi.unit_price - pv.unit_cost) * qi.quantity,
        qi.tax_affectation_type, qi.discount_amount, qi.tax_amount
    FROM public.quotation_items qi
    JOIN public.product_variants pv ON pv.id = qi.variant_id
    WHERE qi.quotation_id = p_quotation_id;

    UPDATE public.quotations
    SET status = 'CONVERTED', converted_order_id = v_order_id, updated_by = v_profile_id, updated_at = now()
    WHERE id = p_quotation_id;

    INSERT INTO public.order_status_history (order_id, previous_status, new_status, notes, changed_by)
    VALUES (v_order_id, NULL, 'PENDING', 'Convertida desde cotización ' || COALESCE(v_q.quotation_number, p_quotation_id::text), v_profile_id);

    RETURN v_order_id;
END;
$$;


-- ============================================================================
-- 6. TRIGGERS DE AUDITORÍA Y HISTORIAL DE ESTADOS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_audit_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_record_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_record_id := OLD.id;
        INSERT INTO public.audit_logs (table_name, record_id, action, old_data, changed_by)
        VALUES (TG_TABLE_NAME, v_record_id, TG_OP, to_jsonb(OLD), auth.uid());
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        v_record_id := NEW.id;
        INSERT INTO public.audit_logs (table_name, record_id, action, old_data, new_data, changed_by)
        VALUES (TG_TABLE_NAME, v_record_id, TG_OP, to_jsonb(OLD), to_jsonb(NEW), auth.uid());
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        v_record_id := NEW.id;
        INSERT INTO public.audit_logs (table_name, record_id, action, new_data, changed_by)
        VALUES (TG_TABLE_NAME, v_record_id, TG_OP, to_jsonb(NEW), auth.uid());
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_track_order_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO public.order_status_history (order_id, previous_status, new_status, changed_by)
        VALUES (NEW.id, OLD.status, NEW.status, COALESCE(NEW.updated_by, NEW.created_by));
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_status_history ON public.orders;
CREATE TRIGGER trg_orders_status_history
    AFTER UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.trg_track_order_status();

DROP TRIGGER IF EXISTS trg_audit_orders ON public.orders;
CREATE TRIGGER trg_audit_orders
    AFTER INSERT OR UPDATE OR DELETE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.trg_audit_log();

DROP TRIGGER IF EXISTS trg_audit_financial_accounts ON public.financial_accounts;
CREATE TRIGGER trg_audit_financial_accounts
    AFTER UPDATE OR DELETE ON public.financial_accounts
    FOR EACH ROW EXECUTE FUNCTION public.trg_audit_log();

DROP TRIGGER IF EXISTS trg_audit_sales_returns ON public.sales_returns;
CREATE TRIGGER trg_audit_sales_returns
    AFTER INSERT OR UPDATE OR DELETE ON public.sales_returns
    FOR EACH ROW EXECUTE FUNCTION public.trg_audit_log();

DROP TRIGGER IF EXISTS trg_audit_expenses ON public.expenses;
CREATE TRIGGER trg_audit_expenses
    AFTER INSERT OR UPDATE OR DELETE ON public.expenses
    FOR EACH ROW EXECUTE FUNCTION public.trg_audit_log();

-- Permisos de ejecución para nuevos RPCs
GRANT EXECUTE ON FUNCTION public.reconcile_balances_report() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_transfer_warehouse_stock(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_process_sales_return(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_record_expense(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_convert_quotation_to_order(uuid) TO authenticated, service_role;

COMMIT;

