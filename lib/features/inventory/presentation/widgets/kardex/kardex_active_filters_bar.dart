import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_state.dart';

/// Banner de información sobre filtros activos (Producto, Variante o Lote específico).
class KardexActiveFiltersBar extends StatelessWidget {
  final VoidCallback onClearProduct;

  const KardexActiveFiltersBar({super.key, required this.onClearProduct});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      KardexCubit,
      KardexState,
      ({
        String? productId,
        String? variantId,
        String? variantName,
        String? batchId,
        String? batchNumber,
        String searchText,
      })?
    >(
      selector: (state) {
        if (state is! KardexLoaded) return null;
        final hasActive =
            state.productId != null ||
            state.variantId != null ||
            state.batchId != null ||
            state.batchNumber != null;
        if (!hasActive) return null;
        return (
          productId: state.productId,
          variantId: state.variantId,
          variantName: state.variantName,
          batchId: state.batchId,
          batchNumber: state.batchNumber,
          searchText: state.searchText,
        );
      },
      builder: (context, data) {
        if (data == null) return const SizedBox.shrink();

        final prodLabel =
            data.searchText.isNotEmpty
                ? data.searchText
                : (data.productId ?? 'Producto');
        final hasVariant = data.variantId != null;
        final hasBatch = data.batchId != null || data.batchNumber != null;
        final variantLabel =
            data.variantName != null && data.variantName!.isNotEmpty
                ? data.variantName!
                : (hasVariant
                    ? 'ID: ${data.variantId!.length > 8 ? data.variantId!.substring(0, 8) : data.variantId}...'
                    : '');
        final batchLabel =
            data.batchNumber != null && data.batchNumber!.isNotEmpty
                ? data.batchNumber!
                : (hasBatch
                    ? 'ID: ${data.batchId!.length > 8 ? data.batchId!.substring(0, 8) : data.batchId}...'
                    : '');

        final cubit = context.read<KardexCubit>();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_alt_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Filtrando: ',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: prodLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (hasVariant) ...[
                          const TextSpan(text: ' · Variante: '),
                          TextSpan(
                            text: variantLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                        if (hasBatch) ...[
                          const TextSpan(text: ' · Lote: '),
                          TextSpan(
                            text: batchLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasBatch) ...[
                  InkWell(
                    onTap: () => cubit.clearBatchFilter(),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        'Ver todos los lotes',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.purple.shade700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (hasVariant) ...[
                  InkWell(
                    onTap: () => cubit.clearVariantFilter(),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: const Text(
                        'Ver todas las variantes',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: onClearProduct,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Limpiar',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
