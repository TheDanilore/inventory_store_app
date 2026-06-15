import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class PosConfirmationDialog extends StatelessWidget {
  final double totalFinal;
  final String? clienteName;
  final String paymentMethod;
  final VoidCallback onConfirm;

  const PosConfirmationDialog({
    super.key,
    required this.totalFinal,
    this.clienteName,
    required this.paymentMethod,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar Venta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Estás seguro de procesar esta venta?'),
          const SizedBox(height: 16),
          _Row('Cliente:', clienteName ?? 'Público General'),
          _Row('Método:', paymentMethod),
          const Divider(),
          _Row('Total:', 'S/ ${totalFinal.toStringAsFixed(2)}', isTotal: true),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, true);
            onConfirm();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
          child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class PosSuccessDialog extends StatelessWidget {
  final bool isDraft;
  final VoidCallback onPrint;

  const PosSuccessDialog({
    super.key,
    required this.isDraft,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isDraft ? Icons.save_rounded : Icons.check_circle_rounded,
            color: AppColors.teal,
          ),
          const SizedBox(width: 8),
          Text(isDraft ? 'Borrador Guardado' : 'Venta Exitosa'),
        ],
      ),
      content: Text(
        isDraft
            ? 'El borrador se guardó correctamente.'
            : 'La venta se ha procesado con éxito.',
      ),
      actions: [
        if (!isDraft)
          OutlinedButton.icon(
            onPressed: () {
              onPrint();
            },
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Imprimir Comprobante'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.teal,
            ),
          ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
          child: const Text('Nueva Venta', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _Row(this.label, this.value, {this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: AppColors.textMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
