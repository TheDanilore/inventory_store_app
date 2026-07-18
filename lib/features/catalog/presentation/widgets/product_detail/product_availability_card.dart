import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail_cubit.dart';

class ProductAvailabilityCard extends StatelessWidget {
  const ProductAvailabilityCard({super.key});

  @override
  Widget build(BuildContext context) {
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
        decoration: AppColors.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              icon: Icons.warehouse_rounded,
              iconColor: Color(0xFF0D9488),
              iconBg: Color(0xFFCCFBF1),
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
              const Text(
                'Sin registros.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color:
                              ok
                                  ? AppColors.successLight
                                  : AppColors.dangerLight,
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
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
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : AppColors.dangerLight,
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
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
