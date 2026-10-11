import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Configuración para la acción principal del toolbar (CTA).
/// El atajo de teclado [keyHint] ahora se muestra exclusivamente en el Tooltip (tooltext).
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
    this.tableTooltip = 'Vista en Tabla Pro (Atajo: V)',
    this.cardsTooltip = 'Vista en Tarjetas (Atajo: V)',
    this.activeColor,
    this.tableIcon = Icons.table_rows_rounded,
    this.cardsIcon = Icons.grid_view_rounded,
    this.showOnMobile = false,
    this.showOnTablet = true,
  });
}

/// Toolbar Pro Unificado de alto rendimiento y diseño consistente para pantallas administrativas.
///
/// Arquitectura Camaleónica:
/// - **Mobile (< 640px)**: Ergonomía Apple HIG, buscador amplio (46dp), botón CTA visible
///   prioritario en primera posición y carrusel de filtros táctiles elásticos.
/// - **Tablet (640px – 1024px)**: Layout híbrido en 2 niveles (Fila 1: Búsqueda + CTA,
///   Fila 2: Filtros + Vista + Refresco).
/// - **Desktop (>= 1024px)**: Barra de comandos de alta densidad estilo Linear/Stripe (40dp)
///   con alineación horizontal unificada y micro-interacciones hover.
///
/// Los atajos de teclado ya no se renderizan como badges literales en pantalla,
/// sino limpiamente en el Tooltip contextual (tooltext) al posicionar el cursor.
class AdminProToolbar extends StatelessWidget {
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
    this.refreshTooltip = 'Refrescar datos (Atajo: R)',
    this.primaryAction,
    this.trailingActions,
    this.secondaryRow,
    this.isDesktop,
    this.isTablet,
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 8),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  // ── BUSCADOR LIMPIO CON ATRIBUTO TOOLTEXT ─────────────────────────────────
  Widget _buildSearchField({required bool isMobile}) {
    final searchTooltipMsg =
        searchKeyHint != null && searchKeyHint!.isNotEmpty
            ? 'Buscar (Atajo: $searchKeyHint)'
            : 'Buscar';

    return SizedBox(
      height: isMobile ? 46 : 40,
      child: Tooltip(
        message: searchTooltipMsg,
        waitDuration: const Duration(milliseconds: 600),
        child: TextField(
          controller: searchController,
          focusNode: searchFocusNode,
          onChanged: onSearchChanged,
          onSubmitted: onSearchSubmitted,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: searchHint,
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.teal,
              size: 19,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchController,
              builder: (context, value, _) {
                if (value.text.isNotEmpty) {
                  return IconButton(
                    icon: const Icon(
                      Icons.cancel_rounded,
                      color: AppColors.textMuted,
                      size: 17,
                    ),
                    tooltip: 'Limpiar búsqueda (Atajo: Esc)',
                    onPressed: () {
                      searchController.clear();
                      if (onClearSearch != null) {
                        onClearSearch!();
                      } else if (onSearchChanged != null) {
                        onSearchChanged!('');
                      }
                    },
                  );
                }
                // Limpieza total: sin badges literales en el buscador
                return const SizedBox.shrink();
              },
            ),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
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

  // ── TOGGLE DE VISTA SEGMENTADO ESTILO LINEAR / APPLE ──────────────────────
  Widget _buildViewModeToggle(AdminProViewToggleConfig config) {
    final activeColor = config.activeColor ?? AppColors.tealDark;

    return SizedBox(
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Tooltip(
              message: config.tableTooltip,
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
                            ? AppColors.surface
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow:
                        config.isTableView
                            ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
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
                        config.isTableView ? activeColor : AppColors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Tooltip(
              message: config.cardsTooltip,
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
                            ? AppColors.surface
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow:
                        !config.isTableView
                            ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
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
                        !config.isTableView ? activeColor : AppColors.textMuted,
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

    final tooltipMsg =
        action.keyHint != null && action.keyHint!.isNotEmpty
            ? '${action.label} (Atajo: ${action.keyHint})'
            : action.label;

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
          // Limpieza total: ya no se renderiza ningún badge literal en la vista
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bool useDesktopLayout = isDesktop ?? (width >= 1024);
    final bool useTabletLayout =
        isTablet ?? (!useDesktopLayout && (width >= 640));

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(useDesktopLayout ? 14 : 16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child:
          useDesktopLayout
              ? _buildDesktopLayout()
              : (useTabletLayout ? _buildTabletLayout() : _buildMobileLayout()),
    );
  }

  // ── 1. DESKTOP LAYOUT (POWER-USER ERP, HIGH-DENSITY SINGLE ROW) ───────────
  Widget _buildDesktopLayout() {
    final primaryRow = Row(
      children: [
        // 1. Buscador expandido
        Expanded(flex: searchFlex, child: _buildSearchField(isMobile: false)),

        // 2. Filtros centrales modulares
        for (final filter in filterWidgets) ...[
          const SizedBox(width: 10),
          filter,
        ],

        // 3. Switch de visualización
        if (viewToggleConfig != null) ...[
          const SizedBox(width: 10),
          _buildViewModeToggle(viewToggleConfig!),
        ],

        // 4. Botón de refresco con rotación interactiva
        if (onRefresh != null) ...[
          const SizedBox(width: 8),
          _AdminProRefreshButton(onRefresh: onRefresh, tooltip: refreshTooltip),
        ],

        // 5. Acciones extra opcionales (ej: Exportar, Importar)
        if (trailingActions != null)
          for (final action in trailingActions!) ...[
            const SizedBox(width: 8),
            action,
          ],

        // 6. Botón de acción principal (CTA)
        if (primaryAction != null) ...[
          const SizedBox(width: 8),
          _buildPrimaryActionButton(primaryAction!, isMobile: false),
        ],
      ],
    );

    if (secondaryRow == null) {
      return primaryRow;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [primaryRow, const SizedBox(height: 12), secondaryRow!],
    );
  }

  // ── 2. TABLET LAYOUT (EFICIENCIA HÍBRIDA EN 2 NIVELES EQUILIBRADOS) ───────
  Widget _buildTabletLayout() {
    final showToggleOnTablet =
        viewToggleConfig != null && viewToggleConfig!.showOnTablet;
    final hasSecondaryItems =
        filterWidgets.isNotEmpty ||
        showToggleOnTablet ||
        onRefresh != null ||
        (trailingActions != null && trailingActions!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila 1: Buscador expandido + CTA destacado a la derecha
        Row(
          children: [
            Expanded(child: _buildSearchField(isMobile: false)),
            if (primaryAction != null) ...[
              const SizedBox(width: 10),
              _buildPrimaryActionButton(primaryAction!, isMobile: false),
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
                      for (final filter in filterWidgets) ...[
                        filter,
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              if (showToggleOnTablet) ...[
                const SizedBox(width: 8),
                _buildViewModeToggle(viewToggleConfig!),
              ],
              if (onRefresh != null) ...[
                const SizedBox(width: 6),
                _AdminProRefreshButton(
                  onRefresh: onRefresh,
                  tooltip: refreshTooltip,
                ),
              ],
              if (trailingActions != null)
                for (final action in trailingActions!) ...[
                  const SizedBox(width: 6),
                  action,
                ],
            ],
          ),
        ],
        if (secondaryRow != null) ...[
          const SizedBox(height: 10),
          secondaryRow!,
        ],
      ],
    );
  }

  // ── 3. MOBILE LAYOUT (APPLE HIG, TOUCH TARGETS 46DP, CTA PRIORITARIO) ─────
  Widget _buildMobileLayout() {
    final showToggleOnMobile =
        viewToggleConfig != null && viewToggleConfig!.showOnMobile;
    final hasMiddleOrEndItems =
        primaryAction != null ||
        filterWidgets.isNotEmpty ||
        showToggleOnMobile ||
        (trailingActions != null && trailingActions!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila superior: Buscador táctil (46dp) + Botón de refresco integrado
        Row(
          children: [
            Expanded(child: _buildSearchField(isMobile: true)),
            if (onRefresh != null) ...[
              const SizedBox(width: 6),
              _AdminProRefreshButton(
                onRefresh: onRefresh,
                tooltip: refreshTooltip,
              ),
            ],
          ],
        ),
        // Fila inferior: CTA SIEMPRE visible primero + Filtros táctiles elásticos
        if (hasMiddleOrEndItems) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // CTA Principal primero en móvil para visibilidad instantánea
                if (primaryAction != null) ...[
                  _buildPrimaryActionButton(primaryAction!, isMobile: true),
                  const SizedBox(width: 8),
                ],
                // Alternador de vista (si habilitado en móvil)
                if (showToggleOnMobile) ...[
                  _buildViewModeToggle(viewToggleConfig!),
                  const SizedBox(width: 8),
                ],
                // Filtros modulares
                for (final filter in filterWidgets) ...[
                  filter,
                  const SizedBox(width: 8),
                ],
                // Acciones extra
                if (trailingActions != null)
                  for (final action in trailingActions!) ...[
                    action,
                    const SizedBox(width: 8),
                  ],
              ],
            ),
          ),
        ],
        if (secondaryRow != null) ...[
          const SizedBox(height: 10),
          secondaryRow!,
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
    return Tooltip(
      message: widget.tooltip,
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
