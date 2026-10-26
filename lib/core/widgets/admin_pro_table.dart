import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
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

  /// Total de registros. Puede ser `null` cuando el backend no lo informa
  /// (p. ej. con filtros activos); en ese caso el pie muestra solo
  /// "página X de Y" y se debe indicar [totalPagesOverride].
  final int? totalItems;

  /// Total de páginas informado por el backend. Si es `null` se calcula a
  /// partir de [totalItems] y [pageSize].
  final int? totalPagesOverride;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final List<int> pageSizeOptions;

  const AdminTablePaginationConfig({
    required this.currentPage,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.totalItems,
    this.totalPagesOverride,
    this.pageSizeOptions = const [15, 25, 50, 100],
  });

  int get totalPages {
    if (totalPagesOverride != null) {
      return totalPagesOverride!.clamp(1, 999999);
    }
    final total = totalItems ?? 0;
    return total <= 0 ? 1 : (total / pageSize).ceil().clamp(1, 999999);
  }

  int get fromItem =>
      (totalItems ?? 0) == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;

  int get toItem =>
      ((currentPage - 1) * pageSize + pageSize).clamp(0, totalItems ?? 0);

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

  /// Fuerza la vista de tarjetas (grid en desktop/tablet) aunque el ancho no
  /// sea móvil. Requiere [mobileCardBuilder]. Lo usa el toggle Tabla/Tarjetas.
  final bool forceCardLayout;

  /// Ancho mínimo de cada tarjeta cuando se muestra el grid de tarjetas.
  final double cardMinWidth;

  /// Si es true, la tabla/tarjetas hacen scroll vertical por sí mismas y la
  /// barra flotante de selección queda anclada al viewport. Úsalo cuando el
  /// padre da una altura acotada (p. ej. dentro de un `Expanded`).
  final bool verticalScroll;
  final ScrollController? scrollController;

  /// Dibuja la paginación como una tarjeta independiente debajo de la tabla
  /// (estilo Salidas de Inventario) en vez de dentro del mismo contenedor.
  final bool detachedFooter;

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
    this.forceCardLayout = false,
    this.cardMinWidth = 360.0,
    this.verticalScroll = false,
    this.scrollController,
    this.detachedFooter = false,
  });

  @override
  State<AdminProTable<T>> createState() => _AdminProTableState<T>();
}

class _AdminProTableState<T> extends State<AdminProTable<T>> {
  Object? _hoveredItemId;

  // ── Barra flotante de selección (vive en el Overlay, fija en pantalla) ───
  final OverlayPortalController _barPortal = OverlayPortalController();
  final GlobalKey _anchorKey = GlobalKey(debugLabel: 'AdminProTableAnchor');

  // ── Keyboard focus navigation ─────────────────────────────────────────────
  late final FocusNode _tableFocusNode;
  int _focusedRowIndex = -1;

