import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';

/// Espaciado compartido (tabla real y shimmer deben coincidir).
const double kAdminTableRowHPad = 14.0;
const double kAdminTableCellGutter = 8.0;

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
    this.pageSizeOptions = const [15, 25, 50, 100],
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

  /// Padding vertical de cada fila de datos y cabecera.
  final double rowVerticalPadding;

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
    this.rowVerticalPadding = 9.0,
  });

  @override
  State<AdminProTable<T>> createState() => _AdminProTableState<T>();
}

class _AdminProTableState<T> extends State<AdminProTable<T>> {
  Object? _hoveredItemId;

  // ── Keyboard focus navigation ─────────────────────────────────────────────
  late final FocusNode _tableFocusNode;
  int _focusedRowIndex = -1;

  @override
  void initState() {
    super.initState();
    _tableFocusNode = FocusNode(debugLabel: 'AdminProTable');
    _tableFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_tableFocusNode.hasFocus &&
        (_focusedRowIndex != -1 || _hoveredItemId != null)) {
      setState(() {
        _focusedRowIndex = -1;
        _hoveredItemId = null;
      });
    }
  }

  @override
  void dispose() {
    _tableFocusNode.removeListener(_onFocusChange);
    _tableFocusNode.dispose();
    super.dispose();
  }

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

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final count = widget.items.length;
    if (count == 0) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _hoveredItemId = null;
        _focusedRowIndex =
            _focusedRowIndex == -1
                ? 0
                : (_focusedRowIndex + 1).clamp(0, count - 1);
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _hoveredItemId = null;
        _focusedRowIndex =
            _focusedRowIndex <= 0
                ? 0
                : (_focusedRowIndex - 1).clamp(0, count - 1);
      });
      return KeyEventResult.handled;
    }

    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        _focusedRowIndex >= 0 &&
        _focusedRowIndex < count) {
      widget.onRowTap?.call(widget.items[_focusedRowIndex]);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 640;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Estado de Carga: Skeleton Shimmer
    if (widget.isLoading) {
      return Padding(
        padding: widget.margin,
        child: AppTableShimmer(
          minWidth: widget.minTableWidth,
          showCheckbox: _isMultiSelectEnabled,
          columns: [
            for (final c in widget.columns)
              AppShimmerColumn(
                flex: c.flex,
                fixedWidth: c.fixedWidth,
                alignment: c.alignment,
              ),
          ],
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
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
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
          child: TapRegion(
            onTapOutside: (_) {
              _tableFocusNode.unfocus();
              if (_hoveredItemId != null || _focusedRowIndex != -1) {
                setState(() {
                  _hoveredItemId = null;
                  _focusedRowIndex = -1;
                });
              }
            },
            child: MouseRegion(
              onExit: (_) {
                if (_hoveredItemId != null || _focusedRowIndex != -1) {
                  setState(() {
                    _hoveredItemId = null;
                    _focusedRowIndex = -1;
                  });
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                    width: 1.2,
                  ),
                  boxShadow:
                      isDark
                          ? AppColors.darkCardShadow(opacity: 0.15)
                          : AppColors.cardShadow(opacity: 0.04),
                ),
                clipBehavior: Clip.antiAlias,
                child: Focus(
                  focusNode: _tableFocusNode,
                  onKeyEvent: _handleKeyEvent,
                  child: GestureDetector(
                    onTap: () => _tableFocusNode.requestFocus(),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cuerpo de la tabla con scroll horizontal + scrollbar visible
                        _HorizontalScrollableTable(
                          minTableWidth: widget.minTableWidth,
                          header: _buildTableHeader(),
                          rows: _buildTableRows(),
                        ),

                        // Pie de Tabla (Paginación y conteo)
                        if (widget.paginationConfig != null)
                          _buildTableFooter(),
                      ],
                    ),
                  ),
                ),
              ),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kAdminTableRowHPad,
        vertical: widget.rowVerticalPadding,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            turns: isSorted && !widget.isSortAscending ? 0.5 : 0.0,
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

    wrappedCell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: kAdminTableCellGutter),
      child: wrappedCell,
    );

    if (col.fixedWidth != null) {
      return SizedBox(width: col.fixedWidth, child: wrappedCell);
    }

    return Expanded(flex: col.flex, child: wrappedCell);
  }

  // ── FILAS DE LA TABLA (ROWS) ───────────────────────────────────────────────
  Widget _buildTableRows() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        for (int i = 0; i < widget.items.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
            ),
          _buildTableRow(widget.items[i], index: i),
        ],
      ],
    );
  }

  Widget _buildTableRow(T item, {required int index}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final id = widget.itemId(item);
    final isSelected = widget.selectedIds.contains(id);
    final isHovered = _hoveredItemId == id;
    final isFocused = _tableFocusNode.hasFocus && _focusedRowIndex == index;
    final isHighlighted = isHovered || isFocused;

    final rowColor =
        isSelected
            ? (isDark
                ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                : AppColors.primary.withValues(alpha: 0.06))
            : (isHighlighted
                ? (isDark
                    ? AppColors.darkSurfaceHighlight
                    : const Color(0xFFF1F5F9))
                : (isDark ? AppColors.darkSurface : Colors.white));

    // Subtle shadow on hover/keyboard focus (like Linear/Stripe row lift)
    final rowShadow =
        isHighlighted && !isSelected
            ? [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF0F172A))
                    .withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ]
            : <BoxShadow>[];

    return MouseRegion(
      cursor:
          widget.onRowTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
      onEnter: (_) {
        setState(() {
          _hoveredItemId = id;
        });
      },
      onExit: (_) {
        setState(() {
          if (_hoveredItemId == id) _hoveredItemId = null;
        });
      },
      child: GestureDetector(
        onTap: () {
          _tableFocusNode.requestFocus();
          setState(() {
            _focusedRowIndex = index;
          });
          widget.onRowTap?.call(item);
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
                isSelected
                    ? Border(
                      left: BorderSide(
                        color:
                            isDark
                                ? const Color(0xFF3B82F6)
                                : AppColors.primary,
                        width: 3.5,
                      ),
                    )
                    : isFocused && !isSelected
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
              if (_isMultiSelectEnabled) ...[
                SizedBox(
                  width: 32,
                  child: Checkbox(
                    value: isSelected,
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

  // ── PIE DE TABLA CON CONTROLES DE PAGINACIÓN (FOOTER) ─────────────────────
  Widget _buildTableFooter() {
    final config = widget.paginationConfig!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: AdminPageBlocks(
        currentPage: config.currentPage - 1,
        totalPages: config.totalPages,
        totalItems: config.totalItems,
        itemsPerPage: config.pageSize,
        availableItemsPerPage: config.pageSizeOptions,
        onPageChanged: (zeroBasedPage) {
          config.onPageChanged(zeroBasedPage + 1);
        },
        onItemsPerPageChanged: (newSize) {
          config.onPageSizeChanged(newSize);
        },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: AdminPageBlocks(
        currentPage: config.currentPage - 1,
        totalPages: config.totalPages,
        totalItems: config.totalItems,
        itemsPerPage: config.pageSize,
        availableItemsPerPage: config.pageSizeOptions,
        isCompact: true,
        onPageChanged: (zeroBasedPage) {
          config.onPageChanged(zeroBasedPage + 1);
        },
        onItemsPerPageChanged: (newSize) {
          config.onPageSizeChanged(newSize);
        },
      ),
    );
  }
}

// ── HELPER PRIVADO: Tabla con scroll horizontal visible ─────────────────────
class _HorizontalScrollableTable extends StatefulWidget {
  final double minTableWidth;
  final Widget header;
  final Widget rows;

  const _HorizontalScrollableTable({
    required this.minTableWidth,
    required this.header,
    required this.rows,
  });

  @override
  State<_HorizontalScrollableTable> createState() =>
      _HorizontalScrollableTableState();
}

class _HorizontalScrollableTableState
    extends State<_HorizontalScrollableTable> {
  final _scrollController = ScrollController();
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicator);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateScrollIndicator(),
    );
  }

  void _updateScrollIndicator() {
    if (!_scrollController.hasClients) return;
    final canScroll =
        _scrollController.position.maxScrollExtent > 0 &&
        _scrollController.offset <
            _scrollController.position.maxScrollExtent - 2;
    if (canScroll != _canScrollRight) {
      setState(() => _canScrollRight = canScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicator);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the available width from parent; fall back to minTableWidth if needed.
        final tableWidth =
            constraints.maxWidth.isFinite &&
                    constraints.maxWidth > widget.minTableWidth
                ? constraints.maxWidth
                : widget.minTableWidth;

        return Stack(
          children: [
            Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 5,
              radius: const Radius.circular(4),
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [widget.header, widget.rows],
                  ),
                ),
              ),
            ),
            // Fade hint (right edge) when more content is available
            if (_canScrollRight)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 36,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
