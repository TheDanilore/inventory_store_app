import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product/exit_sheet_helpers.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/exit_quantity_stepper.dart';

class ExitBatchPicker extends StatelessWidget {
  final List<Map<String, dynamic>> batches;
  final Map<String, dynamic>? selectedBatch;
  final Map<String, double> reserved;
  final ValueChanged<Map<String, dynamic>> onSelectBatch;

  const ExitBatchPicker({
    super.key,
    required this.batches,
    required this.selectedBatch,
    required this.reserved,
    required this.onSelectBatch,
  });

  double _stockOf(Map<String, dynamic> b) =>
      (b['available_quantity'] as num?)?.toDouble() ?? 0.0;

  double _remainingOf(Map<String, dynamic> b) {
    final r = _stockOf(b) - (reserved[exitBatchKey(b)] ?? 0.0);
    return r < 0 ? 0.0 : r;
  }

  DateTime? _expiryOf(Map<String, dynamic> b) {
    final raw = b['expiry_date'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  @override
  Widget build(BuildContext context) {
    final hasMultipleExpiries =
        batches.where((b) => _expiryOf(b) != null).length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ExitFieldLabel('Lote'),
        const SizedBox(height: 8),
        ...List.generate(batches.length, (i) {
          final b = batches[i];
          final remaining = _remainingOf(b);
          final key = exitBatchKey(b);
          return Padding(
            padding: EdgeInsets.only(bottom: i == batches.length - 1 ? 0 : 8),
            child: _BatchTile(
              batchNumber: (b['batch_number'] ?? '—').toString(),
              expiry: _expiryOf(b),
              remaining: remaining,
              alreadyInList: reserved[key] ?? 0.0,
              selected: exitBatchKey(selectedBatch) == key && key.isNotEmpty,
              expiresFirst:
                  hasMultipleExpiries && i == 0 && _expiryOf(b) != null,
              onTap:
                  remaining > 0
                      ? () {
                        AppFeedbackService.selectionClick();
                        onSelectBatch(b);
                      }
                      : null,
            ),
          );
        }),
      ],
    );
  }
}

class _BatchTile extends StatelessWidget {
  final String batchNumber;
  final DateTime? expiry;
  final double remaining;
  final double alreadyInList;
  final bool selected;
  final bool expiresFirst;
  final VoidCallback? onTap;

  const _BatchTile({
    required this.batchNumber,
    required this.expiry,
    required this.remaining,
    required this.alreadyInList,
    required this.selected,
    required this.expiresFirst,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final disabled = onTap == null;

    final subtitleParts = <String>[
      expiry != null ? 'Vence: ${formatExitDate(expiry!)}' : 'Sin vencimiento',
      if (alreadyInList > 0) '${formatExitQty(alreadyInList)} ya en la lista',
    ];

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  selected
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              batchNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (expiresFirst) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Vence primero',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' · '),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Stock',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      formatExitQty(remaining),
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