  @override
  void initState() {
    super.initState();
    _tableFocusNode = FocusNode(debugLabel: 'AdminProTable');
    _tableFocusNode.addListener(_onFocusChange);
    // El portal siempre está en el árbol; la barra se muestra/oculta sola
    // (con animación) según haya filas seleccionadas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_barPortal.isShowing) _barPortal.show();
    });
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
    if (key == LogicalKeyboardKey.escape &&
        _isMultiSelectEnabled &&
        widget.selectedIds.isNotEmpty) {
      _clearSelection();
      return KeyEventResult.handled;
    }
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
    return OverlayPortal(
      controller: _barPortal,
      overlayChildBuilder: _buildBulkBarOverlay,
      child: KeyedSubtree(key: _anchorKey, child: _buildContent(context)),
    );
  }

  Widget _buildContent(BuildContext context) {
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

    // 3. Vista de tarjetas (móvil, o forzada por el toggle de vista)
    final useCards =
        widget.mobileCardBuilder != null &&
        (isMobile || widget.forceCardLayout);
    if (useCards) {
      final cards = _buildCardLayout(isMobile: isMobile);
      return widget.verticalScroll ? _wrapVerticalScroll(cards) : cards;
    }

    // 4. Modo Desktop & Tablet (Tabla Pro de Alta Densidad con Stack para barra flotante)
    final hasFooter = widget.paginationConfig != null;
    final tableBlock = Padding(
      padding: widget.margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TapRegion(
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cuerpo de la tabla con scroll horizontal + scrollbar visible
                        _HorizontalScrollableTable(
                          minTableWidth: widget.minTableWidth,
                          header: _buildTableHeader(),
                          rows: _buildTableRows(),
                        ),

                        // Pie de Tabla integrado (Paginación y conteo)
                        if (hasFooter && !widget.detachedFooter)
                          _buildTableFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Pie de tabla como tarjeta independiente
          if (hasFooter && widget.detachedFooter) ...[
            const SizedBox(height: 10),
            _buildDetachedFooter(),
          ],
        ],
      ),
    );

    return widget.verticalScroll ? _wrapVerticalScroll(tableBlock) : tableBlock;
  }

  /// Envuelve el contenido en un scroll vertical dejando aire inferior para
  /// que la barra flotante de selección no tape la última fila.
  Widget _wrapVerticalScroll(Widget child) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.only(
        bottom:
            _isMultiSelectEnabled && widget.selectedIds.isNotEmpty ? 88 : 12,
      ),
      child: child,
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

  // ── BARRA FLOTANTE DE ACCIONES EN LOTE ─────────────────────────────────────
  // Se dibuja en el Overlay (no dentro de la tabla), por eso queda FIJA en la
  // pantalla aunque la página haga scroll, y se centra sobre el ancho de la
  // tabla (no sobre la ventana, que incluye el sidebar).
  Widget _buildBulkBarOverlay(BuildContext context) {
    final visible = _isMultiSelectEnabled && widget.selectedIds.isNotEmpty;
    final selected =
        widget.items
            .where((item) => widget.selectedIds.contains(widget.itemId(item)))
            .toList();
    final pageFullySelected =
        widget.items.isNotEmpty &&
        widget.items.every(
          (e) => widget.selectedIds.contains(widget.itemId(e)),
        );

    return _FloatingBulkBar(
      visible: visible,
      count: widget.selectedIds.length,
      pageCount: widget.items.length,
      anchorKey: _anchorKey,
      actions: [
        for (final a in widget.bulkActions)
          _BulkBarAction(
            label: a.label,
            icon: a.icon,
            isDestructive: a.isDestructive,
            color: a.customColor,
            onTap: () => a.onPressed(selected),
          ),
      ],
      onClear: _clearSelection,
      onSelectPage:
          (pageFullySelected || widget.items.isEmpty)
              ? null
              : () => _toggleSelectAll(true),
    );
  }

  // ── CAMALEÓN MÓVIL: CARDS VERTICALES TÁCTILES ──────────────────────────────
  Widget _buildCardLayout({required bool isMobile}) {
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

          // Lista (móvil) o grid (desktop/tablet) de tarjetas
          if (isMobile)
            for (final item in widget.items) ...[
              _buildCard(item),
              const SizedBox(height: 10),
            ]
          else
            _buildCardGrid(),

          // Footer paginación
          if (widget.paginationConfig != null) ...[
            const SizedBox(height: 8),
            _buildMobileFooter(isCompact: isMobile),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(T item) {
    return widget.mobileCardBuilder!(
      context,
      item,
      widget.selectedIds.contains(widget.itemId(item)),
      (val) => _toggleSelectItem(widget.itemId(item), val),
    );
  }

  Widget _buildCardGrid() {
    const gap = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / widget.cardMinWidth).floor().clamp(
          1,
          4,
        );
        final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: 0,
          children: [
            for (final item in widget.items)
              SizedBox(width: itemWidth, child: _buildCard(item)),
          ],
        );
      },
    );
  }

  Widget _buildDetachedFooter() {
    final config = widget.paginationConfig!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildMobileFooter({required bool isCompact}) {
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
        isCompact: isCompact,
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

// ─────────────────────────────────────────────────────────────────────────
// Barra flotante de selección (Overlay)
// ─────────────────────────────────────────────────────────────────────────

class _BulkBarAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final Color? color;

  const _BulkBarAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.color,
  });
}

class _BarInsets {
  final double left;
  final double right;
  const _BarInsets(this.left, this.right);

  bool closeTo(_BarInsets o) =>
      (left - o.left).abs() < 0.5 && (right - o.right).abs() < 0.5;
}

class _FloatingBulkBar extends StatefulWidget {
  final bool visible;
  final int count;
  final int pageCount;
  final GlobalKey anchorKey;
  final List<_BulkBarAction> actions;
  final VoidCallback onClear;
  final VoidCallback? onSelectPage;

