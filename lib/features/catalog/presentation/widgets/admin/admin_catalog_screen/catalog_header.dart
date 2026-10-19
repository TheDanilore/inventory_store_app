import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';

/// Barra superior del catálogo admin: buscador con botón 'X', historial reciente + toggle de ingrediente activo.
class CatalogHeader extends StatefulWidget {
  final TextEditingController searchController;
  final bool isExporting;
  final VoidCallback onExport;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final bool searchByIngredient;
  final ValueChanged<bool> onToggleIngredientSearch;
  final VoidCallback onAddProduct;
  final bool isPosMode;
  final VoidCallback? onBack;
  final FocusNode? searchFocusNode;
  final bool isTableView;
  final ValueChanged<bool>? onToggleTableView;
  final VoidCallback? onScanBarcode;

  const CatalogHeader({
    super.key,
    required this.searchController,
    required this.isExporting,
    required this.onExport,
    this.onSearchChanged,
    this.onSearchSubmitted,
    required this.searchByIngredient,
    required this.onToggleIngredientSearch,
    required this.onAddProduct,
    this.isPosMode = false,
    this.onBack,
    this.searchFocusNode,
    this.isTableView = false,
    this.onToggleTableView,
    this.onScanBarcode,
  });

  @override
  State<CatalogHeader> createState() => _CatalogHeaderState();
}

