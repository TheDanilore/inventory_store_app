import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product/exit_sheet_helpers.dart';

class ExitSelectedProductCard extends StatelessWidget {
  final String name;
  final String? variantLabel;
  final String? imageUrl;
  final bool usesBatches;
  final VoidCallback onChange;

  const ExitSelectedProductCard({
    super.key,
    required this.name,
    required this.variantLabel,
    required this.imageUrl,
    required this.usesBatches,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ExitProductThumbnail(imageUrl: imageUrl, size: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (variantLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      variantLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (usesBatches)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Se controla por lote',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(64, 44),
            ),
            child: const Text(
              'Cambiar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
