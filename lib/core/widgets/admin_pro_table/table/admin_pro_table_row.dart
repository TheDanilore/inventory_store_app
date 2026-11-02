import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/models/admin_table_column.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/table/admin_pro_table_header.dart';

/// Fila individual de tabla Pro de alta densidad.
/// Encapsula de forma atómica su propio estado de hover, evitando que el movimiento
/// del mouse dispare reconstrucciones globales de toda la tabla.
class AdminProTableRow<T> extends StatefulWidget {
  final T item;
  final int index;
  final Object itemId;
  final bool isSelected;
  final bool isFocused;
  final bool isMultiSelectEnabled;
  final double rowVerticalPadding;
  final List<AdminTableColumn<T>> columns;
  final ValueChanged<T>? onRowTap;
  final void Function(Object id, bool isSelected) onToggleSelect;
  final VoidCallback? onRowFocused;

  const AdminProTableRow({
    super.key,
    required this.item,
    required this.index,
    required this.itemId,
    required this.isSelected,
    required this.isFocused,
    required this.isMultiSelectEnabled,
    required this.rowVerticalPadding,
    required this.columns,
    this.onRowTap,
    required this.onToggleSelect,
    this.onRowFocused,
  });

  @override
  State<AdminProTableRow<T>> createState() => _AdminProTableRowState<T>();
}

class _AdminProTableRowState<T> extends State<AdminProTableRow<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHighlighted = _isHovered || widget.isFocused;

    final rowColor =
        widget.isSelected
            ? (isDark
                ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                : AppColors.primary.withValues(alpha: 0.06))
            : (isHighlighted
                ? (isDark
                    ? AppColors.darkSurfaceHighlight
                    : const Color(0xFFF1F5F9))
                : (isDark ? AppColors.darkSurface : Colors.white));

    final rowShadow =
        isHighlighted && !widget.isSelected
            ? [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF0F172A))
                    .withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ]
            : const <BoxShadow>[];

    return MouseRegion(
      cursor:
          widget.onRowTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
      onEnter: (_) {
        if (!_isHovered) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isHovered) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: () {
          widget.onRowFocused?.call();
          widget.onRowTap?.call(widget.item);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          padding: EdgeInsets.symmetric(
            horizontal: kAdminTableRowHPad,
            vertical: widget.rowVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: rowColor,
            boxShadow: rowShadow,
            border:
                widget.isSelected
                    ? Border(
                      left: BorderSide(
                        color:
                            isDark
                                ? const Color(0xFF3B82F6)
                                : AppColors.primary,
                        width: 3.5,
                      ),
                    )
                    : widget.isFocused && !widget.isSelected
                    ? Border(
                      left: BorderSide(
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF94A3B8),
                        width: 2,
                      ),
                    )
                    : null,
          ),
          child: Row(
            children: [
              // Checkbox de Fila
              if (widget.isMultiSelectEnabled) ...[
                SizedBox(
                  width: 32,
                  child: Checkbox(
                    value: widget.isSelected,
                    activeColor:
                        isDark ? const Color(0xFF3B82F6) : AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: BorderSide(
                      color:
                          isDark
                              ? AppColors.darkBorderSubtle
                              : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                    onChanged:
                        (val) =>
                            widget.onToggleSelect(widget.itemId, val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Celdas de Datos
              for (final col in widget.columns)
                _buildDataCell(context, col, widget.item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(BuildContext context, AdminTableColumn<T> col, T item) {
    final cellWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: kAdminTableCellGutter),
      child: Align(
        alignment: col.alignment,
        child: col.cellBuilder(context, item),
      ),
    );

    if (col.fixedWidth != null) {
      return SizedBox(width: col.fixedWidth, child: cellWidget);
    }

    return Expanded(flex: col.flex, child: cellWidget);
  }
}

