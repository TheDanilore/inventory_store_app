import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_entry_item_model.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_entry_items_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_entries_repository.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entries/inventory_entries_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entries/inventory_entries_state.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/inventory_entry_detail_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/inventory_entries_table_view.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/adaptive_side_sheet.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';

class InventoryEntriesScreen extends StatefulWidget {
  final String? targetEntryId;

  const InventoryEntriesScreen({super.key, this.targetEntryId});

  @override
  State<InventoryEntriesScreen> createState() => _InventoryEntriesScreenState();
}

class _InventoryEntriesScreenState extends State<InventoryEntriesScreen> {
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _hasDraft = false;
  bool _isTableView = true;
  bool _isSideSheetOpen = false;
  InventoryEntryEntity?
  _selectedEntry; // State for Master-Detail / Table selection
  String? _pendingTargetEntryId;
  bool _isFetchingTargetEntry = false;
  InventoryEntriesLoaded? _lastLoadedState;

  @override
  void initState() {
    super.initState();
    _pendingTargetEntryId = widget.targetEntryId;
    _checkDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
        context.read<InventoryEntriesCubit>().init();
      }
    });
  }

  @override
  void didUpdateWidget(covariant InventoryEntriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetEntryId != oldWidget.targetEntryId) {
      if (widget.targetEntryId == null) {
        if (_selectedEntry != null) {
          setState(() => _selectedEntry = null);
        }
        return;
      }
      if (widget.targetEntryId == _selectedEntry?.id) {
        return;
      }
      _pendingTargetEntryId = widget.targetEntryId;
      final state = context.read<InventoryEntriesCubit>().state;
      if (state is InventoryEntriesLoaded) {
        final isTablet = MediaQuery.sizeOf(context).width >= 640;
        _resolveTargetEntry(state.entries, isTablet);
      }
    }
  }

  void _selectEntry(InventoryEntryEntity? entry, {bool updateUrl = true}) {
    setState(() => _selectedEntry = entry);

    if (updateUrl && mounted) {
      final isTablet = MediaQuery.sizeOf(context).width >= 640;
      if (isTablet) {
        if (entry != null) {
          context.replace('/inventory-entries?selectedId=${entry.id}');
        } else {
          context.replace('/inventory-entries');
        }
      }
    }
  }

  void _resolveTargetEntry(List<InventoryEntryEntity> entries, bool isTablet) {
    final targetId = _pendingTargetEntryId;
    if (targetId == null) return;

    final foundIndex = entries.indexWhere((e) => e.id == targetId);
    if (foundIndex != -1) {
      _pendingTargetEntryId = null;
      _selectEntry(entries[foundIndex], updateUrl: isTablet);
      if (!isTablet) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedEntry != null) {
            _showDetailBottomSheet(context, _selectedEntry!);
          }
        });
      } else if (_isTableView) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedEntry != null) {
            _openDesktopDetailSheet(_selectedEntry!);
          }
        });
      }
    } else {
      _pendingTargetEntryId = null;
      _fetchAndSelectEntry(targetId, isTablet);
    }
  }

  Future<void> _fetchAndSelectEntry(String targetId, bool isTablet) async {
    if (_isFetchingTargetEntry) return;
    _isFetchingTargetEntry = true;
    try {
      final entry = await sl<InventoryEntriesRepository>().getEntryById(
        targetId,
      );
      if (!mounted) return;
      if (entry != null) {
        _selectEntry(entry, updateUrl: isTablet);
        if (!isTablet) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedEntry != null) {
              _showDetailBottomSheet(context, _selectedEntry!);
            }
          });
        } else if (_isTableView) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedEntry != null) {
              _openDesktopDetailSheet(_selectedEntry!);
            }
          });
        }
      } else {
        AppSnackbar.show(
          context,
          message: 'No se pudo encontrar la entrada de inventario asociada.',
          type: SnackbarType.error,
        );
      }
    } catch (e, st) {
      LoggerService.e(
        'Error al obtener entrada $targetId',
        error: e,
        stackTrace: st,
        tag: 'InventoryEntriesScreen',
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error de conexión al cargar la entrada seleccionada.',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingTargetEntry = false);
      } else {
        _isFetchingTargetEntry = false;
      }
    }
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
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  // --- REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) ---
  bool get _isInputFieldFocused {
    if (_searchFocusNode.hasFocus) return true;
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final context = primaryFocus.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorStateOfType<EditableTextState>() != null;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo editable, aislar atajos globales
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Atajo [/] -> Enfocar buscador
    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // Atajo [N] -> Nueva Entrada
    if (key == LogicalKeyboardKey.keyN) {
      _onNewEntry();
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar entradas
    if (key == LogicalKeyboardKey.keyR) {
      context.read<InventoryEntriesCubit>().loadEntries(page: 0);
      AppSnackbar.show(
        context,
        message: 'Actualizando historial de entradas...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    // Atajo [V] -> Alternar Vista (Tabla Pro vs Tarjetas)
    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    // Atajo [Escape] -> Limpiar búsqueda o cerrar detalle
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedEntry != null) {
        setState(() => _selectedEntry = null);
        return KeyEventResult.handled;
      }
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }

    // Flechas arriba y abajo para navegar entradas y [Enter] para abrir detalles
    final state = context.read<InventoryEntriesCubit>().state;
    final loadedState =
        state is InventoryEntriesLoaded ? state : _lastLoadedState;
    if (loadedState != null && loadedState.entries.isNotEmpty) {
      final entries = loadedState.entries;
      final currentIndex =
          _selectedEntry != null
              ? entries.indexWhere((e) => e.id == _selectedEntry!.id)
              : -1;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final nextIndex =
            currentIndex == -1
                ? 0
                : (currentIndex + 1).clamp(0, entries.length - 1);
        _selectEntry(entries[nextIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final prevIndex =
            currentIndex == -1
                ? 0
                : (currentIndex - 1).clamp(0, entries.length - 1);
        _selectEntry(entries[prevIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final entry = _selectedEntry ?? entries.first;
        final isTablet = MediaQuery.sizeOf(context).width >= 640;
        if (isTablet) {
          _openDesktopDetailSheet(entry);
        } else {
          _showDetailBottomSheet(context, entry);
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _onNewEntry() async {
    final result = await context.push('/inventory-entries/form');
    _checkDraft();
    if (result == true && mounted) {
      context.read<InventoryEntriesCubit>().loadEntries(page: 0);
    }
  }

  Future<void> _openDesktopDetailSheet(InventoryEntryEntity entry) async {
    if (!mounted || _isSideSheetOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _isSideSheetOpen = true;
    _selectEntry(entry, updateUrl: true);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth >= 1440 ? 660.0 : 610.0;

    await AdaptiveSideSheet.show<void>(
      context: context,
      desktopWidth: drawerWidth,
      barrierLabel: 'Cerrar detalle de entrada',
      builder: (dialogContext, isSlideOver) {
        return InventoryEntryDetailSheet(
          entry: entry,
          isBottomSheet: !isSlideOver,
          loadItems: () => _loadEntryItems(entry.id, null),
        );
      },
    );
    _isSideSheetOpen = false;
    if (mounted && _isTableView) {
      _selectEntry(null, updateUrl: true);
    }
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
        variantAttrs: attrsText.isNotEmpty ? attrsText : '',
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
      if (_isTableView) {
        _openDesktopDetailSheet(entry);
      } else {
        _selectEntry(entry, updateUrl: true);
      }
    } else {
      _showDetailBottomSheet(context, entry);
    }
  }

  void _showDetailBottomSheet(
    BuildContext context,
    InventoryEntryEntity entry,
  ) {
    _openDesktopDetailSheet(entry);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = MediaQuery.sizeOf(context).width >= 640;

    return BlocConsumer<InventoryEntriesCubit, InventoryEntriesState>(
      listener: (context, state) {
        if (state is InventoryEntriesError) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.error,
          );
        }
        if (state is InventoryEntriesLoaded && _pendingTargetEntryId != null) {
          _resolveTargetEntry(state.entries, isDesktopOrTablet);
        }
      },
      builder: (context, state) {
        if (state is InventoryEntriesLoaded) {
          _lastLoadedState = state;
        }
        final loadedState =
            state is InventoryEntriesLoaded ? state : _lastLoadedState;

        if (loadedState == null && state is InventoryEntriesError) {
          return AdminLayout(
            title: 'Historial de Entradas',
            body: Center(
              child: AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Error al cargar entradas',
                message: state.message,
                action: ElevatedButton.icon(
                  onPressed:
                      () => context.read<InventoryEntriesCubit>().loadEntries(
                        page: 0,
                      ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ),
            ),
          );
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

        // Sincronización de selección ordinaria
        if (_pendingTargetEntryId == null) {
          if (currentState.entries.isNotEmpty) {
            if (_selectedEntry != null) {
              final index = currentState.entries.indexWhere(
                (e) => e.id == _selectedEntry!.id,
              );
              if (index != -1) {
                _selectedEntry = currentState.entries[index];
              }
            } else if (isDesktopOrTablet && !_isTableView) {
              _selectedEntry = currentState.entries.first;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedEntry != null) {
                  _selectEntry(_selectedEntry, updateUrl: true);
                }
              });
            }
          } else {
            _selectedEntry = null;
          }
        }

        final displayEntries =
            (_selectedEntry != null &&
                    !currentState.entries.any(
                      (e) => e.id == _selectedEntry!.id,
                    ))
                ? [_selectedEntry!, ...currentState.entries]
                : currentState.entries;

        final double totalAmount = currentState.entries.fold<double>(
          0,
          (s, e) => s + e.totalAmount,
        );

        return AdminLayout(
          title: 'Historial de Entradas',
          actions:
              isDesktopOrTablet
                  ? null
                  : [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Actualizar entradas',
                      onPressed: () {
                        context.read<InventoryEntriesCubit>().loadEntries(
                          page: 0,
                        );
                      },
                    ),
                  ],
          floatingActionButton:
              !isDesktopOrTablet
                  ? FloatingActionButton.extended(
                    onPressed: _onNewEntry,
                    icon: Icon(
                      _hasDraft ? Icons.edit_note_rounded : Icons.add_rounded,
                    ),
                    label: Text(
                      _hasDraft ? 'Borrador' : 'Nueva Entrada',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor:
                        _hasDraft ? const Color(0xFFF59E0B) : AppColors.primary,
                    foregroundColor: Colors.white,
                  )
                  : null,
          body: Focus(
            focusNode: _screenFocusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 640;

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    context.read<InventoryEntriesCubit>().loadEntries(page: 0);
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── 0. CABECERA EJECUTIVA STRIPE / LINEAR (ARRIBA DE MÉTRICAS) ──
                      SliverToBoxAdapter(
                        child: AdminPageHeader(
                          title: 'Entradas de Inventario',
                          subtitle:
                              'Gestiona las entradas de inventario, recepcion de mercancía y ajuste de inventario',
                          isDesktop: isDesktopOrTablet,
                          actions: [
                            AdminHeaderButton.primary(
                              label:
                                  _hasDraft
                                      ? 'Continuar Borrador'
                                      : 'Nueva Entrada',
                              icon:
                                  _hasDraft
                                      ? Icons.edit_note_rounded
                                      : Icons.add_box_rounded,
                              tooltip:
                                  _hasDraft
                                      ? 'Continuar entrada (Atajo: N)'
                                      : 'Nueva entrada (Atajo: N)',
                              onPressed:
                                  () => context.go('/inventory-entries/form'),
                            ),
                          ],
                        ),
                      ),

                      // ── 1. Aviso de Borrador ──────────────────────────────
                      if (_hasDraft)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit_document,
                                  color: AppColors.warning,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Tienes un borrador de entrada en progreso.',
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                FilledButton.tonal(
                                  onPressed: () {
                                    context.go('/inventory-entries/form');
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: AppColors.warning
                                        .withValues(alpha: 0.2),
                                    foregroundColor: AppColors.warning,
                                  ),
                                  child: const Text('Continuar'),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── 2. Bento KPI Ribbon ───────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _InventoryEntriesBentoKpiBar(
                            count: currentState.entries.length,
                            totalCount: currentState.totalCount,
                            totalAmount: totalAmount,
                            warehouseName: currentState.warehouseFilter,
                            isDesktop: isTablet,
                          ),
                        ),
                      ),

                      // ── 3. Toolbar Pro Unificado ─────────────────────────
                      SliverToBoxAdapter(
                        child: AdminProToolbar(
                          searchController: _searchCtrl,
                          searchFocusNode: _searchFocusNode,
                          searchHint: 'Buscar proveedor o comprobante...',
                          onSearchChanged: (v) {
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
                          onClearSearch: () {
                            _searchDebounce?.cancel();
                            _searchCtrl.clear();
                            context
                                .read<InventoryEntriesCubit>()
                                .setSearchQuery('');
                          },
                          filterGroups: [
                            AdminFilterGroup<String>(
                              title: 'Almacén',
                              icon: Icons.storefront_rounded,
                              selected: currentState.warehouseFilter,
                              defaultValue: 'TODOS',
                              onSelected:
                                  context
                                      .read<InventoryEntriesCubit>()
                                      .setWarehouseFilter,
                              options: [
                                for (final w
                                    in currentState.availableWarehouses)
                                  AdminFilterOption<String>(
                                    value: w,
                                    label: w == 'TODOS' ? 'Todos' : w,
                                    icon: Icons.storefront_rounded,
                                  ),
                              ],
                            ),
                          ],
                          mobileExtraFilters: [
                            DateFilterCalendar(
                              height: 40,
                              borderRadius: BorderRadius.circular(10),
                              dateRange: currentState.dateRange,
                              onDateRangeSelected:
                                  context
                                      .read<InventoryEntriesCubit>()
                                      .setDateRange,
                              onClear:
                                  () => context
                                      .read<InventoryEntriesCubit>()
                                      .setDateRange(null),
                            ),
                          ],
                          activeFiltersCount:
                              (currentState.warehouseFilter != 'TODOS'
                                  ? 1
                                  : 0) +
                              (currentState.dateRange != null ? 1 : 0),
                          onClearFilters: () {
                            final c = context.read<InventoryEntriesCubit>();
                            c.setWarehouseFilter('TODOS');
                            c.setDateRange(null);
                          },
                          viewToggleConfig: AdminProViewToggleConfig(
                            isTableView: _isTableView,
                            onToggleTableView:
                                (val) => setState(() => _isTableView = val),
                          ),
                          onRefresh: () {
                            context.read<InventoryEntriesCubit>().loadEntries(
                              page: 0,
                            );
                          },
                          isDesktop: isTablet,
                        ),
                      ),

                      // ── 5. Contenido Principal: Tabla Pro o Split/Cards ───
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: _buildListOrTableSliver(
                          context: context,
                          state: currentState,
                          displayEntries: displayEntries,
                          isLoading: isLoading,
                          isTablet: isTablet,
                        ),
                      ),

                      // ── 6. Paginación Fluida al Pie del Scroll ────────────
                      _buildPaginationSliver(context, currentState, isLoading),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildListOrTableSliver({
    required BuildContext context,
    required InventoryEntriesLoaded state,
    required List<InventoryEntryEntity> displayEntries,
    required bool isLoading,
    required bool isTablet,
  }) {
    if (isLoading) {
      if (_isTableView && isTablet) {
        return const SliverToBoxAdapter(child: AppTableShimmer());
      }
      return const SliverToBoxAdapter(child: _EntriesSkeleton());
    }

    if (state.entries.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          key: ValueKey('empty'),
          icon: Icons.inbox_outlined,
          title: 'Sin Resultados',
          message: 'Sin resultados para los filtros aplicados',
        ),
      );
    }

    if (_isTableView && isTablet) {
      return SliverToBoxAdapter(
        child: InventoryEntriesTableView(
          entries: displayEntries,
          selectedEntry: _selectedEntry,
          onSelectEntry: (e) => _openDesktopDetailSheet(e),
          onRefresh: () {
            context.read<InventoryEntriesCubit>().loadEntries(page: 0);
          },
        ),
      );
    }

    if (isTablet) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 440,
          mainAxisExtent: 180,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, i) {
          final entry = displayEntries[i];
          return _EntryCard(
            entry: entry,
            isSelected: _selectedEntry?.id == entry.id,
            onTap: () => _openDesktopDetailSheet(entry),
          );
        }, childCount: displayEntries.length),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, i) {
        final entry = displayEntries[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EntryCard(
            entry: entry,
            isSelected: false,
            onTap: () => _onEntryTapped(context, entry, false),
          ),
        );
      }, childCount: displayEntries.length),
    );
  }

  Widget _buildPaginationSliver(
    BuildContext context,
    InventoryEntriesLoaded state,
    bool isLoading,
  ) {
    if (isLoading || state.entries.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox(height: 24));
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(opacity: 0.03),
          ),
          child: AdminPageBlocks(
            currentPage: state.currentPage,
            totalPages: state.totalPages,
            onPageChanged: context.read<InventoryEntriesCubit>().goToPage,
            totalItems: state.totalCount,
            itemName: 'entradas',
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BENTO KPI BAR
// ══════════════════════════════════════════════════════════════════════════════

class _InventoryEntriesBentoKpiBar extends StatelessWidget {
  final int count;
  final int totalCount;
  final double totalAmount;
  final String warehouseName;
  final bool isDesktop;

  const _InventoryEntriesBentoKpiBar({
    required this.count,
    required this.totalCount,
    required this.totalAmount,
    required this.warehouseName,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return AdminKpiMetricsBar(
      isDesktop: isDesktop,
      padding: EdgeInsets.zero,
      items: [
        AdminKpiItem(
          title: 'Total Entradas',
          value: totalCount > 0 ? '$totalCount' : '$count',
          subtitle: 'Entradas registradas',
          icon: Icons.move_to_inbox_rounded,
          accentColor: AppColors.tealDark,
          gradientColors: const [Colors.white, Color(0xFFF0FDFA)],
          iconGradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
          borderColor: const Color(0xFF99F6E4),
          glowColor: const Color(0x2E0D9488),
        ),
        AdminKpiItem(
          title: 'Inversión Total',
          value: 'S/ ${totalAmount.toStringAsFixed(2)}',
          subtitle: 'Inversión acumulada',
          icon: Icons.payments_rounded,
          accentColor: AppColors.successDark,
          gradientColors: const [Colors.white, Color(0xFFECFDF5)],
          iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
          borderColor: const Color(0xFFA7F3D0),
          glowColor: const Color(0x2E10B981),
        ),
        AdminKpiItem(
          title: 'Almacén Destino',
          value:
              warehouseName == 'TODOS' ? 'Todos los Almacenes' : warehouseName,
          subtitle: 'Filtro aplicado',
          icon: Icons.storefront_rounded,
          accentColor: AppColors.warningDark,
          gradientColors: const [Colors.white, Color(0xFFFFFBEB)],
          iconGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
          borderColor: const Color(0xFFFDE68A),
          glowColor: const Color(0x2EF59E0B),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ENTRY CARD
// ══════════════════════════════════════════════════════════════════════════════

class _EntryCard extends StatefulWidget {
  final InventoryEntryEntity entry;
  final VoidCallback onTap;
  final bool isSelected;

  const _EntryCard({
    required this.entry,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final entry = widget.entry;
    final hasDoc =
        entry.documentType != 'NINGUNO' &&
        entry.documentNumber != null &&
        entry.documentNumber!.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color:
              widget.isSelected
                  ? AppColors.teal.withValues(alpha: 0.04)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                widget.isSelected
                    ? AppColors.teal
                    : _isHovered
                    ? AppColors.teal.withValues(alpha: 0.35)
                    : const Color(0xFFE2E8F0),
            width: (widget.isSelected || _isHovered) ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: widget.isSelected ? 0.08 : (_isHovered ? 0.06 : 0.025),
              ),
              blurRadius: (widget.isSelected || _isHovered) ? 14 : 8,
              offset: Offset(0, (widget.isSelected || _isHovered) ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                if (widget.isSelected)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3.5,
                      decoration: const BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(14),
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
                              color: AppColors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.move_to_inbox_rounded,
                              color: AppColors.tealDark,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.createdAt != null
                                      ? fmt.format(entry.createdAt!)
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
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
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entry.itemCount} prod. (${entry.totalQuantity.toInt()} uds.)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (entry.warehouseName != null)
                            _Pill(
                              icon: Icons.storefront_rounded,
                              label: entry.warehouseName!,
                              color: AppColors.textSecondary,
                              bgColor: AppColors.background,
                            ),
                          _Pill(
                            icon: Icons.payments_rounded,
                            label: entry.paymentMode ?? 'Contado',
                            color: AppColors.successDark,
                            bgColor: AppColors.successLight,
                          ),
                          if (hasDoc)
                            _Pill(
                              icon: Icons.receipt_rounded,
                              label:
                                  '${entry.documentType}: ${entry.documentNumber}',
                              color: AppColors.textSecondary,
                              bgColor: AppColors.background,
                            ),
                          if (entry.purchaseOrderId != null)
                            _Pill(
                              icon: Icons.link_rounded,
                              label:
                                  'Orden #${entry.purchaseOrderId!.length >= 8 ? entry.purchaseOrderId!.substring(0, 8).toUpperCase() : entry.purchaseOrderId!.toUpperCase()}',
                              color: const Color(0xFF7E22CE),
                              bgColor: const Color(0xFFFAF5FF),
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
