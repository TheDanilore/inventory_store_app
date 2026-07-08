import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes_cubit.dart';
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

    final cubit = context.read<AttributesCubit>();
    final success = await cubit.saveAttributeValue(
      widget.attributeId,
      _valueCtrl.text,
    );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<AttributesCubit>().state.isSaving;

    return AlertDialog(
      title: Text('Añadir valor a ${widget.attributeName}'),
      content: TextField(
        controller: _valueCtrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Ej: Rojo, XL, Madera...'),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: isSaving ? null : _save,
          child:
              isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Añadir'),
        ),
      ],
    );
  }
}
