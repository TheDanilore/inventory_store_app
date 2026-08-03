


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






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "unaccent" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."user_role" AS ENUM (
    'customer',
    'admin',
    'employee'
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
                RETURN jsonb_build_object('success', false, 'error', 'Límite de crédito excedido. Disponible: S/ ' || ROUND((v_credit_limit - v_real_debt), 2) || ', Monto de la orden: S/ ' || ROUND(p_total_amount, 2));
            END IF;
        END IF;
    END IF;

    -- 2. Validar saldo suficiente y turno de caja abierto (PAID)
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
            RETURN jsonb_build_object('success', false, 'error', 'Saldo insuficiente en la cuenta "' || v_acc_name || '". Saldo disponible: S/ ' || ROUND(v_acc_balance, 2) || ', Monto a pagar: S/ ' || ROUND(p_total_amount, 2));
        END IF;

        IF v_acc_type = 'CAJA' THEN
            -- Autodetectar turno de caja abierto si no viene provisto
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
        amount_paid -- Pre-llenar si es pagado al instante
    ) VALUES (
        p_supplier_id, p_supplier_name, p_warehouse_id, p_total_amount, 
        p_payment_method, p_payment_status, p_due_date, p_document_date, 
        p_document_type, p_document_number, p_notes, p_profile_id, 'PENDING',
        CASE WHEN p_payment_status = 'PAID' THEN p_total_amount ELSE 0 END
    ) RETURNING id INTO v_po_id;

    -- 4. Inserción de los Ítems
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO public.purchase_order_items (
            purchase_order_id, product_id, variant_id, quantity_ordered, 
            unit_cost, subtotal, batch_number, expiry_date
        ) VALUES (
            v_po_id, 
            (v_item->>'product_id')::UUID, 
            (v_item->>'variant_id')::UUID, 
            (v_item->>'quantity')::NUMERIC, 
            (v_item->>'unit_cost')::NUMERIC, 
            ((v_item->>'quantity')::NUMERIC * (v_item->>'unit_cost')::NUMERIC),
            v_item->>'batch_number', 
            CASE WHEN (v_item->>'expiry_date') IS NOT NULL 
                 THEN (v_item->>'expiry_date')::DATE 
                 ELSE NULL END
        );
    END LOOP;

    -- 5. Operaciones Financieras / Movimientos
    IF p_payment_status = 'PAID' THEN
        -- Descontar saldo de la cuenta
        UPDATE public.financial_accounts
        SET balance = balance - p_total_amount,
            updated_at = NOW()
        WHERE id = p_account_id;

        -- Registrar movimiento (ajustar tabla si el esquema de movimientos se llama diferente)
        -- EJ: financial_movements o cash_movements
        INSERT INTO public.cash_movements (
            account_id, shift_id, type, amount, description, reference_type, reference_id, created_by
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

        -- Registrar cargo
        INSERT INTO public.supplier_credit_movements (
            supplier_credit_id, movement_type, amount, purchase_order_id, notes, created_by
        ) VALUES (
            v_credit_id, 'CHARGE', p_total_amount, v_po_id, 
            'Orden de Compra #' || left(v_po_id::text, 8), p_profile_id
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'purchase_order_id', v_po_id);

EXCEPTION WHEN OTHERS THEN
    -- Ante cualquier error de restricción, stock, nulos, etc, se lanza excepción y PostgreSQL hace ROLLBACK
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;


ALTER FUNCTION "public"."create_purchase_order_rpc"("p_supplier_id" "uuid", "p_supplier_name" "text", "p_warehouse_id" "uuid", "p_total_amount" numeric, "p_payment_method" "text", "p_payment_status" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_due_date" "date", "p_document_date" "date", "p_document_type" "text", "p_document_number" "text", "p_notes" "text", "p_profile_id" "uuid", "p_items" "jsonb") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."handle_update_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_update_timestamp"() OWNER TO "postgres";


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

    SELECT unit_price, wholesale_price, unit_cost INTO v_variant_record
    FROM product_variants
    WHERE id = v_item.variant_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variante no encontrada: %', v_item.variant_id;
    END IF;

    v_item_price := v_variant_record.unit_price;
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
    SELECT unit_price, wholesale_price, unit_cost INTO v_variant_record
    FROM product_variants
    WHERE id = v_item.variant_id;

    v_item_price := v_variant_record.unit_price;
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


CREATE OR REPLACE FUNCTION "public"."process_inventory_entry_rpc"("p_warehouse_id" "uuid", "p_supplier_id" "uuid", "p_purchase_order_id" "uuid", "p_payment_mode" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_document_type" "text", "p_document_number" "text", "p_document_date" "date", "p_notes" "text", "p_items" "jsonb") RETURNS "uuid"
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
BEGIN
  -- Obtener el ID del usuario actual (si se llama desde cliente autenticado)
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
     -- Para uso en backend o testing si auth.uid() falla
     -- v_user_id := ... (Opcional)
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

      -- SELECT FOR UPDATE previene condiciones de carrera
      SELECT type, balance INTO v_account_type, v_current_balance
      FROM public.financial_accounts
      WHERE id = p_account_id
      FOR UPDATE;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'La cuenta financiera no existe.';
      END IF;

      -- Verificar saldo suficiente
      IF v_current_balance < v_total_amount THEN
        RAISE EXCEPTION 'Saldo insuficiente en la cuenta financiera.';
      END IF;

      -- VALIDACIÓN ATÓMICA DE TURNO (ignora el parámetro de cliente)
      IF v_account_type = 'CAJA' THEN
        SELECT id INTO p_active_shift_id
        FROM cash_shifts
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

      -- Obtener nombre de proveedor para glosa
      v_supplier_name := '';
      IF p_supplier_id IS NOT NULL THEN
         SELECT name INTO v_supplier_name FROM public.suppliers WHERE id = p_supplier_id;
      END IF;

      -- Registrar movimiento bancario/caja
      INSERT INTO public.account_movements (
        account_id, shift_id, movement_type, amount, description, reference_type, reference_id, created_by
      ) VALUES (
        p_account_id, p_active_shift_id, 'EXPENSE', v_total_amount, 
        'Compra de inventario' || CASE WHEN v_supplier_name != '' THEN ' · ' || v_supplier_name ELSE '' END,
        'inventory_entry', NULL, v_user_id
      ) RETURNING id INTO item; -- Reusamos item solo temporalmente si se requiere;

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
        -- Crear nuevo crédito si no existe
        INSERT INTO public.supplier_credits (supplier_id, current_debt, created_by)
        VALUES (p_supplier_id, v_total_amount, v_user_id)
        RETURNING id INTO v_supplier_credit_id;
      ELSE
        -- Actualizar deuda existente
        UPDATE public.supplier_credits
        SET current_debt = current_debt + v_total_amount,
            updated_at = NOW()
        WHERE id = v_supplier_credit_id;
      END IF;

      -- El supplier_credit_movement se insertará después de crear la entrada para enlazarlo a la nota.
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

  -- Actualizar el account_movement con el reference_id de la entrada
  IF p_purchase_order_id IS NULL AND p_payment_mode = 'CONTADO' THEN
      UPDATE public.account_movements 
      SET reference_id = v_entry_id 
      WHERE reference_type = 'inventory_entry' AND reference_id IS NULL AND created_by = v_user_id
      -- Nota: Para mejor precisión, podríamos haber insertado el movimiento DESPUÉS de la entrada.
      -- Esto asume una transacción rápida.
      ;
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
    -- El RPC de recepción ya hace todo internamente!
    PERFORM public.sync_purchase_order_reception_rpc(p_purchase_order_id);
  END IF;

  RETURN v_entry_id;
END;
$$;


ALTER FUNCTION "public"."process_inventory_entry_rpc"("p_warehouse_id" "uuid", "p_supplier_id" "uuid", "p_purchase_order_id" "uuid", "p_payment_mode" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_document_type" "text", "p_document_number" "text", "p_document_date" "date", "p_notes" "text", "p_items" "jsonb") OWNER TO "postgres";


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
  v_credit_active boolean;
  v_credit_disponible numeric;
BEGIN
  -- 1. BLINDAJE DE SEGURIDAD: Resolver creador únicamente vía JWT de Supabase Auth
  SELECT id INTO v_created_by FROM profiles WHERE auth_user_id = v_auth_user_id LIMIT 1;
  IF v_created_by IS NULL THEN
    RAISE EXCEPTION 'Usuario autenticado no posee un perfil válido en el sistema.';
  END IF;

  -- Handle optional UUIDs
  IF payload->>'customerId' IS NOT NULL AND payload->>'customerId' != '' THEN v_customer_id := (payload->>'customerId')::uuid; END IF;
  IF payload->>'accountId' IS NOT NULL AND payload->>'accountId' != '' THEN v_account_id := (payload->>'accountId')::uuid; END IF;
  
  -- YA NO TOMAMOS EL activeShiftId DESDE EL PAYLOAD POR SEGURIDAD. EL BACKEND LO DETERMINARÁ.

  -- VALIDACIÓN ATÓMICA DE CRÉDITO ANTES DE COMPROMETER STOCK O CREAR ÓRDENES
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

    v_credit_disponible := v_credit_limit - v_current_debt;
    IF v_credit_disponible < (v_total_amount - v_amount_paid) THEN
      RAISE EXCEPTION 'Crédito insuficiente para esta venta. Disponible: %, Requerido: %', 
        v_credit_disponible, (v_total_amount - v_amount_paid)
        USING ERRCODE = 'P0012';
    END IF;
  END IF;

  v_order_status := CASE WHEN v_is_draft THEN 'PENDING' ELSE 'COMPLETED' END;

  -- Insertar orden principal
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
    
    -- Validado con esquema de tabla order_items
    INSERT INTO order_items (
      order_id, product_id, variant_id, quantity, unit_cost, applied_price, net_profit
    ) VALUES (
      v_order_id, (item->>'productId')::uuid, v_variant_id, v_quantity,
      (item->>'unitCost')::numeric, (item->>'appliedPrice')::numeric, (item->>'netProfit')::numeric
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
          
          -- Validado con esquema de tabla inventory_movements (con order_id)
          INSERT INTO inventory_movements (
            variant_id, warehouse_id, stock_batch_id, order_id, quantity, previous_stock, new_stock, unit_cost, reason, notes, created_by
          ) VALUES (
            v_variant_id, v_warehouse_id, (batch_assign->>'batchId')::uuid, v_order_id, -v_take, v_old_qty, v_old_qty - v_take, (item->>'unitCost')::numeric, 'SALE', 
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
            v_variant_id, v_warehouse_id, batch_row.id, v_order_id, -v_take, batch_row.available_quantity, batch_row.available_quantity - v_take, (item->>'unitCost')::numeric, 'SALE', 
            'Venta POS - ' || COALESCE(payload->>'paymentMethod', 'N/A') || ' • Lote: ' || batch_row.batch_number, v_created_by
          );
          
          v_remaining_qty := v_remaining_qty - v_take;
        END LOOP;
        
        IF v_remaining_qty > 0 THEN
          RAISE EXCEPTION 'Stock insuficiente global en almacén para el ítem variante %', v_variant_id;
        END IF;
      END IF;
    END IF;
  END LOOP;

  -- 3. FLUJOS FINANCIEROS Y DE FIDELIZACIÓN COMPLEMENTARIOS
  IF NOT v_is_draft THEN
    
    -- Control de Cajas y Cuentas Financieras
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

        -- Validación ATÓMICA del Turno de Caja (ignora lo que envía el cliente)
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

        -- Insertar el movimiento financiero
        INSERT INTO account_movements (
          account_id, shift_id, movement_type, amount, description, reference_id, reference_type, created_by
        ) VALUES (
          v_account_id, v_shift_id, 'INCOME', v_amount_paid, 'Venta POS #' || substring(v_order_id::text, 1, 8), v_order_id, 'ORDER', v_created_by
        );
        
        UPDATE financial_accounts
        SET balance = balance + v_amount_paid
        WHERE id = v_account_id;
      END;
    END IF;

    -- Actualización Segura de Wallet de Puntos del Cliente
    IF (v_points_earned > 0 OR v_points_used > 0) AND v_customer_id IS NOT NULL THEN
      UPDATE profiles
      SET wallet_balance = wallet_balance + v_points_earned - v_points_used
      WHERE id = v_customer_id;
      
      -- Registrar EARNED y REDEEMED por separado para correcta auditoría y reversión
      IF v_points_earned > 0 THEN
        INSERT INTO wallet_movements (profile_id, order_id, points, movement_type, description)
        VALUES (v_customer_id, v_order_id, v_points_earned, 'EARNED', 'Puntos ganados por Venta #' || substring(v_order_id::text, 1, 8));
      END IF;

      IF v_points_used > 0 THEN
        INSERT INTO wallet_movements (profile_id, order_id, points, movement_type, description)
        VALUES (v_customer_id, v_order_id, v_points_used, 'REDEEMED', 'Puntos canjeados en Venta #' || substring(v_order_id::text, 1, 8));
      END IF;
    END IF;

    -- Flujo de Crédito a Clientes (ya validado y bloqueado atómicamente al inicio del RPC)
    IF v_is_credit AND v_customer_id IS NOT NULL THEN
      UPDATE customer_credits
      SET current_debt = current_debt + (v_total_amount - v_amount_paid)
      WHERE id = v_credit_id;
      
      INSERT INTO credit_movements (
        credit_id, movement_type, amount, description, reference_id, reference_type, created_by
      ) VALUES (
        v_credit_id, 'DEBT', (v_total_amount - v_amount_paid), 'Venta al crédito - POS #' || substring(v_order_id::text, 1, 8), v_order_id, 'ORDER', v_created_by
      );
    END IF;

  END IF;

  RETURN v_order_id;
END;
$$;


ALTER FUNCTION "public"."process_pos_sale"("payload" "jsonb") OWNER TO "postgres";


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
BEGIN
    v_now := NOW() AT TIME ZONE 'America/Lima';

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser mayor a 0.';
    END IF;

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
         FOR UPDATE -- <== BLOQUEO TRANSACCIONAL PARA CONCURRENCIA
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
                created_at
            ) VALUES (
                p_credit_id,
                v_order.id,
                'PAYMENT',
                v_to_apply,
                v_account.name,
                p_notes,
                v_now
            );
        END IF;

        -- Movimiento de caja/banco
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
                auth.uid(),
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
             FOR UPDATE; -- <== BLOQUEO DE BILLETERA
             
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

    -- 3. BLINDAJE DE DEUDA TOTAL (CUSTOMER CREDITS)
    IF p_credit_id IS NOT NULL THEN
        SELECT current_debt
          INTO v_current_debt
          FROM public.customer_credits
         WHERE id = p_credit_id
         FOR UPDATE; -- <== BLOQUEO TRANSACCIONAL PARA CONCURRENCIA DE DEUDA

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
                -- Revert deduction
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
BEGIN
    -- 1. Extract payload fields
    v_order_id := (payload->>'order_id')::uuid;
    v_payment_method := payload->>'payment_method';
    v_customer_id := (payload->>'selected_customer_id')::uuid;
    v_customer_name := payload->>'customer_name_to_save';
    v_points_used := COALESCE((payload->>'points_used')::integer, 0);
    v_points_earned := COALESCE((payload->>'points_earned')::integer, 0);
    v_total_amount := COALESCE((payload->>'total_amount')::numeric, 0);
    v_total_profit := COALESCE((payload->>'total_profit')::numeric, 0);
    v_current_profile_id := (payload->>'current_profile_id')::uuid;
    v_items := payload->'items';
    v_overrides := payload->'batch_overrides';

    -- Fetch warehouse_id from order
    SELECT warehouse_id INTO v_warehouse_id FROM orders WHERE id = v_order_id;
    IF v_warehouse_id IS NULL THEN
        RAISE EXCEPTION 'El pedido no tiene almacén asignado.';
    END IF;

    -- OPTIMIZACIÓN DE DATA EGRESS: Si no vienen ítems del UI, tomarlos de la BD.
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
        
        -- Si no vienen del UI, también recalcular montos (seguridad anti-tampering)
        SELECT total_amount INTO v_total_amount FROM orders WHERE id = v_order_id;
    END IF;

    -- 2. Validate Payment Method for Completion
    IF v_payment_method = 'POR ACORDAR' OR TRIM(v_payment_method) = '' THEN
        RAISE EXCEPTION '__PAYMENT_METHOD_REQUIRED__';
    END IF;

    -- 3. Validate Credit (If Credit Payment)
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

        IF (v_credit_limit - v_current_debt) < v_total_amount THEN
            RAISE EXCEPTION 'Crédito insuficiente. Disponible: S/ %', (v_credit_limit - v_current_debt);
        END IF;
    END IF;

    -- 4. Process Inventory Items & Stock Deduction
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
    LOOP
        v_qty_needed := (v_item->>'quantity')::integer;
        v_remaining := v_qty_needed;
        
        -- Check if we have overrides for this item id
        IF v_overrides IS NOT NULL AND v_overrides ? (v_item->>'id') THEN
            FOR v_override IN SELECT * FROM jsonb_array_elements(v_overrides->(v_item->>'id'))
            LOOP
                v_take := (v_override->>'assigned')::integer;
                v_batch_id := (v_override->>'batch_id')::uuid;
                
                IF v_take > 0 THEN
                    -- Deduct from specific batch
                    UPDATE warehouse_stock_batches
                    SET available_quantity = available_quantity - v_take
                    WHERE id = v_batch_id AND available_quantity >= v_take
                    RETURNING available_quantity INTO v_take; -- dummy check
                    
                    IF NOT FOUND THEN
                        RAISE EXCEPTION 'Stock insuficiente en el lote asignado (override).';
                    END IF;

                    INSERT INTO inventory_movements 
                        (variant_id, warehouse_id, stock_batch_id, order_id, quantity, unit_cost, reason, notes, created_by)
                    VALUES 
                        ((v_item->>'variant_id')::uuid, v_warehouse_id, v_batch_id, v_order_id, -v_take, (v_item->>'unit_cost')::numeric, 'SALE', 'Pedido completado desde detalles', v_current_profile_id);
                        
                    v_remaining := v_remaining - (v_override->>'assigned')::integer;
                END IF;
            END LOOP;
            
            IF v_remaining != 0 THEN
                RAISE EXCEPTION 'Asignación de lotes inválida para producto.';
            END IF;
        ELSE
            -- FEFO Automatic Allocation
            FOR v_batch IN 
                SELECT id, available_quantity, batch_number
                FROM warehouse_stock_batches
                WHERE warehouse_id = v_warehouse_id 
                  AND variant_id = (v_item->>'variant_id')::uuid 
                  AND available_quantity > 0
                ORDER BY expiry_date ASC NULLS LAST
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

                INSERT INTO inventory_movements 
                    (variant_id, warehouse_id, stock_batch_id, order_id, quantity, unit_cost, reason, notes, created_by)
                VALUES 
                    ((v_item->>'variant_id')::uuid, v_warehouse_id, v_batch.id, v_order_id, -v_take, (v_item->>'unit_cost')::numeric, 'SALE', 'Pedido completado (FEFO) · Lote: ' || v_batch.batch_number, v_current_profile_id);

                v_remaining := v_remaining - v_take;
            END LOOP;
            
            IF v_remaining > 0 THEN
                RAISE EXCEPTION 'Stock insuficiente para aplicar FEFO automático.';
            END IF;
        END IF;
        
        -- Update the individual order item ONLY if applied_price is provided (came from UI Edit)
        IF v_item ? 'applied_price' THEN
            UPDATE order_items
            SET quantity = (v_item->>'quantity')::integer,
                unit_cost = (v_item->>'unit_cost')::numeric,
                net_profit = ((v_item->>'applied_price')::numeric - (v_item->>'unit_cost')::numeric) * (v_item->>'quantity')::integer
            WHERE id = (v_item->>'id')::uuid;
        END IF;

    END LOOP;

    -- 5. Register Payment or Debt
    IF v_payment_method = 'CRÉDITO' THEN
        -- Add Debt
        v_new_debt := v_current_debt + v_total_amount;
        
        UPDATE customer_credits 
        SET current_debt = v_new_debt, updated_at = NOW()
        WHERE id = v_credit_id;
        
        INSERT INTO customer_credit_movements 
            (customer_credit_id, order_id, movement_type, amount, notes, created_by)
        VALUES 
            (v_credit_id, v_order_id, 'CHARGE', v_total_amount, 'Activación de pedido completado', v_current_profile_id);
    ELSE
        -- Find Financial Account matching payment method
        SELECT id, type, balance INTO v_account_id, v_account_type, v_account_balance
        FROM financial_accounts
        WHERE is_active = true 
          AND (UPPER(name) LIKE '%' || UPPER(v_payment_method) || '%' OR UPPER(v_payment_method) LIKE '%' || UPPER(name) || '%')
        LIMIT 1;
        
        IF v_account_id IS NULL THEN
            -- Fallback to the first active account if not found
            SELECT id, type, balance INTO v_account_id, v_account_type, v_account_balance
            FROM financial_accounts
            WHERE is_active = true LIMIT 1;
        END IF;

        IF v_account_id IS NOT NULL THEN
            IF v_account_type = 'CAJA' THEN
                SELECT id INTO v_shift_id
                FROM cash_shifts
                WHERE account_id = v_account_id AND status = 'OPEN'
                LIMIT 1;
            END IF;
            
            INSERT INTO account_movements 
                (account_id, movement_type, amount, description, reference_type, reference_id, shift_id, created_by)
            VALUES 
                (v_account_id, 'INCOME', v_total_amount, 'Cobro de venta — Pedido #' || v_order_id, 'orders', v_order_id, v_shift_id, v_current_profile_id);
                
            UPDATE financial_accounts
            SET balance = balance + v_total_amount
            WHERE id = v_account_id;
        END IF;
    END IF;

    -- 6. Loyalty Points Logic
    IF v_customer_id IS NOT NULL THEN
        SELECT wallet_balance INTO v_wallet_balance FROM profiles WHERE id = v_customer_id;
        
        IF v_points_earned > 0 AND v_payment_method != 'CRÉDITO' THEN
            IF NOT EXISTS (SELECT 1 FROM wallet_movements WHERE order_id = v_order_id AND movement_type = 'EARNED') THEN
                UPDATE profiles SET wallet_balance = COALESCE(wallet_balance, 0) + v_points_earned WHERE id = v_customer_id;
                INSERT INTO wallet_movements (profile_id, order_id, points, movement_type, description)
                VALUES (v_customer_id, v_order_id, v_points_earned, 'EARNED', 'Monedas obtenidas al completar pedido');
            END IF;
        END IF;

        IF v_points_used > 0 THEN
            IF NOT EXISTS (SELECT 1 FROM wallet_movements WHERE order_id = v_order_id AND movement_type = 'REDEEMED') THEN
                UPDATE profiles SET wallet_balance = GREATEST(COALESCE(wallet_balance, 0) - v_points_used, 0) WHERE id = v_customer_id;
                INSERT INTO wallet_movements (profile_id, order_id, points, movement_type, description)
                VALUES (v_customer_id, v_order_id, -v_points_used, 'REDEEMED', 'Canje aplicado al completar pedido');
            END IF;
        END IF;
    END IF;

    -- 7. Update the Order
    UPDATE orders
    SET customer_id = COALESCE(v_customer_id, customer_id),
        customer_name = COALESCE(v_customer_name, customer_name),
        status = 'COMPLETED',
        payment_method = v_payment_method,
        payment_status = CASE WHEN v_payment_method = 'CRÉDITO' THEN 'PENDING' ELSE 'PAID' END,
        amount_paid = CASE WHEN v_payment_method = 'CRÉDITO' THEN 0 ELSE v_total_amount END,
        total_amount = v_total_amount,
        total_profit = GREATEST(v_total_profit, total_profit),
        points_used = CASE WHEN v_payment_method = 'CRÉDITO' THEN 0 ELSE v_points_used END,
        points_earned = CASE WHEN v_payment_method = 'CRÉDITO' THEN 0 ELSE v_points_earned END,
        updated_by = COALESCE(v_current_profile_id, updated_by),
        updated_at = NOW()
    WHERE id = v_order_id;

    RETURN jsonb_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."rpc_complete_order"("payload" "jsonb") OWNER TO "postgres";


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
    
    -- Variables para la sincronización eficiente de imágenes
    v_incoming_image_ids uuid[];
BEGIN
    -- 1. BLINDAJE DE SEGURIDAD: Resolver perfil estrictamente desde el token de autenticación seguro
    SELECT id INTO v_profile_id FROM profiles WHERE auth_user_id = v_auth_user_id LIMIT 1;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Operación rechazada: El usuario autenticado no posee un perfil válido en el sistema.';
    END IF;

    v_is_updating := COALESCE((payload->>'is_updating')::boolean, false);

    -- 2. UPSERT DEL PRODUCTO MAESTRO
    IF v_is_updating THEN
        v_product_id := (payload->'product'->>'id')::uuid;
        IF v_product_id IS NULL THEN
            RAISE EXCEPTION 'Error: Se especificó actualización pero el id del producto es nulo.';
        END IF;

        UPDATE products SET
            name = payload->'product'->>'name',
            description = payload->'product'->>'description',
            category_id = (payload->'product'->>'category_id')::uuid,
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
            name, description, category_id, is_active, details, product_type, stock_control, uses_batches, created_by
        ) VALUES (
            payload->'product'->>'name',
            payload->'product'->>'description',
            (payload->'product'->>'category_id')::uuid,
            COALESCE((payload->'product'->>'is_active')::boolean, true),
            payload->'product'->'details',
            payload->'product'->>'product_type',
            COALESCE((payload->'product'->>'stock_control')::boolean, true),
            COALESCE((payload->'product'->>'uses_batches')::boolean, false),
            v_profile_id
        ) RETURNING id INTO v_product_id;
    END IF;

    -- 3. MANEJO OPTIMIZADO DE IMÁGENES DEL PRODUCTO
    IF payload ? 'images' AND jsonb_typeof(payload->'images') = 'array' THEN
        -- Recolectamos los IDs de imágenes que vienen en el payload para no borrarlas si ya existen
        SELECT array_agg((elem->>'id')::uuid) INTO v_incoming_image_ids
        FROM jsonb_array_elements(payload->'images') AS elem
        WHERE (elem->>'id') IS NOT NULL;

        -- Borramos únicamente las imágenes del producto que ya no están en el nuevo listado (huérfanas)
        DELETE FROM product_images 
        WHERE product_id = v_product_id 
          AND variant_id IS NULL 
          AND (id <> ALL(v_incoming_image_ids) OR v_incoming_image_ids IS NULL);

        -- Ejecutamos Upsert inteligente de las imágenes vigentes o nuevas
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
        -- Si no envían array de imágenes, se eliminan todas las asociadas
        DELETE FROM product_images WHERE product_id = v_product_id AND variant_id IS NULL;
    END IF;

    -- 4. DESACTIVAR VARIANTES ELIMINADAS DESDE LA UI
    IF payload ? 'removed_variant_ids' THEN
        FOR v_removed_id IN SELECT * FROM jsonb_array_elements_text(payload->'removed_variant_ids')
        LOOP
            UPDATE product_variants SET is_active = false, updated_at = NOW(), updated_by = v_profile_id WHERE id = v_removed_id::uuid;
        END LOOP;
    END IF;

    -- 5. UPSERT DE VARIANTES
    IF payload ? 'variants' AND jsonb_typeof(payload->'variants') = 'array' THEN
        FOR v_variant IN SELECT * FROM jsonb_array_elements(payload->'variants')
        LOOP
            IF (v_variant->>'id') IS NOT NULL AND (v_variant->>'id') != '' THEN
                v_variant_id := (v_variant->>'id')::uuid;
                UPDATE product_variants SET
                    sku = v_variant->>'sku',
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
                    product_id, sku, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, created_by
                ) VALUES (
                    v_product_id,
                    v_variant->>'sku',
                    COALESCE((v_variant->>'unit_cost')::numeric, 0.00),
                    COALESCE((v_variant->>'sale_price')::numeric, 0.00),
                    (v_variant->>'wholesale_price')::numeric,
                    (v_variant->>'wholesale_min_quantity')::integer,
                    COALESCE((v_variant->>'reorder_point')::integer, 0),
                    COALESCE((v_variant->>'is_active')::boolean, true),
                    v_profile_id
                ) RETURNING id INTO v_variant_id;
            END IF;

            -- Control optimizado de imágenes de variantes (Limpieza)
            IF COALESCE((v_variant->>'clear_images')::boolean, false) THEN
                DELETE FROM product_images WHERE variant_id = v_variant_id;
            END IF;
            
            -- Inserción segura previniendo duplicados exactos en la misma variante
            IF (v_variant->>'new_image_url') IS NOT NULL AND (v_variant->>'new_image_url') <> '' THEN
                INSERT INTO product_images (product_id, variant_id, image_url, display_order, is_main)
                SELECT v_product_id, v_variant_id, v_variant->>'new_image_url', 0, false
                WHERE NOT EXISTS (
                    SELECT 1 FROM product_images 
                    WHERE variant_id = v_variant_id AND image_url = v_variant->>'new_image_url'
                );
            END IF;

            -- Sincronización limpia de atributos de la variante
            DELETE FROM variant_attribute_values WHERE variant_id = v_variant_id;
            IF v_variant ? 'attribute_value_ids' THEN
                FOR v_attr_id IN SELECT * FROM jsonb_array_elements_text(v_variant->'attribute_value_ids')
                LOOP
                    INSERT INTO variant_attribute_values (variant_id, attribute_value_id)
                    VALUES (v_variant_id, v_attr_id::uuid);
                END LOOP;
            END IF;
        END LOOP;
    END IF;

    -- 6. MANEJO EFICIENTE DE INGREDIENTES ACTIVOS
    DELETE FROM product_active_ingredients WHERE product_id = v_product_id;
    IF COALESCE((payload->>'ingredients_enabled')::boolean, false) AND payload ? 'ingredients' AND jsonb_typeof(payload->'ingredients') = 'array' THEN
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

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."account_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "account_id" "uuid" NOT NULL,
    "movement_type" "text" NOT NULL,
    "amount" numeric NOT NULL,
    "description" "text" NOT NULL,
    "reference_type" "text",
    "reference_id" "uuid",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "shift_id" "uuid"
);


ALTER TABLE "public"."account_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."active_ingredients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "search_vector" "tsvector" GENERATED ALWAYS AS ("to_tsvector"('"spanish"'::"regconfig", "name")) STORED
);


