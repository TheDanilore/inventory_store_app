import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Diálogo desacoplado para editar el método de pago acordado de una orden.
class POEditPaymentMethodDialog extends StatefulWidget {
  final String initialMethod;

  const POEditPaymentMethodDialog({super.key, required this.initialMethod});

  static Future<String?> show(
    BuildContext context, {
    required String currentMethod,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => POEditPaymentMethodDialog(initialMethod: currentMethod),
    );
  }

  @override
  State<POEditPaymentMethodDialog> createState() =>
      _POEditPaymentMethodDialogState();
}

class _POEditPaymentMethodDialogState extends State<POEditPaymentMethodDialog> {
  late String _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialMethod;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.edit_outlined, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            'Editar Método de Pago',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seleccione la nueva forma de pago acordada:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedMethod,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
              DropdownMenuItem(
                value: 'TARJETA',
                child: Text('Tarjeta / Transferencia'),
              ),
              DropdownMenuItem(
                value: 'CRÉDITO',
                child: Text('Línea de Crédito'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedMethod = val);
              }
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.pop(context, _selectedMethod),
          child: const Text('Guardar Cambios'),
        ),
      ],
    );
  }
}
