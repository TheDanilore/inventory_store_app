import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Configuración para la acción principal del toolbar (CTA)
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

/// Configuración para alternar vistas (Tabla vs Tarjetas / Grid)
class AdminProViewToggleConfig {
  final bool isTableView;
  final ValueChanged<bool> onToggleTableView;
  final String tableTooltip;
  final String cardsTooltip;
  final Color? activeColor;
  final IconData tableIcon;
  final IconData cardsIcon;

  const AdminProViewToggleConfig({
    required this.isTableView,
    required this.onToggleTableView,
    this.tableTooltip = 'Vista en Tabla Pro [V]',
    this.cardsTooltip = 'Vista en Tarjetas [V]',
    this.activeColor,
    this.tableIcon = Icons.table_rows_rounded,
    this.cardsIcon = Icons.grid_view_rounded,
  });
}

/// Toolbar Pro Unificado de alto rendimiento y diseño consistente para pantallas administrativas.
/// Proporciona buscador con atajo [/], filtros dinámicos, alternador de vista [V],
/// botón de refresco [R], y botón de acción principal [N].
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
    this.refreshTooltip = 'Refrescar [R]',
    this.primaryAction,
    this.trailingActions,
    this.secondaryRow,
    this.isDesktop,
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 8),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  Widget _buildKeyHint(String char) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildButtonKeyHint(String char) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 40,
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
            fontSize: 12.5,
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
                    size: 16,
                  ),
                  tooltip: 'Limpiar búsqueda',
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
              if (searchKeyHint != null && searchKeyHint!.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [_buildKeyHint(searchKeyHint!)],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle(AdminProViewToggleConfig config) {
    final activeColor = config.activeColor ?? AppColors.tealDark;

    return SizedBox(
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IconButton(
              tooltip: config.tableTooltip,
              icon: Icon(
                config.tableIcon,
                size: 18,
                color: config.isTableView ? activeColor : AppColors.textMuted,
              ),
              style: IconButton.styleFrom(
                backgroundColor:
                    config.isTableView ? AppColors.surface : Colors.transparent,
                elevation: config.isTableView ? 1 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
              ),
              onPressed: () => config.onToggleTableView(true),
            ),
            IconButton(
              tooltip: config.cardsTooltip,
              icon: Icon(
                config.cardsIcon,
                size: 18,
                color: !config.isTableView ? activeColor : AppColors.textMuted,
              ),
              style: IconButton.styleFrom(
                backgroundColor:
                    !config.isTableView ? AppColors.surface : Colors.transparent,
                elevation: !config.isTableView ? 1 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
              ),
              onPressed: () => config.onToggleTableView(false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      icon: const Icon(Icons.refresh_rounded, size: 20),
      color: AppColors.textSecondary,
      tooltip: refreshTooltip,
      onPressed: onRefresh,
    );
  }

  Widget _buildPrimaryActionButton(AdminProToolbarAction action) {
    final effectiveBgColor = action.isHighlighted
        ? (action.highlightColor ?? const Color(0xFFF59E0B))
        : (action.backgroundColor ?? AppColors.primary);
    final effectiveFgColor = action.foregroundColor ?? Colors.white;

    return SizedBox(
      height: 40,
      child: FilledButton.icon(
        onPressed: action.onPressed,
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
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action.label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
            if (action.keyHint != null && action.keyHint!.isNotEmpty) ...[
              const SizedBox(width: 6),
              _buildButtonKeyHint(action.keyHint!),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop ?? (MediaQuery.sizeOf(context).width >= 800);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: desktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    final primaryRow = Row(
      children: [
        // 1. Buscador expandido
        Expanded(
          flex: searchFlex,
          child: _buildSearchField(),
        ),

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

        // 4. Botón de refresco
        if (onRefresh != null) ...[
          const SizedBox(width: 8),
          _buildRefreshButton(),
        ],

        // 5. Botón de acción principal (CTA)
        if (primaryAction != null) ...[
          const SizedBox(width: 8),
          _buildPrimaryActionButton(primaryAction!),
        ],

        // 6. Acciones extra opcionales
        if (trailingActions != null)
          for (final action in trailingActions!) ...[
            const SizedBox(width: 8),
            action,
          ],
      ],
    );

    if (secondaryRow == null) {
      return primaryRow;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        primaryRow,
        const SizedBox(height: 12),
        secondaryRow!,
      ],
    );
  }

  Widget _buildMobileLayout() {
    final hasMiddleOrEndItems = filterWidgets.isNotEmpty ||
        viewToggleConfig != null ||
        onRefresh != null ||
        primaryAction != null ||
        (trailingActions != null && trailingActions!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchField(),
        if (hasMiddleOrEndItems) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final filter in filterWidgets) ...[
                  filter,
                  const SizedBox(width: 8),
                ],
                if (viewToggleConfig != null) ...[
                  _buildViewModeToggle(viewToggleConfig!),
                  const SizedBox(width: 8),
                ],
                if (onRefresh != null) ...[
                  _buildRefreshButton(),
                  const SizedBox(width: 6),
                ],
                if (primaryAction != null) ...[
                  _buildPrimaryActionButton(primaryAction!),
                  const SizedBox(width: 8),
                ],
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