ALTER TABLE "public"."active_ingredients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."app_settings" (
    "key" "text" NOT NULL,
    "value" numeric NOT NULL,
    "description" "text"
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
    "raffles_customer_visible" boolean DEFAULT false
);


ALTER TABLE "public"."business_info" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cart_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cart_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "variant_id" "uuid",
    "quantity" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_selected" boolean DEFAULT true,
    CONSTRAINT "cart_items_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."cart_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cash_shifts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "account_id" "uuid" NOT NULL,
    "opened_by" "uuid" NOT NULL,
    "closed_by" "uuid",
    "opened_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "closed_at" timestamp with time zone,
    "opening_amount" numeric DEFAULT 0.00 NOT NULL,
    "expected_amount" numeric,
    "actual_amount" numeric,
    "difference_amount" numeric,
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
    "updated_by" "uuid"
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_credit_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "customer_credit_id" "uuid" NOT NULL,
    "order_id" "uuid",
    "movement_type" "text" NOT NULL,
    "amount" numeric NOT NULL,
    "payment_method" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    CONSTRAINT "credit_movements_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "credit_movements_movement_type_check" CHECK (("movement_type" = ANY (ARRAY['CHARGE'::"text", 'PAYMENT'::"text"])))
);


ALTER TABLE "public"."customer_credit_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "customer_id" "uuid",
    "total_amount" numeric DEFAULT 0 NOT NULL,
    "total_profit" numeric DEFAULT 0 NOT NULL,
    "payment_method" "text" DEFAULT 'EFECTIVO'::"text" NOT NULL,
    "status" "text" DEFAULT 'COMPLETED'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "warehouse_id" "uuid",
    "points_used" integer DEFAULT 0 NOT NULL,
    "points_earned" integer DEFAULT 0 NOT NULL,
    "customer_name" "text" DEFAULT ''::"text",
    "payment_status" "text" DEFAULT 'PAID'::"text" NOT NULL,
    "amount_paid" numeric DEFAULT 0.00 NOT NULL,
    "due_date" timestamp with time zone,
    "created_by" "uuid",
    "discount_amount" numeric DEFAULT 0.00 NOT NULL,
    "document_type" "text" DEFAULT 'NINGUNO'::"text",
    "document_number" "text",
    "document_date" "date",
    "updated_by" "uuid",
    "updated_at" timestamp with time zone,
    CONSTRAINT "orders_document_type_check" CHECK (("document_type" = ANY (ARRAY['BOLETA'::"text", 'FACTURA'::"text", 'TICKET'::"text", 'NINGUNO'::"text"]))),
    CONSTRAINT "orders_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['PAID'::"text", 'PENDING'::"text", 'PARTIAL'::"text"])))
);


