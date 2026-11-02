import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_filter_dropdown.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_mobile_triggers.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_primary_button.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_refresh_button.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_search_field.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_view_toggle.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/models/admin_toolbar_models.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/sheets/admin_filters_sheet.dart';

// Re-exportación completa de la API pública para compatibilidad absoluta
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_filter_chip.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_filter_dropdown.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_mobile_triggers.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_primary_button.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_refresh_button.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_search_field.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_view_toggle.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/models/admin_toolbar_models.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/sheets/admin_filter_select_field.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/sheets/admin_filters_sheet.dart';

/// Toolbar Pro Unificado de alto rendimiento y diseño consistente para pantallas administrativas.
///
/// Arquitectura Camaleónica y Adaptabilidad Multi-dispositivo:
/// - **Mobile (< 640px)**: Fila independiente de 44dp estilo Apple HIG.
/// - **Tablet (640px – 1024px)**: Layout híbrido en 2 niveles equilibrados.
/// - **Desktop (>= 1024px)**: Barra unificada de alta densidad estilo Linear/Stripe (40dp).
class AdminProToolbar extends StatefulWidget {
  final TextEditingController searchController;
  final FocusNode? searchFocusNode;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onClearSearch;
  final ValueChanged<String>? onSearchSubmitted;
  final String? searchKeyHint;
  final int searchFlex;

  final List<Widget> filterWidgets;
  final AdminProViewToggleConfig? viewToggleConfig;
  final VoidCallback? onRefresh;
  final String refreshTooltip;
  final AdminProToolbarAction? primaryAction;
  final List<Widget>? trailingActions;

  /// Fila secundaria opcional para interfaces densas de dos niveles (ej. Catálogo de Productos)
  final Widget? secondaryRow;

  final bool? isDesktop;
  final bool? isTablet;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  /// Si es true, oculta el botón de acción principal (CTA) en vista móvil (<640px)
  final bool hidePrimaryActionOnMobile;

  /// Conteo opcional de filtros actualmente activos para renderizar el badge semántico.
  final int? activeFiltersCount;

  /// Filtros descritos como datos.
  final List<AdminFilterGroup<dynamic>> filterGroups;

  /// Widgets extra que solo viven en el sheet móvil (ej. selector de fechas).
  final List<Widget> mobileExtraFilters;

  /// Texto del botón principal del sheet de filtros (ej. 'Listo', 'Ver resultados').
  final String mobileFiltersApplyLabel;

  /// Callback para abrir un BottomSheet personalizado de filtros en móvil.
  final VoidCallback? onOpenMobileFilters;

  /// Callback opcional para limpiar todos los filtros en el BottomSheet de móvil.
  final VoidCallback? onClearFilters;

  /// Constructor opcional para renderizar un BottomSheet de filtros en móvil.
  final WidgetBuilder? mobileFiltersSheetBuilder;

  /// Título para el BottomSheet modal de filtros en móvil.
  final String mobileFiltersTitle;

  /// Título para el BottomSheet modal de acciones secundarias (Importar/Exportar) en móvil.
  final String mobileActionsTitle;

  /// Activa o desactiva el motor de atajos de teclado con aislamiento de foco.
  final bool enableKeyboardShortcuts;

  /// Si es true (por defecto), la búsqueda se activa únicamente al presionar Enter,
  /// pulsar el botón "Buscar" o limpiar el texto, evitando búsquedas prematuras por tecla.
  final bool searchOnSubmitOnly;

  /// Callback opcional para escanear código de barras o QR desde el buscador.
  final VoidCallback? onScanBarcode;

  /// Tooltip del botón de escaneo de código.
  final String scanBarcodeTooltip;

  /// Si es true, el botón de refresco entra en animación giratoria continua
  final bool isLoading;

