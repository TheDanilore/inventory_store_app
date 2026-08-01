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
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            controller: _controller,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Ej. Producto dañado, cliente cambió de opinión...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
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
