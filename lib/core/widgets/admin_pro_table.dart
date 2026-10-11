import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';

/// Definición declarativa de una columna para [AdminProTable].
class AdminTableColumn<T> {
  final String id;
  final String label;
  final int flex;
  final double? fixedWidth;
  final AlignmentGeometry alignment;
  final bool isSortable;
  final bool isPriorityOnTablet;
  final Widget Function(BuildContext context, T item) cellBuilder;
  final Widget? headerWidget;
  final String? tooltip;

  const AdminTableColumn({
    required this.id,
    required this.label,
    this.flex = 1,
    this.fixedWidth,
    this.alignment = Alignment.centerLeft,
    this.isSortable = false,
    this.isPriorityOnTablet = true,
    required this.cellBuilder,
    this.headerWidget,
    this.tooltip,
  });
}

/// Acción por lote para la barra flotante de seleccionados.
class AdminBulkAction<T> {
  final String label;
  final IconData icon;
  final void Function(List<T> selectedItems) onPressed;
  final bool isDestructive;
  final Color? customColor;

  const AdminBulkAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
    this.customColor,
  });
}

/// Configuración de paginación para [AdminProTable].
class AdminTablePaginationConfig {
  final int currentPage; // 1-indexed
  final int pageSize;
  final int totalItems;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final List<int> pageSizeOptions;

  const AdminTablePaginationConfig({
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.pageSizeOptions = const [10, 25, 50, 100],
  });

  int get totalPages =>
      totalItems <= 0 ? 1 : (totalItems / pageSize).ceil().clamp(1, 999999);

  int get fromItem => totalItems == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;

  int get toItem =>
      ((currentPage - 1) * pageSize + pageSize).clamp(0, totalItems);

  bool get hasPrevious => currentPage > 1;
  bool get hasNext => currentPage < totalPages;
}

/// Componente de tabla ejecutiva reutilizable de nivel internacional (estilo Stripe / Linear).
///
/// Soporta:
/// - Selección múltiple con Checkboxes y [Floating Bulk Action Bar] animada.
/// - Paginación configurable con selector de ítems por página (10, 25, 50, 100).
/// - Ordenamiento interactivo por cabeceras de columnas (Sorting).
/// - Transición camaleónica: En móvil muta a tarjetas verticales táctiles ([mobileCardBuilder]),
///   y en Desktop ofrece alta densidad de información con cabecera fija y estados de hover.
class AdminProTable<T> extends StatefulWidget {
  final List<T> items;
  final List<AdminTableColumn<T>> columns;
  final Object Function(T item) itemId;

  // Selección múltiple
  final Set<Object> selectedIds;
  final ValueChanged<Set<Object>>? onSelectionChanged;
  final List<AdminBulkAction<T>> bulkActions;
  final bool enableMultiSelect;

  // Ordenamiento
  final String? sortColumnId;
  final bool isSortAscending;
  final void Function(String columnId, bool isAscending)? onSort;

  // Paginación
  final AdminTablePaginationConfig? paginationConfig;

  // Interacción
  final ValueChanged<T>? onRowTap;
  final bool isLoading;
  final Widget? emptyState;
  final double minTableWidth;
  final EdgeInsetsGeometry margin;

  // Camaleón Móvil
  final Widget Function(
    BuildContext context,
    T item,
    bool isSelected,
    ValueChanged<bool> onSelect,
  )?
  mobileCardBuilder;

  const AdminProTable({
    super.key,
    required this.items,
    required this.columns,
    required this.itemId,
    this.selectedIds = const {},
    this.onSelectionChanged,
    this.bulkActions = const [],
    this.enableMultiSelect = true,
    this.sortColumnId,
    this.isSortAscending = true,
    this.onSort,
    this.paginationConfig,
    this.onRowTap,
    this.isLoading = false,
    this.emptyState,
    this.minTableWidth = 880.0,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.mobileCardBuilder,
  });

  @override
  State<AdminProTable<T>> createState() => _AdminProTableState<T>();
}

class _AdminProTableState<T> extends State<AdminProTable<T>> {
  Object? _hoveredItemId;

  bool get _isMultiSelectEnabled =>
      widget.enableMultiSelect && widget.onSelectionChanged != null;

  void _toggleSelectAll(bool? selectAll) {
    if (!_isMultiSelectEnabled) return;
    final newSet = Set<Object>.from(widget.selectedIds);
    final currentPageIds = widget.items.map((e) => widget.itemId(e)).toSet();

    if (selectAll == true) {
      newSet.addAll(currentPageIds);
    } else {
      newSet.removeAll(currentPageIds);
    }
    widget.onSelectionChanged?.call(newSet);
  }

  void _toggleSelectItem(Object id, bool isSelected) {
    if (!_isMultiSelectEnabled) return;
    final newSet = Set<Object>.from(widget.selectedIds);
    if (isSelected) {
      newSet.add(id);
    } else {
      newSet.remove(id);
    }
    widget.onSelectionChanged?.call(newSet);
  }