ALTER TABLE "public"."orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "auth_user_id" "uuid",
    "full_name" "text" NOT NULL,
    "avatar_url" "text",
    "role" "public"."user_role" DEFAULT 'customer'::"public"."user_role" NOT NULL,
    "phone" "text",
    "document_type" "text" DEFAULT 'DNI'::"text",
    "document_number" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_active" boolean DEFAULT true NOT NULL,
    "wallet_balance" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


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
    ("o"."id")::"text" AS "order_number"
   FROM (("public"."customer_credit_movements" "cm"
     LEFT JOIN "public"."profiles" "p" ON (("p"."id" = "cm"."created_by")))
     LEFT JOIN "public"."orders" "o" ON (("o"."id" = "cm"."order_id")));


ALTER VIEW "public"."customer_credit_movements_summary" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_credits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "credit_limit" numeric DEFAULT 0.00 NOT NULL,
    "current_debt" numeric DEFAULT 0.00 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    CONSTRAINT "customer_credits_current_debt_check" CHECK (("current_debt" >= (0)::numeric))
);


ALTER TABLE "public"."customer_credits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_locations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
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
    CONSTRAINT "customer_locations_type_check" CHECK (("location_type" = ANY (ARRAY['casa'::"text", 'chacra'::"text", 'fundo'::"text", 'local'::"text", 'otro'::"text"])))
);


