import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class OrderQuantityEditDialog extends StatefulWidget {
  final String initialQty;

  const OrderQuantityEditDialog({super.key, required this.initialQty});

  static Future<String?> show(BuildContext context, String initialQty) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => OrderQuantityEditDialog(initialQty: initialQty),
    );
  }

  @override
  State<OrderQuantityEditDialog> createState() =>
      _OrderQuantityEditDialogState();
}

class _OrderQuantityEditDialogState extends State<OrderQuantityEditDialog> {
  late final TextEditingController _dlgCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _dlgCtrl = TextEditingController(text: widget.initialQty);
  }

  @override
  void dispose() {
    _dlgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Modificar Cantidad',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _dlgCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ingresa la cantidad',
            labelText: 'Cantidad',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Requerido';
            final val = int.tryParse(value.trim());
            if (val == null || val <= 0) return 'Debe ser mayor a 0';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, _dlgCtrl.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