class _CatalogHeaderState extends State<CatalogHeader> {
  static final List<String> _searchHistory = [];
  FocusNode? _internalFocusNode;
  FocusNode get _searchFocusNode =>
      widget.searchFocusNode ?? (_internalFocusNode ??= FocusNode());
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _hideOverlay();
    _searchFocusNode.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_searchFocusNode.hasFocus && _searchHistory.isNotEmpty) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _addToHistory(String term) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    if (!_searchHistory.contains(trimmed)) {
      setState(() {
        _searchHistory.insert(0, trimmed);
        if (_searchHistory.length > 8) _searchHistory.removeLast();
      });
    }
  }

  void _executeSearch(String term) {
    final cleaned = term.trim();
    _searchFocusNode.unfocus();
    _hideOverlay();
    if (cleaned.isNotEmpty) {
      _addToHistory(cleaned);
    }
    if (widget.onSearchSubmitted != null) {
      widget.onSearchSubmitted!(cleaned);
    } else {
      widget.onSearchChanged?.call(cleaned);
    }
  }

  void _selectHistoryItem(String term) {
    widget.searchController.text = term;
    widget.searchController.selection = TextSelection.collapsed(
      offset: term.length,
    );
    _executeSearch(term);
  }

  void _clearSearch() {
    widget.searchController.clear();
    _searchFocusNode.unfocus();
    _hideOverlay();
    if (widget.onSearchSubmitted != null) {
      widget.onSearchSubmitted!('');
    } else {
      widget.onSearchChanged?.call('');
    }
  }

  void _showOverlay() {
    _hideOverlay();
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            width: isDesktop ? 420 : (MediaQuery.of(context).size.width - 32),
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 48),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                color: isDark ? AppColors.darkSurface : Colors.white,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Búsquedas Recientes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() => _searchHistory.clear());
                                _hideOverlay();
                              },
                              child: const Text(
                                'Limpiar',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _searchHistory.length,
                          itemBuilder: (context, index) {
                            final item = _searchHistory[index];
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 0,
                              ),
                              visualDensity: VisualDensity.compact,
                              leading: Icon(
                                Icons.history_rounded,
                                size: 16,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                              title: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchHistory.removeAt(index);
                                  });
                                  if (_searchHistory.isEmpty) {
                                    _hideOverlay();
                                  } else {
                                    _showOverlay();
                                  }
                                },
                              ),
                              onTap: () => _selectHistoryItem(item),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    if (_overlayEntry?.mounted ?? false) {
      _overlayEntry?.remove();
    }
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : Colors.grey.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: isDesktop ? _buildDesktopLayout(isDark) : _buildMobileLayout(isDark),
        );
      },
    );
  }

  Widget _buildSearchField({bool isDesktop = false, required bool isDark}) {
    const activeBlue = Color(0xFF2563EB);
    const activeBorderBlue = Color(0xFF3B82F6);

    return Row(
      children: [
        // ── Selector Segmentado de Modo de Búsqueda (Estilo POS) ───────────
        Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Modo Producto (Cubo 3D)
              Tooltip(
                message: 'Buscar por Producto (${AppShortcutLabels.modPlus}T)',
                child: InkWell(
                  onTap: () {
                    if (widget.searchByIngredient) {
                      widget.onToggleIngredientSearch(false);
                    }
                  },
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          !widget.searchByIngredient
                              ? (isDark ? AppColors.darkSurfaceHighlight : Colors.white)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          !widget.searchByIngredient
                              ? Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.border.withValues(alpha: 0.6),
                                width: 1,
                              )
                              : null,
                      boxShadow:
                          !widget.searchByIngredient
                              ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                              : null,
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color:
                          !widget.searchByIngredient
                              ? activeBlue
                              : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // 2. Modo Ingrediente Activo (Matraz químico / Tubo)
              Tooltip(
                message: 'Buscar por Ingrediente Activo (${AppShortcutLabels.modPlus}T)',
                child: InkWell(
                  onTap: () {
                    if (!widget.searchByIngredient) {
                      widget.onToggleIngredientSearch(true);
                    }
                  },
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          widget.searchByIngredient
                              ? (isDark ? AppColors.darkSurfaceHighlight : Colors.white)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          widget.searchByIngredient
                              ? Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.border.withValues(alpha: 0.6),
                                width: 1,
                              )
                              : null,
                      boxShadow:
                          widget.searchByIngredient
                              ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                              : null,
                    ),
                    child: Icon(
                      Icons.science_outlined,
                      size: 20,
                      color:
                          widget.searchByIngredient
                              ? activeBlue
                              : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // ── Campo de Entrada con Borde Activo y Prefijo Dinámico ───────────
        Expanded(
          child: CompositedTransformTarget(
            link: _layerLink,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: activeBorderBlue, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: activeBorderBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.searchController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _executeSearch,
                      onChanged: widget.onSearchChanged,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            widget.searchByIngredient
                                ? 'Buscar por ingrediente activo...'
                                : 'Buscar producto por nombre o SKU...',
                        hintStyle: TextStyle(
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          widget.searchByIngredient
                              ? Icons.science_outlined
                              : Icons.inventory_2_outlined,
                          color: activeBlue,
                          size: 20,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: widget.searchController,
                              builder: (context, value, child) {
                                if (value.text.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return IconButton(
                                  icon: Icon(
                                    Icons.cancel_rounded,
                                    size: 18,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  ),
                                  onPressed: _clearSearch,
                                  tooltip: 'Borrar búsqueda',
                                );
                              },
                            ),
                            if (isDesktop)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : AppColors.background,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.border,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  AppShortcutLabels.search,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onScanBarcode != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 20,
                          color: activeBlue,
                        ),
                        tooltip: 'Escanear código (QR / Barras)',
                        splashRadius: 18,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onScanBarcode!();
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _executeSearch(widget.searchController.text);
                      },
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: Text(isDesktop ? 'Buscar' : ''),
                      style: FilledButton.styleFrom(
                        backgroundColor: activeBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 14 : 10,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            if (widget.isPosMode) ...[
              if (widget.onBack != null) ...[
                IconButton(
                  onPressed: widget.onBack,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  tooltip: 'Volver al Catálogo',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radius),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                ),
                tooltip: 'Operaciones POS (Ventas recientes y borradores)',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: _buildSearchField(isDesktop: true, isDark: isDark)),
            if (!widget.isPosMode) ...[
              if (widget.onToggleTableView != null) ...[
                const SizedBox(width: 12),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Vista Cuadrícula / Tarjetas (${AppShortcutLabels.modPlus}V)',
                        child: InkWell(
                          onTap: () => widget.onToggleTableView!(false),
                          borderRadius: BorderRadius.circular(7),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: !widget.isTableView
                                  ? (isDark ? AppColors.darkSurfaceHighlight : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: !widget.isTableView
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.grid_view_rounded,
                              size: 18,
                              color: !widget.isTableView
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Tooltip(
                        message: 'Vista Tabla Pro / Alta densidad (${AppShortcutLabels.modPlus}V)',
                        child: InkWell(
                          onTap: () => widget.onToggleTableView!(true),
                          borderRadius: BorderRadius.circular(7),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isTableView
                                  ? (isDark ? AppColors.darkSurfaceHighlight : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: widget.isTableView
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.table_rows_rounded,
                              size: 18,
                              color: widget.isTableView
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: widget.isExporting ? null : widget.onExport,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.slate,
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text(
                  'Exportar',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: widget.onAddProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Crear Producto',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child:
              widget.searchByIngredient
                  ? Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF059669).withValues(alpha: 0.5)
                            : const Color(0xFF6EE7B7),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.science_rounded,
                          size: 14,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Búsqueda por ingrediente activo: Se filtran productos por componente químico.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  : const SizedBox.shrink(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            if (widget.isPosMode) ...[
              if (widget.onBack != null) ...[
                IconButton(
                  onPressed: widget.onBack,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  tooltip: 'Volver al Catálogo',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radius),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                ),
                tooltip: 'Operaciones POS (Ventas recientes y borradores)',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: _buildSearchField(isDesktop: false, isDark: isDark)),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child:
              widget.searchByIngredient
                  ? Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF059669).withValues(alpha: 0.5)
                            : const Color(0xFF6EE7B7),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.science_rounded,
                          size: 13,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Mostrando ingrediente activo completo en tarjeta.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  : const SizedBox.shrink(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
