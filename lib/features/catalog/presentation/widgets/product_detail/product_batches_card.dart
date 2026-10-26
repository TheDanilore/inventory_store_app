import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProductBatchesCard extends StatelessWidget {
  final bool initiallyExpanded;
  const ProductBatchesCard({super.key, this.initiallyExpanded = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = context.watch<ProductDetailCubit>().state;
    final isLoading =
        state.viewState == ViewState.loading && state.batchesList.isEmpty;

    if (state.batchesList.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    final filteredBatches =
        state.selectedVariantId == null
            ? state.batchesList
            : state.batchesList
                .where((row) => row['variant_id'] == state.selectedVariantId)
                .toList();

    return Container(
      decoration: AppColors.cardAdaptive(context),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            collapsedIconColor:
                isDark ? const Color(0xFF94A3B8) : AppColors.slate,
            iconColor: isDark ? const Color(0xFF94A3B8) : AppColors.slate,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF78350F).withValues(alpha: 0.4)
                            : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Lotes y Vencimientos',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark
                            ? const Color(0xFFF8FAFC)
                            : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      )
                    else if (filteredBatches.isEmpty)
                      Text(
                        'No hay lotes registrados para esta variante.',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFF94A3B8)
                                  : AppColors.textMuted,
                        ),
                      )
                    else
                      ...filteredBatches.map((row) {
                        final batchNum =
                            row['batch_number']?.toString() ?? 'Sin Lote';
                        final stock =
                            (row['available_quantity'] as num?)?.toInt() ?? 0;
                        final whName =
                            row['warehouses']?['name']?.toString() ?? 'Almacén';
                        final String? expStr = row['expiry_date'];

                        DateTime? expDate;
                        int daysRemaining = 999;

                        if (expStr != null) {
                          expDate = DateTime.tryParse(expStr);
                          if (expDate != null) {
                            daysRemaining =
                                expDate.difference(DateTime.now()).inDays;
                          }
                        }

                        // Lógica de semáforo de colores
                        Color statusColor = AppColors.success;
                        Color statusBg =
                            isDark
                                ? AppColors.success.withValues(alpha: 0.2)
                                : AppColors.successLight;
                        String statusLabel = 'OK';
                        IconData statusIcon =
                            Icons.check_circle_outline_rounded;

                        if (stock <= 0 && daysRemaining >= 0) {
                          statusColor = AppColors.slate;
                          statusBg =
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : AppColors.slate.withValues(alpha: 0.15);
                          statusLabel = 'Sin stock';
                          statusIcon = Icons.remove_circle_outline_rounded;
                        } else if (expDate != null) {
                          if (daysRemaining < 0) {
                            statusColor = AppColors.danger;
                            statusBg =
                                isDark
                                    ? AppColors.danger.withValues(alpha: 0.2)
                                    : AppColors.dangerLight;
                            statusLabel = 'Vencido';
                            statusIcon = Icons.warning_rounded;
                          } else if (daysRemaining <= 30) {
                            statusColor = AppColors.amberDark;
                            statusBg =
                                isDark
                                    ? AppColors.amberDark.withValues(alpha: 0.2)
                                    : AppColors.amberLight;
                            statusLabel = 'Vence pronto';
                            statusIcon = Icons.info_outline_rounded;
                          }
                        }

                        String dateLabel = 'Sin fecha';
                        if (expDate != null) {
                          dateLabel =
                              '${expDate.day.toString().padLeft(2, '0')}/${expDate.month.toString().padLeft(2, '0')}/${expDate.year}';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? AppColors.darkSurfaceElevated
                                    : AppColors.background,
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusSm + 2,
                            ),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppColors.darkBorder
                                      : AppColors.border,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  statusIcon,
                                  size: 16,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          batchNum,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                isDark
                                                    ? const Color(0xFFF8FAFC)
                                                    : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusBg,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color:
                                              isDark
                                                  ? const Color(0xFF64748B)
                                                  : AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          whName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.event_rounded,
                                          size: 12,
                                          color:
                                              isDark
                                                  ? const Color(0xFF64748B)
                                                  : AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          dateLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                expDate != null &&
                                                        daysRemaining <= 30
                                                    ? statusColor
                                                    : isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : AppColors.textSecondary,
                                            fontWeight:
                                                expDate != null &&
                                                        daysRemaining <= 30
                                                    ? FontWeight.w700
                                                    : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      stock <= 0
                                          ? (isDark
                                              ? AppColors.darkBorder
                                              : AppColors.slate.withValues(
                                                alpha: 0.1,
                                              ))
                                          : (isDark
                                              ? AppColors.primary.withValues(
                                                alpha: 0.2,
                                              )
                                              : AppColors.primary.withValues(
                                                alpha: 0.1,
                                              )),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$stock',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color:
                                            stock <= 0
                                                ? (isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : AppColors.slate)
                                                : AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      'unds',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            stock <= 0
                                                ? (isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : AppColors.slate)
                                                : AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
