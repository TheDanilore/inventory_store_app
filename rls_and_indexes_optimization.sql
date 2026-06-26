-- ==============================================================================
-- 🚀 SCRIPT DE OPTIMIZACIÓN Y SEGURIDAD PARA SUPABASE (RLS + ÍNDICES)
-- Creado por: Antigravity (DBA Senior & SecOps)
-- Aplicación: Inventory Store App
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. FUNCIONES AUXILIARES (PERFORMANCE Y SEGURIDAD)
-- ------------------------------------------------------------------------------
-- Estas funciones evitan hacer JOINs costosos en cada política RLS.
-- Extraen el ID de perfil y el Rol basándose en el auth.uid() de Supabase.

CREATE OR REPLACE FUNCTION public.auth_profile_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.auth_user_role()
RETURNS public.user_role
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$;


-- ------------------------------------------------------------------------------
-- 2. BLOQUEO GLOBAL (ACTIVACIÓN DE ROW LEVEL SECURITY)
-- ------------------------------------------------------------------------------
-- Cierra por defecto el acceso a todas las tablas para usuarios no autorizados.

ALTER TABLE "public"."account_movements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."active_ingredients" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."app_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."attributes" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."attribute_values" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."cart_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."cash_shifts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."customer_credit_movements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."customer_credits" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."daily_checkins" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."financial_accounts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."inventory_entries" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."inventory_entry_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."inventory_exits" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."inventory_exit_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."inventory_movements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."physical_inventories" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."physical_inventory_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."product_active_ingredients" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."product_images" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."product_reviews" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."product_variants" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."purchase_orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."purchase_order_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."shopping_carts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."supplier_credit_movements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."supplier_credits" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."suppliers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."user_addresses" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."variant_attribute_values" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."wallet_movements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."warehouses" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."warehouse_stock_batches" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."wishlist" ENABLE ROW LEVEL SECURITY;


-- ------------------------------------------------------------------------------
-- 3. POLÍTICAS RLS: PERFILES
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Enable read access for all users" ON "public"."profiles";

CREATE POLICY "Lectura total para administradores y empleados" 
ON "public"."profiles" FOR SELECT
USING (public.auth_user_role() IN ('admin', 'employee'));

CREATE POLICY "Lectura del propio perfil" 
ON "public"."profiles" FOR SELECT
USING (auth_user_id = auth.uid());

CREATE POLICY "Actualización del propio perfil" 
ON "public"."profiles" FOR UPDATE
USING (auth_user_id = auth.uid()) 
WITH CHECK (auth_user_id = auth.uid());


-- ------------------------------------------------------------------------------
-- 4. POLÍTICAS RLS: CATÁLOGO (Público de lectura, Restringido de escritura)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  table_name text;
BEGIN
  FOR table_name IN 
    SELECT unnest(ARRAY[
      'categories', 'products', 'product_variants', 'attributes', 'attribute_values', 
      'variant_attribute_values', 'product_images', 'product_active_ingredients', 'active_ingredients', 'app_settings'
    ])
  LOOP
    EXECUTE format('CREATE POLICY "Lectura publica" ON "public".%I FOR SELECT USING (true)', table_name);
    
    EXECUTE format('CREATE POLICY "Insercion admin/empleado con validacion de identidad" ON "public".%I FOR INSERT WITH CHECK (public.auth_user_role() IN (''admin'', ''employee'') AND created_by = public.auth_profile_id())', table_name);
    
    EXECUTE format('CREATE POLICY "Modificacion admin/empleado" ON "public".%I FOR UPDATE USING (public.auth_user_role() IN (''admin'', ''employee''))', table_name);
    
    EXECUTE format('CREATE POLICY "Borrado admin/empleado" ON "public".%I FOR DELETE USING (public.auth_user_role() IN (''admin'', ''employee''))', table_name);
  END LOOP;
END;
$$;


-- ------------------------------------------------------------------------------
-- 5. POLÍTICAS RLS: TABLAS TRANSACCIONALES ESTRICTAS E INMUTABLES
-- ------------------------------------------------------------------------------
-- ¡OJO! No se generan políticas para UPDATE o DELETE de forma deliberada.
-- Al no tener política explícita de UPDATE/DELETE, Supabase bloquea estas acciones (DEFAULT DENY).

DO $$
DECLARE
  t_name text;