  const _FloatingBulkBar({
    required this.visible,
    required this.count,
    required this.pageCount,
    required this.anchorKey,
    required this.actions,
    required this.onClear,
    this.onSelectPage,
  });

  @override
  State<_FloatingBulkBar> createState() => _FloatingBulkBarState();
}

class _FloatingBulkBarState extends State<_FloatingBulkBar>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  _BarInsets? _insets;
  int _shownCount = 0;

  @override
  void initState() {
    super.initState();
    _shownCount = widget.count;
    // Mientras la barra está visible seguimos la posición de la tabla
    // (p. ej. al colapsar el sidebar o redimensionar la ventana).
    _ticker = createTicker((_) {
      final m = _measure();
      if (m != null && (_insets == null || !m.closeTo(_insets!))) {
        setState(() => _insets = m);
      }
    });
    if (widget.visible) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant _FloatingBulkBar old) {
    super.didUpdateWidget(old);
    if (widget.visible && !_ticker.isActive) _ticker.start();
    if (!widget.visible && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Distancia (en coordenadas del Overlay) entre los bordes de la tabla y
  /// los bordes del Overlay.
  _BarInsets? _measure() {
    final anchor = widget.anchorKey.currentContext?.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (anchor is! RenderBox ||
        overlay is! RenderBox ||
        !anchor.attached ||
        !overlay.attached ||
        !anchor.hasSize ||
        !overlay.hasSize) {
      return null;
    }
    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final left = topLeft.dx.clamp(0.0, overlay.size.width);
    final right = (overlay.size.width - (topLeft.dx + anchor.size.width)).clamp(
      0.0,
      overlay.size.width,
    );
    return _BarInsets(left, right);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count > 0) _shownCount = widget.count; // evita "0" al salir

    final screenWidth = MediaQuery.sizeOf(context).width;
    final insets = _insets ?? _measure() ?? const _BarInsets(0, 0);
    final available = (screenWidth - insets.left - insets.right).clamp(
      280.0,
      screenWidth,
    );
    final compact = available < 720;
    final bottom = 24.0 + MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: insets.left,
        right: insets.right,
        bottom: bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: IgnorePointer(
          ignoring: !widget.visible,
          child: AnimatedSlide(
            duration: Duration(milliseconds: widget.visible ? 280 : 180),
            curve: widget.visible ? Curves.easeOutCubic : Curves.easeInCubic,
            offset: widget.visible ? Offset.zero : const Offset(0, 0.8),
            child: AnimatedOpacity(
              duration: Duration(milliseconds: widget.visible ? 220 : 140),
              curve: Curves.easeOut,
              opacity: widget.visible ? 1 : 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: available - 32),
                child: _buildBar(compact),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBar(bool compact) {
    const slate = Color(0xFF334155);

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 32,
              spreadRadius: 1,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: slate, width: 1.1),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _countPill(),
                    if (!compact && widget.onSelectPage != null) ...[
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: widget.onSelectPage,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF93C5FD),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text('Seleccionar todos (${widget.pageCount})'),
                      ),
                    ],
                    if (widget.actions.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        height: 22,
                        child: VerticalDivider(color: slate, thickness: 1.1),
                      ),
                      const SizedBox(width: 6),
                    ],
                    for (final a in widget.actions) ...[
                      _actionButton(a, compact),
                      const SizedBox(width: 2),
                    ],
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Deseleccionar todo (Esc)',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        hoverColor: Colors.white.withValues(alpha: 0.10),
                        onTap: widget.onClear,
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _countPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.55),
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 15,
            color: Color(0xFF60A5FA),
          ),
          const SizedBox(width: 7),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder:
                (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
            child: Text(
              '$_shownCount',
              key: ValueKey(_shownCount),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _shownCount == 1 ? 'seleccionado' : 'seleccionados',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(_BulkBarAction a, bool compact) {
    final color =
        a.isDestructive ? const Color(0xFFFCA5A5) : (a.color ?? Colors.white);

    final button = InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: a.onTap,
      hoverColor: Colors.white.withValues(alpha: 0.08),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 10,
          vertical: 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(a.icon, size: 16, color: color),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                a.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return compact ? Tooltip(message: a.label, child: button) : button;
  }
}
