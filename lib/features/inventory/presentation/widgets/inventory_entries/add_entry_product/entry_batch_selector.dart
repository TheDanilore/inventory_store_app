import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_stock_batch_model.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_product_common_widgets.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_product_formatters.dart';

class EntryBatchSelector extends StatelessWidget {
  final bool isBatchRequired;
  final bool isLoadingBatches;
  final List<Map<String, dynamic>> availableBatches;
  final String? productId;
  final String? variantId;
  final TextEditingController batchCtrl;
  final DateTime? expiryDate;
  final ValueChanged<String> onBatchChanged;
  final ValueChanged<DateTime?> onExpiryDateChanged;
  final ValueChanged<WarehouseStockBatchModel> onBatchSelected;

  const EntryBatchSelector({
    super.key,
    required this.isBatchRequired,
    required this.isLoadingBatches,
    required this.availableBatches,
    required this.productId,
    required this.variantId,
    required this.batchCtrl,
    required this.expiryDate,
    required this.onBatchChanged,
    required this.onExpiryDateChanged,
    required this.onBatchSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntryFieldLabel(
          isBatchRequired ? 'Lote (obligatorio)' : 'Lote (opcional)',
        ),
        const SizedBox(height: 8),
        if (isLoadingBatches)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final overlayWidth = constraints.maxWidth;
              return Autocomplete<WarehouseStockBatchModel>(
                key: ValueKey('batch_autocomplete_${productId}_$variantId'),
                initialValue: TextEditingValue(text: batchCtrl.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final batches =
                      availableBatches
                          .map((e) => WarehouseStockBatchModel.fromJson(e))
                          .toList();
                  if (textEditingValue.text.isEmpty) return batches;
                  return batches.where(
                    (option) => option.batchNumber.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ),
                  );
                },
                displayStringForOption: (option) => option.batchNumber,
                fieldViewBuilder: (
                  context,
                  textEditingController,
                  focusNode,
                  onFieldSubmitted,
                ) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (value) {
                      batchCtrl.text = value;
                      onBatchChanged(value);
                    },
                    decoration: entryInputDecoration(
                      hint:
                          availableBatches.isEmpty
                              ? (isBatchRequired
                                  ? 'Ej: LOTE-2024-001'
                                  : 'Se asigna en la recepción física')
                              : 'Escribe o elige un lote existente',
                      prefixIcon: const Icon(
                        Icons.tag_rounded,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon:
                          availableBatches.isNotEmpty
                              ? Tooltip(
                                message:
                                    '${availableBatches.length} lote(s) en este almacén',
                                child: Icon(
                                  Icons.layers_rounded,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                  size: 20,
                                ),
                              )
                              : null,
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Material(
                        elevation: 8,
                        shadowColor: Colors.black.withValues(alpha: 0.15),
                        surfaceTintColor: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        color: colorScheme.surface,
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 260,
                            maxWidth: overlayWidth,
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder:
                                (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              final dateStr =
                                  option.expiryDate != null
                                      ? formatDate(option.expiryDate!)
                                      : 'Sin vencimiento';
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.tag_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  option.batchNumber,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  'Vence: $dateStr',
                                  style: textTheme.bodySmall,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Stock',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      option.availableQuantity.toStringAsFixed(
                                        0,
                                      ),
                                      style: textTheme.titleSmall?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  AppFeedbackService.lightImpact();
                                  onSelected(option);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
                onSelected: onBatchSelected,
              );
            },
          ),
        const SizedBox(height: 12),
        _DatePickerField(
          label: 'Fecha de vencimiento (opcional)',
          value: expiryDate,
          onPick: onExpiryDateChanged,
          onClear: () {
            AppFeedbackService.lightImpact();
            onExpiryDateChanged(null);
          },
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onClear;

  const _DatePickerField({
    required this.label,
    this.value,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          AppFeedbackService.lightImpact();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now().add(const Duration(days: 30)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            helpText: 'Fecha de vencimiento',
          );
          if (picked != null) onPick(picked);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          padding: EdgeInsets.only(left: 16, right: value != null ? 0 : 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value == null ? label : 'Vence: ${formatDate(value!)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color:
                        value == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                    fontWeight:
                        value == null ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
