import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_cubit.dart';

/// Diálogo modal desacoplado para edición de lote y fecha de vencimiento.
class EntryBatchEditDialog extends StatefulWidget {
  final int itemIndex;
  final InventoryEntryItemEntity item;
  final InventoryEntryFormCubit cubit;

  const EntryBatchEditDialog({
    super.key,
    required this.itemIndex,
    required this.item,
    required this.cubit,
  });

  static Future<void> show(
    BuildContext context, {
    required int itemIndex,
    required InventoryEntryItemEntity item,
    required InventoryEntryFormCubit cubit,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => EntryBatchEditDialog(
            itemIndex: itemIndex,
            item: item,
            cubit: cubit,
          ),
    );
  }

  @override
  State<EntryBatchEditDialog> createState() => _EntryBatchEditDialogState();
}

class _EntryBatchEditDialogState extends State<EntryBatchEditDialog> {
  late final TextEditingController _batchCtrl;
  DateTime? _selectedExpiry;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _batchCtrl = TextEditingController(text: widget.item.batchNumber);
    _selectedExpiry = widget.item.expiryDate;
  }

  @override
  void dispose() {
    _batchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    AppFeedbackService.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedExpiry ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      helpText: 'Fecha de Vencimiento',
    );
    if (picked != null && mounted) {
      setState(() => _selectedExpiry = picked);
    }
  }

  void _submit() {
    final text = _batchCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _localError = 'El número de lote es obligatorio');
      return;
    }
    widget.cubit.updateItemBatch(widget.itemIndex, text, _selectedExpiry);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Lote y Vencimiento',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.productName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.item.variantLabel.isNotEmpty &&
                widget.item.variantLabel != 'Variante Única') ...[
              const SizedBox(height: 2),
              Text(
                widget.item.variantLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _batchCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Nº de Lote *',
                hintText: 'Ej: LOTE-2024-001',
                errorText: _localError,
                prefixIcon: const Icon(
                  Icons.tag,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (val) {
                if (_localError != null) {
                  setState(() => _localError = null);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Fecha de Vencimiento (Opcional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickExpiryDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedExpiry != null
                            ? '${_selectedExpiry!.day.toString().padLeft(2, '0')}/${_selectedExpiry!.month.toString().padLeft(2, '0')}/${_selectedExpiry!.year}'
                            : 'Sin fecha de vencimiento',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              _selectedExpiry != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                          fontWeight:
                              _selectedExpiry != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (_selectedExpiry != null)
                      GestureDetector(
                        onTap: () {
                          AppFeedbackService.lightImpact();
                          setState(() => _selectedExpiry = null);
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Guardar Lote'),
        ),
      ],
    );
  }
}