ALTER TABLE "public"."customer_locations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_checkins" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "checkin_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "points_received" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "streak_day" integer DEFAULT 1
);


ALTER TABLE "public"."daily_checkins" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."financial_accounts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "type" "text" NOT NULL,
    "balance" numeric DEFAULT 0.00 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."financial_accounts" OWNER TO "postgres";


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
    "total_amount" numeric DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."inventory_entries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_entry_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entry_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "variant_id" "uuid" NOT NULL,
    "quantity" numeric NOT NULL,
    "unit_cost" numeric NOT NULL,
    "batch_number" "text" DEFAULT 'DEFAULT'::"text",
    "expiry_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"(),
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
    "unit_cost" numeric DEFAULT 0,
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
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventory_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "quantity" integer DEFAULT 1 NOT NULL,
    "unit_cost" numeric NOT NULL,
    "applied_price" numeric NOT NULL,
    "net_profit" numeric NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "variant_id" "uuid" NOT NULL
);


ALTER TABLE "public"."order_items" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."partner_credit_summary" WITH ("security_invoker"='true') AS
 SELECT "cc"."id" AS "credit_id",
    "cc"."profile_id",
    "p"."full_name" AS "partner_name",
    "p"."document_number" AS "partner_document",
    "p"."document_type" AS "partner_document_type",
    "p"."phone" AS "partner_phone",
    "cc"."credit_limit",
    "cc"."current_debt",
    GREATEST(("cc"."credit_limit" - "cc"."current_debt"), (0)::numeric) AS "available_credit",
    "cc"."is_active"
   FROM ("public"."customer_credits" "cc"
     JOIN "public"."profiles" "p" ON (("p"."id" = "cc"."profile_id")));


