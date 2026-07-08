import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Card financiera con tres columnas de métricas y montos animados.
///
/// Los montos se "cuentan" desde 0 hasta su valor final usando
/// [TweenAnimationBuilder] para una primera impresión premium.
///
/// Usado en `po_detail_sheet` (Total / Pagado / Deuda) y potencialmente
/// en `inventory_exit_detail_sheet` (Costo Total).
class FinancialSummaryCard extends StatelessWidget {
  /// Lista de columnas a mostrar.
  final List<FinancialColumn> columns;

  /// Duración de la animación de conteo. Default: 700ms.
  final Duration animationDuration;

  const FinancialSummaryCard({
    super.key,
    required this.columns,
    this.animationDuration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children:
            columns
                .map(
                  (col) => _FinancialColumnWidget(
                    column: col,
                    animationDuration: animationDuration,
                  ),
                )
                .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Datos de una columna de la [FinancialSummaryCard].
class FinancialColumn {
  final String label;
  final double amount;

  /// Prefijo de moneda. Default: `'S/ '`.
  final String currencyPrefix;

  /// Color del monto. Default: [AppColors.textPrimary].
  final Color? amountColor;

  /// Alineación del texto. Default: [CrossAxisAlignment.start].
  final CrossAxisAlignment alignment;

  const FinancialColumn({
    required this.label,
    required this.amount,
    this.currencyPrefix = 'S/ ',
    this.amountColor,
    this.alignment = CrossAxisAlignment.start,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class _FinancialColumnWidget extends StatelessWidget {
  final FinancialColumn column;
  final Duration animationDuration;

  const _FinancialColumnWidget({
    required this.column,
    required this.animationDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: column.alignment,
      children: [
        // ── Label uppercase ───────────────────────────────────────
        Text(
          column.label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            // Mejorado de textHint (#9CA3AF) a textSecondary (#64748B)
            // para cumplir mejor con WCAG AA en fondos claros.
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),

        // ── Monto con animación de conteo ─────────────────────────
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: column.amount),
          duration: animationDuration,
          curve: Curves.easeOutCubic,
          builder: (_, value, _) {
            return Text(
              '${column.currencyPrefix}${value.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: column.amountColor ?? AppColors.textPrimary,
              ),
            );
          },
        ),
      ],
    );
  }
}
