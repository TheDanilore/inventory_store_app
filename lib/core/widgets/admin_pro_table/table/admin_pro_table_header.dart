import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/models/admin_table_column.dart';

const double kAdminTableRowHPad = 14.0;
const double kAdminTableCellGutter = 8.0;

/// Cabecera de la tabla Pro con checkbox master de selección y ordenamiento interactivo por columna.
class AdminProTableHeader<T> extends StatelessWidget {
  final List<AdminTableColumn<T>> columns;
  final bool isMultiSelectEnabled;
  final bool allSelected;
  final bool someSelected;
  final ValueChanged<bool> onToggleSelectAll;
  final String? sortColumnId;
  final bool isSortAscending;
  final void Function(String columnId, bool isAscending)? onSort;
  final double rowVerticalPadding;

  const AdminProTableHeader({
    super.key,
    required this.columns,
    required this.isMultiSelectEnabled,
    required this.allSelected,
    required this.someSelected,
    required this.onToggleSelectAll,
    required this.sortColumnId,
    required this.isSortAscending,
    required this.onSort,
    required this.rowVerticalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kAdminTableRowHPad,
        vertical: rowVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Checkbox Master de Selección Total
          if (isMultiSelectEnabled) ...[
            SizedBox(
              width: 32,
              child: Checkbox(
                value: allSelected ? true : (someSelected ? null : false),
                tristate: true,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
                onChanged: (val) => onToggleSelectAll(val ?? true),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Columnas declarativas
          for (final col in columns) _buildHeaderCell(context, col, isDark),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    BuildContext context,
    AdminTableColumn<T> col,
    bool isDark,
  ) {
    final isSorted = sortColumnId == col.id;
    final isSortable = col.isSortable && onSort != null;

    final cellContent = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child:
              col.headerWidget ??
              Text(
                col.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      isSorted
                          ? (isDark
                              ? const Color(0xFF60A5FA)
                              : AppColors.primary)
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF64748B)),
                  letterSpacing: 0.6,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        ),
        if (isSortable) ...[
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: isSorted && !isSortAscending ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSorted ? Icons.arrow_upward_rounded : Icons.unfold_more_rounded,
              size: 14,
              color:
                  isSorted
                      ? (isDark ? const Color(0xFF60A5FA) : AppColors.primary)
                      : (isDark
                          ? AppColors.darkTextMuted
                          : const Color(0xFF94A3B8)),
            ),
          ),
        ],
      ],
    );

    Widget wrappedCell = Align(
      alignment: col.alignment,
      child:
          isSortable
              ? MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    final nextAsc = isSorted ? !isSortAscending : true;
                    onSort?.call(col.id, nextAsc);
                  },
                  child: cellContent,
                ),
              )
              : cellContent,
    );

    if (col.tooltip != null) {
      wrappedCell = Tooltip(
        message: col.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: wrappedCell,
      );
    }

    wrappedCell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: kAdminTableCellGutter),
      child: wrappedCell,
    );

    if (col.fixedWidth != null) {
      return SizedBox(width: col.fixedWidth, child: wrappedCell);
    }

    return Expanded(flex: col.flex, child: wrappedCell);
  }
}
