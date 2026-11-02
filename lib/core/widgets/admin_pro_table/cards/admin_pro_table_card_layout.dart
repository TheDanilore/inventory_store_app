import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/footer/admin_pro_table_footer.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/models/admin_table_pagination_config.dart';

/// Disposición camaleónica de tarjetas táctiles para móvil o cuadrícula de cards en tablet/desktop.
class AdminProTableCardLayout<T> extends StatelessWidget {
  final List<T> items;
  final Set<Object> selectedIds;
  final Object Function(T item) itemId;
  final Widget Function(
    BuildContext context,
    T item,
    bool isSelected,
    ValueChanged<bool> onSelect,
  )
  mobileCardBuilder;
  final AdminTablePaginationConfig? paginationConfig;
  final bool isMobile;
  final bool isMultiSelectEnabled;
  final ValueChanged<bool> onToggleSelectAll;
  final void Function(Object id, bool isSelected) onToggleSelectItem;
  final VoidCallback onClearSelection;
  final EdgeInsetsGeometry margin;
  final double cardMinWidth;

  const AdminProTableCardLayout({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.itemId,
    required this.mobileCardBuilder,
    required this.paginationConfig,
    required this.isMobile,
    required this.isMultiSelectEnabled,
    required this.onToggleSelectAll,
    required this.onToggleSelectItem,
    required this.onClearSelection,
    required this.margin,
    required this.cardMinWidth,
  });

  Widget _buildCard(BuildContext context, T item) {
    final id = itemId(item);
    return mobileCardBuilder(
      context,
      item,
      selectedIds.contains(id),
      (val) => onToggleSelectItem(id, val),
    );
  }

  Widget _buildCardGrid(BuildContext context) {
    const gap = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / cardMinWidth).floor().clamp(1, 4);
        final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: 0,
          children: [
            for (final item in items)
              SizedBox(width: itemWidth, child: _buildCard(context, item)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        items.isNotEmpty && items.every((e) => selectedIds.contains(itemId(e)));

    return Padding(
      padding: margin,
      child: Column(
        children: [
          // Selector de todos en móvil si hay selección activa
          if (isMultiSelectEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) => onToggleSelectAll(val ?? true),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Seleccionar todos',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (selectedIds.isNotEmpty)
                    TextButton(
                      onPressed: onClearSelection,
                      child: const Text('Limpiar selección'),
                    ),
                ],
              ),
            ),

          // Lista vertical (móvil) o cuadrícula (desktop/tablet)
          if (isMobile)
            for (final item in items) ...[
              _buildCard(context, item),
              const SizedBox(height: 10),
            ]
          else
            _buildCardGrid(context),

          // Footer de paginación
          if (paginationConfig != null) ...[
            const SizedBox(height: 8),
            AdminProTableMobileFooter(
              config: paginationConfig!,
              isCompact: isMobile,
            ),
          ],
        ],
      ),
    );
  }
}