  void _clearSelection() {
    widget.onSelectionChanged?.call(const {});
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 640;

    // 1. Estado de Carga: Skeleton Shimmer
    if (widget.isLoading) {
      return Padding(
        padding: widget.margin,
        child: AppTableShimmer(
          minWidth: widget.minTableWidth,
          rowCount: widget.paginationConfig?.pageSize.clamp(3, 8) ?? 6,
        ),
      );
    }

    // 2. Estado Vacío
    if (widget.items.isEmpty) {
      return Padding(
        padding: widget.margin,
        child:
            widget.emptyState ??
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const AppEmptyState(
                icon: Icons.inbox_rounded,
                title: 'No se encontraron registros',
                message:
                    'Prueba ajustando los filtros de búsqueda o registra un nuevo elemento.',
              ),
            ),
      );
    }

    // 3. Camaleón Móvil (si se suministra mobileCardBuilder)
    if (isMobile && widget.mobileCardBuilder != null) {
      return _buildMobileCardLayout();
    }

    // 4. Modo Desktop & Tablet (Tabla Pro de Alta Densidad con Stack para barra flotante)
    return Stack(
      children: [
        Padding(
          padding: widget.margin,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.2),
              boxShadow: AppColors.cardShadow(opacity: 0.04),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cuerpo de la tabla con scroll horizontal
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth =
                          screenWidth < widget.minTableWidth
                              ? widget.minTableWidth
                              : (screenWidth - 32).clamp(
                                widget.minTableWidth,
                                double.infinity,
                              );

                      return SizedBox(
                        width: tableWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [_buildTableHeader(), _buildTableRows()],
                        ),
                      );
                    },
                  ),
                ),

                // Pie de Tabla (Paginación y conteo)
                if (widget.paginationConfig != null) _buildTableFooter(),
              ],
            ),
          ),
        ),

        // Barra Flotante de Acciones en Lote (Floating Bulk Action Bar)
        if (_isMultiSelectEnabled && widget.selectedIds.isNotEmpty)
          _buildFloatingBulkActionBar(),
      ],
    );
  }

  // ── CABECERA DE LA TABLA (HEADER) ──────────────────────────────────────────
  Widget _buildTableHeader() {
    final currentPageIds = widget.items.map((e) => widget.itemId(e)).toSet();
    final allSelected =
        currentPageIds.isNotEmpty &&
        currentPageIds.every((id) => widget.selectedIds.contains(id));
    final someSelected =
        !allSelected &&
        currentPageIds.any((id) => widget.selectedIds.contains(id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC), // Slate 50 / Surface Variant
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          // Checkbox Master de Selección Total
          if (_isMultiSelectEnabled) ...[
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
                onChanged: (val) => _toggleSelectAll(val ?? true),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Columnas declarativas
          for (final col in widget.columns) _buildHeaderCell(col),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(AdminTableColumn<T> col) {
    final isSorted = widget.sortColumnId == col.id;
    final isSortable = col.isSortable && widget.onSort != null;

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
                  fontWeight: FontWeight.w800,
                  color:
                      isSorted
                          ? AppColors.primary
                          : const Color(0xFF334155), // Slate-700 (WCAG AAA)
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        ),
        if (isSortable) ...[
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: isSorted && !widget.isSortAscending ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSorted ? Icons.arrow_upward_rounded : Icons.unfold_more_rounded,
              size: 14,
              color: isSorted ? AppColors.primary : const Color(0xFF94A3B8),
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
                    final nextAsc = isSorted ? !widget.isSortAscending : true;
                    widget.onSort?.call(col.id, nextAsc);
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

    if (col.fixedWidth != null) {
      return SizedBox(width: col.fixedWidth, child: wrappedCell);
    }

    return Expanded(flex: col.flex, child: wrappedCell);
  }

  // ── FILAS DE LA TABLA (ROWS) ───────────────────────────────────────────────
  Widget _buildTableRows() {
    return Column(
      children: [
        for (int i = 0; i < widget.items.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          _buildTableRow(widget.items[i]),
        ],
      ],
    );
  }

  Widget _buildTableRow(T item) {
    final id = widget.itemId(item);
    final isSelected = widget.selectedIds.contains(id);
    final isHovered = _hoveredItemId == id;

    final rowColor =
        isSelected
            ? AppColors.primary.withValues(alpha: 0.05)
            : (isHovered ? const Color(0xFFF8FAFC) : Colors.white);

    return MouseRegion(
      cursor:
          widget.onRowTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hoveredItemId = id),
      onExit: (_) => setState(() => _hoveredItemId = null),
      child: GestureDetector(
        onTap: () => widget.onRowTap?.call(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: rowColor,
            border:
                isSelected
                    ? const Border(
                      left: BorderSide(color: AppColors.primary, width: 3.5),
                    )
                    : null,
          ),
          child: Row(
            children: [
              // Checkbox de Fila
              if (_isMultiSelectEnabled) ...[
                SizedBox(
                  width: 32,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: const BorderSide(
                      color: Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                    onChanged: (val) => _toggleSelectItem(id, val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Celdas de Datos
              for (final col in widget.columns) _buildDataCell(col, item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(AdminTableColumn<T> col, T item) {
    final cellWidget = Align(
      alignment: col.alignment,
      child: col.cellBuilder(context, item),
    );

    if (col.fixedWidth != null) {
      return SizedBox(width: col.fixedWidth, child: cellWidget);
    }

    return Expanded(flex: col.flex, child: cellWidget);
  }

  // ── PIE DE TABLA CON CONTROLES DE PAGINACIÓN (FOOTER) ─────────────────────
  Widget _buildTableFooter() {
    final config = widget.paginationConfig!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          // Lado Izquierdo: Selector de tamaño de página y rango visible
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mostrar',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: config.pageSize,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    items:
                        config.pageSizeOptions
                            .map(
                              (size) => DropdownMenuItem(
                                value: size,
                                child: Text('$size'),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null && val != config.pageSize) {
                        config.onPageSizeChanged(val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'por pág. • Viendo ${config.fromItem} - ${config.toItem} de ${config.totalItems}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Lado Derecho: Botones Anterior / Siguiente y número de página
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed:
                    config.hasPrevious
                        ? () => config.onPageChanged(config.currentPage - 1)
                        : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 16),
                label: const Text('Anterior'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  foregroundColor: AppColors.textPrimary,
                  disabledForegroundColor: AppColors.textMuted,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${config.currentPage} / ${config.totalPages}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed:
                    config.hasNext
                        ? () => config.onPageChanged(config.currentPage + 1)
                        : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 16),
                label: const Text('Siguiente'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  foregroundColor: AppColors.textPrimary,
                  disabledForegroundColor: AppColors.textMuted,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── BARRA FLOTANTE DE ACCIONES EN LOTE (FLOATING BULK ACTION BAR) ──────────
  Widget _buildFloatingBulkActionBar() {
    final selectedCount = widget.selectedIds.length;
    final selectedItemsList =
        widget.items
            .where((item) => widget.selectedIds.contains(widget.itemId(item)))
            .toList();

    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, val, child) {
            return Transform.translate(
              offset: Offset(0, 16 * (1 - val)),
              child: Opacity(opacity: val, child: child),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), // Dark Slate / Charcoal
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge de contador
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$selectedCount seleccionados',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),
                const SizedBox(
                  height: 20,
                  child: VerticalDivider(
                    color: Color(0xFF475569),
                    thickness: 1,
                  ),
                ),
                const SizedBox(width: 8),

                // Botones de acciones masivas
                for (final action in widget.bulkActions) ...[
                  TextButton.icon(
                    onPressed: () => action.onPressed(selectedItemsList),
                    icon: Icon(
                      action.icon,
                      size: 15,
                      color:
                          action.isDestructive
                              ? const Color(0xFFFCA5A5)
                              : (action.customColor ?? Colors.white),
                    ),
                    label: Text(
                      action.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            action.isDestructive
                                ? const Color(0xFFFCA5A5)
                                : (action.customColor ?? Colors.white),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],

                // Botón Deseleccionar todo
                Tooltip(
                  message: 'Deseleccionar todos los elementos',
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    splashRadius: 16,
                    onPressed: _clearSelection,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── CAMALEÓN MÓVIL: CARDS VERTICALES TÁCTILES ──────────────────────────────
  Widget _buildMobileCardLayout() {
    return Padding(
      padding: widget.margin,
      child: Column(
        children: [
          // Selector de todos en móvil si hay selección activa
          if (_isMultiSelectEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Checkbox(
                    value:
                        widget.items.isNotEmpty &&
                        widget.items.every(
                          (e) => widget.selectedIds.contains(widget.itemId(e)),
                        ),
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) => _toggleSelectAll(val ?? true),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Seleccionar todos',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (widget.selectedIds.isNotEmpty)
                    TextButton(
                      onPressed: _clearSelection,
                      child: const Text('Limpiar selección'),
                    ),
                ],
              ),
            ),

          // Lista de tarjetas
          for (final item in widget.items) ...[
            widget.mobileCardBuilder!(
              context,
              item,
              widget.selectedIds.contains(widget.itemId(item)),
              (val) => _toggleSelectItem(widget.itemId(item), val),
            ),
            const SizedBox(height: 10),
          ],

          // Footer paginación móvil
          if (widget.paginationConfig != null) ...[
            const SizedBox(height: 8),
            _buildMobileFooter(),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileFooter() {
    final config = widget.paginationConfig!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed:
                config.hasPrevious
                    ? () => config.onPageChanged(config.currentPage - 1)
                    : null,
          ),
          Text(
            'Página ${config.currentPage} de ${config.totalPages}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed:
                config.hasNext
                    ? () => config.onPageChanged(config.currentPage + 1)
                    : null,
          ),
        ],
      ),
    );
  }
}
