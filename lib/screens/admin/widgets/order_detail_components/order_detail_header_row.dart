import 'package:flutter/material.dart';

class OrderDetailHeaderRow extends StatelessWidget {
  final String orderId;
  final bool isCompleted;
  final bool isEditing;
  final bool canToggleEdit;
  final VoidCallback onToggleEditing;
  final VoidCallback onPrint;
  final VoidCallback onShare;

  const OrderDetailHeaderRow({
    super.key,
    required this.orderId,
    required this.isCompleted,
    required this.isEditing,
    this.canToggleEdit = true,
    required this.onToggleEditing,
    required this.onPrint,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detalle del Pedido',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              SelectableText(
                'ID: $orderId',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.blueGrey),
              onPressed: onPrint,
              tooltip: 'Imprimir Ticket',
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.blueGrey),
              onPressed: onShare,
              tooltip: 'Compartir Ticket',
            ),
            if (canToggleEdit)
              IconButton(
                icon: Icon(isEditing ? Icons.close : Icons.edit),
                onPressed: onToggleEditing,
                tooltip: isEditing ? 'Cancelar edición' : 'Editar pedido',
              ),
          ],
        ),
      ],
    );
  }
}
