import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_cubit.dart';

class ProductAvailabilityCard extends StatelessWidget {
  const ProductAvailabilityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = context.watch<ProductDetailCubit>().state;
    final cubit = context.read<ProductDetailCubit>();
    if (!cubit.isAdmin) return const SizedBox.shrink();

    final List<Map<String, dynamic>> displayStocks;
    if (state.selectedVariantId != null) {
      displayStocks =
          state.warehouseStocks
              .where((row) => row['variant_id'] == state.selectedVariantId)
              .toList();
    } else {
      final Map<String, Map<String, dynamic>> aggregated = {};
      for (final row in state.warehouseStocks) {
        final warehouseId = row['warehouse_id']?.toString() ?? 'unknown';
        final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
        if (aggregated.containsKey(warehouseId)) {
          final currentQty =
              aggregated[warehouseId]!['available_quantity'] as int;
          aggregated[warehouseId]!['available_quantity'] = currentQty + qty;
        } else {
          aggregated[warehouseId] = Map<String, dynamic>.from(row);
          aggregated[warehouseId]!['available_quantity'] = qty;
        }
      }
      displayStocks = aggregated.values.toList();
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppColors.cardAdaptive(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.warehouse_rounded,
              iconColor: const Color(0xFF0D9488),
              iconBg:
                  isDark
                      ? const Color(0xFF134E4A).withValues(alpha: 0.4)
                      : const Color(0xFFCCFBF1),
              title: 'Stock por almacén',
            ),
            const SizedBox(height: 14),
            if (state.viewState == ViewState.loading)
              const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              )
            else if (displayStocks.isEmpty)
              Text(
                'Sin registros.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                ),
              )
            else
              ...displayStocks.map((row) {
                final name = row['warehouses']?['name'] ?? 'Almacén';
                final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;
                final ok = stock > 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color:
                              ok
                                  ? (isDark
                                      ? AppColors.success.withValues(alpha: 0.2)
                                      : AppColors.successLight)
                                  : (isDark
                                      ? AppColors.danger.withValues(alpha: 0.2)
                                      : AppColors.dangerLight),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          Icons.warehouse_rounded,
                          size: 13,
                          color: ok ? AppColors.success : AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? const Color(0xFFF8FAFC)
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              ok
                                  ? (isDark
                                      ? AppColors.primary.withValues(alpha: 0.2)
                                      : AppColors.primary.withValues(
                                        alpha: 0.08,
                                      ))
                                  : (isDark
                                      ? AppColors.danger.withValues(alpha: 0.2)
                                      : AppColors.dangerLight),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '$stock',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: ok ? AppColors.primary : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ─── CARD HEADER ──────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  const _CardHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
