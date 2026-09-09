import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_entry_item_model.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_entry_items_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entries/inventory_entries_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entries/inventory_entries_state.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/inventory_entry_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class InventoryEntriesScreen extends StatefulWidget {
  const InventoryEntriesScreen({super.key});

  @override
  State<InventoryEntriesScreen> createState() => _InventoryEntriesScreenState();
}

class _InventoryEntriesScreenState extends State<InventoryEntriesScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _hasDraft = false;
  InventoryEntryEntity? _selectedEntry; // State for Master-Detail

  @override
  void initState() {
    super.initState();
    _checkDraft();
    // Reload entries every time the screen is (re)entered via go_router
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InventoryEntriesCubit>().init();
    });
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
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Atajo Ctrl+K o Cmd+K (o '/' cuando no hay foco) para enfocar buscador
    final isControlOrMeta =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if ((isControlOrMeta && event.logicalKey == LogicalKeyboardKey.keyK) ||
        (event.logicalKey == LogicalKeyboardKey.slash &&
            !_searchFocusNode.hasFocus)) {
      if (!_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus();
        _searchCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchCtrl.text.length,
        );
        return KeyEventResult.handled;
      }
    }

    // Escape para desenfocar buscador o deseleccionar entrada
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      if (_selectedEntry != null) {
        setState(() => _selectedEntry = null);
        return KeyEventResult.handled;
      }
    }

    // Flechas arriba y abajo para navegar entradas en split-view
    final state = context.read<InventoryEntriesCubit>().state;
    if (state is InventoryEntriesLoaded &&
        state.entries.isNotEmpty &&
        !_searchFocusNode.hasFocus) {
      final entries = state.entries;
      final currentIndex =
          _selectedEntry != null
              ? entries.indexWhere((e) => e.id == _selectedEntry!.id)
              : -1;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final nextIndex = (currentIndex + 1).clamp(0, entries.length - 1);
        setState(() => _selectedEntry = entries[nextIndex]);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, entries.length - 1);
        setState(() => _selectedEntry = entries[prevIndex]);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Widget _buildRefreshButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        context.read<InventoryEntriesCubit>().loadEntries(page: 0);
      },
      icon: const Icon(
        Icons.refresh_rounded,
        size: 16,
        color: AppColors.textSecondary,
      ),
      label: const Text(
        'Actualizar',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildNewEntryButton(
    BuildContext context, {
    bool isHeader = false,
    bool isCompactMobile = false,
  }) {
    if (isCompactMobile) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilledButton.icon(
          onPressed: () async {
            await context.push('/admin/inventory-entries/form');
            _checkDraft();
          },
          style: FilledButton.styleFrom(
            backgroundColor:
                _hasDraft ? const Color(0xFFF59E0B) : AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: Icon(
            _hasDraft ? Icons.edit_note_rounded : Icons.add_rounded,
            size: 16,
          ),
          label: Text(
            _hasDraft ? 'Borrador' : 'Nueva',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: () async {
        await context.push('/admin/inventory-entries/form');
        _checkDraft();
      },
      icon: Icon(
        _hasDraft ? Icons.edit_note_rounded : Icons.add_rounded,
        size: 18,
      ),
      label: Text(
        _hasDraft ? 'Continuar Borrador' : 'Nueva entrada',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      style: FilledButton.styleFrom(
        backgroundColor:
            _hasDraft ? const Color(0xFFF59E0B) : AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<List<InventoryEntryItemModel>> _loadEntryItems(
    String entryId,
    Map<String, dynamic>? productData,
  ) async {
    final getEntryItems = sl<GetEntryItemsUseCase>();
    final itemsDynamic = await getEntryItems.call(entryId);
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

      // 1. Buscar en las imágenes del producto la asociada a la variante
      final imagesList = prod?['product_images'] as List<dynamic>? ?? [];
      if (variantId != null && variantId.isNotEmpty && imagesList.isNotEmpty) {
        for (final img in imagesList) {
          if (img is Map<String, dynamic> &&
              img['variant_id'] == variantId &&
              (img['image_url'] as String?)?.isNotEmpty == true) {
            finalImageUrl = img['image_url'] as String;
            break;
          }
        }
      }

      // 2. Si es nulo, buscar en las imágenes anidadas en product_variants
      if (finalImageUrl == null || finalImageUrl.isEmpty) {
        final variantImagesList =
            variantData?['product_images'] as List<dynamic>? ?? [];
        for (final img in variantImagesList) {
          if (img is Map<String, dynamic> &&
              (img['image_url'] as String?)?.isNotEmpty == true) {
            finalImageUrl = img['image_url'] as String;
            if (img['is_main'] == true) break;
          }
        }
      }

      // 3. Herencia automática: si la variante no tiene imagen propia, usar la imagen principal del producto
      if (finalImageUrl == null || finalImageUrl.isEmpty) {
        if (imagesList.isNotEmpty) {
          for (final img in imagesList) {
            if (img is Map<String, dynamic> &&
                (img['image_url'] as String?)?.isNotEmpty == true) {
              finalImageUrl = img['image_url'] as String;
              if (img['is_main'] == true) break;
            }
          }
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
    InventoryEntryEntity entry,
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
    final isDesktopOrTablet = MediaQuery.sizeOf(context).width >= 800;

    return BlocConsumer<InventoryEntriesCubit, InventoryEntriesState>(
      listener: (context, state) {
        if (state is InventoryEntriesError) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final loadedState = state is InventoryEntriesLoaded ? state : null;

        if (loadedState == null && state is InventoryEntriesError) {
          return Center(child: Text('Error: ${state.message}'));
        }

        final currentState =
            loadedState ??
            const InventoryEntriesLoaded(
              entries: [],
              searchQuery: '',
              warehouseFilter: 'Todos',
              availableWarehouses: ['Todos'],
              currentPage: 0,
              totalCount: 0,
              totalPages: 1,
            );

        final isLoading = state is InventoryEntriesLoading;

        // Sincronización automática de selección en vista Master-Detail (Tablet/Desktop)
        if (isDesktopOrTablet &&
            loadedState != null &&
            loadedState.entries.isNotEmpty) {
          final found = loadedState.entries
              .where((e) => e.id == _selectedEntry?.id)
              .firstOrNull;
          final target = found ?? loadedState.entries.first;
          if (_selectedEntry != target) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedEntry != target) {
                setState(() => _selectedEntry = target);
              }
            });
          }
        } else if ((!isDesktopOrTablet ||
                (loadedState != null && loadedState.entries.isEmpty)) &&
            _selectedEntry != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedEntry != null) {
              setState(() => _selectedEntry = null);
            }
          });
        }

        return AdminLayout(
          title: 'Historial de Entradas',
          showBackButton: true,
          actions:
              isDesktopOrTablet
                  ? [
                      _buildRefreshButton(context),
                      const SizedBox(width: 8),
                      _buildNewEntryButton(context, isHeader: true),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Actualizar entradas',
                        onPressed: () {
                          context
                              .read<InventoryEntriesCubit>()
                              .loadEntries(page: 0);
                        },
                      ),
                      _buildNewEntryButton(context, isCompactMobile: true),
                    ],
          floatingActionButton: null,
          body: Focus(
            focusNode: _screenFocusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 800;
                if (isTablet) {
                  return _buildTabletLayout(context, currentState, isLoading);
                }
                return _buildMobileLayout(context, currentState, isLoading);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    InventoryEntriesLoaded state,
    bool isLoading,
  ) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh:
                () async =>
                    context.read<InventoryEntriesCubit>().loadEntries(page: 0),
            child: _buildCustomScrollView(context, state, isLoading, false),
          ),
        ),
        _buildPagination(context, state, isLoading, isTablet: false),
      ],
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    InventoryEntriesLoaded state,
    bool isLoading,
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
                  onRefresh:
                      () async => context
                          .read<InventoryEntriesCubit>()
                          .loadEntries(page: 0),
                  child: _buildCustomScrollView(
                    context,
                    state,
                    isLoading,
                    true,
                  ),
                ),
              ),
              _buildPagination(context, state, isLoading, isTablet: true),
            ],
          ),
        ),
        Container(
          width: 1,
          color: AppColors.border,
        ),
        Expanded(
          flex: 6,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child:
                _selectedEntry == null
                    ? const AppEmptyState(
                        key: ValueKey('empty_detail'),
                        icon: Icons.receipt_long_rounded,
                        title: 'Ninguna Entrada Seleccionada',
                        message:
                            'Selecciona una entrada del panel izquierdo para ver sus detalles.',
                      )
                    : Container(
                        key: ValueKey(_selectedEntry!.id),
                        margin: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
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
    InventoryEntriesLoaded state,
    bool isLoading,
    bool isTablet,
  ) {
    final double totalAmount = state.entries.fold<double>(
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
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_document, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Tienes un borrador de entrada en progreso.',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      await context.push('/admin/inventory-entries/form');
                      _checkDraft();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                      foregroundColor: AppColors.warning,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 0,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Ribbon Compacto de KPIs (42dp) ────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _CompactKpiRibbon(
              count: state.entries.length,
              totalCount: state.totalCount,
              totalAmount: totalAmount,
              warehouseFilter: state.warehouseFilter,
            ),
          ),
        ),

        // ── Filtros Pegajosos (Sticky Header) ─────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyFilterDelegate(
            minHeight: 100,
            maxHeight: 100,
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SearchField(
                          controller: _searchCtrl,
                          focusNode: _searchFocusNode,
                          hint:
                              isTablet
                                  ? 'Buscar proveedor, comprobante... (Ctrl K)'
                                  : 'Buscar proveedor o comprobante...',
                          onChanged: (v) {
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(
                              const Duration(milliseconds: 300),
                              () {
                                if (mounted) {
                                  context
                                      .read<InventoryEntriesCubit>()
                                      .setSearchQuery(v);
                                }
                              },
                            );
                          },
                          onSubmitted: (v) {
                            _searchDebounce?.cancel();
                            context
                                .read<InventoryEntriesCubit>()
                                .setSearchQuery(v);
                          },
                          onClear: () {
                            _searchDebounce?.cancel();
                            _searchCtrl.clear();
                            context
                                .read<InventoryEntriesCubit>()
                                .setSearchQuery('');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      DateFilterCalendar(
                        height: 40,
                        borderRadius: BorderRadius.circular(10),
                        dateRange: state.dateRange,
                        onDateRangeSelected:
                            context.read<InventoryEntriesCubit>().setDateRange,
                        onClear:
                            () => context
                                .read<InventoryEntriesCubit>()
                                .setDateRange(null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          state.availableWarehouses.map((w) {
                            final sel = state.warehouseFilter == w;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _WarehouseFilterPill(
                                label: w,
                                isSelected: sel,
                                onTap:
                                    () => context
                                        .read<InventoryEntriesCubit>()
                                        .setWarehouseFilter(w),
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
        if (isLoading)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _EntriesSkeleton()),
          )
        else if (state.entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Sin Resultados',
              message:
                  state.searchQuery.isEmpty &&
                          state.dateRange == null &&
                          state.warehouseFilter == 'Todos'
                      ? 'No hay entradas registradas'
                      : 'Sin resultados para los filtros aplicados',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final entry = state.entries[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EntryCard(
                    entry: entry,
                    isSelected: isTablet && _selectedEntry?.id == entry.id,
                    onTap: () => _onEntryTapped(context, entry, isTablet),
                  ),
                );
              }, childCount: state.entries.length),
            ),
          ),
      ],
    );
  }

  Widget _buildPagination(
    BuildContext context,
    InventoryEntriesLoaded state,
    bool isLoading, {
    bool isTablet = false,
  }) {
    if (state.totalPages <= 1 || isLoading) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      alignment: Alignment.center,
      child: SafeArea(
        top: false,
        bottom: !isTablet,
        child: AdminPageBlocks(
          isCompact: isTablet,
          currentPage: state.currentPage,
          totalPages: state.totalPages,
          onPageChanged: context.read<InventoryEntriesCubit>().goToPage,
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
  final InventoryEntryEntity entry;
  final VoidCallback onTap;
  final bool isSelected;
  const _EntryCard({
    required this.entry,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'es');
    final hasDoc =
        entry.documentType != 'NINGUNO' &&
        entry.documentNumber != null &&
        entry.documentNumber!.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary.withValues(alpha: 0.04)
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isSelected ? 0.04 : 0.015,
                ),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3.5,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.move_to_inbox_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.supplierName ?? 'Sin proveedor',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
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
                                  fontSize: 11.5,
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
                                fontSize: 15,
                                color: AppColors.primary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              entry.itemCount > 0
                                  ? '${entry.itemCount} prod. (${entry.totalQuantity % 1 == 0 ? entry.totalQuantity.toInt() : entry.totalQuantity.toStringAsFixed(1)} uds.)'
                                  : '0 productos',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Pill(
                          icon: Icons.warehouse_rounded,
                          label: entry.warehouseName ?? 'Sin almacén',
                          color: AppColors.textSecondary,
                          bgColor: AppColors.slateLight.withValues(alpha: 0.5),
                        ),
                        if (entry.paymentMode != null)
                          _Pill(
                            icon: Icons.payments_rounded,
                            label:
                                entry.paymentMode == 'CONTADO'
                                    ? 'Contado'
                                    : entry.paymentMode == 'CRÉDITO'
                                        ? 'Crédito'
                                        : entry.paymentMode!,
                            color:
                                entry.paymentMode == 'CRÉDITO'
                                    ? Colors.purple.shade700
                                    : AppColors.teal,
                            bgColor:
                                entry.paymentMode == 'CRÉDITO'
                                    ? Colors.purple.shade400.withValues(
                                      alpha: 0.12,
                                    )
                                    : AppColors.teal.withValues(alpha: 0.12),
                          ),
                        if (hasDoc)
                          _Pill(
                            icon: Icons.receipt_long_rounded,
                            label:
                                '${entry.documentType} ${entry.documentNumber}',
                            color: AppColors.teal,
                            bgColor: AppColors.teal.withValues(alpha: 0.12),
                          ),
                        if (entry.purchaseOrderId != null)
                          _Pill(
                            icon: Icons.link_rounded,
                            label:
                                'Orden #${entry.purchaseOrderId!.substring(0, entry.purchaseOrderId!.length >= 8 ? 8 : entry.purchaseOrderId!.length).toUpperCase()}',
                            color: Colors.purple.shade700,
                            bgColor: Colors.purple.shade400.withValues(
                              alpha: 0.12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _CompactKpiRibbon extends StatelessWidget {
  final int count;
  final int totalCount;
  final double totalAmount;
  final String? warehouseFilter;

  const _CompactKpiRibbon({
    required this.count,
    required this.totalCount,
    required this.totalAmount,
    this.warehouseFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(
              Icons.move_to_inbox_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            const Text(
              'Entradas: ',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$count de $totalCount',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 16, color: AppColors.border),
            const SizedBox(width: 14),
            const Icon(Icons.payments_rounded, size: 16, color: AppColors.teal),
            const SizedBox(width: 6),
            const Text(
              'Inversión Pág: ',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'S/ ${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.teal,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (warehouseFilter != null && warehouseFilter != 'Todos') ...[
              const SizedBox(width: 14),
              Container(width: 1, height: 16, color: AppColors.border),
              const SizedBox(width: 14),
              const Icon(
                Icons.warehouse_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              const Text(
                'Almacén: ',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                warehouseFilter!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WarehouseFilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WarehouseFilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    this.focusNode,
    required this.hint,
    required this.onSubmitted,
    required this.onClear,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 40,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  onPressed: onClear,
                  tooltip: 'Limpiar búsqueda',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              if (MediaQuery.sizeOf(context).width >= 800)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.slateLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Ctrl K',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 11,
          ),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppShimmer(width: 38, height: 38, borderRadius: 10),
                  const SizedBox(width: 10),
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
              const SizedBox(height: 12),
              Row(
                children: const [
                  AppShimmer(width: 90, height: 24, borderRadius: 6),
                  SizedBox(width: 8),
                  AppShimmer(width: 120, height: 24, borderRadius: 6),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