BEGIN
  FOR t_name IN 
    SELECT unnest(ARRAY[
      'customer_credit_movements', 'supplier_credit_movements', 'inventory_movements', 
      'inventory_entries', 'inventory_exits', 'cash_shifts', 'orders', 'purchase_orders',
      'inventory_entry_items', 'inventory_exit_items', 'order_items', 'purchase_order_items'
    ])
  LOOP
    EXECUTE format('CREATE POLICY "Lectura admin/empleado" ON "public".%I FOR SELECT USING (public.auth_user_role() IN (''admin'', ''employee''))', t_name);
    
    -- Exigimos mediante WITH CHECK que el registro se guarde a nombre de quien está logueado.
    EXECUTE format('CREATE POLICY "Insercion validada e inmutable" ON "public".%I FOR INSERT WITH CHECK (public.auth_user_role() IN (''admin'', ''employee'') AND created_by = public.auth_profile_id())', t_name);
  END LOOP;
END;
$$;


-- ------------------------------------------------------------------------------
-- 6. CORRECCIÓN DE NOMBRES DE RESTRICCIONES (CONSTRAINTS)
-- ------------------------------------------------------------------------------
ALTER TABLE "public"."customer_credit_movements"
  RENAME CONSTRAINT "credit_movements_credit_id_fkey" TO "customer_credit_movements_credit_id_fkey";

ALTER TABLE "public"."customer_credit_movements"
  RENAME CONSTRAINT "credit_movements_created_by_fkey" TO "customer_credit_movements_created_by_fkey";

ALTER TABLE "public"."customer_credit_movements"
  RENAME CONSTRAINT "credit_movements_order_id_fkey" TO "customer_credit_movements_order_id_fkey";


-- ------------------------------------------------------------------------------
-- 7. ÍNDICES DE ALTO RENDIMIENTO PARA FOREIGN KEYS (MOBILE APP OPTIMIZATION)
-- ------------------------------------------------------------------------------

-- Créditos de Clientes
CREATE INDEX IF NOT EXISTS "idx_customer_credit_movements_credit_id" ON "public"."customer_credit_movements"("credit_id");
CREATE INDEX IF NOT EXISTS "idx_customer_credit_movements_order_id" ON "public"."customer_credit_movements"("order_id");
CREATE INDEX IF NOT EXISTS "idx_customer_credit_movements_created_by" ON "public"."customer_credit_movements"("created_by");

-- Créditos de Proveedores
CREATE INDEX IF NOT EXISTS "idx_supplier_credit_movements_credit_id" ON "public"."supplier_credit_movements"("credit_id");
CREATE INDEX IF NOT EXISTS "idx_supplier_credit_movements_po_id" ON "public"."supplier_credit_movements"("purchase_order_id");
CREATE INDEX IF NOT EXISTS "idx_supplier_credit_movements_created_by" ON "public"."supplier_credit_movements"("created_by");

-- Ventas / Órdenes
CREATE INDEX IF NOT EXISTS "idx_orders_customer_id" ON "public"."orders"("customer_id");
CREATE INDEX IF NOT EXISTS "idx_orders_shift_id" ON "public"."orders"("shift_id");
CREATE INDEX IF NOT EXISTS "idx_orders_created_by" ON "public"."orders"("created_by");
CREATE INDEX IF NOT EXISTS "idx_order_items_order_id" ON "public"."order_items"("order_id");
CREATE INDEX IF NOT EXISTS "idx_order_items_product_id" ON "public"."order_items"("product_id");

-- Movimientos de Inventario
CREATE INDEX IF NOT EXISTS "idx_inventory_movements_variant_id" ON "public"."inventory_movements"("variant_id");
CREATE INDEX IF NOT EXISTS "idx_inventory_movements_warehouse_id" ON "public"."inventory_movements"("warehouse_id");
CREATE INDEX IF NOT EXISTS "idx_inventory_movements_created_by" ON "public"."inventory_movements"("created_by");

-- Catálogo
CREATE INDEX IF NOT EXISTS "idx_products_category_id" ON "public"."products"("category_id");
CREATE INDEX IF NOT EXISTS "idx_product_variants_product_id" ON "public"."product_variants"("product_id");
CREATE INDEX IF NOT EXISTS "idx_product_images_product_id" ON "public"."product_images"("product_id");

