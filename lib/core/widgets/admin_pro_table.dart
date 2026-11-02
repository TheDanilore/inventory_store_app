import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/cards/admin_pro_table_card_layout.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/footer/admin_pro_table_footer.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/models/admin_bulk_action.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/models/admin_table_column.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/models/admin_table_pagination_config.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/overlay/admin_pro_floating_bulk_bar.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/table/admin_pro_horizontal_scroll.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/table/admin_pro_table_header.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table/table/admin_pro_table_row.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';

// Re-exportar contratos públicos para garantizar 100% de compatibilidad retroactiva
export 'package:inventory_store_app/core/widgets/admin_pro_table/models/admin_bulk_action.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_table/models/admin_table_column.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_table/models/admin_table_pagination_config.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_table/table/admin_pro_table_header.dart'
    show kAdminTableCellGutter, kAdminTableRowHPad;

/// Componente de tabla ejecutiva reutilizable de nivel internacional (estilo Stripe / Linear).
///
/// Soporta:
/// - Frame-0 Zero-Shimmer (SWR): Muestra inmediatamente los datos en caché sin parpadeos.
/// - Aislamiento atómico de hover en filas (0 rebuilds globales al mover el mouse).
/// - Selección múltiple con Checkboxes y [Floating Bulk Action Bar] sin tickers continuos.
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
  // Barra flotante de selección (vive en el Overlay, fija en pantalla)
  final OverlayPortalController _barPortal = OverlayPortalController();
  final GlobalKey _anchorKey = GlobalKey(debugLabel: 'AdminProTableAnchor');

  // Keyboard focus navigation
  late final FocusNode _tableFocusNode;
  int _focusedRowIndex = -1;

  @override
  void initState() {
    super.initState();
    _tableFocusNode = FocusNode(debugLabel: 'AdminProTable');
    _tableFocusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_barPortal.isShowing) _barPortal.show();
    });
  }

  void _onFocusChange() {
    if (!_tableFocusNode.hasFocus && _focusedRowIndex != -1) {
      setState(() => _focusedRowIndex = -1);
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
        _focusedRowIndex =
            _focusedRowIndex == -1
                ? 0
                : (_focusedRowIndex + 1).clamp(0, count - 1);
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 640;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasData = widget.items.isNotEmpty;
    final isInitialLoading = widget.isLoading && !hasData;

    // 1. Estado de Carga Inicial (Zero-Shimmer): Solo se muestra skeleton si NO hay datos en memoria/caché
    if (isInitialLoading) {
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

    // 2. Estado Vacío real (sin datos y no está cargando)
    if (!hasData) {
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

    // 3. Vista de tarjetas (móvil o forzada por toggle)
    final useCards =
        widget.mobileCardBuilder != null &&
        (isMobile || widget.forceCardLayout);
    if (useCards) {
      final cards = AdminProTableCardLayout<T>(
        items: widget.items,
        selectedIds: widget.selectedIds,
        itemId: widget.itemId,
        mobileCardBuilder: widget.mobileCardBuilder!,
        paginationConfig: widget.paginationConfig,
        isMobile: isMobile,
        isMultiSelectEnabled: _isMultiSelectEnabled,
        onToggleSelectAll: _toggleSelectAll,
        onToggleSelectItem: _toggleSelectItem,
        onClearSelection: _clearSelection,
        margin: widget.margin,
        cardMinWidth: widget.cardMinWidth,
      );
      final cardsContent =
          widget.verticalScroll ? _wrapVerticalScroll(cards) : cards;
      return _wrapBackgroundLoading(cardsContent);
    }

    // 4. Modo Desktop & Tablet (Tabla Pro de Alta Densidad)
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
              if (_focusedRowIndex != -1) {
                setState(() => _focusedRowIndex = -1);
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
                      // Indicador no bloqueante cuando revalida con datos en caché
                      if (widget.isLoading)
                        const LinearProgressIndicator(
                          minHeight: 2.5,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),

                      // Cuerpo con scroll horizontal y scrollbar visible
                      HorizontalScrollableTable(
                        minTableWidth: widget.minTableWidth,
                        header: _buildTableHeader(),
                        rows: _buildTableRows(isDark),
                      ),

                      // Pie de Tabla integrado
                      if (hasFooter && !widget.detachedFooter)
                        AdminProTableIntegratedFooter(
                          config: widget.paginationConfig!,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Pie de tabla como tarjeta independiente
          if (hasFooter && widget.detachedFooter) ...[
            const SizedBox(height: 10),
            AdminProTableDetachedFooter(config: widget.paginationConfig!),
          ],
        ],
      ),
    );

    return widget.verticalScroll ? _wrapVerticalScroll(tableBlock) : tableBlock;
  }

  Widget _wrapBackgroundLoading(Widget child) {
    if (!widget.isLoading) return child;
    return Stack(
      children: [
        child,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(
            minHeight: 2.5,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

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

  // ── CABECERA DE LA TABLA ───────────────────────────────────────────────────
  Widget _buildTableHeader() {
    final currentPageIds = widget.items.map((e) => widget.itemId(e)).toSet();
    final allSelected =
        currentPageIds.isNotEmpty &&
        currentPageIds.every((id) => widget.selectedIds.contains(id));
    final someSelected =
        !allSelected &&
        currentPageIds.any((id) => widget.selectedIds.contains(id));

    return AdminProTableHeader<T>(
      columns: widget.columns,
      isMultiSelectEnabled: _isMultiSelectEnabled,
      allSelected: allSelected,
      someSelected: someSelected,
      onToggleSelectAll: _toggleSelectAll,
      sortColumnId: widget.sortColumnId,
      isSortAscending: widget.isSortAscending,
      onSort: widget.onSort,
      rowVerticalPadding: widget.rowVerticalPadding,
    );
  }

  // ── FILAS DE LA TABLA CON HOVER Y FOCO ATÓMICOS ───────────────────────────
  Widget _buildTableRows(bool isDark) {
    return Column(
      children: [
        for (int i = 0; i < widget.items.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
            ),
          AdminProTableRow<T>(
            item: widget.items[i],
            index: i,
            itemId: widget.itemId(widget.items[i]),
            isSelected: widget.selectedIds.contains(
              widget.itemId(widget.items[i]),
            ),
            isFocused: _tableFocusNode.hasFocus && _focusedRowIndex == i,
            isMultiSelectEnabled: _isMultiSelectEnabled,
            rowVerticalPadding: widget.rowVerticalPadding,
            columns: widget.columns,
            onRowTap: widget.onRowTap,
            onToggleSelect: _toggleSelectItem,
            onRowFocused: () {
              if (_focusedRowIndex != i) {
                setState(() => _focusedRowIndex = i);
              }
            },
          ),
        ],
      ],
    );
  }

  // ── BARRA FLOTANTE DE ACCIONES EN LOTE (OVERLAY) ───────────────────────────
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

    return AdminProFloatingBulkBar(
      visible: visible,
      count: widget.selectedIds.length,
      pageCount: widget.items.length,
      anchorKey: _anchorKey,
      actions: [
        for (final a in widget.bulkActions)
          AdminBulkBarActionItem(
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
}
