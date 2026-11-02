-- ==============================================================================
-- FIX: RPC OPTIMIZADO PARA TOTALES Y CONTEO DE MOVIMIENTOS DE CRÉDITO
-- ==============================================================================
-- Elimina el Egress masivo: En lugar de descargar miles de filas JSON al cliente
-- para calcular la suma y conteo en Dart, PostgreSQL agrega en milisegundos
-- y retorna exactamente 1 sola fila con 4 valores escalares.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_credit_movements_totals_rpc(
    p_credit_id UUID,
    p_date_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
    total_charged NUMERIC,
    total_paid NUMERIC,
    charge_count BIGINT,
    payment_count BIGINT
) 
LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
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

-- Permisos de ejecución
GRANT EXECUTE ON FUNCTION public.get_credit_movements_totals_rpc(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_credit_movements_totals_rpc(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_credit_movements_totals_rpc(UUID, TEXT) TO anon;

