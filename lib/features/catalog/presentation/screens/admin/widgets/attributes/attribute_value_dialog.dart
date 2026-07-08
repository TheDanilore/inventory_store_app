import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/catalog/presentation/providers/attributes_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class AttributeValueDialog extends StatefulWidget {
  final String attributeId;
  final String attributeName;

  const AttributeValueDialog({
    super.key,
    required this.attributeId,
    required this.attributeName,
  });

  @override
  State<AttributeValueDialog> createState() => _AttributeValueDialogState();
}

class _AttributeValueDialogState extends State<AttributeValueDialog> {
  final _valueCtrl = TextEditingController();

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_valueCtrl.text.trim().isEmpty) return;
    
    final provider = context.read<AttributesProvider>();
    final success = await provider.saveAttributeValue(
      context,
      attributeId: widget.attributeId,
      value: _valueCtrl.text,
    );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttributesProvider>();

    return AlertDialog(
      title: Text('Añadir valor a ${widget.attributeName}'),
      content: TextField(
        controller: _valueCtrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Ej: Rojo, XL, Madera...',
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: provider.isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: provider.isSaving ? null : _save,
          child: provider.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Añadir'),
        ),
      ],
    );
  }
}
