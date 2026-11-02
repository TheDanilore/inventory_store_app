import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_cubit.dart';

/// Chip interactivo para un valor de atributo. Permite visualización y eliminación rápida.
class AttributeValueChip extends StatefulWidget {
  final AttributeValueEntity value;
  final String attributeName;
  final bool isSearchMatch;

  const AttributeValueChip({
    super.key,
    required this.value,
    required this.attributeName,
    this.isSearchMatch = false,
  });

  @override
  State<AttributeValueChip> createState() => _AttributeValueChipState();
}

class _AttributeValueChipState extends State<AttributeValueChip> {
  bool _isDeleting = false;
  bool _isHovered = false;

  Future<void> _handleDelete() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar Valor',
      message:
          '¿Estás seguro de eliminar el valor "${widget.value.value}" de ${widget.attributeName}?',
      confirmText: 'Eliminar',
      confirmColor: AppColors.error,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final cubit = context.read<AttributesCubit>();
    final success = await cubit.deleteAttributeValue(widget.value.id);
    if (mounted) {
      if (success) {
        AppSnackbar.show(
          context,
          message: 'Valor eliminado',
          type: SnackbarType.success,
        );
      }
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              widget.isSearchMatch
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : (_isHovered
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : AppColors.background),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                widget.isSearchMatch
                    ? AppColors.primary
                    : (_isHovered
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.border),
            width: widget.isSearchMatch ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.value.value,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    widget.isSearchMatch ? FontWeight.bold : FontWeight.w500,
                color:
                    widget.isSearchMatch
                        ? AppColors.primary
                        : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _isDeleting ? null : _handleDelete,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child:
                    _isDeleting
                        ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textSecondary,
                          ),
                        )
                        : const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón para agregar un valor nuevo a la lista de valores de un atributo.
class AddValueChipButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const AddValueChipButton({super.key, required this.onTap, this.onLongPress});

  @override
  State<AddValueChipButton> createState() => _AddValueChipButtonState();
}

class _AddValueChipButtonState extends State<AddValueChipButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message:
            'Añadir valor rápido (Clic) / Diálogo múltiple (Mantener presionado)',
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  _isHovered
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(
                  alpha: _isHovered ? 0.4 : 0.2,
                ),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 15, color: AppColors.primary),
                SizedBox(width: 4),
                Text(
                  'Añadir valor',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
