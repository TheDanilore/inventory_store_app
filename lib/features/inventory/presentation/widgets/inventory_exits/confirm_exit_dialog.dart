import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/exit_quantity_stepper.dart';

/// Confirmación estricta con escritura obligatoria de "CONFIRMAR".
/// Es un StatefulWidget con su propio controlador encapsulado para evitar
/// que se destruya antes del cierre del modal ("TextEditingController used after being disposed").
class ConfirmExitDialog extends StatefulWidget {
  final String? reason;
  final int lines;
  final double units;
  final double totalLoss;

  const ConfirmExitDialog({
    super.key,
    required this.reason,
    required this.lines,
    required this.units,
    required this.totalLoss,
  });

  @override
  State<ConfirmExitDialog> createState() => _ConfirmExitDialogState();
}

class _ConfirmExitDialogState extends State<ConfirmExitDialog> {
  final _ctrl = TextEditingController();
  bool _valid = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Confirmar salida',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    if (widget.reason != null)
                      ExitSummaryRow(label: 'Motivo', value: widget.reason!),
                    ExitSummaryRow(label: 'Líneas', value: '${widget.lines}'),
                    ExitSummaryRow(
                      label: 'Unidades',
                      value: formatExitQty(widget.units),
                    ),
                    const Divider(height: 20),
                    ExitSummaryRow(
                      label: 'Pérdida valorizada',
                      value: 'S/ ${widget.totalLoss.toStringAsFixed(2)}',
                      emphasize: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Esto descontará el stock del inventario físico.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text(
                'Para autorizar, escribe CONFIRMAR:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged:
                    (v) => setState(
                      () => _valid = v.trim().toUpperCase() == 'CONFIRMAR',
                    ),
                decoration: InputDecoration(
                  hintText: 'CONFIRMAR',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: _valid ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Autorizar salida',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class ExitSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const ExitSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 18 : 13,
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              color: emphasize ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
