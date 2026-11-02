import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/add_widget_sheet/catalog/dashboard_widgets_catalog.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/add_widget_sheet/components/dashboard_widget_catalog_card.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/add_widget_sheet/components/dashboard_widget_category_chips.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/add_widget_sheet/components/dashboard_widget_search_bar.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/add_widget_sheet/models/dashboard_widget_item.dart';

// Re-exportar el descriptor de widget para compatibilidad retroactiva total
export 'package:inventory_store_app/features/dashboard/presentation/widgets/add_widget_sheet/models/dashboard_widget_item.dart';

/// Panel interactivo "Add Widget" / Personalizador de componentes del Dashboard.
///
/// Optimizado con:
/// - Memoización estricta de micro-mockups vectoriales (0 alocaciones innecesarias de memoria).
/// - Aislamiento atómico de hover en cada tarjeta (0 rebuilds globales al mover el puntero).
/// - Modularización limpia en componentes desacoplados.
class DashboardAddWidgetSheet extends StatefulWidget {
  final Set<String> visibleWidgetIds;
  final void Function(String id, bool isVisible) onToggleWidget;
  final VoidCallback onResetDefaults;

  const DashboardAddWidgetSheet({
    super.key,
    required this.visibleWidgetIds,
    required this.onToggleWidget,
    required this.onResetDefaults,
  });

  /// Muestra el panel de widgets en Desktop (Side Sheet derecho) o Móvil (Modal BottomSheet)
  static Future<void> show(
    BuildContext context, {
    required Set<String> visibleWidgetIds,
    required void Function(String id, bool isVisible) onToggleWidget,
    required VoidCallback onResetDefaults,
  }) {
    return AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: 440,
      breakpoint: 720,
      barrierLabel: 'Añadir Widgets al Dashboard',
      builder:
          (sheetContext) => DashboardAddWidgetSheet(
            visibleWidgetIds: visibleWidgetIds,
            onToggleWidget: onToggleWidget,
            onResetDefaults: onResetDefaults,
          ),
    );
  }

  @override
  State<DashboardAddWidgetSheet> createState() =>
      _DashboardAddWidgetSheetState();
}

class _DashboardAddWidgetSheetState extends State<DashboardAddWidgetSheet> {
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _currentVisible;

  @override
  void initState() {
    super.initState();
    _currentVisible = Set<String>.from(widget.visibleWidgetIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DashboardWidgetItem> get _filteredWidgets {
    return DashboardWidgetsCatalog.items.where((w) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          w.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.categoryTag.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == 'Todos' || w.categoryTag == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _handleToggle(DashboardWidgetItem item) {
    if (item.isComingSoon) return;
    AppFeedbackService.selectionClick();
    final nextState = !_currentVisible.contains(item.id);
    setState(() {
      if (nextState) {
        _currentVisible.add(item.id);
      } else {
        _currentVisible.remove(item.id);
      }
    });
    widget.onToggleWidget(item.id, nextState);
  }

  void _handleReset() {
    AppFeedbackService.mediumImpact();
    setState(() {
      _currentVisible =
          DashboardWidgetsCatalog.items
              .where((w) => !w.isComingSoon && w.isDefaultVisible)
              .map((w) => w.id)
              .toSet();
    });
    widget.onResetDefaults();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final totalCount = DashboardWidgetsCatalog.items.length;
    final filtered = _filteredWidgets;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius:
            isDesktop
                ? const BorderRadius.horizontal(left: Radius.circular(20))
                : const BorderRadius.vertical(top: Radius.circular(24)),
        border:
            isDesktop
                ? Border(
                  left: BorderSide(
                    color:
                        isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                )
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 28,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle móvil
          if (!isDesktop) const AppSheetDragHandle(),

          // Cabecera: Título, contador y botón cerrar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Añadir Widgets',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark
                                ? const Color(0xFFF8FAFC)
                                : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.55),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentVisible.length} de $totalCount activos en el dashboard',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cerrar panel (Esc)',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
          ),

          // Buscador de componentes
          DashboardWidgetSearchBar(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            onClear: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            hasQuery: _searchQuery.isNotEmpty,
          ),

          // Selector horizontal de categorías
          DashboardWidgetCategoryChips(
            categories: DashboardWidgetsCatalog.categories,
            selectedCategory: _selectedCategory,
            onSelectCategory: (cat) {
              setState(() => _selectedCategory = cat);
            },
          ),
          const SizedBox(height: 10),

          // Lista de widgets del catálogo
          Expanded(
            child:
                filtered.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.grid_off_rounded,
                            size: 40,
                            color:
                                isDark
                                    ? const Color(0xFF475569)
                                    : const Color(
                                      0xFF94A3B8,
                                    ).withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No se encontraron widgets',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
                      itemCount: filtered.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isVisible = _currentVisible.contains(item.id);

                        return DashboardWidgetCatalogCard(
                          item: item,
                          isVisible: isVisible,
                          onToggle: () => _handleToggle(item),
                        );
                      },
                    ),
          ),

          // Footer: Restaurar predeterminados y Botón Listo
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _handleReset,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text(
                    'Restaurar por defecto',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Listo',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
