import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_state.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _valueCtrl = TextEditingController();

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<AttributesCubit>();
    final success = await cubit.saveAttributeValue(
      widget.attributeId,
      _valueCtrl.text.trim(),
    );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Añadir valor a ${widget.attributeName}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _valueCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej: Rojo, XL, Madera...'),
          validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa un valor' : null,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        BlocSelector<AttributesCubit, AttributesState, bool>(
          selector: (state) => state.isSaving,
          builder: (context, isSaving) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
          },
        ),
      ],
    );
  }
}
