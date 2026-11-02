import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/ingredients/ingredients_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/ingredients/ingredients_state.dart';

/// Slide-Over Drawer lateral estilo Linear/Stripe para Desktop y Tablet.
///
/// Permite crear o editar un componente químico activo sin perder el contexto visual.
class SlideOverIngredientDrawer extends StatefulWidget {
  final String? ingredientId;
  final String? ingredientName;

  const SlideOverIngredientDrawer({
    super.key,
    this.ingredientId,
    this.ingredientName,
  });

  static Future<bool?> show({
    required BuildContext context,
    String? ingredientId,
    String? ingredientName,
  }) {
    final cubit = context.read<IngredientsCubit>();
    return showGeneralDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Cerrar panel',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim1, anim2) {
        return BlocProvider.value(
          value: cubit,
          child: Align(
            alignment: Alignment.centerRight,
            child: SlideOverIngredientDrawer(
              ingredientId: ingredientId,
              ingredientName: ingredientName,
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curvedAnim = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnim),
          child: child,
        );
      },
    );
  }

  @override
  State<SlideOverIngredientDrawer> createState() =>
      _SlideOverIngredientDrawerState();
}

class _SlideOverIngredientDrawerState extends State<SlideOverIngredientDrawer> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  final TextEditingController _descCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.ingredientName ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'El nombre del componente es requerido.',
        type: SnackbarType.warning,
      );
      return;
    }

    final cubit = context.read<IngredientsCubit>();
    final success = await cubit.saveIngredient(name, id: widget.ingredientId);

    if (mounted) {
      if (success) {
        AppSnackbar.show(
          context,
          message:
              widget.ingredientId == null
                  ? 'Componente "$name" creado correctamente.'
                  : 'Componente actualizado correctamente.',
          type: SnackbarType.success,
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop(false);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _handleSave();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.ingredientId != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final panelWidth = width < 500 ? width * 0.95 : 440.0;

    return Focus(
      onKeyEvent: _handleKey,
      child: Material(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 16,
        child: Container(
          width: panelWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            border: Border(
              left: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera del Slide-Over
              Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 16, 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.divider,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.tealDark.withValues(alpha: 0.3)
                                : AppColors.tealLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.science_rounded,
                        color:
                            isDark
                                ? const Color(0xFF2DD4BF)
                                : AppColors.tealDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Editar Componente'
                                : 'Nuevo Componente Químico',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? const Color(0xFFF8FAFC)
                                      : AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEditing
                                ? 'Modifica los datos del principio activo.'
                                : 'Registra un nuevo principio activo para el catálogo.',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : AppColors.textSecondary,
                      tooltip: 'Cerrar (Esc)',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),

              // Formulario interno
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _nameCtrl,
                          focusNode: _focusNode,
                          label: 'Nombre del Componente *',
                          icon: Icons.label_outlined,
                          hintText: 'Ej: Sulfato de Cobre, Paracetamol...',
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 18),
                        AppTextField(
                          controller: _descCtrl,
                          label: 'Descripción o Notas Técnicas (Opcional)',
                          icon: Icons.notes_rounded,
                          hintText:
                              'Ej: Fungicida cúprico preventivo de amplio espectro...',
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 24),

                        // Callout informativo de buenas prácticas
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? const Color(
                                      0xFF134E4A,
                                    ).withValues(alpha: 0.25)
                                    : const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isDark
                                      ? const Color(0xFF134E4A)
                                      : const Color(0xFFCCFBF1),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 18,
                                color:
                                    isDark
                                        ? const Color(0xFF2DD4BF)
                                        : AppColors.tealDark,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Los componentes químicos activos se asignan a las fichas técnicas de productos y permiten filtrados agronómicos o farmacológicos avanzados en el punto de venta.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isDark
                                            ? const Color(0xFF5EEAD4)
                                            : AppColors.tealDark,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Barra de botones inferior
              BlocSelector<IngredientsCubit, IngredientsState, bool>(
                selector: (state) => state.isSaving,
                builder: (context, isSaving) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surface,
                      border: Border(
                        top: BorderSide(
                          color:
                              isDark ? AppColors.darkBorder : AppColors.divider,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isSaving
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : AppColors.textSecondary,
                              side: BorderSide(
                                color:
                                    isDark
                                        ? AppColors.darkBorder
                                        : AppColors.border,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancelar (Esc)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child:
                                isSaving
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Text(
                                      isEditing
                                          ? 'Guardar Cambios'
                                          : 'Crear Componente',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
