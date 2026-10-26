import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_state.dart';

/// Banda de métricas financieras del producto.
/// Aislada con BlocSelector para minimizar rebuilds y consumo de CPU.
class ProductFinancialStrip extends StatelessWidget {
  final bool isCompact;

  const ProductFinancialStrip({super.key, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = _getCurrencySymbol(context);

    return BlocSelector<
      ProductDetailCubit,
      ProductDetailState,
      _FinancialMetrics
    >(
      selector:
          (state) => _FinancialMetrics(
            effectivePrice: state.effectivePrice,
            cost: state.effectiveCost,
            effectiveStock: state.effectiveStock,
            baseWholesalePrice: state.baseWholesalePrice,
            baseWholesaleMinQty: state.baseWholesaleMinQty,
            retailProfit: state.retailProfit,
            retailMargin: state.retailMargin,
            isLowStock: state.isLowStock,
            reorderPoint: state.reorderPoint,
            totalInventoryValue: state.totalInventoryValue,
          ),
      builder: (context, metrics) {
        if (isCompact) {
          return _buildCompact(context, isDark, currencySymbol, metrics);
        }
        return _buildDesktop(context, isDark, currencySymbol, metrics);
      },
    );
  }

  static String _getCurrencySymbol(BuildContext context) {
    try {
      return context.read<AppConfigCubit>().state.baseCurrency.symbol;
    } catch (_) {
      return 'S/';
    }
  }

  Widget _buildCompact(
    BuildContext context,
    bool isDark,
    String currencySymbol,
    _FinancialMetrics m,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
        boxShadow:
            isDark
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  label: 'PRECIO VENTA',
                  value:
                      '$currencySymbol ${m.effectivePrice.toStringAsFixed(2)}',
                  subValue:
                      m.baseWholesalePrice != null
                          ? 'Mayorista: $currencySymbol ${m.baseWholesalePrice!.toStringAsFixed(2)}'
                          : null,
                  valueColor: AppColors.primary,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: (isDark ? AppColors.darkBorder : AppColors.border)
                    .withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricItem(
                  label: 'STOCK TOTAL',
                  value: '${m.effectiveStock} uds',
                  subValue:
                      m.isLowStock ? 'Bajo punto de reorden' : 'Stock óptimo',
                  valueColor:
                      m.isLowStock ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
          Divider(
            height: 18,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  label: 'COSTO ERP',
                  value:
                      m.cost > 0
                          ? '$currencySymbol ${m.cost.toStringAsFixed(2)}'
                          : '$currencySymbol 0.00',
                  subValue:
                      '${m.retailMargin.toStringAsFixed(1)}% margen bruto',
                  valueColor:
                      isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: (isDark ? AppColors.darkBorder : AppColors.border)
                    .withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricItem(
                  label: 'VALOR INVENTARIO',
                  value:
                      '$currencySymbol ${m.totalInventoryValue.toStringAsFixed(2)}',
                  subValue:
                      m.reorderPoint > 0
                          ? 'Mínimo: ${m.reorderPoint} u.'
                          : 'Sin reorden',
                  valueColor:
                      isDark
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(
    BuildContext context,
    bool isDark,
    String currencySymbol,
    _FinancialMetrics m,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
        boxShadow:
            isDark
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _MetricItem(
              label: 'PRECIO DE VENTA',
              value: '$currencySymbol ${m.effectivePrice.toStringAsFixed(2)}',
              subValue:
                  m.baseWholesalePrice != null
                      ? 'Mayorista: $currencySymbol ${m.baseWholesalePrice!.toStringAsFixed(2)} (Min ${m.baseWholesaleMinQty}u)'
                      : null,
              valueColor: AppColors.primary,
            ),
          ),
          Container(
            width: 1,
            height: 46,
            color: (isDark ? AppColors.darkBorder : AppColors.border)
                .withValues(alpha: 0.7),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 3,
            child: _MetricItem(
              label: 'COSTO & RENTABILIDAD',
              value:
                  m.cost > 0
                      ? '$currencySymbol ${m.cost.toStringAsFixed(2)}'
                      : '$currencySymbol 0.00',
              subValue:
                  '${m.retailMargin.toStringAsFixed(1)}% margen bruto ($currencySymbol ${m.retailProfit.toStringAsFixed(2)})',
              valueColor:
                  isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              badgeColor:
                  m.retailMargin > 20 ? AppColors.success : AppColors.warning,
            ),
          ),
          Container(
            width: 1,
            height: 46,
            color: (isDark ? AppColors.darkBorder : AppColors.border)
                .withValues(alpha: 0.7),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 3,
            child: _MetricItem(
              label: 'STOCK TOTAL DISPONIBLE',
              value: '${m.effectiveStock} unidades',
              subValue:
                  m.isLowStock
                      ? 'Alerta: Bajo punto de reorden'
                      : 'Existencias saludables',
              valueColor: m.isLowStock ? AppColors.error : AppColors.success,
              isPill: true,
            ),
          ),
          Container(
            width: 1,
            height: 46,
            color: (isDark ? AppColors.darkBorder : AppColors.border)
                .withValues(alpha: 0.7),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 2,
            child: _MetricItem(
              label: 'VALORIZACIÓN TOTAL',
              value:
                  '$currencySymbol ${m.totalInventoryValue.toStringAsFixed(2)}',
              subValue:
                  m.reorderPoint > 0
                      ? 'Mínimo: ${m.reorderPoint} u.'
                      : 'Sin reorden',
              valueColor:
                  isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final Color valueColor;
  final Color? badgeColor;
  final bool isPill;

  const _MetricItem({
    required this.label,
    required this.value,
    this.subValue,
    required this.valueColor,
    this.badgeColor,
    this.isPill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: valueColor,
              ),
            ),
            if (badgeColor != null) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        if (subValue != null) ...[
          const SizedBox(height: 2),
          Text(
            subValue!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color:
                  isPill && valueColor == AppColors.error
                      ? AppColors.error
                      : AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _FinancialMetrics {
  final double effectivePrice;
  final double cost;
  final int effectiveStock;
  final double? baseWholesalePrice;
  final int baseWholesaleMinQty;
  final double retailProfit;
  final double retailMargin;
  final bool isLowStock;
  final int reorderPoint;
  final double totalInventoryValue;

  const _FinancialMetrics({
    required this.effectivePrice,
    required this.cost,
    required this.effectiveStock,
    this.baseWholesalePrice,
    required this.baseWholesaleMinQty,
    required this.retailProfit,
    required this.retailMargin,
    required this.isLowStock,
    required this.reorderPoint,
    required this.totalInventoryValue,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FinancialMetrics &&
          runtimeType == other.runtimeType &&
          effectivePrice == other.effectivePrice &&
          cost == other.cost &&
          effectiveStock == other.effectiveStock &&
          baseWholesalePrice == other.baseWholesalePrice &&
          baseWholesaleMinQty == other.baseWholesaleMinQty &&
          retailProfit == other.retailProfit &&
          retailMargin == other.retailMargin &&
          isLowStock == other.isLowStock &&
          reorderPoint == other.reorderPoint &&
          totalInventoryValue == other.totalInventoryValue;

  @override
  int get hashCode => Object.hash(
    effectivePrice,
    cost,
    effectiveStock,
    baseWholesalePrice,
    baseWholesaleMinQty,
    retailProfit,
    retailMargin,
    isLowStock,
    reorderPoint,
    totalInventoryValue,
  );
}
