import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Configuración para la acción principal del toolbar (CTA).
/// El atajo de teclado [keyHint] se muestra exclusivamente en el Tooltip (tooltext).
class AdminProToolbarAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String? keyHint;
  final bool isHighlighted;
  final Color? highlightColor;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AdminProToolbarAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.keyHint = 'N',
    this.isHighlighted = false,
    this.highlightColor,
    this.backgroundColor,
    this.foregroundColor,
  });
}

/// Configuración para alternar vistas (Tabla vs Tarjetas / Grid).
class AdminProViewToggleConfig {
  final bool isTableView;
  final ValueChanged<bool> onToggleTableView;
  final String tableTooltip;
  final String cardsTooltip;
  final Color? activeColor;
  final IconData tableIcon;
  final IconData cardsIcon;
  final bool showOnMobile;
  final bool showOnTablet;

  const AdminProViewToggleConfig({
    required this.isTableView,
    required this.onToggleTableView,
    this.tableTooltip = 'Vista en Tabla',
    this.cardsTooltip = 'Vista en Tarjetas',
    this.activeColor,
    this.tableIcon = Icons.table_rows_rounded,
    this.cardsIcon = Icons.grid_view_rounded,
    this.showOnMobile = false,
    this.showOnTablet = true,
  });
}

/// Toolbar Pro Unificado de alto rendimiento y diseño consistente para pantallas administrativas.
///
/// Arquitectura Camaleónica y Adaptabilidad Multi-dispositivo:
/// - **Mobile (< 640px)**: Idéntico a Products Command Bar (Apple HIG):
///   Buscador independiente de 44dp, botón de filtros agrupados 44x44 con badge numérico que abre
///   el Modal Bottom Sheet, botón de más acciones/exportación 44x44, botón de refresco 44x44
///   y el CTA de creación oculto por defecto (`hidePrimaryActionOnMobile = true`) para delegar
///   la creación al FAB de la zona del pulgar.
/// - **Tablet (640px – 1024px)**: Layout híbrido en 2 niveles equilibrados (Fila 1: Búsqueda + CTA,
///   Fila 2: Filtros modulares + Toggle de Vista + Trailing + Refresco).
/// - **Desktop (>= 1024px)**: Barra de comandos unificada de alta densidad estilo Linear/Stripe (40dp)
///   con alineación horizontal, micro-interacciones hover y cursores explícitos.
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

  /// Callback para abrir un BottomSheet personalizado de filtros en móvil (ej. ProductsMobileFiltersSheet).
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
    this.onOpenMobileFilters,
    this.onClearFilters,
    this.mobileFiltersSheetBuilder,
    this.mobileFiltersTitle = 'Filtros de Búsqueda',
    this.mobileActionsTitle = 'Opciones y Herramientas',
    this.enableKeyboardShortcuts = true,
    this.searchOnSubmitOnly = true,
  });

  @override
  State<AdminProToolbar> createState() => _AdminProToolbarState();
}

class _AdminProToolbarState extends State<AdminProToolbar> {
  late final FocusNode _internalSearchFocusNode = FocusNode();

