import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
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

/// Opción individual de un grupo de filtros.
class AdminFilterOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;

  const AdminFilterOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });
}

/// Grupo de filtros descrito como DATOS (no como widgets).
///
/// Con esto el toolbar puede dibujar el mismo filtro como dropdown en desktop
/// y como chips dentro del bottom sheet en móvil, y el sheet se mantiene
/// sincronizado con el estado de la pantalla.
class AdminFilterGroup<T> {
  final String title;
  final IconData? icon;
  final List<AdminFilterOption<T>> options;
  final T selected;

  /// Valor que significa "sin filtro" (ej. 'ALL', null). Sirve para el badge
  /// de filtros activos y para el botón "Limpiar".
  final T defaultValue;
  final ValueChanged<T> onSelected;

  /// Forma en que se presenta el filtro en el BottomSheet móvil:
  /// - [AdminFilterDisplayType.auto]: si tiene <= 4 opciones usa chips, si tiene más usa select.
  /// - [AdminFilterDisplayType.chips]: siempre chips.
  /// - [AdminFilterDisplayType.select]: siempre menú/select desplegable.
  final AdminFilterDisplayType displayType;

  const AdminFilterGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.defaultValue,
    required this.onSelected,
    this.icon,
    this.displayType = AdminFilterDisplayType.auto,
  });

  bool get isActive => selected != defaultValue;

  /// Invoca [onSelected] de forma segura evitando problemas de covarianza
  /// en tipos de funciones Dart cuando el grupo está tipado como [dynamic].
  void select(dynamic value) {
    onSelected(value as T);
  }

  /// Restablece el filtro al valor por defecto.
  void reset() {
    onSelected(defaultValue);
  }

  /// Comprueba si la opción dada está actualmente seleccionada.
  bool isSelected(dynamic value) => selected == value;

  String get selectedLabel {
    for (final o in options) {
      if (o.value == selected) return o.label;
    }
    return title;
  }
}

/// Modo de visualización de un grupo de filtros en el modal bottom sheet de móvil.
enum AdminFilterDisplayType {
  /// Si tiene <= 4 opciones se muestra como chips horizontales; si tiene más, como select desplegable.
  auto,

  /// Siempre como chips envueltos (Wrap). Ideal para opciones cortas y rápidas (ej. Estado, Stock).
  chips,

  /// Siempre como selector desplegable estilizado. Ideal para listas largas (ej. Categorías, Marcas, Ordenar por).
  select,
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

  /// Filtros descritos como datos. Si se usan, el sheet móvil por defecto los
  /// dibuja como chips con estado en vivo. [filterWidgets] sigue funcionando
  /// para desktop/tablet y como respaldo.
  final List<AdminFilterGroup<dynamic>> filterGroups;

  /// Widgets extra que solo viven en el sheet móvil (ej. selector de fechas).
  final List<Widget> mobileExtraFilters;

  /// Texto del botón principal del sheet de filtros (ej. 'Ver 19 resultados').
  final String mobileFiltersApplyLabel;

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

  /// Callback opcional para escanear código de barras o QR desde el buscador.
  final VoidCallback? onScanBarcode;

  /// Tooltip del botón de escaneo de código.
  final String scanBarcodeTooltip;

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
  });

  @override
  State<AdminProToolbar> createState() => _AdminProToolbarState();
}

class _AdminProToolbarState extends State<AdminProToolbar> {
  late final FocusNode _internalSearchFocusNode = FocusNode();

  FocusNode get _effectiveSearchFocusNode =>
      widget.searchFocusNode ?? _internalSearchFocusNode;

  /// Copia de los filtros que el sheet escucha. Se actualiza cada vez que la
  /// pantalla reconstruye el toolbar, así el sheet nunca queda desfasado.
  late final ValueNotifier<_FiltersSnapshot> _filtersSnapshot = ValueNotifier(
    _FiltersSnapshot.from(widget),
  );

