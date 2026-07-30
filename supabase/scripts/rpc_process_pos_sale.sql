CREATE OR REPLACE FUNCTION process_pos_sale(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER -- Ejecuta con privilegios del sistema para bypass de RLS controlado
SET search_path = public, auth -- Hardening de seguridad para evitar ataques de Search Path Injection
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
  
  item jsonb;
  v_variant_id uuid;
  v_quantity int;
  v_remaining_qty int;
  
  batch_assign jsonb;
  batch_row record;
  v_take int;
  v_batch_number text;
  v_old_qty int;
  
  v_credit_id uuid;
  v_current_balance numeric;
  v_current_debt numeric;
  v_credit_limit numeric;
BEGIN
  -- 1. BLINDAJE DE SEGURIDAD: Resolver creador únicamente vía JWT de Supabase Auth
  SELECT id INTO v_created_by FROM profiles WHERE auth_user_id = v_auth_user_id LIMIT 1;
  IF v_created_by IS NULL THEN
    RAISE EXCEPTION 'Usuario autenticado no posee un perfil válido en el sistema.';
  END IF;

  -- Handle optional UUIDs
  IF payload->>'customerId' IS NOT NULL THEN v_customer_id := (payload->>'customerId')::uuid; END IF;
  IF payload->>'accountId' IS NOT NULL THEN v_account_id := (payload->>'accountId')::uuid; END IF;
  IF payload->>'activeShiftId' IS NOT NULL THEN v_shift_id := (payload->>'activeShiftId')::uuid; END IF;

  v_order_status := CASE WHEN v_is_draft THEN 'PENDING' ELSE 'COMPLETED' END;

  -- Insert order centralizada
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
    created_by
  ) VALUES (
    v_customer_id,
    NULLIF(payload->>'customerName', ''),
    v_warehouse_id,
    v_total_amount,
    COALESCE((payload->>'totalProfit')::numeric, 0.00),
    COALESCE((payload->>'discountAmount')::numeric, 0.00),
    payload->>'paymentMethod',
    payload->>'paymentStatus',
    v_amount_paid,
    v_order_status,
    CASE WHEN v_is_draft THEN 0 ELSE v_points_used END,
    CASE WHEN v_is_draft THEN 0 ELSE v_points_earned END,
    v_created_by
  ) RETURNING id INTO v_order_id;

  -- 2. PROCESAMIENTO ATÓMICO DE ITEMS
  FOR item IN SELECT * FROM jsonb_array_elements(payload->'items')
  LOOP
    v_variant_id := (item->>'variantId')::uuid;
    v_quantity := (item->>'quantity')::int;
    
    INSERT INTO order_items (
      order_id, product_id, variant_id, quantity, unit_cost, unit_price, subtotal, net_profit
    ) VALUES (
      v_order_id, (item->>'productId')::uuid, v_variant_id, v_quantity,
      (item->>'unitCost')::numeric, (item->>'appliedPrice')::numeric, (item->>'subtotal')::numeric, (item->>'netProfit')::numeric
    );

    IF NOT v_is_draft THEN
      v_remaining_qty := v_quantity;
      
      -- Escenario A: Asignación Manual de Lotes desde Flutter
      IF item ? 'batchAssignments' AND jsonb_array_length(item->'batchAssignments') > 0 THEN
        FOR batch_assign IN SELECT * FROM jsonb_array_elements(item->'batchAssignments')
        LOOP
          v_take := (batch_assign->>'take')::int;
          v_batch_number := batch_assign->>'batchNumber';
          
          -- Bloqueo pesimista del lote específico para evitar sobreventa concurrente
          SELECT available_quantity INTO v_old_qty 
          FROM warehouse_stock_batches 
          WHERE id = (batch_assign->>'batchId')::uuid FOR UPDATE;
          
          -- Validación crítica de quiebre de stock en asignación manual
          IF v_old_qty < v_take THEN
            RAISE EXCEPTION 'Stock insuficiente en el lote manual % para la variante %. Disponible: %, Solicitado: %', 
              v_batch_number, v_variant_id, v_old_qty, v_take;
          END IF;
          
          UPDATE warehouse_stock_batches
          SET available_quantity = available_quantity - v_take
          WHERE id = (batch_assign->>'batchId')::uuid;
          
          INSERT INTO inventory_movements (
            variant_id, warehouse_id, stock_batch_id, quantity, previous_stock, new_stock, unit_cost, reason, notes, created_by
          ) VALUES (
            v_variant_id, v_warehouse_id, (batch_assign->>'batchId')::uuid, -v_take, v_old_qty, v_old_qty - v_take, (item->>'unitCost')::numeric, 'SALE', 
            'Venta POS - ' || COALESCE(payload->>'paymentMethod', 'N/A') || ' • Lote: ' || v_batch_number, v_created_by
          );
        END LOOP;
        
      -- Escenario B: Auto FEFO por Servidor
      ELSE
        FOR batch_row IN 
          SELECT id, available_quantity, batch_number 
          FROM warehouse_stock_batches 
          WHERE variant_id = v_variant_id AND warehouse_id = v_warehouse_id AND available_quantity > 0 
          ORDER BY expiry_date ASC NULLS LAST
          FOR UPDATE -- Bloquea la fila del lote secuencialmente
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
            variant_id, warehouse_id, stock_batch_id, quantity, previous_stock, new_stock, unit_cost, reason, notes, created_by
          ) VALUES (
            v_variant_id, v_warehouse_id, batch_row.id, -v_take, batch_row.available_quantity, batch_row.available_quantity - v_take, (item->>'unitCost')::numeric, 'SALE', 
            'Venta POS - ' || COALESCE(payload->>'paymentMethod', 'N/A') || ' • Lote: ' || batch_row.batch_number, v_created_by
          );
          
          v_remaining_qty := v_remaining_qty - v_take;
        END LOOP;
        
        -- Si termina el algoritmo FEFO y falta stock, cancela la transacción entera (ROLLBACK)
        IF v_remaining_qty > 0 THEN
          RAISE EXCEPTION 'Stock insuficiente global en almacén para el ítem variante %', v_variant_id;
        END IF;
      END IF;
    END IF;
  END LOOP;

  -- 3. FLUJOS FINANCIEROS Y DE FIDELIZACIÓN COMPLEMENTARIOS
  IF NOT v_is_draft THEN
    
    -- Control de Cajas y Cuentas Financieras (Anti-Race Conditions)
    IF v_account_id IS NOT NULL AND v_shift_id IS NOT NULL THEN
      -- Bloqueo preventivo de la cuenta de dinero para evitar descuadres concurrentes
      SELECT balance INTO v_current_balance 
      FROM financial_accounts 
      WHERE id = v_account_id FOR UPDATE;

      INSERT INTO account_movements (
        account_id, shift_id, movement_type, amount, reason, reference_id, reference_type, notes, created_by
      ) VALUES (
        v_account_id, v_shift_id, 'INCOME', v_amount_paid, 'SALE', v_order_id, 'ORDER', 'Venta POS #' || substring(v_order_id::text, 1, 8), v_created_by
      );
      
      UPDATE financial_accounts
      SET balance = balance + v_amount_paid
      WHERE id = v_account_id;
    END IF;

    -- Actualización Segura del Wallet de Puntos del Cliente
    IF (v_points_earned > 0 OR v_points_used > 0) AND v_customer_id IS NOT NULL THEN
      UPDATE profiles
      SET wallet_balance = wallet_balance + v_points_earned - v_points_used
      WHERE id = v_customer_id;
      
      INSERT INTO wallet_movements (
        profile_id, amount, movement_type, description, reference_id, reference_type, created_by
      ) VALUES (
        v_customer_id, v_points_earned - v_points_used, 
        CASE WHEN (v_points_earned - v_points_used) >= 0 THEN 'EARNED' ELSE 'REDEEMED' END,
        'Puntos por Venta #' || substring(v_order_id::text, 1, 8), v_order_id, 'ORDER', v_created_by
      );
    END IF;

    -- Flujo de Crédito a Clientes Blindado con Bloqueo de Fila
    IF v_is_credit AND v_customer_id IS NOT NULL THEN
      SELECT id, current_debt, credit_limit INTO v_credit_id, v_current_debt, v_credit_limit
      FROM customer_credits
      WHERE profile_id = v_customer_id
      ORDER BY created_at DESC LIMIT 1
      FOR UPDATE; -- Serializa las solicitudes de crédito del mismo cliente
      
      IF v_credit_id IS NOT NULL THEN
        IF (v_current_debt + v_total_amount) > v_credit_limit THEN
          RAISE EXCEPTION 'Límite de crédito excedido. Disponible: %', (v_credit_limit - v_current_debt);
        END IF;

        UPDATE customer_credits
        SET current_debt = current_debt + v_total_amount
        WHERE id = v_credit_id;
        
        INSERT INTO customer_credit_movements (
          credit_id, amount, movement_type, description, reference_id, created_by
        ) VALUES (
          v_credit_id, v_total_amount, 'CHARGE', 'Crédito Venta POS #' || substring(v_order_id::text, 1, 8), v_order_id, v_created_by
        );
      ELSE
        RAISE EXCEPTION 'El cliente no cuenta con una línea de crédito activa configurada.';
      END IF;
    END IF;
  END IF;

  RETURN v_order_id;
END;
$$;
