-- ============================================================================
-- MIGRACIÓN 11: SOPORTE COMPLETO DE customers SIN profile_id EN POS Y CRÉDITOS
-- Proyecto: inventory_store_app (PostgreSQL / Supabase)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ACTUALIZAR process_pos_sale PARA CLIENTES CON O SIN CUENTA EN profiles
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

  v_raw_customer_id uuid;
  v_customer_record_id uuid;
  v_customer_profile_id uuid;

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

  -- Resolver customer_record_id (customers.id) y profile_id opcional
  IF payload->>'customerId' IS NOT NULL AND payload->>'customerId' != '' THEN
    v_raw_customer_id := (payload->>'customerId')::uuid;
    SELECT id, profile_id INTO v_customer_record_id, v_customer_profile_id
    FROM public.customers
    WHERE id = v_raw_customer_id OR profile_id = v_raw_customer_id
    LIMIT 1;

    IF v_customer_record_id IS NULL THEN
      -- Fallback si solo existiera en profiles
      SELECT id INTO v_customer_profile_id FROM public.profiles WHERE id = v_raw_customer_id LIMIT 1;
    END IF;
  END IF;

  IF payload->>'accountId' IS NOT NULL AND payload->>'accountId' != '' THEN v_account_id := (payload->>'accountId')::uuid; END IF;

  IF payload ? 'payments' AND jsonb_array_length(payload->'payments') > 0 AND v_amount_paid = 0 THEN
    SELECT COALESCE(SUM((p->>'amount')::numeric), 0)
    INTO v_amount_paid
    FROM jsonb_array_elements(payload->'payments') AS p;
  END IF;

  IF NOT v_is_draft AND v_is_credit AND (v_customer_record_id IS NOT NULL OR v_customer_profile_id IS NOT NULL) THEN
    SELECT id, current_debt, credit_limit, is_active
      INTO v_credit_id, v_current_debt, v_credit_limit, v_credit_active
    FROM public.customer_credits
    WHERE (v_customer_record_id IS NOT NULL AND customer_record_id = v_customer_record_id)
       OR (v_customer_profile_id IS NOT NULL AND profile_id = v_customer_profile_id)
    LIMIT 1
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
    customer_id, customer_record_id, customer_name, warehouse_id, total_amount, total_profit, discount_amount,
    payment_method, payment_status, amount_paid, status, points_used, points_earned, created_by,
    document_type, document_series, document_number, document_date,
    tax_amount, subtotal_amount, payment_reference,
    customer_document_type, customer_document_number, customer_address,
    currency_code, exchange_rate, total_amount_base, subtotal_amount_base, tax_amount_base
  ) VALUES (
    v_customer_profile_id, v_customer_record_id, NULLIF(payload->>'customerName', ''), v_warehouse_id, v_total_amount, v_total_profit,
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

    -- Actualización de puntos (en customers y en profiles si está vinculado)
    IF (v_points_earned > 0 OR v_points_used > 0) AND (v_customer_record_id IS NOT NULL OR v_customer_profile_id IS NOT NULL) THEN
      IF v_customer_record_id IS NOT NULL THEN
        UPDATE public.customers
        SET wallet_balance = GREATEST(wallet_balance + v_points_earned - v_points_used, 0)
        WHERE id = v_customer_record_id;
      END IF;

      IF v_customer_profile_id IS NOT NULL THEN
        UPDATE public.profiles
        SET wallet_balance = GREATEST(wallet_balance + v_points_earned - v_points_used, 0)
        WHERE id = v_customer_profile_id;
      END IF;

      IF v_points_earned > 0 THEN
        INSERT INTO public.wallet_movements (profile_id, customer_id, order_id, points, movement_type, description)
        VALUES (v_customer_profile_id, v_customer_record_id, v_order_id, v_points_earned, 'EARNED',
          'Puntos ganados por Venta ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)));
      END IF;

      IF v_points_used > 0 THEN
        INSERT INTO public.wallet_movements (profile_id, customer_id, order_id, points, movement_type, description)
        VALUES (v_customer_profile_id, v_customer_record_id, v_order_id, v_points_used, 'REDEEMED',
          'Puntos canjeados en Venta ' || COALESCE(v_doc_number, '#' || substring(v_order_id::text, 1, 8)));
      END IF;
    END IF;

    -- Crédito a clientes
    IF v_is_credit AND v_credit_id IS NOT NULL AND (v_total_amount - v_amount_paid) > 0 THEN
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
-- 2. ACTUALIZAR register_credit_payment_rpc PARA CLIENTES CON O SIN profile_id
-- ============================================================================

CREATE OR REPLACE FUNCTION public.register_credit_payment_rpc(
    p_customer_id uuid,
    p_credit_id uuid,
    p_amount numeric,
    p_account_id uuid,
    p_order_id uuid DEFAULT NULL,
    p_notes text DEFAULT 'Abono registrado a crédito',
    p_shift_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_remaining        NUMERIC := p_amount;
    v_order            RECORD;
    v_pending_of_order NUMERIC;
    v_to_apply         NUMERIC;
    v_new_paid         NUMERIC;
    v_new_status       TEXT;
    v_points_earned    INT;
    v_account          RECORD;
    v_shift_status     TEXT;
    v_current_debt     NUMERIC;
    v_new_debt         NUMERIC;
    v_now              TIMESTAMPTZ;
    v_created_by       UUID;
    v_customer_record_id UUID;
    v_customer_profile_id UUID;
BEGIN
    v_now := NOW() AT TIME ZONE 'America/Lima';

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser mayor a 0.';
    END IF;

    SELECT id INTO v_created_by
      FROM public.profiles
     WHERE auth_user_id = auth.uid() OR id = auth.uid()
     LIMIT 1;

    -- Resolver cliente (p_customer_id puede llegar como customers.id o profiles.id)
    SELECT id, profile_id INTO v_customer_record_id, v_customer_profile_id
      FROM public.customers
     WHERE id = p_customer_id OR profile_id = p_customer_id
     LIMIT 1;

    IF v_customer_record_id IS NULL THEN
        v_customer_profile_id := p_customer_id;
    END IF;

    SELECT type, name INTO v_account
      FROM public.financial_accounts
     WHERE id = p_account_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuenta financiera no encontrada.';
    END IF;

    IF v_account.type = 'CAJA' THEN
        IF p_shift_id IS NULL THEN
            RAISE EXCEPTION 'El pago es por Caja pero no se proporcionó un turno de caja (shift_id).';
        END IF;

        SELECT status INTO v_shift_status
        FROM public.cash_shifts
        WHERE id = p_shift_id;

        IF NOT FOUND OR v_shift_status != 'OPEN' THEN
            RAISE EXCEPTION 'El turno de caja está cerrado o no existe. No se puede recibir el pago.';
        END IF;
    END IF;

    FOR v_order IN
        SELECT id, total_amount, amount_paid, payment_status
          FROM public.orders
         WHERE (
                (v_customer_record_id IS NOT NULL AND customer_record_id = v_customer_record_id)
                OR (v_customer_profile_id IS NOT NULL AND customer_id = v_customer_profile_id)
               )
           AND (p_order_id IS NULL OR id = p_order_id)
           AND payment_status IN ('PENDING', 'PARTIAL')
           AND status = 'COMPLETED'
         ORDER BY created_at ASC
         FOR UPDATE
    LOOP
        EXIT WHEN v_remaining <= 0;

        v_pending_of_order := GREATEST(0, (v_order.total_amount - v_order.amount_paid));
        v_to_apply         := LEAST(v_remaining, v_pending_of_order);
        v_new_paid         := v_order.amount_paid + v_to_apply;
        v_remaining        := v_remaining - v_to_apply;

        IF v_new_paid >= v_order.total_amount THEN
            v_new_status    := 'PAID';
            v_points_earned := FLOOR(v_order.total_amount * 0.03 / 0.01);
        ELSE
            v_new_status    := 'PARTIAL';
            v_points_earned := 0;
        END IF;

        UPDATE public.orders
           SET amount_paid   = v_new_paid,
               payment_status = v_new_status,
               points_earned  = CASE WHEN v_points_earned > 0 THEN v_points_earned ELSE points_earned END,
               updated_at    = v_now
         WHERE id = v_order.id;

        IF v_to_apply > 0 AND p_credit_id IS NOT NULL THEN
            INSERT INTO public.customer_credit_movements (
                customer_credit_id, order_id, movement_type, amount, payment_method, notes, created_by, created_at
            ) VALUES (
                p_credit_id, v_order.id, 'PAYMENT', v_to_apply, v_account.name, p_notes, v_created_by, v_now
            );
        END IF;

        IF v_to_apply > 0 THEN
            INSERT INTO public.account_movements (
                account_id, movement_type, amount, description, reference_type, reference_id, shift_id, created_by, created_at
            ) VALUES (
                p_account_id, 'INCOME', v_to_apply,
                'Cobro de crédito — Pedido #' || UPPER(SUBSTRING(v_order.id::text, 1, 8)),
                'orders', v_order.id, p_shift_id, v_created_by, v_now
            );

            UPDATE public.financial_accounts
               SET balance = balance + v_to_apply
             WHERE id = p_account_id;
        END IF;

        IF v_points_earned > 0 THEN
            IF v_customer_record_id IS NOT NULL THEN
                UPDATE public.customers
                   SET wallet_balance = wallet_balance + v_points_earned
                 WHERE id = v_customer_record_id;
            END IF;

            IF v_customer_profile_id IS NOT NULL THEN
                UPDATE public.profiles
                   SET wallet_balance = COALESCE(wallet_balance, 0) + v_points_earned
                 WHERE id = v_customer_profile_id;
            END IF;

            INSERT INTO public.wallet_movements (
                profile_id, customer_id, order_id, points, movement_type, description, created_at
            ) VALUES (
                v_customer_profile_id, v_customer_record_id, v_order.id, v_points_earned,
                'EARNED', 'Monedas ganadas al saldar pedido a crédito', v_now
            );
        END IF;
    END LOOP;

    IF v_remaining > 0 THEN
        INSERT INTO public.account_movements (
            account_id, movement_type, amount, description, reference_type, reference_id, shift_id, created_by, created_at
        ) VALUES (
            p_account_id, 'INCOME', v_remaining,
            COALESCE(p_notes, 'Abono registrado a cuenta de crédito'),
            'customer_credits', p_credit_id, p_shift_id, v_created_by, v_now
        );

        UPDATE public.financial_accounts
           SET balance = balance + v_remaining
         WHERE id = p_account_id;

        IF p_credit_id IS NOT NULL THEN
            INSERT INTO public.customer_credit_movements (
                customer_credit_id, order_id, movement_type, amount, payment_method, notes, created_by, created_at
            ) VALUES (
                p_credit_id, NULL, 'PAYMENT', v_remaining, v_account.name, p_notes, v_created_by, v_now
            );
        END IF;
    END IF;

    IF p_credit_id IS NOT NULL THEN
        SELECT current_debt INTO v_current_debt
          FROM public.customer_credits
         WHERE id = p_credit_id
         FOR UPDATE;

        IF v_current_debt IS NOT NULL THEN
            IF p_amount > v_current_debt THEN
               RAISE EXCEPTION 'El monto (S/%) sobrepasa la deuda pendiente (S/%)', p_amount, v_current_debt;
            END IF;
            v_new_debt := GREATEST(0, v_current_debt - p_amount);

            UPDATE public.customer_credits
               SET current_debt = v_new_debt,
                   updated_at   = v_now
             WHERE id = p_credit_id;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'amount_paid', p_amount
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'detail', SQLSTATE
        );
END;
$$;

COMMIT;