ALTER VIEW "public"."partner_credit_summary" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."product_active_ingredients" (
    "product_id" "uuid" NOT NULL,
    "ingredient_id" "uuid" NOT NULL,
    "concentration" numeric,
    "unit" "text"
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
    "sale_price" numeric,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "reorder_point" integer DEFAULT 3 NOT NULL,
    "wholesale_price" numeric,
    "wholesale_min_quantity" integer,
    "created_by" "uuid",
    "updated_by" "uuid",
    "unit_cost" numeric DEFAULT 0 NOT NULL,
    "barcode" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
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
    "supplier_id" "uuid"
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
    CONSTRAINT "products_product_type_check" CHECK (("product_type" = ANY (ARRAY['good'::"text", 'service'::"text", 'digital'::"text"])))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."profiles_with_email" WITH ("security_invoker"='false') AS
 SELECT "p"."id",
    "p"."auth_user_id",
    "p"."full_name",
    "p"."avatar_url",
    "p"."role",
    "p"."phone",
    "p"."document_type",
    "p"."document_number",
    "p"."created_at",
    "p"."is_active",
    "p"."wallet_balance",
    "u"."email"
   FROM ("public"."profiles" "p"
     LEFT JOIN "auth"."users" "u" ON (("p"."auth_user_id" = "u"."id")));


ALTER VIEW "public"."profiles_with_email" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purchase_order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "purchase_order_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "variant_id" "uuid" NOT NULL,
    "quantity_ordered" numeric NOT NULL,
    "quantity_received" numeric DEFAULT 0 NOT NULL,
    "unit_cost" numeric NOT NULL,
    "net_cost" numeric DEFAULT 0 NOT NULL,
    "batch_number" "text" DEFAULT 'DEFAULT'::"text",
    "expiry_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"(),
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
    "total_amount" numeric DEFAULT 0 NOT NULL,
    "payment_method" "text" DEFAULT 'EFECTIVO'::"text" NOT NULL,
    "payment_status" "text" DEFAULT 'PAID'::"text" NOT NULL,
    "amount_paid" numeric DEFAULT 0 NOT NULL,
    "due_date" timestamp with time zone,
    "discount_amount" numeric DEFAULT 0 NOT NULL,
    "document_type" "text" DEFAULT 'NINGUNO'::"text",
    "document_number" "text",
    "document_date" "date",
    "tax_amount" numeric DEFAULT 0 NOT NULL,
    "notes" "text",
    "created_by" "uuid",
    "updated_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "purchase_orders_document_type_check" CHECK (("document_type" = ANY (ARRAY['FACTURA'::"text", 'BOLETA'::"text", 'GUIA_REMISION'::"text", 'TICKET'::"text", 'NINGUNO'::"text"]))),
    CONSTRAINT "purchase_orders_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['PAID'::"text", 'PENDING'::"text", 'PARTIAL'::"text"]))),
    CONSTRAINT "purchase_orders_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'SENT'::"text", 'PARTIAL'::"text", 'RECEIVED'::"text", 'CANCELLED'::"text"])))
);


ALTER TABLE "public"."purchase_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shopping_carts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shopping_carts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."supplier_credit_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "supplier_credit_id" "uuid" NOT NULL,
    "purchase_order_id" "uuid",
    "movement_type" "text" NOT NULL,
    "amount" numeric NOT NULL,
    "payment_method" "text",
    "due_date" "date",
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "supplier_credit_movements_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "supplier_credit_movements_movement_type_check" CHECK (("movement_type" = ANY (ARRAY['CHARGE'::"text", 'PAYMENT'::"text"])))
);


ALTER TABLE "public"."supplier_credit_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."supplier_credits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "supplier_id" "uuid" NOT NULL,
    "current_debt" numeric DEFAULT 0 NOT NULL,
    "credit_limit" numeric DEFAULT 0 NOT NULL,
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


CREATE TABLE IF NOT EXISTS "public"."variant_attribute_values" (
    "variant_id" "uuid" NOT NULL,
    "attribute_value_id" "uuid" NOT NULL
);


