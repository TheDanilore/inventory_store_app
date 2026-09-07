import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_state.dart';

/// Formulario adaptativo de Atributo:
/// - Desktop / Tablet (>= 720px): Slide-Over Drawer lateral derecho (Stripe / Linear style).
/// - Mobile (< 720px): Modal BottomSheet elástico con esquinas redondeadas (Apple HIG style).
class AttributeFormSheet extends StatefulWidget {
  final AttributeEntity? attribute;
  final bool isSlideOver;

  const AttributeFormSheet({
    super.key,
    this.attribute,
    this.isSlideOver = false,
  });

  /// Muestra el formulario adaptándose de forma automática al tamaño de pantalla.
  static Future<void> showAdaptive(
    BuildContext context, {
    AttributeEntity? attribute,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cubit = context.read<AttributesCubit>();

    if (screenWidth >= 720) {
      return showGeneralDialog(
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
                  child: AttributeFormSheet(
                    attribute: attribute,
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
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => BlocProvider.value(
          value: cubit,
          child: AttributeFormSheet(
            attribute: attribute,
            isSlideOver: false,
          ),
        ),
      );
    }
  }

  @override
  State<AttributeFormSheet> createState() => _AttributeFormSheetState();
}

class _AttributeFormSheetState extends State<AttributeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  final FocusNode _nameFocusNode = FocusNode();

  String _previewName = '';

  @override
  void initState() {
    super.initState();
    _previewName = widget.attribute?.name ?? '';
    _nameCtrl = TextEditingController(text: widget.attribute?.name ?? '');
    _descCtrl = TextEditingController(
      text: widget.attribute?.description ?? '',
    );
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

    final cubit = context.read<AttributesCubit>();
    final success = await cubit.saveAttribute(
      _nameCtrl.text.trim(),
      id: widget.attribute?.id,
      description: _descCtrl.text.trim(),
    );

    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  IconData _getIconForName(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('talla') || lower.contains('tamaño') || lower.contains('size')) {
      return Icons.straighten_rounded;
    }
    if (lower.contains('color')) return Icons.palette_outlined;
    if (lower.contains('presentacion') ||
        lower.contains('presentación') ||
        lower.contains('unidad')) {
      return Icons.inventory_2_outlined;
    }
    if (lower.contains('modelo') || lower.contains('model')) {
      return Icons.layers_outlined;
    }
    if (lower.contains('material') || lower.contains('tela')) {
      return Icons.texture_rounded;
    }
    if (lower.contains('marca') || lower.contains('brand')) {
      return Icons.verified_outlined;
    }
    if (lower.contains('peso') ||
        lower.contains('capacidad') ||
        lower.contains('volumen')) {
      return Icons.scale_outlined;
    }
    return Icons.category_outlined;
  }

  Color _getColorForName(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('talla')) return const Color(0xFF10B981);
    if (lower.contains('color')) return const Color(0xFF8B5CF6);
    if (lower.contains('presentacion') || lower.contains('presentación')) {
      return const Color(0xFF0EA5E9);
    }
    if (lower.contains('modelo')) return const Color(0xFFF59E0B);
    if (lower.contains('material')) return const Color(0xFFEC4899);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.attribute != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final themeColor = _getColorForName(_previewName);
    final themeIcon = _getIconForName(_previewName);

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
                      isEditing ? 'Editar Propiedad' : 'Nueva Propiedad',
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
                          ? 'Modifica los datos de la propiedad'
                          : 'Crea una propiedad para variantes de producto',
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
                onPressed: () => Navigator.of(context).pop(),
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
              labelText: 'Nombre de la propiedad *',
              hintText: 'Ej: Talla, Color, Presentación, Modelo...',
              prefixIcon: const Icon(Icons.label_outlined, size: 18),
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
                    ? 'El nombre es requerido'
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
              hintText: 'Ej: Define las medidas físicas del artículo...',
              prefixIcon: const Icon(Icons.notes_rounded, size: 18),
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
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(themeIcon, color: themeColor, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _previewName.isEmpty ? 'Nombre de la propiedad' : _previewName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _previewName.isEmpty
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        '0 valores',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Botones de Acción
          BlocSelector<AttributesCubit, AttributesState, bool>(
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
                      onPressed: isSaving ? null : () => Navigator.of(context).pop(),
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
                              isEditing ? 'Guardar Cambios' : 'Crear Propiedad',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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

    // En Desktop / SlideOver:
    if (widget.isSlideOver) {
      return KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: formContent,
        ),
      );
    }

    // En Mobile BottomSheet:
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: bottomInset + 20,
        left: 20,
        right: 20,
        top: 12,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
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
          Expanded(child: formContent),
        ],
      ),
    );
  }
}