  FocusNode get _effectiveSearchFocusNode =>
      widget.searchFocusNode ?? _internalSearchFocusNode;

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
    super.dispose();
  }

  // ── MOTOR DE AISLAMIENTO DE FOCO Y ATAJOS DE TECLADO ──────────────────────
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

    final isInputActive = _isTextInputActive();

    // Si el usuario está escribiendo activamente dentro de un campo de texto:
    if (isInputActive) {
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

    // 1. Atajo [/] o [Alt+/] -> Enfocar buscador
    if (event.logicalKey == LogicalKeyboardKey.slash ||
        (isAlt && event.logicalKey == LogicalKeyboardKey.slash)) {
      _effectiveSearchFocusNode.requestFocus();
      return true;
    }

    // 2. Atajo [Esc] -> Limpiar búsqueda
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.searchController.text.isNotEmpty) {
        _handleClearSearch();
        return true;
      }
    }

    // 3. Atajo [R] o [Alt+R] -> Refrescar datos
    if (event.logicalKey == LogicalKeyboardKey.keyR) {
      if (widget.onRefresh != null) {
        HapticFeedback.selectionClick();
        widget.onRefresh!();
        return true;
      }
    }

    // 4. Atajo [N] o [Alt+N] -> Acción principal (Crear)
    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      if (widget.primaryAction != null) {
        HapticFeedback.lightImpact();
        widget.primaryAction!.onPressed();
        return true;
      }
    }

    // 5. Atajo [V] o [Alt+V] -> Alternar vista Tabla / Tarjetas
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      if (widget.viewToggleConfig != null) {
        HapticFeedback.selectionClick();
        widget.viewToggleConfig!.onToggleTableView(
          !widget.viewToggleConfig!.isTableView,
        );
        return true;
      }
    }

    // 6. Atajo [F] o [Alt+F] -> Filtros
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      if (widget.onOpenMobileFilters != null) {
        widget.onOpenMobileFilters!();
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
                    Tooltip(
                      message: 'Buscar (Atajo: Enter)',
                      waitDuration: const Duration(milliseconds: 400),
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
                                        : AppColors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      isDark
                                          ? const Color(
                                            0xFF60A5FA,
                                          ).withValues(alpha: 0.4)
                                          : AppColors.teal.withValues(
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
                                            ? const Color(0xFF60A5FA)
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
                                              ? const Color(0xFF60A5FA)
                                              : AppColors.tealDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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

  // ── BUSCADOR DE MÓVIL (STANDALONE 44DP ESTILO PRODUCTS) ───────────────────
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
                      HapticFeedback.lightImpact();
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

  // ── TOGGLE DE VISTA SEGMENTADO ESTILO LINEAR / APPLE ──────────────────────
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Tooltip(
              message: '${config.tableTooltip} (Atajo: V)',
              waitDuration: const Duration(milliseconds: 300),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  config.onToggleTableView(true);
                },
                borderRadius: BorderRadius.circular(7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        config.isTableView
                            ? (isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.surface)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow:
                        config.isTableView
                            ? [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.06,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                            : null,
                  ),
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
            const SizedBox(width: 2),
            Tooltip(
              message: '${config.cardsTooltip} (Atajo: V)',
              waitDuration: const Duration(milliseconds: 300),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  config.onToggleTableView(false);
                },
                borderRadius: BorderRadius.circular(7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        !config.isTableView
                            ? (isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.surface)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow:
                        !config.isTableView
                            ? [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.06,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                            : null,
                  ),
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
          ],
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
              HapticFeedback.lightImpact();
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

  // ── BOTÓN DE FILTROS AGRUPADOS PARA MÓVIL (STANDALONE 44X44 ESTILO PRODUCTS)
  Widget _buildMobileFiltersTriggerButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.activeFiltersCount ?? 0;
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
              HapticFeedback.lightImpact();
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
        if (hasActive)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
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
            ),
          ),
      ],
    );
  }

  // ── MODAL BOTTOM SHEET DE FILTROS POR DEFECTO PARA MÓVIL ──────────────────
  void _showDefaultMobileFiltersSheet(BuildContext context) {
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
                      Text(
                        widget.mobileFiltersTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.onClearFilters != null)
                        TextButton(
                          onPressed: () {
                            widget.onClearFilters!();
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Limpiar Todo',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppColors.textMuted,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                    ],
                  ),
                  const Divider(color: AppColors.divider, height: 20),
                  for (final filter in widget.filterWidgets) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: filter,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Aplicar Filtros',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── BOTÓN DE ACCIONES SECUNDARIAS (STANDALONE 44X44 ESTILO PRODUCTS) ──────
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

  // ── BOTÓN DE REFRESCO STANDALONE 44X44 EN MÓVIL ───────────────────────────
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
      child: _AdminProRefreshButton(
        onRefresh: widget.onRefresh,
        tooltip: widget.refreshTooltip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bool useDesktopLayout = widget.isDesktop ?? (width >= 1024);
    final bool useTabletLayout =
        widget.isTablet ?? (!useDesktopLayout && (width >= 640));

    // ── MÓVIL (< 640px): Fila limpia de botones standalone idéntica a Products ──
    if (!useDesktopLayout && !useTabletLayout) {
      return Padding(
        padding: widget.margin,
        child: _buildMobileLayout(context),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── DESKTOP & TABLET: Barra unificada en tarjeta de superficie ─────────────
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

  // ── 1. DESKTOP LAYOUT (POWER-USER ERP, HIGH-DENSITY SINGLE ROW) ───────────
  Widget _buildDesktopLayout() {
    final primaryRow = Row(
      children: [
        // 1. Buscador expandido
        Expanded(flex: widget.searchFlex, child: _buildDesktopSearchField()),

        // 2. Filtros centrales modulares
        for (final filter in widget.filterWidgets) ...[
          const SizedBox(width: 10),
          filter,
        ],

        // 3. Switch de visualización
        if (widget.viewToggleConfig != null) ...[
          const SizedBox(width: 10),
          _buildViewModeToggle(widget.viewToggleConfig!),
        ],

        // 4. Botón de refresco con rotación interactiva
        if (widget.onRefresh != null) ...[
          const SizedBox(width: 8),
          _AdminProRefreshButton(
            onRefresh: widget.onRefresh,
            tooltip: widget.refreshTooltip,
          ),
        ],

        // 5. Acciones extra opcionales (ej: Exportar, Importar)
        if (widget.trailingActions != null)
          for (final action in widget.trailingActions!) ...[
            const SizedBox(width: 8),
            action,
          ],

        // 6. Botón de acción principal (CTA)
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

  // ── 2. TABLET LAYOUT (EFICIENCIA HÍBRIDA EN 2 NIVELES EQUILIBRADOS) ───────
  Widget _buildTabletLayout() {
    final showToggleOnTablet =
        widget.viewToggleConfig != null &&
        widget.viewToggleConfig!.showOnTablet;
    final hasSecondaryItems =
        widget.filterWidgets.isNotEmpty ||
        showToggleOnTablet ||
        widget.onRefresh != null ||
        (widget.trailingActions != null && widget.trailingActions!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila 1: Buscador expandido + CTA destacado a la derecha
        Row(
          children: [
            Expanded(child: _buildDesktopSearchField()),
            if (widget.primaryAction != null) ...[
              const SizedBox(width: 10),
              _buildPrimaryActionButton(widget.primaryAction!, isMobile: false),
            ],
          ],
        ),
        // Fila 2: Filtros modulares + Toggle de vista + Refresco + Trailing
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
                      for (final filter in widget.filterWidgets) ...[
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
                _AdminProRefreshButton(
                  onRefresh: widget.onRefresh,
                  tooltip: widget.refreshTooltip,
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

  // ── 3. MOBILE LAYOUT (APPLE HIG, STANDALONE ROW, CTA DELEGADO AL FAB) ────
  Widget _buildMobileLayout(BuildContext context) {
    final hasFilters =
        widget.filterWidgets.isNotEmpty ||
        widget.onOpenMobileFilters != null ||
        widget.mobileFiltersSheetBuilder != null;
    final hasTrailing =
        widget.trailingActions != null && widget.trailingActions!.isNotEmpty;
    final showToggleOnMobile =
        widget.viewToggleConfig != null &&
        widget.viewToggleConfig!.showOnMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila compacta de comandos (44dp de altura táctil)
        Row(
          children: [
            // Buscador expandido
            Expanded(child: _buildMobileSearchField()),

            // Botón de Filtros agrupados (con badge de activos)
            if (hasFilters) ...[
              const SizedBox(width: 8),
              _buildMobileFiltersTriggerButton(context),
            ],

            // Alternador de vista (si habilitado en móvil)
            if (showToggleOnMobile) ...[
              const SizedBox(width: 8),
              _buildViewModeToggle(widget.viewToggleConfig!),
            ],

            // Acciones secundarias (Importar / Exportar colapsadas en menú)
            if (hasTrailing) ...[
              const SizedBox(width: 8),
              _buildMobileTrailingActionsButton(context),
            ],

            // Botón de Refresco
            if (widget.onRefresh != null) ...[
              const SizedBox(width: 8),
              _buildMobileRefreshButton(),
            ],
          ],
        ),

        // CTA Principal en móvil SOLO si se solicita explícitamente no ocultarlo
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
}

/// Botón de refresco con rotación interactiva de 360° al presionar y feedback háptico.
class _AdminProRefreshButton extends StatefulWidget {
  final VoidCallback? onRefresh;
  final String tooltip;

  const _AdminProRefreshButton({this.onRefresh, required this.tooltip});

  @override
  State<_AdminProRefreshButton> createState() => _AdminProRefreshButtonState();
}

class _AdminProRefreshButtonState extends State<_AdminProRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onRefresh == null) return;
    _animCtrl.forward(from: 0.0);
    HapticFeedback.selectionClick();
    widget.onRefresh!();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTooltip =
        widget.tooltip.contains('Atajo')
            ? widget.tooltip
            : '${widget.tooltip} (Atajo: R o Alt+R)';

    return Tooltip(
      message: effectiveTooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: IconButton(
        onPressed: widget.onRefresh != null ? _handleTap : null,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          hoverColor: AppColors.background,
          highlightColor: AppColors.teal.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: RotationTransition(
          turns: _animCtrl,
          child: const Icon(Icons.refresh_rounded, size: 20),
        ),
      ),
    );
  }
}