ALTER TABLE "public"."variant_attribute_values" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wallet_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "order_id" "uuid",
    "points" integer NOT NULL,
    "movement_type" "text" NOT NULL,
    "description" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."wallet_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."warehouses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "address" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."warehouses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wishlist" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."wishlist" OWNER TO "postgres";


ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."active_ingredients"
    ADD CONSTRAINT "active_ingredients_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."active_ingredients"
    ADD CONSTRAINT "active_ingredients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_settings"
    ADD CONSTRAINT "app_settings_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."attribute_values"
    ADD CONSTRAINT "attribute_values_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attributes"
    ADD CONSTRAINT "attributes_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."attributes"
    ADD CONSTRAINT "attributes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attribute_values"
    ADD CONSTRAINT "av_unique_value_per_attribute" UNIQUE ("attribute_id", "value");



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



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "credit_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_profile_id_key" UNIQUE ("profile_id");



ALTER TABLE ONLY "public"."customer_locations"
    ADD CONSTRAINT "customer_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_checkins"
    ADD CONSTRAINT "daily_checkins_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."financial_accounts"
    ADD CONSTRAINT "financial_accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_entry_items"
    ADD CONSTRAINT "inventory_entry_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_exit_items"
    ADD CONSTRAINT "inventory_exit_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_exits"
    ADD CONSTRAINT "inventory_exits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "inventory_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."physical_inventories"
    ADD CONSTRAINT "physical_inventories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."physical_inventory_items"
    ADD CONSTRAINT "physical_inventory_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_active_ingredients"
    ADD CONSTRAINT "product_active_ingredients_pkey" PRIMARY KEY ("product_id", "ingredient_id");



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_reviews"
    ADD CONSTRAINT "product_reviews_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shopping_carts"
    ADD CONSTRAINT "shopping_carts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shopping_carts"
    ADD CONSTRAINT "shopping_carts_profile_id_key" UNIQUE ("profile_id");



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



ALTER TABLE ONLY "public"."variant_attribute_values"
    ADD CONSTRAINT "variant_attribute_values_pkey" PRIMARY KEY ("variant_id", "attribute_value_id");



ALTER TABLE ONLY "public"."wallet_movements"
    ADD CONSTRAINT "wallet_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "warehouse_stock_batches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."warehouses"
    ADD CONSTRAINT "warehouses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wishlist"
    ADD CONSTRAINT "wishlist_pkey" PRIMARY KEY ("id");



CREATE INDEX "account_movements_account_id_idx" ON "public"."account_movements" USING "btree" ("account_id");



CREATE INDEX "account_movements_created_by_idx" ON "public"."account_movements" USING "btree" ("created_by");



CREATE INDEX "account_movements_shift_id_idx" ON "public"."account_movements" USING "btree" ("shift_id");



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



CREATE INDEX "idx_customer_credit_movements_created_by" ON "public"."customer_credit_movements" USING "btree" ("created_by");



CREATE INDEX "idx_customer_credit_movements_customer_credit_id" ON "public"."customer_credit_movements" USING "btree" ("customer_credit_id");



CREATE INDEX "idx_customer_credit_movements_order_id" ON "public"."customer_credit_movements" USING "btree" ("order_id");



CREATE INDEX "idx_customer_locations_profile_id" ON "public"."customer_locations" USING "btree" ("profile_id");



CREATE INDEX "idx_inventory_movements_created_by" ON "public"."inventory_movements" USING "btree" ("created_by");



CREATE INDEX "idx_inventory_movements_variant_id" ON "public"."inventory_movements" USING "btree" ("variant_id");



CREATE INDEX "idx_inventory_movements_warehouse_id" ON "public"."inventory_movements" USING "btree" ("warehouse_id");



CREATE INDEX "idx_order_items_order_id" ON "public"."order_items" USING "btree" ("order_id");



CREATE INDEX "idx_order_items_product_id" ON "public"."order_items" USING "btree" ("product_id");



CREATE INDEX "idx_orders_created_by" ON "public"."orders" USING "btree" ("created_by");



CREATE INDEX "idx_orders_customer_id" ON "public"."orders" USING "btree" ("customer_id");



CREATE INDEX "idx_orders_warehouse_id" ON "public"."orders" USING "btree" ("warehouse_id");



CREATE INDEX "idx_product_images_product_id" ON "public"."product_images" USING "btree" ("product_id");



CREATE INDEX "idx_product_variants_barcode" ON "public"."product_variants" USING "btree" ("barcode");



CREATE INDEX "idx_product_variants_product_id" ON "public"."product_variants" USING "btree" ("product_id");



CREATE INDEX "idx_products_category_id" ON "public"."products" USING "btree" ("category_id");



CREATE INDEX "idx_purchase_order_items_po_id" ON "public"."purchase_order_items" USING "btree" ("purchase_order_id");



CREATE INDEX "idx_purchase_orders_supplier_id" ON "public"."purchase_orders" USING "btree" ("supplier_id");



CREATE INDEX "idx_supplier_credit_movements_created_by" ON "public"."supplier_credit_movements" USING "btree" ("created_by");



CREATE INDEX "idx_supplier_credit_movements_credit_id" ON "public"."supplier_credit_movements" USING "btree" ("supplier_credit_id");



CREATE INDEX "idx_supplier_credit_movements_po_id" ON "public"."supplier_credit_movements" USING "btree" ("purchase_order_id");



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



CREATE INDEX "products_created_by_idx" ON "public"."products" USING "btree" ("created_by");



CREATE INDEX "purchase_orders_created_by_idx" ON "public"."purchase_orders" USING "btree" ("created_by");



CREATE INDEX "purchase_orders_updated_by_idx" ON "public"."purchase_orders" USING "btree" ("updated_by");



CREATE INDEX "purchase_orders_warehouse_id_idx" ON "public"."purchase_orders" USING "btree" ("warehouse_id");



CREATE INDEX "supplier_credits_created_by_fidx" ON "public"."supplier_credits" USING "btree" ("created_by");



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



ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."financial_accounts"("id");



ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."account_movements"
    ADD CONSTRAINT "account_movements_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."cash_shifts"("id");



ALTER TABLE ONLY "public"."attribute_values"
    ADD CONSTRAINT "av_attribute_id_fkey" FOREIGN KEY ("attribute_id") REFERENCES "public"."attributes"("id") ON DELETE CASCADE;



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



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "customer_credit_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "customer_credit_movements_customer_credit_id_fkey" FOREIGN KEY ("customer_credit_id") REFERENCES "public"."customer_credits"("id");



ALTER TABLE ONLY "public"."customer_credit_movements"
    ADD CONSTRAINT "customer_credit_movements_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."customer_credits"
    ADD CONSTRAINT "customer_credits_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."customer_locations"
    ADD CONSTRAINT "customer_locations_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_checkins"
    ADD CONSTRAINT "daily_checkins_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



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
    ADD CONSTRAINT "inventory_entries_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."purchase_orders"("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_store_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."inventory_entries"
    ADD CONSTRAINT "inventory_entries_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."inventory_exits"
    ADD CONSTRAINT "inventory_exits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."inventory_exits"
    ADD CONSTRAINT "inventory_exits_store_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_store_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."product_active_ingredients"
    ADD CONSTRAINT "pai_ingredient_id_fkey" FOREIGN KEY ("ingredient_id") REFERENCES "public"."active_ingredients"("id");



ALTER TABLE ONLY "public"."product_active_ingredients"
    ADD CONSTRAINT "pai_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



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



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."product_reviews"
    ADD CONSTRAINT "product_reviews_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."product_reviews"
    ADD CONSTRAINT "product_reviews_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."product_variants"
    ADD CONSTRAINT "product_variants_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_auth_user_id_fkey" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."purchase_orders"("id");



ALTER TABLE ONLY "public"."purchase_order_items"
    ADD CONSTRAINT "purchase_order_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."purchase_orders"
    ADD CONSTRAINT "purchase_orders_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."shopping_carts"
    ADD CONSTRAINT "shopping_carts_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."purchase_orders"("id");



ALTER TABLE ONLY "public"."supplier_credit_movements"
    ADD CONSTRAINT "supplier_credit_movements_supplier_credit_id_fkey" FOREIGN KEY ("supplier_credit_id") REFERENCES "public"."supplier_credits"("id");