  const AdminProToolbar({
    super.key,
    required this.searchController,
    this.searchFocusNode,
    this.searchHint = 'Buscar...',
    this.onSearchChanged,
    this.onClearSearch,
    this.onSearchSubmitted,
    this.searchKeyHint = '/',
    this.searchFlex = 5,
    this.filterWidgets = const [],
    this.viewToggleConfig,
    this.onRefresh,
    this.refreshTooltip = 'Actualizar',
    this.primaryAction,
    this.trailingActions,
    this.secondaryRow,
    this.isDesktop,
    this.isTablet,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.hidePrimaryActionOnMobile = true,
    this.activeFiltersCount,
    this.filterGroups = const [],
    this.mobileExtraFilters = const [],
    this.mobileFiltersApplyLabel = 'Listo',
    this.onOpenMobileFilters,
    this.onClearFilters,
    this.mobileFiltersSheetBuilder,
    this.mobileFiltersTitle = 'Filtros de Búsqueda',
    this.mobileActionsTitle = 'Opciones y Herramientas',
    this.enableKeyboardShortcuts = true,
    this.searchOnSubmitOnly = true,
    this.onScanBarcode,
    this.scanBarcodeTooltip = 'Escanear código (QR / Barras)',
    this.isLoading = false,
  });

  @override
  State<AdminProToolbar> createState() => _AdminProToolbarState();
}

class _AdminProToolbarState extends State<AdminProToolbar> {
  late final FocusNode _internalSearchFocusNode = FocusNode();

  FocusNode get _effectiveSearchFocusNode =>
      widget.searchFocusNode ?? _internalSearchFocusNode;

  late final ValueNotifier<FiltersSnapshot> _filtersSnapshot = ValueNotifier(
    _createSnapshot(),
  );

  FiltersSnapshot _createSnapshot() {
    return FiltersSnapshot(
      groups: widget.filterGroups,
      extras: widget.mobileExtraFilters,
      legacyWidgets: widget.filterWidgets,
      applyLabel: widget.mobileFiltersApplyLabel,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.enableKeyboardShortcuts) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
  }

  @override
  void didUpdateWidget(covariant AdminProToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.enableKeyboardShortcuts != oldWidget.enableKeyboardShortcuts) {
      if (widget.enableKeyboardShortcuts) {
        HardwareKeyboard.instance.addHandler(_handleKeyEvent);
      } else {
        HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
      }
    }

