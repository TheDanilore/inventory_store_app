import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';

class CategoryDesktopRow extends StatefulWidget {
  final CategoryEntity category;
  final Color catColor;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const CategoryDesktopRow({
    super.key,
    required this.category,
    required this.catColor,
    this.isSelected = false,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  State<CategoryDesktopRow> createState() => _CategoryDesktopRowState();
}

class _CategoryDesktopRowState extends State<CategoryDesktopRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final color = widget.catColor;
    final selected = widget.isSelected;
    final hovered = _isHovered;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onEdit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            height: 64,
            decoration: BoxDecoration(
              color:
                  selected
                      ? color.withValues(alpha: 0.06)
                      : hovered
                      ? AppColors.background
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    selected ? color.withValues(alpha: 0.35) : AppColors.border,
                width: selected ? 1.5 : 1.0,
              ),
              boxShadow:
                  hovered || selected
                      ? AppColors.cardShadow(opacity: 0.04)
                      : null,
            ),
            child: Row(
              children: [
                // Selected accent bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: selected ? 4 : 0,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),

                // Color icon
                Padding(
                  padding: EdgeInsets.only(left: selected ? 12 : 14, right: 12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.style_rounded, color: color, size: 18),
                  ),
                ),

                // Nombre + descripción
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: selected ? color : AppColors.textPrimary,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat.description?.isNotEmpty == true
                            ? cat.description!
                            : 'Sin descripción',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              cat.description?.isNotEmpty == true
                                  ? AppColors.textSecondary
                                  : AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Productos count badge
                if (cat.productsCount != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${cat.productsCount} prod.',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                // Status Badge
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          cat.isActive
                              ? AppColors.teal.withValues(alpha: 0.1)
                              : AppColors.textMuted.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cat.isActive ? 'Activo' : 'Inactivo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            cat.isActive ? AppColors.teal : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),

                // Acciones
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: hovered || selected ? 1.0 : 0.3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Editar categoría',
                          child: _RowIconBtn(
                            icon: Icons.edit_outlined,
                            color: AppColors.textSecondary,
                            onTap: widget.onEdit,
                          ),
                        ),
                        Tooltip(
                          message: 'Eliminar categoría',
                          child: _RowIconBtn(
                            icon: Icons.delete_outline_rounded,
                            color: AppColors.error,
                            onTap: widget.onDelete,
                          ),
                        ),
                        Semantics(
                          label: 'Estado de ${cat.name}',
                          child: Switch(
                            value: cat.isActive,
                            onChanged: widget.onToggle,
                            activeThumbColor: AppColors.teal,
                            activeTrackColor: AppColors.teal.withValues(
                              alpha: 0.35,
                            ),
                            inactiveThumbColor: AppColors.textMuted,
                            inactiveTrackColor: AppColors.border,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
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

class _RowIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RowIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        icon: Icon(icon, color: color, size: 19),
        onPressed: () {
          AppFeedbackService.selectionClick();
          onTap();
        },
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        splashRadius: 20,
      ),
    );
  }
}