  @override
  void didUpdateWidget(covariant AdminProToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _FiltersSnapshot.from(widget);
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
        AppFeedbackService.selectionClick();
        widget.onRefresh!();
        return true;
      }
    }

    // 4. Atajo [N] o [Alt+N] -> Acción principal (Crear)
    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      if (widget.primaryAction != null) {
        AppFeedbackService.lightImpact();
        widget.primaryAction!.onPressed();
        return true;
      }
    }

    // 5. Atajo [V] o [Alt+V] -> Alternar vista Tabla / Tarjetas
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      if (widget.viewToggleConfig != null) {
        AppFeedbackService.selectionClick();
        widget.viewToggleConfig!.onToggleTableView(
          !widget.viewToggleConfig!.isTableView,
        );
        return true;
      }
    }

    // 6. Atajo [F] o [Alt+F] -> Filtros
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
                  AppFeedbackService.selectionClick();
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
                  AppFeedbackService.selectionClick();
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

  // ── BOTÓN DE FILTROS AGRUPADOS PARA MÓVIL (STANDALONE 44X44 ESTILO PRODUCTS)
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
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _AdminFiltersSheet(
            title: widget.mobileFiltersTitle,
            snapshot: _filtersSnapshot,
            onClearAll: widget.onClearFilters,
          ),
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

  /// Filtros para desktop/tablet: los widgets manuales tienen prioridad;
  /// si no hay, se generan dropdowns desde [AdminProToolbar.filterGroups].
  List<Widget> get _desktopFilters =>
      widget.filterWidgets.isNotEmpty
          ? widget.filterWidgets
          : [
            for (final g in widget.filterGroups) _AdminFilterDropdown(group: g),
            ...widget.mobileExtraFilters,
          ];

  // ── 1. DESKTOP LAYOUT (POWER-USER ERP, HIGH-DENSITY SINGLE ROW) ───────────
  Widget _buildDesktopLayout() {
    final primaryRow = Row(
      children: [
        // 1. Buscador expandido
        Expanded(flex: widget.searchFlex, child: _buildDesktopSearchField()),

        // 2. Filtros centrales modulares
        for (final filter in _desktopFilters) ...[
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
        _desktopFilters.isNotEmpty ||
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
    AppFeedbackService.selectionClick();
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

// ════════════════════════════════════════════════════════════════════════════
//  FILTROS: snapshot, dropdown de desktop y bottom sheet de móvil
// ════════════════════════════════════════════════════════════════════════════

class _FiltersSnapshot {
  final List<AdminFilterGroup<dynamic>> groups;
  final List<Widget> extras;
  final List<Widget> legacyWidgets;
  final String applyLabel;

  const _FiltersSnapshot({
    required this.groups,
    required this.extras,
    required this.legacyWidgets,
    required this.applyLabel,
  });

  factory _FiltersSnapshot.from(AdminProToolbar w) => _FiltersSnapshot(
    groups: w.filterGroups,
    extras: w.mobileExtraFilters,
    legacyWidgets: w.filterWidgets,
    applyLabel: w.mobileFiltersApplyLabel,
  );
}

/// Dropdown de desktop/tablet generado desde un [AdminFilterGroup].
class _AdminFilterDropdown extends StatelessWidget {
  final AdminFilterGroup<dynamic> group;
  const _AdminFilterDropdown({required this.group});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = group.isActive;
    final accent = isDark ? const Color(0xFF2DD4BF) : AppColors.teal;

    return PopupMenuButton<int>(
      tooltip: group.title,
      offset: const Offset(0, 44),
      color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      onSelected: (i) => group.select(group.options[i].value),
      itemBuilder:
          (_) => [
            for (var i = 0; i < group.options.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    Icon(
                      group.options[i].icon ??
                          (group.options[i].value == group.selected
                              ? Icons.check_rounded
                              : Icons.circle_outlined),
                      size: 16,
                      color: group.options[i].color ?? AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      group.options[i].label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            group.options[i].value == group.selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                        color: group.options[i].color,
                      ),
                    ),
                  ],
                ),
              ),
          ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              active
                  ? accent.withValues(alpha: isDark ? 0.18 : 0.10)
                  : (isDark ? AppColors.darkSurfaceElevated : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                active
                    ? accent
                    : (isDark
                        ? AppColors.darkBorderSubtle
                        : const Color(0xFFCBD5E1)),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              group.icon ?? Icons.filter_list_rounded,
              size: 15,
              color: active ? accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              active ? group.selectedLabel : group.title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color:
                    active
                        ? (isDark ? accent : AppColors.tealDark)
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? accent : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet de filtros: chips agrupados, estado en vivo, sin menús
/// flotantes encima. Se redibuja cuando la pantalla reconstruye el toolbar.
class _AdminFiltersSheet extends StatelessWidget {
  final String title;
  final ValueNotifier<_FiltersSnapshot> snapshot;
  final VoidCallback? onClearAll;

  const _AdminFiltersSheet({
    required this.title,
    required this.snapshot,
    this.onClearAll,
  });

  void _clear(_FiltersSnapshot s) {
    AppFeedbackService.selectionClick();
    if (onClearAll != null) {
      onClearAll!();
      return;
    }
    for (final g in s.groups) {
      if (g.isActive) g.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ValueListenableBuilder<_FiltersSnapshot>(
        valueListenable: snapshot,
        builder: (context, s, _) {
          final activeCount = s.groups.where((g) => g.isActive).length;
          final hasGroups = s.groups.isNotEmpty;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (activeCount > 0 || onClearAll != null)
                      TextButton(
                        onPressed: () => _clear(s),
                        child: const Text(
                          'Limpiar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: AppColors.textMuted,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final g in s.groups) _FilterGroupSection(group: g),
                      // Respaldo: filtros antiguos como widgets
                      if (!hasGroups)
                        for (final w in s.legacyWidgets)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: w,
                          ),
                      for (final w in s.extras)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: w,
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    s.applyLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterGroupSection extends StatelessWidget {
  final AdminFilterGroup<dynamic> group;
  const _FilterGroupSection({required this.group});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool useSelect =
        group.displayType == AdminFilterDisplayType.select ||
        (group.displayType == AdminFilterDisplayType.auto &&
            group.options.length > 4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.textMuted,
                ),
              ),
              if (group.isActive) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (useSelect)
            _AdminFilterSelectField(group: group, isDark: isDark)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in group.options)
                  _FilterChip(
                    option: o,
                    selected: group.isSelected(o.value),
                    isDark: isDark,
                    onTap: () {
                      AppFeedbackService.selectionClick();
                      group.select(o.value);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Selector desplegable moderno y estilizado para móvil cuando una lista de filtros
/// tiene muchas opciones (ej. Categorías con 10+ elementos) evitando un muro de chips.
class _AdminFilterSelectField extends StatelessWidget {
  final AdminFilterGroup<dynamic> group;
  final bool isDark;

  const _AdminFilterSelectField({required this.group, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final active = group.isActive;
    final accent = isDark ? const Color(0xFF60A5FA) : AppColors.primary;

    return PopupMenuButton<int>(
      tooltip: 'Seleccionar ${group.title}',
      offset: const Offset(0, 48),
      color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      onSelected: (i) {
        AppFeedbackService.selectionClick();
        group.select(group.options[i].value);
      },
      itemBuilder:
          (ctx) => [
            for (var i = 0; i < group.options.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    Icon(
                      group.isSelected(group.options[i].value)
                          ? Icons.check_circle_rounded
                          : (group.options[i].icon ?? Icons.circle_outlined),
                      size: 18,
                      color:
                          group.isSelected(group.options[i].value)
                              ? accent
                              : (group.options[i].color ??
                                  AppColors.textSecondary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.options[i].label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              group.isSelected(group.options[i].value)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                          color:
                              group.isSelected(group.options[i].value)
                                  ? (isDark
                                      ? Colors.white
                                      : AppColors.textPrimary)
                                  : (group.options[i].color ??
                                      (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color:
              active
                  ? accent.withValues(alpha: isDark ? 0.16 : 0.08)
                  : (isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.background),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                active
                    ? accent
                    : (isDark ? AppColors.darkBorder : AppColors.border),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (group.icon != null) ...[
              Icon(
                group.icon,
                size: 18,
                color: active ? accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                group.selectedLabel,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color:
                      active
                          ? (isDark ? accent : AppColors.primary)
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: active ? accent : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final AdminFilterOption<dynamic> option;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.option,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = option.color ?? AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color:
                selected
                    ? accent.withValues(alpha: isDark ? 0.22 : 0.10)
                    : (isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.background),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected
                      ? accent
                      : (isDark ? AppColors.darkBorder : AppColors.border),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                Icon(Icons.check_rounded, size: 15, color: accent)
              else if (option.icon != null)
                Icon(
                  option.icon,
                  size: 15,
                  color: accent.withValues(alpha: 0.8),
                ),
              if (selected || option.icon != null) const SizedBox(width: 6),
              Text(
                option.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color:
                      selected
                          ? accent
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
