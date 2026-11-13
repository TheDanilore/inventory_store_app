


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "unaccent" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."user_role" AS ENUM (
    'customer',
    'admin',
    'employee',
    'cashier',
    'warehouse_keeper'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."award_mini_game_points"("p_profile_id" "uuid", "p_movement_type" "text", "p_points" integer, "p_description" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_safe_points INT;
  v_game_id TEXT;
  v_limit_key TEXT;
  v_daily_limit INT;
  v_plays_today INT;
  v_max_possible_points INT;
BEGIN
  -- 1. Extraer el identificador del juego (ej: 'MINI_GAME_BOXES' -> 'boxes')
  v_game_id := LOWER(REPLACE(p_movement_type, 'MINI_GAME_', ''));
  
  -- Ajustar mapeos específicos según los nombres en AppConfigCubit
  IF v_game_id = 'memory' THEN v_game_id := 'memorama'; END IF;
  
  v_limit_key := v_game_id || '_daily_limit';

  -- 2. Obtener el límite diario desde la tabla app_settings (por defecto 1 si no existe)
  SELECT COALESCE((SELECT value::numeric::int FROM app_settings WHERE key = v_limit_key), 1)
  INTO v_daily_limit;

  -- 3. Contar cuántas veces ha jugado hoy este juego
  SELECT COUNT(*) INTO v_plays_today
  FROM wallet_movements
  WHERE profile_id = p_profile_id
    AND movement_type = p_movement_type
    AND DATE(created_at AT TIME ZONE 'UTC') = DATE(NOW() AT TIME ZONE 'UTC');

  -- 4. Validar el límite diario de forma 100% segura en el servidor
  IF v_plays_today >= v_daily_limit THEN
    RAISE EXCEPTION 'Límite diario superado para el juego %', p_movement_type;
  END IF;

  -- 5. Calcular el máximo de puntos permitidos dinámicamente
  -- Para evitar una condicional masiva, buscamos el premio mayor global configurado
  -- y lo multiplicamos por 10 (margen seguro para juegos acumulativos como memorama o catcher).
  SELECT COALESCE(MAX(value::numeric::int), 50) * 10
  INTO v_max_possible_points
  FROM app_settings
  WHERE key LIKE '%_prize%' OR key LIKE '%_reward%';

  IF p_points > v_max_possible_points THEN
    v_safe_points := v_max_possible_points;
  ELSE
    v_safe_points := p_points;
  END IF;

  -- 6. Insertar el movimiento en el historial
  INSERT INTO wallet_movements (
    profile_id,
    movement_type,
    points,
    description,
    created_at
  ) VALUES (
    p_profile_id,
    p_movement_type,
    v_safe_points,
    p_description,
    NOW()
  );

  -- 7. Actualizar el saldo del perfil atómicamente
  UPDATE profiles
  SET wallet_balance = wallet_balance + v_safe_points
  WHERE id = p_profile_id;
  
END;
$$;


ALTER FUNCTION "public"."award_mini_game_points"("p_profile_id" "uuid", "p_movement_type" "text", "p_points" integer, "p_description" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calc_expected_shift_rpc"("p_shift_id" "uuid", "p_account_id" "uuid") RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_income  numeric := 0;
  v_expense numeric := 0;
BEGIN
  SELECT
    COALESCE(SUM(CASE WHEN movement_type = 'INCOME'  THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN movement_type = 'EXPENSE' THEN amount ELSE 0 END), 0)
  INTO v_income, v_expense
  FROM public.account_movements
  WHERE shift_id   = p_shift_id
    AND account_id = p_account_id;

  RETURN v_income - v_expense;
END;
$$;


ALTER FUNCTION "public"."calc_expected_shift_rpc"("p_shift_id" "uuid", "p_account_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_purchase_order_rpc"("p_purchase_order_id" "uuid", "p_account_id" "uuid" DEFAULT NULL::"uuid", "p_profile_id" "uuid" DEFAULT NULL::"uuid", "p_reason" "text" DEFAULT 'Anulación de orden de compra'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_po RECORD;
    v_now TIMESTAMPTZ := NOW();
    v_real_profile_id UUID;
    v_account_id UUID := p_account_id;
    v_credit_id UUID;
    v_outstanding NUMERIC;
BEGIN
    -- 1. Obtener la orden de compra
    SELECT * INTO v_po
      FROM public.purchase_orders
     WHERE id = p_purchase_order_id;

    IF v_po.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'La orden de compra no existe.');
    END IF;

    IF v_po.status = 'CANCELLED' THEN
        RETURN jsonb_build_object('success', false, 'error', 'La orden ya se encuentra anulada.');
    END IF;

    IF v_po.status IN ('PARTIAL', 'RECEIVED') THEN
        RETURN jsonb_build_object('success', false, 'error', 'No se puede anular una orden con mercadería ya recepcionada en almacén.');
    END IF;

    IF p_profile_id IS NOT NULL THEN
        SELECT id INTO v_real_profile_id
          FROM public.profiles
         WHERE auth_user_id = p_profile_id OR id = p_profile_id
         LIMIT 1;
    END IF;

    -- 2. Devolución de dinero abonado/pagado a la cuenta financiera
    IF v_po.amount_paid > 0 THEN
        IF v_account_id IS NULL THEN
            SELECT account_id INTO v_account_id
              FROM public.account_movements
             WHERE reference_type = 'purchase_orders' AND reference_id = p_purchase_order_id
             ORDER BY created_at DESC LIMIT 1;
        END IF;

        IF v_account_id IS NOT NULL THEN
            INSERT INTO public.account_movements (
                account_id, movement_type, amount, description,
                reference_type, reference_id, created_by, created_at
            ) VALUES (
                v_account_id, 'INCOME', v_po.amount_paid,
                'Reembolso por anulación de Orden #' || UPPER(SUBSTRING(p_purchase_order_id::text, 1, 8)),
                'purchase_orders', p_purchase_order_id, v_real_profile_id, v_now
            );

            UPDATE public.financial_accounts
               SET balance    = balance + v_po.amount_paid,
                   updated_at = v_now
             WHERE id = v_account_id;
        END IF;
    END IF;

    -- 3. Reversión de deuda en créditos del proveedor, basada en evidencia real del ledger
    SELECT scm.supplier_credit_id
      INTO v_credit_id
      FROM public.supplier_credit_movements scm
     WHERE scm.purchase_order_id = p_purchase_order_id
       AND scm.movement_type = 'CHARGE'
     ORDER BY scm.created_at ASC
     LIMIT 1;

    IF v_credit_id IS NOT NULL THEN
        v_outstanding := GREATEST(0, v_po.total_amount - v_po.amount_paid);

        IF v_outstanding > 0 THEN
            UPDATE public.supplier_credits
               SET current_debt = GREATEST(0, current_debt - v_outstanding),
                   updated_at   = v_now
             WHERE id = v_credit_id;

            INSERT INTO public.supplier_credit_movements (
                supplier_credit_id, purchase_order_id, movement_type,
                amount, notes, created_by, created_at
            ) VALUES (
                v_credit_id, p_purchase_order_id, 'PAYMENT',
                v_outstanding, 'Ajuste por anulación de Orden #' || UPPER(SUBSTRING(p_purchase_order_id::text, 1, 8)),
                v_real_profile_id, v_now
            );
        END IF;
    END IF;

    -- 4. Marcar orden como CANCELLED
    UPDATE public.purchase_orders
       SET status     = 'CANCELLED',
           updated_at = v_now
     WHERE id = p_purchase_order_id;

    RETURN jsonb_build_object('success', true, 'refunded_amount', v_po.amount_paid);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;


ALTER FUNCTION "public"."cancel_purchase_order_rpc"("p_purchase_order_id" "uuid", "p_account_id" "uuid", "p_profile_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_daily_checkin"("p_profile_id" "uuid", "p_action_by" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_today date := CURRENT_DATE;
    v_yesterday date := CURRENT_DATE - INTERVAL '1 day';
    v_yesterday_checkin record;
    v_today_checkin record;
    v_new_streak integer;
    v_points integer;
    v_base_reward integer;
    v_streak_step integer;
BEGIN
    -- 1. Validar si ya existe el check-in de hoy (Protección contra doble clic/ataque de red)
    SELECT id INTO v_today_checkin 
    FROM public.daily_checkins 
    WHERE profile_id = p_profile_id AND checkin_date = v_today;
    
    IF v_today_checkin.id IS NOT NULL THEN
        RAISE EXCEPTION 'Ya realizaste tu check-in hoy.';
    END IF;

    -- 2. Consultar el streak (racha) de ayer
    SELECT streak_day INTO v_yesterday_checkin 
    FROM public.daily_checkins 
    WHERE profile_id = p_profile_id AND checkin_date = v_yesterday 
    LIMIT 1;

    IF v_yesterday_checkin.streak_day IS NOT NULL THEN
        v_new_streak := v_yesterday_checkin.streak_day + 1;
    ELSE
        -- Si no hizo checkin ayer, se reinicia la racha a 1
        v_new_streak := 1;
    END IF;

    -- 3. Extraer configuración de recompensas de la tabla app_settings
    SELECT COALESCE((SELECT value::numeric::int FROM app_settings WHERE key = 'checkin_reward'), 20) INTO v_base_reward;
    SELECT COALESCE((SELECT value::numeric::int FROM app_settings WHERE key = 'checkin_streak_step'), 10) INTO v_streak_step;

    -- 4. Calcular Puntos de Recompensa
    -- Regla de Negocio Dinámica: Recompensa Base + (Paso * (Racha - 1))
    v_points := v_base_reward + ((v_new_streak - 1) * v_streak_step);

    -- 5. Insertar Check-in
    INSERT INTO public.daily_checkins (profile_id, checkin_date, streak_day, points_received)
    VALUES (p_profile_id, v_today, v_new_streak, v_points);

    -- 6. Insertar Movimiento en la Billetera (Auditoría)
    INSERT INTO public.wallet_movements (profile_id, movement_type, points, description)
    VALUES (p_profile_id, 'CHECKIN', v_points, 'Check-in diario del ' || v_today::text);

    -- 7. Actualizar Saldo Final del Usuario Atómicamente
    UPDATE public.profiles
    SET wallet_balance = COALESCE(wallet_balance, 0) + v_points
    WHERE id = p_profile_id;

END;
$$;


ALTER FUNCTION "public"."claim_daily_checkin"("p_profile_id" "uuid", "p_action_by" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."clear_cloud_cart_rpc"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_profile_id UUID;
  v_cart_id UUID;
BEGIN
  -- 1. Resolver el profile.id nativo comparando tanto contra id como contra auth_user_id
  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE id = p_user_id OR auth_user_id = p_user_id
  LIMIT 1;

  -- 2. Si no se halló en profiles, verificar si p_user_id ya existe como profile_id en shopping_carts
  IF v_profile_id IS NULL THEN
    SELECT profile_id INTO v_profile_id
    FROM public.shopping_carts
    WHERE profile_id = p_user_id
    LIMIT 1;
  END IF;

  -- Si tras la búsqueda extensiva es NULL, no existe carrito activo que limpiar
  IF v_profile_id IS NULL THEN
    RETURN;
  END IF;

  -- 3. Obtener el cart_id asociado al usuario
  SELECT id INTO v_cart_id
  FROM public.shopping_carts
  WHERE profile_id = v_profile_id
  LIMIT 1;

  -- 4. Borrar todos los items dentro del carrito en una sola transacción atómica
  IF v_cart_id IS NOT NULL THEN
    DELETE FROM public.cart_items WHERE cart_id = v_cart_id;
  END IF;
END;
$$;


ALTER FUNCTION "public"."clear_cloud_cart_rpc"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_purchase_order_rpc"("p_supplier_id" "uuid", "p_supplier_name" "text", "p_warehouse_id" "uuid", "p_total_amount" numeric, "p_payment_method" "text", "p_payment_status" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_due_date" "date", "p_document_date" "date", "p_document_type" "text", "p_document_number" "text", "p_notes" "text", "p_profile_id" "uuid", "p_items" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
    v_po_id UUID;
    v_item JSONB;
    v_credit_id UUID;
    v_credit_limit NUMERIC;
    v_current_debt NUMERIC;
    v_credit_active BOOLEAN;
    v_acc_balance NUMERIC;
    v_acc_type TEXT;
    v_acc_name TEXT;
    v_shift_status TEXT;
    v_real_debt NUMERIC;
    v_po_debt NUMERIC;
    v_item_subtotal NUMERIC;
BEGIN
    -- 0. Extraer Profile ID (Auditoría) si no se provee
    IF p_profile_id IS NULL THEN
        SELECT id INTO p_profile_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    END IF;

    -- 1. Validar límite de crédito si la orden queda en Pago Pendiente o es CRÉDITO
    IF p_payment_method = 'CRÉDITO' OR p_payment_status = 'PENDING' THEN
        SELECT id, credit_limit, current_debt, is_active 
        INTO v_credit_id, v_credit_limit, v_current_debt, v_credit_active
        FROM public.supplier_credits
        WHERE supplier_id = p_supplier_id
        FOR UPDATE; -- Bloquear fila para evitar Race Conditions

        IF NOT FOUND AND p_payment_method = 'CRÉDITO' THEN
            RETURN jsonb_build_object('success', false, 'error', 'El proveedor no tiene una línea de crédito habilitada.');
        END IF;

        IF v_credit_id IS NOT NULL THEN
            IF NOT v_credit_active AND p_payment_method = 'CRÉDITO' THEN
                RETURN jsonb_build_object('success', false, 'error', 'La línea de crédito con este proveedor se encuentra inactiva.');
            END IF;

            IF p_payment_method = 'CRÉDITO' AND v_credit_limit <= 0 THEN
                RETURN jsonb_build_object('success', false, 'error', 'El proveedor tiene un límite de crédito de S/ 0.00.');
            END IF;

            -- Calcular deuda real (sumando OCs pendientes que no hayan reflejado su monto en current_debt aún)
            SELECT COALESCE(SUM(total_amount - COALESCE(amount_paid, 0)), 0) INTO v_po_debt
            FROM public.purchase_orders
            WHERE supplier_id = p_supplier_id 
              AND payment_status IN ('PENDING', 'PARTIAL')
              AND status != 'CANCELLED';

            v_real_debt := GREATEST(v_current_debt, v_po_debt);

            IF v_credit_limit > 0 AND (v_real_debt + p_total_amount) > v_credit_limit THEN
                RETURN jsonb_build_object(
                    'success', false, 
                    'error', 'Límite de crédito excedido. Disponible: S/ ' || ROUND((v_credit_limit - v_real_debt), 2) || ', Monto de la orden: S/ ' || ROUND(p_total_amount, 2)
                );
            END IF;
        END IF;
    END IF;

    -- 2. Validar saldo suficiente y turno de caja abierto si es PAID
    IF p_payment_status = 'PAID' THEN
        IF p_account_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Debe seleccionar una cuenta origen para registrar el pago.');
        END IF;

        SELECT name, type, balance INTO v_acc_name, v_acc_type, v_acc_balance
        FROM public.financial_accounts
        WHERE id = p_account_id
        FOR UPDATE; -- Bloquear cuenta

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'La cuenta financiera seleccionada no existe.');
        END IF;

        IF v_acc_balance < p_total_amount THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Saldo insuficiente en la cuenta "' || v_acc_name || '". Saldo disponible: S/ ' || ROUND(v_acc_balance, 2) || ', Monto a pagar: S/ ' || ROUND(p_total_amount, 2)
            );
        END IF;

        IF v_acc_type = 'CAJA' THEN
            IF p_active_shift_id IS NULL THEN
                SELECT id INTO p_active_shift_id 
                FROM public.cash_shifts 
                WHERE account_id = p_account_id AND status = 'OPEN' 
                LIMIT 1;
            END IF;

            IF p_active_shift_id IS NULL THEN
                RETURN jsonb_build_object('success', false, 'error', 'No hay un turno de caja abierto para la cuenta "' || v_acc_name || '".');
            END IF;

            SELECT status INTO v_shift_status FROM public.cash_shifts WHERE id = p_active_shift_id;
            IF v_shift_status != 'OPEN' THEN
                RETURN jsonb_build_object('success', false, 'error', 'El turno de caja especificado ya no está abierto.');
            END IF;
        END IF;
    END IF;

    -- 3. Inserción de la Orden de Compra
    INSERT INTO public.purchase_orders (
        supplier_id, supplier_name, warehouse_id, total_amount, 
        payment_method, payment_status, due_date, document_date, 
        document_type, document_number, notes, created_by, status,
        amount_paid
    ) VALUES (
        p_supplier_id, p_supplier_name, p_warehouse_id, p_total_amount, 
        p_payment_method, p_payment_status, p_due_date, p_document_date, 
        p_document_type, p_document_number, p_notes, p_profile_id, 'PENDING',
        CASE WHEN p_payment_status = 'PAID' THEN p_total_amount ELSE 0 END
    ) RETURNING id INTO v_po_id;

    -- 4. Inserción de los Ítems (Mapeo a net_cost y subtotal, con NULLIF seguro para variant_id)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_item_subtotal := ((v_item->>'quantity')::NUMERIC * (v_item->>'unit_cost')::NUMERIC);

        INSERT INTO public.purchase_order_items (
            purchase_order_id, 
            product_id, 
            variant_id, 
            quantity_ordered, 
            unit_cost, 
            net_cost,
            subtotal, 
            batch_number, 
            expiry_date
        ) VALUES (
            v_po_id, 
            (v_item->>'product_id')::UUID, 
            NULLIF(v_item->>'variant_id', '')::UUID, 
            (v_item->>'quantity')::NUMERIC, 
            (v_item->>'unit_cost')::NUMERIC, 
            v_item_subtotal,
            v_item_subtotal,
            COALESCE(v_item->>'batch_number', 'DEFAULT'), 
            CASE WHEN (v_item->>'expiry_date') IS NOT NULL AND (v_item->>'expiry_date') != ''
                 THEN (v_item->>'expiry_date')::DATE 
                 ELSE NULL END
        );
    END LOOP;

    -- 5. Operaciones Financieras / Movimientos (Corregido a account_movements)
    IF p_payment_status = 'PAID' THEN
        -- Descontar saldo de la cuenta
        UPDATE public.financial_accounts
        SET balance = balance - p_total_amount,
            updated_at = NOW()
        WHERE id = p_account_id;

        -- Registrar movimiento en la tabla real account_movements
        INSERT INTO public.account_movements (
            account_id, shift_id, movement_type, amount, description, reference_type, reference_id, created_by
        ) VALUES (
            p_account_id, p_active_shift_id, 'EXPENSE', p_total_amount, 
            'Pago OC #' || left(v_po_id::text, 8), 
            'PURCHASE_ORDER', v_po_id, p_profile_id
        );

    ELSIF p_payment_method = 'CRÉDITO' THEN
        -- Aumentar deuda en la línea de crédito
        UPDATE public.supplier_credits
        SET current_debt = current_debt + p_total_amount,
            updated_at = NOW()
        WHERE id = v_credit_id;

        -- Registrar cargo en supplier_credit_movements
        INSERT INTO public.supplier_credit_movements (
            supplier_credit_id, movement_type, amount, purchase_order_id, notes, created_by
        ) VALUES (
            v_credit_id, 'CHARGE', p_total_amount, v_po_id, 
            'Orden de Compra #' || left(v_po_id::text, 8), p_profile_id
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'purchase_order_id', v_po_id);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;


ALTER FUNCTION "public"."create_purchase_order_rpc"("p_supplier_id" "uuid", "p_supplier_name" "text", "p_warehouse_id" "uuid", "p_total_amount" numeric, "p_payment_method" "text", "p_payment_status" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_due_date" "date", "p_document_date" "date", "p_document_type" "text", "p_document_number" "text", "p_notes" "text", "p_profile_id" "uuid", "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_purchase_order_rpc"("p_supplier_id" "uuid", "p_supplier_name" "text", "p_warehouse_id" "uuid", "p_total_amount" numeric, "p_payment_method" "text", "p_payment_status" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_due_date" "date", "p_document_date" "date", "p_document_type" "text", "p_document_number" "text", "p_notes" "text", "p_profile_id" "uuid", "p_items" "jsonb", "p_currency_code" "text" DEFAULT 'PEN'::"text", "p_exchange_rate" numeric DEFAULT 1.0000) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
    v_po_id UUID;
    v_item JSONB;
    v_credit_id UUID;
    v_credit_limit NUMERIC;
    v_current_debt NUMERIC;
    v_credit_active BOOLEAN;
    v_acc_balance NUMERIC;
    v_acc_type TEXT;
    v_acc_name TEXT;
    v_acc_currency TEXT;
    v_shift_status TEXT;
    v_real_debt NUMERIC;
    v_po_debt NUMERIC;
    v_item_subtotal NUMERIC;
    v_rate NUMERIC;
    v_total_base NUMERIC;
    v_deduct_amount NUMERIC;
BEGIN
    -- 0. Verificación de permisos granulares (requiere purchases.create o rol admin)
    IF NOT public.user_has_permission('purchases.create') THEN
        RETURN jsonb_build_object('success', false, 'error', 'No cuenta con el permiso requerido para registrar órdenes de compra (purchases.create).');
    END IF;

    -- Extraer Profile ID (Auditoría) si no se provee
    IF p_profile_id IS NULL THEN
        SELECT id INTO p_profile_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    END IF;

    v_rate := COALESCE(p_exchange_rate, 1.0000);
    IF v_rate <= 0 THEN
        v_rate := 1.0000;
    END IF;
    v_total_base := p_total_amount * v_rate;

    -- 1. Validar límite de crédito si la orden queda en Pago Pendiente o es CRÉDITO
    IF p_payment_method = 'CRÉDITO' OR p_payment_status = 'PENDING' THEN
        SELECT id, credit_limit, current_debt, is_active 
        INTO v_credit_id, v_credit_limit, v_current_debt, v_credit_active
        FROM public.supplier_credits
        WHERE supplier_id = p_supplier_id
        FOR UPDATE;

        IF NOT FOUND AND p_payment_method = 'CRÉDITO' THEN
            RETURN jsonb_build_object('success', false, 'error', 'El proveedor no tiene una línea de crédito habilitada.');
        END IF;

        IF v_credit_id IS NOT NULL THEN
            IF NOT v_credit_active AND p_payment_method = 'CRÉDITO' THEN
                RETURN jsonb_build_object('success', false, 'error', 'La línea de crédito con este proveedor se encuentra inactiva.');
            END IF;

            IF p_payment_method = 'CRÉDITO' AND v_credit_limit <= 0 THEN
                RETURN jsonb_build_object('success', false, 'error', 'El proveedor tiene un límite de crédito de S/ 0.00.');
            END IF;

            -- Calcular deuda real (sumando OCs pendientes valorizadas en moneda base)
            SELECT COALESCE(SUM(total_amount_base - (COALESCE(amount_paid, 0) * exchange_rate)), 0) INTO v_po_debt
            FROM public.purchase_orders
            WHERE supplier_id = p_supplier_id 
              AND payment_status IN ('PENDING', 'PARTIAL')
              AND status != 'CANCELLED';

            v_real_debt := GREATEST(v_current_debt, v_po_debt);

            IF v_credit_limit > 0 AND (v_real_debt + v_total_base) > v_credit_limit THEN
                RETURN jsonb_build_object(
                    'success', false, 
                    'error', 'Límite de crédito excedido. Disponible: S/ ' || ROUND((v_credit_limit - v_real_debt), 2) || ', Monto base orden: S/ ' || ROUND(v_total_base, 2)
                );
            END IF;
        END IF;
    END IF;

    -- 2. Validar saldo suficiente y turno de caja abierto si es PAID
    IF p_payment_status = 'PAID' THEN
        IF p_account_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Debe seleccionar una cuenta origen para registrar el pago.');
        END IF;

        SELECT name, type, balance, currency_code 
        INTO v_acc_name, v_acc_type, v_acc_balance, v_acc_currency
        FROM public.financial_accounts
        WHERE id = p_account_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'La cuenta financiera seleccionada no existe.');
        END IF;

        -- Calcular deducción según la moneda de la cuenta
        IF v_acc_currency = p_currency_code THEN
            v_deduct_amount := p_total_amount;
        ELSEIF v_acc_currency = 'PEN' THEN
            v_deduct_amount := v_total_base;
        ELSEIF p_currency_code = 'PEN' THEN
            v_deduct_amount := p_total_amount / v_rate;
        ELSE
            v_deduct_amount := v_total_base;
        END IF;

        IF v_acc_balance < v_deduct_amount THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Saldo insuficiente en la cuenta "' || v_acc_name || '". Saldo disponible: ' || COALESCE(v_acc_currency, 'PEN') || ' ' || ROUND(v_acc_balance, 2) || ', Requerido: ' || ROUND(v_deduct_amount, 2)
            );
        END IF;

        IF v_acc_type = 'CAJA' THEN
            IF p_active_shift_id IS NULL THEN
                SELECT id INTO p_active_shift_id 
                FROM public.cash_shifts 
                WHERE account_id = p_account_id AND status = 'OPEN' 
                LIMIT 1;
            END IF;

            IF p_active_shift_id IS NULL THEN
                RETURN jsonb_build_object('success', false, 'error', 'No hay un turno de caja abierto para la cuenta "' || v_acc_name || '".');
            END IF;

            SELECT status INTO v_shift_status FROM public.cash_shifts WHERE id = p_active_shift_id;
            IF v_shift_status != 'OPEN' THEN
                RETURN jsonb_build_object('success', false, 'error', 'El turno de caja especificado ya no está abierto.');
            END IF;
        END IF;
    END IF;

    -- 3. Inserción de la Orden de Compra
    INSERT INTO public.purchase_orders (
        supplier_id, supplier_name, warehouse_id, total_amount, 
        payment_method, payment_status, due_date, document_date, 
        document_type, document_number, notes, created_by, status,
        amount_paid, currency_code, exchange_rate, total_amount_base
    ) VALUES (
        p_supplier_id, p_supplier_name, p_warehouse_id, p_total_amount, 
        p_payment_method, p_payment_status, p_due_date, p_document_date, 
        p_document_type, p_document_number, p_notes, p_profile_id, 'PENDING',
        CASE WHEN p_payment_status = 'PAID' THEN p_total_amount ELSE 0 END,
        p_currency_code, v_rate, v_total_base
    ) RETURNING id INTO v_po_id;

    -- 4. Inserción de los Ítems
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_item_subtotal := ((v_item->>'quantity')::NUMERIC * (v_item->>'unit_cost')::NUMERIC);

        INSERT INTO public.purchase_order_items (
            purchase_order_id, 
            product_id, 
            variant_id, 
            quantity_ordered, 
            unit_cost, 
            net_cost,
            subtotal, 
            batch_number, 
            expiry_date,
            unit_cost_base
        ) VALUES (
            v_po_id, 
            (v_item->>'product_id')::UUID, 
            NULLIF(v_item->>'variant_id', '')::UUID, 
            (v_item->>'quantity')::NUMERIC, 
            (v_item->>'unit_cost')::NUMERIC, 
            (v_item->>'unit_cost')::NUMERIC,
            v_item_subtotal,
            COALESCE(v_item->>'batch_number', 'DEFAULT'), 
            CASE WHEN (v_item->>'expiry_date') IS NOT NULL AND (v_item->>'expiry_date') != ''
                 THEN (v_item->>'expiry_date')::DATE 
                 ELSE NULL END,
            ((v_item->>'unit_cost')::NUMERIC * v_rate)
        );
    END LOOP;

    -- 5. Operaciones Financieras / Movimientos
    IF p_payment_status = 'PAID' THEN
        UPDATE public.financial_accounts
        SET balance = balance - v_deduct_amount,
            updated_at = NOW()
        WHERE id = p_account_id;

        INSERT INTO public.account_movements (
            account_id, shift_id, movement_type, amount, description, reference_type, reference_id, created_by,
            currency_code, exchange_rate, amount_base
        ) VALUES (
            p_account_id, p_active_shift_id, 'EXPENSE', v_deduct_amount, 
            'Pago OC #' || left(v_po_id::text, 8), 
            'PURCHASE_ORDER', v_po_id, p_profile_id,
            v_acc_currency, v_rate, (v_deduct_amount * CASE WHEN v_acc_currency = 'PEN' THEN 1.0 ELSE v_rate END)
        );
    END IF;

    -- 6. Actualización de Deuda en Línea de Crédito Proveedor
    IF p_payment_method = 'CRÉDITO' OR p_payment_status = 'PENDING' THEN
        IF v_credit_id IS NOT NULL THEN
            UPDATE public.supplier_credits
            SET current_debt = current_debt + v_total_base,
                updated_at = NOW()
            WHERE id = v_credit_id;

            INSERT INTO public.supplier_credit_movements (
                supplier_credit_id, movement_type, amount, purchase_order_id, notes, created_by
            ) VALUES (
                v_credit_id, 'CHARGE', v_total_base, v_po_id, 'Generación de deuda por OC #' || left(v_po_id::text, 8), p_profile_id
            );
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'id', v_po_id, 'purchase_order_id', v_po_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;


ALTER FUNCTION "public"."create_purchase_order_rpc"("p_supplier_id" "uuid", "p_supplier_name" "text", "p_warehouse_id" "uuid", "p_total_amount" numeric, "p_payment_method" "text", "p_payment_status" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_due_date" "date", "p_document_date" "date", "p_document_type" "text", "p_document_number" "text", "p_notes" "text", "p_profile_id" "uuid", "p_items" "jsonb", "p_currency_code" "text", "p_exchange_rate" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_active_ingredient_safely"("p_ingredient_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_usage_count INT;
    v_product_names TEXT;
BEGIN
    -- Verificar si el componente está asociado a productos
    SELECT COUNT(*), STRING_AGG(p.name, ', ')
    INTO v_usage_count, v_product_names
    FROM public.product_active_ingredients pai
    JOIN public.products p ON p.id = pai.product_id
    WHERE pai.ingredient_id = p_ingredient_id;

    IF v_usage_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', format('No se puede eliminar: El componente está asignado en %s producto(s) (%s). Desvincúlalo antes de eliminar.', v_usage_count, v_product_names)
        );
    END IF;

    -- Proceder con la eliminación atómica
    DELETE FROM public.active_ingredients WHERE id = p_ingredient_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Componente químico eliminado exitosamente.'
    );
END;
$$;


ALTER FUNCTION "public"."delete_active_ingredient_safely"("p_ingredient_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_product_safely"("p_product_id" "uuid") RETURNS "text"[]
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_image_urls TEXT[];
    v_has_stock BOOLEAN := FALSE;
    v_has_orders BOOLEAN := FALSE;
    v_has_purchases BOOLEAN := FALSE;
    v_has_movements BOOLEAN := FALSE;
    v_has_exits BOOLEAN := FALSE;
    v_total_stock NUMERIC := 0;
    v_product_name TEXT;
BEGIN
    -- 0. Verificar si el producto existe y obtener su nombre
    SELECT name INTO v_product_name FROM public.products WHERE id = p_product_id;
    IF v_product_name IS NULL THEN
        RAISE EXCEPTION 'El producto no fue encontrado en el catálogo.';
    END IF;

    -- 1. VALIDACIÓN DE STOCK FÍSICO ACTIVO
    SELECT COALESCE(SUM(quantity), 0) INTO v_total_stock
    FROM public.warehouse_stock_batches
    WHERE variant_id IN (SELECT id FROM public.product_variants WHERE product_id = p_product_id);

    IF v_total_stock > 0 THEN
        RAISE EXCEPTION 'No se puede eliminar "%": cuenta con % unidades de stock físico en almacenes. Debes dar de baja el stock mediante una Salida de Inventario o transferirlo antes de eliminarlo.', v_product_name, v_total_stock;
    END IF;

    -- 2. VALIDACIÓN DE VENTAS / FACTURACIÓN (order_items)
    SELECT EXISTS (
        SELECT 1 FROM public.order_items
        WHERE variant_id IN (SELECT id FROM public.product_variants WHERE product_id = p_product_id)
           OR product_id = p_product_id
    ) INTO v_has_orders;

    IF v_has_orders THEN
        RAISE EXCEPTION 'No se puede eliminar "%": tiene historial de ventas y pedidos registrados. Por normativa contable y tributaria, desactiva el producto (Inactivo) en lugar de eliminarlo.', v_product_name;
    END IF;

    -- 3. VALIDACIÓN DE ÓRDENES DE COMPRA (purchase_order_items)
    SELECT EXISTS (
        SELECT 1 FROM public.purchase_order_items
        WHERE product_id = p_product_id
           OR variant_id IN (SELECT id FROM public.product_variants WHERE product_id = p_product_id)
    ) INTO v_has_purchases;

    IF v_has_purchases THEN
        RAISE EXCEPTION 'No se puede eliminar "%": está registrado en órdenes de compra a proveedores. Desactiva el producto para preservar la trazabilidad de abastecimiento.', v_product_name;
    END IF;

    -- 4. VALIDACIÓN DE MOVIMIENTOS HISTÓRICOS DE KARDEX (inventory_movements)
    SELECT EXISTS (
        SELECT 1 FROM public.inventory_movements
        WHERE variant_id IN (SELECT id FROM public.product_variants WHERE product_id = p_product_id)
           OR product_id = p_product_id
    ) INTO v_has_movements;

    IF v_has_movements THEN
        RAISE EXCEPTION 'No se puede eliminar "%": cuenta con movimientos registrados en el Kardex de almacén. La auditoría de inventario exige conservar su registro histórico.', v_product_name;
    END IF;

    -- 5. VALIDACIÓN DE SALIDAS DE INVENTARIO / MERMAS (inventory_exit_items)
    SELECT EXISTS (
        SELECT 1 FROM public.inventory_exit_items
        WHERE variant_id IN (SELECT id FROM public.product_variants WHERE product_id = p_product_id)
    ) INTO v_has_exits;

    IF v_has_exits THEN
        RAISE EXCEPTION 'No se puede eliminar "%": tiene registros de bajas o salidas de almacén asociadas.', v_product_name;
    END IF;

    -- 6. RECOPILACIÓN DE IMÁGENES PARA PURGA EN STORAGE BUCKET
    SELECT array_agg(image_url) INTO v_image_urls 
    FROM public.product_images 
    WHERE product_id = p_product_id AND image_url IS NOT NULL;

    -- 7. PURGA DE REGISTROS VOLÁTILES NO AUDITABLES (Carritos de compras huérfanos)
    DELETE FROM public.cart_items 
    WHERE variant_id IN (SELECT id FROM public.product_variants WHERE product_id = p_product_id);

    -- 8. PURGA DE CONFIGURACIONES DE CATÁLOGO DEL PRODUCTO
    DELETE FROM public.variant_attribute_values 
    WHERE variant_id IN (SELECT id FROM public.product_variants WHERE product_id = p_product_id);

    DELETE FROM public.product_active_ingredients 
    WHERE product_id = p_product_id;

    DELETE FROM public.product_images 
    WHERE product_id = p_product_id;

    -- 9. ELIMINACIÓN ATÓMICA DE VARIANTES Y PRODUCTO
    DELETE FROM public.product_variants 
    WHERE product_id = p_product_id;

    DELETE FROM public.products 
    WHERE id = p_product_id;

    RETURN COALESCE(v_image_urls, ARRAY[]::TEXT[]);

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '%', SQLERRM;
END;
$$;


ALTER FUNCTION "public"."delete_product_safely"("p_product_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_user_force"("p_user_id" "uuid", "p_reassign_to" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $_$
DECLARE
  v_actor uuid;
  v_actor_role text;
  v_auth_id uuid;
  v_target_role text;
  v_reassign uuid;
  v_fk record; -- Renombrado para evitar sombra con alias
BEGIN
  -- Solo administradores (alias 'ro')
  SELECT pr.id, COALESCE(ro.name, 'customer') INTO v_actor, v_actor_role
  FROM public.profiles pr
  LEFT JOIN public.user_roles ur ON ur.profile_id = pr.id
  LEFT JOIN public.roles ro ON ro.id = ur.role_id
  WHERE pr.auth_user_id = auth.uid()
  ORDER BY CASE WHEN ro.name = 'admin' THEN 1 ELSE 2 END
  LIMIT 1;

  IF v_actor IS NULL OR v_actor_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false,
      'message', 'No tienes permisos para eliminar usuarios.');
  END IF;

  IF p_user_id = v_actor THEN
    RETURN jsonb_build_object('success', false,
      'message', 'No puedes eliminar tu propia cuenta.');
  END IF;

  SELECT pr.auth_user_id, COALESCE(ro.name, 'customer') INTO v_auth_id, v_target_role
  FROM public.profiles pr
  LEFT JOIN public.user_roles ur ON ur.profile_id = pr.id
  LEFT JOIN public.roles ro ON ro.id = ur.role_id
  WHERE pr.id = p_user_id
  ORDER BY CASE WHEN ro.name = 'admin' THEN 1 ELSE 2 END
  LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false,
      'message', 'El usuario no fue encontrado.');
  END IF;

  IF v_target_role = 'admin' AND
     (SELECT count(DISTINCT pr.id) FROM public.profiles pr
      JOIN public.user_roles ur ON ur.profile_id = pr.id
      JOIN public.roles ro ON ro.id = ur.role_id
      WHERE ro.name = 'admin' AND pr.is_active) <= 1 THEN
    RETURN jsonb_build_object('success', false,
      'message', 'No puedes eliminar al único administrador activo.');
  END IF;

  v_reassign := COALESCE(p_reassign_to, v_actor);

  DELETE FROM customer_credit_movements
  WHERE customer_credit_id IN
        (SELECT id FROM customer_credits WHERE profile_id = p_user_id);
  DELETE FROM customer_credits WHERE profile_id = p_user_id;

  FOR v_fk IN
    SELECT c.conrelid::regclass::text AS tbl,
           a.attname AS col,
           a.attnotnull AS notnull
    FROM pg_constraint c
    JOIN pg_attribute a
      ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
    WHERE c.contype = 'f'
      AND c.confrelid = 'public.profiles'::regclass
      AND c.conrelid <> 'public.profiles'::regclass
      AND c.confdeltype IN ('a', 'r')
  LOOP
    IF v_fk.col = 'profile_id' THEN
      EXECUTE format('DELETE FROM %s WHERE %I = $1', v_fk.tbl, v_fk.col)
        USING p_user_id;
    ELSIF v_fk.notnull THEN
      EXECUTE format('UPDATE %s SET %I = $2 WHERE %I = $1', v_fk.tbl, v_fk.col, v_fk.col)
        USING p_user_id, v_reassign;
    ELSE
      EXECUTE format('UPDATE %s SET %I = NULL WHERE %I = $1', v_fk.tbl, v_fk.col, v_fk.col)
        USING p_user_id;
    END IF;
  END LOOP;

  DELETE FROM public.user_roles WHERE profile_id = p_user_id;
  DELETE FROM public.profiles WHERE id = p_user_id;

  IF v_auth_id IS NOT NULL THEN
    DELETE FROM auth.users WHERE id = v_auth_id;
  END IF;

  RETURN jsonb_build_object('success', true,
    'message', 'Usuario eliminado correctamente.');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false,
    'message', 'Error en el servidor: ' || SQLERRM);
END;
$_$;


ALTER FUNCTION "public"."delete_user_force"("p_user_id" "uuid", "p_reassign_to" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_user_safely"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_auth_user_id UUID;
    v_has_orders BOOLEAN := FALSE;
    v_has_sales_created BOOLEAN := FALSE;
    v_has_shifts BOOLEAN := FALSE;
    v_has_movements BOOLEAN := FALSE;
    v_has_credits BOOLEAN := FALSE;
BEGIN
    -- 1. Obtener auth_user_id vinculado al perfil
    SELECT auth_user_id INTO v_auth_user_id
    FROM public.profiles
    WHERE id = p_user_id;

    -- Respaldo: chequear si el p_user_id fue recibido como auth_user_id
    IF v_auth_user_id IS NULL AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        SELECT id, auth_user_id INTO p_user_id, v_auth_user_id
        FROM public.profiles
        WHERE auth_user_id = p_user_id;
        
        IF p_user_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'El usuario no fue encontrado en el sistema.');
        END IF;
    END IF;

    -- 2. Validar si el usuario tiene pedidos o compras como cliente
    SELECT EXISTS (
        SELECT 1 FROM public.orders 
        WHERE customer_id = p_user_id
    ) INTO v_has_orders;

    IF v_has_orders THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'No se puede eliminar el usuario porque tiene pedidos o ventas registradas en el historial contable. En su lugar, desactiva su cuenta.'
        );
    END IF;

    -- 3. Validar si el usuario creó ventas como cajero/vendedor
    SELECT EXISTS (
        SELECT 1 FROM public.orders 
        WHERE created_by = p_user_id OR (v_auth_user_id IS NOT NULL AND created_by = v_auth_user_id)
    ) INTO v_has_sales_created;

    IF v_has_sales_created THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'No se puede eliminar el usuario porque tiene ventas registradas como operador de caja. Te sugerimos desactivar su cuenta.'
        );
    END IF;

    -- 4. Validar si abrió o cerró turnos de caja
    SELECT EXISTS (
        SELECT 1 FROM public.cash_shifts 
        WHERE opened_by = p_user_id OR closed_by = p_user_id
           OR (v_auth_user_id IS NOT NULL AND (opened_by = v_auth_user_id OR closed_by = v_auth_user_id))
    ) INTO v_has_shifts;

    IF v_has_shifts THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'No se puede eliminar el usuario porque tiene aperturas o cierres de caja registrados.'
        );
    END IF;

    -- 5. Validar movimientos de cuentas financieras
    SELECT EXISTS (
        SELECT 1 FROM public.account_movements 
        WHERE created_by = p_user_id OR (v_auth_user_id IS NOT NULL AND created_by = v_auth_user_id)
    ) INTO v_has_movements;

    IF v_has_movements THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'No se puede eliminar el usuario porque tiene movimientos en cuentas financieras.'
        );
    END IF;

    -- 6. Validar cuentas de crédito de clientes
    SELECT EXISTS (
        SELECT 1 FROM public.customer_credits 
        WHERE customer_id = p_user_id
    ) INTO v_has_credits;

    IF v_has_credits THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'No se puede eliminar el usuario porque cuenta con una línea de crédito comercial activa.'
        );
    END IF;

    -- 7. Limpieza de tablas satélites no auditables
    DELETE FROM public.wallet_movements WHERE profile_id = p_user_id;
    DELETE FROM public.daily_checkins WHERE profile_id = p_user_id;
    DELETE FROM public.cart_items WHERE profile_id = p_user_id;

    -- 8. Eliminar perfil en public.profiles
    DELETE FROM public.profiles WHERE id = p_user_id;

    -- 9. Eliminar cuenta en auth.users si existe
    IF v_auth_user_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = v_auth_user_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Usuario eliminado correctamente.');

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Error en el servidor: ' || SQLERRM);
END;
$$;


ALTER FUNCTION "public"."delete_user_safely"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_existing_variants_for_import"("p_names" "text"[], "p_skus" "text"[], "p_warehouse_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("variant_id" "uuid", "product_id" "uuid", "product_name" "text", "brand_name" "text", "sku" "text", "variant_name" "text", "uses_lots" boolean, "current_stock" numeric)
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'extensions'
    AS $$
  SELECT
    pv.id,
    p.id,
    p.name,
    COALESCE(b.name, ''),
    COALESCE(pv.sku, ''),
    COALESCE((
      SELECT string_agg(av.value, ' / ' ORDER BY a.name)
      FROM variant_attribute_values vav
      JOIN attribute_values av ON av.id = vav.attribute_value_id
      JOIN attributes a ON a.id = av.attribute_id
      WHERE vav.variant_id = pv.id
    ), ''),
    p.uses_batches,
    COALESCE((
      SELECT sum(w.available_quantity)
      FROM warehouse_stock_batches w
      WHERE w.variant_id = pv.id AND w.warehouse_id = p_warehouse_id
    ), 0)
  FROM products p
  JOIN product_variants pv ON pv.product_id = p.id
  LEFT JOIN brands b ON b.id = p.brand_id
  WHERE import_norm(p.name) = ANY (COALESCE(p_names, '{}'))
     OR lower(pv.sku) = ANY (COALESCE(p_skus, '{}'));
$$;


ALTER FUNCTION "public"."find_existing_variants_for_import"("p_names" "text"[], "p_skus" "text"[], "p_warehouse_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_cash_shifts_summary_rpc"("p_limit" integer, "p_offset" integer, "p_status" "text" DEFAULT NULL::"text", "p_date_from" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_date_to" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_profile_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_open_count   int;
  v_closed_count int;
  v_total_count  int;
  v_shifts       jsonb;
BEGIN
  -- Conteo de OPEN (siempre sin filtro de status para el badge)
  SELECT COUNT(*) INTO v_open_count
  FROM public.cash_shifts
  WHERE (p_profile_id IS NULL OR opened_by = p_profile_id)
    AND (p_date_from IS NULL OR opened_at >= p_date_from)
    AND (p_date_to   IS NULL OR opened_at <= p_date_to)
    AND status = 'OPEN';

  -- Conteo de CLOSED
  SELECT COUNT(*) INTO v_closed_count
  FROM public.cash_shifts
  WHERE (p_profile_id IS NULL OR opened_by = p_profile_id)
    AND (p_date_from IS NULL OR opened_at >= p_date_from)
    AND (p_date_to   IS NULL OR opened_at <= p_date_to)
    AND status = 'CLOSED';

  -- Total con filtro de status aplicado
  SELECT COUNT(*) INTO v_total_count
  FROM public.cash_shifts
  WHERE (p_status     IS NULL OR status = p_status)
    AND (p_profile_id IS NULL OR opened_by = p_profile_id)
    AND (p_date_from  IS NULL OR opened_at >= p_date_from)
    AND (p_date_to    IS NULL OR opened_at <= p_date_to);

  -- Página de turnos con todos los joins
  SELECT jsonb_agg(row_to_json(s.*)) INTO v_shifts
  FROM (
    SELECT
      cs.id, cs.status, cs.opening_amount, cs.expected_amount,
      cs.actual_amount, cs.difference_amount, cs.notes,
      cs.opened_at, cs.closed_at, cs.account_id,
      jsonb_build_object('id', fa.id, 'name', fa.name, 'type', fa.type) AS financial_accounts,
      jsonb_build_object('full_name', op.full_name) AS opened_by_profile,
      jsonb_build_object('full_name', cp.full_name) AS closed_by_profile
    FROM public.cash_shifts cs
    JOIN public.financial_accounts fa ON fa.id = cs.account_id
    LEFT JOIN public.profiles op ON op.id = cs.opened_by
    LEFT JOIN public.profiles cp ON cp.id = cs.closed_by
    WHERE (p_status     IS NULL OR cs.status = p_status)
      AND (p_profile_id IS NULL OR cs.opened_by = p_profile_id)
      AND (p_date_from  IS NULL OR cs.opened_at >= p_date_from)
      AND (p_date_to    IS NULL OR cs.opened_at <= p_date_to)
    ORDER BY
      CASE cs.status WHEN 'OPEN' THEN 0 ELSE 1 END ASC,
      cs.opened_at DESC
    LIMIT p_limit OFFSET p_offset
  ) s;

  RETURN jsonb_build_object(
    'shifts',        COALESCE(v_shifts, '[]'::jsonb),
    'total_count',   v_total_count,
    'open_count',    v_open_count,
    'closed_count',  v_closed_count
  );
END;
$$;


ALTER FUNCTION "public"."get_cash_shifts_summary_rpc"("p_limit" integer, "p_offset" integer, "p_status" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_profile_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_credit_movements_totals_rpc"("p_credit_id" "uuid", "p_date_filter" "text" DEFAULT NULL::"text") RETURNS TABLE("total_charged" numeric, "total_paid" numeric, "charge_count" bigint, "payment_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
    v_from_date TIMESTAMPTZ;
BEGIN
    IF p_date_filter = '30_days' THEN
        v_from_date := NOW() - INTERVAL '30 days';
    ELSIF p_date_filter = 'this_month' THEN
        v_from_date := DATE_TRUNC('month', NOW());
    ELSE
        v_from_date := NULL;
    END IF;

    RETURN QUERY
    SELECT 
        COALESCE(SUM(amount) FILTER (WHERE movement_type = 'CHARGE'), 0)::NUMERIC AS total_charged,
        COALESCE(SUM(amount) FILTER (WHERE movement_type = 'PAYMENT'), 0)::NUMERIC AS total_paid,
        COUNT(*) FILTER (WHERE movement_type = 'CHARGE')::BIGINT AS charge_count,
        COUNT(*) FILTER (WHERE movement_type = 'PAYMENT')::BIGINT AS payment_count
    FROM public.customer_credit_movements
    WHERE customer_credit_id = p_credit_id
      AND (v_from_date IS NULL OR created_at >= v_from_date);
END;
$$;


ALTER FUNCTION "public"."get_credit_movements_totals_rpc"("p_credit_id" "uuid", "p_date_filter" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_customer_credits_stats_rpc"("p_search_query" "text" DEFAULT ''::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_total_debt numeric := 0;
  v_active_count int := 0;
  v_suspended_count int := 0;
  v_maxed_out_count int := 0;
  v_debt_count int := 0;
  v_result jsonb;
BEGIN
  SELECT 
    COALESCE(SUM(cc.current_debt), 0),
    COUNT(*) FILTER (WHERE cc.is_active = true),
    COUNT(*) FILTER (WHERE cc.is_active = false),
    COUNT(*) FILTER (WHERE cc.is_active = true AND cc.credit_limit > 0 AND cc.current_debt >= cc.credit_limit),
    COUNT(*) FILTER (WHERE cc.is_active = true AND cc.current_debt > 0)
  INTO 
    v_total_debt, 
    v_active_count, 
    v_suspended_count, 
    v_maxed_out_count, 
    v_debt_count
  FROM customer_credits cc
  JOIN profiles p ON p.id = cc.profile_id
  WHERE p_search_query = '' 
     OR p.full_name ILIKE '%' || p_search_query || '%'
     OR p.document_number ILIKE '%' || p_search_query || '%'
     OR p.phone ILIKE '%' || p_search_query || '%';

  v_result := jsonb_build_object(
    'totalDebt', v_total_debt,
    'activeAccounts', v_active_count,
    'suspendedAccounts', v_suspended_count,
    'maxedOutAccounts', v_maxed_out_count,
    'debtCount', v_debt_count
  );

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_customer_credits_stats_rpc"("p_search_query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_customers_global_stats_rpc"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
    v_total_customers INT;
    v_active_customers INT;
    v_inactive_customers INT;
    v_total_revenue NUMERIC;
    v_total_debt NUMERIC;
    v_debt_customers_count INT;
BEGIN
    SELECT COUNT(*),
           COUNT(*) FILTER (WHERE p.is_active = true),
           COUNT(*) FILTER (WHERE p.is_active = false)
      INTO v_total_customers, v_active_customers, v_inactive_customers
      FROM public.profiles p
     WHERE NOT EXISTS (
       SELECT 1 FROM public.user_roles ur
       JOIN public.roles ro ON ro.id = ur.role_id
       WHERE ur.profile_id = p.id AND ro.name IN ('admin', 'employee')
     );

    SELECT COALESCE(SUM(total_amount), 0)
      INTO v_total_revenue
      FROM public.orders
     WHERE status = 'COMPLETED';

    SELECT COALESCE(SUM(current_debt), 0),
           COUNT(*) FILTER (WHERE current_debt > 0)
      INTO v_total_debt, v_debt_customers_count
      FROM public.customer_credits;

    RETURN jsonb_build_object(
        'totalCustomersCount', v_total_customers,
        'activeCustomersCount', v_active_customers,
        'inactiveCustomersCount', v_inactive_customers,
        'totalRevenue', v_total_revenue,
        'totalDebt', v_total_debt,
        'debtCustomersCount', v_debt_customers_count
    );
END;
$$;


ALTER FUNCTION "public"."get_customers_global_stats_rpc"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dashboard_sales_overview"("p_from" "date" DEFAULT NULL::"date", "p_to" "date" DEFAULT NULL::"date", "p_warehouse_id" "uuid" DEFAULT NULL::"uuid", "p_tz" "text" DEFAULT 'America/Lima'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_from date;
  v_to date;
  v_days int;
  v_bucket text;
  v_prev_from date;
  v_prev_to date;
  v_trend jsonb;
  v_weekday jsonb;
  v_cur record;
  v_prev record;
BEGIN
  v_to := COALESCE(p_to, (now() AT TIME ZONE p_tz)::date);

  v_from := p_from;
  IF v_from IS NULL THEN
    SELECT min((created_at AT TIME ZONE p_tz)::date) INTO v_from
    FROM orders
    WHERE status = 'COMPLETED'
      AND (p_warehouse_id IS NULL OR warehouse_id = p_warehouse_id);
    v_from := COALESCE(v_from, v_to);
  END IF;

  IF v_from > v_to THEN
    RAISE EXCEPTION 'La fecha inicial no puede ser mayor que la final.';
  END IF;

  v_days := (v_to - v_from) + 1;
  v_bucket := CASE
    WHEN v_days <= 62 THEN 'day'
    WHEN v_days <= 366 THEN 'week'
    ELSE 'month'
  END;

  -- Periodo anterior de igual duración (para "vs anterior")
  v_prev_to := v_from - 1;
  v_prev_from := v_prev_to - (v_days - 1);

  -- Pedidos COMPLETED con su día local (se reutiliza en las 4 consultas)
  -- (se repite el CTE en vez de usar tabla temporal: la función es STABLE)

  SELECT COALESCE(sum(total_amount), 0) AS revenue,
         COALESCE(sum(total_profit), 0) AS profit,
         COALESCE(sum(LEAST(COALESCE(amount_paid, 0), total_amount)), 0) AS collected,
         count(*) AS orders
  INTO v_cur
  FROM orders
  WHERE status = 'COMPLETED'
    AND (p_warehouse_id IS NULL OR warehouse_id = p_warehouse_id)
    AND (created_at AT TIME ZONE p_tz)::date BETWEEN v_from AND v_to;

  SELECT COALESCE(sum(total_amount), 0) AS revenue,
         COALESCE(sum(total_profit), 0) AS profit,
         COALESCE(sum(LEAST(COALESCE(amount_paid, 0), total_amount)), 0) AS collected,
         count(*) AS orders
  INTO v_prev
  FROM orders
  WHERE status = 'COMPLETED'
    AND (p_warehouse_id IS NULL OR warehouse_id = p_warehouse_id)
    AND (created_at AT TIME ZONE p_tz)::date BETWEEN v_prev_from AND v_prev_to;

  -- Serie temporal con buckets completos (generate_series rellena huecos)
  WITH buckets AS (
    SELECT gs::date AS b_start
    FROM generate_series(
      date_trunc(v_bucket, v_from::timestamp),
      date_trunc(v_bucket, v_to::timestamp),
      ('1 ' || v_bucket)::interval
    ) gs
  ),
  agg AS (
    SELECT date_trunc(v_bucket, ((created_at AT TIME ZONE p_tz)::date)::timestamp)::date AS b_start,
           sum(total_amount) AS revenue, sum(total_profit) AS profit, count(*) AS orders
    FROM orders
    WHERE status = 'COMPLETED'
      AND (p_warehouse_id IS NULL OR warehouse_id = p_warehouse_id)
      AND (created_at AT TIME ZONE p_tz)::date BETWEEN v_from AND v_to
    GROUP BY 1
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'date', to_char(GREATEST(b.b_start, v_from), 'YYYY-MM-DD'),
    'revenue', COALESCE(a.revenue, 0),
    'profit', COALESCE(a.profit, 0),
    'orders', COALESCE(a.orders, 0)
  ) ORDER BY b.b_start), '[]'::jsonb)
  INTO v_trend
  FROM buckets b LEFT JOIN agg a USING (b_start);

  -- Actividad por día de la semana (Lun..Dom) sobre TODO el rango
  WITH dow AS (
    SELECT i AS iso_dow FROM generate_series(1, 7) i
  ),
  agg AS (
    SELECT extract(isodow FROM (created_at AT TIME ZONE p_tz)::date)::int AS iso_dow,
           sum(total_amount) AS revenue, count(*) AS orders
    FROM orders
    WHERE status = 'COMPLETED'
      AND (p_warehouse_id IS NULL OR warehouse_id = p_warehouse_id)
      AND (created_at AT TIME ZONE p_tz)::date BETWEEN v_from AND v_to
    GROUP BY 1
  )
  SELECT jsonb_agg(jsonb_build_object(
    'iso_dow', dow.iso_dow,
    'revenue', COALESCE(a.revenue, 0),
    'orders', COALESCE(a.orders, 0)
  ) ORDER BY dow.iso_dow)
  INTO v_weekday
  FROM dow LEFT JOIN agg a USING (iso_dow);

  RETURN jsonb_build_object(
    'from', to_char(v_from, 'YYYY-MM-DD'),
    'to', to_char(v_to, 'YYYY-MM-DD'),
    'days', v_days,
    'bucket', v_bucket,
    'total_revenue', v_cur.revenue,
    'total_profit', v_cur.profit,
    'total_collected', v_cur.collected,
    'total_orders', v_cur.orders,
    'prev_revenue', v_prev.revenue,
    'prev_profit', v_prev.profit,
    'prev_collected', v_prev.collected,
    'prev_orders', v_prev.orders,
    'trend', v_trend,
    'weekday', v_weekday
  );
END;
$$;


ALTER FUNCTION "public"."get_dashboard_sales_overview"("p_from" "date", "p_to" "date", "p_warehouse_id" "uuid", "p_tz" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_loyalty_dashboard"("p_auth_user_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_result JSON;
  v_profile_id UUID;
  v_wallet_balance INT;
  v_today_date DATE := DATE(NOW() AT TIME ZONE 'UTC');
  v_has_today_checkin BOOLEAN := FALSE;
  v_latest_checkin JSON;
  v_today_games JSON;
  v_recent_movements JSON;
BEGIN
  -- 1. Obtener perfil
  SELECT id, COALESCE(wallet_balance, 0) INTO v_profile_id, v_wallet_balance
  FROM profiles
  WHERE auth_user_id = p_auth_user_id;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado para auth_user_id: %', p_auth_user_id;
  END IF;

  -- 2. Verificar Check-in de hoy
  SELECT EXISTS (
    SELECT 1 FROM daily_checkins
    WHERE profile_id = v_profile_id
      AND checkin_date = v_today_date
  ) INTO v_has_today_checkin;

  -- 3. Obtener último checkin (para racha)
  SELECT row_to_json(c) INTO v_latest_checkin
  FROM (
    SELECT checkin_date, streak_day 
    FROM daily_checkins
    WHERE profile_id = v_profile_id
    ORDER BY checkin_date DESC
    LIMIT 1
  ) c;

  -- 4. Contar minijuegos de hoy agrupados por tipo
  SELECT COALESCE(json_object_agg(game_type, game_count), '{}'::json) INTO v_today_games
  FROM (
    SELECT movement_type AS game_type, COUNT(*) AS game_count
    FROM wallet_movements
    WHERE profile_id = v_profile_id
      AND movement_type LIKE 'MINI_GAME_%'
      AND DATE(created_at AT TIME ZONE 'UTC') = v_today_date
    GROUP BY movement_type
  ) g;

  -- 5. Obtener últimos 20 movimientos
  SELECT COALESCE(json_agg(row_to_json(m)), '[]'::json) INTO v_recent_movements
  FROM (
    SELECT id, movement_type, points, description, created_at
    FROM wallet_movements
    WHERE profile_id = v_profile_id
    ORDER BY created_at DESC
    LIMIT 20
  ) m;

  -- Armar JSON final
  v_result := json_build_object(
    'profile_id', v_profile_id,
    'wallet_balance', v_wallet_balance,
    'has_today_checkin', v_has_today_checkin,
    'latest_checkin', v_latest_checkin,
    'today_games', v_today_games,
    'recent_movements', v_recent_movements
  );

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_loyalty_dashboard"("p_auth_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_movement_totals_rpc"("p_filter_type" "text", "p_account_id" "text", "p_search_text" "text", "p_date_from" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_date_to" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
DECLARE
  v_income NUMERIC := 0;
  v_expense NUMERIC := 0;
  v_is_uuid BOOLEAN := FALSE;
BEGIN
  -- Detectar si la búsqueda es un UUID
  v_is_uuid := p_search_text ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

  SELECT 
    COALESCE(SUM(amount) FILTER (WHERE movement_type = 'INCOME'), 0),
    COALESCE(SUM(amount) FILTER (WHERE movement_type = 'EXPENSE'), 0)
  INTO v_income, v_expense
  FROM public.account_movements
  WHERE (p_filter_type = 'Todos' OR movement_type = p_filter_type)
    AND (p_account_id = 'Todas' OR account_id::text = p_account_id)
    AND (
      p_search_text = '' OR 
      (v_is_uuid AND (description ILIKE '%' || p_search_text || '%' OR reference_id::text = p_search_text)) OR
      (NOT v_is_uuid AND description ILIKE '%' || p_search_text || '%')
    )
    AND (p_date_from IS NULL OR created_at >= p_date_from)
    AND (p_date_to IS NULL OR created_at <= p_date_to);

  RETURN jsonb_build_object(
    'totalIncome', v_income,
    'totalExpense', v_expense
  );
END;
$_$;


ALTER FUNCTION "public"."get_movement_totals_rpc"("p_filter_type" "text", "p_account_id" "text", "p_search_text" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_default_warehouse"() RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Si puede ver todos, devolver primer almacén activo
  IF public.user_has_permission('warehouses.view_all') THEN
    RETURN (
      SELECT w.id
      FROM public.warehouses w
      WHERE w.is_active = TRUE
      ORDER BY w.name
      LIMIT 1
    );
  END IF;

  -- Sino, devolver almacén por defecto o primer asignado
  RETURN (
    SELECT uw.warehouse_id
    FROM public.user_warehouses uw
    JOIN public.profiles p ON p.id = uw.profile_id
    WHERE p.auth_user_id = auth.uid()
    ORDER BY uw.is_default DESC, uw.created_at ASC
    LIMIT 1
  );
END;
$$;


ALTER FUNCTION "public"."get_my_default_warehouse"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_permissions"() RETURNS TABLE("role_name" "text", "permission_code" "text", "permission_name" "text", "module" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT DISTINCT
    r.name as role_name,
    p.code as permission_code,
    p.name as permission_name,
    p.module as module
  FROM public.profiles pr
  JOIN public.user_roles ur ON ur.profile_id = pr.id
  JOIN public.roles r ON r.id = ur.role_id
  LEFT JOIN public.role_permissions rp ON rp.role_id = r.id
  LEFT JOIN public.permissions p ON p.id = rp.permission_id
  WHERE pr.auth_user_id = auth.uid();
$$;


ALTER FUNCTION "public"."get_my_permissions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_warehouses"() RETURNS TABLE("id" "uuid", "name" "text", "address" "text", "is_active" boolean, "is_default" boolean, "type" "text", "code" "text", "layout_config" "jsonb")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF public.user_has_permission('warehouses.view_all') OR public.is_admin() THEN
    RETURN QUERY
    SELECT w.id, w.name, w.address, w.is_active, FALSE AS is_default,
           COALESCE(w.type, 'warehouse') AS type, w.code, w.layout_config
    FROM public.warehouses w
    WHERE w.is_active = TRUE
    ORDER BY w.name;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT w.id, w.name, w.address, w.is_active, uw.is_default,
         COALESCE(w.type, 'warehouse') AS type, w.code, w.layout_config
  FROM public.user_warehouses uw
  JOIN public.profiles p ON p.id = uw.profile_id
  JOIN public.warehouses w ON w.id = uw.warehouse_id
  WHERE p.auth_user_id = auth.uid() AND w.is_active = TRUE
  ORDER BY uw.is_default DESC, w.name ASC;
END;
$$;


ALTER FUNCTION "public"."get_my_warehouses"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_product_detail_bundle"("p_product_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'financials', (
            SELECT jsonb_build_object(
                'total_sold', COALESCE(SUM(oi.quantity), 0),
                'total_revenue', COALESCE(SUM(oi.quantity * oi.applied_price), 0),
                'reinvestment_needed', COALESCE(SUM(oi.quantity * oi.unit_cost), 0),
                'variant_sales', COALESCE(
                    (
                        SELECT jsonb_object_agg(
                            oi_var.variant_id,
                            jsonb_build_object(
                                'qty', SUM(oi_var.quantity),
                                'cost', SUM(oi_var.quantity * oi_var.unit_cost),
                                'revenue', SUM(oi_var.quantity * oi_var.applied_price)
                            )
                        )
                        FROM order_items oi_var
                        INNER JOIN orders o_var ON o_var.id = oi_var.order_id
                        WHERE oi_var.product_id = p_product_id
                          AND o_var.status = 'COMPLETED'
                        GROUP BY oi_var.variant_id
                    ), '{}'::jsonb
                )
            )
            FROM order_items oi
            INNER JOIN orders o ON o.id = oi.order_id
            WHERE oi.product_id = p_product_id
              AND o.status = 'COMPLETED'
        ),
        'stocks', (
            SELECT COALESCE(jsonb_agg(s), '[]'::jsonb)
            FROM (
                SELECT warehouse_id, variant_id, SUM(available_quantity) AS available_quantity
                FROM warehouse_stock_batches
                WHERE product_id = p_product_id
                GROUP BY warehouse_id, variant_id
            ) s
        ),
        'batches', (
            SELECT COALESCE(jsonb_agg(b), '[]'::jsonb)
            FROM (
                SELECT wsb.id, wsb.available_quantity, wsb.variant_id, wsb.warehouse_id,
                       wsb.batch_number, wsb.expiry_date,
                       jsonb_build_object('name', w.name) AS warehouses
                FROM warehouse_stock_batches wsb
                LEFT JOIN warehouses w ON w.id = wsb.warehouse_id
                WHERE wsb.product_id = p_product_id
                ORDER BY wsb.expiry_date ASC NULLS LAST
            ) b
        ),
        'images', (
            SELECT COALESCE(jsonb_agg(img), '[]'::jsonb)
            FROM (
                SELECT id, product_id, variant_id, image_url, display_order, is_main
                FROM product_images
                WHERE product_id = p_product_id
                ORDER BY display_order ASC
            ) img
        ),
        'variants', (
            SELECT COALESCE(jsonb_agg(v), '[]'::jsonb)
            FROM (
                SELECT pv.id, pv.product_id, pv.sku, pv.sale_price, pv.wholesale_price,
                       pv.wholesale_min_quantity, pv.reorder_point, pv.is_active, pv.unit_cost,
                       (
                           SELECT jsonb_agg(vav)
                           FROM variant_attribute_values vav
                           WHERE vav.variant_id = pv.id
                       ) AS variant_attribute_values
                FROM product_variants pv
                WHERE pv.product_id = p_product_id AND pv.is_active = true
                ORDER BY pv.created_at ASC
            ) v
        ),
        'reviews', (
            SELECT COALESCE(jsonb_agg(r), '[]'::jsonb)
            FROM (
                SELECT rating, comment, user_name, created_at
                FROM product_reviews
                WHERE product_id = p_product_id
                ORDER BY created_at DESC
                LIMIT 50
            ) r
        ),
        'ingredients', (
            SELECT COALESCE(jsonb_agg(ing), '[]'::jsonb)
            FROM (
                SELECT pai.concentration, pai.unit,
                       jsonb_build_object('id', ai.id, 'name', ai.name, 'description', ai.description) AS active_ingredients
                FROM product_active_ingredients pai
                LEFT JOIN active_ingredients ai ON ai.id = pai.active_ingredient_id
                WHERE pai.product_id = p_product_id
            ) ing
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_product_detail_bundle"("p_product_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_profiles_with_email"() RETURNS TABLE("id" "uuid", "auth_user_id" "uuid", "full_name" "text", "avatar_url" "text", "role" "text", "phone" "text", "document_type" "text", "document_number" "text", "created_at" timestamp with time zone, "is_active" boolean, "wallet_balance" integer, "email" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."get_profiles_with_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_purchase_order_items_details"("p_order_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'product_id', poi.product_id,
      'variant_id', poi.variant_id,
      'product_name', p.name,
      'sku', pv.sku,
      'quantity_ordered', poi.quantity_ordered,
      'quantity_received', poi.quantity_received,
      'unit_cost', poi.unit_cost,
      'batch_number', COALESCE(poi.batch_number, 'DEFAULT'),
      'expiry_date', poi.expiry_date,
      'uses_batches', COALESCE(p.uses_batches, false),
      'variant_attrs', COALESCE(
        (
          SELECT STRING_AGG(attr.name || ': ' || val.value, ' · ')
          FROM variant_attribute_values vav
          JOIN attribute_values val ON val.id = vav.attribute_value_id
          JOIN attributes attr ON attr.id = val.attribute_id
          WHERE vav.variant_id = poi.variant_id
        ), 'Única'
      ),
      'image_url', (
        SELECT pi.image_url 
        FROM product_images pi 
        WHERE pi.product_id = poi.product_id 
          AND (pi.variant_id = poi.variant_id OR pi.variant_id IS NULL)
        ORDER BY CASE WHEN pi.variant_id = poi.variant_id THEN 0 ELSE 1 END, pi.is_main DESC 
        LIMIT 1
      )
    )
  ), '[]'::jsonb)
  INTO v_result
  FROM purchase_order_items poi
  LEFT JOIN products p ON p.id = poi.product_id
  LEFT JOIN product_variants pv ON pv.id = poi.variant_id
  WHERE poi.purchase_order_id = p_order_id;

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_purchase_order_items_details"("p_order_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_supplier_credits_stats_rpc"("p_search_query" "text" DEFAULT ''::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_total_debt numeric := 0;
  v_active_count int := 0;
  v_suspended_count int := 0;
  v_maxed_out_count int := 0;
  v_debt_count int := 0;
  v_result jsonb;
BEGIN
  SELECT 
    COALESCE(SUM(sc.current_debt), 0),
    COUNT(*) FILTER (WHERE sc.is_active = true),
    COUNT(*) FILTER (WHERE sc.is_active = false),
    COUNT(*) FILTER (WHERE sc.is_active = true AND sc.current_debt >= sc.credit_limit AND sc.credit_limit > 0),
    COUNT(*) FILTER (WHERE sc.is_active = true AND sc.current_debt > 0)
  INTO 
    v_total_debt, 
    v_active_count, 
    v_suspended_count, 
    v_maxed_out_count, 
    v_debt_count
  FROM supplier_credits sc
  JOIN suppliers s ON s.id = sc.supplier_id
  WHERE p_search_query = '' 
     OR s.name ILIKE '%' || p_search_query || '%'
     OR s.tax_id ILIKE '%' || p_search_query || '%'
     OR s.phone ILIKE '%' || p_search_query || '%';

  v_result := jsonb_build_object(
    'totalDebt', v_total_debt,
    'activeAccounts', v_active_count,
    'suspendedAccounts', v_suspended_count,
    'maxedOutAccounts', v_maxed_out_count,
    'debtCount', v_debt_count
  );

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_supplier_credits_stats_rpc"("p_search_query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_top_customers"("p_limit" integer DEFAULT 10) RETURNS TABLE("id" "uuid", "full_name" "text", "avatar_url" "text", "is_active" boolean, "wallet_balance" integer, "created_at" timestamp with time zone, "total_revenue" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.avatar_url,
    p.is_active,
    p.wallet_balance,
    p.created_at,
    COALESCE(SUM(o.total_amount), 0) AS total_revenue
  FROM profiles p
  JOIN orders o ON o.customer_id = p.id
  WHERE o.status = 'COMPLETED'
  GROUP BY p.id
  ORDER BY total_revenue DESC
  LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_top_customers"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_top_customers_rpc"("p_limit" integer DEFAULT 5) RETURNS TABLE("id" "uuid", "full_name" "text", "phone" "text", "document_number" "text", "document_type" "text", "avatar_url" "text", "wallet_balance" numeric, "is_active" boolean, "created_at" timestamp with time zone, "total_revenue" numeric, "order_count" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT 
        p.id,
        p.full_name,
        p.phone,
        p.document_number,
        p.document_type,
        p.avatar_url,
        p.wallet_balance::numeric,
        p.is_active,
        p.created_at,
        COALESCE(SUM(o.total_amount), 0) AS total_revenue,
        COUNT(o.id) AS order_count
    FROM public.profiles p
    JOIN public.orders o ON o.customer_id = p.id
    WHERE o.status = 'COMPLETED'
      AND NOT EXISTS (
        SELECT 1 FROM public.user_roles ur
        JOIN public.roles ro ON ro.id = ur.role_id
        WHERE ur.profile_id = p.id AND ro.name IN ('admin', 'employee')
      )
    GROUP BY p.id
    ORDER BY total_revenue DESC
    LIMIT p_limit;
$$;


ALTER FUNCTION "public"."get_top_customers_rpc"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_relations_summary"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_orders int; v_sales int; v_shifts int; v_movs int; v_credits int;
  v_debt numeric; v_wallet int; v_points int;
BEGIN
  SELECT COALESCE(wallet_balance, 0) INTO v_points FROM profiles WHERE id = p_user_id;
  SELECT count(*) INTO v_orders FROM orders WHERE customer_id = p_user_id;
  SELECT count(*) INTO v_sales  FROM orders WHERE created_by = p_user_id;
  SELECT count(*) INTO v_shifts FROM cash_shifts
    WHERE opened_by = p_user_id OR closed_by = p_user_id;
  SELECT count(*) INTO v_movs   FROM account_movements WHERE created_by = p_user_id;
  SELECT count(*), COALESCE(sum(current_debt), 0) INTO v_credits, v_debt
    FROM customer_credits WHERE profile_id = p_user_id;
  SELECT count(*) INTO v_wallet FROM wallet_movements WHERE profile_id = p_user_id;

  RETURN jsonb_build_object(
    'orders', v_orders,
    'sales_created', v_sales,
    'cash_shifts', v_shifts,
    'account_movements', v_movs,
    'credit_accounts', v_credits,
    'credit_debt_cents', round(v_debt * 100)::int,
    'wallet_movements', v_wallet,
    'wallet_points', v_points,
    'blocking_total', v_orders + v_sales + v_shifts + v_movs + v_credits
  );
END;
$$;


ALTER FUNCTION "public"."get_user_relations_summary"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_update_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_update_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_catalog_batch_v2"("p_products" "jsonb", "p_warehouse_id" "uuid", "p_stock_mode" "text", "p_update_prices" boolean, "p_batch_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'extensions', 'auth'
    AS $$
DECLARE
  v_profile_id uuid;
  v_role text;
  v_prev jsonb;
  v_result jsonb;

  v_prod jsonb;
  v_var jsonb;
  v_entry jsonb;

  v_product_id uuid;
  v_variant_id uuid;
  v_brand_id uuid;
  v_category_id uuid;
  v_uses_lots boolean;
  v_name text;
  v_brand_name text;
  v_cat_name text;
  v_sku text;
  v_variant_name text;
  v_is_new_variant boolean;
  v_touched boolean;

  v_attr_id uuid;
  v_attr_value_id uuid;
  v_ing_name text;
  v_ing_id uuid;

  v_qty numeric;
  v_lot text;
  v_expiry date;
  v_unit_cost numeric;
  v_entry_id uuid;
  v_entry_total numeric := 0;
  v_stock_batch_id uuid;
  v_prev_stock numeric;
  v_new_stock numeric;
  v_total_current numeric;
  v_diff numeric;
  v_remaining numeric;
  v_take numeric;
  v_batch_rec record; -- Renombrado para evitar colisión con el alias 'r'

  v_created_products int := 0;
  v_created_variants int := 0;
  v_updated_variants int := 0;
  v_movements int := 0;
BEGIN
  -- Autorización: resolver perfil y rol desde user_roles / roles (alias 'ro')
  SELECT pr.id, COALESCE(ro.name, 'customer') INTO v_profile_id, v_role
  FROM public.profiles pr
  LEFT JOIN public.user_roles ur ON ur.profile_id = pr.id
  LEFT JOIN public.roles ro ON ro.id = ur.role_id
  WHERE pr.auth_user_id = auth.uid()
  ORDER BY CASE WHEN ro.name = 'admin' THEN 1 WHEN ro.name = 'employee' THEN 2 ELSE 3 END
  LIMIT 1;

  IF v_profile_id IS NULL OR v_role NOT IN ('admin', 'employee') THEN
    RAISE EXCEPTION 'Operación rechazada: solo administradores o empleados pueden importar.';
  END IF;

  IF p_stock_mode NOT IN ('add', 'replace') THEN
    RAISE EXCEPTION 'Modo de stock inválido: %', p_stock_mode;
  END IF;
  IF p_batch_id IS NULL OR btrim(p_batch_id) = '' THEN
    RAISE EXCEPTION 'batch_id es obligatorio.';
  END IF;

  -- Idempotencia (con candado para llamadas simultáneas del mismo lote)
  PERFORM pg_advisory_xact_lock(hashtext(p_batch_id));
  SELECT result INTO v_prev FROM import_batches WHERE batch_id = p_batch_id;
  IF FOUND THEN
    RETURN v_prev;
  END IF;

  IF p_warehouse_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM warehouses WHERE id = p_warehouse_id AND is_active
  ) THEN
    RAISE EXCEPTION 'El almacén seleccionado no existe o está inactivo.';
  END IF;

  FOR v_prod IN SELECT * FROM jsonb_array_elements(p_products)
  LOOP
    v_name := btrim(v_prod->>'name');
    v_brand_name := btrim(coalesce(v_prod->>'brand_name', ''));
    v_cat_name := btrim(coalesce(v_prod->>'category_name', ''));
    v_product_id := NULLIF(v_prod->>'product_id', '')::uuid;

    IF v_product_id IS NOT NULL THEN
      -- Producto existente: no se modifica nada de su ficha.
      SELECT uses_batches INTO v_uses_lots FROM products WHERE id = v_product_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto "%" ya no existe.', v_name;
      END IF;
    ELSE
      -- Marca (buscar o crear)
      v_brand_id := NULL;
      IF v_brand_name <> '' THEN
        SELECT id INTO v_brand_id FROM brands
        WHERE import_norm(name) = import_norm(v_brand_name) LIMIT 1;
        IF v_brand_id IS NULL THEN
          INSERT INTO brands (name, created_by) VALUES (v_brand_name, v_profile_id)
          RETURNING id INTO v_brand_id;
        END IF;
      END IF;

      -- ¿Otro proceso ya lo creó? (mismo nombre + marca)
      SELECT id, uses_batches INTO v_product_id, v_uses_lots FROM products
      WHERE import_norm(name) = import_norm(v_name)
        AND brand_id IS NOT DISTINCT FROM v_brand_id
      LIMIT 1;

      IF v_product_id IS NULL THEN
        -- Categoría (buscar o crear)
        v_category_id := NULL;
        IF v_cat_name <> '' THEN
          SELECT id INTO v_category_id FROM categories
          WHERE import_norm(name) = import_norm(v_cat_name) LIMIT 1;
          IF v_category_id IS NULL THEN
            INSERT INTO categories (name, created_by) VALUES (v_cat_name, v_profile_id)
            RETURNING id INTO v_category_id;
          END IF;
        END IF;

        v_uses_lots := COALESCE((v_prod->>'uses_lots')::boolean, false);

        INSERT INTO products (
          name, description, category_id, brand_id, is_active, details,
          product_type, stock_control, uses_batches, created_by
        ) VALUES (
          v_name, NULLIF(btrim(coalesce(v_prod->>'description', '')), ''),
          v_category_id, v_brand_id, true, '{}'::jsonb,
          'good', true, v_uses_lots, v_profile_id
        ) RETURNING id INTO v_product_id;
        v_created_products := v_created_products + 1;

        -- Componentes químicos / principios activos (a nivel de producto)
        FOR v_ing_name IN
          SELECT btrim(x) FROM regexp_split_to_table(coalesce(v_prod->>'components', ''), '[;|,]') AS x
        LOOP
          IF v_ing_name = '' THEN CONTINUE; END IF;
          SELECT id INTO v_ing_id FROM active_ingredients
          WHERE import_norm(name) = import_norm(v_ing_name) LIMIT 1;
          IF v_ing_id IS NULL THEN
            INSERT INTO active_ingredients (name) VALUES (v_ing_name)
            RETURNING id INTO v_ing_id;
          END IF;
          INSERT INTO product_active_ingredients (product_id, ingredient_id)
          VALUES (v_product_id, v_ing_id)
          ON CONFLICT DO NOTHING;
        END LOOP;
      END IF;
    END IF;

    -- ---------------------------- Variantes ----------------------------
    FOR v_var IN SELECT * FROM jsonb_array_elements(v_prod->'variants')
    LOOP
      v_variant_id := NULLIF(v_var->>'variant_id', '')::uuid;
      v_sku := NULLIF(btrim(coalesce(v_var->>'sku', '')), '');
      v_variant_name := btrim(coalesce(v_var->>'variant_name', ''));
      v_is_new_variant := false;
      v_touched := false;

      IF v_variant_id IS NULL AND v_sku IS NOT NULL THEN
        SELECT id INTO v_variant_id FROM product_variants
        WHERE lower(sku) = lower(v_sku) LIMIT 1;
      END IF;

      IF v_variant_id IS NOT NULL THEN
        PERFORM 1 FROM product_variants WHERE id = v_variant_id AND product_id = v_product_id;
        IF NOT FOUND THEN
          RAISE EXCEPTION 'El SKU "%" pertenece a otro producto (fila de "%").', coalesce(v_sku, ''), v_name;
        END IF;
      END IF;

      IF v_variant_id IS NULL THEN
        INSERT INTO product_variants (
          product_id, sku, unit_cost, sale_price, wholesale_price,
          wholesale_min_quantity, is_active, created_by
        ) VALUES (
          v_product_id, v_sku,
          COALESCE((v_var->>'unit_cost')::numeric, 0),
          COALESCE((v_var->>'sale_price')::numeric, 0),
          (v_var->>'wholesale_price')::numeric,
          (v_var->>'wholesale_min_quantity')::integer,
          true, v_profile_id
        ) RETURNING id INTO v_variant_id;
        v_is_new_variant := true;
        v_created_variants := v_created_variants + 1;

        IF v_variant_name <> '' THEN
          SELECT id INTO v_attr_id FROM attributes
          WHERE import_norm(name) = 'variante' LIMIT 1;
          IF v_attr_id IS NULL THEN
            INSERT INTO attributes (name) VALUES ('Variante') RETURNING id INTO v_attr_id;
          END IF;
          SELECT id INTO v_attr_value_id FROM attribute_values
          WHERE attribute_id = v_attr_id AND import_norm(value) = import_norm(v_variant_name)
          LIMIT 1;
          IF v_attr_value_id IS NULL THEN
            INSERT INTO attribute_values (attribute_id, value) VALUES (v_attr_id, v_variant_name)
            RETURNING id INTO v_attr_value_id;
          END IF;
          INSERT INTO variant_attribute_values (variant_id, attribute_value_id)
          VALUES (v_variant_id, v_attr_value_id)
          ON CONFLICT DO NOTHING;
        END IF;

        IF NULLIF(btrim(coalesce(v_var->>'image_url', '')), '') IS NOT NULL THEN
          INSERT INTO product_images (product_id, variant_id, image_url, is_main, display_order)
          VALUES (v_product_id, v_variant_id, btrim(v_var->>'image_url'), true, 0);
        END IF;

      ELSIF p_update_prices THEN
        UPDATE product_variants SET
          unit_cost = COALESCE((v_var->>'unit_cost')::numeric, unit_cost),
          sale_price = COALESCE((v_var->>'sale_price')::numeric, sale_price),
          wholesale_price = COALESCE((v_var->>'wholesale_price')::numeric, wholesale_price),
          wholesale_min_quantity = COALESCE((v_var->>'wholesale_min_quantity')::integer, wholesale_min_quantity),
          updated_by = v_profile_id
        WHERE id = v_variant_id;
        v_touched := true;
      END IF;

      -- ----------------------------- Stock -----------------------------
      IF p_warehouse_id IS NOT NULL
         AND jsonb_array_length(coalesce(v_var->'stock_entries', '[]'::jsonb)) > 0 THEN
        v_touched := true;
        SELECT unit_cost INTO v_unit_cost FROM product_variants WHERE id = v_variant_id;

        FOR v_entry IN SELECT * FROM jsonb_array_elements(v_var->'stock_entries')
        LOOP
          v_qty := COALESCE((v_entry->>'quantity')::numeric, 0);
          IF v_uses_lots THEN
            v_lot := NULLIF(btrim(coalesce(v_entry->>'lot_code', '')), '');
            v_expiry := NULLIF(v_entry->>'expiry_date', '')::date;
            IF v_lot IS NULL THEN CONTINUE; END IF;
          ELSE
            v_lot := 'DEFAULT';
            v_expiry := NULL;
          END IF;

          IF p_stock_mode = 'add' OR v_is_new_variant THEN
            IF v_qty <= 0 THEN CONTINUE; END IF;

            IF v_entry_id IS NULL THEN
              INSERT INTO inventory_entries (
                warehouse_id, notes, created_by, document_type,
                total_amount, payment_mode, status
              ) VALUES (
                p_warehouse_id, 'Importación masiva', v_profile_id, 'NINGUNO',
                0, 'NINGUNO', 'COMPLETED'
              ) RETURNING id INTO v_entry_id;
            END IF;

            INSERT INTO inventory_entry_items (
              entry_id, product_id, variant_id, batch_number, expiry_date, quantity, unit_cost
            ) VALUES (
              v_entry_id, v_product_id, v_variant_id, v_lot, v_expiry, v_qty, v_unit_cost
            );
            v_entry_total := v_entry_total + v_qty * v_unit_cost;

            SELECT id, available_quantity INTO v_stock_batch_id, v_prev_stock
            FROM warehouse_stock_batches
            WHERE variant_id = v_variant_id AND warehouse_id = p_warehouse_id AND batch_number = v_lot
            LIMIT 1 FOR UPDATE;

            IF v_stock_batch_id IS NULL THEN
              v_prev_stock := 0;
              v_new_stock := v_qty;
              INSERT INTO warehouse_stock_batches (
                variant_id, warehouse_id, product_id, batch_number, expiry_date,
                available_quantity, created_by, updated_by
              ) VALUES (
                v_variant_id, p_warehouse_id, v_product_id, v_lot, v_expiry,
                v_new_stock, v_profile_id, v_profile_id
              ) RETURNING id INTO v_stock_batch_id;
            ELSE
              v_new_stock := v_prev_stock + v_qty;
              UPDATE warehouse_stock_batches
              SET available_quantity = v_new_stock, updated_at = now(), updated_by = v_profile_id
              WHERE id = v_stock_batch_id;
            END IF;

            INSERT INTO inventory_movements (
              variant_id, warehouse_id, stock_batch_id, inventory_entry_id, quantity,
              previous_stock, new_stock, unit_cost, total_cost, reason, notes, created_by
            ) VALUES (
              v_variant_id, p_warehouse_id, v_stock_batch_id, v_entry_id, v_qty,
              v_prev_stock, v_new_stock, v_unit_cost, v_qty * v_unit_cost,
              'ENTRY', 'Importación masiva', v_profile_id
            );
            v_movements := v_movements + 1;

          ELSIF v_uses_lots THEN
            SELECT id, available_quantity INTO v_stock_batch_id, v_prev_stock
            FROM warehouse_stock_batches
            WHERE variant_id = v_variant_id AND warehouse_id = p_warehouse_id AND batch_number = v_lot
            LIMIT 1 FOR UPDATE;

            IF v_stock_batch_id IS NULL THEN
              IF v_qty > 0 THEN
                INSERT INTO warehouse_stock_batches (
                  variant_id, warehouse_id, product_id, batch_number, expiry_date,
                  available_quantity, created_by, updated_by
                ) VALUES (
                  v_variant_id, p_warehouse_id, v_product_id, v_lot, v_expiry,
                  v_qty, v_profile_id, v_profile_id
                ) RETURNING id INTO v_stock_batch_id;
                INSERT INTO inventory_movements (
                  variant_id, warehouse_id, stock_batch_id, quantity, previous_stock, new_stock,
                  unit_cost, total_cost, reason, notes, created_by
                ) VALUES (
                  v_variant_id, p_warehouse_id, v_stock_batch_id, v_qty, 0, v_qty,
                  v_unit_cost, v_qty * v_unit_cost, 'ADJUSTMENT',
                  'Importación masiva (reemplazo de stock)', v_profile_id
                );
                v_movements := v_movements + 1;
              END IF;
            ELSIF v_prev_stock <> v_qty THEN
              UPDATE warehouse_stock_batches
              SET available_quantity = v_qty, updated_at = now(), updated_by = v_profile_id
              WHERE id = v_stock_batch_id;
              INSERT INTO inventory_movements (
                variant_id, warehouse_id, stock_batch_id, quantity, previous_stock, new_stock,
                unit_cost, total_cost, reason, notes, created_by
              ) VALUES (
                v_variant_id, p_warehouse_id, v_stock_batch_id, v_qty - v_prev_stock,
                v_prev_stock, v_qty, v_unit_cost, abs(v_qty - v_prev_stock) * v_unit_cost,
                'ADJUSTMENT', 'Importación masiva (reemplazo de stock)', v_profile_id
              );
              v_movements := v_movements + 1;
            END IF;

          ELSE
            SELECT COALESCE(SUM(available_quantity), 0) INTO v_total_current
            FROM warehouse_stock_batches
            WHERE variant_id = v_variant_id AND warehouse_id = p_warehouse_id;
            v_diff := v_qty - v_total_current;

            IF v_diff > 0 THEN
              SELECT id, available_quantity INTO v_stock_batch_id, v_prev_stock
              FROM warehouse_stock_batches
              WHERE variant_id = v_variant_id AND warehouse_id = p_warehouse_id AND batch_number = 'DEFAULT'
              LIMIT 1 FOR UPDATE;

              IF v_stock_batch_id IS NULL THEN
                v_prev_stock := 0;
                INSERT INTO warehouse_stock_batches (
                  variant_id, warehouse_id, product_id, batch_number,
                  available_quantity, created_by, updated_by
                ) VALUES (
                  v_variant_id, p_warehouse_id, v_product_id, 'DEFAULT',
                  v_diff, v_profile_id, v_profile_id
                ) RETURNING id INTO v_stock_batch_id;
              ELSE
                UPDATE warehouse_stock_batches
                SET available_quantity = v_prev_stock + v_diff, updated_at = now(), updated_by = v_profile_id
                WHERE id = v_stock_batch_id;
              END IF;

              INSERT INTO inventory_movements (
                variant_id, warehouse_id, stock_batch_id, quantity, previous_stock, new_stock,
                unit_cost, total_cost, reason, notes, created_by
              ) VALUES (
                v_variant_id, p_warehouse_id, v_stock_batch_id, v_diff, v_prev_stock,
                v_prev_stock + v_diff, v_unit_cost, v_diff * v_unit_cost,
                'ADJUSTMENT', 'Importación masiva (reemplazo de stock)', v_profile_id
              );
              v_movements := v_movements + 1;

            ELSIF v_diff < 0 THEN
              v_remaining := -v_diff;
              FOR v_batch_rec IN
                SELECT id, available_quantity FROM warehouse_stock_batches
                WHERE variant_id = v_variant_id AND warehouse_id = p_warehouse_id
                  AND available_quantity > 0
                ORDER BY expiry_date NULLS LAST, created_at
                FOR UPDATE
              LOOP
                EXIT WHEN v_remaining <= 0;
                v_take := LEAST(v_batch_rec.available_quantity, v_remaining);
                UPDATE warehouse_stock_batches
                SET available_quantity = v_batch_rec.available_quantity - v_take,
                    updated_at = now(), updated_by = v_profile_id
                WHERE id = v_batch_rec.id;
                INSERT INTO inventory_movements (
                  variant_id, warehouse_id, stock_batch_id, quantity, previous_stock, new_stock,
                  unit_cost, total_cost, reason, notes, created_by
                ) VALUES (
                  v_variant_id, p_warehouse_id, v_batch_rec.id, -v_take, v_batch_rec.available_quantity,
                  v_batch_rec.available_quantity - v_take, v_unit_cost, v_take * v_unit_cost,
                  'ADJUSTMENT', 'Importación masiva (reemplazo de stock)', v_profile_id
                );
                v_movements := v_movements + 1;
                v_remaining := v_remaining - v_take;
              END LOOP;
            END IF;
          END IF;
        END LOOP;
      END IF;

      IF v_touched AND NOT v_is_new_variant THEN
        v_updated_variants := v_updated_variants + 1;
      END IF;
    END LOOP;
  END LOOP;

  IF v_entry_id IS NOT NULL THEN
    UPDATE inventory_entries SET total_amount = v_entry_total WHERE id = v_entry_id;
  END IF;

  v_result := jsonb_build_object(
    'created_products', v_created_products,
    'created_variants', v_created_variants,
    'updated_variants', v_updated_variants,
    'stock_movements', v_movements
  );

  INSERT INTO import_batches (batch_id, result, created_by)
  VALUES (p_batch_id, v_result, v_profile_id);

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."import_catalog_batch_v2"("p_products" "jsonb", "p_warehouse_id" "uuid", "p_stock_mode" "text", "p_update_prices" boolean, "p_batch_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_norm"("t" "text") RETURNS "text"
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'extensions'
    AS $$
  SELECT lower(unaccent(regexp_replace(btrim(coalesce(t, '')), '\s+', ' ', 'g')))
$$;


ALTER FUNCTION "public"."import_norm"("t" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    JOIN public.profiles p ON p.id = ur.profile_id
    WHERE p.auth_user_id = auth.uid() 
      AND r.name = 'admin'
  );
END;
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_customer_checkout"("p_customer_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb", "p_use_points" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_order_id UUID;
  v_item RECORD;
  v_variant_record RECORD;
  v_stock INT;
  v_total_amount NUMERIC := 0;
  v_total_cost NUMERIC := 0;
  v_total_profit NUMERIC := 0;
  v_points_used INT := 0;
  v_points_earned INT := 0;
  v_points_to_soles_ratio NUMERIC := 0.01;
  v_earning_rate NUMERIC := 1.0;
  v_customer_balance INT := 0;
  v_max_discount NUMERIC := 0;
  v_item_price NUMERIC;
  v_item_wholesale NUMERIC;
  v_item_cost NUMERIC;
BEGIN
  -- 1. Obtener configuraciones globales (Evitar manipulación desde el cliente)
  SELECT COALESCE((SELECT value::numeric FROM app_settings WHERE key = 'points_to_soles_ratio'), 0.01) INTO v_points_to_soles_ratio;
  SELECT COALESCE((SELECT value::numeric FROM app_settings WHERE key = 'loyalty_earning_rate'), 1.0) INTO v_earning_rate;

  -- 2. Validar stock atómicamente y calcular totales
  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id UUID, variant_id UUID, quantity INT)
  LOOP
    SELECT total_stock INTO v_stock
    FROM product_stock_summary
    WHERE variant_id = v_item.variant_id
    FOR UPDATE;

    IF v_stock IS NULL OR v_stock < v_item.quantity THEN
      RAISE EXCEPTION 'Stock insuficiente para la variante %', v_item.variant_id;
    END IF;

    SELECT sale_price, wholesale_price, unit_cost INTO v_variant_record
    FROM product_variants
    WHERE id = v_item.variant_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variante no encontrada: %', v_item.variant_id;
    END IF;

    v_item_price := v_variant_record.sale_price;
    v_item_wholesale := COALESCE(v_variant_record.wholesale_price, v_item_price);
    v_item_cost := v_variant_record.unit_cost;

    v_total_amount := v_total_amount + (v_item_price * v_item.quantity);
    v_total_cost := v_total_cost + (v_item_cost * v_item.quantity);
    
    IF v_item_price > v_item_wholesale THEN
      v_max_discount := v_max_discount + ((v_item_price - v_item_wholesale) * v_item.quantity);
    END IF;
  END LOOP;

  -- 3. Calcular Descuentos y Puntos
  IF p_use_points AND p_customer_id IS NOT NULL THEN
    SELECT wallet_balance INTO v_customer_balance
    FROM profiles
    WHERE id = p_customer_id
    FOR UPDATE;

    DECLARE
      v_needed_points INT;
    BEGIN
      v_needed_points := CEIL(v_max_discount / v_points_to_soles_ratio);
      
      IF v_customer_balance >= v_needed_points THEN
        v_points_used := v_needed_points;
      ELSE
        v_points_used := v_customer_balance;
      END IF;
    END;
    
    v_total_amount := v_total_amount - (v_points_used * v_points_to_soles_ratio);
    
    IF v_points_used > 0 THEN
      UPDATE profiles
      SET wallet_balance = wallet_balance - v_points_used
      WHERE id = p_customer_id;
      
      INSERT INTO wallet_movements (profile_id, movement_type, points, description, created_at)
      VALUES (p_customer_id, 'PURCHASE_DISCOUNT', -v_points_used, 'Descuento aplicado en compra', NOW());
    END IF;
  END IF;

  v_total_profit := v_total_amount - v_total_cost;

  IF v_earning_rate > 0 AND p_customer_id IS NOT NULL THEN
    v_points_earned := FLOOR(v_total_amount / v_earning_rate);
  END IF;

  -- 4. Insertar la Orden
  INSERT INTO orders (
    customer_id, created_by, warehouse_id, 
    total_amount, total_profit, discount_amount,
    points_used, points_earned,
    status, payment_status, payment_method, 
    created_at
  ) VALUES (
    p_customer_id, p_customer_id, p_warehouse_id,
    v_total_amount, v_total_profit, (v_points_used * v_points_to_soles_ratio),
    v_points_used, v_points_earned,
    'PENDING', 'PENDING', 'POR ACORDAR',
    NOW()
  ) RETURNING id INTO v_order_id;

  -- 5. Insertar Ítems
  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id UUID, variant_id UUID, quantity INT)
  LOOP
    SELECT sale_price, wholesale_price, unit_cost INTO v_variant_record
    FROM product_variants
    WHERE id = v_item.variant_id;

    v_item_price := v_variant_record.sale_price;
    v_item_cost := v_variant_record.unit_cost;

    INSERT INTO order_items (
      order_id, product_id, variant_id, quantity,
      unit_cost, applied_price, net_profit
    ) VALUES (
      v_order_id, v_item.product_id, v_item.variant_id, v_item.quantity,
      v_item_cost, v_item_price, (v_item_price - v_item_cost) * v_item.quantity
    );
  END LOOP;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'total_amount', v_total_amount,
    'points_used', v_points_used
  );
END;
$$;


ALTER FUNCTION "public"."process_customer_checkout"("p_customer_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb", "p_use_points" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_inventory_entry_rpc"("p_warehouse_id" "uuid", "p_supplier_id" "uuid", "p_purchase_order_id" "uuid", "p_payment_mode" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_document_type" "text", "p_document_number" "text", "p_document_date" "date", "p_notes" "text", "p_items" "jsonb", "p_profile_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_entry_id UUID;
  v_total_amount DECIMAL(12, 2) := 0;
  v_account_type TEXT;
  v_current_balance DECIMAL(12, 2);
  v_stock_batch_id UUID;
  v_previous_stock DECIMAL(12, 2);
  v_new_stock DECIMAL(12, 2);
  v_supplier_credit_id UUID;
  v_current_debt DECIMAL(12, 2);
  v_supplier_name TEXT;
  item JSONB;
  v_item_qty DECIMAL(12, 2);
  v_item_cost DECIMAL(12, 2);
  v_item_subtotal DECIMAL(12, 2);
  v_user_id UUID;
  v_movement_id UUID; -- Variable tipada UUID para evitar conflicto con JSONB
BEGIN
  -- 0. RESOLVER EL ID DE PERFIL DEL USUARIO
  v_user_id := p_profile_id;
  IF v_user_id IS NULL THEN
     SELECT id INTO v_user_id
       FROM public.profiles
      WHERE auth_user_id = auth.uid() OR id = auth.uid()
      LIMIT 1;
  END IF;

  -- Fallback de seguridad si v_user_id sigue siendo null
  IF v_user_id IS NULL THEN
     v_user_id := auth.uid();
  END IF;

  -- 1. Calcular el monto total del ingreso
  FOR item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_total_amount := v_total_amount + ((item->>'quantity')::DECIMAL * (item->>'unitCost')::DECIMAL);
  END LOOP;

  -- 2. Validaciones Financieras y Débitos (SOLO si no viene de una orden de compra)
  IF p_purchase_order_id IS NULL THEN
    
    -- Pago al CONTADO
    IF p_payment_mode = 'CONTADO' THEN
      IF p_account_id IS NULL THEN
        RAISE EXCEPTION 'Debe proporcionar una cuenta para pagos al contado.';
      END IF;

      -- Bloqueo FOR UPDATE para consistencia de saldo
      SELECT type, balance INTO v_account_type, v_current_balance
      FROM public.financial_accounts
      WHERE id = p_account_id
      FOR UPDATE;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'La cuenta financiera no existe.';
      END IF;

      IF v_current_balance < v_total_amount THEN
        RAISE EXCEPTION 'Saldo insuficiente en la cuenta financiera.';
      END IF;

      -- VALIDACIÓN ATÓMICA DE TURNO
      IF v_account_type = 'CAJA' THEN
        SELECT id INTO p_active_shift_id
        FROM public.cash_shifts
        WHERE account_id = p_account_id AND status = 'OPEN'
        FOR UPDATE;
        
        IF NOT FOUND THEN
          RAISE EXCEPTION 'La caja seleccionada no tiene un turno abierto para realizar el pago al contado.';
        END IF;
      ELSE
        p_active_shift_id := NULL;
      END IF;

      -- Actualizar Saldo
      UPDATE public.financial_accounts
      SET balance = balance - v_total_amount,
          updated_at = NOW()
      WHERE id = p_account_id;

      -- Glosa de proveedor
      v_supplier_name := '';
      IF p_supplier_id IS NOT NULL THEN
         SELECT name INTO v_supplier_name FROM public.suppliers WHERE id = p_supplier_id;
      END IF;

      -- Registrar movimiento contable
      INSERT INTO public.account_movements (
        account_id, shift_id, movement_type, amount, description, reference_type, reference_id, created_by
      ) VALUES (
        p_account_id, p_active_shift_id, 'EXPENSE', v_total_amount, 
        'Compra de inventario' || CASE WHEN v_supplier_name != '' THEN ' · ' || v_supplier_name ELSE '' END,
        'inventory_entry', NULL, v_user_id
      ) RETURNING id INTO v_movement_id;

    -- Pago a CRÉDITO
    ELSIF p_payment_mode = 'CRÉDITO' THEN
      IF p_supplier_id IS NULL THEN
        RAISE EXCEPTION 'Debe seleccionar un proveedor para compras a crédito.';
      END IF;

      SELECT id, current_debt INTO v_supplier_credit_id, v_current_debt
      FROM public.supplier_credits
      WHERE supplier_id = p_supplier_id
      FOR UPDATE;

      IF v_supplier_credit_id IS NULL THEN
        INSERT INTO public.supplier_credits (supplier_id, current_debt, created_by)
        VALUES (p_supplier_id, v_total_amount, v_user_id)
        RETURNING id INTO v_supplier_credit_id;
      ELSE
        UPDATE public.supplier_credits
        SET current_debt = current_debt + v_total_amount,
            updated_at = NOW()
        WHERE id = v_supplier_credit_id;
      END IF;
    END IF;
  END IF;

  -- 3. Crear Registro Cabecera (inventory_entries)
  INSERT INTO public.inventory_entries (
    warehouse_id, supplier_id, purchase_order_id, payment_mode, 
    account_id, shift_id, document_type, document_number, document_date, 
    total_amount, notes, status, created_by
  ) VALUES (
    p_warehouse_id, p_supplier_id, p_purchase_order_id, p_payment_mode,
    p_account_id, p_active_shift_id, p_document_type, p_document_number, p_document_date,
    v_total_amount, p_notes, 'COMPLETED', v_user_id
  ) RETURNING id INTO v_entry_id;

  -- 3.1 Actualizar el movimiento contable unívocamente por su ID primario
  IF p_purchase_order_id IS NULL AND p_payment_mode = 'CONTADO' AND v_movement_id IS NOT NULL THEN
      UPDATE public.account_movements 
      SET reference_id = v_entry_id 
      WHERE id = v_movement_id;
  END IF;

  IF p_purchase_order_id IS NULL AND p_payment_mode = 'CRÉDITO' THEN
      INSERT INTO public.supplier_credit_movements (
          supplier_credit_id, movement_type, amount, notes, created_by
      ) VALUES (
          v_supplier_credit_id, 'CHARGE', v_total_amount, 'Compra a crédito — Entrada #' || v_entry_id, v_user_id
      );
  END IF;

  -- 4. Procesar Items: inventory_entry_items, Kárdex, Batches
  FOR item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_item_qty := (item->>'quantity')::DECIMAL;
    v_item_cost := (item->>'unitCost')::DECIMAL;
    v_item_subtotal := v_item_qty * v_item_cost;

    -- Insertar item
    INSERT INTO public.inventory_entry_items (
      entry_id, product_id, variant_id, batch_number, expiry_date, quantity, unit_cost
    ) VALUES (
      v_entry_id, 
      (item->>'productId')::UUID, 
      (item->>'variantId')::UUID, 
      item->>'batchNumber', 
      (item->>'expiryDate')::DATE,
      v_item_qty, 
      v_item_cost
    );

    -- Actualizar o Crear Batch de Stock
    SELECT id, available_quantity INTO v_stock_batch_id, v_previous_stock
    FROM public.warehouse_stock_batches
    WHERE variant_id = (item->>'variantId')::UUID 
      AND warehouse_id = p_warehouse_id 
      AND batch_number = (item->>'batchNumber')
    FOR UPDATE;

    IF v_stock_batch_id IS NOT NULL THEN
      v_new_stock := v_previous_stock + v_item_qty;
      UPDATE public.warehouse_stock_batches
      SET available_quantity = v_new_stock,
          updated_at = NOW(),
          updated_by = v_user_id
      WHERE id = v_stock_batch_id;
    ELSE
      v_previous_stock := 0;
      v_new_stock := v_item_qty;
      
      INSERT INTO public.warehouse_stock_batches (
        variant_id, warehouse_id, product_id, supplier_id, batch_number, expiry_date,
        available_quantity, created_by, updated_by
      ) VALUES (
        (item->>'variantId')::UUID, p_warehouse_id, (item->>'productId')::UUID, p_supplier_id,
        item->>'batchNumber', (item->>'expiryDate')::DATE, v_new_stock, v_user_id, v_user_id
      ) RETURNING id INTO v_stock_batch_id;
    END IF;

    -- Actualizar Costo Unitario de la Variante
    UPDATE public.product_variants
    SET unit_cost = v_item_cost,
        updated_by = v_user_id
    WHERE id = (item->>'variantId')::UUID;

    -- Registrar Movimiento en Kárdex (inventory_movements)
    INSERT INTO public.inventory_movements (
      variant_id, warehouse_id, stock_batch_id, inventory_entry_id, quantity,
      previous_stock, new_stock, unit_cost, total_cost, reason, notes, created_by
    ) VALUES (
      (item->>'variantId')::UUID, p_warehouse_id, v_stock_batch_id, v_entry_id, v_item_qty,
      v_previous_stock, v_new_stock, v_item_cost, v_item_subtotal, 'ENTRY', p_notes, v_user_id
    );

  END LOOP;

  -- 5. Sincronizar Orden de Compra si existe
  IF p_purchase_order_id IS NOT NULL THEN
    PERFORM public.sync_purchase_order_reception_rpc(p_purchase_order_id);
  END IF;

  RETURN v_entry_id;
END;
$$;


ALTER FUNCTION "public"."process_inventory_entry_rpc"("p_warehouse_id" "uuid", "p_supplier_id" "uuid", "p_purchase_order_id" "uuid", "p_payment_mode" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_document_type" "text", "p_document_number" "text", "p_document_date" "date", "p_notes" "text", "p_items" "jsonb", "p_profile_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_inventory_exit_rpc"("p_warehouse_id" "uuid", "p_reason" "text", "p_notes" "text", "p_items" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_exit_id UUID;
  v_stock_batch_id UUID;
  v_previous_stock DECIMAL(12, 2);
  v_new_stock DECIMAL(12, 2);
  item JSONB;
  v_item_qty DECIMAL(12, 2);
  v_item_unit_cost DECIMAL(12, 2);
  v_item_total_cost DECIMAL(12, 2);
  v_user_id UUID;
BEGIN
  -- Obtener el ID del usuario actual (si se llama desde cliente autenticado)
  v_user_id := auth.uid();

  -- 1. Crear Registro Cabecera (inventory_exits)
  INSERT INTO public.inventory_exits (
    warehouse_id, reason, notes, created_by
  ) VALUES (
    p_warehouse_id, p_reason, p_notes, v_user_id
  ) RETURNING id INTO v_exit_id;

  -- 2. Procesar Items: inventory_exit_items, Kárdex, Batches
  FOR item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_item_qty := (item->>'quantity')::DECIMAL;
    v_item_unit_cost := (item->>'unit_cost')::DECIMAL;
    v_item_total_cost := (item->>'total_cost')::DECIMAL;

    -- Validar y Bloquear el Lote (SELECT FOR UPDATE)
    SELECT id, available_quantity INTO v_stock_batch_id, v_previous_stock
    FROM public.warehouse_stock_batches
    WHERE id = (item->>'batch_id')::UUID 
    FOR UPDATE;

    IF v_stock_batch_id IS NULL THEN
       RAISE EXCEPTION 'El lote % no existe en la base de datos.', item->>'batch_number';
    END IF;

    v_new_stock := v_previous_stock - v_item_qty;

    IF v_new_stock < 0 THEN
       RAISE EXCEPTION 'Stock insuficiente para % (Lote: %). Disponible: %', 
          item->>'product_name', item->>'batch_number', v_previous_stock;
    END IF;

    -- Insertar Detalle de Salida
    INSERT INTO public.inventory_exit_items (
      exit_id, product_id, variant_id, batch_number, quantity, unit_cost
    ) VALUES (
      v_exit_id, 
      (item->>'product_id')::UUID, 
      (item->>'variant_id')::UUID, 
      item->>'batch_number', 
      v_item_qty, 
      v_item_unit_cost
    );

    -- Actualizar Batch de Stock
    UPDATE public.warehouse_stock_batches
    SET available_quantity = v_new_stock,
        updated_at = NOW(),
        updated_by = v_user_id
    WHERE id = v_stock_batch_id;

    -- Registrar Movimiento en Kárdex (inventory_movements)
    INSERT INTO public.inventory_movements (
      variant_id, warehouse_id, stock_batch_id, inventory_exit_id, quantity,
      previous_stock, new_stock, unit_cost, total_cost, reason, notes, created_by
    ) VALUES (
      (item->>'variant_id')::UUID, p_warehouse_id, v_stock_batch_id, v_exit_id, -v_item_qty,
      v_previous_stock, v_new_stock, v_item_unit_cost, v_item_total_cost, 'EXIT', 'Salida por: ' || p_reason, v_user_id
    );

  END LOOP;

  RETURN v_exit_id;
END;
$$;


ALTER FUNCTION "public"."process_inventory_exit_rpc"("p_warehouse_id" "uuid", "p_reason" "text", "p_notes" "text", "p_items" "jsonb") OWNER TO "postgres";


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


ALTER FUNCTION "public"."process_pos_sale"("payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."protect_system_roles"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Impedir eliminar roles del sistema
  IF TG_OP = 'DELETE' THEN
    IF LOWER(OLD.name) IN ('admin', 'administrador', 'cashier', 'cajero', 'warehouse_keeper', 'almacenero', 'employee', 'empleado', 'customer', 'cliente') THEN
      RAISE EXCEPTION 'Operación denegada: No está permitido eliminar los roles base del sistema (%).', OLD.name;
    END IF;
    RETURN OLD;
  END IF;

  -- Impedir cambiar el identificador 'name' de roles del sistema
  IF TG_OP = 'UPDATE' THEN
    IF LOWER(OLD.name) IN ('admin', 'administrador', 'cashier', 'cajero', 'warehouse_keeper', 'almacenero', 'employee', 'empleado', 'customer', 'cliente') 
       AND LOWER(NEW.name) <> LOWER(OLD.name) THEN
      RAISE EXCEPTION 'Operación denegada: No está permitido renombrar el identificador de los roles base del sistema (%).', OLD.name;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."protect_system_roles"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reconcile_balances_report"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."reconcile_balances_report"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_credit_payment_rpc"("p_customer_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid" DEFAULT NULL::"uuid", "p_notes" "text" DEFAULT 'Abono registrado a crédito'::"text", "p_shift_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
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
    v_current_wallet   INT;
    v_now              TIMESTAMPTZ;
    v_created_by       UUID;
BEGIN
    v_now := NOW() AT TIME ZONE 'America/Lima';

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser mayor a 0.';
    END IF;

    -- 0. RESOLVER EL ID DE PERFIL DEL USUARIO AUTENTICADO (Para evitar error de foreign key en account_movements)
    SELECT id INTO v_created_by
      FROM public.profiles
     WHERE auth_user_id = auth.uid() OR id = auth.uid()
     LIMIT 1;

    -- 1. BLINDAJE DE CAJA Y TURNOS
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

    -- 2. BLINDAJE CON FOR UPDATE Y ASIGNACIÓN A ÓRDENES
    FOR v_order IN
        SELECT id, total_amount, amount_paid, payment_status
          FROM public.orders
         WHERE customer_id = p_customer_id
           AND (p_order_id IS NULL OR id = p_order_id)
           AND payment_status IN ('PENDING', 'PARTIAL')
           AND status = 'COMPLETED'
         ORDER BY created_at ASC
         FOR UPDATE -- Bloqueo transaccional para concurrencia
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

        -- Actualizar orden
        UPDATE public.orders
           SET amount_paid   = v_new_paid,
               payment_status = v_new_status,
               points_earned  = CASE WHEN v_points_earned > 0 THEN v_points_earned ELSE points_earned END,
               updated_at    = v_now
         WHERE id = v_order.id;

        -- Movimiento de crédito
        IF v_to_apply > 0 AND p_credit_id IS NOT NULL THEN
            INSERT INTO public.customer_credit_movements (
                customer_credit_id,
                order_id,
                movement_type,
                amount,
                payment_method,
                notes,
                created_by,
                created_at
            ) VALUES (
                p_credit_id,
                v_order.id,
                'PAYMENT',
                v_to_apply,
                v_account.name,
                p_notes,
                v_created_by,
                v_now
            );
        END IF;

        -- Movimiento de caja/banco (Usando v_created_by para respetar account_movements_created_by_fkey)
        IF v_to_apply > 0 THEN
            INSERT INTO public.account_movements (
                account_id,
                movement_type,
                amount,
                description,
                reference_type,
                reference_id,
                shift_id,
                created_by,
                created_at
            ) VALUES (
                p_account_id,
                'INCOME',
                v_to_apply,
                'Cobro de crédito — Pedido #' || UPPER(SUBSTRING(v_order.id::text, 1, 8)),
                'orders',
                v_order.id,
                p_shift_id,
                v_created_by,
                v_now
            );

            UPDATE public.financial_accounts
               SET balance = balance + v_to_apply
             WHERE id = p_account_id;
        END IF;

        -- Monedas de lealtad
        IF v_points_earned > 0 THEN
            SELECT COALESCE(wallet_balance, 0)
              INTO v_current_wallet
              FROM public.profiles
             WHERE id = p_customer_id
             FOR UPDATE;
             
            UPDATE public.profiles
               SET wallet_balance = v_current_wallet + v_points_earned
             WHERE id = p_customer_id;

            INSERT INTO public.wallet_movements (
                profile_id,
                order_id,
                points,
                movement_type,
                description,
                created_at
            ) VALUES (
                p_customer_id,
                v_order.id,
                v_points_earned,
                'EARNED',
                'Monedas ganadas al saldar pedido a crédito',
                v_now
            );
        END IF;
    END LOOP;

    -- Si queda remanente no ligado a una orden (abono a cuenta global o deuda general)
    IF v_remaining > 0 THEN
        INSERT INTO public.account_movements (
            account_id,
            movement_type,
            amount,
            description,
            reference_type,
            reference_id,
            shift_id,
            created_by,
            created_at
        ) VALUES (
            p_account_id,
            'INCOME',
            v_remaining,
            COALESCE(p_notes, 'Abono registrado a cuenta de crédito'),
            'customer_credits',
            p_credit_id,
            p_shift_id,
            v_created_by,
            v_now
        );

        UPDATE public.financial_accounts
           SET balance = balance + v_remaining
         WHERE id = p_account_id;

        IF p_credit_id IS NOT NULL THEN
            INSERT INTO public.customer_credit_movements (
                customer_credit_id,
                order_id,
                movement_type,
                amount,
                payment_method,
                notes,
                created_by,
                created_at
            ) VALUES (
                p_credit_id,
                NULL,
                'PAYMENT',
                v_remaining,
                v_account.name,
                p_notes,
                v_created_by,
                v_now
            );
        END IF;
    END IF;

    -- 3. BLINDAJE DE DEUDA TOTAL (CUSTOMER CREDITS)
    IF p_credit_id IS NOT NULL THEN
        SELECT current_debt
          INTO v_current_debt
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
        'success',      true,
        'amount_paid',  p_amount
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error',   SQLERRM,
            'detail',  SQLSTATE
        );
END;
$$;


ALTER FUNCTION "public"."register_credit_payment_rpc"("p_customer_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_financial_movement"("p_account_id" "uuid", "p_movement_type" "text", "p_amount" numeric, "p_description" "text", "p_reference_type" "text", "p_reference_id" "uuid", "p_created_by" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_account_type TEXT;
    v_shift_id UUID;
    v_current_balance NUMERIC;
BEGIN
    -- 1. Obtener el tipo de cuenta y bloquear la fila para evitar concurrencia
    SELECT type, balance INTO v_account_type, v_current_balance
    FROM financial_accounts
    WHERE id = p_account_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuenta financiera no encontrada.';
    END IF;

    -- 2. Validar Turno de Caja si la cuenta es de tipo CAJA
    IF v_account_type = 'CAJA' THEN
        SELECT id INTO v_shift_id
        FROM cash_shifts
        WHERE account_id = p_account_id AND status = 'OPEN'
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'No hay un turno de caja abierto para procesar este movimiento.';
        END IF;
    END IF;

    -- 3. Insertar el movimiento
    INSERT INTO account_movements (
        account_id,
        movement_type,
        amount,
        description,
        reference_type,
        reference_id,
        shift_id,
        created_by
    ) VALUES (
        p_account_id,
        p_movement_type,
        p_amount,
        p_description,
        p_reference_type,
        p_reference_id,
        v_shift_id, -- será NULL si no es CAJA
        p_created_by
    );

    -- 4. Actualizar el saldo (Balance)
    IF p_movement_type = 'INCOME' THEN
        v_current_balance := v_current_balance + p_amount;
    ELSIF p_movement_type = 'EXPENSE' THEN
        v_current_balance := v_current_balance - p_amount;
    END IF;

    UPDATE financial_accounts
    SET balance = v_current_balance
    WHERE id = p_account_id;

END;
$$;


ALTER FUNCTION "public"."register_financial_movement"("p_account_id" "uuid", "p_movement_type" "text", "p_amount" numeric, "p_description" "text", "p_reference_type" "text", "p_reference_id" "uuid", "p_created_by" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_supplier_credit_payment_rpc"("p_supplier_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid" DEFAULT NULL::"uuid", "p_notes" "text" DEFAULT 'Pago a proveedor registrado'::"text", "p_shift_id" "uuid" DEFAULT NULL::"uuid", "p_profile_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_remaining        NUMERIC := p_amount;
    v_order            RECORD;
    v_pending_of_order NUMERIC;
    v_to_apply         NUMERIC;
    v_new_paid         NUMERIC;
    v_new_status       TEXT;
    v_account_name     TEXT;
    v_current_debt     NUMERIC;
    v_now              TIMESTAMPTZ := NOW();
    v_real_profile_id  UUID;
    v_credit_id        UUID := p_credit_id;
BEGIN
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'El monto debe ser mayor a 0.');
    END IF;

    IF p_profile_id IS NOT NULL THEN
        SELECT id INTO v_real_profile_id
          FROM public.profiles
         WHERE auth_user_id = p_profile_id OR id = p_profile_id
         LIMIT 1;
    END IF;

    IF v_credit_id IS NULL AND p_supplier_id IS NOT NULL THEN
        SELECT id INTO v_credit_id
          FROM public.supplier_credits
         WHERE supplier_id = p_supplier_id
         LIMIT 1;
    END IF;

    SELECT name INTO v_account_name
      FROM public.financial_accounts
     WHERE id = p_account_id;
    IF v_account_name IS NULL THEN
        v_account_name := 'EFECTIVO';
    END IF;

    IF v_credit_id IS NOT NULL THEN
        INSERT INTO public.supplier_credit_movements (
            supplier_credit_id, purchase_order_id, movement_type,
            amount, payment_method, notes, created_by, created_at
        ) VALUES (
            v_credit_id, p_order_id, 'PAYMENT',
            p_amount, v_account_name, p_notes, v_real_profile_id, v_now
        );
    END IF;

    FOR v_order IN
        SELECT id, total_amount, amount_paid, payment_status, status
          FROM public.purchase_orders
         WHERE supplier_id = p_supplier_id
           AND (p_order_id IS NULL OR id = p_order_id)
           AND payment_status IN ('PENDING', 'PARTIAL')
         ORDER BY created_at ASC
    LOOP
        EXIT WHEN v_remaining <= 0;

        v_pending_of_order := GREATEST(0, v_order.total_amount - v_order.amount_paid);
        v_to_apply         := LEAST(v_remaining, v_pending_of_order);
        v_new_paid         := v_order.amount_paid + v_to_apply;
        v_remaining        := v_remaining - v_to_apply;

        v_new_status := CASE WHEN v_new_paid >= v_order.total_amount THEN 'PAID' ELSE 'PARTIAL' END;

        UPDATE public.purchase_orders
           SET amount_paid    = v_new_paid,
               payment_status = v_new_status,
               status         = CASE WHEN status = 'PENDING' THEN 'SENT' ELSE status END,
               updated_at     = v_now
         WHERE id = v_order.id;

        -- 👇 Movimiento de caja individual por orden, con vínculo trazable
        IF p_account_id IS NOT NULL AND v_to_apply > 0 THEN
            INSERT INTO public.account_movements (
                account_id, movement_type, amount, description,
                reference_type, reference_id, shift_id,
                created_by, created_at
            ) VALUES (
                p_account_id, 'EXPENSE', v_to_apply,
                'Pago a proveedor — Orden #' || UPPER(SUBSTRING(v_order.id::text, 1, 8)),
                'purchase_orders', v_order.id, p_shift_id,
                v_real_profile_id, v_now
            );
        END IF;
    END LOOP;

    IF v_credit_id IS NOT NULL THEN
        SELECT current_debt INTO v_current_debt
          FROM public.supplier_credits WHERE id = v_credit_id;

        IF v_current_debt IS NOT NULL THEN
            UPDATE public.supplier_credits
               SET current_debt = GREATEST(0, v_current_debt - p_amount),
                   updated_at   = v_now
             WHERE id = v_credit_id;
        END IF;
    END IF;

    IF p_account_id IS NOT NULL THEN
        UPDATE public.financial_accounts
           SET balance    = balance - p_amount,
               updated_at = v_now
         WHERE id = p_account_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'amount_paid', p_amount);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;


ALTER FUNCTION "public"."register_supplier_credit_payment_rpc"("p_supplier_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid", "p_profile_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_adjust_financial_account_balance"("p_account_id" "uuid", "p_new_balance" numeric, "p_reason" "text" DEFAULT 'Ajuste manual de saldo desde formulario'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_old_balance NUMERIC;
  v_difference NUMERIC;
  v_movement_type TEXT;
  v_profile_id UUID;
BEGIN
  -- 1. Bloqueo pesimista para prevenir mutaciones concurrentes
  SELECT balance INTO v_old_balance 
  FROM financial_accounts 
  WHERE id = p_account_id 
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cuenta financiera no encontrada: %', p_account_id;
  END IF;

  v_difference := p_new_balance - v_old_balance;

  -- Si no hay variación numérica, no genera movimiento innecesario
  IF v_difference = 0 THEN
    RETURN jsonb_build_object(
      'success', true, 
      'message', 'El saldo actual coincide con el valor indicado; sin cambios.'
    );
  END IF;

  -- 2. Clasificar tipo de movimiento según el signo de la diferencia
  IF v_difference > 0 THEN
    v_movement_type := 'INCOME';
  ELSE
    v_movement_type := 'EXPENSE';
    v_difference := ABS(v_difference);
  END IF;

  -- 3. Resolver perfil del usuario operador autenticado
  SELECT id INTO v_profile_id 
  FROM profiles 
  WHERE auth_user_id = auth.uid() 
  LIMIT 1;

  -- 4. Registrar movimiento contable de auditoría (Ledger)
  INSERT INTO account_movements (
    account_id,
    movement_type,
    amount,
    description,
    reference_type,
    reference_id,
    created_by,
    created_at
  ) VALUES (
    p_account_id,
    v_movement_type,
    v_difference,
    p_reason,
    'ADJUSTMENT',
    p_account_id,
    v_profile_id,
    NOW()
  );

  -- 5. Actualizar saldo en la cuenta financiera
  UPDATE financial_accounts
  SET 
    balance = p_new_balance,
    updated_at = NOW()
  WHERE id = p_account_id;

  RETURN jsonb_build_object(
    'success', true, 
    'account_id', p_account_id,
    'old_balance', v_old_balance, 
    'new_balance', p_new_balance,
    'difference', v_difference,
    'movement_type', v_movement_type
  );
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Fallo al ajustar saldo atómicamente: %', SQLERRM;
END;
$$;


ALTER FUNCTION "public"."rpc_adjust_financial_account_balance"("p_account_id" "uuid", "p_new_balance" numeric, "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_adjust_wallet"("p_user_id" "uuid", "p_amount" integer) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_new_balance INT;
BEGIN
  -- Actualiza saldo con cl\u00e1usula GREATEST/LEAST para evitar
  -- valores negativos o desbordamientos, y bloquea la fila
  -- con FOR UPDATE para evitar race conditions concurrentes.
  UPDATE profiles
  SET wallet_balance = GREATEST(0, LEAST(wallet_balance + p_amount, 9999999))
  WHERE id = p_user_id
  RETURNING wallet_balance INTO v_new_balance;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Usuario no encontrado: %', p_user_id;
  END IF;

  -- Registra el movimiento dentro de la misma transacci\u00f3n
  INSERT INTO wallet_movements (profile_id, points, movement_type, description)
  VALUES (
    p_user_id,
    p_amount,
    'MANUAL_BONUS',
    CASE
      WHEN p_amount > 0 THEN 'Abono manual de administrador'
      ELSE 'Descuento manual de administrador'
    END
  );

  RETURN v_new_balance;
END;
$$;


ALTER FUNCTION "public"."rpc_adjust_wallet"("p_user_id" "uuid", "p_amount" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_cancel_order"("payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_order_id uuid;
    v_customer_id uuid;
    v_current_profile_id uuid;
    v_notes_override text;
    
    v_order record;
    v_mov record;
    v_new_stock integer;
    v_credit_id uuid;
    v_current_debt numeric;
    v_net_reduction numeric;
    
    v_acc_mov record;
BEGIN
    v_order_id := (payload->>'order_id')::uuid;
    v_customer_id := (payload->>'selected_customer_id')::uuid;
    v_current_profile_id := (payload->>'current_profile_id')::uuid;
    v_notes_override := payload->>'notes_override';

    -- Fallback defensivo para created_by
    IF v_current_profile_id IS NULL THEN
        SELECT id INTO v_current_profile_id FROM profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    END IF;
    IF v_current_profile_id IS NULL THEN
        SELECT ur.profile_id INTO v_current_profile_id
        FROM public.user_roles ur
        JOIN public.roles ro ON ro.id = ur.role_id
        WHERE ro.name = 'admin'
        LIMIT 1;
    END IF;

    -- 1. Fetch Order Data
    SELECT status, warehouse_id, total_amount, amount_paid, payment_method, customer_id
    INTO v_order
    FROM orders
    WHERE id = v_order_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF v_order.status = 'COMPLETED' THEN
        -- 2. Revert Stock
        FOR v_mov IN 
            SELECT variant_id, stock_batch_id, quantity, unit_cost 
            FROM inventory_movements 
            WHERE order_id = v_order_id AND reason = 'SALE'
        LOOP
            IF v_mov.stock_batch_id IS NOT NULL AND v_mov.quantity < 0 THEN
                UPDATE warehouse_stock_batches
                SET available_quantity = available_quantity + ABS(v_mov.quantity)
                WHERE id = v_mov.stock_batch_id
                RETURNING available_quantity INTO v_new_stock;
                
                INSERT INTO inventory_movements 
                    (variant_id, warehouse_id, stock_batch_id, order_id, quantity, previous_stock, new_stock, unit_cost, reason, notes, created_by)
                VALUES 
                    (v_mov.variant_id, v_order.warehouse_id, v_mov.stock_batch_id, v_order_id, ABS(v_mov.quantity), v_new_stock - ABS(v_mov.quantity), v_new_stock, v_mov.unit_cost, 'RETURN', COALESCE(v_notes_override, 'Devolución de inventario — Pedido #' || v_order_id), v_current_profile_id);
            END IF;
        END LOOP;

        -- 3. Revert Credit Debt or Financial Movement
        IF v_order.payment_method = 'CRÉDITO' AND v_order.customer_id IS NOT NULL THEN
            SELECT id, current_debt INTO v_credit_id, v_current_debt
            FROM customer_credits WHERE profile_id = v_order.customer_id;
            
            IF FOUND THEN
                v_net_reduction := v_order.total_amount - v_order.amount_paid;
                
                UPDATE customer_credits 
                SET current_debt = GREATEST(current_debt - v_net_reduction, 0), updated_at = NOW()
                WHERE id = v_credit_id;
                
                INSERT INTO customer_credit_movements (customer_credit_id, order_id, movement_type, amount, notes, created_by)
                VALUES (v_credit_id, v_order_id, 'PAYMENT', v_order.total_amount, COALESCE(v_notes_override, 'Reversión por cancelación de pedido #' || v_order_id), v_current_profile_id);
            END IF;
        END IF;
        
        -- Revert Financial Movement
        FOR v_acc_mov IN
            SELECT id, account_id, amount, shift_id
            FROM account_movements
            WHERE reference_type = 'orders' AND reference_id = v_order_id AND movement_type = 'INCOME'
        LOOP
            UPDATE financial_accounts
            SET balance = balance - v_acc_mov.amount
            WHERE id = v_acc_mov.account_id;
            
            INSERT INTO account_movements (account_id, movement_type, amount, description, reference_type, reference_id, shift_id, created_by)
            VALUES (v_acc_mov.account_id, 'EXPENSE', v_acc_mov.amount, COALESCE(v_notes_override, 'Extorno por cancelación de venta — Pedido #' || v_order_id), 'orders', v_order_id, v_acc_mov.shift_id, v_current_profile_id);
        END LOOP;
    END IF;

    -- 4. Revert Loyalty Points
    IF v_order.customer_id IS NOT NULL THEN
        FOR v_mov IN SELECT points, movement_type FROM wallet_movements WHERE order_id = v_order_id LOOP
            IF v_mov.movement_type = 'EARNED' THEN
                UPDATE profiles SET wallet_balance = GREATEST(COALESCE(wallet_balance, 0) - v_mov.points, 0) WHERE id = v_order.customer_id;
                INSERT INTO wallet_movements (profile_id, order_id, points, movement_type, description)
                VALUES (v_order.customer_id, v_order_id, -v_mov.points, 'ADJUSTMENT', 'Reversión de puntos ganados por cancelación');
            ELSIF v_mov.movement_type = 'REDEEMED' THEN
                UPDATE profiles SET wallet_balance = COALESCE(wallet_balance, 0) + ABS(v_mov.points) WHERE id = v_order.customer_id;
                INSERT INTO wallet_movements (profile_id, order_id, points, movement_type, description)
                VALUES (v_order.customer_id, v_order_id, ABS(v_mov.points), 'ADJUSTMENT', 'Reversión de canje por cancelación');
            END IF;
        END LOOP;
    END IF;

    -- 5. Update Order Status
    UPDATE orders
    SET status = CASE WHEN v_order.status = 'COMPLETED' THEN 'RETURNED' ELSE 'CANCELLED' END,
        payment_status = 'PAID',
        amount_paid = 0
    WHERE id = v_order_id;

    RETURN jsonb_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."rpc_cancel_order"("payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_close_cash_shift"("p_shift_id" "uuid", "p_actual_amount" numeric, "p_closed_by" "uuid", "p_notes" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_shift RECORD;
    v_income NUMERIC := 0;
    v_expense NUMERIC := 0;
    v_expected NUMERIC;
    v_difference NUMERIC;
    v_closed_shift RECORD;
BEGIN
    -- 1. Bloquear el turno para lectura/escritura (FOR UPDATE)
    SELECT * INTO v_shift 
    FROM cash_shifts 
    WHERE id = p_shift_id 
    FOR UPDATE;

    IF v_shift IS NULL THEN
        RAISE EXCEPTION 'El turno de caja especificado no existe.';
    END IF;

    IF v_shift.status = 'CLOSED' THEN
        RAISE EXCEPTION 'Este turno de caja ya se encuentra cerrado.';
    END IF;

    -- 2. Calcular los ingresos de todos los movimientos de este turno
    SELECT COALESCE(SUM(amount), 0) INTO v_income
    FROM account_movements
    WHERE shift_id = p_shift_id AND movement_type = 'INCOME';

    -- 3. Calcular los egresos de todos los movimientos de este turno
    SELECT COALESCE(SUM(amount), 0) INTO v_expense
    FROM account_movements
    WHERE shift_id = p_shift_id AND movement_type = 'EXPENSE';

    -- 4. Recalcular el expected_amount atómicamente
    v_expected := v_shift.opening_amount + v_income - v_expense;
    
    -- 5. Calcular la diferencia final
    v_difference := p_actual_amount - v_expected;

    -- 6. Actualizar y cerrar el turno
    UPDATE cash_shifts
    SET 
        status = 'CLOSED',
        closed_by = p_closed_by,
        closed_at = now(),
        expected_amount = v_expected,
        actual_amount = p_actual_amount,
        difference_amount = v_difference,
        notes = COALESCE(p_notes, notes)
    WHERE id = p_shift_id
    RETURNING * INTO v_closed_shift;

    -- Devolver el registro modificado
    RETURN row_to_json(v_closed_shift);
END;
$$;


ALTER FUNCTION "public"."rpc_close_cash_shift"("p_shift_id" "uuid", "p_actual_amount" numeric, "p_closed_by" "uuid", "p_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_complete_order"("payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_order_id uuid;
    v_warehouse_id uuid;
    v_payment_method text;
    v_customer_id uuid;
    v_customer_name text;
    v_points_used integer;
    v_points_earned integer;
    v_total_amount numeric;
    v_total_profit numeric;
    v_current_profile_id uuid;
    
    v_item jsonb;
    v_items jsonb;
    v_overrides jsonb;
    v_override jsonb;
    
    v_account_id uuid;
    v_account_type text;
    v_account_balance numeric;
    v_shift_id uuid;
    
    v_credit_id uuid;
    v_credit_limit numeric;
    v_current_debt numeric;
    v_is_credit_active boolean;
    v_new_debt numeric;
    
    v_wallet_balance integer;
    
    v_qty_needed integer;
    v_remaining integer;
    v_batch_id uuid;
    v_batch record;
    v_take integer;
    v_old_stock numeric;
BEGIN
    v_order_id := (payload->>'order_id')::uuid;
    v_warehouse_id := (payload->>'warehouse_id')::uuid;
    v_payment_method := payload->>'payment_method';
    v_customer_id := (payload->>'selected_customer_id')::uuid;
    v_customer_name := payload->>'customer_name_to_save';
    v_points_used := COALESCE((payload->>'points_used')::integer, 0);
    v_points_earned := COALESCE((payload->>'points_earned')::integer, 0);
    v_total_amount := COALESCE((payload->>'total_amount')::numeric, 0);
    v_total_profit := COALESCE((payload->>'total_profit')::numeric, 0);
    v_current_profile_id := (payload->>'current_profile_id')::uuid;

    -- Fallback defensivo para created_by
    IF v_current_profile_id IS NULL THEN
        SELECT id INTO v_current_profile_id FROM profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    END IF;
    IF v_current_profile_id IS NULL THEN
        SELECT ur.profile_id INTO v_current_profile_id
        FROM public.user_roles ur
        JOIN public.roles ro ON ro.id = ur.role_id
        WHERE ro.name = 'admin'
        LIMIT 1;
    END IF;

    v_items := payload->'items';
    v_overrides := payload->'batch_overrides';

    SELECT warehouse_id INTO v_warehouse_id FROM orders WHERE id = v_order_id;
    IF v_warehouse_id IS NULL THEN
        RAISE EXCEPTION 'El pedido no tiene almacén asignado.';
    END IF;

    IF v_items IS NULL OR jsonb_array_length(v_items) = 0 THEN
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', id,
                'variant_id', variant_id,
                'quantity', quantity,
                'unit_cost', unit_cost
            )
        ), '[]'::jsonb) INTO v_items
        FROM order_items
        WHERE order_id = v_order_id;
        
        SELECT total_amount INTO v_total_amount FROM orders WHERE id = v_order_id;
    END IF;

    IF v_payment_method = 'POR ACORDAR' OR TRIM(v_payment_method) = '' THEN
        RAISE EXCEPTION '__PAYMENT_METHOD_REQUIRED__';
    END IF;

    IF v_payment_method = 'CRÉDITO' THEN
        IF v_customer_id IS NULL THEN
            RAISE EXCEPTION 'No hay cliente asignado para validar el crédito.';
        END IF;

        SELECT id, credit_limit, current_debt, is_active
        INTO v_credit_id, v_credit_limit, v_current_debt, v_is_credit_active
        FROM customer_credits
        WHERE profile_id = v_customer_id;

        IF NOT FOUND OR v_is_credit_active = false THEN
            RAISE EXCEPTION 'El cliente no tiene línea de crédito activa.';
        END IF;

        IF v_credit_limit > 0
           AND (v_credit_limit - v_current_debt) < v_total_amount THEN
            RAISE EXCEPTION 'Crédito insuficiente. Disponible: S/ %',
                (v_credit_limit - v_current_debt);
        END IF;
    END IF;

    -- 4. Deducción de inventario
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
    LOOP
        v_qty_needed := (v_item->>'quantity')::integer;
        v_remaining := v_qty_needed;
        
        IF v_overrides IS NOT NULL AND v_overrides ? (v_item->>'id') THEN
            FOR v_override IN SELECT * FROM jsonb_array_elements(v_overrides->(v_item->>'id'))
            LOOP
                v_take := (v_override->>'assigned')::integer;
                v_batch_id := (v_override->>'batch_id')::uuid;
                
                IF v_take > 0 THEN
                    SELECT available_quantity INTO v_old_stock
                    FROM warehouse_stock_batches
                    WHERE id = v_batch_id FOR UPDATE;

                    IF v_old_stock IS NULL OR v_old_stock < v_take THEN
                        RAISE EXCEPTION 'Stock insuficiente en el lote asignado (override).';
                    END IF;

                    UPDATE warehouse_stock_batches
                    SET available_quantity = available_quantity - v_take
                    WHERE id = v_batch_id;

                    INSERT INTO inventory_movements (
                        variant_id, warehouse_id, stock_batch_id, order_id, quantity, previous_stock, new_stock, unit_cost, reason, notes, created_by
                    ) VALUES (
                        (v_item->>'variant_id')::uuid, v_warehouse_id, v_batch_id, v_order_id, -v_take, v_old_stock, v_old_stock - v_take, (v_item->>'unit_cost')::numeric, 'SALE', 'Pedido completado desde detalles', v_current_profile_id
                    );
                        
                    v_remaining := v_remaining - v_take;
                END IF;
            END LOOP;
            
            IF v_remaining != 0 THEN
                RAISE EXCEPTION 'Asignación de lotes inválida para producto.';
            END IF;
        ELSE
            FOR v_batch IN 
                SELECT id, available_quantity, batch_number
                FROM warehouse_stock_batches
                WHERE warehouse_id = v_warehouse_id 
                  AND variant_id = (v_item->>'variant_id')::uuid 
                  AND available_quantity > 0
                ORDER BY expiry_date ASC NULLS LAST
                FOR UPDATE
            LOOP
                IF v_remaining <= 0 THEN EXIT; END IF;
                
                IF v_batch.available_quantity >= v_remaining THEN
                    v_take := v_remaining;
                ELSE
                    v_take := v_batch.available_quantity;
                END IF;

                UPDATE warehouse_stock_batches
                SET available_quantity = available_quantity - v_take
                WHERE id = v_batch.id;

                INSERT INTO inventory_movements (
                    variant_id, warehouse_id, stock_batch_id, order_id, quantity, previous_stock, new_stock, unit_cost, reason, notes, created_by
                ) VALUES (
                    (v_item->>'variant_id')::uuid, v_warehouse_id, v_batch.id, v_order_id, -v_take, v_batch.available_quantity, v_batch.available_quantity - v_take, (v_item->>'unit_cost')::numeric, 'SALE', 'Pedido completado (FEFO) · Lote: ' || v_batch.batch_number, v_current_profile_id
                );

                v_remaining := v_remaining - v_take;
            END LOOP;
            
            IF v_remaining > 0 THEN
                RAISE EXCEPTION 'Stock insuficiente para aplicar FEFO automático.';
            END IF;
        END IF;
    END LOOP;

    -- 5. Flujos Financieros
    IF v_payment_method != 'CRÉDITO' THEN
        SELECT id INTO v_shift_id
        FROM cash_shifts
        WHERE status = 'OPEN' AND closed_at IS NULL
        ORDER BY opened_at DESC LIMIT 1;

        SELECT id, current_balance, type INTO v_account_id, v_account_balance, v_account_type
        FROM financial_accounts
        WHERE (
            (v_payment_method = 'EFECTIVO' AND type = 'CASH') OR
            (v_payment_method = 'TRANSFERENCIA' AND type = 'BANK') OR
            (v_payment_method IN ('YAPE', 'PLIN') AND type = 'WALLET')
        )
        ORDER BY created_at ASC LIMIT 1;

        IF v_account_id IS NOT NULL THEN
            UPDATE financial_accounts 
            SET current_balance = current_balance + v_total_amount, updated_at = NOW()
            WHERE id = v_account_id;

            INSERT INTO account_movements (
                account_id, movement_type, amount, reference_type, reference_id, notes, shift_id, created_by
            ) VALUES (
                v_account_id, 'INCOME', v_total_amount, 'orders', v_order_id, 
                'Ingreso por Pedido #' || SUBSTRING(v_order_id::text, 1, 8), 
                v_shift_id, v_current_profile_id
            );
        END IF;
    ELSE
        UPDATE customer_credits
        SET current_debt = current_debt + v_total_amount, updated_at = NOW()
        WHERE id = v_credit_id;

        INSERT INTO customer_credit_movements (
            customer_credit_id, order_id, movement_type, amount, notes, created_by
        ) VALUES (
            v_credit_id, v_order_id, 'CHARGE', v_total_amount,
            'Cargo a crédito por Pedido #' || SUBSTRING(v_order_id::text, 1, 8), v_current_profile_id
        );
    END IF;

    -- 6. Fidelización (Puntos)
    IF v_customer_id IS NOT NULL THEN
        SELECT current_points INTO v_wallet_balance FROM customer_loyalty_wallets WHERE profile_id = v_customer_id;
        IF FOUND THEN
            IF v_points_used > 0 THEN
                UPDATE customer_loyalty_wallets
                SET current_points = GREATEST(current_points - v_points_used, 0),
                    lifetime_redeemed = lifetime_redeemed + v_points_used,
                    updated_at = NOW()
                WHERE profile_id = v_customer_id;

                INSERT INTO customer_loyalty_movements (
                    wallet_id, movement_type, points, order_id, reason, created_by
                ) VALUES (
                    (SELECT id FROM customer_loyalty_wallets WHERE profile_id = v_customer_id),
                    'REDEEM', -v_points_used, v_order_id, 'Puntos canjeados en Pedido', v_current_profile_id
                );
            END IF;

            IF v_points_earned > 0 AND v_payment_method != 'CRÉDITO' THEN
                UPDATE customer_loyalty_wallets
                SET current_points = current_points + v_points_earned,
                    lifetime_earned = lifetime_earned + v_points_earned,
                    updated_at = NOW()
                WHERE profile_id = v_customer_id;

                INSERT INTO customer_loyalty_movements (
                    wallet_id, movement_type, points, order_id, reason, created_by
                ) VALUES (
                    (SELECT id FROM customer_loyalty_wallets WHERE profile_id = v_customer_id),
                    'EARN', v_points_earned, v_order_id, 'Puntos ganados por compra', v_current_profile_id
                );
            END IF;
        END IF;
    END IF;

    -- 7. Actualización del registro del pedido
    UPDATE orders SET
        status = 'COMPLETED',
        payment_method = v_payment_method,
        payment_status = CASE WHEN v_payment_method = 'CRÉDITO' THEN 'PENDING' ELSE 'PAID' END,
        amount_paid = CASE WHEN v_payment_method = 'CRÉDITO' THEN 0 ELSE v_total_amount END,
        total_amount = v_total_amount,
        total_profit = v_total_profit,
        points_used = CASE WHEN v_payment_method = 'CRÉDITO' THEN 0 ELSE v_points_used END,
        points_earned = CASE WHEN v_payment_method = 'CRÉDITO' THEN 0 ELSE v_points_earned END,
        updated_by = v_current_profile_id,
        updated_at = NOW()
    WHERE id = v_order_id;

    RETURN jsonb_build_object('success', true, 'order_id', v_order_id);
END;
$$;


ALTER FUNCTION "public"."rpc_complete_order"("payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_convert_quotation_to_order"("p_quotation_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."rpc_convert_quotation_to_order"("p_quotation_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_create_journal_entry"("payload" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."rpc_create_journal_entry"("payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_create_supplier_credit"("p_supplier_id" "uuid", "p_credit_limit" numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_initial_debt numeric := 0;
  v_new_credit_id uuid;
BEGIN
  -- 1. Calcular deuda inicial bloqueando de forma segura
  SELECT COALESCE(SUM(total_amount - amount_paid), 0)
  INTO v_initial_debt
  FROM purchase_orders
  WHERE supplier_id = p_supplier_id
    AND payment_status IN ('PENDING', 'PARTIAL')
    AND status != 'CANCELLED';

  -- 2. Insertar el nuevo crédito
  INSERT INTO supplier_credits (supplier_id, credit_limit, current_debt, is_active)
  VALUES (p_supplier_id, p_credit_limit, v_initial_debt, true)
  RETURNING id INTO v_new_credit_id;

  RETURN jsonb_build_object('success', true, 'credit_id', v_new_credit_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."rpc_create_supplier_credit"("p_supplier_id" "uuid", "p_credit_limit" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_get_shift_payment_breakdown"("p_shift_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
    v_shift record;
    v_by_method jsonb;
    v_total_expenses numeric;
    v_total_incomes numeric;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado';
    END IF;

    SELECT * INTO v_shift FROM public.cash_shifts WHERE id = p_shift_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Turno de caja no encontrado.';
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
    INTO v_by_method
    FROM (
        SELECT
            op.payment_method,
            COUNT(*) AS transactions,
            SUM(op.amount) AS total_amount,
            SUM(op.amount_base) AS total_amount_base
        FROM public.order_payments op
        JOIN public.orders o ON o.id = op.order_id
        WHERE op.shift_id = p_shift_id
          AND o.status <> 'CANCELLED'
        GROUP BY op.payment_method
        ORDER BY total_amount_base DESC
    ) t;

    SELECT
        COALESCE(SUM(CASE WHEN movement_type IN ('INCOME', 'TRANSFER_IN') THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN movement_type IN ('EXPENSE', 'TRANSFER_OUT') THEN amount ELSE 0 END), 0)
    INTO v_total_incomes, v_total_expenses
    FROM public.account_movements
    WHERE shift_id = p_shift_id;

    RETURN jsonb_build_object(
        'shift_id', p_shift_id,
        'account_id', v_shift.account_id,
        'status', v_shift.status,
        'opening_amount', v_shift.opening_amount,
        'total_incomes', v_total_incomes,
        'total_expenses', v_total_expenses,
        'expected_closing', v_shift.opening_amount + v_total_incomes - v_total_expenses,
        'sales_by_payment_method', v_by_method
    );
END;
$$;


ALTER FUNCTION "public"."rpc_get_shift_payment_breakdown"("p_shift_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_open_cash_shift"("p_account_id" "uuid", "p_opening_amount" numeric, "p_opened_by" "uuid", "p_notes" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_shift_id uuid;
BEGIN
  -- 1. Verificar si ya existe un turno abierto para esta caja
  IF EXISTS (
    SELECT 1 FROM cash_shifts 
    WHERE account_id = p_account_id AND status = 'OPEN'
  ) THEN
    RAISE EXCEPTION 'Esta caja ya tiene un turno abierto.'
      USING ERRCODE = 'P0001';
  END IF;

  -- 2. Validar monto de apertura
  IF p_opening_amount < 0 THEN
    RAISE EXCEPTION 'El saldo de apertura no puede ser negativo.';
  END IF;

  -- 3. Crear el turno
  INSERT INTO cash_shifts (
    account_id,
    opening_amount,
    expected_amount,
    opened_by,
    status,
    opened_at,
    notes
  ) VALUES (
    p_account_id,
    p_opening_amount,
    p_opening_amount,
    p_opened_by,
    'OPEN',
    NOW(),
    p_notes
  ) RETURNING id INTO v_shift_id;

  RETURN v_shift_id;
END;
$$;


ALTER FUNCTION "public"."rpc_open_cash_shift"("p_account_id" "uuid", "p_opening_amount" numeric, "p_opened_by" "uuid", "p_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_post_order_to_journal"("p_order_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
    v_profile_id uuid;
    v_order record;
    v_existing_id uuid;
    v_entry_id uuid;
    v_total_cost numeric := 0;
BEGIN
    SELECT id INTO v_profile_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin perfil válido.';
    END IF;
    IF NOT public.user_has_permission('accounting.manage') THEN
        RAISE EXCEPTION 'Sin permiso contable (accounting.manage).' USING ERRCODE = '42501';
    END IF;

    SELECT id INTO v_existing_id
    FROM public.journal_entries
    WHERE reference_type = 'orders' AND reference_id = p_order_id AND status = 'POSTED'
    LIMIT 1;
    IF v_existing_id IS NOT NULL THEN
        RETURN v_existing_id;
    END IF;

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND OR v_order.status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Orden inválida o anulada.';
    END IF;

    SELECT COALESCE(SUM(unit_cost_base * quantity), 0)
    INTO v_total_cost
    FROM public.order_items
    WHERE order_id = p_order_id;

    INSERT INTO public.journal_entries (
        entry_number, entry_date, description, reference_type, reference_id, created_by
    ) VALUES (
        'VTA-' || COALESCE(v_order.document_number, substring(p_order_id::text, 1, 8)),
        COALESCE(v_order.document_date, CURRENT_DATE),
        'Provisión venta ' || COALESCE(v_order.document_number, p_order_id::text),
        'orders', p_order_id, v_profile_id
    ) RETURNING id INTO v_entry_id;

    -- 1212 Cuentas por cobrar (Debe)
    INSERT INTO public.journal_entry_lines (journal_entry_id, account_code, description, debit, credit)
    VALUES (v_entry_id, '1212', 'Venta al cliente', v_order.total_amount_base, 0);

    -- 4011 IGV por pagar (Haber) si hay impuesto
    IF COALESCE(v_order.tax_amount_base, 0) > 0 THEN
        INSERT INTO public.journal_entry_lines (journal_entry_id, account_code, description, debit, credit)
        VALUES (v_entry_id, '4011', 'IGV Venta', 0, v_order.tax_amount_base);
    END IF;

    -- 7011 Ventas (Haber)
    INSERT INTO public.journal_entry_lines (journal_entry_id, account_code, description, debit, credit)
    VALUES (v_entry_id, '7011', 'Ingreso por venta', 0, v_order.total_amount_base - COALESCE(v_order.tax_amount_base, 0));

    -- Costo de ventas (6911 Debe / 2011 Haber)
    IF v_total_cost > 0 THEN
        INSERT INTO public.journal_entry_lines (journal_entry_id, account_code, description, debit, credit)
        VALUES
            (v_entry_id, '6911', 'Costo de ventas', ROUND(v_total_cost, 2), 0),
            (v_entry_id, '2011', 'Salida de mercaderías', 0, ROUND(v_total_cost, 2));
    END IF;

    RETURN v_entry_id;
END;
$$;


ALTER FUNCTION "public"."rpc_post_order_to_journal"("p_order_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_process_sales_return"("payload" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."rpc_process_sales_return"("payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_receive_inventory_only"("payload" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."rpc_receive_inventory_only"("payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_receive_purchase_order_items"("p_order_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_item jsonb;
  v_receive_qty numeric;
  v_fully_received boolean;
  v_product_id uuid;
  v_variant_id uuid;
  v_uses_batches boolean;
  v_batch_number text;
  v_expiry_date date;
  v_quantity_ordered numeric;
  
  v_old_received numeric;
  v_new_received numeric;
  v_batch_id uuid;
  v_stock_id uuid;
  
  v_all_fully_received boolean := true;
BEGIN
  -- 1. Iterar sobre los items recibidos de forma atómica
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_receive_qty := (v_item->>'receiveQty')::numeric;
    v_fully_received := (v_item->>'fullyReceived')::boolean;
    v_product_id := (v_item->>'product_id')::uuid;
    v_variant_id := (v_item->>'variant_id')::uuid;
    v_uses_batches := (v_item->>'uses_batches')::boolean;
    v_batch_number := v_item->>'batch_number';
    
    IF v_item->>'expiry_date' IS NOT NULL THEN
      v_expiry_date := (v_item->>'expiry_date')::date;
    ELSE
      v_expiry_date := NULL;
    END IF;

    -- Solo procesar si hay cantidad a recibir o si fue marcado como completamente recibido
    IF v_receive_qty <= 0 THEN
      IF NOT v_fully_received THEN
        v_all_fully_received := false;
      END IF;
      CONTINUE;
    END IF;

    -- A. Actualizar quantity_received en purchase_order_items con bloqueo (FOR UPDATE)
    SELECT quantity_received, quantity_ordered 
    INTO v_old_received, v_quantity_ordered
    FROM purchase_order_items
    WHERE purchase_order_id = p_order_id AND product_id = v_product_id AND variant_id = v_variant_id
    FOR UPDATE;

    v_new_received := v_old_received + v_receive_qty;
    
    UPDATE purchase_order_items
    SET quantity_received = v_new_received
    WHERE purchase_order_id = p_order_id AND product_id = v_product_id AND variant_id = v_variant_id;

    -- Determinar si la orden completa está totalmente recibida
    IF v_new_received < v_quantity_ordered AND NOT v_fully_received THEN
      v_all_fully_received := false;
    END IF;

    -- B. Gestionar Lotes (inventory_batches) si usa lotes
    IF v_uses_batches = true THEN
      SELECT id INTO v_batch_id
      FROM inventory_batches
      WHERE product_id = v_product_id 
        AND variant_id = v_variant_id 
        AND warehouse_id = p_warehouse_id 
        AND batch_number = v_batch_number
      FOR UPDATE;

      IF v_batch_id IS NOT NULL THEN
        UPDATE inventory_batches
        SET quantity = quantity + v_receive_qty
        WHERE id = v_batch_id;
      ELSE
        INSERT INTO inventory_batches (product_id, variant_id, warehouse_id, batch_number, quantity, expiry_date)
        VALUES (v_product_id, v_variant_id, p_warehouse_id, v_batch_number, v_receive_qty, v_expiry_date);
      END IF;
    END IF;

    -- C. Gestionar Stock General (inventory_stock)
    SELECT id INTO v_stock_id
    FROM inventory_stock
    WHERE product_id = v_product_id 
      AND variant_id = v_variant_id 
      AND warehouse_id = p_warehouse_id
    FOR UPDATE;

    IF v_stock_id IS NOT NULL THEN
      UPDATE inventory_stock
      SET quantity = quantity + v_receive_qty
      WHERE id = v_stock_id;
    ELSE
      INSERT INTO inventory_stock (product_id, variant_id, warehouse_id, quantity)
      VALUES (v_product_id, v_variant_id, p_warehouse_id, v_receive_qty);
    END IF;

  END LOOP;

  -- 2. Actualizar el estado de la orden (purchase_orders)
  UPDATE purchase_orders
  SET 
    status = CASE WHEN v_all_fully_received THEN 'RECEIVED' ELSE 'PARTIAL' END,
    updated_at = NOW()
  WHERE id = p_order_id;

  RETURN jsonb_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."rpc_receive_purchase_order_items"("p_order_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_record_expense"("payload" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."rpc_record_expense"("payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_resolve_variant_price"("p_variant_id" "uuid", "p_price_list_id" "uuid" DEFAULT NULL::"uuid", "p_unit_code" "text" DEFAULT 'NIU'::"text", "p_quantity" numeric DEFAULT 1) RETURNS numeric
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."rpc_resolve_variant_price"("p_variant_id" "uuid", "p_price_list_id" "uuid", "p_unit_code" "text", "p_quantity" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_transfer_warehouse_stock"("payload" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."rpc_transfer_warehouse_stock"("payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_upsert_customer"("payload" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."rpc_upsert_customer"("payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_customer_full_profile_rpc"("p_customer_id" "uuid" DEFAULT NULL::"uuid", "p_full_name" "text" DEFAULT ''::"text", "p_phone" "text" DEFAULT NULL::"text", "p_document_number" "text" DEFAULT NULL::"text", "p_document_type" "text" DEFAULT 'DNI'::"text", "p_is_active" boolean DEFAULT true, "p_wallet_delta" integer DEFAULT 0, "p_has_credit" boolean DEFAULT true, "p_credit_limit" numeric DEFAULT 0.00) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_admin_profile_id uuid;
  v_target_profile_id uuid;
  v_credit_id uuid;
  v_current_wallet int;
BEGIN
  SELECT id INTO v_admin_profile_id 
  FROM profiles 
  WHERE auth_user_id = auth.uid() OR id = auth.uid() 
  LIMIT 1;

  IF p_customer_id IS NOT NULL THEN
    UPDATE profiles
    SET 
      full_name = p_full_name,
      phone = NULLIF(TRIM(p_phone), ''),
      document_number = NULLIF(TRIM(p_document_number), ''),
      document_type = p_document_type,
      is_active = p_is_active
    WHERE id = p_customer_id;
    
    v_target_profile_id := p_customer_id;

    IF p_wallet_delta <> 0 THEN
      SELECT wallet_balance INTO v_current_wallet FROM profiles WHERE id = v_target_profile_id;
      UPDATE profiles 
      SET wallet_balance = COALESCE(v_current_wallet, 0) + p_wallet_delta 
      WHERE id = v_target_profile_id;

      INSERT INTO wallet_movements(profile_id, points, movement_type, description)
      VALUES (
        v_target_profile_id, 
        p_wallet_delta, 
        CASE WHEN p_wallet_delta > 0 THEN 'ADMIN_ADD' ELSE 'ADMIN_SUBTRACT' END,
        'Ajuste manual administrativo'
      );
    END IF;
  ELSE
    INSERT INTO profiles (
      full_name, 
      phone, 
      document_type, 
      document_number, 
      is_active, 
      wallet_balance
    )
    VALUES (
      p_full_name, 
      NULLIF(TRIM(p_phone), ''), 
      p_document_type, 
      NULLIF(TRIM(p_document_number), ''), 
      p_is_active, 
      0
    )
    RETURNING id INTO v_target_profile_id;
  END IF;

  SELECT id INTO v_credit_id FROM customer_credits WHERE profile_id = v_target_profile_id;

  IF v_credit_id IS NOT NULL THEN
    UPDATE customer_credits
    SET 
      credit_limit = COALESCE(p_credit_limit, 0.00),
      is_active = p_has_credit,
      updated_at = now()
    WHERE id = v_credit_id;
  ELSE
    INSERT INTO customer_credits (
      profile_id, 
      credit_limit, 
      current_debt, 
      is_active, 
      created_by
    )
    VALUES (
      v_target_profile_id, 
      COALESCE(p_credit_limit, 0.00), 
      0.00, 
      p_has_credit, 
      v_admin_profile_id
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'profile_id', v_target_profile_id
  );
END;
$$;


ALTER FUNCTION "public"."save_customer_full_profile_rpc"("p_customer_id" "uuid", "p_full_name" "text", "p_phone" "text", "p_document_number" "text", "p_document_type" "text", "p_is_active" boolean, "p_wallet_delta" integer, "p_has_credit" boolean, "p_credit_limit" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_product_complete"("payload" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
    v_auth_user_id uuid := auth.uid();
    v_is_updating boolean;
    v_product_id uuid;
    v_profile_id uuid;
    v_variant_id uuid;
    v_variant jsonb;
    v_image jsonb;
    v_ingredient jsonb;
    v_removed_id text;
    v_attr_id text;
    v_incoming_image_ids uuid[];
BEGIN
    v_profile_id := (payload->>'profile_id')::uuid;
    IF v_profile_id IS NULL THEN
        SELECT id INTO v_profile_id FROM profiles WHERE auth_user_id = v_auth_user_id LIMIT 1;
    END IF;
    IF v_profile_id IS NULL THEN
        SELECT ur.profile_id INTO v_profile_id
        FROM public.user_roles ur
        JOIN public.roles ro ON ro.id = ur.role_id
        WHERE ro.name = 'admin'
        LIMIT 1;
    END IF;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Operación rechazada: El usuario autenticado no posee un perfil válido en el sistema.';
    END IF;

    v_is_updating := COALESCE((payload->>'is_updating')::boolean, false);

    IF v_is_updating THEN
        v_product_id := (payload->'product'->>'id')::uuid;
        IF v_product_id IS NULL THEN
            RAISE EXCEPTION 'Error: Se especificó actualización pero el id del producto es nulo.';
        END IF;

        UPDATE products SET
            name = payload->'product'->>'name',
            description = payload->'product'->>'description',
            category_id = (NULLIF(payload->'product'->>'category_id', ''))::uuid,
            brand_id = (NULLIF(payload->'product'->>'brand_id', ''))::uuid,
            is_active = COALESCE((payload->'product'->>'is_active')::boolean, true),
            details = payload->'product'->'details',
            product_type = payload->'product'->>'product_type',
            stock_control = COALESCE((payload->'product'->>'stock_control')::boolean, true),
            uses_batches = COALESCE((payload->'product'->>'uses_batches')::boolean, false),
            updated_at = NOW(),
            updated_by = v_profile_id
        WHERE id = v_product_id;
    ELSE
        INSERT INTO products (
            name, description, category_id, brand_id, is_active, details, product_type, stock_control, uses_batches, created_by
        ) VALUES (
            payload->'product'->>'name',
            payload->'product'->>'description',
            (NULLIF(payload->'product'->>'category_id', ''))::uuid,
            (NULLIF(payload->'product'->>'brand_id', ''))::uuid,
            COALESCE((payload->'product'->>'is_active')::boolean, true),
            payload->'product'->'details',
            payload->'product'->>'product_type',
            COALESCE((payload->'product'->>'stock_control')::boolean, true),
            COALESCE((payload->'product'->>'uses_batches')::boolean, false),
            v_profile_id
        ) RETURNING id INTO v_product_id;
    END IF;

    IF payload ? 'images' AND jsonb_typeof(payload->'images') = 'array' THEN
        SELECT array_agg((elem->>'id')::uuid) INTO v_incoming_image_ids
        FROM jsonb_array_elements(payload->'images') AS elem
        WHERE (elem->>'id') IS NOT NULL;

        DELETE FROM product_images 
        WHERE product_id = v_product_id 
          AND variant_id IS NULL 
          AND (id <> ALL(v_incoming_image_ids) OR v_incoming_image_ids IS NULL);

        FOR v_image IN SELECT * FROM jsonb_array_elements(payload->'images')
        LOOP
            INSERT INTO product_images (id, product_id, image_url, display_order, is_main)
            VALUES (
                COALESCE((v_image->>'id')::uuid, gen_random_uuid()),
                v_product_id,
                v_image->>'image_url',
                COALESCE((v_image->>'display_order')::integer, 0),
                COALESCE((v_image->>'is_main')::boolean, false)
            )
            ON CONFLICT (id) DO UPDATE SET
                image_url = EXCLUDED.image_url,
                display_order = EXCLUDED.display_order,
                is_main = EXCLUDED.is_main;
        END LOOP;
    ELSE
        DELETE FROM product_images WHERE product_id = v_product_id AND variant_id IS NULL;
    END IF;

    IF payload ? 'removed_variant_ids' THEN
        FOR v_removed_id IN SELECT * FROM jsonb_array_elements_text(payload->'removed_variant_ids')
        LOOP
            UPDATE product_variants SET is_active = false, updated_at = NOW(), updated_by = v_profile_id WHERE id = v_removed_id::uuid;
        END LOOP;
    END IF;

    IF payload ? 'variants' AND jsonb_typeof(payload->'variants') = 'array' THEN
        FOR v_variant IN SELECT * FROM jsonb_array_elements(payload->'variants')
        LOOP
            IF (v_variant->>'id') IS NOT NULL AND (v_variant->>'id') != '' THEN
                v_variant_id := (v_variant->>'id')::uuid;
                UPDATE product_variants SET
                    sku = v_variant->>'sku',
                    barcode = NULLIF(TRIM(v_variant->>'barcode'), ''),
                    unit_cost = (v_variant->>'unit_cost')::numeric,
                    sale_price = (v_variant->>'sale_price')::numeric,
                    wholesale_price = (v_variant->>'wholesale_price')::numeric,
                    wholesale_min_quantity = (v_variant->>'wholesale_min_quantity')::integer,
                    reorder_point = (v_variant->>'reorder_point')::integer,
                    is_active = COALESCE((v_variant->>'is_active')::boolean, true),
                    updated_at = NOW(),
                    updated_by = v_profile_id
                WHERE id = v_variant_id;
            ELSE
                INSERT INTO product_variants (
                    product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, created_by
                ) VALUES (
                    v_product_id,
                    v_variant->>'sku',
                    NULLIF(TRIM(v_variant->>'barcode'), ''),
                    COALESCE((v_variant->>'unit_cost')::numeric, 0.00),
                    COALESCE((v_variant->>'sale_price')::numeric, 0.00),
                    (v_variant->>'wholesale_price')::numeric,
                    (v_variant->>'wholesale_min_quantity')::integer,
                    COALESCE((v_variant->>'reorder_point')::integer, 0),
                    COALESCE((v_variant->>'is_active')::boolean, true),
                    v_profile_id
                ) RETURNING id INTO v_variant_id;
            END IF;

            IF COALESCE((v_variant->>'clear_images')::boolean, false) THEN
                DELETE FROM product_images WHERE variant_id = v_variant_id;
            END IF;
            
            IF (v_variant->>'new_image_url') IS NOT NULL AND (v_variant->>'new_image_url') != '' THEN
                IF NOT EXISTS (
                    SELECT 1 FROM product_images 
                    WHERE variant_id = v_variant_id AND image_url = (v_variant->>'new_image_url')
                ) THEN
                    INSERT INTO product_images (product_id, variant_id, image_url, is_main, display_order)
                    VALUES (v_product_id, v_variant_id, v_variant->>'new_image_url', true, 0);
                END IF;
            END IF;

            IF v_variant ? 'attribute_value_ids' AND jsonb_typeof(v_variant->'attribute_value_ids') = 'array' THEN
                DELETE FROM variant_attribute_values WHERE variant_id = v_variant_id;
                FOR v_attr_id IN SELECT * FROM jsonb_array_elements_text(v_variant->'attribute_value_ids')
                LOOP
                    INSERT INTO variant_attribute_values (variant_id, attribute_value_id)
                    VALUES (v_variant_id, v_attr_id::uuid)
                    ON CONFLICT DO NOTHING;
                END LOOP;
            END IF;
        END LOOP;
    END IF;

    IF COALESCE((payload->>'ingredients_enabled')::boolean, false) AND payload ? 'ingredients' THEN
        DELETE FROM product_active_ingredients WHERE product_id = v_product_id;
        FOR v_ingredient IN SELECT * FROM jsonb_array_elements(payload->'ingredients')
        LOOP
            INSERT INTO product_active_ingredients (product_id, ingredient_id, concentration, unit)
            VALUES (
                v_product_id,
                (v_ingredient->>'ingredient_id')::uuid,
                (v_ingredient->>'concentration')::numeric,
                v_ingredient->>'unit'
            );
        END LOOP;
    ELSE
        DELETE FROM product_active_ingredients WHERE product_id = v_product_id;
    END IF;
END;
$$;


ALTER FUNCTION "public"."save_product_complete"("payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_variant_attributes_rpc"("p_variant_id" "uuid", "p_attribute_value_ids" "uuid"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
    v_attr_id uuid;
BEGIN
    -- Operación 100% atómica dentro de la transacción del motor de PostgreSQL
    DELETE FROM variant_attribute_values WHERE variant_id = p_variant_id;
    
    IF p_attribute_value_ids IS NOT NULL AND array_length(p_attribute_value_ids, 1) > 0 THEN
        FOREACH v_attr_id IN ARRAY p_attribute_value_ids
        LOOP
            INSERT INTO variant_attribute_values (variant_id, attribute_value_id)
            VALUES (p_variant_id, v_attr_id);
        END LOOP;
    END IF;
END;
$$;


ALTER FUNCTION "public"."save_variant_attributes_rpc"("p_variant_id" "uuid", "p_attribute_value_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_ingredients_unaccent"("search_term" "text") RETURNS TABLE("id" "text")
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'extensions'
    AS $$
begin
  return query
  select ai.id::text
  from active_ingredients ai
  where unaccent(lower(ai.name)) ilike unaccent(lower('%' || search_term || '%'));
end;
$$;


ALTER FUNCTION "public"."search_ingredients_unaccent"("search_term" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_default_location"("p_profile_id" "uuid", "p_location_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'extensions'
    AS $$
BEGIN
  -- 1. Quitar el flag is_default a todas las ubicaciones de este perfil
  UPDATE customer_locations
  SET is_default = false
  WHERE profile_id = p_profile_id;

  -- 2. Establecer el flag is_default solo a la ubicación deseada
  UPDATE customer_locations
  SET is_default = true
  WHERE id = p_location_id;
END;
$$;


ALTER FUNCTION "public"."set_default_location"("p_profile_id" "uuid", "p_location_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_cloud_cart_rpc"("p_auth_user_id" "uuid", "p_items" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_profile_id uuid;
  v_cart_id uuid;
BEGIN
  -- 1. Obtener el profile_id
  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE auth_user_id = p_auth_user_id;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado para el usuario dado.';
  END IF;

  -- 2. Obtener o crear el carrito
  SELECT id INTO v_cart_id
  FROM public.shopping_carts
  WHERE profile_id = v_profile_id;

  IF v_cart_id IS NULL THEN
    INSERT INTO public.shopping_carts (profile_id)
    VALUES (v_profile_id)
    RETURNING id INTO v_cart_id;
  END IF;

  -- 3. Limpiar los items actuales del carrito
  DELETE FROM public.cart_items WHERE cart_id = v_cart_id;

  -- 4. Insertar los nuevos items usando bulk insert desde JSONB
  IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
    INSERT INTO public.cart_items (
      cart_id,
      product_id,
      variant_id,
      quantity,
      is_selected
    )
    SELECT
      v_cart_id,
      (rec.product_id)::uuid,
      CASE WHEN rec.variant_id IS NULL OR rec.variant_id = '' THEN NULL ELSE (rec.variant_id)::uuid END,
      (rec.quantity)::integer,
      (rec.is_selected)::boolean
    FROM jsonb_to_recordset(p_items) AS rec(
      product_id text,
      variant_id text,
      quantity text,
      is_selected text
    );
  END IF;

  -- 5. Retornar el ID del carrito
  RETURN v_cart_id;
END;
$$;


ALTER FUNCTION "public"."sync_cloud_cart_rpc"("p_auth_user_id" "uuid", "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_purchase_order_reception_rpc"("p_purchase_order_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_item RECORD;
    v_total_received NUMERIC;
    v_all_received BOOLEAN := TRUE;
    v_any_received BOOLEAN := FALSE;
    v_new_status TEXT;
    v_current_status TEXT;
BEGIN
    IF p_purchase_order_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'ID de orden nulo');
    END IF;

    -- Obtener estado actual para no pisar estados terminales/manuales
    SELECT status INTO v_current_status
      FROM public.purchase_orders
     WHERE id = p_purchase_order_id;

    IF v_current_status IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'La orden de compra no existe.');
    END IF;

    -- Una orden anulada nunca debe volver a cambiar de estado por este sync
    IF v_current_status = 'CANCELLED' THEN
        RETURN jsonb_build_object(
            'success', true,
            'purchase_order_id', p_purchase_order_id,
            'new_status', v_current_status,
            'skipped', true
        );
    END IF;

    FOR v_item IN
        SELECT id, product_id, variant_id, quantity_ordered
        FROM public.purchase_order_items
        WHERE purchase_order_id = p_purchase_order_id
    LOOP
        SELECT COALESCE(SUM(iei.quantity), 0)
        INTO v_total_received
        FROM public.inventory_entry_items iei
        JOIN public.inventory_entries ie ON ie.id = iei.entry_id
        WHERE ie.purchase_order_id = p_purchase_order_id
          AND (
               (v_item.variant_id IS NOT NULL AND iei.variant_id = v_item.variant_id)
               OR
               (v_item.product_id IS NOT NULL AND iei.product_id = v_item.product_id)
              );

        UPDATE public.purchase_order_items
        SET quantity_received = v_total_received
        WHERE id = v_item.id;

        IF v_total_received > 0 THEN
            v_any_received := TRUE;
        END IF;

        IF v_total_received < v_item.quantity_ordered THEN
            v_all_received := FALSE;
        END IF;
    END LOOP;

    IF v_all_received THEN
        v_new_status := 'RECEIVED';
    ELSIF v_any_received THEN
        v_new_status := 'PARTIAL';
    ELSE
        v_new_status := 'SENT';
    END IF;

    UPDATE public.purchase_orders
    SET status = v_new_status,
        updated_at = NOW()
    WHERE id = p_purchase_order_id;

    RETURN jsonb_build_object(
        'success', true,
        'purchase_order_id', p_purchase_order_id,
        'new_status', v_new_status
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."sync_purchase_order_reception_rpc"("p_purchase_order_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_funds_rpc"("p_source_account_id" "uuid", "p_dest_account_id" "uuid", "p_amount" numeric, "p_description" "text", "p_created_by" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_source_name TEXT;
  v_dest_name TEXT;
  v_desc_source TEXT;
  v_desc_dest TEXT;
BEGIN
  -- 1. Obtener nombres de las cuentas
  SELECT name INTO v_source_name FROM public.financial_accounts WHERE id = p_source_account_id;
  SELECT name INTO v_dest_name FROM public.financial_accounts WHERE id = p_dest_account_id;

  IF v_source_name IS NULL OR v_dest_name IS NULL THEN
      RAISE EXCEPTION 'Una de las cuentas financieras no existe.';
  END IF;

  -- 2. Formatear descripciones
  IF p_description IS NOT NULL AND p_description <> '' THEN
      v_desc_source := 'Transferencia enviada a ' || v_dest_name || ' — ' || p_description;
      v_desc_dest := 'Transferencia recibida de ' || v_source_name || ' — ' || p_description;
  ELSE
      v_desc_source := 'Transferencia enviada a ' || v_dest_name;
      v_desc_dest := 'Transferencia recibida de ' || v_source_name;
  END IF;

  -- 3. Registrar Expense en origen (Llama al RPC base atómicamente)
  PERFORM public.register_financial_movement(
    p_source_account_id,
    'EXPENSE',
    p_amount,
    v_desc_source,
    'manual_transfer',
    NULL,
    p_created_by
  );

  -- 4. Registrar Income en destino (Llama al RPC base atómicamente)
  PERFORM public.register_financial_movement(
    p_dest_account_id,
    'INCOME',
    p_amount,
    v_desc_dest,
    'manual_transfer',
    NULL,
    p_created_by
  );
END;
$$;


ALTER FUNCTION "public"."transfer_funds_rpc"("p_source_account_id" "uuid", "p_dest_account_id" "uuid", "p_amount" numeric, "p_description" "text", "p_created_by" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_audit_log"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


ALTER FUNCTION "public"."trg_audit_log"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_auto_create_counter_cash_account"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Verificar si ya existe una caja física para este almacén
  IF NOT EXISTS (
    SELECT 1 FROM public.financial_accounts
    WHERE warehouse_id = NEW.id AND type = 'CAJA'
  ) THEN
    INSERT INTO public.financial_accounts (
      name,
      type,
      currency_code,
      balance,
      warehouse_id,
      is_active,
      created_by
    ) VALUES (
      'Caja Mostrador - ' || NEW.name,
      'CAJA',
      'PEN',
      0.00,
      NEW.id,
      NEW.is_active,
      NEW.created_by
    );
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_auto_create_counter_cash_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_check_journal_entry_lines_balanced"() RETURNS "trigger"
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "public"."trg_check_journal_entry_lines_balanced"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_compute_base_amounts"() RETURNS "trigger"
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "public"."trg_compute_base_amounts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_journal_balanced_and_period"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_debit numeric;
    v_credit numeric;
    v_period_id uuid;
    v_period_status text;
BEGIN
    SELECT id, status INTO v_period_id, v_period_status
    FROM public.accounting_periods
    WHERE year = EXTRACT(YEAR FROM NEW.entry_date)::int
      AND month = EXTRACT(MONTH FROM NEW.entry_date)::int;

    IF v_period_status = 'CLOSED' THEN
        RAISE EXCEPTION 'El periodo contable %-% está CERRADO.', EXTRACT(YEAR FROM NEW.entry_date), EXTRACT(MONTH FROM NEW.entry_date);
    END IF;

    IF NEW.period_id IS NULL AND v_period_id IS NOT NULL THEN
        NEW.period_id := v_period_id;
    END IF;

    IF NEW.status = 'POSTED' AND (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM 'POSTED') THEN
        SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
        INTO v_debit, v_credit
        FROM public.journal_entry_lines
        WHERE journal_entry_id = NEW.id;

        IF v_debit <= 0 OR ABS(v_debit - v_credit) > 0.01 THEN
            RAISE EXCEPTION 'Asiento % descuadrado: Debe (%) <> Haber (%)', NEW.id, v_debit, v_credit;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_journal_balanced_and_period"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_sync_customer_record_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_cid uuid;
    v_pid uuid;
BEGIN
    IF TG_TABLE_NAME = 'orders' THEN
        IF NEW.customer_record_id IS NULL AND NEW.customer_id IS NOT NULL THEN
            SELECT id INTO v_cid FROM public.customers WHERE profile_id = NEW.customer_id LIMIT 1;
            NEW.customer_record_id := v_cid;
        ELSIF NEW.customer_id IS NULL AND NEW.customer_record_id IS NOT NULL THEN
            SELECT profile_id INTO v_pid FROM public.customers WHERE id = NEW.customer_record_id LIMIT 1;
            NEW.customer_id := v_pid;
        END IF;
    ELSE
        -- customer_credits, customer_locations
        IF NEW.customer_record_id IS NULL AND NEW.profile_id IS NOT NULL THEN
            SELECT id INTO v_cid FROM public.customers WHERE profile_id = NEW.profile_id LIMIT 1;
            NEW.customer_record_id := v_cid;
        ELSIF NEW.profile_id IS NULL AND NEW.customer_record_id IS NOT NULL THEN
            SELECT profile_id INTO v_pid FROM public.customers WHERE id = NEW.customer_record_id LIMIT 1;
            NEW.profile_id := v_pid;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_sync_customer_record_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_sync_warehouse_status_to_cash_account"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF (OLD.is_active IS DISTINCT FROM NEW.is_active) THEN
    UPDATE public.financial_accounts
    SET is_active = NEW.is_active
    WHERE warehouse_id = NEW.id AND type = 'CAJA';
  END IF;

  -- Si se renombra el almacén, actualizar el nombre de la Caja Mostrador
  IF (OLD.name IS DISTINCT FROM NEW.name) THEN
    UPDATE public.financial_accounts
    SET name = 'Caja Mostrador - ' || NEW.name
    WHERE warehouse_id = NEW.id AND type = 'CAJA' AND name LIKE 'Caja Mostrador%';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_sync_warehouse_status_to_cash_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_sync_warehouse_variant_qty"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_wh_id uuid := COALESCE(NEW.warehouse_id, OLD.warehouse_id);
    v_var_id uuid := COALESCE(NEW.variant_id, OLD.variant_id);
    v_sum numeric(14,4);
BEGIN
    SELECT COALESCE(SUM(available_quantity), 0)
    INTO v_sum
    FROM public.warehouse_stock_batches
    WHERE warehouse_id = v_wh_id AND variant_id = v_var_id;

    INSERT INTO public.warehouse_variant_costs (warehouse_id, variant_id, total_quantity, updated_at)
    VALUES (v_wh_id, v_var_id, v_sum, now())
    ON CONFLICT (warehouse_id, variant_id)
    DO UPDATE SET total_quantity = v_sum, updated_at = now();

    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."trg_sync_warehouse_variant_qty"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_track_order_status"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO public.order_status_history (order_id, previous_status, new_status, changed_by)
        VALUES (NEW.id, OLD.status, NEW.status, COALESCE(NEW.updated_by, NEW.created_by));
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_track_order_status"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_po_payment_method_rpc"("p_order_id" "uuid", "p_supplier_id" "uuid", "p_new_method" "text", "p_old_method" "text", "p_order_amount" numeric, "p_profile_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_credit_record RECORD;
    v_new_debt NUMERIC;
    v_available_credit NUMERIC;
BEGIN
    -- 1. Si el método es idéntico al actual, retornar éxito sin realizar cambios
    IF p_new_method = p_old_method THEN
        RETURN jsonb_build_object('success', true, 'message', 'El método de pago es idéntico al actual.');
    END IF;

    -- 2. Si involucra 'CRÉDITO' (ya sea origen o destino), bloqueamos la fila de crédito de forma transaccional (ACID)
    IF p_new_method = 'CRÉDITO' OR p_old_method = 'CRÉDITO' THEN
        SELECT id, current_debt, credit_limit, is_active
        INTO v_credit_record
        FROM supplier_credits
        WHERE supplier_id = p_supplier_id
        FOR UPDATE;
    END IF;

    -- 3. Si el nuevo método es 'CRÉDITO':
    IF p_new_method = 'CRÉDITO' THEN
        -- a. Verificar existencia del crédito
        IF NOT FOUND OR v_credit_record.id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'El proveedor no tiene una línea de crédito habilitada. Regístrala en Créditos Proveedores.');
        END IF;

        -- b. Verificar estado activo
        IF NOT v_credit_record.is_active THEN
            RETURN jsonb_build_object('success', false, 'error', 'La línea de crédito de este proveedor está inactiva.');
        END IF;

        -- c. Verificar límite de crédito mayor a 0
        IF v_credit_record.credit_limit <= 0 THEN
            RETURN jsonb_build_object('success', false, 'error', 'El proveedor tiene un límite de crédito de S/ 0.00. Configura un límite mayor a 0.');
        END IF;

        -- d. Verificar disponibilidad de crédito suficiente
        v_available_credit := GREATEST(0, v_credit_record.credit_limit - v_credit_record.current_debt);
        IF (v_credit_record.current_debt + p_order_amount) > v_credit_record.credit_limit THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', format('Límite de crédito excedido. Disponible: S/ %s, Monto de la orden: S/ %s.', 
                                round(v_available_credit, 2), round(p_order_amount, 2))
            );
        END IF;

        -- e. UPDATE supplier_credits SET current_debt = current_debt + p_order_amount
        UPDATE supplier_credits
        SET current_debt = current_debt + p_order_amount,
            updated_at = NOW()
        WHERE id = v_credit_record.id;

        -- f. INSERT en supplier_credit_movements (CHARGE)
        INSERT INTO supplier_credit_movements (
            supplier_credit_id,
            purchase_order_id,
            movement_type,
            amount,
            notes,
            created_by
        ) VALUES (
            v_credit_record.id,
            p_order_id,
            'CHARGE',
            p_order_amount,
            format('Cambio de método de pago a CRÉDITO en Orden #%s', upper(substring(p_order_id::text from 1 for 8))),
            p_profile_id
        );
    END IF;

    -- 4. Si el método anterior era 'CRÉDITO' y se cambia a uno diferente ('EFECTIVO' o 'TARJETA'):
    IF p_old_method = 'CRÉDITO' AND p_new_method != 'CRÉDITO' THEN
        IF v_credit_record.id IS NOT NULL THEN
            -- a. Reducimos la deuda y aseguramos que no caiga debajo de 0
            v_new_debt := GREATEST(0, v_credit_record.current_debt - p_order_amount);

            UPDATE supplier_credits
            SET current_debt = v_new_debt,
                updated_at = NOW()
            WHERE id = v_credit_record.id;
        END IF;
    END IF;

    -- 5. Actualizar método en purchase_orders
    UPDATE purchase_orders
    SET payment_method = p_new_method,
        updated_at = NOW()
    WHERE id = p_order_id;

    -- 6. Confirmación de éxito
    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."update_po_payment_method_rpc"("p_order_id" "uuid", "p_supplier_id" "uuid", "p_new_method" "text", "p_old_method" "text", "p_order_amount" numeric, "p_profile_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_has_permission"("p_permission_code" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles pr
    JOIN public.user_roles ur ON ur.profile_id = pr.id
    JOIN public.roles r ON r.id = ur.role_id
    LEFT JOIN public.role_permissions rp ON rp.role_id = r.id
    LEFT JOIN public.permissions p ON p.id = rp.permission_id
    WHERE pr.auth_user_id = auth.uid()
      AND (
        LOWER(r.name) IN ('admin', 'administrador')
        OR p.code = p_permission_code
      )
  );
$$;


ALTER FUNCTION "public"."user_has_permission"("p_permission_code" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."account_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "account_id" "uuid" NOT NULL,
    "movement_type" "text" NOT NULL,
    "amount" numeric(14,2) NOT NULL,
    "description" "text" NOT NULL,
    "reference_type" "text",
    "reference_id" "uuid",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "shift_id" "uuid",
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "exchange_rate" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "amount_base" numeric(14,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT "account_movements_exchange_rate_pos" CHECK (("exchange_rate" > (0)::numeric)),
    CONSTRAINT "account_movements_movement_type_check" CHECK (("movement_type" = ANY (ARRAY['INCOME'::"text", 'EXPENSE'::"text", 'TRANSFER_IN'::"text", 'TRANSFER_OUT'::"text", 'ADJUSTMENT'::"text"])))
);


ALTER TABLE "public"."account_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accounting_periods" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "year" integer NOT NULL,
    "month" integer NOT NULL,
    "status" "text" DEFAULT 'OPEN'::"text" NOT NULL,
    "closed_by" "uuid",
    "closed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "accounting_periods_month_check" CHECK ((("month" >= 1) AND ("month" <= 12))),
    CONSTRAINT "accounting_periods_status_check" CHECK (("status" = ANY (ARRAY['OPEN'::"text", 'CLOSED'::"text"]))),
    CONSTRAINT "accounting_periods_year_check" CHECK ((("year" >= 2020) AND ("year" <= 2100)))
);


ALTER TABLE "public"."accounting_periods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accounting_posting_rule_lines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rule_id" "uuid" NOT NULL,
    "line_order" integer DEFAULT 1 NOT NULL,
    "account_code" "text" NOT NULL,
    "side" "text" NOT NULL,
    "amount_source" "text" NOT NULL,
    "description_template" "text",
    CONSTRAINT "accounting_posting_rule_lines_amount_source_check" CHECK (("amount_source" = ANY (ARRAY['TOTAL'::"text", 'SUBTOTAL'::"text", 'TAX'::"text", 'COGS'::"text", 'DISCOUNT'::"text"]))),
    CONSTRAINT "accounting_posting_rule_lines_side_check" CHECK (("side" = ANY (ARRAY['DEBIT'::"text", 'CREDIT'::"text"])))
);


ALTER TABLE "public"."accounting_posting_rule_lines" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accounting_posting_rules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_code" "text" NOT NULL,
    "description" "text" NOT NULL,
    "debit_account_code" "text",
    "credit_account_code" "text",
    "tax_account_code" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "accounting_posting_rules_mode_check" CHECK (((("debit_account_code" IS NOT NULL) AND ("credit_account_code" IS NOT NULL)) OR (("debit_account_code" IS NULL) AND ("credit_account_code" IS NULL))))
);


ALTER TABLE "public"."accounting_posting_rules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."active_ingredients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "search_vector" "tsvector" GENERATED ALWAYS AS ("to_tsvector"('"spanish"'::"regconfig", "name")) STORED,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."active_ingredients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."app_settings" (
    "key" "text" NOT NULL,
    "value" numeric,
    "description" "text",
    "value_text" "text",
    "value_type" "text" DEFAULT 'NUMERIC'::"text" NOT NULL,
    CONSTRAINT "app_settings_value_type_check" CHECK (("value_type" = ANY (ARRAY['NUMERIC'::"text", 'TEXT'::"text", 'BOOLEAN'::"text", 'JSON'::"text"])))
);


ALTER TABLE "public"."app_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."attribute_values" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "attribute_id" "uuid" NOT NULL,
    "value" "text" NOT NULL
);


ALTER TABLE "public"."attribute_values" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."attributes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text"
);


ALTER TABLE "public"."attributes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."audit_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "table_name" "text" NOT NULL,
    "record_id" "uuid",
    "action" "text" NOT NULL,
    "old_data" "jsonb",
    "new_data" "jsonb",
    "changed_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "audit_logs_action_check" CHECK (("action" = ANY (ARRAY['INSERT'::"text", 'UPDATE'::"text", 'DELETE'::"text"])))
);


ALTER TABLE "public"."audit_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."brands" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "logo_url" "text",
    "website" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."brands" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."business_info" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "business_name" "text" NOT NULL,
    "tax_id" "text",
    "address" "text",
    "phone" "text",
    "logo_url" "text",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "loyalty_global_enabled" boolean DEFAULT true,
    "loyalty_customer_visible" boolean DEFAULT true,
    "raffles_global_enabled" boolean DEFAULT false,
    "raffles_customer_visible" boolean DEFAULT false,
    "cash_register_mode" character varying(20) DEFAULT 'COUNTER'::character varying
);


ALTER TABLE "public"."business_info" OWNER TO "postgres";


COMMENT ON COLUMN "public"."business_info"."cash_register_mode" IS 'Modalidad de control de caja: COUNTER (Caja por mostrador/sucursal) o INDIVIDUAL (Caja por cajero).';



CREATE TABLE IF NOT EXISTS "public"."cart_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cart_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "variant_id" "uuid",
    "quantity" numeric(12,4) DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_selected" boolean DEFAULT true,
    CONSTRAINT "cart_items_quantity_check" CHECK (("quantity" > (0)::numeric))
);


ALTER TABLE "public"."cart_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cash_shifts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "account_id" "uuid" NOT NULL,
    "opened_by" "uuid" NOT NULL,
    "closed_by" "uuid",
    "opened_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "closed_at" timestamp with time zone,
    "opening_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "expected_amount" numeric(14,2),
    "actual_amount" numeric(14,2),
    "difference_amount" numeric(14,2),
    "status" "text" DEFAULT 'OPEN'::"text" NOT NULL,
    "notes" "text",
    CONSTRAINT "cash_shifts_status_check" CHECK (("status" = ANY (ARRAY['OPEN'::"text", 'CLOSED'::"text"])))
);


ALTER TABLE "public"."cash_shifts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid",
    "default_tax_affectation_type" "text" DEFAULT '10'::"text" NOT NULL,
    "default_tax_rate" numeric(5,2) DEFAULT 18.00 NOT NULL,
    CONSTRAINT "categories_tax_affectation_check" CHECK (("default_tax_affectation_type" = ANY (ARRAY['10'::"text", '11'::"text", '12'::"text", '13'::"text", '14'::"text", '15'::"text", '16'::"text", '17'::"text", '20'::"text", '21'::"text", '30'::"text", '31'::"text", '32'::"text", '33'::"text", '34'::"text", '35'::"text", '36'::"text", '37'::"text", '40'::"text"]))),
    CONSTRAINT "categories_tax_rate_range" CHECK ((("default_tax_rate" >= (0)::numeric) AND ("default_tax_rate" <= (100)::numeric)))
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."chart_of_accounts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "account_type" "text" NOT NULL,
    "parent_code" "text",
    "is_postable" boolean DEFAULT true NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chart_of_accounts_account_type_check" CHECK (("account_type" = ANY (ARRAY['ASSET'::"text", 'LIABILITY'::"text", 'EQUITY'::"text", 'REVENUE'::"text", 'EXPENSE'::"text"])))
);


ALTER TABLE "public"."chart_of_accounts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."currencies" (
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "symbol" "text" NOT NULL,
    "suggested_exchange_rate" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "is_base" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "decimal_places" integer DEFAULT 2 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."currencies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_credit_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "customer_credit_id" "uuid" NOT NULL,
    "order_id" "uuid",
    "movement_type" "text" NOT NULL,
    "amount" numeric(14,2) NOT NULL,
    "payment_method" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    CONSTRAINT "credit_movements_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "credit_movements_movement_type_check" CHECK (("movement_type" = ANY (ARRAY['CHARGE'::"text", 'PAYMENT'::"text", 'REFUND'::"text", 'ADJUSTMENT'::"text"])))
);


ALTER TABLE "public"."customer_credit_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "customer_id" "uuid",
    "total_amount" numeric(14,2) DEFAULT 0 NOT NULL,
    "total_profit" numeric(14,2) DEFAULT 0 NOT NULL,
    "payment_method" "text" DEFAULT 'EFECTIVO'::"text" NOT NULL,
    "status" "text" DEFAULT 'COMPLETED'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "warehouse_id" "uuid",
    "points_used" integer DEFAULT 0 NOT NULL,
    "points_earned" integer DEFAULT 0 NOT NULL,
    "customer_name" "text" DEFAULT ''::"text",
    "payment_status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "amount_paid" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "due_date" timestamp with time zone,
    "created_by" "uuid",
    "discount_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "document_type" "text" DEFAULT 'NINGUNO'::"text",
    "document_number" "text",
    "document_date" "date",
    "updated_by" "uuid",
    "updated_at" timestamp with time zone,
    "document_series" "text",
    "tax_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "subtotal_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "customer_document_type" "text",
    "customer_document_number" "text",
    "customer_address" "text",
    "payment_reference" "text",
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "exchange_rate" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "total_amount_base" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "subtotal_amount_base" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "tax_amount_base" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "customer_record_id" "uuid",
    "total_gravado" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "total_exonerado" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "total_inafecto" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "total_gratuito" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "icbper_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "detraction_code" "text",
    "detraction_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "detraction_percentage" numeric(5,2) DEFAULT 0.00 NOT NULL,
    "detraction_account_number" "text",
    "shipping_cost" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "delivery_location_id" "uuid",
    "delivery_address_snapshot" "text",
    "fulfillment_status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    CONSTRAINT "orders_detraction_percentage_check" CHECK ((("detraction_percentage" >= (0)::numeric) AND ("detraction_percentage" <= (100)::numeric))),
    CONSTRAINT "orders_document_type_check" CHECK (("document_type" = ANY (ARRAY['NOTA_VENTA'::"text", 'BOLETA'::"text", 'FACTURA'::"text", 'TICKET'::"text", 'NINGUNO'::"text"]))),
    CONSTRAINT "orders_exchange_rate_pos" CHECK (("exchange_rate" > (0)::numeric)),
    CONSTRAINT "orders_fulfillment_status_check" CHECK (("fulfillment_status" = ANY (ARRAY['PENDING'::"text", 'PACKING'::"text", 'READY'::"text", 'DISPATCHED'::"text", 'DELIVERED'::"text", 'CANCELLED'::"text"]))),
    CONSTRAINT "orders_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['PAID'::"text", 'PENDING'::"text", 'PARTIAL'::"text"]))),
    CONSTRAINT "orders_shipping_cost_check" CHECK (("shipping_cost" >= (0)::numeric))
);


ALTER TABLE "public"."orders" OWNER TO "postgres";


COMMENT ON COLUMN "public"."orders"."customer_id" IS 'TRANSICIÓN: FK legado hacia public.profiles; sincronizado vía trigger con customer_record_id.';



COMMENT ON COLUMN "public"."orders"."customer_record_id" IS 'FK canónica hacia public.customers (usar en nuevos flujos).';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "auth_user_id" "uuid",
    "full_name" "text" NOT NULL,
    "avatar_url" "text",
    "phone" "text",
    "document_type" "text" DEFAULT 'DNI'::"text",
    "document_number" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_active" boolean DEFAULT true NOT NULL,
    "wallet_balance" integer DEFAULT 0 NOT NULL,
    "birthdate" "date"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."birthdate" IS 'Fecha de nacimiento del usuario para felicitaciones y métricas corporativas';



CREATE OR REPLACE VIEW "public"."customer_credit_movements_summary" WITH ("security_invoker"='true') AS
 SELECT "cm"."id",
    "cm"."customer_credit_id",
    "cm"."order_id",
    "cm"."movement_type",
    "cm"."amount",
    "cm"."payment_method",
    "cm"."notes",
    "cm"."created_at",
    "cm"."created_by",
    "p"."full_name" AS "created_by_name",
    "o"."customer_name",
    "o"."payment_method" AS "order_payment_method",
    "o"."total_amount" AS "order_total_amount",
    COALESCE(NULLIF("o"."document_number", ''::"text"),
        CASE
            WHEN ("o"."document_series" IS NOT NULL) THEN (("o"."document_series" || '-'::"text") || "left"(("o"."id")::"text", 8))
            ELSE ('#'::"text" || "left"(("o"."id")::"text", 8))
        END) AS "order_number"
   FROM (("public"."customer_credit_movements" "cm"
     LEFT JOIN "public"."profiles" "p" ON (("p"."id" = "cm"."created_by")))
     LEFT JOIN "public"."orders" "o" ON (("o"."id" = "cm"."order_id")));


ALTER VIEW "public"."customer_credit_movements_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_credits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid",
    "credit_limit" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "current_debt" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "customer_record_id" "uuid",
    "credit_balance" numeric(14,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT "customer_credits_credit_balance_check" CHECK (("credit_balance" >= (0)::numeric)),
    CONSTRAINT "customer_credits_current_debt_check" CHECK (("current_debt" >= (0)::numeric)),
    CONSTRAINT "customer_credits_owner_check" CHECK ((("profile_id" IS NOT NULL) OR ("customer_record_id" IS NOT NULL)))
);


ALTER TABLE "public"."customer_credits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_locations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid",
    "name" "text" NOT NULL,
    "location_type" "text" DEFAULT 'otro'::"text" NOT NULL,
    "latitude" double precision NOT NULL,
    "longitude" double precision NOT NULL,
    "address_line" "text",
    "reference" "text",
    "notes" "text",
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "customer_record_id" "uuid",
    CONSTRAINT "customer_locations_owner_check" CHECK ((("profile_id" IS NOT NULL) OR ("customer_record_id" IS NOT NULL))),
    CONSTRAINT "customer_locations_type_check" CHECK (("location_type" = ANY (ARRAY['casa'::"text", 'chacra'::"text", 'fundo'::"text", 'local'::"text", 'otro'::"text"])))
);


ALTER TABLE "public"."customer_locations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid",
    "customer_type" "text" DEFAULT 'PERSON'::"text" NOT NULL,
    "document_type" "text" DEFAULT 'DNI'::"text",
    "document_number" "text",
    "full_name" "text" NOT NULL,
    "trade_name" "text",
    "email" "text",
    "phone" "text",
    "address" "text",
    "tax_condition" "text" DEFAULT 'HABIDO'::"text",
    "is_active" boolean DEFAULT true NOT NULL,
    "wallet_balance" integer DEFAULT 0 NOT NULL,
    "created_by" "uuid",
    "updated_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "customers_customer_type_check" CHECK (("customer_type" = ANY (ARRAY['PERSON'::"text", 'COMPANY'::"text"]))),
    CONSTRAINT "customers_document_type_check" CHECK (("document_type" = ANY (ARRAY['DNI'::"text", 'RUC'::"text", 'CE'::"text", 'PASAPORTE'::"text", 'OTRO'::"text"])))
);


ALTER TABLE "public"."customers" OWNER TO "postgres";


COMMENT ON TABLE "public"."customers" IS 'Entidad canónica de clientes ERP (personas y empresas RUC/DNI). profile_id es opcional para clientes con cuenta en tienda online.';



CREATE TABLE IF NOT EXISTS "public"."daily_checkins" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "checkin_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "points_received" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "streak_day" integer DEFAULT 1
);


ALTER TABLE "public"."daily_checkins" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dispatch_guide_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "dispatch_guide_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "unit_code" "text" DEFAULT 'NIU'::"text" NOT NULL,
    "quantity" numeric(12,4) NOT NULL,
    "description" "text" NOT NULL,
    "gross_weight_kg" numeric(12,3) DEFAULT 0.000,
    CONSTRAINT "dispatch_guide_items_quantity_check" CHECK (("quantity" > (0)::numeric))
);


ALTER TABLE "public"."dispatch_guide_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dispatch_guides" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "electronic_document_id" "uuid",
    "transfer_id" "uuid",
    "order_id" "uuid",
    "series" "text" NOT NULL,
    "correlative" "text" NOT NULL,
    "issue_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "start_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "transfer_reason_code" "text" DEFAULT '01'::"text" NOT NULL,
    "transport_mode" "text" DEFAULT '02'::"text" NOT NULL,
    "gross_weight_kg" numeric(12,3) DEFAULT 0.000 NOT NULL,
    "packages_count" integer DEFAULT 1 NOT NULL,
    "carrier_ruc" "text",
    "carrier_name" "text",
    "driver_document_number" "text",
    "driver_license_number" "text",
    "vehicle_plate" "text",
    "origin_ubigeo" "text",
    "origin_address" "text" NOT NULL,
    "dest_ubigeo" "text",
    "dest_address" "text" NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "sender_document_type" "text" DEFAULT 'RUC'::"text",
    "sender_document_number" "text",
    "sender_name" "text",
    "recipient_document_type" "text",
    "recipient_document_number" "text",
    "recipient_name" "text",
    CONSTRAINT "dispatch_guides_reason_check" CHECK (("transfer_reason_code" = ANY (ARRAY['01'::"text", '02'::"text", '03'::"text", '04'::"text", '05'::"text", '06'::"text", '07'::"text", '08'::"text", '09'::"text", '13'::"text", '14'::"text", '17'::"text", '18'::"text"]))),
    CONSTRAINT "dispatch_guides_source_check" CHECK ((("electronic_document_id" IS NOT NULL) OR ("transfer_id" IS NOT NULL) OR ("order_id" IS NOT NULL))),
    CONSTRAINT "dispatch_guides_transport_mode_check" CHECK (("transport_mode" = ANY (ARRAY['01'::"text", '02'::"text"])))
);


ALTER TABLE "public"."dispatch_guides" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."document_series" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "document_type" "text" NOT NULL,
    "series" "text" NOT NULL,
    "current_correlative" integer DEFAULT 0 NOT NULL,
    "correlative_padding" integer DEFAULT 8 NOT NULL,
    "is_default" boolean DEFAULT true,
    "is_active" boolean DEFAULT true,
    "warehouse_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "document_series_type_check" CHECK (("document_type" = ANY (ARRAY['NOTA_VENTA'::"text", 'BOLETA'::"text", 'FACTURA'::"text", 'TICKET'::"text", 'NOTA_CREDITO'::"text", 'NOTA_DEBITO'::"text", 'COTIZACION'::"text", 'GUIA_REMISION'::"text"])))
);


ALTER TABLE "public"."document_series" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."electronic_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid",
    "sales_return_id" "uuid",
    "document_type" "text" NOT NULL,
    "series" "text" NOT NULL,
    "correlative" "text" NOT NULL,
    "sunat_status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "hash_cpe" "text",
    "xml_url" "text",
    "cdr_url" "text",
    "pdf_url" "text",
    "sunat_response_code" "text",
    "sunat_response_message" "text",
    "sent_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "issue_date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "customer_snapshot" "jsonb",
    "is_active" boolean DEFAULT true NOT NULL,
    "reference_document_id" "uuid",
    "reference_document_type" "text",
    "reference_series" "text",
    "reference_correlative" "text",
    "dispatch_guide_id" "uuid",
    CONSTRAINT "electronic_documents_document_type_check" CHECK (("document_type" = ANY (ARRAY['BOLETA'::"text", 'FACTURA'::"text", 'NOTA_CREDITO'::"text", 'NOTA_DEBITO'::"text", 'GUIA_REMISION'::"text"]))),
    CONSTRAINT "electronic_documents_source_check" CHECK ((("order_id" IS NOT NULL) OR ("sales_return_id" IS NOT NULL) OR ("dispatch_guide_id" IS NOT NULL))),
    CONSTRAINT "electronic_documents_sunat_status_check" CHECK (("sunat_status" = ANY (ARRAY['PENDING'::"text", 'SENT'::"text", 'ACCEPTED'::"text", 'OBSERVED'::"text", 'REJECTED'::"text", 'VOIDED'::"text"])))
);


ALTER TABLE "public"."electronic_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."exchange_rates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "currency_code" "text" NOT NULL,
    "rate_date" "date" NOT NULL,
    "buy_rate" numeric(12,4) NOT NULL,
    "sell_rate" numeric(12,4) NOT NULL,
    "source" "text" DEFAULT 'SUNAT'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "exchange_rates_buy_rate_check" CHECK (("buy_rate" > (0)::numeric)),
    CONSTRAINT "exchange_rates_sell_rate_check" CHECK (("sell_rate" > (0)::numeric))
);


ALTER TABLE "public"."exchange_rates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expense_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."expense_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expenses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "category_id" "uuid",
    "warehouse_id" "uuid",
    "supplier_id" "uuid",
    "account_id" "uuid" NOT NULL,
    "shift_id" "uuid",
    "description" "text" NOT NULL,
    "document_type" "text",
    "document_number" "text",
    "expense_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "exchange_rate" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "amount_base" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "status" "text" DEFAULT 'PAID'::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "expenses_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "expenses_status_check" CHECK (("status" = ANY (ARRAY['PAID'::"text", 'CANCELLED'::"text"])))
);


ALTER TABLE "public"."expenses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."financial_accounts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "type" "text" NOT NULL,
    "balance" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "warehouse_id" "uuid"
);


ALTER TABLE "public"."financial_accounts" OWNER TO "postgres";


COMMENT ON COLUMN "public"."financial_accounts"."warehouse_id" IS 'ID del almacén o sucursal al que pertenece la caja física. NULL para cuentas centralizadas (bancos, billeteras digitales).';



CREATE TABLE IF NOT EXISTS "public"."import_batches" (
    "batch_id" "text" NOT NULL,
    "result" "jsonb" NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."import_batches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_entries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "supplier_id" "uuid",
    "purchase_order_id" "uuid",
    "document_type" "text" DEFAULT 'NINGUNO'::"text",
    "document_number" "text",
    "document_date" "date",
    "total_amount" numeric(14,2) DEFAULT 0 NOT NULL,
    "payment_mode" "text",
    "account_id" "uuid",
    "shift_id" "uuid",
    "status" "text" DEFAULT 'COMPLETED'::"text",
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "exchange_rate" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "total_amount_base" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "guide_number" "text",
    "received_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventory_entries" OWNER TO "postgres";


COMMENT ON COLUMN "public"."inventory_entries"."payment_mode" IS 'DEPRECATED: Los pagos deben gestionarse en purchase_orders y cuentas por pagar.';



COMMENT ON COLUMN "public"."inventory_entries"."account_id" IS 'DEPRECATED: La recepción física no debe mover cuentas financieras.';



COMMENT ON COLUMN "public"."inventory_entries"."shift_id" IS 'DEPRECATED: La recepción física no depende de turnos de caja.';



CREATE TABLE IF NOT EXISTS "public"."inventory_entry_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entry_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "quantity" numeric NOT NULL,
    "unit_cost" numeric(14,4) NOT NULL,
    "batch_number" "text" DEFAULT 'DEFAULT'::"text",
    "expiry_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "unit_cost_base" numeric DEFAULT 0.00 NOT NULL,
    CONSTRAINT "inventory_entry_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "inventory_entry_items_unit_cost_check" CHECK (("unit_cost" >= (0)::numeric))
);


ALTER TABLE "public"."inventory_entry_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_exit_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "exit_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "quantity" numeric NOT NULL,
    "batch_number" "text" DEFAULT 'DEFAULT'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "unit_cost" numeric(14,4) DEFAULT 0,
    CONSTRAINT "inventory_exit_items_quantity_check" CHECK (("quantity" > (0)::numeric))
);


ALTER TABLE "public"."inventory_exit_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_exits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "reason" "text",
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventory_exits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "stock_batch_id" "uuid",
    "order_id" "uuid",
    "inventory_entry_id" "uuid",
    "inventory_exit_id" "uuid",
    "physical_inventory_id" "uuid",
    "quantity" numeric NOT NULL,
    "previous_stock" numeric NOT NULL,
    "new_stock" numeric NOT NULL,
    "unit_cost" numeric,
    "total_cost" numeric,
    "reason" "text" NOT NULL,
    "notes" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "exchange_rate" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "transfer_id" "uuid",
    "sales_return_id" "uuid",
    CONSTRAINT "inventory_movements_exchange_rate_pos" CHECK (("exchange_rate" > (0)::numeric))
);


ALTER TABLE "public"."inventory_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."journal_entries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entry_number" "text",
    "entry_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "description" "text" NOT NULL,
    "reference_type" "text",
    "reference_id" "uuid",
    "status" "text" DEFAULT 'POSTED'::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "period_id" "uuid",
    CONSTRAINT "journal_entries_status_check" CHECK (("status" = ANY (ARRAY['DRAFT'::"text", 'POSTED'::"text", 'VOIDED'::"text"])))
);


ALTER TABLE "public"."journal_entries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."journal_entry_lines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "journal_entry_id" "uuid" NOT NULL,
    "account_code" "text" NOT NULL,
    "description" "text",
    "debit" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "credit" numeric(14,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT "journal_entry_lines_check" CHECK (((("debit" > (0)::numeric) AND ("credit" = (0)::numeric)) OR (("credit" > (0)::numeric) AND ("debit" = (0)::numeric)))),
    CONSTRAINT "journal_entry_lines_credit_check" CHECK (("credit" >= (0)::numeric)),
    CONSTRAINT "journal_entry_lines_debit_check" CHECK (("debit" >= (0)::numeric))
);


ALTER TABLE "public"."journal_entry_lines" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."order_installments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "installment_number" integer NOT NULL,
    "due_date" "date" NOT NULL,
    "amount" numeric(14,2) NOT NULL,
    "status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "paid_at" timestamp with time zone,
    CONSTRAINT "order_installments_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "order_installments_installment_number_check" CHECK (("installment_number" > 0)),
    CONSTRAINT "order_installments_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'PAID'::"text", 'OVERDUE'::"text"])))
);


ALTER TABLE "public"."order_installments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "quantity" numeric(12,4) DEFAULT 1 NOT NULL,
    "unit_cost" numeric(14,4) NOT NULL,
    "applied_price" numeric(14,4) NOT NULL,
    "net_profit" numeric(14,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "variant_id" "uuid" NOT NULL,
    "applied_price_base" numeric(14,4) DEFAULT 0.00 NOT NULL,
    "unit_cost_base" numeric(14,4) DEFAULT 0.00 NOT NULL,
    "tax_affectation_type" "text" DEFAULT '10'::"text" NOT NULL,
    "discount_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "unit_value_without_tax" numeric(12,4) DEFAULT 0.0000 NOT NULL,
    "tax_rate" numeric(5,2) DEFAULT 18.00 NOT NULL,
    "tax_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "tax_amount_base" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "unit_code" "text" DEFAULT 'NIU'::"text" NOT NULL,
    "conversion_factor" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "quantity_base" numeric(14,4) GENERATED ALWAYS AS (("quantity" * "conversion_factor")) STORED,
    "icbper_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT "order_items_conversion_factor_check" CHECK (("conversion_factor" > (0)::numeric)),
    CONSTRAINT "order_items_quantity_positive" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "order_items_tax_affectation_check" CHECK (("tax_affectation_type" = ANY (ARRAY['10'::"text", '11'::"text", '12'::"text", '13'::"text", '14'::"text", '15'::"text", '16'::"text", '17'::"text", '20'::"text", '21'::"text", '30'::"text", '31'::"text", '32'::"text", '33'::"text", '34'::"text", '35'::"text", '36'::"text", '37'::"text", '40'::"text"]))),
    CONSTRAINT "order_items_tax_rate_range" CHECK ((("tax_rate" >= (0)::numeric) AND ("tax_rate" <= (100)::numeric)))
);


ALTER TABLE "public"."order_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."order_payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "account_id" "uuid",
    "shift_id" "uuid",
    "amount" numeric(14,2) NOT NULL,
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "exchange_rate" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "amount_base" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "reference_number" "text",
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "payment_method_code" "text" DEFAULT 'EFECTIVO'::"text" NOT NULL,
    CONSTRAINT "order_payments_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "order_payments_exchange_rate_pos" CHECK (("exchange_rate" > (0)::numeric))
);


ALTER TABLE "public"."order_payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."order_status_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "previous_status" "text",
    "new_status" "text" NOT NULL,
    "notes" "text",
    "changed_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."order_status_history" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."partner_credit_summary" WITH ("security_invoker"='true') AS
 SELECT "cc"."id" AS "credit_id",
    "cc"."profile_id",
    COALESCE("c"."full_name", "p"."full_name") AS "partner_name",
    COALESCE("c"."document_number", "p"."document_number") AS "partner_document",
    COALESCE("c"."document_type", "p"."document_type") AS "partner_document_type",
    COALESCE("c"."phone", "p"."phone") AS "partner_phone",
    "cc"."credit_limit",
    "cc"."current_debt",
    GREATEST(("cc"."credit_limit" - "cc"."current_debt"), (0)::numeric) AS "available_credit",
    "cc"."is_active",
    "cc"."customer_record_id",
    "cc"."credit_balance"
   FROM (("public"."customer_credits" "cc"
     LEFT JOIN "public"."customers" "c" ON (("c"."id" = "cc"."customer_record_id")))
     LEFT JOIN "public"."profiles" "p" ON (("p"."id" = "cc"."profile_id")));


ALTER VIEW "public"."partner_credit_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_methods" (
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "method_type" "text" NOT NULL,
    "default_account_id" "uuid",
    "requires_reference" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "payment_methods_method_type_check" CHECK (("method_type" = ANY (ARRAY['CASH'::"text", 'DIGITAL'::"text", 'CARD'::"text", 'TRANSFER'::"text", 'CREDIT'::"text"])))
);


ALTER TABLE "public"."payment_methods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."permissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "module" "text" NOT NULL
);


ALTER TABLE "public"."permissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."physical_inventories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone,
    CONSTRAINT "physical_inventories_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'COMPLETED'::"text", 'CANCELLED'::"text"])))
);


ALTER TABLE "public"."physical_inventories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."physical_inventory_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "physical_inventory_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "batch_number" "text",
    "expiry_date" "date",
    "system_quantity" numeric NOT NULL,
    "counted_quantity" numeric,
    "difference" numeric,
    "unit_cost" numeric,
    "total_difference_cost" numeric,
    "notes" "text",
    "counted_by" "uuid",
    "counted_at" timestamp with time zone
);


ALTER TABLE "public"."physical_inventory_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."price_list_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "price_list_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "unit_code" "text" DEFAULT 'NIU'::"text" NOT NULL,
    "min_quantity" numeric(12,4) DEFAULT 1 NOT NULL,
    "price" numeric(12,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "price_list_items_min_quantity_check" CHECK (("min_quantity" > (0)::numeric)),
    CONSTRAINT "price_list_items_price_check" CHECK (("price" >= (0)::numeric))
);


ALTER TABLE "public"."price_list_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."price_lists" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "valid_from" timestamp with time zone,
    "valid_to" timestamp with time zone,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."price_lists" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_active_ingredients" (
    "product_id" "uuid" NOT NULL,
    "ingredient_id" "uuid" NOT NULL,
    "concentration" numeric,
    "unit" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."product_active_ingredients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_images" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "variant_id" "uuid",
    "image_url" "text" NOT NULL,
    "display_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_main" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."product_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "profile_id" "uuid",
    "user_name" "text" DEFAULT 'Usuario Anónimo'::"text" NOT NULL,
    "rating" integer NOT NULL,
    "comment" "text",
    "images" "text"[] DEFAULT '{}'::"text"[],
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "product_reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."product_reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_variants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "sku" "text",
    "sale_price" numeric(14,4),
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "reorder_point" integer DEFAULT 3 NOT NULL,
    "wholesale_price" numeric(14,4),
    "wholesale_min_quantity" integer,
    "created_by" "uuid",
    "updated_by" "uuid",
    "unit_cost" numeric(14,4) DEFAULT 0 NOT NULL,
    "barcode" "text",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "costing_method" "text" DEFAULT 'WEIGHTED_AVG'::"text" NOT NULL,
    "base_unit_code" "text" DEFAULT 'NIU'::"text" NOT NULL,
    CONSTRAINT "product_variants_costing_method_check" CHECK (("costing_method" = ANY (ARRAY['WEIGHTED_AVG'::"text", 'STANDARD'::"text"])))
);


ALTER TABLE "public"."product_variants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."warehouse_stock_batches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "batch_number" "text" DEFAULT 'DEFAULT'::"text" NOT NULL,
    "expiry_date" "date",
    "available_quantity" numeric DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid",
    "product_id" "uuid" NOT NULL,
    "supplier_id" "uuid",
    CONSTRAINT "wsb_available_quantity_non_negative" CHECK (("available_quantity" >= (0)::numeric))
);


ALTER TABLE "public"."warehouse_stock_batches" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."product_stock_summary" WITH ("security_invoker"='true') AS
 SELECT "pv"."product_id",
    "pv"."id" AS "variant_id",
    COALESCE("sum"("wsb"."available_quantity"), (0)::numeric) AS "total_stock"
   FROM ("public"."product_variants" "pv"
     LEFT JOIN "public"."warehouse_stock_batches" "wsb" ON (("pv"."id" = "wsb"."variant_id")))
  GROUP BY "pv"."product_id", "pv"."id";


ALTER VIEW "public"."product_stock_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_unit_conversions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "unit_code" "text" NOT NULL,
    "conversion_factor" numeric(12,4) NOT NULL,
    "barcode" "text",
    "sale_price" numeric(12,2),
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "product_unit_conversions_conversion_factor_check" CHECK (("conversion_factor" > (0)::numeric))
);


ALTER TABLE "public"."product_unit_conversions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "category_id" "uuid",
    "description" "text",
    "updated_at" timestamp with time zone,
    "details" "jsonb" DEFAULT '{}'::"jsonb",
    "created_by" "uuid",
    "updated_by" "uuid",
    "stock_control" boolean DEFAULT true NOT NULL,
    "uses_batches" boolean DEFAULT false NOT NULL,
    "product_type" "text" DEFAULT 'good'::"text" NOT NULL,
    "brand_id" "uuid",
    "tax_affectation_type" "text" DEFAULT '10'::"text" NOT NULL,
    "tax_rate" numeric(5,2) DEFAULT 18.00 NOT NULL,
    "sunat_product_code" "text",
    CONSTRAINT "products_product_type_check" CHECK (("product_type" = ANY (ARRAY['good'::"text", 'service'::"text", 'digital'::"text"]))),
    CONSTRAINT "products_tax_affectation_check" CHECK (("tax_affectation_type" = ANY (ARRAY['10'::"text", '11'::"text", '12'::"text", '13'::"text", '14'::"text", '15'::"text", '16'::"text", '17'::"text", '20'::"text", '21'::"text", '30'::"text", '31'::"text", '32'::"text", '33'::"text", '34'::"text", '35'::"text", '36'::"text", '37'::"text", '40'::"text"]))),
    CONSTRAINT "products_tax_rate_range" CHECK ((("tax_rate" >= (0)::numeric) AND ("tax_rate" <= (100)::numeric)))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purchase_invoice_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "purchase_invoice_id" "uuid" NOT NULL,
    "variant_id" "uuid",
    "description" "text" NOT NULL,
    "quantity" numeric(12,4) NOT NULL,
    "unit_cost" numeric(14,4) NOT NULL,
    "tax_affectation_type" "text" DEFAULT '10'::"text" NOT NULL,
    "tax_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "subtotal" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "purchase_order_item_id" "uuid",
    "inventory_entry_item_id" "uuid",
    CONSTRAINT "purchase_invoice_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "purchase_invoice_items_unit_cost_check" CHECK (("unit_cost" >= (0)::numeric))
);


ALTER TABLE "public"."purchase_invoice_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purchase_invoice_payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "purchase_invoice_id" "uuid" NOT NULL,
    "account_id" "uuid" NOT NULL,
    "shift_id" "uuid",
    "payment_method_code" "text" DEFAULT 'TRANSFERENCIA'::"text" NOT NULL,
    "amount" numeric(14,2) NOT NULL,
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "exchange_rate" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "amount_base" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "reference_number" "text",
    "paid_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "purchase_invoice_payments_amount_check" CHECK (("amount" > (0)::numeric))
);


ALTER TABLE "public"."purchase_invoice_payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purchase_invoices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "purchase_order_id" "uuid",
    "supplier_id" "uuid" NOT NULL,
    "document_type" "text" NOT NULL,
    "series" "text" NOT NULL,
    "document_number" "text" NOT NULL,
    "issue_date" "date" NOT NULL,
    "due_date" "date",
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "exchange_rate" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "taxable_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "tax_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "exempt_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "total_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "amount_paid" numeric(14,2) DEFAULT 0.00 NOT NULL,
    "payment_status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "purchase_invoices_document_type_check" CHECK (("document_type" = ANY (ARRAY['FACTURA'::"text", 'BOLETA'::"text", 'RECIBO_HONORARIOS'::"text", 'NOTA_CREDITO'::"text", 'OTRO'::"text"]))),
    CONSTRAINT "purchase_invoices_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['PENDING'::"text", 'PARTIAL'::"text", 'PAID'::"text", 'CANCELLED'::"text"])))
);


ALTER TABLE "public"."purchase_invoices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purchase_order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "purchase_order_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "variant_id" "uuid" NOT NULL,
    "quantity_ordered" numeric NOT NULL,
    "quantity_received" numeric DEFAULT 0 NOT NULL,
    "unit_cost" numeric(14,4) NOT NULL,
    "net_cost" numeric DEFAULT 0 NOT NULL,
    "batch_number" "text" DEFAULT 'DEFAULT'::"text",
    "expiry_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "subtotal" numeric DEFAULT 0,
    "unit_cost_base" numeric DEFAULT 0.00 NOT NULL,
    CONSTRAINT "purchase_order_items_quantity_ordered_check" CHECK (("quantity_ordered" > (0)::numeric)),
    CONSTRAINT "purchase_order_items_unit_cost_check" CHECK (("unit_cost" >= (0)::numeric))
);


ALTER TABLE "public"."purchase_order_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purchase_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "supplier_id" "uuid",
    "supplier_name" "text" DEFAULT ''::"text" NOT NULL,
    "warehouse_id" "uuid",
    "status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "total_amount" numeric(14,2) DEFAULT 0 NOT NULL,
    "payment_method" "text" DEFAULT 'EFECTIVO'::"text" NOT NULL,
    "payment_status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "amount_paid" numeric(14,2) DEFAULT 0 NOT NULL,
    "due_date" timestamp with time zone,
    "discount_amount" numeric(14,2) DEFAULT 0 NOT NULL,
    "document_type" "text" DEFAULT 'NINGUNO'::"text",
    "document_number" "text",
    "document_date" "date",
    "tax_amount" numeric(14,2) DEFAULT 0 NOT NULL,
    "notes" "text",
    "created_by" "uuid",
    "updated_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "exchange_rate" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "total_amount_base" numeric DEFAULT 0.00 NOT NULL,
    "subtotal_amount_base" numeric DEFAULT 0.00 NOT NULL,
    "tax_amount_base" numeric DEFAULT 0.00 NOT NULL,
    CONSTRAINT "purchase_orders_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['PAID'::"text", 'PENDING'::"text", 'PARTIAL'::"text"]))),
    CONSTRAINT "purchase_orders_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'SENT'::"text", 'PARTIAL'::"text", 'RECEIVED'::"text", 'CANCELLED'::"text"])))
);


ALTER TABLE "public"."purchase_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."quotation_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "quotation_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "unit_code" "text" DEFAULT 'NIU'::"text" NOT NULL,
    "quantity" numeric(12,4) NOT NULL,
    "unit_price" numeric(12,2) NOT NULL,
    "discount_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "tax_affectation_type" "text" DEFAULT '10'::"text" NOT NULL,
    "tax_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "subtotal" numeric(12,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT "quotation_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "quotation_items_unit_price_check" CHECK (("unit_price" >= (0)::numeric))
);


ALTER TABLE "public"."quotation_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."quotations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "quotation_number" "text",
    "customer_id" "uuid",
    "customer_name" "text",
    "customer_document_number" "text",
    "warehouse_id" "uuid",
    "status" "text" DEFAULT 'DRAFT'::"text" NOT NULL,
    "valid_until" "date",
    "currency_code" "text" DEFAULT 'PEN'::"text" NOT NULL,
    "exchange_rate" numeric(12,4) DEFAULT 1.0000 NOT NULL,
    "subtotal_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "tax_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "discount_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "total_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "notes" "text",
    "converted_order_id" "uuid",
    "created_by" "uuid",
    "updated_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "customer_record_id" "uuid",
    CONSTRAINT "quotations_status_check" CHECK (("status" = ANY (ARRAY['DRAFT'::"text", 'SENT'::"text", 'ACCEPTED'::"text", 'REJECTED'::"text", 'EXPIRED'::"text", 'CONVERTED'::"text"])))
);


ALTER TABLE "public"."quotations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."quotations"."customer_id" IS 'TRANSICIÓN: FK legado hacia public.profiles; usar customer_record_id hacia public.customers.';



CREATE TABLE IF NOT EXISTS "public"."raffle_tickets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "raffle_id" "uuid" NOT NULL,
    "customer_id" "uuid",
    "profile_id" "uuid",
    "ticket_number" "text" NOT NULL,
    "order_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "raffle_tickets_check" CHECK ((("customer_id" IS NOT NULL) OR ("profile_id" IS NOT NULL)))
);


ALTER TABLE "public"."raffle_tickets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."raffles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "prize_description" "text" NOT NULL,
    "start_date" timestamp with time zone NOT NULL,
    "end_date" timestamp with time zone NOT NULL,
    "draw_date" timestamp with time zone NOT NULL,
    "ticket_points_cost" integer DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'DRAFT'::"text" NOT NULL,
    "winner_customer_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "raffles_status_check" CHECK (("status" = ANY (ARRAY['DRAFT'::"text", 'ACTIVE'::"text", 'DRAWN'::"text", 'CANCELLED'::"text"]))),
    CONSTRAINT "raffles_ticket_points_cost_check" CHECK (("ticket_points_cost" >= 0))
);


ALTER TABLE "public"."raffles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."role_permissions" (
    "role_id" "uuid" NOT NULL,
    "permission_id" "uuid" NOT NULL
);


ALTER TABLE "public"."role_permissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sales_return_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "sales_return_id" "uuid" NOT NULL,
    "order_item_id" "uuid",
    "variant_id" "uuid" NOT NULL,
    "stock_batch_id" "uuid",
    "quantity" numeric(12,4) NOT NULL,
    "unit_price" numeric(12,2) NOT NULL,
    "refund_subtotal" numeric(12,2) NOT NULL,
    "restock" boolean DEFAULT true NOT NULL,
    "tax_affectation_type" "text" DEFAULT '10'::"text" NOT NULL,
    "tax_rate" numeric(5,2) DEFAULT 18.00 NOT NULL,
    "unit_value_without_tax" numeric(14,4) DEFAULT 0.0000 NOT NULL,
    "tax_amount" numeric(14,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT "sales_return_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "sales_return_items_tax_rate_range" CHECK ((("tax_rate" >= (0)::numeric) AND ("tax_rate" <= (100)::numeric)))
);


ALTER TABLE "public"."sales_return_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sales_returns" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "document_type" "text" DEFAULT 'NOTA_CREDITO'::"text" NOT NULL,
    "document_series" "text",
    "document_number" "text",
    "reason_code" "text" DEFAULT '01'::"text" NOT NULL,
    "reason_description" "text" NOT NULL,
    "refund_method" "text" DEFAULT 'CASH'::"text" NOT NULL,
    "account_id" "uuid",
    "shift_id" "uuid",
    "total_refund_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "status" "text" DEFAULT 'COMPLETED'::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sales_returns_document_type_check" CHECK (("document_type" = ANY (ARRAY['NOTA_CREDITO'::"text", 'DEVOLUCION_INTERNA'::"text"]))),
    CONSTRAINT "sales_returns_refund_method_check" CHECK (("refund_method" = ANY (ARRAY['CASH'::"text", 'ACCOUNT_TRANSFER'::"text", 'CREDIT_BALANCE'::"text", 'NONE'::"text"]))),
    CONSTRAINT "sales_returns_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'COMPLETED'::"text", 'CANCELLED'::"text"])))
);


ALTER TABLE "public"."sales_returns" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shopping_carts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shopping_carts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sunat_daily_summaries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "summary_type" "text" NOT NULL,
    "summary_date" "date" NOT NULL,
    "correlative" "text" NOT NULL,
    "ticket_number" "text",
    "sunat_status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "xml_url" "text",
    "cdr_url" "text",
    "response_message" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sunat_daily_summaries_summary_type_check" CHECK (("summary_type" = ANY (ARRAY['RC'::"text", 'RA'::"text"]))),
    CONSTRAINT "sunat_daily_summaries_sunat_status_check" CHECK (("sunat_status" = ANY (ARRAY['PENDING'::"text", 'SENT'::"text", 'ACCEPTED'::"text", 'REJECTED'::"text"])))
);


ALTER TABLE "public"."sunat_daily_summaries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sunat_daily_summary_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "summary_id" "uuid" NOT NULL,
    "electronic_document_id" "uuid" NOT NULL,
    "condition_code" "text" DEFAULT '1'::"text" NOT NULL,
    "reason" "text",
    CONSTRAINT "sunat_daily_summary_items_condition_code_check" CHECK (("condition_code" = ANY (ARRAY['1'::"text", '2'::"text", '3'::"text"])))
);


ALTER TABLE "public"."sunat_daily_summary_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."supplier_credit_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "supplier_credit_id" "uuid" NOT NULL,
    "purchase_order_id" "uuid",
    "movement_type" "text" NOT NULL,
    "amount" numeric(14,2) NOT NULL,
    "payment_method" "text",
    "due_date" "date",
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "purchase_invoice_id" "uuid",
    CONSTRAINT "supplier_credit_movements_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "supplier_credit_movements_movement_type_check" CHECK (("movement_type" = ANY (ARRAY['CHARGE'::"text", 'PAYMENT'::"text"])))
);


ALTER TABLE "public"."supplier_credit_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."supplier_credits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "supplier_id" "uuid" NOT NULL,
    "current_debt" numeric(14,2) DEFAULT 0 NOT NULL,
    "credit_limit" numeric(14,2) DEFAULT 0 NOT NULL,
    "payment_terms_days" integer DEFAULT 30 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    CONSTRAINT "supplier_credits_current_debt_check" CHECK (("current_debt" >= (0)::numeric))
);


ALTER TABLE "public"."supplier_credits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."suppliers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "tax_id" "text",
    "contact_name" "text",
    "phone" "text",
    "email" "text",
    "address" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."suppliers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."units_of_measure" (
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "symbol" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."units_of_measure" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "profile_id" "uuid" NOT NULL,
    "role_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."user_effective_permissions" WITH ("security_invoker"='true') AS
 SELECT DISTINCT "pr"."id" AS "profile_id",
    "pr"."auth_user_id",
    "r"."id" AS "role_id",
    "r"."name" AS "role_name",
    "p"."id" AS "permission_id",
    "p"."code" AS "permission_code",
    "p"."name" AS "permission_name",
    "p"."module" AS "permission_module"
   FROM (((("public"."profiles" "pr"
     JOIN "public"."user_roles" "ur" ON (("ur"."profile_id" = "pr"."id")))
     JOIN "public"."roles" "r" ON (("r"."id" = "ur"."role_id")))
     JOIN "public"."role_permissions" "rp" ON (("rp"."role_id" = "r"."id")))
     JOIN "public"."permissions" "p" ON (("p"."id" = "rp"."permission_id")));


ALTER VIEW "public"."user_effective_permissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_warehouses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "is_default" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid"
);


ALTER TABLE "public"."user_warehouses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."variant_attribute_values" (
    "variant_id" "uuid" NOT NULL,
    "attribute_value_id" "uuid" NOT NULL
);


ALTER TABLE "public"."variant_attribute_values" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wallet_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid",
    "order_id" "uuid",
    "points" integer NOT NULL,
    "movement_type" "text" NOT NULL,
    "description" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "customer_id" "uuid",
    CONSTRAINT "wallet_movements_owner_check" CHECK ((("profile_id" IS NOT NULL) OR ("customer_id" IS NOT NULL)))
);


ALTER TABLE "public"."wallet_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."warehouse_transfer_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "transfer_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "source_batch_id" "uuid",
    "quantity_sent" numeric(12,4) NOT NULL,
    "quantity_received" numeric(12,4) DEFAULT 0,
    "unit_cost" numeric(12,4) DEFAULT 0,
    CONSTRAINT "warehouse_transfer_items_quantity_received_check" CHECK (("quantity_received" >= (0)::numeric)),
    CONSTRAINT "warehouse_transfer_items_quantity_sent_check" CHECK (("quantity_sent" > (0)::numeric))
);


ALTER TABLE "public"."warehouse_transfer_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."warehouse_transfers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "transfer_number" "text",
    "source_warehouse_id" "uuid" NOT NULL,
    "dest_warehouse_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "notes" "text",
    "shipped_at" timestamp with time zone,
    "received_at" timestamp with time zone,
    "created_by" "uuid" NOT NULL,
    "received_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "warehouse_transfers_check" CHECK (("source_warehouse_id" <> "dest_warehouse_id")),
    CONSTRAINT "warehouse_transfers_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'IN_TRANSIT'::"text", 'RECEIVED'::"text", 'CANCELLED'::"text"])))
);


ALTER TABLE "public"."warehouse_transfers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."warehouse_variant_costs" (
    "warehouse_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "average_cost" numeric(14,4) DEFAULT 0.0000 NOT NULL,
    "total_quantity" numeric(14,4) DEFAULT 0.0000 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "warehouse_variant_costs_average_cost_check" CHECK (("average_cost" >= (0)::numeric)),
    CONSTRAINT "warehouse_variant_costs_total_quantity_check" CHECK (("total_quantity" >= (0)::numeric))
);


ALTER TABLE "public"."warehouse_variant_costs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."warehouses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "address" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid",
    "type" character varying(30) DEFAULT 'warehouse'::character varying NOT NULL,
    "code" character varying(30),
    "layout_config" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."warehouses" OWNER TO "postgres";


COMMENT ON COLUMN "public"."warehouses"."type" IS 'Tipo operativo: store (Tienda/Sucursal), warehouse (Almacén Central), dark_store (Micro-Hub), transit (Móvil)';



COMMENT ON COLUMN "public"."warehouses"."code" IS 'Código o identificador corto del almacén/tienda (ej. TDA-01, ALM-CENTRAL)';



COMMENT ON COLUMN "public"."warehouses"."layout_config" IS 'Receta procedural JSON con dimensiones, pasillos, estantes y zonas';



CREATE TABLE IF NOT EXISTS "public"."wishlist" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."wishlist" OWNER TO "postgres";


ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accounting_periods"
    ADD CONSTRAINT "accounting_periods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accounting_periods"
    ADD CONSTRAINT "accounting_periods_year_month_key" UNIQUE ("year", "month");



ALTER TABLE ONLY "public"."accounting_posting_rule_lines"
    ADD CONSTRAINT "accounting_posting_rule_lines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accounting_posting_rule_lines"
    ADD CONSTRAINT "accounting_posting_rule_lines_rule_id_line_order_key" UNIQUE ("rule_id", "line_order");



ALTER TABLE ONLY "public"."accounting_posting_rules"
    ADD CONSTRAINT "accounting_posting_rules_event_code_key" UNIQUE ("event_code");



ALTER TABLE ONLY "public"."accounting_posting_rules"
    ADD CONSTRAINT "accounting_posting_rules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."active_ingredients"
    ADD CONSTRAINT "active_ingredients_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."active_ingredients"
    ADD CONSTRAINT "active_ingredients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_settings"
    ADD CONSTRAINT "app_settings_pkey" PRIMARY KEY ("key");



ALTER TABLE "public"."app_settings"
    ADD CONSTRAINT "app_settings_value_by_type_check" CHECK (((("value_type" = 'NUMERIC'::"text") AND ("value" IS NOT NULL)) OR (("value_type" <> 'NUMERIC'::"text") AND ("value_text" IS NOT NULL)))) NOT VALID;



ALTER TABLE ONLY "public"."attribute_values"
    ADD CONSTRAINT "attribute_values_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attributes"
    ADD CONSTRAINT "attributes_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."attributes"
    ADD CONSTRAINT "attributes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attribute_values"
    ADD CONSTRAINT "av_unique_value_per_attribute" UNIQUE ("attribute_id", "value");



ALTER TABLE ONLY "public"."brands"
    ADD CONSTRAINT "brands_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."brands"
    ADD CONSTRAINT "brands_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."business_info"
    ADD CONSTRAINT "business_info_cash_mode_check" CHECK ((("cash_register_mode")::"text" = ANY ((ARRAY['COUNTER'::character varying, 'INDIVIDUAL'::character varying])::"text"[]))) NOT VALID;



ALTER TABLE ONLY "public"."business_info"
    ADD CONSTRAINT "business_info_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."chart_of_accounts"
    ADD CONSTRAINT "chart_of_accounts_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."chart_of_accounts"
    ADD CONSTRAINT "chart_of_accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "credit_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."currencies"
    ADD CONSTRAINT "currencies_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_customer_record_id_key" UNIQUE ("customer_record_id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_profile_id_key" UNIQUE ("profile_id");



ALTER TABLE ONLY "public"."customer_locations"
    ADD CONSTRAINT "customer_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_profile_id_key" UNIQUE ("profile_id");



ALTER TABLE ONLY "public"."daily_checkins"
    ADD CONSTRAINT "daily_checkins_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dispatch_guide_items"
    ADD CONSTRAINT "dispatch_guide_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dispatch_guides"
    ADD CONSTRAINT "dispatch_guides_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dispatch_guides"
    ADD CONSTRAINT "dispatch_guides_series_correlative_key" UNIQUE ("series", "correlative");



ALTER TABLE ONLY "public"."document_series"
    ADD CONSTRAINT "document_series_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."document_series"
    ADD CONSTRAINT "document_series_unique" UNIQUE ("warehouse_id", "document_type", "series");



ALTER TABLE ONLY "public"."electronic_documents"
    ADD CONSTRAINT "electronic_documents_document_type_series_correlative_key" UNIQUE ("document_type", "series", "correlative");



ALTER TABLE ONLY "public"."electronic_documents"
    ADD CONSTRAINT "electronic_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."exchange_rates"
    ADD CONSTRAINT "exchange_rates_currency_code_rate_date_key" UNIQUE ("currency_code", "rate_date");



ALTER TABLE ONLY "public"."exchange_rates"
    ADD CONSTRAINT "exchange_rates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."expense_categories"
    ADD CONSTRAINT "expense_categories_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."expense_categories"
    ADD CONSTRAINT "expense_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."financial_accounts"
    ADD CONSTRAINT "financial_accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."financial_accounts"
    ADD CONSTRAINT "financial_accounts_type_check" CHECK (("type" = ANY (ARRAY['CAJA'::"text", 'BANCO'::"text", 'BILLETERA_DIGITAL'::"text", 'OTRO'::"text"]))) NOT VALID;



ALTER TABLE ONLY "public"."import_batches"
    ADD CONSTRAINT "import_batches_pkey" PRIMARY KEY ("batch_id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'COMPLETED'::"text", 'CANCELLED'::"text"]))) NOT VALID;



ALTER TABLE ONLY "public"."inventory_entry_items"
    ADD CONSTRAINT "inventory_entry_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_exit_items"
    ADD CONSTRAINT "inventory_exit_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_exits"
    ADD CONSTRAINT "inventory_exits_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."inventory_exits"
    ADD CONSTRAINT "inventory_exits_reason_check" CHECK (("reason" = ANY (ARRAY['DAMAGED'::"text", 'EXPIRED'::"text", 'THEFT'::"text", 'INTERNAL_USE'::"text", 'SAMPLE'::"text", 'ADJUSTMENT'::"text", 'OTHER'::"text", 'MERMA'::"text", 'VENCIMIENTO'::"text", 'CONSUMO_INTERNO'::"text", 'OTRO'::"text"]))) NOT VALID;



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "inventory_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."inventory_movements"
    ADD CONSTRAINT "inventory_movements_reason_check" CHECK (("reason" = ANY (ARRAY['ENTRY'::"text", 'SALE'::"text", 'PURCHASE_ENTRY'::"text", 'MANUAL_EXIT'::"text", 'ADJUSTMENT'::"text", 'RETURN'::"text", 'TRANSFER_OUT'::"text", 'TRANSFER_IN'::"text", 'INITIAL'::"text", 'CANCELLATION'::"text"]))) NOT VALID;



ALTER TABLE ONLY "public"."journal_entries"
    ADD CONSTRAINT "journal_entries_entry_number_key" UNIQUE ("entry_number");



ALTER TABLE ONLY "public"."journal_entries"
    ADD CONSTRAINT "journal_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."journal_entry_lines"
    ADD CONSTRAINT "journal_entry_lines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_installments"
    ADD CONSTRAINT "order_installments_order_id_installment_number_key" UNIQUE ("order_id", "installment_number");



ALTER TABLE ONLY "public"."order_installments"
    ADD CONSTRAINT "order_installments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_payments"
    ADD CONSTRAINT "order_payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_status_history"
    ADD CONSTRAINT "order_status_history_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."orders"
    ADD CONSTRAINT "orders_amount_paid_coherence" CHECK ((("amount_paid" >= (0)::numeric) AND ("amount_paid" <= "total_amount"))) NOT VALID;



ALTER TABLE "public"."orders"
    ADD CONSTRAINT "orders_payment_coherence_check" CHECK ((("total_amount" = (0)::numeric) OR (("payment_status" = 'PENDING'::"text") AND ("amount_paid" = (0)::numeric)) OR (("payment_status" = 'PARTIAL'::"text") AND ("amount_paid" > (0)::numeric) AND ("amount_paid" < "total_amount")) OR (("payment_status" = 'PAID'::"text") AND ("amount_paid" >= "total_amount")))) NOT VALID;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."orders"
    ADD CONSTRAINT "orders_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'CONFIRMED'::"text", 'PROCESSING'::"text", 'SHIPPED'::"text", 'DELIVERED'::"text", 'COMPLETED'::"text", 'CANCELLED'::"text"]))) NOT VALID;



ALTER TABLE "public"."orders"
    ADD CONSTRAINT "orders_sunat_totals_coherence" CHECK ((((("total_gravado" + "total_exonerado") + "total_inafecto") = (0)::numeric) OR ("abs"((((((("total_gravado" + "total_exonerado") + "total_inafecto") + "tax_amount") + "icbper_amount") - "discount_amount") - "total_amount")) <= 0.05))) NOT VALID;



ALTER TABLE ONLY "public"."payment_methods"
    ADD CONSTRAINT "payment_methods_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."permissions"
    ADD CONSTRAINT "permissions_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."permissions"
    ADD CONSTRAINT "permissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."physical_inventories"
    ADD CONSTRAINT "physical_inventories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."physical_inventory_items"
    ADD CONSTRAINT "physical_inventory_items_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."purchase_orders"
    ADD CONSTRAINT "po_payment_coherence_check" CHECK ((("amount_paid" >= (0)::numeric) AND ("amount_paid" <= "total_amount") AND (("total_amount" = (0)::numeric) OR (("payment_status" = 'PENDING'::"text") AND ("amount_paid" = (0)::numeric)) OR (("payment_status" = 'PARTIAL'::"text") AND ("amount_paid" > (0)::numeric) AND ("amount_paid" < "total_amount")) OR (("payment_status" = 'PAID'::"text") AND ("amount_paid" >= "total_amount"))))) NOT VALID;



ALTER TABLE ONLY "public"."price_list_items"
    ADD CONSTRAINT "price_list_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."price_list_items"
    ADD CONSTRAINT "price_list_items_price_list_id_variant_id_unit_code_min_qua_key" UNIQUE ("price_list_id", "variant_id", "unit_code", "min_quantity");



ALTER TABLE ONLY "public"."price_lists"
    ADD CONSTRAINT "price_lists_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."price_lists"
    ADD CONSTRAINT "price_lists_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_active_ingredients"
    ADD CONSTRAINT "product_active_ingredients_pkey" PRIMARY KEY ("product_id", "ingredient_id");



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_reviews"
    ADD CONSTRAINT "product_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_unit_conversions"
    ADD CONSTRAINT "product_unit_conversions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_unit_conversions"
    ADD CONSTRAINT "product_unit_conversions_variant_id_unit_code_key" UNIQUE ("variant_id", "unit_code");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_sku_key" UNIQUE ("sku");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_auth_user_id_key" UNIQUE ("auth_user_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purchase_invoice_items"
    ADD CONSTRAINT "purchase_invoice_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purchase_invoice_payments"
    ADD CONSTRAINT "purchase_invoice_payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purchase_invoices"
    ADD CONSTRAINT "purchase_invoices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purchase_invoices"
    ADD CONSTRAINT "purchase_invoices_supplier_id_document_type_series_document_key" UNIQUE ("supplier_id", "document_type", "series", "document_number");



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_document_type_check" CHECK (("document_type" = ANY (ARRAY['FACTURA'::"text", 'BOLETA'::"text", 'RECIBO_HONORARIOS'::"text", 'NOTA_CREDITO'::"text", 'NOTA_DEBITO'::"text", 'GUIA_REMISION'::"text", 'NINGUNO'::"text", 'OTRO'::"text"]))) NOT VALID;



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quotation_items"
    ADD CONSTRAINT "quotation_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quotations"
    ADD CONSTRAINT "quotations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quotations"
    ADD CONSTRAINT "quotations_quotation_number_key" UNIQUE ("quotation_number");



ALTER TABLE ONLY "public"."raffle_tickets"
    ADD CONSTRAINT "raffle_tickets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."raffle_tickets"
    ADD CONSTRAINT "raffle_tickets_raffle_id_ticket_number_key" UNIQUE ("raffle_id", "ticket_number");



ALTER TABLE ONLY "public"."raffles"
    ADD CONSTRAINT "raffles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."role_permissions"
    ADD CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("role_id", "permission_id");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "sales_return_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shopping_carts"
    ADD CONSTRAINT "shopping_carts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shopping_carts"
    ADD CONSTRAINT "shopping_carts_profile_id_key" UNIQUE ("profile_id");



ALTER TABLE ONLY "public"."sunat_daily_summaries"
    ADD CONSTRAINT "sunat_daily_summaries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sunat_daily_summaries"
    ADD CONSTRAINT "sunat_daily_summaries_summary_type_summary_date_correlative_key" UNIQUE ("summary_type", "summary_date", "correlative");



ALTER TABLE ONLY "public"."sunat_daily_summary_items"
    ADD CONSTRAINT "sunat_daily_summary_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."supplier_credits"
    ADD CONSTRAINT "supplier_credits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."supplier_credits"
    ADD CONSTRAINT "supplier_credits_supplier_id_key" UNIQUE ("supplier_id");



ALTER TABLE ONLY "public"."suppliers"
    ADD CONSTRAINT "suppliers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."suppliers"
    ADD CONSTRAINT "suppliers_tax_id_key" UNIQUE ("tax_id");



ALTER TABLE ONLY "public"."financial_accounts"
    ADD CONSTRAINT "unique_financial_account_name" UNIQUE ("name");



ALTER TABLE ONLY "public"."units_of_measure"
    ADD CONSTRAINT "units_of_measure_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("profile_id", "role_id");



ALTER TABLE ONLY "public"."user_warehouses"
    ADD CONSTRAINT "user_warehouses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_warehouses"
    ADD CONSTRAINT "user_warehouses_profile_id_warehouse_id_key" UNIQUE ("profile_id", "warehouse_id");



ALTER TABLE ONLY "public"."variant_attribute_values"
    ADD CONSTRAINT "variant_attribute_values_pkey" PRIMARY KEY ("variant_id", "attribute_value_id");



ALTER TABLE ONLY "public"."wallet_movements"
    ADD CONSTRAINT "wallet_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."wallet_movements"
    ADD CONSTRAINT "wallet_movements_type_check" CHECK (("movement_type" = ANY (ARRAY['EARNED'::"text", 'REDEEMED'::"text", 'ADJUSTMENT'::"text", 'CHECKIN'::"text", 'EXPIRED'::"text", 'REFUND'::"text", 'BONUS'::"text"]))) NOT VALID;



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "warehouse_stock_batches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."warehouse_transfer_items"
    ADD CONSTRAINT "warehouse_transfer_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."warehouse_transfers"
    ADD CONSTRAINT "warehouse_transfers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."warehouse_transfers"
    ADD CONSTRAINT "warehouse_transfers_transfer_number_key" UNIQUE ("transfer_number");



ALTER TABLE ONLY "public"."warehouse_variant_costs"
    ADD CONSTRAINT "warehouse_variant_costs_pkey" PRIMARY KEY ("warehouse_id", "variant_id");



ALTER TABLE ONLY "public"."warehouses"
    ADD CONSTRAINT "warehouses_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."warehouses"
    ADD CONSTRAINT "warehouses_type_check" CHECK ((("type")::"text" = ANY ((ARRAY['STORE'::character varying, 'WAREHOUSE'::character varying, 'TIENDA'::character varying, 'ALMACEN'::character varying, 'PRINCIPAL'::character varying, 'SUCURSAL'::character varying])::"text"[]))) NOT VALID;



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_pkey" PRIMARY KEY ("id");



CREATE INDEX "account_movements_account_id_idx" ON "public"."account_movements" USING "btree" ("account_id");



CREATE INDEX "account_movements_created_by_idx" ON "public"."account_movements" USING "btree" ("created_by");



CREATE INDEX "account_movements_shift_id_idx" ON "public"."account_movements" USING "btree" ("shift_id");



CREATE INDEX "brands_created_by_idx" ON "public"."brands" USING "btree" ("created_by");



CREATE INDEX "brands_is_active_idx" ON "public"."brands" USING "btree" ("is_active");



CREATE INDEX "brands_name_idx" ON "public"."brands" USING "btree" ("name");



CREATE INDEX "brands_updated_by_idx" ON "public"."brands" USING "btree" ("updated_by");



CREATE INDEX "cart_items_cart_id_idx" ON "public"."cart_items" USING "btree" ("cart_id");



CREATE INDEX "cart_items_product_id_idx" ON "public"."cart_items" USING "btree" ("product_id");



CREATE INDEX "cart_items_variant_id_idx" ON "public"."cart_items" USING "btree" ("variant_id");



CREATE INDEX "cash_shifts_account_id_idx" ON "public"."cash_shifts" USING "btree" ("account_id");



CREATE INDEX "cash_shifts_closed_by_idx" ON "public"."cash_shifts" USING "btree" ("closed_by");



CREATE INDEX "cash_shifts_opened_by_idx" ON "public"."cash_shifts" USING "btree" ("opened_by");



CREATE INDEX "categories_created_by_idx" ON "public"."categories" USING "btree" ("created_by");



CREATE INDEX "categories_updated_by_idx" ON "public"."categories" USING "btree" ("updated_by");



CREATE INDEX "customer_credits_created_by_idx" ON "public"."customer_credits" USING "btree" ("created_by");



CREATE INDEX "daily_checkins_profile_id_idx" ON "public"."daily_checkins" USING "btree" ("profile_id");



CREATE INDEX "idx_active_ingredients_created_at" ON "public"."active_ingredients" USING "btree" ("created_at" DESC);



CREATE UNIQUE INDEX "idx_active_ingredients_name_normalized" ON "public"."active_ingredients" USING "btree" ("lower"(TRIM(BOTH FROM "name")));



CREATE INDEX "idx_active_ingredients_name_sort" ON "public"."active_ingredients" USING "btree" ("name");



CREATE INDEX "idx_audit_logs_created_at" ON "public"."audit_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_audit_logs_table_record" ON "public"."audit_logs" USING "btree" ("table_name", "record_id");



CREATE UNIQUE INDEX "idx_cash_shifts_one_open_per_account" ON "public"."cash_shifts" USING "btree" ("account_id") WHERE ("status" = 'OPEN'::"text");



CREATE UNIQUE INDEX "idx_currencies_unique_base" ON "public"."currencies" USING "btree" ("is_base") WHERE ("is_base" = true);



CREATE INDEX "idx_customer_credit_movements_created_by" ON "public"."customer_credit_movements" USING "btree" ("created_by");



CREATE INDEX "idx_customer_credit_movements_customer_credit_id" ON "public"."customer_credit_movements" USING "btree" ("customer_credit_id");



CREATE INDEX "idx_customer_credit_movements_order_id" ON "public"."customer_credit_movements" USING "btree" ("order_id");



CREATE INDEX "idx_customer_locations_profile_id" ON "public"."customer_locations" USING "btree" ("profile_id");



CREATE UNIQUE INDEX "idx_customers_document_unique" ON "public"."customers" USING "btree" ("document_type", "document_number") WHERE (("document_number" IS NOT NULL) AND (TRIM(BOTH FROM "document_number") <> ''::"text"));



CREATE INDEX "idx_customers_full_name" ON "public"."customers" USING "btree" ("full_name");



CREATE INDEX "idx_dispatch_guide_items_guide_id" ON "public"."dispatch_guide_items" USING "btree" ("dispatch_guide_id");



CREATE INDEX "idx_dispatch_guide_items_variant_id" ON "public"."dispatch_guide_items" USING "btree" ("variant_id");



CREATE INDEX "idx_dispatch_guides_edoc_id" ON "public"."dispatch_guides" USING "btree" ("electronic_document_id");



CREATE INDEX "idx_dispatch_guides_order_id" ON "public"."dispatch_guides" USING "btree" ("order_id");



CREATE INDEX "idx_dispatch_guides_transfer_id" ON "public"."dispatch_guides" USING "btree" ("transfer_id");



CREATE UNIQUE INDEX "idx_document_series_global_unique" ON "public"."document_series" USING "btree" ("document_type", "series") WHERE ("warehouse_id" IS NULL);



CREATE UNIQUE INDEX "idx_document_series_one_default_global" ON "public"."document_series" USING "btree" ("document_type") WHERE (("is_default" = true) AND ("warehouse_id" IS NULL));



CREATE UNIQUE INDEX "idx_document_series_one_default_warehouse" ON "public"."document_series" USING "btree" ("warehouse_id", "document_type") WHERE (("is_default" = true) AND ("warehouse_id" IS NOT NULL));



CREATE UNIQUE INDEX "idx_document_series_warehouse_unique" ON "public"."document_series" USING "btree" ("warehouse_id", "document_type", "series") WHERE ("warehouse_id" IS NOT NULL);



CREATE INDEX "idx_edocs_dispatch_guide_id" ON "public"."electronic_documents" USING "btree" ("dispatch_guide_id");



CREATE INDEX "idx_edocs_order_id" ON "public"."electronic_documents" USING "btree" ("order_id");



CREATE INDEX "idx_edocs_reference_doc_id" ON "public"."electronic_documents" USING "btree" ("reference_document_id");



CREATE INDEX "idx_edocs_sales_return_id" ON "public"."electronic_documents" USING "btree" ("sales_return_id");



CREATE INDEX "idx_expenses_account_id" ON "public"."expenses" USING "btree" ("account_id");



CREATE INDEX "idx_expenses_category_id" ON "public"."expenses" USING "btree" ("category_id");



CREATE INDEX "idx_expenses_shift_id" ON "public"."expenses" USING "btree" ("shift_id");



CREATE INDEX "idx_financial_accounts_warehouse_id" ON "public"."financial_accounts" USING "btree" ("warehouse_id");



CREATE INDEX "idx_inv_movements_return_id" ON "public"."inventory_movements" USING "btree" ("sales_return_id");



CREATE INDEX "idx_inv_movements_transfer_id" ON "public"."inventory_movements" USING "btree" ("transfer_id");



CREATE INDEX "idx_inv_movements_var_wh_date" ON "public"."inventory_movements" USING "btree" ("variant_id", "warehouse_id", "created_at" DESC);



CREATE INDEX "idx_inventory_entries_account_id" ON "public"."inventory_entries" USING "btree" ("account_id");



CREATE INDEX "idx_inventory_entries_created_at_desc" ON "public"."inventory_entries" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_inventory_entries_doc_trgm" ON "public"."inventory_entries" USING "gin" ("document_number" "public"."gin_trgm_ops");



CREATE INDEX "idx_inventory_entries_shift_id" ON "public"."inventory_entries" USING "btree" ("shift_id");



CREATE INDEX "idx_inventory_entries_warehouse_created" ON "public"."inventory_entries" USING "btree" ("warehouse_id", "created_at" DESC);



CREATE INDEX "idx_inventory_entry_items_entry_id" ON "public"."inventory_entry_items" USING "btree" ("entry_id");



CREATE INDEX "idx_inventory_movements_batch_created_at" ON "public"."inventory_movements" USING "btree" ("stock_batch_id", "created_at" DESC);



CREATE INDEX "idx_inventory_movements_created_at_desc" ON "public"."inventory_movements" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_inventory_movements_created_by" ON "public"."inventory_movements" USING "btree" ("created_by");



CREATE INDEX "idx_inventory_movements_variant_created_at" ON "public"."inventory_movements" USING "btree" ("variant_id", "created_at" DESC);



CREATE INDEX "idx_inventory_movements_variant_id" ON "public"."inventory_movements" USING "btree" ("variant_id");



CREATE INDEX "idx_inventory_movements_warehouse_created_at" ON "public"."inventory_movements" USING "btree" ("warehouse_id", "created_at" DESC);



CREATE INDEX "idx_inventory_movements_warehouse_id" ON "public"."inventory_movements" USING "btree" ("warehouse_id");



CREATE INDEX "idx_journal_entries_period_id" ON "public"."journal_entries" USING "btree" ("period_id");



CREATE INDEX "idx_journal_lines_account_code" ON "public"."journal_entry_lines" USING "btree" ("account_code");



CREATE INDEX "idx_journal_lines_entry_id" ON "public"."journal_entry_lines" USING "btree" ("journal_entry_id");



CREATE UNIQUE INDEX "idx_one_default_per_user" ON "public"."user_warehouses" USING "btree" ("profile_id") WHERE ("is_default" = true);



CREATE INDEX "idx_order_installments_order_id" ON "public"."order_installments" USING "btree" ("order_id");



CREATE INDEX "idx_order_items_order_id" ON "public"."order_items" USING "btree" ("order_id");



CREATE INDEX "idx_order_items_product_id" ON "public"."order_items" USING "btree" ("product_id");



CREATE INDEX "idx_order_payments_account_id" ON "public"."order_payments" USING "btree" ("account_id");



CREATE INDEX "idx_order_payments_order_id" ON "public"."order_payments" USING "btree" ("order_id");



CREATE INDEX "idx_order_payments_shift_id" ON "public"."order_payments" USING "btree" ("shift_id");



CREATE INDEX "idx_order_status_history_order_id" ON "public"."order_status_history" USING "btree" ("order_id");



CREATE INDEX "idx_orders_created_at_desc" ON "public"."orders" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_orders_created_by" ON "public"."orders" USING "btree" ("created_by");



CREATE INDEX "idx_orders_created_wh" ON "public"."orders" USING "btree" ("created_at" DESC, "warehouse_id");



CREATE INDEX "idx_orders_customer_id" ON "public"."orders" USING "btree" ("customer_id");



CREATE INDEX "idx_orders_customer_record_id" ON "public"."orders" USING "btree" ("customer_record_id");



CREATE INDEX "idx_orders_delivery_location" ON "public"."orders" USING "btree" ("delivery_location_id");



CREATE UNIQUE INDEX "idx_orders_document_unique" ON "public"."orders" USING "btree" ("document_type", "document_series", "document_number") WHERE (("document_number" IS NOT NULL) AND ("document_type" IS NOT NULL) AND ("document_type" <> 'NINGUNO'::"text") AND ("status" <> 'CANCELLED'::"text"));



CREATE INDEX "idx_orders_warehouse_id" ON "public"."orders" USING "btree" ("warehouse_id");



CREATE INDEX "idx_permissions_code" ON "public"."permissions" USING "btree" ("code");



CREATE INDEX "idx_pi_payments_account_id" ON "public"."purchase_invoice_payments" USING "btree" ("account_id");



CREATE INDEX "idx_pi_payments_invoice_id" ON "public"."purchase_invoice_payments" USING "btree" ("purchase_invoice_id");



CREATE INDEX "idx_pii_entry_item_id" ON "public"."purchase_invoice_items" USING "btree" ("inventory_entry_item_id");



CREATE INDEX "idx_pii_po_item_id" ON "public"."purchase_invoice_items" USING "btree" ("purchase_order_item_id");



CREATE INDEX "idx_product_images_product_id" ON "public"."product_images" USING "btree" ("product_id");



CREATE INDEX "idx_product_variants_barcode" ON "public"."product_variants" USING "btree" ("barcode");



CREATE INDEX "idx_product_variants_barcode_trgm" ON "public"."product_variants" USING "gin" ("barcode" "public"."gin_trgm_ops");



CREATE UNIQUE INDEX "idx_product_variants_barcode_unique" ON "public"."product_variants" USING "btree" ("barcode") WHERE (("barcode" IS NOT NULL) AND (TRIM(BOTH FROM "barcode") <> ''::"text"));



CREATE INDEX "idx_product_variants_product_id" ON "public"."product_variants" USING "btree" ("product_id");



CREATE INDEX "idx_product_variants_sku_trgm" ON "public"."product_variants" USING "gin" ("sku" "public"."gin_trgm_ops");



CREATE INDEX "idx_products_brand_is_active" ON "public"."products" USING "btree" ("brand_id", "is_active", "created_at" DESC);



CREATE INDEX "idx_products_category_id" ON "public"."products" USING "btree" ("category_id");



CREATE INDEX "idx_products_category_is_active" ON "public"."products" USING "btree" ("category_id", "is_active", "created_at" DESC);



CREATE INDEX "idx_products_name_trgm" ON "public"."products" USING "gin" ("name" "public"."gin_trgm_ops");



CREATE INDEX "idx_purchase_invoice_items_inv_id" ON "public"."purchase_invoice_items" USING "btree" ("purchase_invoice_id");



CREATE INDEX "idx_purchase_invoices_po_id" ON "public"."purchase_invoices" USING "btree" ("purchase_order_id");



CREATE INDEX "idx_purchase_invoices_supplier_id" ON "public"."purchase_invoices" USING "btree" ("supplier_id");



CREATE INDEX "idx_purchase_order_items_po_id" ON "public"."purchase_order_items" USING "btree" ("purchase_order_id");



CREATE INDEX "idx_purchase_orders_supplier_id" ON "public"."purchase_orders" USING "btree" ("supplier_id");



CREATE INDEX "idx_quotation_items_quotation_id" ON "public"."quotation_items" USING "btree" ("quotation_id");



CREATE INDEX "idx_quotation_items_variant_id" ON "public"."quotation_items" USING "btree" ("variant_id");



CREATE INDEX "idx_quotations_customer_id" ON "public"."quotations" USING "btree" ("customer_id");



CREATE INDEX "idx_quotations_customer_record_id" ON "public"."quotations" USING "btree" ("customer_record_id");



CREATE INDEX "idx_quotations_warehouse_id" ON "public"."quotations" USING "btree" ("warehouse_id");



CREATE INDEX "idx_raffle_tickets_customer" ON "public"."raffle_tickets" USING "btree" ("customer_id");



CREATE INDEX "idx_raffle_tickets_raffle" ON "public"."raffle_tickets" USING "btree" ("raffle_id");



CREATE INDEX "idx_role_permissions_permission_id" ON "public"."role_permissions" USING "btree" ("permission_id");



CREATE INDEX "idx_role_permissions_role_id" ON "public"."role_permissions" USING "btree" ("role_id");



CREATE INDEX "idx_sales_return_items_return_id" ON "public"."sales_return_items" USING "btree" ("sales_return_id");



CREATE INDEX "idx_sales_return_items_variant_id" ON "public"."sales_return_items" USING "btree" ("variant_id");



CREATE INDEX "idx_sales_returns_order_id" ON "public"."sales_returns" USING "btree" ("order_id");



CREATE INDEX "idx_sales_returns_warehouse_id" ON "public"."sales_returns" USING "btree" ("warehouse_id");



CREATE INDEX "idx_sunat_summary_items_edoc" ON "public"."sunat_daily_summary_items" USING "btree" ("electronic_document_id");



CREATE INDEX "idx_sunat_summary_items_summary" ON "public"."sunat_daily_summary_items" USING "btree" ("summary_id");



CREATE INDEX "idx_supplier_credit_movements_created_by" ON "public"."supplier_credit_movements" USING "btree" ("created_by");



CREATE INDEX "idx_supplier_credit_movements_credit_id" ON "public"."supplier_credit_movements" USING "btree" ("supplier_credit_id");



CREATE INDEX "idx_supplier_credit_movements_po_id" ON "public"."supplier_credit_movements" USING "btree" ("purchase_order_id");



CREATE INDEX "idx_user_roles_profile_id" ON "public"."user_roles" USING "btree" ("profile_id");



CREATE INDEX "idx_user_roles_role_id" ON "public"."user_roles" USING "btree" ("role_id");



CREATE INDEX "idx_user_warehouses_profile_id" ON "public"."user_warehouses" USING "btree" ("profile_id");



CREATE INDEX "idx_user_warehouses_warehouse_id" ON "public"."user_warehouses" USING "btree" ("warehouse_id");



CREATE INDEX "idx_wallet_movements_customer_id" ON "public"."wallet_movements" USING "btree" ("customer_id");



CREATE INDEX "idx_warehouse_stock_batches_variant_qty" ON "public"."warehouse_stock_batches" USING "btree" ("variant_id", "available_quantity");



CREATE INDEX "idx_warehouses_type" ON "public"."warehouses" USING "btree" ("type");



CREATE INDEX "idx_wh_transfer_items_transfer" ON "public"."warehouse_transfer_items" USING "btree" ("transfer_id");



CREATE INDEX "idx_wh_transfer_items_variant" ON "public"."warehouse_transfer_items" USING "btree" ("variant_id");



CREATE INDEX "idx_wh_transfers_dest" ON "public"."warehouse_transfers" USING "btree" ("dest_warehouse_id");



CREATE INDEX "idx_wh_transfers_source" ON "public"."warehouse_transfers" USING "btree" ("source_warehouse_id");



CREATE UNIQUE INDEX "idx_wsb_variant_warehouse_batch_unique" ON "public"."warehouse_stock_batches" USING "btree" ("variant_id", "warehouse_id", "batch_number");



CREATE INDEX "iei_entry_id__idx" ON "public"."inventory_entry_items" USING "btree" ("entry_id");



CREATE INDEX "iei_product_id_idx" ON "public"."inventory_entry_items" USING "btree" ("product_id");



CREATE INDEX "iei_variant_id_idx" ON "public"."inventory_entry_items" USING "btree" ("variant_id");



CREATE INDEX "iexi_exit_id_idx" ON "public"."inventory_exit_items" USING "btree" ("exit_id");



CREATE INDEX "iexi_product_id_idx" ON "public"."inventory_exit_items" USING "btree" ("product_id");



CREATE INDEX "iexi_variant_id_idx" ON "public"."inventory_exit_items" USING "btree" ("variant_id");



CREATE INDEX "im_entry_id_idx" ON "public"."inventory_movements" USING "btree" ("inventory_entry_id");



CREATE INDEX "im_exit_id_idx" ON "public"."inventory_movements" USING "btree" ("inventory_exit_id");



CREATE INDEX "im_order_id_idx" ON "public"."inventory_movements" USING "btree" ("order_id");



CREATE INDEX "im_physical_inv_id_idx" ON "public"."inventory_movements" USING "btree" ("physical_inventory_id");



CREATE INDEX "im_stock_batch_id_idx" ON "public"."inventory_movements" USING "btree" ("stock_batch_id");



CREATE INDEX "inventory_entries_created_by_idx" ON "public"."inventory_entries" USING "btree" ("created_by");



CREATE INDEX "inventory_entries_purchase_order_id_idx" ON "public"."inventory_entries" USING "btree" ("purchase_order_id");



CREATE INDEX "inventory_entries_supplier_id_idx" ON "public"."inventory_entries" USING "btree" ("supplier_id");



CREATE INDEX "inventory_entries_warehouse_id_idx" ON "public"."inventory_entries" USING "btree" ("warehouse_id");



CREATE INDEX "inventory_exits_created_by_idx" ON "public"."inventory_exits" USING "btree" ("created_by");



CREATE INDEX "inventory_exits_store_id_idx" ON "public"."inventory_exits" USING "btree" ("warehouse_id");



CREATE INDEX "order_items_variant_id_idx" ON "public"."order_items" USING "btree" ("variant_id");



CREATE INDEX "orders_updated_by_idx" ON "public"."orders" USING "btree" ("updated_by");



CREATE INDEX "p_variants_created_by_idx" ON "public"."product_variants" USING "btree" ("created_by");



CREATE INDEX "pai_ingredient_id_idx" ON "public"."product_active_ingredients" USING "btree" ("ingredient_id");



CREATE INDEX "pi_created_by_idx" ON "public"."physical_inventories" USING "btree" ("created_by");



CREATE INDEX "pi_warehouse_id_idx" ON "public"."physical_inventories" USING "btree" ("warehouse_id");



CREATE INDEX "pii_counted_by_idx" ON "public"."physical_inventory_items" USING "btree" ("counted_by");



CREATE INDEX "pii_inventory_id_idx" ON "public"."physical_inventory_items" USING "btree" ("physical_inventory_id");



CREATE INDEX "pii_variant_id_idx" ON "public"."physical_inventory_items" USING "btree" ("variant_id");



CREATE INDEX "po_items_product_id_idx" ON "public"."purchase_order_items" USING "btree" ("product_id");



CREATE INDEX "po_items_variant_id_idx" ON "public"."purchase_order_items" USING "btree" ("variant_id");



CREATE INDEX "product_images_variant_id_idx" ON "public"."product_images" USING "btree" ("variant_id");



CREATE INDEX "product_reviews_product_id_idx" ON "public"."product_reviews" USING "btree" ("product_id");



CREATE INDEX "product_reviews_profile_id_idx" ON "public"."product_reviews" USING "btree" ("profile_id");



CREATE INDEX "product_updated_by_idx" ON "public"."products" USING "btree" ("updated_by");



CREATE INDEX "product_variants_updated_by_idx" ON "public"."product_variants" USING "btree" ("updated_by");



CREATE INDEX "products_brand_id_idx" ON "public"."products" USING "btree" ("brand_id");



CREATE INDEX "products_created_by_idx" ON "public"."products" USING "btree" ("created_by");



CREATE INDEX "purchase_orders_created_by_idx" ON "public"."purchase_orders" USING "btree" ("created_by");



CREATE INDEX "purchase_orders_updated_by_idx" ON "public"."purchase_orders" USING "btree" ("updated_by");



CREATE INDEX "purchase_orders_warehouse_id_idx" ON "public"."purchase_orders" USING "btree" ("warehouse_id");



CREATE INDEX "supplier_credits_created_by_fidx" ON "public"."supplier_credits" USING "btree" ("created_by");



CREATE UNIQUE INDEX "uq_edoc_active_order_boleta_factura" ON "public"."electronic_documents" USING "btree" ("order_id") WHERE (("order_id" IS NOT NULL) AND ("document_type" = ANY (ARRAY['BOLETA'::"text", 'FACTURA'::"text"])) AND ("is_active" = true) AND ("sunat_status" <> 'VOIDED'::"text"));



CREATE INDEX "vav_attribute_value_id_fidx" ON "public"."variant_attribute_values" USING "btree" ("attribute_value_id");



CREATE INDEX "wallet_movements_order_id_idx" ON "public"."wallet_movements" USING "btree" ("order_id");



CREATE INDEX "wallet_movements_profile_id_idx" ON "public"."wallet_movements" USING "btree" ("profile_id");



CREATE INDEX "warehouse_stock_batches_supplier_id_idx" ON "public"."warehouse_stock_batches" USING "btree" ("supplier_id");



CREATE INDEX "warehouses_created_by_idx" ON "public"."warehouses" USING "btree" ("created_by");



CREATE INDEX "warehouses_updated_by_idx" ON "public"."warehouses" USING "btree" ("updated_by");



CREATE INDEX "wishlist_product_id_idx" ON "public"."wishlist" USING "btree" ("product_id");



CREATE INDEX "wishlist_profile_id_idx" ON "public"."wishlist" USING "btree" ("profile_id");



CREATE INDEX "wsb_created_by_idx" ON "public"."warehouse_stock_batches" USING "btree" ("created_by");



CREATE INDEX "wsb_product_id_idx" ON "public"."warehouse_stock_batches" USING "btree" ("product_id");



CREATE INDEX "wsb_updated_by_idx" ON "public"."warehouse_stock_batches" USING "btree" ("updated_by");



CREATE INDEX "wsb_variant_id_idx" ON "public"."warehouse_stock_batches" USING "btree" ("variant_id");



CREATE INDEX "wsb_warehouse_id_idx" ON "public"."warehouse_stock_batches" USING "btree" ("warehouse_id");



CREATE OR REPLACE TRIGGER "set_product_variants_updated_at" BEFORE UPDATE ON "public"."product_variants" FOR EACH ROW EXECUTE FUNCTION "public"."handle_update_timestamp"();



CREATE OR REPLACE TRIGGER "trg_account_movements_compute_base" BEFORE INSERT OR UPDATE ON "public"."account_movements" FOR EACH ROW EXECUTE FUNCTION "public"."trg_compute_base_amounts"();



CREATE OR REPLACE TRIGGER "trg_audit_expenses" AFTER INSERT OR DELETE OR UPDATE ON "public"."expenses" FOR EACH ROW EXECUTE FUNCTION "public"."trg_audit_log"();



CREATE OR REPLACE TRIGGER "trg_audit_financial_accounts" AFTER DELETE OR UPDATE ON "public"."financial_accounts" FOR EACH ROW EXECUTE FUNCTION "public"."trg_audit_log"();



CREATE OR REPLACE TRIGGER "trg_audit_orders" AFTER INSERT OR DELETE OR UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."trg_audit_log"();



CREATE OR REPLACE TRIGGER "trg_audit_sales_returns" AFTER INSERT OR DELETE OR UPDATE ON "public"."sales_returns" FOR EACH ROW EXECUTE FUNCTION "public"."trg_audit_log"();



CREATE OR REPLACE TRIGGER "trg_customer_credits_sync_customer" BEFORE INSERT OR UPDATE ON "public"."customer_credits" FOR EACH ROW EXECUTE FUNCTION "public"."trg_sync_customer_record_id"();



CREATE OR REPLACE TRIGGER "trg_customer_locations_sync_customer" BEFORE INSERT OR UPDATE ON "public"."customer_locations" FOR EACH ROW EXECUTE FUNCTION "public"."trg_sync_customer_record_id"();



CREATE OR REPLACE TRIGGER "trg_customers_updated_at" BEFORE UPDATE ON "public"."customers" FOR EACH ROW EXECUTE FUNCTION "public"."trg_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_electronic_documents_updated_at" BEFORE UPDATE ON "public"."electronic_documents" FOR EACH ROW EXECUTE FUNCTION "public"."trg_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_financial_accounts_updated_at" BEFORE UPDATE ON "public"."financial_accounts" FOR EACH ROW EXECUTE FUNCTION "public"."trg_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_journal_entries_validate" BEFORE INSERT OR UPDATE ON "public"."journal_entries" FOR EACH ROW EXECUTE FUNCTION "public"."trg_journal_balanced_and_period"();



CREATE CONSTRAINT TRIGGER "trg_journal_lines_balanced_deferred" AFTER INSERT OR DELETE OR UPDATE ON "public"."journal_entry_lines" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."trg_check_journal_entry_lines_balanced"();



CREATE OR REPLACE TRIGGER "trg_order_payments_compute_base" BEFORE INSERT OR UPDATE ON "public"."order_payments" FOR EACH ROW EXECUTE FUNCTION "public"."trg_compute_base_amounts"();



CREATE OR REPLACE TRIGGER "trg_orders_compute_base" BEFORE INSERT OR UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."trg_compute_base_amounts"();



CREATE OR REPLACE TRIGGER "trg_orders_status_history" AFTER UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."trg_track_order_status"();



CREATE OR REPLACE TRIGGER "trg_orders_sync_customer" BEFORE INSERT OR UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."trg_sync_customer_record_id"();



CREATE OR REPLACE TRIGGER "trg_orders_updated_at" BEFORE UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."trg_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_price_lists_updated_at" BEFORE UPDATE ON "public"."price_lists" FOR EACH ROW EXECUTE FUNCTION "public"."trg_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_product_variants_updated_at" BEFORE UPDATE ON "public"."product_variants" FOR EACH ROW EXECUTE FUNCTION "public"."trg_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_products_updated_at" BEFORE UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."trg_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_protect_system_roles" BEFORE DELETE OR UPDATE ON "public"."roles" FOR EACH ROW EXECUTE FUNCTION "public"."protect_system_roles"();



CREATE OR REPLACE TRIGGER "trg_quotations_updated_at" BEFORE UPDATE ON "public"."quotations" FOR EACH ROW EXECUTE FUNCTION "public"."trg_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_suppliers_updated_at" BEFORE UPDATE ON "public"."suppliers" FOR EACH ROW EXECUTE FUNCTION "public"."trg_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_warehouse_auto_cash_account" AFTER INSERT ON "public"."warehouses" FOR EACH ROW EXECUTE FUNCTION "public"."trg_auto_create_counter_cash_account"();



CREATE OR REPLACE TRIGGER "trg_warehouse_sync_cash_account" AFTER UPDATE ON "public"."warehouses" FOR EACH ROW EXECUTE FUNCTION "public"."trg_sync_warehouse_status_to_cash_account"();



CREATE OR REPLACE TRIGGER "trg_warehouse_transfers_updated_at" BEFORE UPDATE ON "public"."warehouse_transfers" FOR EACH ROW EXECUTE FUNCTION "public"."trg_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_wsb_sync_variant_qty" AFTER INSERT OR DELETE OR UPDATE ON "public"."warehouse_stock_batches" FOR EACH ROW EXECUTE FUNCTION "public"."trg_sync_warehouse_variant_qty"();



ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."financial_accounts"("id");



ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_currency_code_fkey" FOREIGN KEY ("currency_code") REFERENCES "public"."currencies"("code") NOT VALID;



ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."cash_shifts"("id");



ALTER TABLE ONLY "public"."accounting_periods"
    ADD CONSTRAINT "accounting_periods_closed_by_fkey" FOREIGN KEY ("closed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."accounting_posting_rule_lines"
    ADD CONSTRAINT "accounting_posting_rule_lines_account_code_fkey" FOREIGN KEY ("account_code") REFERENCES "public"."chart_of_accounts"("code");



ALTER TABLE ONLY "public"."accounting_posting_rule_lines"
    ADD CONSTRAINT "accounting_posting_rule_lines_rule_id_fkey" FOREIGN KEY ("rule_id") REFERENCES "public"."accounting_posting_rules"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accounting_posting_rules"
    ADD CONSTRAINT "accounting_posting_rules_credit_account_code_fkey" FOREIGN KEY ("credit_account_code") REFERENCES "public"."chart_of_accounts"("code");



ALTER TABLE ONLY "public"."accounting_posting_rules"
    ADD CONSTRAINT "accounting_posting_rules_debit_account_code_fkey" FOREIGN KEY ("debit_account_code") REFERENCES "public"."chart_of_accounts"("code");



ALTER TABLE ONLY "public"."accounting_posting_rules"
    ADD CONSTRAINT "accounting_posting_rules_tax_account_code_fkey" FOREIGN KEY ("tax_account_code") REFERENCES "public"."chart_of_accounts"("code");



ALTER TABLE ONLY "public"."attribute_values"
    ADD CONSTRAINT "av_attribute_id_fkey" FOREIGN KEY ("attribute_id") REFERENCES "public"."attributes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."brands"
    ADD CONSTRAINT "brands_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."brands"
    ADD CONSTRAINT "brands_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "public"."shopping_carts"("id");



ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."financial_accounts"("id");



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_closed_by_fkey" FOREIGN KEY ("closed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_opened_by_fkey" FOREIGN KEY ("opened_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."chart_of_accounts"
    ADD CONSTRAINT "chart_of_accounts_parent_code_fkey" FOREIGN KEY ("parent_code") REFERENCES "public"."chart_of_accounts"("code");



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "customer_credit_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "customer_credit_movements_customer_credit_id_fkey" FOREIGN KEY ("customer_credit_id") REFERENCES "public"."customer_credits"("id");



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "customer_credit_movements_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_customer_record_id_fkey" FOREIGN KEY ("customer_record_id") REFERENCES "public"."customers"("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."customer_locations"
    ADD CONSTRAINT "customer_locations_customer_record_id_fkey" FOREIGN KEY ("customer_record_id") REFERENCES "public"."customers"("id");



ALTER TABLE ONLY "public"."customer_locations"
    ADD CONSTRAINT "customer_locations_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."daily_checkins"
    ADD CONSTRAINT "daily_checkins_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."dispatch_guide_items"
    ADD CONSTRAINT "dispatch_guide_items_dispatch_guide_id_fkey" FOREIGN KEY ("dispatch_guide_id") REFERENCES "public"."dispatch_guides"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dispatch_guide_items"
    ADD CONSTRAINT "dispatch_guide_items_unit_code_fkey" FOREIGN KEY ("unit_code") REFERENCES "public"."units_of_measure"("code");



ALTER TABLE ONLY "public"."dispatch_guide_items"
    ADD CONSTRAINT "dispatch_guide_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."dispatch_guides"
    ADD CONSTRAINT "dispatch_guides_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."dispatch_guides"
    ADD CONSTRAINT "dispatch_guides_electronic_document_id_fkey" FOREIGN KEY ("electronic_document_id") REFERENCES "public"."electronic_documents"("id");



ALTER TABLE ONLY "public"."dispatch_guides"
    ADD CONSTRAINT "dispatch_guides_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."dispatch_guides"
    ADD CONSTRAINT "dispatch_guides_transfer_id_fkey" FOREIGN KEY ("transfer_id") REFERENCES "public"."warehouse_transfers"("id");



ALTER TABLE ONLY "public"."document_series"
    ADD CONSTRAINT "document_series_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."electronic_documents"
    ADD CONSTRAINT "electronic_documents_dispatch_guide_id_fkey" FOREIGN KEY ("dispatch_guide_id") REFERENCES "public"."dispatch_guides"("id");



ALTER TABLE ONLY "public"."electronic_documents"
    ADD CONSTRAINT "electronic_documents_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."electronic_documents"
    ADD CONSTRAINT "electronic_documents_reference_document_id_fkey" FOREIGN KEY ("reference_document_id") REFERENCES "public"."electronic_documents"("id");



ALTER TABLE ONLY "public"."electronic_documents"
    ADD CONSTRAINT "electronic_documents_sales_return_id_fkey" FOREIGN KEY ("sales_return_id") REFERENCES "public"."sales_returns"("id");



ALTER TABLE ONLY "public"."exchange_rates"
    ADD CONSTRAINT "exchange_rates_currency_code_fkey" FOREIGN KEY ("currency_code") REFERENCES "public"."currencies"("code");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."financial_accounts"("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."expense_categories"("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_currency_code_fkey" FOREIGN KEY ("currency_code") REFERENCES "public"."currencies"("code") NOT VALID;



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."cash_shifts"("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."financial_accounts"
    ADD CONSTRAINT "financial_accounts_currency_code_fkey" FOREIGN KEY ("currency_code") REFERENCES "public"."currencies"("code");



ALTER TABLE ONLY "public"."financial_accounts"
    ADD CONSTRAINT "financial_accounts_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."inventory_entry_items"
    ADD CONSTRAINT "iei_entry_id_fkey" FOREIGN KEY ("entry_id") REFERENCES "public"."inventory_entries"("id");



ALTER TABLE ONLY "public"."inventory_entry_items"
    ADD CONSTRAINT "iei_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."inventory_entry_items"
    ADD CONSTRAINT "iei_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."inventory_exit_items"
    ADD CONSTRAINT "iexi_exit_id_fkey" FOREIGN KEY ("exit_id") REFERENCES "public"."inventory_exits"("id");



ALTER TABLE ONLY "public"."inventory_exit_items"
    ADD CONSTRAINT "iexi_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."inventory_exit_items"
    ADD CONSTRAINT "iexi_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_entry_id_fkey" FOREIGN KEY ("inventory_entry_id") REFERENCES "public"."inventory_entries"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_exit_id_fkey" FOREIGN KEY ("inventory_exit_id") REFERENCES "public"."inventory_exits"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_physical_inv_id_fkey" FOREIGN KEY ("physical_inventory_id") REFERENCES "public"."physical_inventories"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_stock_batch_id_fkey" FOREIGN KEY ("stock_batch_id") REFERENCES "public"."warehouse_stock_batches"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "im_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."financial_accounts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_currency_code_fkey" FOREIGN KEY ("currency_code") REFERENCES "public"."currencies"("code");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."purchase_orders"("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."cash_shifts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_store_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."inventory_exits"
    ADD CONSTRAINT "inventory_exits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."inventory_exits"
    ADD CONSTRAINT "inventory_exits_store_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "inventory_movements_currency_code_fkey" FOREIGN KEY ("currency_code") REFERENCES "public"."currencies"("code");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "inventory_movements_sales_return_id_fkey" FOREIGN KEY ("sales_return_id") REFERENCES "public"."sales_returns"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "inventory_movements_transfer_id_fkey" FOREIGN KEY ("transfer_id") REFERENCES "public"."warehouse_transfers"("id");



ALTER TABLE ONLY "public"."journal_entries"
    ADD CONSTRAINT "journal_entries_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."journal_entries"
    ADD CONSTRAINT "journal_entries_period_id_fkey" FOREIGN KEY ("period_id") REFERENCES "public"."accounting_periods"("id");



ALTER TABLE ONLY "public"."journal_entry_lines"
    ADD CONSTRAINT "journal_entry_lines_account_code_fkey" FOREIGN KEY ("account_code") REFERENCES "public"."chart_of_accounts"("code");



ALTER TABLE ONLY "public"."journal_entry_lines"
    ADD CONSTRAINT "journal_entry_lines_journal_entry_id_fkey" FOREIGN KEY ("journal_entry_id") REFERENCES "public"."journal_entries"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_installments"
    ADD CONSTRAINT "order_installments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_unit_code_fkey" FOREIGN KEY ("unit_code") REFERENCES "public"."units_of_measure"("code");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."order_payments"
    ADD CONSTRAINT "order_payments_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."financial_accounts"("id");



ALTER TABLE ONLY "public"."order_payments"
    ADD CONSTRAINT "order_payments_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."order_payments"
    ADD CONSTRAINT "order_payments_currency_code_fkey" FOREIGN KEY ("currency_code") REFERENCES "public"."currencies"("code") NOT VALID;



ALTER TABLE ONLY "public"."order_payments"
    ADD CONSTRAINT "order_payments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_payments"
    ADD CONSTRAINT "order_payments_payment_method_code_fkey" FOREIGN KEY ("payment_method_code") REFERENCES "public"."payment_methods"("code");



ALTER TABLE ONLY "public"."order_payments"
    ADD CONSTRAINT "order_payments_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."cash_shifts"("id");



ALTER TABLE ONLY "public"."order_status_history"
    ADD CONSTRAINT "order_status_history_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."order_status_history"
    ADD CONSTRAINT "order_status_history_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_currency_code_fkey" FOREIGN KEY ("currency_code") REFERENCES "public"."currencies"("code") NOT VALID;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_customer_record_id_fkey" FOREIGN KEY ("customer_record_id") REFERENCES "public"."customers"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_delivery_location_id_fkey" FOREIGN KEY ("delivery_location_id") REFERENCES "public"."customer_locations"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_store_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."product_active_ingredients"
    ADD CONSTRAINT "pai_ingredient_id_fkey" FOREIGN KEY ("ingredient_id") REFERENCES "public"."active_ingredients"("id");



ALTER TABLE ONLY "public"."product_active_ingredients"
    ADD CONSTRAINT "pai_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."payment_methods"
    ADD CONSTRAINT "payment_methods_default_account_id_fkey" FOREIGN KEY ("default_account_id") REFERENCES "public"."financial_accounts"("id");



ALTER TABLE ONLY "public"."physical_inventories"
    ADD CONSTRAINT "pi_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."physical_inventories"
    ADD CONSTRAINT "pi_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."physical_inventory_items"
    ADD CONSTRAINT "pii_counted_by_fkey" FOREIGN KEY ("counted_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."physical_inventory_items"
    ADD CONSTRAINT "pii_inventory_id_fkey" FOREIGN KEY ("physical_inventory_id") REFERENCES "public"."physical_inventories"("id");



ALTER TABLE ONLY "public"."physical_inventory_items"
    ADD CONSTRAINT "pii_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."price_list_items"
    ADD CONSTRAINT "price_list_items_price_list_id_fkey" FOREIGN KEY ("price_list_id") REFERENCES "public"."price_lists"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."price_list_items"
    ADD CONSTRAINT "price_list_items_unit_code_fkey" FOREIGN KEY ("unit_code") REFERENCES "public"."units_of_measure"("code");



ALTER TABLE ONLY "public"."price_list_items"
    ADD CONSTRAINT "price_list_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."price_lists"
    ADD CONSTRAINT "price_lists_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."product_reviews"
    ADD CONSTRAINT "product_reviews_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."product_reviews"
    ADD CONSTRAINT "product_reviews_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."product_unit_conversions"
    ADD CONSTRAINT "product_unit_conversions_unit_code_fkey" FOREIGN KEY ("unit_code") REFERENCES "public"."units_of_measure"("code");



ALTER TABLE ONLY "public"."product_unit_conversions"
    ADD CONSTRAINT "product_unit_conversions_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_base_unit_code_fkey" FOREIGN KEY ("base_unit_code") REFERENCES "public"."units_of_measure"("code");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_brand_id_fkey" FOREIGN KEY ("brand_id") REFERENCES "public"."brands"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_auth_user_id_fkey" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."purchase_invoice_items"
    ADD CONSTRAINT "purchase_invoice_items_inventory_entry_item_id_fkey" FOREIGN KEY ("inventory_entry_item_id") REFERENCES "public"."inventory_entry_items"("id");



ALTER TABLE ONLY "public"."purchase_invoice_items"
    ADD CONSTRAINT "purchase_invoice_items_purchase_invoice_id_fkey" FOREIGN KEY ("purchase_invoice_id") REFERENCES "public"."purchase_invoices"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purchase_invoice_items"
    ADD CONSTRAINT "purchase_invoice_items_purchase_order_item_id_fkey" FOREIGN KEY ("purchase_order_item_id") REFERENCES "public"."purchase_order_items"("id");



ALTER TABLE ONLY "public"."purchase_invoice_items"
    ADD CONSTRAINT "purchase_invoice_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."purchase_invoice_payments"
    ADD CONSTRAINT "purchase_invoice_payments_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."financial_accounts"("id");



ALTER TABLE ONLY "public"."purchase_invoice_payments"
    ADD CONSTRAINT "purchase_invoice_payments_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."purchase_invoice_payments"
    ADD CONSTRAINT "purchase_invoice_payments_payment_method_code_fkey" FOREIGN KEY ("payment_method_code") REFERENCES "public"."payment_methods"("code");



ALTER TABLE ONLY "public"."purchase_invoice_payments"
    ADD CONSTRAINT "purchase_invoice_payments_purchase_invoice_id_fkey" FOREIGN KEY ("purchase_invoice_id") REFERENCES "public"."purchase_invoices"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purchase_invoice_payments"
    ADD CONSTRAINT "purchase_invoice_payments_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."cash_shifts"("id");



ALTER TABLE ONLY "public"."purchase_invoices"
    ADD CONSTRAINT "purchase_invoices_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."purchase_invoices"
    ADD CONSTRAINT "purchase_invoices_currency_code_fkey" FOREIGN KEY ("currency_code") REFERENCES "public"."currencies"("code") NOT VALID;



ALTER TABLE ONLY "public"."purchase_invoices"
    ADD CONSTRAINT "purchase_invoices_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."purchase_orders"("id");



ALTER TABLE ONLY "public"."purchase_invoices"
    ADD CONSTRAINT "purchase_invoices_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."purchase_orders"("id");



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_currency_code_fkey" FOREIGN KEY ("currency_code") REFERENCES "public"."currencies"("code");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."quotation_items"
    ADD CONSTRAINT "quotation_items_quotation_id_fkey" FOREIGN KEY ("quotation_id") REFERENCES "public"."quotations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quotation_items"
    ADD CONSTRAINT "quotation_items_unit_code_fkey" FOREIGN KEY ("unit_code") REFERENCES "public"."units_of_measure"("code");



ALTER TABLE ONLY "public"."quotation_items"
    ADD CONSTRAINT "quotation_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."quotations"
    ADD CONSTRAINT "quotations_converted_order_id_fkey" FOREIGN KEY ("converted_order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."quotations"
    ADD CONSTRAINT "quotations_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."quotations"
    ADD CONSTRAINT "quotations_currency_code_fkey" FOREIGN KEY ("currency_code") REFERENCES "public"."currencies"("code") NOT VALID;



ALTER TABLE ONLY "public"."quotations"
    ADD CONSTRAINT "quotations_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."quotations"
    ADD CONSTRAINT "quotations_customer_record_id_fkey" FOREIGN KEY ("customer_record_id") REFERENCES "public"."customers"("id");



ALTER TABLE ONLY "public"."quotations"
    ADD CONSTRAINT "quotations_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."quotations"
    ADD CONSTRAINT "quotations_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."raffle_tickets"
    ADD CONSTRAINT "raffle_tickets_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id");



ALTER TABLE ONLY "public"."raffle_tickets"
    ADD CONSTRAINT "raffle_tickets_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."raffle_tickets"
    ADD CONSTRAINT "raffle_tickets_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."raffle_tickets"
    ADD CONSTRAINT "raffle_tickets_raffle_id_fkey" FOREIGN KEY ("raffle_id") REFERENCES "public"."raffles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."raffles"
    ADD CONSTRAINT "raffles_winner_customer_id_fkey" FOREIGN KEY ("winner_customer_id") REFERENCES "public"."customers"("id");



ALTER TABLE ONLY "public"."role_permissions"
    ADD CONSTRAINT "role_permissions_permission_id_fkey" FOREIGN KEY ("permission_id") REFERENCES "public"."permissions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."role_permissions"
    ADD CONSTRAINT "role_permissions_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "sales_return_items_order_item_id_fkey" FOREIGN KEY ("order_item_id") REFERENCES "public"."order_items"("id");



ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "sales_return_items_sales_return_id_fkey" FOREIGN KEY ("sales_return_id") REFERENCES "public"."sales_returns"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "sales_return_items_stock_batch_id_fkey" FOREIGN KEY ("stock_batch_id") REFERENCES "public"."warehouse_stock_batches"("id");



ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "sales_return_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."financial_accounts"("id");



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."cash_shifts"("id");



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."shopping_carts"
    ADD CONSTRAINT "shopping_carts_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."sunat_daily_summaries"
    ADD CONSTRAINT "sunat_daily_summaries_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."sunat_daily_summary_items"
    ADD CONSTRAINT "sunat_daily_summary_items_electronic_document_id_fkey" FOREIGN KEY ("electronic_document_id") REFERENCES "public"."electronic_documents"("id");



ALTER TABLE ONLY "public"."sunat_daily_summary_items"
    ADD CONSTRAINT "sunat_daily_summary_items_summary_id_fkey" FOREIGN KEY ("summary_id") REFERENCES "public"."sunat_daily_summaries"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_purchase_invoice_id_fkey" FOREIGN KEY ("purchase_invoice_id") REFERENCES "public"."purchase_invoices"("id");



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."purchase_orders"("id");



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_supplier_credit_id_fkey" FOREIGN KEY ("supplier_credit_id") REFERENCES "public"."supplier_credits"("id");



ALTER TABLE ONLY "public"."supplier_credits"
    ADD CONSTRAINT "supplier_credits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."supplier_credits"
    ADD CONSTRAINT "supplier_credits_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_warehouses"
    ADD CONSTRAINT "user_warehouses_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."user_warehouses"
    ADD CONSTRAINT "user_warehouses_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_warehouses"
    ADD CONSTRAINT "user_warehouses_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."variant_attribute_values"
    ADD CONSTRAINT "vav_attribute_value_id_fkey" FOREIGN KEY ("attribute_value_id") REFERENCES "public"."attribute_values"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."variant_attribute_values"
    ADD CONSTRAINT "vav_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wallet_movements"
    ADD CONSTRAINT "wallet_movements_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id");



ALTER TABLE ONLY "public"."wallet_movements"
    ADD CONSTRAINT "wallet_movements_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."wallet_movements"
    ADD CONSTRAINT "wallet_movements_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "warehouse_stock_batches_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."warehouse_transfer_items"
    ADD CONSTRAINT "warehouse_transfer_items_source_batch_id_fkey" FOREIGN KEY ("source_batch_id") REFERENCES "public"."warehouse_stock_batches"("id");



ALTER TABLE ONLY "public"."warehouse_transfer_items"
    ADD CONSTRAINT "warehouse_transfer_items_transfer_id_fkey" FOREIGN KEY ("transfer_id") REFERENCES "public"."warehouse_transfers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."warehouse_transfer_items"
    ADD CONSTRAINT "warehouse_transfer_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."warehouse_transfers"
    ADD CONSTRAINT "warehouse_transfers_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."warehouse_transfers"
    ADD CONSTRAINT "warehouse_transfers_dest_warehouse_id_fkey" FOREIGN KEY ("dest_warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."warehouse_transfers"
    ADD CONSTRAINT "warehouse_transfers_received_by_fkey" FOREIGN KEY ("received_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."warehouse_transfers"
    ADD CONSTRAINT "warehouse_transfers_source_warehouse_id_fkey" FOREIGN KEY ("source_warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."warehouse_variant_costs"
    ADD CONSTRAINT "warehouse_variant_costs_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."warehouse_variant_costs"
    ADD CONSTRAINT "warehouse_variant_costs_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."warehouses"
    ADD CONSTRAINT "warehouses_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."warehouses"
    ADD CONSTRAINT "warehouses_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "wsb_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "wsb_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "wsb_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "wsb_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "wsb_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



CREATE POLICY "Actualización del propio perfil" ON "public"."profiles" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Administración de monedas por settings.edit" ON "public"."currencies" TO "authenticated" USING ("public"."user_has_permission"('settings.edit'::"text")) WITH CHECK ("public"."user_has_permission"('settings.edit'::"text"));



CREATE POLICY "Admins and owners can manage customer locations" ON "public"."customer_locations" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Admins manage warehouse assignments" ON "public"."user_warehouses" TO "authenticated" USING ("public"."user_has_permission"('warehouses.view_all'::"text")) WITH CHECK ("public"."user_has_permission"('warehouses.view_all'::"text"));



CREATE POLICY "App Settings: Gestión por permiso" ON "public"."app_settings" TO "authenticated" USING ("public"."user_has_permission"('settings.edit'::"text")) WITH CHECK ("public"."user_has_permission"('settings.edit'::"text"));



CREATE POLICY "Asientos: Gestión por permiso" ON "public"."journal_entries" TO "authenticated" USING ("public"."user_has_permission"('accounting.manage'::"text")) WITH CHECK ("public"."user_has_permission"('accounting.manage'::"text"));



CREATE POLICY "Asientos: Lectura por permiso" ON "public"."journal_entries" FOR SELECT TO "authenticated" USING ("public"."user_has_permission"('accounting.read'::"text"));



CREATE POLICY "Atributos: Gestión por permiso" ON "public"."attributes" TO "authenticated" USING (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text"))) WITH CHECK (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text")));



CREATE POLICY "Audit logs: Solo administradores" ON "public"."audit_logs" FOR SELECT TO "authenticated" USING ("public"."user_has_permission"('users.manage'::"text"));



CREATE POLICY "Billetera: Lectura por permiso o propio" ON "public"."wallet_movements" FOR SELECT TO "authenticated" USING ((("auth"."uid"() = "profile_id") OR "public"."user_has_permission"('reports.financial'::"text") OR "public"."user_has_permission"('customers.manage'::"text")));



CREATE POLICY "Business Info: Modificación por permiso" ON "public"."business_info" TO "authenticated" USING ("public"."user_has_permission"('settings.edit'::"text")) WITH CHECK ("public"."user_has_permission"('settings.edit'::"text"));



CREATE POLICY "Carritos: Acceso propio o gestión" ON "public"."shopping_carts" TO "authenticated" USING ((("profile_id" = "extensions"."auth_profile_id"()) OR "public"."user_has_permission"('customers.manage'::"text")));



CREATE POLICY "Categorías gastos: Gestión por permiso" ON "public"."expense_categories" TO "authenticated" USING ("public"."user_has_permission"('finance.read'::"text")) WITH CHECK ("public"."user_has_permission"('finance.manage'::"text"));



CREATE POLICY "Categorías: Gestión por permiso" ON "public"."categories" TO "authenticated" USING ("public"."user_has_permission"('categories.manage'::"text")) WITH CHECK ("public"."user_has_permission"('categories.manage'::"text"));



CREATE POLICY "Checkins: Lectura por permiso o propio" ON "public"."daily_checkins" FOR SELECT TO "authenticated" USING ((("profile_id" = "extensions"."auth_profile_id"()) OR "public"."user_has_permission"('customers.manage'::"text")));



CREATE POLICY "Clientes: Gestión por permiso" ON "public"."customers" TO "authenticated" USING (("public"."user_has_permission"('customers.manage'::"text") OR "public"."user_has_permission"('pos.sale'::"text"))) WITH CHECK (("public"."user_has_permission"('customers.manage'::"text") OR "public"."user_has_permission"('pos.sale'::"text")));



CREATE POLICY "Clientes: Lectura por permiso o propio" ON "public"."customers" FOR SELECT TO "authenticated" USING ((("profile_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."auth_user_id" = "auth"."uid"()))) OR "public"."user_has_permission"('customers.read'::"text") OR "public"."user_has_permission"('pos.sale'::"text") OR "public"."user_has_permission"('orders.read'::"text")));



CREATE POLICY "Compras: Gestión por permiso" ON "public"."purchase_orders" TO "authenticated" USING (("public"."user_has_permission"('purchases.create'::"text") OR "public"."user_has_permission"('purchases.view'::"text"))) WITH CHECK ("public"."user_has_permission"('purchases.create'::"text"));



CREATE POLICY "Compras: Inserción por permiso" ON "public"."purchase_orders" FOR INSERT TO "authenticated" WITH CHECK ("public"."user_has_permission"('purchases.create'::"text"));



CREATE POLICY "Compras: Lectura por permiso" ON "public"."purchase_orders" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('purchases.view'::"text") OR "public"."user_has_permission"('purchases.create'::"text")));



CREATE POLICY "Comprobantes electrónicos: Gestión por permiso" ON "public"."electronic_documents" TO "authenticated" USING ("public"."user_has_permission"('orders.read'::"text")) WITH CHECK ("public"."user_has_permission"('pos.sell'::"text"));



CREATE POLICY "Conversiones UOM: Gestión por permiso" ON "public"."product_unit_conversions" TO "authenticated" USING ("public"."user_has_permission"('products.manage'::"text")) WITH CHECK ("public"."user_has_permission"('products.manage'::"text"));



CREATE POLICY "Conversiones UOM: Lectura autenticada" ON "public"."product_unit_conversions" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Costos por almacén: Gestión por permiso" ON "public"."warehouse_variant_costs" TO "authenticated" USING ("public"."user_has_permission"('inventory.manage'::"text")) WITH CHECK ("public"."user_has_permission"('inventory.manage'::"text"));



CREATE POLICY "Costos por almacén: Lectura por permiso" ON "public"."warehouse_variant_costs" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('inventory.read'::"text") OR "public"."user_has_permission"('pos.sale'::"text")));



CREATE POLICY "Cotizaciones: Gestión por permiso" ON "public"."quotations" TO "authenticated" USING (("public"."user_has_permission"('orders.read'::"text") OR "public"."user_has_permission"('pos.sell'::"text"))) WITH CHECK (("public"."user_has_permission"('orders.create'::"text") OR "public"."user_has_permission"('pos.sell'::"text")));



CREATE POLICY "Créditos cliente: Gestión por permiso" ON "public"."customer_credits" TO "authenticated" USING ("public"."user_has_permission"('credits.manage'::"text")) WITH CHECK ("public"."user_has_permission"('credits.manage'::"text"));



CREATE POLICY "Créditos cliente: Lectura por permiso o propio" ON "public"."customer_credits" FOR SELECT TO "authenticated" USING ((("auth"."uid"() = "profile_id") OR "public"."user_has_permission"('credits.manage'::"text") OR "public"."user_has_permission"('reports.financial'::"text")));



CREATE POLICY "Créditos proveedor: Lectura por permiso" ON "public"."supplier_credits" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('purchases.view'::"text") OR "public"."user_has_permission"('reports.financial'::"text")));



CREATE POLICY "Cuentas: Gestión por permiso" ON "public"."financial_accounts" TO "authenticated" USING ("public"."user_has_permission"('financial.accounts.manage'::"text")) WITH CHECK ("public"."user_has_permission"('financial.accounts.manage'::"text"));



CREATE POLICY "Cuotas orden: Gestión por permiso" ON "public"."order_installments" TO "authenticated" USING ("public"."user_has_permission"('orders.read'::"text")) WITH CHECK ("public"."user_has_permission"('pos.sale'::"text"));



CREATE POLICY "Devoluciones: Gestión por permiso" ON "public"."sales_returns" TO "authenticated" USING (("public"."user_has_permission"('orders.read'::"text") OR "public"."user_has_permission"('pos.sell'::"text"))) WITH CHECK (("public"."user_has_permission"('orders.cancel'::"text") OR "public"."user_has_permission"('pos.sell'::"text")));



CREATE POLICY "Entradas: Lectura por permiso" ON "public"."inventory_entries" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('inventory.view'::"text") OR "public"."user_has_permission"('inventory.entries'::"text")));



CREATE POLICY "Facturas compra: Gestión por permiso" ON "public"."purchase_invoices" TO "authenticated" USING (("public"."user_has_permission"('finance.read'::"text") OR "public"."user_has_permission"('inventory.read'::"text"))) WITH CHECK (("public"."user_has_permission"('finance.manage'::"text") OR "public"."user_has_permission"('inventory.manage'::"text")));



CREATE POLICY "Financial accounts: read all for authenticated" ON "public"."financial_accounts" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Gastos: Gestión por permiso" ON "public"."expenses" TO "authenticated" USING ("public"."user_has_permission"('finance.read'::"text")) WITH CHECK ("public"."user_has_permission"('finance.manage'::"text"));



CREATE POLICY "Guías remisión: Gestión por permiso" ON "public"."dispatch_guides" TO "authenticated" USING (("public"."user_has_permission"('inventory.read'::"text") OR "public"."user_has_permission"('orders.read'::"text"))) WITH CHECK (("public"."user_has_permission"('inventory.manage'::"text") OR "public"."user_has_permission"('pos.sale'::"text")));



CREATE POLICY "Historial estados orden: Lectura por permiso" ON "public"."order_status_history" FOR SELECT TO "authenticated" USING ("public"."user_has_permission"('orders.read'::"text"));



CREATE POLICY "Imágenes producto: Gestión por permiso" ON "public"."product_images" TO "authenticated" USING (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text"))) WITH CHECK (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text")));



CREATE POLICY "Ingredientes activos producto: Gestión" ON "public"."product_active_ingredients" TO "authenticated" USING (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text"))) WITH CHECK (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text")));



CREATE POLICY "Ingredientes activos: Gestión" ON "public"."active_ingredients" TO "authenticated" USING (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text"))) WITH CHECK (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text")));



CREATE POLICY "Insercion de reviews" ON "public"."product_reviews" FOR INSERT WITH CHECK (("profile_id" = "extensions"."auth_profile_id"()));



CREATE POLICY "Insercion propia de checkins" ON "public"."daily_checkins" FOR INSERT WITH CHECK (("profile_id" = "extensions"."auth_profile_id"()));



CREATE POLICY "Inventario: Entradas por permiso" ON "public"."inventory_entries" FOR INSERT TO "authenticated" WITH CHECK ("public"."user_has_permission"('inventory.entries'::"text"));



CREATE POLICY "Inventario: Salidas por permiso" ON "public"."inventory_exits" FOR INSERT TO "authenticated" WITH CHECK ("public"."user_has_permission"('inventory.exits'::"text"));



CREATE POLICY "Items carrito: Acceso propio o gestión" ON "public"."cart_items" TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."shopping_carts" "sc"
  WHERE (("sc"."id" = "cart_items"."cart_id") AND ("sc"."profile_id" = "extensions"."auth_profile_id"())))) OR "public"."user_has_permission"('customers.manage'::"text")));



CREATE POLICY "Items compra: Gestión por permiso" ON "public"."purchase_order_items" TO "authenticated" USING ("public"."user_has_permission"('purchases.create'::"text")) WITH CHECK ("public"."user_has_permission"('purchases.create'::"text"));



CREATE POLICY "Items compra: Lectura por permiso" ON "public"."purchase_order_items" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('purchases.view'::"text") OR "public"."user_has_permission"('purchases.create'::"text")));



CREATE POLICY "Items cotización: Gestión por permiso" ON "public"."quotation_items" TO "authenticated" USING (("public"."user_has_permission"('orders.read'::"text") OR "public"."user_has_permission"('pos.sell'::"text"))) WITH CHECK (("public"."user_has_permission"('orders.create'::"text") OR "public"."user_has_permission"('pos.sell'::"text")));



CREATE POLICY "Items devolución: Gestión por permiso" ON "public"."sales_return_items" TO "authenticated" USING (("public"."user_has_permission"('orders.read'::"text") OR "public"."user_has_permission"('pos.sell'::"text"))) WITH CHECK (("public"."user_has_permission"('orders.cancel'::"text") OR "public"."user_has_permission"('pos.sell'::"text")));



CREATE POLICY "Items entradas: Inserción por permiso" ON "public"."inventory_entry_items" FOR INSERT TO "authenticated" WITH CHECK ("public"."user_has_permission"('inventory.entries'::"text"));



CREATE POLICY "Items entradas: Lectura por permiso" ON "public"."inventory_entry_items" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('inventory.view'::"text") OR "public"."user_has_permission"('inventory.entries'::"text")));



CREATE POLICY "Items factura compra: Gestión por permiso" ON "public"."purchase_invoice_items" TO "authenticated" USING (("public"."user_has_permission"('finance.read'::"text") OR "public"."user_has_permission"('inventory.read'::"text"))) WITH CHECK (("public"."user_has_permission"('finance.manage'::"text") OR "public"."user_has_permission"('inventory.manage'::"text")));



CREATE POLICY "Items guía remisión: Gestión por permiso" ON "public"."dispatch_guide_items" TO "authenticated" USING (("public"."user_has_permission"('inventory.read'::"text") OR "public"."user_has_permission"('orders.read'::"text"))) WITH CHECK (("public"."user_has_permission"('inventory.manage'::"text") OR "public"."user_has_permission"('pos.sale'::"text")));



CREATE POLICY "Items lista precios: Gestión por permiso" ON "public"."price_list_items" TO "authenticated" USING ("public"."user_has_permission"('products.manage'::"text")) WITH CHECK ("public"."user_has_permission"('products.manage'::"text"));



CREATE POLICY "Items lista precios: Lectura autenticada" ON "public"."price_list_items" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Items orden: Inserción por permiso o cliente propio" ON "public"."order_items" FOR INSERT TO "authenticated" WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."orders" "o"
  WHERE (("o"."id" = "order_items"."order_id") AND ("o"."customer_id" = "auth"."uid"())))) OR "public"."user_has_permission"('pos.sale'::"text")));



CREATE POLICY "Items orden: Lectura por permiso o cliente propio" ON "public"."order_items" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."orders" "o"
  WHERE (("o"."id" = "order_items"."order_id") AND ("o"."customer_id" = "auth"."uid"())))) OR "public"."user_has_permission"('pos.view'::"text") OR "public"."user_has_permission"('pos.sale'::"text") OR "public"."user_has_permission"('reports.sales'::"text")));



CREATE POLICY "Items salidas: Inserción por permiso" ON "public"."inventory_exit_items" FOR INSERT TO "authenticated" WITH CHECK ("public"."user_has_permission"('inventory.exits'::"text"));



CREATE POLICY "Items salidas: Lectura por permiso" ON "public"."inventory_exit_items" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('inventory.view'::"text") OR "public"."user_has_permission"('inventory.exits'::"text")));



CREATE POLICY "Items tomas físicas: Gestión por permiso" ON "public"."physical_inventory_items" TO "authenticated" USING (("public"."user_has_permission"('inventory.physical_count'::"text") OR "public"."user_has_permission"('inventory.adjust'::"text"))) WITH CHECK (("public"."user_has_permission"('inventory.physical_count'::"text") OR "public"."user_has_permission"('inventory.adjust'::"text")));



CREATE POLICY "Items transferencia: Gestión por permiso" ON "public"."warehouse_transfer_items" TO "authenticated" USING ("public"."user_has_permission"('inventory.read'::"text")) WITH CHECK ("public"."user_has_permission"('inventory.manage'::"text"));



CREATE POLICY "Kardex: Inserción por permiso" ON "public"."inventory_movements" FOR INSERT TO "authenticated" WITH CHECK (("public"."user_has_permission"('inventory.entries'::"text") OR "public"."user_has_permission"('inventory.exits'::"text") OR "public"."user_has_permission"('pos.sale'::"text")));



CREATE POLICY "Kardex: Lectura por permiso" ON "public"."inventory_movements" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('inventory.kardex'::"text") OR "public"."user_has_permission"('inventory.view'::"text")));



CREATE POLICY "Lectura de monedas para personal autenticado" ON "public"."currencies" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Lectura publica" ON "public"."active_ingredients" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."app_settings" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."attribute_values" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."attributes" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."brands" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."categories" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."product_active_ingredients" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."product_images" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."product_variants" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."products" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."variant_attribute_values" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de business_info" ON "public"."business_info" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de reviews" ON "public"."product_reviews" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de stock" ON "public"."warehouse_stock_batches" FOR SELECT USING (true);



CREATE POLICY "Listas de precios: Gestión por permiso" ON "public"."price_lists" TO "authenticated" USING ("public"."user_has_permission"('products.manage'::"text")) WITH CHECK ("public"."user_has_permission"('products.manage'::"text"));



CREATE POLICY "Listas de precios: Lectura autenticada" ON "public"."price_lists" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Lotes de stock: Gestión por permiso" ON "public"."warehouse_stock_batches" TO "authenticated" USING (("public"."user_has_permission"('inventory.adjust'::"text") OR "public"."user_has_permission"('warehouses.manage'::"text"))) WITH CHECK (("public"."user_has_permission"('inventory.adjust'::"text") OR "public"."user_has_permission"('warehouses.manage'::"text")));



CREATE POLICY "Lotes de stock: Lectura por permiso" ON "public"."warehouse_stock_batches" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('inventory.view'::"text") OR "public"."user_has_permission"('warehouses.manage'::"text")));



CREATE POLICY "Líneas asiento: Gestión por permiso" ON "public"."journal_entry_lines" TO "authenticated" USING ("public"."user_has_permission"('accounting.manage'::"text")) WITH CHECK ("public"."user_has_permission"('accounting.manage'::"text"));



CREATE POLICY "Líneas asiento: Lectura por permiso" ON "public"."journal_entry_lines" FOR SELECT TO "authenticated" USING ("public"."user_has_permission"('accounting.read'::"text"));



CREATE POLICY "Líneas reglas contables: Gestión por permiso" ON "public"."accounting_posting_rule_lines" TO "authenticated" USING ("public"."user_has_permission"('accounting.manage'::"text")) WITH CHECK ("public"."user_has_permission"('accounting.manage'::"text"));



CREATE POLICY "Líneas reglas contables: Lectura por permiso" ON "public"."accounting_posting_rule_lines" FOR SELECT TO "authenticated" USING ("public"."user_has_permission"('accounting.read'::"text"));



CREATE POLICY "Marcas: Gestión por permiso" ON "public"."brands" TO "authenticated" USING ("public"."user_has_permission"('brands.manage'::"text")) WITH CHECK ("public"."user_has_permission"('brands.manage'::"text"));



CREATE POLICY "Movimientos crédito cliente: Inserción por permiso" ON "public"."customer_credit_movements" FOR INSERT TO "authenticated" WITH CHECK (("public"."user_has_permission"('credits.manage'::"text") OR "public"."user_has_permission"('pos.sale'::"text")));



CREATE POLICY "Movimientos crédito cliente: Lectura por permiso o propio" ON "public"."customer_credit_movements" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('credits.manage'::"text") OR "public"."user_has_permission"('reports.financial'::"text")));



CREATE POLICY "Movimientos crédito proveedor: Inserción por permiso" ON "public"."supplier_credit_movements" FOR INSERT TO "authenticated" WITH CHECK (("public"."user_has_permission"('purchases.create'::"text") OR "public"."user_has_permission"('financial.movements.create'::"text")));



CREATE POLICY "Movimientos crédito proveedor: Lectura por permiso" ON "public"."supplier_credit_movements" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('purchases.view'::"text") OR "public"."user_has_permission"('reports.financial'::"text")));



CREATE POLICY "Movimientos cuenta: Inserción por permiso" ON "public"."account_movements" FOR INSERT TO "authenticated" WITH CHECK (("public"."user_has_permission"('financial.movements.create'::"text") OR "public"."user_has_permission"('financial.accounts.manage'::"text")));



CREATE POLICY "Movimientos cuenta: Lectura por permiso" ON "public"."account_movements" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('financial.accounts.manage'::"text") OR "public"."user_has_permission"('reports.financial'::"text")));



CREATE POLICY "Métodos de pago: Gestión por permiso" ON "public"."payment_methods" TO "authenticated" USING ("public"."user_has_permission"('finance.manage'::"text")) WITH CHECK ("public"."user_has_permission"('finance.manage'::"text"));



CREATE POLICY "Métodos de pago: Lectura autenticada" ON "public"."payment_methods" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "PCGE: Gestión por permiso" ON "public"."chart_of_accounts" TO "authenticated" USING ("public"."user_has_permission"('accounting.manage'::"text")) WITH CHECK ("public"."user_has_permission"('accounting.manage'::"text"));



CREATE POLICY "PCGE: Lectura autenticada" ON "public"."chart_of_accounts" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Pagos factura compra: Gestión por permiso" ON "public"."purchase_invoice_payments" TO "authenticated" USING ("public"."user_has_permission"('finance.read'::"text")) WITH CHECK ("public"."user_has_permission"('finance.manage'::"text"));



CREATE POLICY "Pagos orden: Inserción por permiso" ON "public"."order_payments" FOR INSERT TO "authenticated" WITH CHECK (("public"."user_has_permission"('orders.create'::"text") OR "public"."user_has_permission"('pos.sell'::"text")));



CREATE POLICY "Pagos orden: Lectura por permiso o cliente propio" ON "public"."order_payments" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."orders" "o"
  WHERE (("o"."id" = "order_payments"."order_id") AND ("o"."customer_id" = "auth"."uid"())))) OR "public"."user_has_permission"('orders.read'::"text") OR "public"."user_has_permission"('pos.sell'::"text")));



CREATE POLICY "Perfiles: Gestión por permiso o propio" ON "public"."profiles" TO "authenticated" USING ((("auth"."uid"() = "auth_user_id") OR ("auth"."uid"() = "id") OR "public"."user_has_permission"('users.manage'::"text") OR "public"."user_has_permission"('customers.manage'::"text") OR "public"."user_has_permission"('pos.sale'::"text"))) WITH CHECK ((("auth"."uid"() = "auth_user_id") OR ("auth"."uid"() = "id") OR "public"."user_has_permission"('users.manage'::"text") OR "public"."user_has_permission"('customers.manage'::"text") OR "public"."user_has_permission"('pos.sale'::"text")));



CREATE POLICY "Perfiles: Lectura por permiso o propio" ON "public"."profiles" FOR SELECT TO "authenticated" USING ((("auth"."uid"() = "auth_user_id") OR ("auth"."uid"() = "id") OR "public"."user_has_permission"('users.view'::"text") OR "public"."user_has_permission"('customers.view'::"text") OR "public"."user_has_permission"('pos.view'::"text") OR "public"."user_has_permission"('pos.sale'::"text")));



CREATE POLICY "Periodos contables: Gestión por permiso" ON "public"."accounting_periods" TO "authenticated" USING ("public"."user_has_permission"('accounting.manage'::"text")) WITH CHECK ("public"."user_has_permission"('accounting.manage'::"text"));



CREATE POLICY "Periodos contables: Lectura por permiso" ON "public"."accounting_periods" FOR SELECT TO "authenticated" USING ("public"."user_has_permission"('accounting.read'::"text"));



CREATE POLICY "Permitir lectura de permisos a usuarios autenticados" ON "public"."permissions" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Permitir lectura de role_permissions a usuarios autenticados" ON "public"."role_permissions" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Permitir lectura de roles a usuarios autenticados" ON "public"."roles" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Productos: Crear por permiso" ON "public"."products" FOR INSERT TO "authenticated" WITH CHECK ("public"."user_has_permission"('products.create'::"text"));



CREATE POLICY "Productos: Eliminar por permiso" ON "public"."products" FOR DELETE TO "authenticated" USING ("public"."user_has_permission"('products.delete'::"text"));



CREATE POLICY "Productos: Modificar por permiso" ON "public"."products" FOR UPDATE TO "authenticated" USING ("public"."user_has_permission"('products.edit'::"text"));



CREATE POLICY "Proveedores: Gestión por permiso" ON "public"."suppliers" TO "authenticated" USING ("public"."user_has_permission"('suppliers.manage'::"text")) WITH CHECK ("public"."user_has_permission"('suppliers.manage'::"text"));



CREATE POLICY "Proveedores: Lectura por permiso" ON "public"."suppliers" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('suppliers.view'::"text") OR "public"."user_has_permission"('suppliers.manage'::"text")));



CREATE POLICY "Reglas contables: Gestión por permiso" ON "public"."accounting_posting_rules" TO "authenticated" USING ("public"."user_has_permission"('accounting.manage'::"text")) WITH CHECK ("public"."user_has_permission"('accounting.manage'::"text"));



CREATE POLICY "Reglas contables: Lectura por permiso" ON "public"."accounting_posting_rules" FOR SELECT TO "authenticated" USING ("public"."user_has_permission"('accounting.read'::"text"));



CREATE POLICY "Reseñas: Eliminación por permiso o propio" ON "public"."product_reviews" FOR DELETE TO "authenticated" USING ((("profile_id" = "extensions"."auth_profile_id"()) OR "public"."user_has_permission"('products.edit'::"text")));



CREATE POLICY "Reseñas: Modificación por permiso o propio" ON "public"."product_reviews" FOR UPDATE TO "authenticated" USING ((("profile_id" = "extensions"."auth_profile_id"()) OR "public"."user_has_permission"('products.edit'::"text")));



CREATE POLICY "SUNAT resumen items: Gestión por permiso" ON "public"."sunat_daily_summary_items" TO "authenticated" USING ("public"."user_has_permission"('orders.read'::"text")) WITH CHECK ("public"."user_has_permission"('pos.sale'::"text"));



CREATE POLICY "SUNAT resúmenes: Gestión por permiso" ON "public"."sunat_daily_summaries" TO "authenticated" USING ("public"."user_has_permission"('orders.read'::"text")) WITH CHECK ("public"."user_has_permission"('pos.sale'::"text"));



CREATE POLICY "Salidas: Lectura por permiso" ON "public"."inventory_exits" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('inventory.view'::"text") OR "public"."user_has_permission"('inventory.exits'::"text")));



CREATE POLICY "Series administrables por personal con permiso de configuració" ON "public"."document_series" TO "authenticated" USING ("public"."user_has_permission"('settings.edit'::"text")) WITH CHECK ("public"."user_has_permission"('settings.edit'::"text"));



CREATE POLICY "Series legibles por personal con acceso" ON "public"."document_series" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('pos.view'::"text") OR "public"."user_has_permission"('pos.sale'::"text") OR "public"."user_has_permission"('settings.view'::"text") OR "public"."user_has_permission"('settings.edit'::"text")));



CREATE POLICY "Solo administradores pueden asignar user_roles" ON "public"."user_roles" TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());



CREATE POLICY "Solo administradores pueden modificar permisos" ON "public"."permissions" TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());



CREATE POLICY "Solo administradores pueden modificar role_permissions" ON "public"."role_permissions" TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());



CREATE POLICY "Solo administradores pueden modificar roles" ON "public"."roles" TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());



CREATE POLICY "Sorteos: Lectura autenticada" ON "public"."raffles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Tickets sorteo: Lectura propia o permiso" ON "public"."raffle_tickets" FOR SELECT TO "authenticated" USING ((("profile_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."auth_user_id" = "auth"."uid"()))) OR "public"."user_has_permission"('customers.read'::"text")));



CREATE POLICY "Tipo cambio: Gestión por permiso" ON "public"."exchange_rates" TO "authenticated" USING ("public"."user_has_permission"('finance.manage'::"text")) WITH CHECK ("public"."user_has_permission"('finance.manage'::"text"));



CREATE POLICY "Tipo cambio: Lectura autenticada" ON "public"."exchange_rates" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Tomas físicas: Gestión por permiso" ON "public"."physical_inventories" TO "authenticated" USING (("public"."user_has_permission"('inventory.physical_count'::"text") OR "public"."user_has_permission"('inventory.adjust'::"text"))) WITH CHECK (("public"."user_has_permission"('inventory.physical_count'::"text") OR "public"."user_has_permission"('inventory.adjust'::"text")));



CREATE POLICY "Transferencias: Gestión por permiso" ON "public"."warehouse_transfers" TO "authenticated" USING ("public"."user_has_permission"('inventory.read'::"text")) WITH CHECK ("public"."user_has_permission"('inventory.manage'::"text"));



CREATE POLICY "Turnos de caja: Apertura por permiso" ON "public"."cash_shifts" FOR INSERT TO "authenticated" WITH CHECK (("public"."user_has_permission"('pos.cash_shift.open'::"text") AND ("opened_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Turnos de caja: Cierre por permiso" ON "public"."cash_shifts" FOR UPDATE TO "authenticated" USING ("public"."user_has_permission"('pos.cash_shift.close'::"text"));



CREATE POLICY "Turnos de caja: Lectura por permiso o propio" ON "public"."cash_shifts" FOR SELECT TO "authenticated" USING ((("opened_by" = "extensions"."auth_profile_id"()) OR ("closed_by" = "extensions"."auth_profile_id"()) OR "public"."user_has_permission"('pos.cash_shift.view'::"text") OR "public"."user_has_permission"('pos.view'::"text")));



CREATE POLICY "UOM: Gestión por permiso" ON "public"."units_of_measure" TO "authenticated" USING ("public"."user_has_permission"('products.manage'::"text")) WITH CHECK ("public"."user_has_permission"('products.manage'::"text"));



CREATE POLICY "UOM: Lectura autenticada" ON "public"."units_of_measure" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Ubicaciones: Gestión por permiso o propio" ON "public"."customer_locations" TO "authenticated" USING ((("auth"."uid"() = "profile_id") OR "public"."user_has_permission"('customers.manage'::"text"))) WITH CHECK ((("auth"."uid"() = "profile_id") OR "public"."user_has_permission"('customers.manage'::"text")));



CREATE POLICY "Users can view own warehouse assignments" ON "public"."user_warehouses" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "user_warehouses"."profile_id") AND ("p"."auth_user_id" = "auth"."uid"())))) OR "public"."user_has_permission"('warehouses.view_all'::"text")));



CREATE POLICY "Usuarios pueden ver sus propios roles asignados" ON "public"."user_roles" FOR SELECT TO "authenticated" USING ((("profile_id" IN ( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("profiles"."auth_user_id" = "auth"."uid"()))) OR "public"."is_admin"()));



CREATE POLICY "Valores atributo: Gestión por permiso" ON "public"."attribute_values" TO "authenticated" USING (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text"))) WITH CHECK (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text")));



CREATE POLICY "Valores variante: Gestión por permiso" ON "public"."variant_attribute_values" TO "authenticated" USING (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text"))) WITH CHECK (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text")));



CREATE POLICY "Variantes: Gestión por permiso" ON "public"."product_variants" TO "authenticated" USING (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text"))) WITH CHECK (("public"."user_has_permission"('products.edit'::"text") OR "public"."user_has_permission"('products.create'::"text")));



CREATE POLICY "Warehouses: manage for authenticated" ON "public"."warehouses" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Warehouses: view all or assigned" ON "public"."warehouses" FOR SELECT TO "authenticated" USING (("public"."user_has_permission"('warehouses.view_all'::"text") OR (EXISTS ( SELECT 1
   FROM ("public"."user_warehouses" "uw"
     JOIN "public"."profiles" "p" ON (("p"."id" = "uw"."profile_id")))
  WHERE (("p"."auth_user_id" = "auth"."uid"()) AND ("uw"."warehouse_id" = "warehouses"."id"))))));



CREATE POLICY "Wishlist: Acceso propio o gestión" ON "public"."wishlist" TO "authenticated" USING ((("profile_id" = "extensions"."auth_profile_id"()) OR "public"."user_has_permission"('customers.manage'::"text")));



ALTER TABLE "public"."account_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."accounting_periods" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."accounting_posting_rule_lines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."accounting_posting_rules" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."active_ingredients" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."app_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."attribute_values" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."attributes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."audit_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."brands" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."business_info" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cart_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cash_shifts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."chart_of_accounts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."currencies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_credit_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_credits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_locations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."daily_checkins" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."dispatch_guide_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."dispatch_guides" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."document_series" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."electronic_documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."exchange_rates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."expense_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."expenses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."financial_accounts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."import_batches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_entry_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_exit_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_exits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."journal_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."journal_entry_lines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_installments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_payments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_status_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payment_methods" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."permissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."physical_inventories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."physical_inventory_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."price_list_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."price_lists" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_active_ingredients" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_images" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_unit_conversions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_variants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."purchase_invoice_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."purchase_invoice_payments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."purchase_invoices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."purchase_order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."purchase_orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."quotation_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."quotations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."raffle_tickets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."raffles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."role_permissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sales_return_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sales_returns" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shopping_carts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sunat_daily_summaries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sunat_daily_summary_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."supplier_credit_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."supplier_credits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."suppliers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."units_of_measure" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_warehouses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."variant_attribute_values" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wallet_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouse_stock_batches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouse_transfer_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouse_transfers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouse_variant_costs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wishlist" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Órdenes: Inserción por permiso o cliente propio" ON "public"."orders" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() = "customer_id") OR "public"."user_has_permission"('pos.sale'::"text")));



CREATE POLICY "Órdenes: Lectura por permiso o cliente propio" ON "public"."orders" FOR SELECT TO "authenticated" USING ((("auth"."uid"() = "customer_id") OR "public"."user_has_permission"('pos.view'::"text") OR "public"."user_has_permission"('pos.sale'::"text") OR "public"."user_has_permission"('reports.sales'::"text")));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "service_role";























































































































































































GRANT ALL ON FUNCTION "public"."award_mini_game_points"("p_profile_id" "uuid", "p_movement_type" "text", "p_points" integer, "p_description" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."award_mini_game_points"("p_profile_id" "uuid", "p_movement_type" "text", "p_points" integer, "p_description" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."award_mini_game_points"("p_profile_id" "uuid", "p_movement_type" "text", "p_points" integer, "p_description" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."calc_expected_shift_rpc"("p_shift_id" "uuid", "p_account_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calc_expected_shift_rpc"("p_shift_id" "uuid", "p_account_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calc_expected_shift_rpc"("p_shift_id" "uuid", "p_account_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_purchase_order_rpc"("p_purchase_order_id" "uuid", "p_account_id" "uuid", "p_profile_id" "uuid", "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_purchase_order_rpc"("p_purchase_order_id" "uuid", "p_account_id" "uuid", "p_profile_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_purchase_order_rpc"("p_purchase_order_id" "uuid", "p_account_id" "uuid", "p_profile_id" "uuid", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."claim_daily_checkin"("p_profile_id" "uuid", "p_action_by" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."claim_daily_checkin"("p_profile_id" "uuid", "p_action_by" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."claim_daily_checkin"("p_profile_id" "uuid", "p_action_by" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."clear_cloud_cart_rpc"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."clear_cloud_cart_rpc"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."clear_cloud_cart_rpc"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_purchase_order_rpc"("p_supplier_id" "uuid", "p_supplier_name" "text", "p_warehouse_id" "uuid", "p_total_amount" numeric, "p_payment_method" "text", "p_payment_status" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_due_date" "date", "p_document_date" "date", "p_document_type" "text", "p_document_number" "text", "p_notes" "text", "p_profile_id" "uuid", "p_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."create_purchase_order_rpc"("p_supplier_id" "uuid", "p_supplier_name" "text", "p_warehouse_id" "uuid", "p_total_amount" numeric, "p_payment_method" "text", "p_payment_status" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_due_date" "date", "p_document_date" "date", "p_document_type" "text", "p_document_number" "text", "p_notes" "text", "p_profile_id" "uuid", "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_purchase_order_rpc"("p_supplier_id" "uuid", "p_supplier_name" "text", "p_warehouse_id" "uuid", "p_total_amount" numeric, "p_payment_method" "text", "p_payment_status" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_due_date" "date", "p_document_date" "date", "p_document_type" "text", "p_document_number" "text", "p_notes" "text", "p_profile_id" "uuid", "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_purchase_order_rpc"("p_supplier_id" "uuid", "p_supplier_name" "text", "p_warehouse_id" "uuid", "p_total_amount" numeric, "p_payment_method" "text", "p_payment_status" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_due_date" "date", "p_document_date" "date", "p_document_type" "text", "p_document_number" "text", "p_notes" "text", "p_profile_id" "uuid", "p_items" "jsonb", "p_currency_code" "text", "p_exchange_rate" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."create_purchase_order_rpc"("p_supplier_id" "uuid", "p_supplier_name" "text", "p_warehouse_id" "uuid", "p_total_amount" numeric, "p_payment_method" "text", "p_payment_status" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_due_date" "date", "p_document_date" "date", "p_document_type" "text", "p_document_number" "text", "p_notes" "text", "p_profile_id" "uuid", "p_items" "jsonb", "p_currency_code" "text", "p_exchange_rate" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_purchase_order_rpc"("p_supplier_id" "uuid", "p_supplier_name" "text", "p_warehouse_id" "uuid", "p_total_amount" numeric, "p_payment_method" "text", "p_payment_status" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_due_date" "date", "p_document_date" "date", "p_document_type" "text", "p_document_number" "text", "p_notes" "text", "p_profile_id" "uuid", "p_items" "jsonb", "p_currency_code" "text", "p_exchange_rate" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_active_ingredient_safely"("p_ingredient_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_active_ingredient_safely"("p_ingredient_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_active_ingredient_safely"("p_ingredient_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_product_safely"("p_product_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_product_safely"("p_product_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_product_safely"("p_product_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_user_force"("p_user_id" "uuid", "p_reassign_to" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_user_force"("p_user_id" "uuid", "p_reassign_to" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_user_force"("p_user_id" "uuid", "p_reassign_to" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_user_safely"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_user_safely"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_user_safely"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."find_existing_variants_for_import"("p_names" "text"[], "p_skus" "text"[], "p_warehouse_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."find_existing_variants_for_import"("p_names" "text"[], "p_skus" "text"[], "p_warehouse_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_existing_variants_for_import"("p_names" "text"[], "p_skus" "text"[], "p_warehouse_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_cash_shifts_summary_rpc"("p_limit" integer, "p_offset" integer, "p_status" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_profile_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_cash_shifts_summary_rpc"("p_limit" integer, "p_offset" integer, "p_status" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_profile_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_cash_shifts_summary_rpc"("p_limit" integer, "p_offset" integer, "p_status" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_profile_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_credit_movements_totals_rpc"("p_credit_id" "uuid", "p_date_filter" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_credit_movements_totals_rpc"("p_credit_id" "uuid", "p_date_filter" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_credit_movements_totals_rpc"("p_credit_id" "uuid", "p_date_filter" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_customer_credits_stats_rpc"("p_search_query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_customer_credits_stats_rpc"("p_search_query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_customer_credits_stats_rpc"("p_search_query" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_customers_global_stats_rpc"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_customers_global_stats_rpc"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_customers_global_stats_rpc"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_dashboard_sales_overview"("p_from" "date", "p_to" "date", "p_warehouse_id" "uuid", "p_tz" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_dashboard_sales_overview"("p_from" "date", "p_to" "date", "p_warehouse_id" "uuid", "p_tz" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dashboard_sales_overview"("p_from" "date", "p_to" "date", "p_warehouse_id" "uuid", "p_tz" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_loyalty_dashboard"("p_auth_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_loyalty_dashboard"("p_auth_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_loyalty_dashboard"("p_auth_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_movement_totals_rpc"("p_filter_type" "text", "p_account_id" "text", "p_search_text" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."get_movement_totals_rpc"("p_filter_type" "text", "p_account_id" "text", "p_search_text" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_movement_totals_rpc"("p_filter_type" "text", "p_account_id" "text", "p_search_text" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_default_warehouse"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_default_warehouse"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_default_warehouse"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_permissions"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_permissions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_permissions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_warehouses"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_warehouses"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_warehouses"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_product_detail_bundle"("p_product_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_product_detail_bundle"("p_product_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_product_detail_bundle"("p_product_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_profiles_with_email"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_profiles_with_email"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_profiles_with_email"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_profiles_with_email"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_purchase_order_items_details"("p_order_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_purchase_order_items_details"("p_order_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_purchase_order_items_details"("p_order_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_supplier_credits_stats_rpc"("p_search_query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_supplier_credits_stats_rpc"("p_search_query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_supplier_credits_stats_rpc"("p_search_query" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_top_customers"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_top_customers"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_top_customers"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_top_customers_rpc"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_top_customers_rpc"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_top_customers_rpc"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_relations_summary"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_relations_summary"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_relations_summary"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_update_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_update_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_update_timestamp"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_catalog_batch_v2"("p_products" "jsonb", "p_warehouse_id" "uuid", "p_stock_mode" "text", "p_update_prices" boolean, "p_batch_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_catalog_batch_v2"("p_products" "jsonb", "p_warehouse_id" "uuid", "p_stock_mode" "text", "p_update_prices" boolean, "p_batch_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."import_catalog_batch_v2"("p_products" "jsonb", "p_warehouse_id" "uuid", "p_stock_mode" "text", "p_update_prices" boolean, "p_batch_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."import_norm"("t" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."import_norm"("t" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."import_norm"("t" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."process_customer_checkout"("p_customer_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb", "p_use_points" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."process_customer_checkout"("p_customer_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb", "p_use_points" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_customer_checkout"("p_customer_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb", "p_use_points" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."process_inventory_entry_rpc"("p_warehouse_id" "uuid", "p_supplier_id" "uuid", "p_purchase_order_id" "uuid", "p_payment_mode" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_document_type" "text", "p_document_number" "text", "p_document_date" "date", "p_notes" "text", "p_items" "jsonb", "p_profile_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."process_inventory_entry_rpc"("p_warehouse_id" "uuid", "p_supplier_id" "uuid", "p_purchase_order_id" "uuid", "p_payment_mode" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_document_type" "text", "p_document_number" "text", "p_document_date" "date", "p_notes" "text", "p_items" "jsonb", "p_profile_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_inventory_entry_rpc"("p_warehouse_id" "uuid", "p_supplier_id" "uuid", "p_purchase_order_id" "uuid", "p_payment_mode" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_document_type" "text", "p_document_number" "text", "p_document_date" "date", "p_notes" "text", "p_items" "jsonb", "p_profile_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."process_inventory_exit_rpc"("p_warehouse_id" "uuid", "p_reason" "text", "p_notes" "text", "p_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."process_inventory_exit_rpc"("p_warehouse_id" "uuid", "p_reason" "text", "p_notes" "text", "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_inventory_exit_rpc"("p_warehouse_id" "uuid", "p_reason" "text", "p_notes" "text", "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."process_pos_sale"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."process_pos_sale"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_pos_sale"("payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."protect_system_roles"() TO "anon";
GRANT ALL ON FUNCTION "public"."protect_system_roles"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."protect_system_roles"() TO "service_role";



GRANT ALL ON FUNCTION "public"."reconcile_balances_report"() TO "anon";
GRANT ALL ON FUNCTION "public"."reconcile_balances_report"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."reconcile_balances_report"() TO "service_role";



GRANT ALL ON FUNCTION "public"."register_credit_payment_rpc"("p_customer_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."register_credit_payment_rpc"("p_customer_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_credit_payment_rpc"("p_customer_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."register_financial_movement"("p_account_id" "uuid", "p_movement_type" "text", "p_amount" numeric, "p_description" "text", "p_reference_type" "text", "p_reference_id" "uuid", "p_created_by" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."register_financial_movement"("p_account_id" "uuid", "p_movement_type" "text", "p_amount" numeric, "p_description" "text", "p_reference_type" "text", "p_reference_id" "uuid", "p_created_by" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_financial_movement"("p_account_id" "uuid", "p_movement_type" "text", "p_amount" numeric, "p_description" "text", "p_reference_type" "text", "p_reference_id" "uuid", "p_created_by" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."register_supplier_credit_payment_rpc"("p_supplier_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid", "p_profile_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."register_supplier_credit_payment_rpc"("p_supplier_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid", "p_profile_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_supplier_credit_payment_rpc"("p_supplier_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid", "p_profile_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_adjust_financial_account_balance"("p_account_id" "uuid", "p_new_balance" numeric, "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_adjust_financial_account_balance"("p_account_id" "uuid", "p_new_balance" numeric, "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_adjust_financial_account_balance"("p_account_id" "uuid", "p_new_balance" numeric, "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_adjust_wallet"("p_user_id" "uuid", "p_amount" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_adjust_wallet"("p_user_id" "uuid", "p_amount" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_adjust_wallet"("p_user_id" "uuid", "p_amount" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_cancel_order"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_cancel_order"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_cancel_order"("payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_close_cash_shift"("p_shift_id" "uuid", "p_actual_amount" numeric, "p_closed_by" "uuid", "p_notes" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_close_cash_shift"("p_shift_id" "uuid", "p_actual_amount" numeric, "p_closed_by" "uuid", "p_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_close_cash_shift"("p_shift_id" "uuid", "p_actual_amount" numeric, "p_closed_by" "uuid", "p_notes" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_complete_order"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_complete_order"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_complete_order"("payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_convert_quotation_to_order"("p_quotation_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_convert_quotation_to_order"("p_quotation_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_convert_quotation_to_order"("p_quotation_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_create_journal_entry"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_create_journal_entry"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_create_journal_entry"("payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_create_supplier_credit"("p_supplier_id" "uuid", "p_credit_limit" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_create_supplier_credit"("p_supplier_id" "uuid", "p_credit_limit" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_create_supplier_credit"("p_supplier_id" "uuid", "p_credit_limit" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_get_shift_payment_breakdown"("p_shift_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_get_shift_payment_breakdown"("p_shift_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_get_shift_payment_breakdown"("p_shift_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_open_cash_shift"("p_account_id" "uuid", "p_opening_amount" numeric, "p_opened_by" "uuid", "p_notes" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_open_cash_shift"("p_account_id" "uuid", "p_opening_amount" numeric, "p_opened_by" "uuid", "p_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_open_cash_shift"("p_account_id" "uuid", "p_opening_amount" numeric, "p_opened_by" "uuid", "p_notes" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_post_order_to_journal"("p_order_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_post_order_to_journal"("p_order_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_post_order_to_journal"("p_order_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_process_sales_return"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_process_sales_return"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_process_sales_return"("payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_receive_inventory_only"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_receive_inventory_only"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_receive_inventory_only"("payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_receive_purchase_order_items"("p_order_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_receive_purchase_order_items"("p_order_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_receive_purchase_order_items"("p_order_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_record_expense"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_record_expense"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_record_expense"("payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_resolve_variant_price"("p_variant_id" "uuid", "p_price_list_id" "uuid", "p_unit_code" "text", "p_quantity" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_resolve_variant_price"("p_variant_id" "uuid", "p_price_list_id" "uuid", "p_unit_code" "text", "p_quantity" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_resolve_variant_price"("p_variant_id" "uuid", "p_price_list_id" "uuid", "p_unit_code" "text", "p_quantity" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_transfer_warehouse_stock"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_transfer_warehouse_stock"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_transfer_warehouse_stock"("payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_upsert_customer"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_upsert_customer"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_upsert_customer"("payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."save_customer_full_profile_rpc"("p_customer_id" "uuid", "p_full_name" "text", "p_phone" "text", "p_document_number" "text", "p_document_type" "text", "p_is_active" boolean, "p_wallet_delta" integer, "p_has_credit" boolean, "p_credit_limit" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."save_customer_full_profile_rpc"("p_customer_id" "uuid", "p_full_name" "text", "p_phone" "text", "p_document_number" "text", "p_document_type" "text", "p_is_active" boolean, "p_wallet_delta" integer, "p_has_credit" boolean, "p_credit_limit" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_customer_full_profile_rpc"("p_customer_id" "uuid", "p_full_name" "text", "p_phone" "text", "p_document_number" "text", "p_document_type" "text", "p_is_active" boolean, "p_wallet_delta" integer, "p_has_credit" boolean, "p_credit_limit" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."save_product_complete"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."save_product_complete"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_product_complete"("payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."save_variant_attributes_rpc"("p_variant_id" "uuid", "p_attribute_value_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."save_variant_attributes_rpc"("p_variant_id" "uuid", "p_attribute_value_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_variant_attributes_rpc"("p_variant_id" "uuid", "p_attribute_value_ids" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."search_ingredients_unaccent"("search_term" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."search_ingredients_unaccent"("search_term" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_ingredients_unaccent"("search_term" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_default_location"("p_profile_id" "uuid", "p_location_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_default_location"("p_profile_id" "uuid", "p_location_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_default_location"("p_profile_id" "uuid", "p_location_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "postgres";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "anon";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "service_role";



GRANT ALL ON FUNCTION "public"."show_limit"() TO "postgres";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "anon";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "service_role";



GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_cloud_cart_rpc"("p_auth_user_id" "uuid", "p_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."sync_cloud_cart_rpc"("p_auth_user_id" "uuid", "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_cloud_cart_rpc"("p_auth_user_id" "uuid", "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_purchase_order_reception_rpc"("p_purchase_order_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."sync_purchase_order_reception_rpc"("p_purchase_order_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_purchase_order_reception_rpc"("p_purchase_order_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."transfer_funds_rpc"("p_source_account_id" "uuid", "p_dest_account_id" "uuid", "p_amount" numeric, "p_description" "text", "p_created_by" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."transfer_funds_rpc"("p_source_account_id" "uuid", "p_dest_account_id" "uuid", "p_amount" numeric, "p_description" "text", "p_created_by" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_funds_rpc"("p_source_account_id" "uuid", "p_dest_account_id" "uuid", "p_amount" numeric, "p_description" "text", "p_created_by" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_audit_log"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_audit_log"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_audit_log"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_auto_create_counter_cash_account"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_auto_create_counter_cash_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_auto_create_counter_cash_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_check_journal_entry_lines_balanced"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_check_journal_entry_lines_balanced"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_check_journal_entry_lines_balanced"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_compute_base_amounts"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_compute_base_amounts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_compute_base_amounts"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_journal_balanced_and_period"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_journal_balanced_and_period"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_journal_balanced_and_period"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_sync_customer_record_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_sync_customer_record_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_sync_customer_record_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_sync_warehouse_status_to_cash_account"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_sync_warehouse_status_to_cash_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_sync_warehouse_status_to_cash_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_sync_warehouse_variant_qty"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_sync_warehouse_variant_qty"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_sync_warehouse_variant_qty"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_track_order_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_track_order_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_track_order_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_po_payment_method_rpc"("p_order_id" "uuid", "p_supplier_id" "uuid", "p_new_method" "text", "p_old_method" "text", "p_order_amount" numeric, "p_profile_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."update_po_payment_method_rpc"("p_order_id" "uuid", "p_supplier_id" "uuid", "p_new_method" "text", "p_old_method" "text", "p_order_amount" numeric, "p_profile_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_po_payment_method_rpc"("p_order_id" "uuid", "p_supplier_id" "uuid", "p_new_method" "text", "p_old_method" "text", "p_order_amount" numeric, "p_profile_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."user_has_permission"("p_permission_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."user_has_permission"("p_permission_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_has_permission"("p_permission_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "service_role";
























GRANT ALL ON TABLE "public"."account_movements" TO "anon";
GRANT ALL ON TABLE "public"."account_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."account_movements" TO "service_role";



GRANT ALL ON TABLE "public"."accounting_periods" TO "anon";
GRANT ALL ON TABLE "public"."accounting_periods" TO "authenticated";
GRANT ALL ON TABLE "public"."accounting_periods" TO "service_role";



GRANT ALL ON TABLE "public"."accounting_posting_rule_lines" TO "anon";
GRANT ALL ON TABLE "public"."accounting_posting_rule_lines" TO "authenticated";
GRANT ALL ON TABLE "public"."accounting_posting_rule_lines" TO "service_role";



GRANT ALL ON TABLE "public"."accounting_posting_rules" TO "anon";
GRANT ALL ON TABLE "public"."accounting_posting_rules" TO "authenticated";
GRANT ALL ON TABLE "public"."accounting_posting_rules" TO "service_role";



GRANT ALL ON TABLE "public"."active_ingredients" TO "anon";
GRANT ALL ON TABLE "public"."active_ingredients" TO "authenticated";
GRANT ALL ON TABLE "public"."active_ingredients" TO "service_role";



GRANT ALL ON TABLE "public"."app_settings" TO "anon";
GRANT ALL ON TABLE "public"."app_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."app_settings" TO "service_role";



GRANT ALL ON TABLE "public"."attribute_values" TO "anon";
GRANT ALL ON TABLE "public"."attribute_values" TO "authenticated";
GRANT ALL ON TABLE "public"."attribute_values" TO "service_role";



GRANT ALL ON TABLE "public"."attributes" TO "anon";
GRANT ALL ON TABLE "public"."attributes" TO "authenticated";
GRANT ALL ON TABLE "public"."attributes" TO "service_role";



GRANT ALL ON TABLE "public"."audit_logs" TO "anon";
GRANT ALL ON TABLE "public"."audit_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."audit_logs" TO "service_role";



GRANT ALL ON TABLE "public"."brands" TO "anon";
GRANT ALL ON TABLE "public"."brands" TO "authenticated";
GRANT ALL ON TABLE "public"."brands" TO "service_role";



GRANT ALL ON TABLE "public"."business_info" TO "anon";
GRANT ALL ON TABLE "public"."business_info" TO "authenticated";
GRANT ALL ON TABLE "public"."business_info" TO "service_role";



GRANT ALL ON TABLE "public"."cart_items" TO "anon";
GRANT ALL ON TABLE "public"."cart_items" TO "authenticated";
GRANT ALL ON TABLE "public"."cart_items" TO "service_role";



GRANT ALL ON TABLE "public"."cash_shifts" TO "anon";
GRANT ALL ON TABLE "public"."cash_shifts" TO "authenticated";
GRANT ALL ON TABLE "public"."cash_shifts" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."chart_of_accounts" TO "anon";
GRANT ALL ON TABLE "public"."chart_of_accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."chart_of_accounts" TO "service_role";



GRANT ALL ON TABLE "public"."currencies" TO "anon";
GRANT ALL ON TABLE "public"."currencies" TO "authenticated";
GRANT ALL ON TABLE "public"."currencies" TO "service_role";



GRANT ALL ON TABLE "public"."customer_credit_movements" TO "anon";
GRANT ALL ON TABLE "public"."customer_credit_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_credit_movements" TO "service_role";



GRANT ALL ON TABLE "public"."orders" TO "anon";
GRANT ALL ON TABLE "public"."orders" TO "authenticated";
GRANT ALL ON TABLE "public"."orders" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."customer_credit_movements_summary" TO "anon";
GRANT ALL ON TABLE "public"."customer_credit_movements_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_credit_movements_summary" TO "service_role";



GRANT ALL ON TABLE "public"."customer_credits" TO "anon";
GRANT ALL ON TABLE "public"."customer_credits" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_credits" TO "service_role";



GRANT ALL ON TABLE "public"."customer_locations" TO "anon";
GRANT ALL ON TABLE "public"."customer_locations" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_locations" TO "service_role";



GRANT ALL ON TABLE "public"."customers" TO "anon";
GRANT ALL ON TABLE "public"."customers" TO "authenticated";
GRANT ALL ON TABLE "public"."customers" TO "service_role";



GRANT ALL ON TABLE "public"."daily_checkins" TO "anon";
GRANT ALL ON TABLE "public"."daily_checkins" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_checkins" TO "service_role";



GRANT ALL ON TABLE "public"."dispatch_guide_items" TO "anon";
GRANT ALL ON TABLE "public"."dispatch_guide_items" TO "authenticated";
GRANT ALL ON TABLE "public"."dispatch_guide_items" TO "service_role";



GRANT ALL ON TABLE "public"."dispatch_guides" TO "anon";
GRANT ALL ON TABLE "public"."dispatch_guides" TO "authenticated";
GRANT ALL ON TABLE "public"."dispatch_guides" TO "service_role";



GRANT ALL ON TABLE "public"."document_series" TO "anon";
GRANT ALL ON TABLE "public"."document_series" TO "authenticated";
GRANT ALL ON TABLE "public"."document_series" TO "service_role";



GRANT ALL ON TABLE "public"."electronic_documents" TO "anon";
GRANT ALL ON TABLE "public"."electronic_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."electronic_documents" TO "service_role";



GRANT ALL ON TABLE "public"."exchange_rates" TO "anon";
GRANT ALL ON TABLE "public"."exchange_rates" TO "authenticated";
GRANT ALL ON TABLE "public"."exchange_rates" TO "service_role";



GRANT ALL ON TABLE "public"."expense_categories" TO "anon";
GRANT ALL ON TABLE "public"."expense_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."expense_categories" TO "service_role";



GRANT ALL ON TABLE "public"."expenses" TO "anon";
GRANT ALL ON TABLE "public"."expenses" TO "authenticated";
GRANT ALL ON TABLE "public"."expenses" TO "service_role";



GRANT ALL ON TABLE "public"."financial_accounts" TO "anon";
GRANT ALL ON TABLE "public"."financial_accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."financial_accounts" TO "service_role";



GRANT ALL ON TABLE "public"."import_batches" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_entries" TO "anon";
GRANT ALL ON TABLE "public"."inventory_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_entries" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_entry_items" TO "anon";
GRANT ALL ON TABLE "public"."inventory_entry_items" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_entry_items" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_exit_items" TO "anon";
GRANT ALL ON TABLE "public"."inventory_exit_items" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_exit_items" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_exits" TO "anon";
GRANT ALL ON TABLE "public"."inventory_exits" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_exits" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_movements" TO "anon";
GRANT ALL ON TABLE "public"."inventory_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_movements" TO "service_role";



GRANT ALL ON TABLE "public"."journal_entries" TO "anon";
GRANT ALL ON TABLE "public"."journal_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."journal_entries" TO "service_role";



GRANT ALL ON TABLE "public"."journal_entry_lines" TO "anon";
GRANT ALL ON TABLE "public"."journal_entry_lines" TO "authenticated";
GRANT ALL ON TABLE "public"."journal_entry_lines" TO "service_role";



GRANT ALL ON TABLE "public"."order_installments" TO "anon";
GRANT ALL ON TABLE "public"."order_installments" TO "authenticated";
GRANT ALL ON TABLE "public"."order_installments" TO "service_role";



GRANT ALL ON TABLE "public"."order_items" TO "anon";
GRANT ALL ON TABLE "public"."order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."order_items" TO "service_role";



GRANT ALL ON TABLE "public"."order_payments" TO "anon";
GRANT ALL ON TABLE "public"."order_payments" TO "authenticated";
GRANT ALL ON TABLE "public"."order_payments" TO "service_role";



GRANT ALL ON TABLE "public"."order_status_history" TO "anon";
GRANT ALL ON TABLE "public"."order_status_history" TO "authenticated";
GRANT ALL ON TABLE "public"."order_status_history" TO "service_role";



GRANT ALL ON TABLE "public"."partner_credit_summary" TO "anon";
GRANT ALL ON TABLE "public"."partner_credit_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."partner_credit_summary" TO "service_role";



GRANT ALL ON TABLE "public"."payment_methods" TO "anon";
GRANT ALL ON TABLE "public"."payment_methods" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_methods" TO "service_role";



GRANT ALL ON TABLE "public"."permissions" TO "anon";
GRANT ALL ON TABLE "public"."permissions" TO "authenticated";
GRANT ALL ON TABLE "public"."permissions" TO "service_role";



GRANT ALL ON TABLE "public"."physical_inventories" TO "anon";
GRANT ALL ON TABLE "public"."physical_inventories" TO "authenticated";
GRANT ALL ON TABLE "public"."physical_inventories" TO "service_role";



GRANT ALL ON TABLE "public"."physical_inventory_items" TO "anon";
GRANT ALL ON TABLE "public"."physical_inventory_items" TO "authenticated";
GRANT ALL ON TABLE "public"."physical_inventory_items" TO "service_role";



GRANT ALL ON TABLE "public"."price_list_items" TO "anon";
GRANT ALL ON TABLE "public"."price_list_items" TO "authenticated";
GRANT ALL ON TABLE "public"."price_list_items" TO "service_role";



GRANT ALL ON TABLE "public"."price_lists" TO "anon";
GRANT ALL ON TABLE "public"."price_lists" TO "authenticated";
GRANT ALL ON TABLE "public"."price_lists" TO "service_role";



GRANT ALL ON TABLE "public"."product_active_ingredients" TO "anon";
GRANT ALL ON TABLE "public"."product_active_ingredients" TO "authenticated";
GRANT ALL ON TABLE "public"."product_active_ingredients" TO "service_role";



GRANT ALL ON TABLE "public"."product_images" TO "anon";
GRANT ALL ON TABLE "public"."product_images" TO "authenticated";
GRANT ALL ON TABLE "public"."product_images" TO "service_role";



GRANT ALL ON TABLE "public"."product_reviews" TO "anon";
GRANT ALL ON TABLE "public"."product_reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."product_reviews" TO "service_role";



GRANT ALL ON TABLE "public"."product_variants" TO "anon";
GRANT ALL ON TABLE "public"."product_variants" TO "authenticated";
GRANT ALL ON TABLE "public"."product_variants" TO "service_role";



GRANT ALL ON TABLE "public"."warehouse_stock_batches" TO "anon";
GRANT ALL ON TABLE "public"."warehouse_stock_batches" TO "authenticated";
GRANT ALL ON TABLE "public"."warehouse_stock_batches" TO "service_role";



GRANT ALL ON TABLE "public"."product_stock_summary" TO "anon";
GRANT ALL ON TABLE "public"."product_stock_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."product_stock_summary" TO "service_role";



GRANT ALL ON TABLE "public"."product_unit_conversions" TO "anon";
GRANT ALL ON TABLE "public"."product_unit_conversions" TO "authenticated";
GRANT ALL ON TABLE "public"."product_unit_conversions" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."purchase_invoice_items" TO "anon";
GRANT ALL ON TABLE "public"."purchase_invoice_items" TO "authenticated";
GRANT ALL ON TABLE "public"."purchase_invoice_items" TO "service_role";



GRANT ALL ON TABLE "public"."purchase_invoice_payments" TO "anon";
GRANT ALL ON TABLE "public"."purchase_invoice_payments" TO "authenticated";
GRANT ALL ON TABLE "public"."purchase_invoice_payments" TO "service_role";



GRANT ALL ON TABLE "public"."purchase_invoices" TO "anon";
GRANT ALL ON TABLE "public"."purchase_invoices" TO "authenticated";
GRANT ALL ON TABLE "public"."purchase_invoices" TO "service_role";



GRANT ALL ON TABLE "public"."purchase_order_items" TO "anon";
GRANT ALL ON TABLE "public"."purchase_order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."purchase_order_items" TO "service_role";



GRANT ALL ON TABLE "public"."purchase_orders" TO "anon";
GRANT ALL ON TABLE "public"."purchase_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."purchase_orders" TO "service_role";



GRANT ALL ON TABLE "public"."quotation_items" TO "anon";
GRANT ALL ON TABLE "public"."quotation_items" TO "authenticated";
GRANT ALL ON TABLE "public"."quotation_items" TO "service_role";



GRANT ALL ON TABLE "public"."quotations" TO "anon";
GRANT ALL ON TABLE "public"."quotations" TO "authenticated";
GRANT ALL ON TABLE "public"."quotations" TO "service_role";



GRANT ALL ON TABLE "public"."raffle_tickets" TO "anon";
GRANT ALL ON TABLE "public"."raffle_tickets" TO "authenticated";
GRANT ALL ON TABLE "public"."raffle_tickets" TO "service_role";



GRANT ALL ON TABLE "public"."raffles" TO "anon";
GRANT ALL ON TABLE "public"."raffles" TO "authenticated";
GRANT ALL ON TABLE "public"."raffles" TO "service_role";



GRANT ALL ON TABLE "public"."role_permissions" TO "anon";
GRANT ALL ON TABLE "public"."role_permissions" TO "authenticated";
GRANT ALL ON TABLE "public"."role_permissions" TO "service_role";



GRANT ALL ON TABLE "public"."roles" TO "anon";
GRANT ALL ON TABLE "public"."roles" TO "authenticated";
GRANT ALL ON TABLE "public"."roles" TO "service_role";



GRANT ALL ON TABLE "public"."sales_return_items" TO "anon";
GRANT ALL ON TABLE "public"."sales_return_items" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_return_items" TO "service_role";



GRANT ALL ON TABLE "public"."sales_returns" TO "anon";
GRANT ALL ON TABLE "public"."sales_returns" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_returns" TO "service_role";



GRANT ALL ON TABLE "public"."shopping_carts" TO "anon";
GRANT ALL ON TABLE "public"."shopping_carts" TO "authenticated";
GRANT ALL ON TABLE "public"."shopping_carts" TO "service_role";



GRANT ALL ON TABLE "public"."sunat_daily_summaries" TO "anon";
GRANT ALL ON TABLE "public"."sunat_daily_summaries" TO "authenticated";
GRANT ALL ON TABLE "public"."sunat_daily_summaries" TO "service_role";



GRANT ALL ON TABLE "public"."sunat_daily_summary_items" TO "anon";
GRANT ALL ON TABLE "public"."sunat_daily_summary_items" TO "authenticated";
GRANT ALL ON TABLE "public"."sunat_daily_summary_items" TO "service_role";



GRANT ALL ON TABLE "public"."supplier_credit_movements" TO "anon";
GRANT ALL ON TABLE "public"."supplier_credit_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."supplier_credit_movements" TO "service_role";



GRANT ALL ON TABLE "public"."supplier_credits" TO "anon";
GRANT ALL ON TABLE "public"."supplier_credits" TO "authenticated";
GRANT ALL ON TABLE "public"."supplier_credits" TO "service_role";



GRANT ALL ON TABLE "public"."suppliers" TO "anon";
GRANT ALL ON TABLE "public"."suppliers" TO "authenticated";
GRANT ALL ON TABLE "public"."suppliers" TO "service_role";



GRANT ALL ON TABLE "public"."units_of_measure" TO "anon";
GRANT ALL ON TABLE "public"."units_of_measure" TO "authenticated";
GRANT ALL ON TABLE "public"."units_of_measure" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."user_effective_permissions" TO "anon";
GRANT ALL ON TABLE "public"."user_effective_permissions" TO "authenticated";
GRANT ALL ON TABLE "public"."user_effective_permissions" TO "service_role";



GRANT ALL ON TABLE "public"."user_warehouses" TO "anon";
GRANT ALL ON TABLE "public"."user_warehouses" TO "authenticated";
GRANT ALL ON TABLE "public"."user_warehouses" TO "service_role";



GRANT ALL ON TABLE "public"."variant_attribute_values" TO "anon";
GRANT ALL ON TABLE "public"."variant_attribute_values" TO "authenticated";
GRANT ALL ON TABLE "public"."variant_attribute_values" TO "service_role";



GRANT ALL ON TABLE "public"."wallet_movements" TO "anon";
GRANT ALL ON TABLE "public"."wallet_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."wallet_movements" TO "service_role";



GRANT ALL ON TABLE "public"."warehouse_transfer_items" TO "anon";
GRANT ALL ON TABLE "public"."warehouse_transfer_items" TO "authenticated";
GRANT ALL ON TABLE "public"."warehouse_transfer_items" TO "service_role";



GRANT ALL ON TABLE "public"."warehouse_transfers" TO "anon";
GRANT ALL ON TABLE "public"."warehouse_transfers" TO "authenticated";
GRANT ALL ON TABLE "public"."warehouse_transfers" TO "service_role";



GRANT ALL ON TABLE "public"."warehouse_variant_costs" TO "anon";
GRANT ALL ON TABLE "public"."warehouse_variant_costs" TO "authenticated";
GRANT ALL ON TABLE "public"."warehouse_variant_costs" TO "service_role";



GRANT ALL ON TABLE "public"."warehouses" TO "anon";
GRANT ALL ON TABLE "public"."warehouses" TO "authenticated";
GRANT ALL ON TABLE "public"."warehouses" TO "service_role";



GRANT ALL ON TABLE "public"."wishlist" TO "anon";
GRANT ALL ON TABLE "public"."wishlist" TO "authenticated";
GRANT ALL ON TABLE "public"."wishlist" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































