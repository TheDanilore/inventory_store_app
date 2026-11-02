-- ==============================================================================
-- MIGRACIÓN SQL: Integridad ACID y Rendimiento para Ingredientes Activos
-- ==============================================================================

-- 1. Índice único funcional normalizado para evitar duplicados insensibles a mayúsculas y espacios
-- Previene que existan 'Glifosato', 'GLIFOSATO', ' glifosato ' simultáneamente en la base de datos.
CREATE UNIQUE INDEX IF NOT EXISTS "idx_active_ingredients_name_normalized"
ON "public"."active_ingredients" (LOWER(TRIM("name")));

-- 2. Índice B-Tree para optimizar búsquedas por prefijo / ordenamiento
CREATE INDEX IF NOT EXISTS "idx_active_ingredients_name_sort"
ON "public"."active_ingredients" ("name" ASC);

-- 3. Extensión y RPC seguro para eliminación atómica con chequeo relacional (evita race conditions)
CREATE OR REPLACE FUNCTION "public"."delete_active_ingredient_safely"(p_ingredient_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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
