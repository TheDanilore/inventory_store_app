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

class PosSuccessDialog extends StatefulWidget {
  final bool isDraft;
  final Future<void> Function() onPrint;

  const PosSuccessDialog({
    super.key,
    required this.isDraft,
    required this.onPrint,
  });

  @override
  State<PosSuccessDialog> createState() => _PosSuccessDialogState();
}

class _PosSuccessDialogState extends State<PosSuccessDialog> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isDraft ? Icons.save_rounded : Icons.check_circle_rounded,
            color: AppColors.teal,
          ),
          const SizedBox(width: 8),
          Text(widget.isDraft ? 'Borrador Guardado' : 'Venta Exitosa'),
        ],
      ),
      content: Text(
        widget.isDraft
            ? 'El borrador se guardó correctamente.'
            : 'La venta se ha procesado con éxito.',
      ),
      actions: [
        if (!widget.isDraft)
          OutlinedButton.icon(
            onPressed: _isGenerating
                ? null
                : () async {
                    setState(() => _isGenerating = true);
                    try {
                      await widget.onPrint();
                    } finally {
                      if (mounted) setState(() => _isGenerating = false);
                    }
                  },
            icon: _isGenerating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_rounded, size: 18),
            label: Text(_isGenerating ? 'Generando...' : 'Generar Ticket'),
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