-- Órdenes de Compra
CREATE INDEX IF NOT EXISTS "idx_purchase_orders_supplier_id" ON "public"."purchase_orders"("supplier_id");
CREATE INDEX IF NOT EXISTS "idx_purchase_order_items_po_id" ON "public"."purchase_order_items"("purchase_order_id");


-- ------------------------------------------------------------------------------
-- 8. POLÍTICAS RLS: TABLAS EXCLUSIVAS ADMIN/EMPLEADO
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  t_name text;
BEGIN
  FOR t_name IN 
    SELECT unnest(ARRAY[
      'warehouses', 'warehouse_stock_batches', 'suppliers', 'supplier_credits', 
      'financial_accounts', 'account_movements', 'physical_inventories', 'physical_inventory_items'
    ])
  LOOP
    EXECUTE format('CREATE POLICY "Acceso total admin y empleado" ON "public".%I USING (public.auth_user_role() IN (''admin'', ''employee''))', t_name);
  END LOOP;
END;
$$;


-- ------------------------------------------------------------------------------
-- 9. POLÍTICAS RLS: ACCESO DEL USUARIO A SUS PROPIOS REGISTROS (READ-ONLY)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  t_name text;
BEGIN
  FOR t_name IN SELECT unnest(ARRAY['customer_credits', 'wallet_movements'])
  LOOP
    EXECUTE format('CREATE POLICY "Lectura propia" ON "public".%I FOR SELECT USING (profile_id = public.auth_profile_id() OR public.auth_user_role() IN (''admin'', ''employee''))', t_name);
    EXECUTE format('CREATE POLICY "Modificacion admin" ON "public".%I USING (public.auth_user_role() IN (''admin'', ''employee''))', t_name);
  END LOOP;
END;
$$;


-- ------------------------------------------------------------------------------
-- 10. POLÍTICAS RLS: ACCESO DEL USUARIO A SUS PROPIOS REGISTROS (CRUD)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  t_name text;
BEGIN
  FOR t_name IN SELECT unnest(ARRAY['shopping_carts', 'wishlist', 'user_addresses'])
  LOOP
    EXECUTE format('CREATE POLICY "Acceso propio CRUD" ON "public".%I USING (profile_id = public.auth_profile_id() OR public.auth_user_role() IN (''admin'', ''employee''))', t_name);
  END LOOP;
END;
$$;


-- ------------------------------------------------------------------------------
-- 11. POLÍTICAS RLS: CARRITO DE COMPRAS (ITEMS)
-- ------------------------------------------------------------------------------
CREATE POLICY "Acceso a cart_items propios" ON "public"."cart_items"
USING (
  cart_id IN (SELECT id FROM public.shopping_carts WHERE profile_id = public.auth_profile_id())
  OR public.auth_user_role() IN ('admin', 'employee')
);


-- ------------------------------------------------------------------------------
-- 12. POLÍTICAS RLS: RESEÑAS Y CHECKINS (USUARIOS)
-- ------------------------------------------------------------------------------
-- Product Reviews
CREATE POLICY "Lectura publica de reviews" ON "public"."product_reviews" FOR SELECT USING (true);
CREATE POLICY "Insercion de reviews" ON "public"."product_reviews" FOR INSERT WITH CHECK (profile_id = public.auth_profile_id());
CREATE POLICY "Actualizacion de reviews" ON "public"."product_reviews" FOR UPDATE USING (profile_id = public.auth_profile_id() OR public.auth_user_role() IN ('admin', 'employee'));
CREATE POLICY "Borrado de reviews" ON "public"."product_reviews" FOR DELETE USING (profile_id = public.auth_profile_id() OR public.auth_user_role() IN ('admin', 'employee'));

-- Daily Checkins
CREATE POLICY "Lectura propia de checkins" ON "public"."daily_checkins" FOR SELECT USING (profile_id = public.auth_profile_id() OR public.auth_user_role() IN ('admin', 'employee'));
CREATE POLICY "Insercion propia de checkins" ON "public"."daily_checkins" FOR INSERT WITH CHECK (profile_id = public.auth_profile_id());
CREATE POLICY "Modificacion admin checkins" ON "public"."daily_checkins" FOR UPDATE USING (public.auth_user_role() IN ('admin', 'employee'));
CREATE POLICY "Borrado admin checkins" ON "public"."daily_checkins" FOR DELETE USING (public.auth_user_role() IN ('admin', 'employee'));
