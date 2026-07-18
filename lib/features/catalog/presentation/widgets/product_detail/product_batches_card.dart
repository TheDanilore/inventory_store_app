import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProductBatchesCard extends StatelessWidget {
  const ProductBatchesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductDetailCubit>().state;
    final isLoading = state.viewState == ViewState.loading;

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
      decoration: AppColors.card(),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            collapsedIconColor: AppColors.slate,
            iconColor: AppColors.slate,
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
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Lotes y Vencimientos',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
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
                      const Text(
                        'No hay lotes con stock para esta variante.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
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
                        Color statusBg = AppColors.successLight;
                        String statusLabel = 'OK';
                        IconData statusIcon =
                            Icons.check_circle_outline_rounded;

                        if (expDate != null) {
                          if (daysRemaining < 0) {
                            statusColor = AppColors.danger;
                            statusBg = AppColors.dangerLight;
                            statusLabel = 'Vencido';
                            statusIcon = Icons.warning_rounded;
                          } else if (daysRemaining <= 30) {
                            statusColor = AppColors.amberDark;
                            statusBg = AppColors.amberLight;
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
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusSm + 2,
                            ),
                            border: Border.all(color: AppColors.border),
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
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
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
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          whName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.event_rounded,
                                          size: 12,
                                          color: AppColors.textMuted,
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
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$stock',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const Text(
                                      'unds',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
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
