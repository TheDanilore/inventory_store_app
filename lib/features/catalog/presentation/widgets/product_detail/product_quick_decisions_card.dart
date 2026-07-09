// ─── COMPONENTE: DECISIONES RÁPIDAS ──────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail_cubit.dart';
import 'package:inventory_store_app/features/dashboard/data/models/product_financial_summary.dart';

class ProductQuickDecisionsCard extends StatelessWidget {
  const ProductQuickDecisionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductDetailCubit>().state;
    final cubit = context.read<ProductDetailCubit>();
    if (!cubit.isAdmin) return const SizedBox.shrink();

    final totalSold = state.totalSold;
    final inventoryValue = state.inventoryValue;
    final totalRevenue = state.totalRevenue;
    final reinvestmentNeeded = state.reinvestmentNeeded;
    final variantSummaries = state.variantSummaries;

    final hasData = totalSold > 0 || inventoryValue > 0;
    if (!hasData) return const SizedBox.shrink();

    final double realizedProfit = totalRevenue - reinvestmentNeeded;
    final double totalCapital = inventoryValue + totalRevenue;
    final bool multiVariant = variantSummaries.length > 1;

    return Material(
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        side: const BorderSide(color: Color(0xFF86EFAC), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: const Color(0xFF166534),
          iconColor: const Color(0xFF166534),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFF166534),
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Decisiones rápidas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
              if (totalSold > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalSold uds.',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
            ],
          ),
          children: [
            // ── Totales generales destacados ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _TotalHighlight(
                    label: 'En inventario',
                    value: 'S/ ${inventoryValue.toStringAsFixed(2)}',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _TotalHighlight(
                    label: 'Ingresos ventas',
                    value: 'S/ ${totalRevenue.toStringAsFixed(2)}',
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF059669),
                  ),
                ],
              ),
            ),

            // ── Desglose por variante (si hay más de una) ──────────────────
            if (multiVariant) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.layers_rounded,
                      size: 13,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Por variante',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    // Cabecera de columnas
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 5,
                            child: Text(
                              'Variante',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          _ColHeader('Stock\nactual'),
                          _ColHeader('Capital\nstock'),
                          _ColHeader('Vendido\nuds.'),
                          _ColHeader('Ingreso\nventa'),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFBBF7D0)),
                    ...variantSummaries.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final isLast = i == variantSummaries.length - 1;
                      return Column(
                        children: [
                          _VariantRow(summary: s),
                          if (!isLast)
                            const Divider(
                              height: 1,
                              color: Color(0xFFECFDF5),
                              indent: 12,
                              endIndent: 12,
                            ),
                        ],
                      );
                    }),
                    // Fila de totales
                    const Divider(height: 1, color: Color(0xFFBBF7D0)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 5,
                            child: Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ),
                          _ColValue(
                            '${variantSummaries.fold(0, (s, v) => s + v.stockQuantity)}',
                            bold: true,
                          ),
                          _ColValue(
                            'S/${inventoryValue.toStringAsFixed(2)}',
                            bold: true,
                            color: AppColors.primary,
                          ),
                          _ColValue('$totalSold', bold: true),
                          _ColValue(
                            'S/${totalRevenue.toStringAsFixed(2)}',
                            bold: true,
                            color: const Color(0xFF059669),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Detalle de ganancias ───────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                children: [
                  if (reinvestmentNeeded > 0) ...[
                    _DecisionRow(
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.amberDark,
                      label: 'Fondo de reposición',
                      value: 'S/ ${reinvestmentNeeded.toStringAsFixed(2)}',
                      subtitle: 'Para reponer el stock vendido al costo.',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFBBF7D0)),
                    ),
                  ],
                  _DecisionRow(
                    icon: Icons.savings_rounded,
                    color:
                        realizedProfit >= 0
                            ? const Color(0xFF059669)
                            : AppColors.danger,
                    label: 'Ganancia realizada',
                    value:
                        '${realizedProfit >= 0 ? '+' : ''}S/ ${realizedProfit.toStringAsFixed(2)}',
                    subtitle: 'Ingresos totales menos costo de lo vendido.',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFBBF7D0)),
                  ),
                  _DecisionRow(
                    icon: Icons.account_balance_rounded,
                    color: const Color(0xFF166534),
                    label: 'Capital total generado',
                    value: 'S/ ${totalCapital.toStringAsFixed(2)}',
                    subtitle: 'Inventario actual + ingresos acumulados.',
                    isBold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fila por variante en la tabla ─────────────────────────────────────────────
class _VariantRow extends StatelessWidget {
  final VariantFinancialSummary summary;
  const _VariantRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.variant.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'C: S/${s.unitCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _ColValue('${s.stockQuantity}'),
          _ColValue(
            'S/${s.inventoryValue.toStringAsFixed(2)}',
            color: s.inventoryValue > 0 ? AppColors.primary : null,
          ),
          _ColValue('${s.soldQuantity}'),
          _ColValue(
            'S/${s.soldRevenue.toStringAsFixed(2)}',
            color: s.soldRevenue > 0 ? const Color(0xFF059669) : null,
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares de tabla ───────────────────────────────────────────────
class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          height: 1.3,
        ),
      ),
    );
  }
}

class _ColValue extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;
  const _ColValue(this.text, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: bold ? 11 : 10,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color ?? AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ── Tarjeta de total destacado ────────────────────────────────────────────────
class _TotalHighlight extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TotalHighlight({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fila de detalle ───────────────────────────────────────────────────────────
class _DecisionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;
  final bool isBold;

  const _DecisionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isBold ? color : AppColors.textSecondary,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
