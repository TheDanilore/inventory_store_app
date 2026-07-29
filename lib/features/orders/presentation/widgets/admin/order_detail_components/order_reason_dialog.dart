import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class OrderReasonDialog extends StatefulWidget {
  final String title;
  final String hint;

  const OrderReasonDialog({super.key, required this.title, required this.hint});

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String hint,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => OrderReasonDialog(title: title, hint: hint),
    );
  }

  @override
  State<OrderReasonDialog> createState() => _OrderReasonDialogState();
}

class _OrderReasonDialogState extends State<OrderReasonDialog> {
  String _notes = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.hint, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Ej. Producto dañado, cliente cambió de opinión...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _notes = val;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _notes),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
          ),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
