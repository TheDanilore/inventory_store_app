import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_filter_dropdown.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_refresh_button.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/models/admin_toolbar_models.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/sheets/admin_filters_sheet.dart';

// Re-exportación completa de la API pública para compatibilidad absoluta
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_filter_chip.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_filter_dropdown.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_refresh_button.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/models/admin_toolbar_models.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/sheets/admin_filter_select_field.dart';
export 'package:inventory_store_app/core/widgets/admin_pro_toolbar/sheets/admin_filters_sheet.dart';

/// Toolbar Pro Unificado de alto rendimiento y diseño consistente para pantallas administrativas.
///
/// Arquitectura Camaleónica y Adaptabilidad Multi-dispositivo:
/// - **Mobile (< 640px)**: Fila independiente de 44dp estilo Apple HIG:
///   Buscador táctil, botón de filtros agrupados con badge numérico, acciones secundarias colapsadas,
///   botón de refresco independiente y CTA de creación delegado al FAB.
/// - **Tablet (640px – 1024px)**: Layout híbrido en 2 niveles equilibrados (Fila 1: Búsqueda + CTA,
///   Fila 2: Filtros modulares + Toggle de Vista + Trailing + Refresco).
/// - **Desktop (>= 1024px)**: Barra unificada de alta densidad estilo Linear/Stripe (40dp)
///   con micro-interacciones hover, cursores explícitos y atajos de teclado.
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
  /// para evitar duplicidad con el FloatingActionButton (FAB) inferior del Scaffold.
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
  /// para comunicar carga en progreso.
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

  /// Snapshot reactivo para sincronización con modal sheet móvil sin re-layouts innecesarios.
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
  void didUpdateWidget(covariant AdminProToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _createSnapshot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _filtersSnapshot.value = next;
      }
    });
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

  @override
  void initState() {
    super.initState();
    if (widget.enableKeyboardShortcuts) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
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

    // Si el usuario escribe en un campo de texto, aislamos los atajos
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

    // [/] o [Alt+/] -> Enfocar buscador
    if (event.logicalKey == LogicalKeyboardKey.slash ||
        (isAlt && event.logicalKey == LogicalKeyboardKey.slash)) {
      _effectiveSearchFocusNode.requestFocus();
      return true;
    }

    // [Esc] -> Limpiar búsqueda
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.searchController.text.isNotEmpty) {
        _handleClearSearch();
        return true;
      }
    }

    // [R] -> Refrescar datos
    if (event.logicalKey == LogicalKeyboardKey.keyR) {
      if (widget.onRefresh != null) {
        AppFeedbackService.selectionClick();
        widget.onRefresh!();
        return true;
      }
    }

    // [N] -> Acción principal (Crear)
    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      if (widget.primaryAction != null) {
        AppFeedbackService.lightImpact();
        widget.primaryAction!.onPressed();
        return true;
      }
    }

    // [V] -> Alternar vista Tabla / Tarjetas
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      if (widget.viewToggleConfig != null) {
        AppFeedbackService.selectionClick();
        widget.viewToggleConfig!.onToggleTableView(
          !widget.viewToggleConfig!.isTableView,
        );
        return true;
      }
    }

    // [F] -> Filtros
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      if (_hasFilters) {
        _openFilters();
        return true;
      }
    }

    return false;
  }

  // ── BUSCADOR DE ESCRITORIO (DENTRO DE BARRA COHESIVA) ─────────────────────
  Widget _buildDesktopSearchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchTooltipMsg =
        widget.searchKeyHint != null && widget.searchKeyHint!.isNotEmpty
            ? 'Buscar (Atajo: ${widget.searchKeyHint} o Alt+${widget.searchKeyHint})'
            : 'Buscar';

    return SizedBox(
      height: 40,
      child: Tooltip(
        message: searchTooltipMsg,
        waitDuration: const Duration(milliseconds: 600),
        child: TextField(
          controller: widget.searchController,
          focusNode: _effectiveSearchFocusNode,
          onChanged: (val) {
            if (widget.searchOnSubmitOnly) {
              if (val.isEmpty) {
                _executeSearch('');
              }
            } else {
              widget.onSearchChanged?.call(val);
            }
          },
          onSubmitted: (val) => _executeSearch(val),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: widget.searchHint,
            hintStyle: TextStyle(
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: isDark ? const Color(0xFF60A5FA) : AppColors.teal,
              size: 19,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.searchController,
              builder: (context, value, _) {
                final hasFocus = _effectiveSearchFocusNode.hasFocus;
                final showSearchBtn = value.text.isNotEmpty || hasFocus;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.cancel_rounded,
                          color: AppColors.textMuted,
                          size: 17,
                        ),
                        tooltip: 'Limpiar búsqueda (Atajo: Esc)',
                        splashRadius: 16,
                        onPressed: _handleClearSearch,
                      ),
                    if (widget.onScanBarcode != null)
                      IconButton(
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 19,
                        ),
                        color:
                            isDark
                                ? const Color(0xFF60A5FA)
                                : AppColors.tealDark,
                        tooltip: widget.scanBarcodeTooltip,
                        splashRadius: 18,
                        onPressed: () {
                          AppFeedbackService.lightImpact();
                          widget.onScanBarcode!();
                        },
                      ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: showSearchBtn ? 1.0 : 0.0,
                        child:
                            showSearchBtn
                                ? Tooltip(
                                  message: 'Buscar (Atajo: Enter)',
                                  waitDuration: const Duration(
                                    milliseconds: 400,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _executeSearch(),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Ink(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? const Color(
                                                      0xFF60A5FA,
                                                    ).withValues(alpha: 0.15)
                                                    : AppColors.teal.withValues(
                                                      alpha: 0.1,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color:
                                                  isDark
                                                      ? const Color(
                                                        0xFF60A5FA,
                                                      ).withValues(alpha: 0.4)
                                                      : AppColors.teal
                                                          .withValues(
                                                            alpha: 0.35,
                                                          ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.search_rounded,
                                                size: 14,
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFF60A5FA,
                                                        )
                                                        : AppColors.tealDark,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Buscar',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      isDark
                                                          ? const Color(
                                                            0xFF60A5FA,
                                                          )
                                                          : AppColors.tealDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                );
              },
            ),
            filled: true,
            fillColor:
                isDark ? AppColors.darkSurfaceElevated : AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF60A5FA) : AppColors.teal,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 0,
            ),
          ),
        ),
      ),
    );
  }

  // ── BUSCADOR DE MÓVIL (STANDALONE 44DP) ────────────────────────────────────
  Widget _buildMobileSearchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: widget.searchController,
        focusNode: _effectiveSearchFocusNode,
        onChanged: (val) {
          if (widget.searchOnSubmitOnly) {
            if (val.isEmpty) {
              _executeSearch('');
            }
          } else {
            widget.onSearchChanged?.call(val);
          }
        },
        onSubmitted: (val) => _executeSearch(val),
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: widget.searchHint,
          hintStyle: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.searchController,
            builder: (context, value, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      splashRadius: 18,
                      onPressed: _handleClearSearch,
                    ),
                  if (widget.onScanBarcode != null)
                    IconButton(
                      icon: Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 20,
                        color:
                            isDark
                                ? const Color(0xFF60A5FA)
                                : AppColors.primary,
                      ),
                      tooltip: widget.scanBarcodeTooltip,
                      splashRadius: 20,
                      onPressed: () {
                        AppFeedbackService.lightImpact();
                        widget.onScanBarcode!();
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color:
                          isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                    ),
                    tooltip: 'Buscar',
                    splashRadius: 20,
                    onPressed: () {
                      AppFeedbackService.lightImpact();
                      _executeSearch();
                    },
                  ),
                ],
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  // ── TOGGLE DE VISTA SEGMENTADO ────────────────────────────────────────────
  Widget _buildViewModeToggle(AdminProViewToggleConfig config) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor =
        config.activeColor ??
        (isDark ? const Color(0xFF60A5FA) : AppColors.tealDark);

    return SizedBox(
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.border,
          ),
        ),
        child: SizedBox(
          width: 76,
          child: Stack(
            children: [
              AnimatedAlign(
                alignment:
                    config.isTableView
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 35,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.08,
                        ),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Tooltip(
                      message: '${config.tableTooltip} (Atajo: V)',
                      waitDuration: const Duration(milliseconds: 300),
                      child: InkWell(
                        onTap: () {
                          AppFeedbackService.selectionClick();
                          config.onToggleTableView(true);
                        },
                        borderRadius: BorderRadius.circular(7),
                        child: Center(
                          child: Icon(
                            config.tableIcon,
                            size: 18,
                            color:
                                config.isTableView
                                    ? activeColor
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Tooltip(
                      message: '${config.cardsTooltip} (Atajo: V)',
                      waitDuration: const Duration(milliseconds: 300),
                      child: InkWell(
                        onTap: () {
                          AppFeedbackService.selectionClick();
                          config.onToggleTableView(false);
                        },
                        borderRadius: BorderRadius.circular(7),
                        child: Center(
                          child: Icon(
                            config.cardsIcon,
                            size: 18,
                            color:
                                !config.isTableView
                                    ? activeColor
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BOTÓN DE ACCIÓN PRINCIPAL (CTA) ───────────────────────────────────────
  Widget _buildPrimaryActionButton(
    AdminProToolbarAction action, {
    required bool isMobile,
  }) {
    final effectiveBgColor =
        action.isHighlighted
            ? (action.highlightColor ?? AppColors.warning)
            : (action.backgroundColor ?? AppColors.primary);
    final effectiveFgColor = action.foregroundColor ?? Colors.white;

    final keyHint = action.keyHint ?? 'N';
    final tooltipMsg = '${action.label} (Atajo: $keyHint o Alt+$keyHint)';

    return Tooltip(
      message: tooltipMsg,
      waitDuration: const Duration(milliseconds: 400),
      child: SizedBox(
        height: isMobile ? 44 : 40,
        child: FilledButton.icon(
          onPressed: () {
            if (isMobile) {
              AppFeedbackService.lightImpact();
            }
            action.onPressed();
          },
          style: FilledButton.styleFrom(
            backgroundColor: effectiveBgColor,
            foregroundColor: effectiveFgColor,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: Icon(action.icon, size: 18),
          label: Text(
            action.label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }

  // ── BOTÓN DE FILTROS AGRUPADOS PARA MÓVIL ─────────────────────────────────
  Widget _buildMobileFiltersTriggerButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = _effectiveActiveFilters;
    final hasActive = count > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color:
                hasActive
                    ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.08)
                    : (isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.surface),
            borderRadius: BorderRadius.circular(AppColors.radius),
            border: Border.all(
              color:
                  hasActive
                      ? (isDark ? const Color(0xFF60A5FA) : AppColors.primary)
                      : (isDark ? AppColors.darkBorder : AppColors.border),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {
              AppFeedbackService.lightImpact();
              _openFilters();
            },
            icon: Icon(
              Icons.tune_rounded,
              size: 20,
              color: hasActive ? AppColors.primary : AppColors.textSecondary,
            ),
            tooltip: 'Filtros (Atajo: F)',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.all(10),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder:
                (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                  child: c,
                ),
            child:
                hasActive
                    ? Container(
                      key: ValueKey(count),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                    : const SizedBox.shrink(key: ValueKey(0)),
          ),
        ),
      ],
    );
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

  // ── BOTÓN DE ACCIONES SECUNDARIAS MÓVIL ───────────────────────────────────
  Widget _buildMobileTrailingActionsButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Tooltip(
        message: widget.mobileActionsTitle,
        waitDuration: const Duration(milliseconds: 300),
        child: IconButton(
          onPressed: () => _showMobileTrailingActionsSheet(context),
          icon: Icon(
            Icons.more_vert_rounded,
            size: 20,
            color:
                isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.all(10),
        ),
      ),
    );
  }

  void _showMobileTrailingActionsSheet(BuildContext context) {
    if (widget.trailingActions == null || widget.trailingActions!.isEmpty) {
      return;
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.more_horiz_rounded,
                            size: 22,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.mobileActionsTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.textMuted,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.divider, height: 20),
                  for (final action in widget.trailingActions!) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: action,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── BOTÓN DE REFRESCO STANDALONE EN MÓVIL ─────────────────────────────────
  Widget _buildMobileRefreshButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AdminProRefreshButton(
        onRefresh: widget.onRefresh,
        tooltip: widget.refreshTooltip,
        isDesktop: false,
        isLoading: widget.isLoading,
      ),
    );
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
        Expanded(flex: widget.searchFlex, child: _buildDesktopSearchField()),
        for (final filter in _desktopFilters) ...[
          const SizedBox(width: 10),
          filter,
        ],
        if (widget.viewToggleConfig != null) ...[
          const SizedBox(width: 10),
          _buildViewModeToggle(widget.viewToggleConfig!),
        ],
        if (widget.onRefresh != null) ...[
          const SizedBox(width: 8),
          AdminProRefreshButton(
            onRefresh: widget.onRefresh,
            tooltip: widget.refreshTooltip,
            isDesktop: true,
            isLoading: widget.isLoading,
          ),
        ],
        if (widget.trailingActions != null)
          for (final action in widget.trailingActions!) ...[
            const SizedBox(width: 8),
            action,
          ],
        if (widget.primaryAction != null) ...[
          const SizedBox(width: 8),
          _buildPrimaryActionButton(widget.primaryAction!, isMobile: false),
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
            Expanded(child: _buildDesktopSearchField()),
            if (widget.primaryAction != null) ...[
              const SizedBox(width: 10),
              _buildPrimaryActionButton(widget.primaryAction!, isMobile: false),
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
                _buildViewModeToggle(widget.viewToggleConfig!),
              ],
              if (widget.onRefresh != null) ...[
                const SizedBox(width: 6),
                AdminProRefreshButton(
                  onRefresh: widget.onRefresh,
                  tooltip: widget.refreshTooltip,
                  isDesktop: true,
                  isLoading: widget.isLoading,
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
            Expanded(child: _buildMobileSearchField()),
            if (hasFilters) ...[
              const SizedBox(width: 8),
              _buildMobileFiltersTriggerButton(context),
            ],
            if (showToggleOnMobile) ...[
              const SizedBox(width: 8),
              _buildViewModeToggle(widget.viewToggleConfig!),
            ],
            if (hasTrailing) ...[
              const SizedBox(width: 8),
              _buildMobileTrailingActionsButton(context),
            ],
            if (widget.onRefresh != null) ...[
              const SizedBox(width: 8),
              _buildMobileRefreshButton(),
            ],
          ],
        ),
        if (!widget.hidePrimaryActionOnMobile &&
            widget.primaryAction != null) ...[
          const SizedBox(height: 10),
          _buildPrimaryActionButton(widget.primaryAction!, isMobile: true),
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
      return Padding(
        padding: widget.margin,
        child: _buildMobileLayout(context),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
    );
  }
}