ALTER TABLE ONLY "public"."supplier_credits"
    ADD CONSTRAINT "supplier_credits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."supplier_credits"
    ADD CONSTRAINT "supplier_credits_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."variant_attribute_values"
    ADD CONSTRAINT "vav_attribute_value_id_fkey" FOREIGN KEY ("attribute_value_id") REFERENCES "public"."attribute_values"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."variant_attribute_values"
    ADD CONSTRAINT "vav_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "public"."product_variants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wallet_movements"
    ADD CONSTRAINT "wallet_movements_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."wallet_movements"
    ADD CONSTRAINT "wallet_movements_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."warehouse_stock_batches"
    ADD CONSTRAINT "warehouse_stock_batches_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



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



CREATE POLICY "Acceso a cart_items propios" ON "public"."cart_items" USING ((("cart_id" IN ( SELECT "shopping_carts"."id"
   FROM "public"."shopping_carts"
  WHERE ("shopping_carts"."profile_id" = "extensions"."auth_profile_id"()))) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Acceso propio CRUD" ON "public"."shopping_carts" USING ((("profile_id" = "extensions"."auth_profile_id"()) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Acceso propio CRUD" ON "public"."wishlist" USING ((("profile_id" = "extensions"."auth_profile_id"()) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Acceso selectivo a créditos por rol o propietario" ON "public"."customer_credits" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "profile_id") OR (( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Acceso total admin y empleado" ON "public"."account_movements" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."financial_accounts" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."physical_inventories" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."physical_inventory_items" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."supplier_credits" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."suppliers" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."warehouse_stock_batches" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Acceso total admin y empleado" ON "public"."warehouses" USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Actualizacion de reviews" ON "public"."product_reviews" FOR UPDATE USING ((("profile_id" = "extensions"."auth_profile_id"()) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Actualizacion de turno" ON "public"."cash_shifts" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Actualización del propio perfil" ON "public"."profiles" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Admins and owners can manage customer locations" ON "public"."customer_locations" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Borrado admin checkins" ON "public"."daily_checkins" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."active_ingredients" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."app_settings" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."attribute_values" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."attributes" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."categories" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."product_active_ingredients" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."product_images" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."product_variants" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."products" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado admin/empleado" ON "public"."variant_attribute_values" FOR DELETE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Borrado de reviews" ON "public"."product_reviews" FOR DELETE USING ((("profile_id" = "extensions"."auth_profile_id"()) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Gestión selectiva de ubicaciones por rol o propietario" ON "public"."customer_locations" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "profile_id") OR (( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."active_ingredients" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."app_settings" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."attribute_values" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."attributes" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."categories" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."product_active_ingredients" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."product_images" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."product_variants" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."products" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public"."variant_attribute_values" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion de reviews" ON "public"."product_reviews" FOR INSERT WITH CHECK (("profile_id" = "extensions"."auth_profile_id"()));



CREATE POLICY "Insercion propia de checkins" ON "public"."daily_checkins" FOR INSERT WITH CHECK (("profile_id" = "extensions"."auth_profile_id"()));



CREATE POLICY "Insercion validada e inmutable" ON "public"."cash_shifts" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("opened_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."customer_credit_movements" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."inventory_entries" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."inventory_entry_items" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion validada e inmutable" ON "public"."inventory_exit_items" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion validada e inmutable" ON "public"."inventory_exits" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."inventory_movements" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."purchase_order_items" FOR INSERT WITH CHECK (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Insercion validada e inmutable" ON "public"."purchase_orders" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Insercion validada e inmutable" ON "public"."supplier_credit_movements" FOR INSERT WITH CHECK ((("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) AND ("created_by" = "extensions"."auth_profile_id"())));



CREATE POLICY "Inserción unificada de artículos de orden" ON "public"."order_items" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) OR (EXISTS ( SELECT 1
   FROM "public"."orders" "o"
  WHERE (("o"."id" = "order_items"."order_id") AND ("o"."customer_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "Inserción unificada de órdenes" ON "public"."orders" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) OR (( SELECT "auth"."uid"() AS "uid") = "customer_id")));



CREATE POLICY "Lectura admin/empleado" ON "public"."cash_shifts" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."customer_credit_movements" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."inventory_entries" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."inventory_entry_items" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."inventory_exit_items" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."inventory_exits" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."inventory_movements" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."purchase_order_items" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."purchase_orders" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura admin/empleado" ON "public"."supplier_credit_movements" FOR SELECT USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Lectura propia de checkins" ON "public"."daily_checkins" FOR SELECT USING ((("profile_id" = "extensions"."auth_profile_id"()) OR ("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Lectura publica" ON "public"."active_ingredients" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."app_settings" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."attribute_values" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."attributes" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."categories" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."product_active_ingredients" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."product_images" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."product_variants" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."products" FOR SELECT USING (true);



CREATE POLICY "Lectura publica" ON "public"."variant_attribute_values" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de business_info" ON "public"."business_info" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de reviews" ON "public"."product_reviews" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de stock" ON "public"."warehouse_stock_batches" FOR SELECT USING (true);



CREATE POLICY "Lectura selectiva de movimientos de billetera por rol o propiet" ON "public"."wallet_movements" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "profile_id") OR (( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Lectura selectiva de perfiles por rol o propietario" ON "public"."profiles" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "id") OR (( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"]))));



CREATE POLICY "Lectura unificada de artículos de orden" ON "public"."order_items" FOR SELECT TO "authenticated" USING (((( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) OR (EXISTS ( SELECT 1
   FROM "public"."orders" "o"
  WHERE (("o"."id" = "order_items"."order_id") AND ("o"."customer_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "Lectura unificada de órdenes" ON "public"."orders" FOR SELECT TO "authenticated" USING (((( SELECT "extensions"."auth_user_role"() AS "auth_user_role") = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])) OR (( SELECT "auth"."uid"() AS "uid") = "customer_id")));



CREATE POLICY "Modificacion admin business_info" ON "public"."business_info" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin checkins" ON "public"."daily_checkins" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."active_ingredients" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."app_settings" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."attribute_values" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."attributes" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."categories" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."product_active_ingredients" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."product_images" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."product_variants" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."products" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."purchase_order_items" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."purchase_orders" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



CREATE POLICY "Modificacion admin/empleado" ON "public"."variant_attribute_values" FOR UPDATE USING (("extensions"."auth_user_role"() = ANY (ARRAY['admin'::"public"."user_role", 'employee'::"public"."user_role"])));



ALTER TABLE "public"."account_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."active_ingredients" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."app_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."attribute_values" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."attributes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."business_info" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cart_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cash_shifts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_credit_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_credits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_locations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."daily_checkins" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."financial_accounts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_entry_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_exit_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_exits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."physical_inventories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."physical_inventory_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_active_ingredients" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_images" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_variants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."purchase_order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."purchase_orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shopping_carts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."supplier_credit_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."supplier_credits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."suppliers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."variant_attribute_values" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wallet_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouse_stock_batches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wishlist" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";























































































































































































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



GRANT ALL ON FUNCTION "public"."get_cash_shifts_summary_rpc"("p_limit" integer, "p_offset" integer, "p_status" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_profile_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_cash_shifts_summary_rpc"("p_limit" integer, "p_offset" integer, "p_status" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_profile_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_cash_shifts_summary_rpc"("p_limit" integer, "p_offset" integer, "p_status" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_profile_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_loyalty_dashboard"("p_auth_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_loyalty_dashboard"("p_auth_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_loyalty_dashboard"("p_auth_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_movement_totals_rpc"("p_filter_type" "text", "p_account_id" "text", "p_search_text" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."get_movement_totals_rpc"("p_filter_type" "text", "p_account_id" "text", "p_search_text" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_movement_totals_rpc"("p_filter_type" "text", "p_account_id" "text", "p_search_text" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_purchase_order_items_details"("p_order_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_purchase_order_items_details"("p_order_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_purchase_order_items_details"("p_order_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_supplier_credits_stats_rpc"("p_search_query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_supplier_credits_stats_rpc"("p_search_query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_supplier_credits_stats_rpc"("p_search_query" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_top_customers"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_top_customers"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_top_customers"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_update_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_update_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_update_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."process_customer_checkout"("p_customer_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb", "p_use_points" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."process_customer_checkout"("p_customer_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb", "p_use_points" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_customer_checkout"("p_customer_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb", "p_use_points" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."process_inventory_entry_rpc"("p_warehouse_id" "uuid", "p_supplier_id" "uuid", "p_purchase_order_id" "uuid", "p_payment_mode" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_document_type" "text", "p_document_number" "text", "p_document_date" "date", "p_notes" "text", "p_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."process_inventory_entry_rpc"("p_warehouse_id" "uuid", "p_supplier_id" "uuid", "p_purchase_order_id" "uuid", "p_payment_mode" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_document_type" "text", "p_document_number" "text", "p_document_date" "date", "p_notes" "text", "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_inventory_entry_rpc"("p_warehouse_id" "uuid", "p_supplier_id" "uuid", "p_purchase_order_id" "uuid", "p_payment_mode" "text", "p_account_id" "uuid", "p_active_shift_id" "uuid", "p_document_type" "text", "p_document_number" "text", "p_document_date" "date", "p_notes" "text", "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."process_inventory_exit_rpc"("p_warehouse_id" "uuid", "p_reason" "text", "p_notes" "text", "p_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."process_inventory_exit_rpc"("p_warehouse_id" "uuid", "p_reason" "text", "p_notes" "text", "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_inventory_exit_rpc"("p_warehouse_id" "uuid", "p_reason" "text", "p_notes" "text", "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."process_pos_sale"("payload" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."process_pos_sale"("payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_pos_sale"("payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."register_credit_payment_rpc"("p_customer_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."register_credit_payment_rpc"("p_customer_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_credit_payment_rpc"("p_customer_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."register_financial_movement"("p_account_id" "uuid", "p_movement_type" "text", "p_amount" numeric, "p_description" "text", "p_reference_type" "text", "p_reference_id" "uuid", "p_created_by" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."register_financial_movement"("p_account_id" "uuid", "p_movement_type" "text", "p_amount" numeric, "p_description" "text", "p_reference_type" "text", "p_reference_id" "uuid", "p_created_by" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_financial_movement"("p_account_id" "uuid", "p_movement_type" "text", "p_amount" numeric, "p_description" "text", "p_reference_type" "text", "p_reference_id" "uuid", "p_created_by" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."register_supplier_credit_payment_rpc"("p_supplier_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid", "p_profile_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."register_supplier_credit_payment_rpc"("p_supplier_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid", "p_profile_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_supplier_credit_payment_rpc"("p_supplier_id" "uuid", "p_credit_id" "uuid", "p_amount" numeric, "p_account_id" "uuid", "p_order_id" "uuid", "p_notes" "text", "p_shift_id" "uuid", "p_profile_id" "uuid") TO "service_role";



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



GRANT ALL ON FUNCTION "public"."rpc_create_supplier_credit"("p_supplier_id" "uuid", "p_credit_limit" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_create_supplier_credit"("p_supplier_id" "uuid", "p_credit_limit" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_create_supplier_credit"("p_supplier_id" "uuid", "p_credit_limit" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_open_cash_shift"("p_account_id" "uuid", "p_opening_amount" numeric, "p_opened_by" "uuid", "p_notes" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_open_cash_shift"("p_account_id" "uuid", "p_opening_amount" numeric, "p_opened_by" "uuid", "p_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_open_cash_shift"("p_account_id" "uuid", "p_opening_amount" numeric, "p_opened_by" "uuid", "p_notes" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."rpc_receive_purchase_order_items"("p_order_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_receive_purchase_order_items"("p_order_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_receive_purchase_order_items"("p_order_id" "uuid", "p_warehouse_id" "uuid", "p_items" "jsonb") TO "service_role";



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



GRANT ALL ON FUNCTION "public"."sync_cloud_cart_rpc"("p_auth_user_id" "uuid", "p_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."sync_cloud_cart_rpc"("p_auth_user_id" "uuid", "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_cloud_cart_rpc"("p_auth_user_id" "uuid", "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_purchase_order_reception_rpc"("p_purchase_order_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."sync_purchase_order_reception_rpc"("p_purchase_order_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_purchase_order_reception_rpc"("p_purchase_order_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."transfer_funds_rpc"("p_source_account_id" "uuid", "p_dest_account_id" "uuid", "p_amount" numeric, "p_description" "text", "p_created_by" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."transfer_funds_rpc"("p_source_account_id" "uuid", "p_dest_account_id" "uuid", "p_amount" numeric, "p_description" "text", "p_created_by" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_funds_rpc"("p_source_account_id" "uuid", "p_dest_account_id" "uuid", "p_amount" numeric, "p_description" "text", "p_created_by" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_po_payment_method_rpc"("p_order_id" "uuid", "p_supplier_id" "uuid", "p_new_method" "text", "p_old_method" "text", "p_order_amount" numeric, "p_profile_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."update_po_payment_method_rpc"("p_order_id" "uuid", "p_supplier_id" "uuid", "p_new_method" "text", "p_old_method" "text", "p_order_amount" numeric, "p_profile_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_po_payment_method_rpc"("p_order_id" "uuid", "p_supplier_id" "uuid", "p_new_method" "text", "p_old_method" "text", "p_order_amount" numeric, "p_profile_id" "uuid") TO "service_role";
























GRANT ALL ON TABLE "public"."account_movements" TO "anon";
GRANT ALL ON TABLE "public"."account_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."account_movements" TO "service_role";



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



GRANT ALL ON TABLE "public"."daily_checkins" TO "anon";
GRANT ALL ON TABLE "public"."daily_checkins" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_checkins" TO "service_role";



GRANT ALL ON TABLE "public"."financial_accounts" TO "anon";
GRANT ALL ON TABLE "public"."financial_accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."financial_accounts" TO "service_role";



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



GRANT ALL ON TABLE "public"."order_items" TO "anon";
GRANT ALL ON TABLE "public"."order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."order_items" TO "service_role";



GRANT ALL ON TABLE "public"."partner_credit_summary" TO "anon";
GRANT ALL ON TABLE "public"."partner_credit_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."partner_credit_summary" TO "service_role";



GRANT ALL ON TABLE "public"."physical_inventories" TO "anon";
GRANT ALL ON TABLE "public"."physical_inventories" TO "authenticated";
GRANT ALL ON TABLE "public"."physical_inventories" TO "service_role";



GRANT ALL ON TABLE "public"."physical_inventory_items" TO "anon";
GRANT ALL ON TABLE "public"."physical_inventory_items" TO "authenticated";
GRANT ALL ON TABLE "public"."physical_inventory_items" TO "service_role";



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



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."profiles_with_email" TO "anon";
GRANT ALL ON TABLE "public"."profiles_with_email" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_with_email" TO "service_role";



GRANT ALL ON TABLE "public"."purchase_order_items" TO "anon";
GRANT ALL ON TABLE "public"."purchase_order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."purchase_order_items" TO "service_role";



GRANT ALL ON TABLE "public"."purchase_orders" TO "anon";
GRANT ALL ON TABLE "public"."purchase_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."purchase_orders" TO "service_role";



GRANT ALL ON TABLE "public"."shopping_carts" TO "anon";
GRANT ALL ON TABLE "public"."shopping_carts" TO "authenticated";
GRANT ALL ON TABLE "public"."shopping_carts" TO "service_role";



GRANT ALL ON TABLE "public"."supplier_credit_movements" TO "anon";
GRANT ALL ON TABLE "public"."supplier_credit_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."supplier_credit_movements" TO "service_role";



GRANT ALL ON TABLE "public"."supplier_credits" TO "anon";
GRANT ALL ON TABLE "public"."supplier_credits" TO "authenticated";
GRANT ALL ON TABLE "public"."supplier_credits" TO "service_role";



GRANT ALL ON TABLE "public"."suppliers" TO "anon";
GRANT ALL ON TABLE "public"."suppliers" TO "authenticated";
GRANT ALL ON TABLE "public"."suppliers" TO "service_role";



GRANT ALL ON TABLE "public"."variant_attribute_values" TO "anon";
GRANT ALL ON TABLE "public"."variant_attribute_values" TO "authenticated";
GRANT ALL ON TABLE "public"."variant_attribute_values" TO "service_role";



GRANT ALL ON TABLE "public"."wallet_movements" TO "anon";
GRANT ALL ON TABLE "public"."wallet_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."wallet_movements" TO "service_role";



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































