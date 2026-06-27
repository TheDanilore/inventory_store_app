import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/inventory_entry_item_model.dart';
import 'package:inventory_store_app/models/inventory_entry_model.dart';
import 'package:inventory_store_app/providers/admin/inventory_entries_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/screens/admin/widgets/inventory_entries/inventory_entry_detail_sheet.dart';
import 'package:inventory_store_app/shared/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/services/admin/inventory_entries_service.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';

class InventoryEntriesScreen extends StatefulWidget {
  const InventoryEntriesScreen({super.key});

  @override
  State<InventoryEntriesScreen> createState() => _InventoryEntriesScreenState();
}

class _InventoryEntriesScreenState extends State<InventoryEntriesScreen> {
  final _searchCtrl = TextEditingController();
  bool _hasDraft = false;
  InventoryEntryModel? _selectedEntry; // State for Master-Detail

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InventoryEntriesProvider>();
      _searchCtrl.text = provider.searchQuery;
      provider.init();
    });
    _checkDraft();
  }

  Future<void> _checkDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsString = prefs.getString('inventory_entry_draft');
    if (mounted) {
      setState(() {
        _hasDraft =
            itemsString != null &&
            itemsString.isNotEmpty &&
            itemsString != '[]';
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<InventoryEntryItemModel>> _loadEntryItems(
    String entryId,
    Map<String, dynamic>? productData,
  ) async {
    final service = InventoryEntriesService();
    final itemsDynamic = await service.getEntryItems(entryId);
    return itemsDynamic.map((r) {
      final prod = r['products'] as Map<String, dynamic>?;
      final variantData = r['product_variants'] as Map<String, dynamic>?;
      final variantId = r['variant_id'] as String?;

      final vavList =
          variantData?['variant_attribute_values'] as List<dynamic>? ?? [];
      final List<String> attrValues = [];

      for (var vav in vavList) {
        final av = vav['attribute_values'] as Map<String, dynamic>?;
        if (av != null && av['value'] != null) {
          attrValues.add(av['value'].toString());
        }
      }

      final attrsText = attrValues.join(' · ');
      final bool usesBatches = prod?['uses_batches'] == true;

      String? finalImageUrl;
      final imagesList = prod?['product_images'] as List<dynamic>? ?? [];
      if (imagesList.isNotEmpty) {
        final variantImage = imagesList.cast<Map<String, dynamic>>().firstWhere(
          (img) => img['variant_id'] == variantId,
          orElse: () => <String, dynamic>{},
        );
        if (variantImage.isNotEmpty && variantImage['image_url'] != null) {
          finalImageUrl = variantImage['image_url'] as String;
        } else {
          final mainImage = imagesList.cast<Map<String, dynamic>>().firstWhere(
            (img) => img['is_main'] == true,
            orElse: () => imagesList.first as Map<String, dynamic>,
          );
          finalImageUrl = mainImage['image_url'] as String?;
        }
      }

      return InventoryEntryItemModel(
        id: r['id'] as String? ?? '',
        entryId: entryId,
        productId: prod?['id'] as String? ?? '',
        variantId: variantId ?? '',
        productName: prod?['name'] as String? ?? '—',
        variantAttrs: attrsText.isNotEmpty ? attrsText : 'Única',
        quantity: (r['quantity'] as num).toDouble(),
        unitCost: (r['unit_cost'] as num).toDouble(),
        batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
        expiryDate:
            r['expiry_date'] != null
                ? DateTime.tryParse(r['expiry_date'] as String)
                : null,
        usesBatches: usesBatches,
        imageUrl: finalImageUrl,
      );
    }).toList();
  }

  void _onEntryTapped(
    BuildContext context,
    InventoryEntryModel entry,
    bool isTablet,
  ) {
    if (isTablet) {
      setState(() => _selectedEntry = entry);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => InventoryEntryDetailSheet(
              entry: entry,
              isBottomSheet: true,
              loadItems: () => _loadEntryItems(entry.id, null),
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryEntriesProvider>(
      builder: (context, provider, child) {
        if (provider.errorMessage.isNotEmpty && !provider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppSnackbar.show(
              context,
              message: provider.errorMessage,
              type: SnackbarType.error,
            );
            provider.clearError();
          });
        }

        return AdminLayout(
          title: 'Historial de Entradas',
          showBackButton: true,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 800;
              return Stack(
                children: [
                  if (isTablet)
                    _buildTabletLayout(context, provider)
                  else
                    _buildMobileLayout(context, provider),

                  _buildFloatingAction(provider),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFloatingAction(InventoryEntriesProvider provider) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push<bool>(
            '/admin/inventory-entry-form',
          );
          if (result == true) {
            provider.loadEntries(page: 0);
          }
          _checkDraft();
        },
        icon: Icon(_hasDraft ? Icons.edit_note_rounded : Icons.add_rounded),
        label: Text(_hasDraft ? 'Continuar Borrador' : 'Nueva entrada'),
        backgroundColor:
            _hasDraft ? const Color(0xFFF59E0B) : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    InventoryEntriesProvider provider,
  ) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => provider.loadEntries(page: 0),
            child: _buildCustomScrollView(context, provider, false),
          ),
        ),
        _buildPagination(provider),
      ],
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    InventoryEntriesProvider provider,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => provider.loadEntries(page: 0),
                  child: _buildCustomScrollView(context, provider, true),
                ),
              ),
              _buildPagination(provider),
            ],
          ),
        ),
        Container(
          width: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        Expanded(
          flex: 6,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child:
                _selectedEntry == null
                    ? AppEmptyState(
                      key: const ValueKey('empty_detail'),
                      icon: Icons.receipt_long_rounded,
                      title: 'Ninguna Entrada Seleccionada',
                      message:
                          'Selecciona una entrada del panel izquierdo para ver sus detalles.',
                    )
                    : Padding(
                      key: ValueKey(_selectedEntry!.id),
                      padding: const EdgeInsets.all(16.0),
                      child: InventoryEntryDetailSheet(
                        entry: _selectedEntry!,
                        isBottomSheet: false,
                        loadItems:
                            () => _loadEntryItems(_selectedEntry!.id, null),
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomScrollView(
    BuildContext context,
    InventoryEntriesProvider provider,
    bool isTablet,
  ) {
    final double totalAmount = provider.entries.fold<double>(
      0,
      (s, e) => s + e.totalAmount,
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Borrador ──────────────────────────────────────────
        if (_hasDraft)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_document, color: AppColors.warning),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tienes un borrador de entrada en progreso.',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      final result = await context.push<bool>(
                        '/admin/inventory-entry-form',
                      );
                      _checkDraft();
                      if (result == true && context.mounted) {
                        context.read<InventoryEntriesProvider>().init();
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                      foregroundColor: AppColors.warning,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Resumen ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _SummaryChip(
                  label: 'Página actual',
                  value: '${provider.entries.length}',
                  icon: Icons.move_to_inbox_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                _SummaryChip(
                  label: 'Inversión (pág)',
                  value: 'S/ ${totalAmount.toStringAsFixed(2)}',
                  icon: Icons.payments_rounded,
                  color: AppColors.teal,
                  isPremium: true,
                ),
              ],
            ),
          ),
        ),

        // ── Filtros Pegajosos (Sticky Header) ─────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyFilterDelegate(
            minHeight: 110,
            maxHeight: 110,
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SearchField(
                          controller: _searchCtrl,
                          hint: 'Buscar proveedor o comprobante...',
                          onChanged: (v) {},
                          onSubmitted: (v) => provider.setSearchQuery(v),
                          onClear: () {
                            _searchCtrl.clear();
                            provider.setSearchQuery('');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      DateFilterCalendar(
                        dateRange: provider.dateRange,
                        onDateRangeSelected: provider.setDateRange,
                        onClear: () => provider.setDateRange(null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          provider.availableWarehouses.map((w) {
                            final sel = provider.warehouseFilter == w;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: FilterChip(
                                  label: Text(w),
                                  selected: sel,
                                  onSelected:
                                      (_) => provider.setWarehouseFilter(w),
                                  selectedColor: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  checkmarkColor: AppColors.primary,
                                  backgroundColor: AppColors.surface,
                                  side: BorderSide(
                                    color:
                                        sel
                                            ? Colors.transparent
                                            : Colors.grey.shade300,
                                  ),
                                  labelStyle: TextStyle(
                                    fontWeight:
                                        sel ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 12,
                                    color:
                                        sel
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Lista ─────────────────────────────────────────────
        if (provider.isLoading)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _EntriesSkeleton()),
          )
        else if (provider.entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Sin Resultados',
              message:
                  provider.searchQuery.isEmpty &&
                          provider.dateRange == null &&
                          provider.warehouseFilter == 'Todos'
                      ? 'No hay entradas registradas'
                      : 'Sin resultados para los filtros aplicados',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              80,
            ), // Padding inferior por FAB
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final entry = provider.entries[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EntryCard(
                    entry: entry,
                    isSelected: _selectedEntry?.id == entry.id,
                    onTap: () => _onEntryTapped(context, entry, isTablet),
                  ),
                );
              }, childCount: provider.entries.length),
            ),
          ),
      ],
    );
  }

  Widget _buildPagination(InventoryEntriesProvider provider) {
    if (provider.totalPages <= 1 || provider.isLoading) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AdminPageBlocks(
          currentPage: provider.currentPage,
          totalPages: provider.totalPages,
          onPageChanged: provider.goToPage,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STICKY DELEGATE
// ══════════════════════════════════════════════════════════════════════════════

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double maxHeight;
  final double minHeight;

  _StickyFilterDelegate({
    required this.child,
    required this.maxHeight,
    required this.minHeight,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant _StickyFilterDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ENTRY CARD
// ══════════════════════════════════════════════════════════════════════════════

class _EntryCard extends StatelessWidget {
  final InventoryEntryModel entry;
  final VoidCallback onTap;
  final bool isSelected;
  const _EntryCard({
    required this.entry,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final hasDoc =
        entry.documentType != 'NINGUNO' &&
        entry.documentNumber != null &&
        entry.documentNumber!.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color:
            isSelected
                ? AppColors.primary.withValues(alpha: 0.05)
                : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.move_to_inbox_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.supplierName ?? 'Sin proveedor',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.createdAt != null
                                ? fmt.format(entry.createdAt!.toLocal())
                                : '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/ ${entry.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.itemCount} producto${entry.itemCount != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      icon: Icons.warehouse_rounded,
                      label: entry.warehouseName ?? 'Sin almacén',
                      color:
                          AppColors
                              .textPrimary, // Texto más oscuro para contraste
                      bgColor: Colors.grey.shade200,
                    ),
                    if (hasDoc)
                      _Pill(
                        icon: Icons.receipt_long_rounded,
                        label: '${entry.documentType} ${entry.documentNumber}',
                        color: AppColors.teal,
                        bgColor: AppColors.teal.withValues(alpha: 0.15),
                      ),
                    if (entry.purchaseOrderId != null)
                      _Pill(
                        icon: Icons.link_rounded,
                        label: 'Orden de compra',
                        color: Colors.purple.shade700,
                        bgColor: Colors.purple.shade400.withValues(alpha: 0.15),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isPremium;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient:
            isPremium
                ? LinearGradient(
                  colors: [color.withValues(alpha: 0.8), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                : null,
        color: isPremium ? null : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium ? Colors.transparent : color.withValues(alpha: 0.1),
        ),
        boxShadow:
            isPremium
                ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isPremium ? Colors.white : color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isPremium ? Colors.white : color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isPremium
                            ? Colors.white.withValues(alpha: 0.9)
                            : color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      prefixIcon: const Icon(Icons.search_rounded, size: 20),
      suffixIcon:
          controller.text.isNotEmpty
              ? IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.clear_rounded, size: 20),
                onPressed: onClear,
              )
              : null,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: AppColors.surface,
    ),
  );
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntriesSkeleton extends StatelessWidget {
  const _EntriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        6,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppShimmer(width: 44, height: 44, borderRadius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: 140, height: 16, borderRadius: 4),
                        SizedBox(height: 8),
                        AppShimmer(width: 90, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      AppShimmer(width: 70, height: 18, borderRadius: 4),
                      SizedBox(height: 8),
                      AppShimmer(width: 50, height: 12, borderRadius: 4),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: const [
                  AppShimmer(width: 90, height: 24, borderRadius: 8),
                  SizedBox(width: 8),
                  AppShimmer(width: 120, height: 24, borderRadius: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
