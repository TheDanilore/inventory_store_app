import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/chips/catalog_filter_models.dart';

/// Componente adaptativo optimizado (Modal Bottom Sheet en móvil / Diálogo en Desktop)
/// con buscador y virtualización estricta de scroll para rendimiento en dispositivos de gama baja.
class CatalogSearchableItemPicker extends StatefulWidget {
  final String title;
  final String allLabel;
  final IconData defaultIcon;
  final List<FilterPickerItem> items;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const CatalogSearchableItemPicker({
    super.key,
    required this.title,
    required this.allLabel,
    required this.defaultIcon,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String allLabel,
    required IconData defaultIcon,
    required List<FilterPickerItem> items,
    required String? selectedId,
    required ValueChanged<String?> onSelected,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 650;

    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (ctx) => CatalogSearchableItemPicker(
              title: title,
              allLabel: allLabel,
              defaultIcon: defaultIcon,
              items: items,
              selectedId: selectedId,
              onSelected: onSelected,
            ),
      );
    } else {
      await showDialog(
        context: context,
        useRootNavigator: true,
        builder:
            (ctx) => Dialog(
              backgroundColor:
                  isDark ? AppColors.darkSurface : AppColors.surface,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 380,
                  maxHeight: 480,
                ),
                child: CatalogSearchableItemPicker(
                  title: title,
                  allLabel: allLabel,
                  defaultIcon: defaultIcon,
                  items: items,
                  selectedId: selectedId,
                  onSelected: onSelected,
                ),
              ),
            ),
      );
    }
  }

  @override
  State<CatalogSearchableItemPicker> createState() =>
      _CatalogSearchableItemPickerState();
}

class _CatalogSearchableItemPickerState
    extends State<CatalogSearchableItemPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  List<FilterPickerItem>? _memoizedFiltered;
  String _lastEvaluatedQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FilterPickerItem> _getFilteredItems() {
    if (_query.isEmpty) {
      return widget.items;
    }
    if (_memoizedFiltered != null && _lastEvaluatedQuery == _query) {
      return _memoizedFiltered!;
    }
    final lowerQuery = _query.toLowerCase();
    _lastEvaluatedQuery = _query;
    _memoizedFiltered = widget.items
        .where((i) => i.name.toLowerCase().contains(lowerQuery))
        .toList(growable: false);
    return _memoizedFiltered!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 650;
    final showSearch = widget.items.length > 5;
    final filteredItems = _getFilteredItems();
    final bool hasAllOption = _query.isEmpty;
    final int totalCount = filteredItems.length + (hasAllOption ? 1 : 0);

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Drag Handle (Móvil) ───────────────────────────────────
        if (isMobile) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 16),

        // ── Cabecera con Título y Acción de Limpiar ───────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              if (widget.selectedId != null)
                TextButton(
                  onPressed: () {
                    AppFeedbackService.lightImpact();
                    widget.onSelected(null);
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor:
                        isDark ? const Color(0xFFF87171) : AppColors.error,
                  ),
                  child: const Text(
                    'Limpiar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              if (!isMobile)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cerrar',
                ),
            ],
          ),
        ),

        // ── Buscador Dinámico ─────────────────────────────────────
        if (showSearch) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: !isMobile,
              onChanged: (val) {
                final cleaned = val.trim();
                if (cleaned != _query) {
                  setState(() => _query = cleaned);
                }
              },
              style: TextStyle(
                fontSize: 13,
                color:
                    isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar en ${widget.title.toLowerCase()}...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
                suffixIcon:
                    _query.isNotEmpty
                        ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            size: 16,
                            color:
                                isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                        : null,
                filled: true,
                fillColor:
                    isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],

        Divider(
          height: 1,
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),

        // ── Lista Virtualizada de Opciones (Zero-Jank en teléfonos antiguos) ──
        Flexible(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: totalCount,
            separatorBuilder:
                (_, _) => Divider(
                  height: 1,
                  indent: 48,
                  color:
                      isDark
                          ? AppColors.darkBorder.withValues(alpha: 0.5)
                          : AppColors.divider,
                ),
            itemBuilder: (context, index) {
              if (hasAllOption && index == 0) {
                final isAllSelected = widget.selectedId == null;
                return _buildOptionTile(
                  title: widget.allLabel,
                  isSelected: isAllSelected,
                  icon: Icons.all_inclusive_rounded,
                  isDark: isDark,
                  onTap: () {
                    AppFeedbackService.selectionClick();
                    widget.onSelected(null);
                    Navigator.of(context).pop();
                  },
                );
              }

              final itemIndex = hasAllOption ? index - 1 : index;
              final item = filteredItems[itemIndex];
              final isSelected = widget.selectedId == item.id;

              return _buildOptionTile(
                title: item.name,
                isSelected: isSelected,
                icon: widget.defaultIcon,
                isDark: isDark,
                onTap: () {
                  AppFeedbackService.selectionClick();
                  widget.onSelected(item.id);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),

        if (isMobile)
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );

    if (isMobile) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(top: false, child: content),
      );
    }

    return content;
  }

  Widget _buildOptionTile({
    required String title,
    required bool isSelected,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color:
          isSelected
              ? (isDark
                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.05))
              : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color:
                      isSelected
                          ? (isDark
                              ? const Color(0xFF60A5FA)
                              : AppColors.primary)
                          : (isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color:
                          isSelected
                              ? (isDark
                                  ? const Color(0xFF93C5FD)
                                  : AppColors.primary)
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary),
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
