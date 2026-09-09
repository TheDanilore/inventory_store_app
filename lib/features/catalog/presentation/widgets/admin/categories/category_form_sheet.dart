import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:inventory_store_app/features/catalog/presentation/bloc/categories/categories_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/categories/categories_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

/// Formulario adaptativo de Categoría:
/// - Desktop / Tablet (>= 720px): Slide-Over Drawer lateral derecho (Stripe / Linear style).
/// - Mobile (< 720px): Modal BottomSheet elástico con esquinas redondeadas (Apple HIG style).
class CategoryFormSheet extends StatefulWidget {
  final CategoryEntity? category;
  final bool isSlideOver;

  const CategoryFormSheet({
    super.key,
    this.category,
    this.isSlideOver = false,
  });

  /// Muestra el formulario adaptándose de forma automática al tamaño de pantalla.
  static Future<bool?> showAdaptive(
    BuildContext context, {
    CategoryEntity? category,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cubit = context.read<CategoriesCubit>();

    if (screenWidth >= 720) {
      return showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Cerrar',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (dialogContext, anim1, anim2) {
          return BlocProvider.value(
            value: cubit,
            child: Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 440,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 32,
                        offset: const Offset(-8, 0),
                      ),
                    ],
                  ),
                  child: CategoryFormSheet(
                    category: category,
                    isSlideOver: true,
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, anim1, anim2, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: anim1,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          );
        },
      );
    } else {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => BlocProvider.value(
          value: cubit,
          child: CategoryFormSheet(
            category: category,
            isSlideOver: false,
          ),
        ),
      );
    }
  }

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  final FocusNode _nameFocusNode = FocusNode();
  bool _isActive = true;

  String _previewName = '';

  static const _categoryColors = [
    Color(0xFF6366F1), // indigo
    Color(0xFF0EA5E9), // sky
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEC4899), // pink
    Color(0xFF8B5CF6), // violet
  ];

  Color _getCategoryColor(String name) {
    if (name.isEmpty) return _categoryColors[0];
    return _categoryColors[name.hashCode.abs() % _categoryColors.length];
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('ropa') || lower.contains('textil') || lower.contains('prenda')) {
      return Icons.checkroom_rounded;
    }
    if (lower.contains('calzado') || lower.contains('zapato')) {
      return Icons.roller_skating_rounded;
    }
    if (lower.contains('insecticida') || lower.contains('plaga')) {
      return Icons.pest_control_rounded;
    }
    if (lower.contains('fertilizante') || lower.contains('abono') || lower.contains('agro')) {
      return Icons.grass_rounded;
    }
    if (lower.contains('quimico') || lower.contains('químico') || lower.contains('componente')) {
      return Icons.science_rounded;
    }
    if (lower.contains('herramienta') || lower.contains('ferreteria') || lower.contains('ferretería')) {
      return Icons.handyman_rounded;
    }
    if (lower.contains('electron') || lower.contains('electrón')) {
      return Icons.devices_other_rounded;
    }
    return Icons.category_rounded;
  }

  @override
  void initState() {
    super.initState();
    _previewName = widget.category?.name ?? '';
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
    _descCtrl = TextEditingController(text: widget.category?.description ?? '');
    _isActive = widget.category?.isActive ?? true;

    _nameCtrl.addListener(() {
      if (mounted) {
        setState(() => _previewName = _nameCtrl.text.trim());
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<CategoriesCubit>();
    final success = await cubit.saveCategory(
      existingCategory: widget.category,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      isActive: _isActive,
    );

    if (mounted) {
      if (success) {
        AppSnackbar.show(
          context,
          message: widget.category == null
              ? 'Categoría creada correctamente.'
              : 'Categoría actualizada correctamente.',
          type: SnackbarType.success,
        );
        Navigator.of(context).pop(true);
      } else if (cubit.state.errorMessage != null) {
        AppSnackbar.show(
          context,
          message: cubit.state.errorMessage!,
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final themeColor = _getCategoryColor(_previewName);
    final themeIcon = _getCategoryIcon(_previewName);

    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEditing ? Icons.edit_note_rounded : themeIcon,
                  color: themeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Editar Categoría' : 'Nueva Categoría',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEditing
                          ? 'Modifica los datos de la categoría.'
                          : 'Organiza tu catálogo con categorías claras.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Cerrar (Esc)',
                onPressed: () => Navigator.of(context).pop(false),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 20),

          // Campo Nombre
          TextFormField(
            controller: _nameCtrl,
            focusNode: _nameFocusNode,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Nombre de la categoría *',
              hintText: 'Ej: Fertilizantes, Ropa, Herramientas...',
              prefixIcon: const Icon(Icons.category_outlined, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: themeColor, width: 1.5),
              ),
            ),
            validator: (val) =>
                val == null || val.trim().isEmpty
                    ? 'El nombre es obligatorio'
                    : null,
            onFieldSubmitted: (_) => _save(),
          ),

          const SizedBox(height: 16),

          // Campo Descripción
          TextFormField(
            controller: _descCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Descripción (Opcional)',
              hintText: 'Breve descripción de los productos en esta categoría...',
              prefixIcon: const Icon(Icons.description_outlined, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Switch de Estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado de la categoría',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _isActive
                          ? 'Visible para selección en productos'
                          : 'Oculta en la asignación de catálogo',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isActive,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Previsualización en Vivo de la Tarjeta
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'VISTA PREVIA EN CATÁLOGO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(themeIcon, color: themeColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _previewName.isEmpty ? 'Nombre de la categoría' : _previewName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _previewName.isEmpty
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_descCtrl.text.isNotEmpty)
                            Text(
                              _descCtrl.text,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _isActive
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.textMuted.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isActive ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _isActive ? AppColors.success : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (widget.isSlideOver) const Spacer(),
          if (!widget.isSlideOver) const SizedBox(height: 24),

          // Botones de Acción
          BlocSelector<CategoriesCubit, CategoriesState, bool>(
            selector: (state) => state.isSaving,
            builder: (context, isSaving) {
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isSaving ? null : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isSaving ? null : _save,
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEditing ? 'Guardar Cambios' : 'Crear Categoría',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (widget.isSlideOver) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.of(context).pop(false);
          },
          const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: formContent,
        ),
      );
    }

    // Versión Mobile: Modal BottomSheet con esquinas superiores redondeadas y drag handle
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              formContent,
            ],
          ),
        ),
      ),
    );
  }
}
