import 'package:flutter/material.dart';

/// Diálogo que muestra los productos con stock insuficiente al intentar
/// procesar el pedido. Se extrae del widget padre para mantener la pantalla limpia.
class CartStockErrorDialog extends StatelessWidget {
  final List<String> messages;

  const CartStockErrorDialog({super.key, required this.messages});

  static Future<void> show(
    BuildContext context, {
    required List<String> messages,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => CartStockErrorDialog(messages: messages),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Stock Insuficiente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lo sentimos, el stock ha variado y algunos productos ya no están '
            'disponibles en las cantidades solicitadas:',
          ),
          const SizedBox(height: 12),
          ...messages.map(
            (msg) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                msg,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
