-- ============================================================================
-- MIGRACIÓN DE RENDIMIENTO: Índices Compuestos para Kárdex (inventory_movements)
-- ============================================================================
-- Elimina escaneos secuenciales y ordenamientos costosos en disco (filesort)
-- durante la consulta del Kárdex por fecha y variante/producto.

-- 1. Índice ordenado por fecha de creación descendente (para el listado principal)
CREATE INDEX IF NOT EXISTS "idx_inventory_movements_created_at_desc"
ON "public"."inventory_movements" USING "btree" ("created_at" DESC);

-- 2. Índice compuesto para consultas filtradas por variante y ordenadas por fecha
CREATE INDEX IF NOT EXISTS "idx_inventory_movements_variant_created_at"
ON "public"."inventory_movements" USING "btree" ("variant_id", "created_at" DESC);

-- 3. Índice compuesto para consultas filtradas por almacén y ordenadas por fecha
CREATE INDEX IF NOT EXISTS "idx_inventory_movements_warehouse_created_at"
ON "public"."inventory_movements" USING "btree" ("warehouse_id", "created_at" DESC);

-- 4. Índice compuesto para consultas filtradas por lote y ordenadas por fecha
CREATE INDEX IF NOT EXISTS "idx_inventory_movements_batch_created_at"
ON "public"."inventory_movements" USING "btree" ("stock_batch_id", "created_at" DESC);
