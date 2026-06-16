import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/providers/admin/categories_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class CategoryFormSheet extends StatefulWidget {
  final CategoryModel? category;

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

    final provider = context.read<CategoriesProvider>();
    final success = await provider.saveCategory(
      context,
      existingCategory: widget.category,
      name: _nameCtrl.text,
      description: _descCtrl.text,
      isActive: _isActive,
    );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.category != null;
    final provider = context.watch<CategoriesProvider>();

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              const Text(
                'Nombre de la categoría',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Ej. Electrónica, Ropa...',
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator:
                    (val) =>
                        val == null || val.trim().isEmpty
                            ? 'El nombre es requerido'
                            : null,
              ),

              const SizedBox(height: 16),
              const Text(
                'Descripción (Opcional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Breve descripción de los productos en esta categoría...',
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  'Estado',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _isActive
                      ? 'La categoría estará visible en el sistema'
                      : 'La categoría estará oculta',
                  style: const TextStyle(fontSize: 12),
                ),
                value: _isActive,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged:
                    provider.isSaving
                        ? null
                        : (val) => setState(() => _isActive = val),
              ),

              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: provider.isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child:
                      provider.isSaving
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
