import 'package:flutter/material.dart';

class OrderReturnConfirmDialog extends StatelessWidget {
  const OrderReturnConfirmDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => const OrderReturnConfirmDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.assignment_return_rounded, color: Colors.red.shade600),
          const SizedBox(width: 8),
          const Text(
            'Confirmar Devolución',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: const Text(
        'Esta acción cancelará el pedido y revertirá todos los movimientos asociados:\n\n'
        '• Stock de productos devuelto al almacén\n'
        '• Monedas de fidelidad revertidas\n'
        '• Deuda de crédito o cuenta ajustada\n\n'
        '¿Deseas continuar?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.assignment_return_rounded, size: 18),
          label: const Text('Confirmar'),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}
