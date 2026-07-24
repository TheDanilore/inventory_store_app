import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Barra superior del catálogo admin: buscador con botón 'X', historial reciente + toggle de ingrediente activo.
class CatalogHeader extends StatefulWidget {
  final TextEditingController searchController;
  final bool isExporting;
  final VoidCallback onExport;
  final ValueChanged<String> onSearchChanged;
  final bool searchByIngredient;
  final ValueChanged<bool> onToggleIngredientSearch;
  final VoidCallback onAddProduct;
  final bool isPosMode;
  final VoidCallback? onBack;

  const CatalogHeader({
    super.key,
    required this.searchController,
    required this.isExporting,
    required this.onExport,
    required this.onSearchChanged,
    required this.searchByIngredient,
    required this.onToggleIngredientSearch,
    required this.onAddProduct,
    this.isPosMode = false,
    this.onBack,
  });

  @override
  State<CatalogHeader> createState() => _CatalogHeaderState();
}

class _CatalogHeaderState extends State<CatalogHeader> {
  static final List<String> _searchHistory = [];
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchTextChange);
    _searchFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _hideOverlay();
    widget.searchController.removeListener(_onSearchTextChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_searchFocusNode.hasFocus && _searchHistory.isNotEmpty) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _onSearchTextChange() {
    if (mounted) setState(() {});
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

  void _selectHistoryItem(String term) {
    widget.searchController.text = term;
    widget.onSearchChanged(term);
    _searchFocusNode.unfocus();
    _hideOverlay();
  }

  void _clearSearch() {
    widget.searchController.clear();
    widget.onSearchChanged('');
  }

  void _showOverlay() {
    _hideOverlay();
    if (!mounted) return;

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
                shadowColor: Colors.black.withValues(alpha: 0.15),
                color: Colors.white,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
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
                            const Text(
                              'Búsquedas Recientes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
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
                      const Divider(height: 1, color: AppColors.border),
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
                              leading: const Icon(
                                Icons.history_rounded,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              title: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: AppColors.textMuted,
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
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              color: Colors.white.withValues(alpha: 0.85),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    final hasText = widget.searchController.text.isNotEmpty;

    return CompositedTransformTarget(
      link: _layerLink,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 44,
        decoration: BoxDecoration(
          color:
              widget.searchByIngredient
                  ? const Color(0xFFECFDF5)
                  : AppColors.background,
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(
            color:
                widget.searchByIngredient
                    ? const Color(0xFF10B981)
                    : AppColors.border,
            width: widget.searchByIngredient ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.searchController,
                focusNode: _searchFocusNode,
                onChanged: (val) {
                  widget.onSearchChanged(val);
                  if (val.trim().length >= 3) {
                    _addToHistory(val);
                  }
                },
                onSubmitted: (val) => _addToHistory(val),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText:
                      widget.searchByIngredient
                          ? 'Ej: Glifosato, Clorpirifos, Paracetamol...'
                          : 'Buscar producto...',
                  hintStyle: TextStyle(
                    color:
                        widget.searchByIngredient
                            ? const Color(0xFF6EE7B7)
                            : AppColors.textMuted,
                    fontSize: 14,
                  ),
                  prefixIcon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.searchByIngredient
                          ? Icons.science_rounded
                          : Icons.search_rounded,
                      key: ValueKey(widget.searchByIngredient),
                      color:
                          widget.searchByIngredient
                              ? const Color(0xFF10B981)
                              : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  suffixIcon:
                      hasText
                          ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            onPressed: _clearSearch,
                            tooltip: 'Borrar búsqueda',
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Tooltip(
              message: 'Buscar por ingrediente activo',
              child: GestureDetector(
                onTap:
                    () => widget.onToggleIngredientSearch(
                      !widget.searchByIngredient,
                    ),
                child: Container(
                  padding: const EdgeInsets.only(left: 8, right: 14),
                  color: Colors.transparent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ingrediente',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              widget.searchByIngredient
                                  ? const Color(0xFF059669)
                                  : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 32,
                        height: 18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color:
                              widget.searchByIngredient
                                  ? const Color(0xFF10B981)
                                  : AppColors.border,
                        ),
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              left: widget.searchByIngredient ? 16 : 2,
                              top: 2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Row(
          children: [
            if (widget.isPosMode && widget.onBack != null) ...[
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
                tooltip: 'Volver al Catálogo',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: _buildSearchField()),
            if (!widget.isPosMode) ...[
              const SizedBox(width: 16),
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
                    borderRadius: BorderRadius.circular(AppColors.radius),
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
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(
                        color: const Color(0xFF6EE7B7),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.science_rounded,
                          size: 14,
                          color: Color(0xFF059669),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Búsqueda por ingrediente activo: Se filtran productos por componente químico.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF065F46),
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

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Row(
          children: [
            if (widget.isPosMode && widget.onBack != null) ...[
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
                tooltip: 'Volver al Catálogo',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: _buildSearchField()),
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
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(
                        color: const Color(0xFF6EE7B7),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.science_rounded,
                          size: 13,
                          color: Color(0xFF059669),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Mostrando ingrediente activo completo en tarjeta.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF065F46),
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