    if (!_areFiltersEqual(oldWidget, widget)) {
      _filtersSnapshot.value = _createSnapshot();
    }
  }

  bool _areFiltersEqual(AdminProToolbar a, AdminProToolbar b) {
    return a.filterGroups == b.filterGroups &&
        a.mobileExtraFilters == b.mobileExtraFilters &&
        a.filterWidgets == b.filterWidgets &&
        a.mobileFiltersApplyLabel == b.mobileFiltersApplyLabel;
  }

  @override
  void dispose() {
    if (widget.enableKeyboardShortcuts) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    _internalSearchFocusNode.dispose();
    _filtersSnapshot.dispose();
    super.dispose();
  }

  int get _effectiveActiveFilters =>
      widget.activeFiltersCount ??
      widget.filterGroups.where((g) => g.isActive).length;

  bool get _hasFilters =>
      widget.filterGroups.isNotEmpty ||
      widget.mobileExtraFilters.isNotEmpty ||
      widget.filterWidgets.isNotEmpty ||
      widget.onOpenMobileFilters != null ||
      widget.mobileFiltersSheetBuilder != null;

  void _openFilters() {
    if (widget.onOpenMobileFilters != null) {
      widget.onOpenMobileFilters!();
    } else if (widget.mobileFiltersSheetBuilder != null) {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: widget.mobileFiltersSheetBuilder!,
      );
    } else {
      _showDefaultMobileFiltersSheet(context);
    }
  }

  void _showDefaultMobileFiltersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => AdminFiltersSheet(
            title: widget.mobileFiltersTitle,
            snapshot: _filtersSnapshot,
            onClearAll: widget.onClearFilters,
          ),
    );
  }

  bool _isTextInputActive() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final context = primaryFocus.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _executeSearch([String? query]) {
    final text = query ?? widget.searchController.text;
    final trimmed = text.trim();
    widget.onSearchSubmitted?.call(trimmed);
    widget.onSearchChanged?.call(trimmed);
  }

  void _handleClearSearch() {
    widget.searchController.clear();
    if (widget.onClearSearch != null) {
      widget.onClearSearch!();
    } else {
      _executeSearch('');
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    if (_isTextInputActive()) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (widget.searchController.text.isNotEmpty) {
          _handleClearSearch();
        }
        FocusManager.instance.primaryFocus?.unfocus();
        return true;
      }
      return false;
    }

    final isAlt = HardwareKeyboard.instance.isAltPressed;

    if (event.logicalKey == LogicalKeyboardKey.slash ||
        (isAlt && event.logicalKey == LogicalKeyboardKey.slash)) {
      _effectiveSearchFocusNode.requestFocus();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.searchController.text.isNotEmpty) {
        _handleClearSearch();
        return true;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.keyR) {
      if (widget.onRefresh != null) {
        AppFeedbackService.selectionClick();
        widget.onRefresh!();
        return true;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      if (widget.primaryAction != null) {
        AppFeedbackService.lightImpact();
        widget.primaryAction!.onPressed();
        return true;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      if (widget.viewToggleConfig != null) {
        AppFeedbackService.selectionClick();
        widget.viewToggleConfig!.onToggleTableView(
          !widget.viewToggleConfig!.isTableView,
        );
        return true;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      if (_hasFilters) {
        _openFilters();
        return true;
      }
    }

    return false;
  }

  List<Widget> get _desktopFilters =>
      widget.filterWidgets.isNotEmpty
          ? widget.filterWidgets
          : [
            for (final g in widget.filterGroups) AdminFilterDropdown(group: g),
            ...widget.mobileExtraFilters,
          ];

  // ── 1. DESKTOP LAYOUT (ALTA DENSIDAD, 1 FILA) ─────────────────────────────
  Widget _buildDesktopLayout() {
    final primaryRow = Row(
      children: [
        Expanded(
          flex: widget.searchFlex,
          child: AdminDesktopSearchField(
            controller: widget.searchController,
            focusNode: _effectiveSearchFocusNode,
            hintText: widget.searchHint,
            searchKeyHint: widget.searchKeyHint,
            searchOnSubmitOnly: widget.searchOnSubmitOnly,
            onSearchChanged: widget.onSearchChanged,
            onSearchSubmitted: widget.onSearchSubmitted,
            onClearSearch: _handleClearSearch,
            onScanBarcode: widget.onScanBarcode,
            scanBarcodeTooltip: widget.scanBarcodeTooltip,
          ),
        ),
        for (final filter in _desktopFilters) ...[
          const SizedBox(width: 10),
          filter,
        ],
        if (widget.viewToggleConfig != null) ...[
          const SizedBox(width: 10),
          AdminProViewToggle(config: widget.viewToggleConfig!),
        ],
        if (widget.onRefresh != null) ...[
          const SizedBox(width: 8),
          RepaintBoundary(
            child: AdminProRefreshButton(
              onRefresh: widget.onRefresh,
              tooltip: widget.refreshTooltip,
              isDesktop: true,
              isLoading: widget.isLoading,
            ),
          ),
        ],
        if (widget.trailingActions != null)
          for (final action in widget.trailingActions!) ...[
            const SizedBox(width: 8),
            action,
          ],
        if (widget.primaryAction != null) ...[
          const SizedBox(width: 8),
          AdminProPrimaryButton(action: widget.primaryAction!, isMobile: false),
        ],
      ],
    );

    if (widget.secondaryRow == null) {
      return primaryRow;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [primaryRow, const SizedBox(height: 12), widget.secondaryRow!],
    );
  }

  // ── 2. TABLET LAYOUT (2 NIVELES EQUILIBRADOS) ─────────────────────────────
  Widget _buildTabletLayout() {
    final showToggleOnTablet =
        widget.viewToggleConfig != null &&
        widget.viewToggleConfig!.showOnTablet;
    final hasSecondaryItems =
        _desktopFilters.isNotEmpty ||
        showToggleOnTablet ||
        widget.onRefresh != null ||
        (widget.trailingActions != null && widget.trailingActions!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: AdminDesktopSearchField(
                controller: widget.searchController,
                focusNode: _effectiveSearchFocusNode,
                hintText: widget.searchHint,
                searchKeyHint: widget.searchKeyHint,
                searchOnSubmitOnly: widget.searchOnSubmitOnly,
                onSearchChanged: widget.onSearchChanged,
                onSearchSubmitted: widget.onSearchSubmitted,
                onClearSearch: _handleClearSearch,
                onScanBarcode: widget.onScanBarcode,
                scanBarcodeTooltip: widget.scanBarcodeTooltip,
              ),
            ),
            if (widget.primaryAction != null) ...[
              const SizedBox(width: 10),
              AdminProPrimaryButton(
                action: widget.primaryAction!,
                isMobile: false,
              ),
            ],
          ],
        ),
        if (hasSecondaryItems) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final filter in _desktopFilters) ...[
                        filter,
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              if (showToggleOnTablet) ...[
                const SizedBox(width: 8),
                AdminProViewToggle(config: widget.viewToggleConfig!),
              ],
              if (widget.onRefresh != null) ...[
                const SizedBox(width: 6),
                RepaintBoundary(
                  child: AdminProRefreshButton(
                    onRefresh: widget.onRefresh,
                    tooltip: widget.refreshTooltip,
                    isDesktop: true,
                    isLoading: widget.isLoading,
                  ),
                ),
              ],
              if (widget.trailingActions != null)
                for (final action in widget.trailingActions!) ...[
                  const SizedBox(width: 6),
                  action,
                ],
            ],
          ),
        ],
        if (widget.secondaryRow != null) ...[
          const SizedBox(height: 10),
          widget.secondaryRow!,
        ],
      ],
    );
  }

  // ── 3. MOBILE LAYOUT (FILA COMPACTA 44DP) ─────────────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
    final hasFilters = _hasFilters;
    final hasTrailing =
        widget.trailingActions != null && widget.trailingActions!.isNotEmpty;
    final showToggleOnMobile =
        widget.viewToggleConfig != null &&
        widget.viewToggleConfig!.showOnMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: AdminMobileSearchField(
                controller: widget.searchController,
                focusNode: _effectiveSearchFocusNode,
                hintText: widget.searchHint,
                searchOnSubmitOnly: widget.searchOnSubmitOnly,
                onSearchChanged: widget.onSearchChanged,
                onSearchSubmitted: widget.onSearchSubmitted,
                onClearSearch: _handleClearSearch,
                onScanBarcode: widget.onScanBarcode,
                scanBarcodeTooltip: widget.scanBarcodeTooltip,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(width: 8),
              AdminMobileFiltersTriggerButton(
                activeCount: _effectiveActiveFilters,
                onOpenFilters: _openFilters,
              ),
            ],
            if (showToggleOnMobile) ...[
              const SizedBox(width: 8),
              AdminProViewToggle(config: widget.viewToggleConfig!),
            ],
            if (hasTrailing) ...[
              const SizedBox(width: 8),
              AdminMobileTrailingActionsButton(
                title: widget.mobileActionsTitle,
                trailingActions: widget.trailingActions!,
              ),
            ],
            if (widget.onRefresh != null) ...[
              const SizedBox(width: 8),
              RepaintBoundary(
                child: AdminMobileRefreshButtonContainer(
                  onRefresh: widget.onRefresh,
                  tooltip: widget.refreshTooltip,
                  isLoading: widget.isLoading,
                ),
              ),
            ],
          ],
        ),
        if (!widget.hidePrimaryActionOnMobile &&
            widget.primaryAction != null) ...[
          const SizedBox(height: 10),
          AdminProPrimaryButton(action: widget.primaryAction!, isMobile: true),
        ],
        if (widget.secondaryRow != null) ...[
          const SizedBox(height: 10),
          widget.secondaryRow!,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bool useDesktopLayout = widget.isDesktop ?? (width >= 1024);
    final bool useTabletLayout =
        widget.isTablet ?? (!useDesktopLayout && (width >= 640));

    if (!useDesktopLayout && !useTabletLayout) {
      return RepaintBoundary(
        child: Padding(
          padding: widget.margin,
          child: _buildMobileLayout(context),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(useDesktopLayout ? 14 : 16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : const Color(0x050F172A),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: useDesktopLayout ? _buildDesktopLayout() : _buildTabletLayout(),
      ),
    );
  }
}
