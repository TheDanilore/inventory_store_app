import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_entry_item_model.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_entries_repository.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_entry_items_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entries/inventory_entries_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entries/inventory_entries_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/inventory_entries_kpi_bar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/inventory_entries_skeleton.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/inventory_entries_table_view.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/inventory_entry_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/inventory_entry_detail_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

/// Pantalla Ejecutiva y de Alto Rendimiento para el Historial de Entradas de Inventario.
///
/// Implementa:
/// - **Zero-Shimmer (Stale-While-Revalidate)**: Renderizado instantáneo desde memoria L1 sin skeleton al volver de otra vista.
/// - **Aislamiento de Rebuilds**: Árboles de widgets granulares mediante [BlocSelector].
/// - **Bajo Consumo de RAM/GPU**: Tarjetas y tablas virtualizadas con [RepaintBoundary].
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
  InventoryEntryEntity? _selectedEntry;
  String? _pendingTargetEntryId;
  bool _isFetchingTargetEntry = false;

  @override
  void initState() {
    super.initState();
    _pendingTargetEntryId = widget.targetEntryId;
    _checkDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
        final cubit = context.read<InventoryEntriesCubit>();
        // Zero-Shimmer: Solo iniciar si no hay datos cargados previamente
        if (cubit.state is! InventoryEntriesLoaded ||
            (cubit.state as InventoryEntriesLoaded).entries.isEmpty) {
          cubit.init();
        }
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

    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyN) {
      _onNewEntry();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyR) {
      context.read<InventoryEntriesCubit>().loadEntries(page: 0);
      AppSnackbar.show(
        context,
        message: 'Actualizando historial de entradas...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

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

    final state = context.read<InventoryEntriesCubit>().state;
    if (state is InventoryEntriesLoaded && state.entries.isNotEmpty) {
      final entries = state.entries;
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

    await AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: drawerWidth,
      barrierLabel: 'Cerrar detalle de entrada',
      builder: (dialogContext) {
        return InventoryEntryDetailSheet(
          entry: entry,
          isBottomSheet: !AdaptiveDetailSheet.isSideSheet(dialogContext),
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
    return itemsDynamic
        .map(
          (r) => InventoryEntryItemModel.fromSupabaseQueryResult(
            r as Map<String, dynamic>,
            entryId,
          ),
        )
        .toList();
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
    final cubit = context.read<InventoryEntriesCubit>();

    return BlocListener<InventoryEntriesCubit, InventoryEntriesState>(
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
      child: AdminLayout(
        title: 'Historial de Entradas',
        actions:
            isDesktopOrTablet
                ? null
                : [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Actualizar entradas',
                    onPressed: () => cubit.loadEntries(page: 0),
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
                onRefresh: () async => cubit.loadEntries(page: 0),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── 0. Cabecera Ejecutiva Stripe / Linear ──
                    SliverToBoxAdapter(
                      child: AdminPageHeader(
                        title: 'Entradas de Inventario',
                        subtitle:
                            'Gestiona las entradas de inventario, recepción de mercancía y ajuste de inventario',
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

                    // ── 1. Aviso de Borrador ──
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
                                  backgroundColor: AppColors.warning.withValues(
                                    alpha: 0.2,
                                  ),
                                  foregroundColor: AppColors.warning,
                                ),
                                child: const Text('Continuar'),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── 2. Bento KPI Ribbon (Aislado con BlocSelector) ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: BlocSelector<
                          InventoryEntriesCubit,
                          InventoryEntriesState,
                          ({
                            int count,
                            int totalCount,
                            double totalAmount,
                            String warehouse,
                          })
                        >(
                          selector: (state) {
                            if (state is InventoryEntriesLoaded) {
                              final total = state.entries.fold<double>(
                                0,
                                (s, e) => s + e.totalAmount,
                              );
                              return (
                                count: state.entries.length,
                                totalCount: state.totalCount,
                                totalAmount: total,
                                warehouse: state.warehouseFilter,
                              );
                            }
                            return (
                              count: 0,
                              totalCount: 0,
                              totalAmount: 0.0,
                              warehouse: 'Todos',
                            );
                          },
                          builder: (context, data) {
                            return InventoryEntriesBentoKpiBar(
                              count: data.count,
                              totalCount: data.totalCount,
                              totalAmount: data.totalAmount,
                              warehouseName: data.warehouse,
                              isDesktop: isTablet,
                            );
                          },
                        ),
                      ),
                    ),

                    // ── 3. Toolbar Pro Unificado (Aislado con BlocSelector) ──
                    SliverToBoxAdapter(
                      child: BlocSelector<
                        InventoryEntriesCubit,
                        InventoryEntriesState,
                        ({
                          String warehouse,
                          List<String> availableWarehouses,
                          DateTimeRange? dateRange,
                        })
                      >(
                        selector: (state) {
                          if (state is InventoryEntriesLoaded) {
                            return (
                              warehouse: state.warehouseFilter,
                              availableWarehouses: state.availableWarehouses,
                              dateRange: state.dateRange,
                            );
                          }
                          return (
                            warehouse: 'Todos',
                            availableWarehouses: const ['Todos'],
                            dateRange: null,
                          );
                        },
                        builder: (context, filterData) {
                          return AdminProToolbar(
                            searchController: _searchCtrl,
                            searchFocusNode: _searchFocusNode,
                            searchHint: 'Buscar proveedor o comprobante...',
                            onSearchChanged: (v) {
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 300),
                                () {
                                  if (mounted) {
                                    cubit.setSearchQuery(v);
                                  }
                                },
                              );
                            },
                            onClearSearch: () {
                              _searchDebounce?.cancel();
                              _searchCtrl.clear();
                              cubit.setSearchQuery('');
                            },
                            filterGroups: [
                              AdminFilterGroup<String>(
                                title: 'Almacén',
                                icon: Icons.storefront_rounded,
                                selected: filterData.warehouse,
                                defaultValue: 'Todos',
                                onSelected: cubit.setWarehouseFilter,
                                options: [
                                  for (final w
                                      in filterData.availableWarehouses)
                                    AdminFilterOption<String>(
                                      value: w,
                                      label:
                                          (w == 'TODOS' || w == 'Todos')
                                              ? 'Todos'
                                              : w,
                                      icon: Icons.storefront_rounded,
                                    ),
                                ],
                              ),
                            ],
                            mobileExtraFilters: [
                              DateFilterCalendar(
                                height: 40,
                                borderRadius: BorderRadius.circular(10),
                                dateRange: filterData.dateRange,
                                onDateRangeSelected: cubit.setDateRange,
                                onClear: () => cubit.setDateRange(null),
                              ),
                            ],
                            activeFiltersCount:
                                ((filterData.warehouse != 'Todos' &&
                                        filterData.warehouse != 'TODOS')
                                    ? 1
                                    : 0) +
                                (filterData.dateRange != null ? 1 : 0),
                            onClearFilters: () {
                              cubit.setWarehouseFilter('Todos');
                              cubit.setDateRange(null);
                            },
                            viewToggleConfig: AdminProViewToggleConfig(
                              isTableView: _isTableView,
                              onToggleTableView:
                                  (val) => setState(() => _isTableView = val),
                            ),
                            onRefresh: () => cubit.loadEntries(page: 0),
                            isDesktop: isTablet,
                          );
                        },
                      ),
                    ),

                    // ── 4. Contenido Principal: Tabla Pro o Tarjetas (Aislado con BlocSelector) ──
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: BlocSelector<
                        InventoryEntriesCubit,
                        InventoryEntriesState,
                        ({List<InventoryEntryEntity> entries, bool isLoading})
                      >(
                        selector: (state) {
                          if (state is InventoryEntriesLoaded) {
                            return (entries: state.entries, isLoading: false);
                          }
                          if (state is InventoryEntriesLoading) {
                            return (
                              entries: const <InventoryEntryEntity>[],
                              isLoading: true,
                            );
                          }
                          return (
                            entries: const <InventoryEntryEntity>[],
                            isLoading: false,
                          );
                        },
                        builder: (context, data) {
                          return _buildListOrTableSliver(
                            context: context,
                            entries: data.entries,
                            isLoading: data.isLoading,
                            isTablet: isTablet,
                          );
                        },
                      ),
                    ),

                    // ── 5. Paginación Fluida (Aislada con BlocSelector) ──
                    BlocSelector<
                      InventoryEntriesCubit,
                      InventoryEntriesState,
                      ({
                        int currentPage,
                        int totalPages,
                        int totalCount,
                        bool hasEntries,
                      })
                    >(
                      selector: (state) {
                        if (state is InventoryEntriesLoaded) {
                          return (
                            currentPage: state.currentPage,
                            totalPages: state.totalPages,
                            totalCount: state.totalCount,
                            hasEntries: state.entries.isNotEmpty,
                          );
                        }
                        return (
                          currentPage: 0,
                          totalPages: 1,
                          totalCount: 0,
                          hasEntries: false,
                        );
                      },
                      builder: (context, pageData) {
                        if (!pageData.hasEntries) {
                          return const SliverToBoxAdapter(
                            child: SizedBox(height: 24),
                          );
                        }
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppColors.cardShadow(opacity: 0.03),
                              ),
                              child: AdminPageBlocks(
                                currentPage: pageData.currentPage,
                                totalPages: pageData.totalPages,
                                onPageChanged: cubit.goToPage,
                                totalItems: pageData.totalCount,
                                itemName: 'entradas',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildListOrTableSliver({
    required BuildContext context,
    required List<InventoryEntryEntity> entries,
    required bool isLoading,
    required bool isTablet,
  }) {
    // Zero-Shimmer: Solo mostrar esqueleto si realmente está en carga inicial y la lista está vacía
    final hasCachedEntries = entries.isNotEmpty;
    if (isLoading && !hasCachedEntries) {
      if (_isTableView && isTablet) {
        return const SliverToBoxAdapter(child: AppTableShimmer());
      }
      return const SliverToBoxAdapter(child: InventoryEntriesSkeleton());
    }

    if (entries.isEmpty) {
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
          entries: entries,
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
          final entry = entries[i];
          return InventoryEntryCard(
            key: ValueKey(entry.id),
            entry: entry,
            isSelected: _selectedEntry?.id == entry.id,
            onTap: () => _openDesktopDetailSheet(entry),
          );
        }, childCount: entries.length),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, i) {
        final entry = entries[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InventoryEntryCard(
            key: ValueKey(entry.id),
            entry: entry,
            isSelected: false,
            onTap: () => _onEntryTapped(context, entry, false),
          ),
        );
      }, childCount: entries.length),
    );
  }
}
