import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:inventory_store_app/features/catalog/presentation/bloc/categories_cubit.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/categories_state.dart';

class CategoryFormSheet extends StatefulWidget {
  final CategoryEntity? category;

  const CategoryFormSheet({super.key, this.category});

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
    _descCtrl = TextEditingController(text: widget.category?.description ?? '');
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<CategoriesCubit>();
    final success = await cubit.saveCategory(
      existingCategory: widget.category,
      name: _nameCtrl.text,
      description: _descCtrl.text,
      isActive: _isActive,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.category != null;
    final cubit = context.read<CategoriesCubit>();
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Material(
      color: Colors.white,
      borderRadius:
          isTablet
              ? BorderRadius.circular(24)
              : const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle (solo visible en bottom sheet / móvil)
                if (!isTablet)
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                Text(
                  isEditing ? 'Editar Categoría' : 'Nueva Categoría',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                AppTextField(
                  controller: _nameCtrl,
                  label: 'Nombre de la categoría',
                  icon: Icons.category_outlined,
                  hintText: 'Ej. Electrónica, Ropa...',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator:
                      (val) =>
                          val == null || val.trim().isEmpty
                              ? 'El nombre es requerido'
                              : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _descCtrl,
                  label: 'Descripción (Opcional)',
                  icon: Icons.description_outlined,
                  hintText:
                      'Breve descripción de los productos en esta categoría...',
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),

                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(
                    'Estado',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'La categoría estará visible en el sistema'
                        : 'La categoría estará oculta',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: _isActive,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(
                    alpha: 0.4,
                  ), // Fix de activeTrackColor
                  contentPadding: EdgeInsets.zero,
                  onChanged:
                      cubit.state.isSaving
                          ? null
                          : (val) => setState(() => _isActive = val),
                ),

                const SizedBox(height: 24),
                BlocBuilder<CategoriesCubit, CategoriesState>(
                  builder: (context, state) {
                    return SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: state.isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child:
                            state.isSaving
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  'Guardar Categoría',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
