import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_product_common_widgets.dart';

class EntryProductFooterActions extends StatelessWidget {
  final String? formError;
  final bool canAdd;
  final bool showAddAndContinue;
  final VoidCallback onAddAndContinue;
  final VoidCallback onSubmit;

  const EntryProductFooterActions({
    super.key,
    required this.formError,
    required this.canAdd,
    required this.showAddAndContinue,
    required this.onAddAndContinue,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (formError != null) EntryInlineError(message: formError!),
          Row(
            children: [
              if (showAddAndContinue) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: canAdd ? onAddAndContinue : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Agregar y seguir',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: canAdd ? onSubmit : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.primary,
                    foregroundColor: colorScheme.onPrimary,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Agregar a la lista',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
