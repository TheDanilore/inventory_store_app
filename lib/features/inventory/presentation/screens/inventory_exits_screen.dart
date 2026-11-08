import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/features/inventory/data/utils/inventory_exits_pdf_generator.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exits/inventory_exits_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exits/inventory_exits_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/inventory_exit_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/inventory_exit_detail_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/inventory_exits_bento_kpi_bar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/inventory_exits_table_view.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_skeleton.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class InventoryExitsScreen extends StatefulWidget {
  final String? targetExitId;

  const InventoryExitsScreen({super.key, this.targetExitId});

  @override
  State<InventoryExitsScreen> createState() => _InventoryExitsScreenState();
}

class _InventoryExitsScreenState extends State<InventoryExitsScreen> {
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  Timer? _searchDebounce;

  bool _hasDraft = false;
  bool _isTableView = true;
  bool _isSideSheetOpen = false;
  InventoryExitEntity? _selectedExit;
  String? _pendingTargetExitId;

  @override
  void initState() {
    super.initState();
    _pendingTargetExitId = widget.targetExitId;
    _checkDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
        final cubit = context.read<InventoryExitsCubit>();
        _searchCtrl.text = cubit.state.searchQuery;

        // Zero-Shimmer (Stale-While-Revalidate):
        // Si ya existen datos en memoria L1, se muestran en Frame 0 sin skeleton
        // y se revalidan silenciosamente en background.
        if (cubit.state.exits.isEmpty) {
          cubit.initLoad();
        } else {
          cubit.initLoad(forceRefresh: false);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant InventoryExitsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetExitId != oldWidget.targetExitId) {
      if (widget.targetExitId == null) {
        if (_selectedExit != null) {
          setState(() => _selectedExit = null);
        }
        return;
      }
      if (widget.targetExitId == _selectedExit?.id) {
        return;
      }
      _pendingTargetExitId = widget.targetExitId;
      final exits = context.read<InventoryExitsCubit>().state.exits;
      final isTablet = MediaQuery.sizeOf(context).width >= 640;
      _resolveTargetExit(exits, isTablet);
    }
  }

  void _selectExit(InventoryExitEntity? exit, {bool updateUrl = true}) {
    setState(() => _selectedExit = exit);

    if (updateUrl && mounted) {
      final isTablet = MediaQuery.sizeOf(context).width >= 640;
      if (isTablet) {
        if (exit != null) {
          context.replace('/inventory-exits?selectedId=${exit.id}');
        } else {
          context.replace('/inventory-exits');
        }
      }
    }
  }

  void _resolveTargetExit(List<InventoryExitEntity> exits, bool isTablet) {
    final targetId = _pendingTargetExitId;
    if (targetId == null) return;

    final foundIndex = exits.indexWhere((e) => e.id == targetId);
    if (foundIndex != -1) {
      _pendingTargetExitId = null;
      _selectExit(exits[foundIndex], updateUrl: isTablet);
      if (!isTablet) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedExit != null) {
            _showDetailBottomSheet(context, _selectedExit!);
          }
        });
      } else if (_isTableView) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedExit != null) {
            _openDesktopDetailSheet(_selectedExit!);
          }
        });
      }
    }
  }

  Future<void> _checkDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftString = prefs.getString('inventory_exit_draft');
    if (mounted) {
      setState(() {
        _hasDraft = draftString != null && draftString.isNotEmpty;
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

    // Atajo [/] -> Enfocar buscador
    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // Atajo [N] -> Nueva Salida
    if (key == LogicalKeyboardKey.keyN) {
      _onNewExit();
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar salidas
    if (key == LogicalKeyboardKey.keyR) {
      context.read<InventoryExitsCubit>().loadExits(isRefresh: true);
      AppSnackbar.show(
        context,
        message: 'Actualizando historial de salidas...',
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
      if (_selectedExit != null) {
        setState(() => _selectedExit = null);
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }

    // Flechas arriba y abajo para navegar salidas
    final state = context.read<InventoryExitsCubit>().state;
    if (state.exits.isNotEmpty) {
      final exits = state.exits;
      final currentIndex =
          _selectedExit != null
              ? exits.indexWhere((e) => e.id == _selectedExit!.id)
              : -1;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final nextIndex = (currentIndex + 1).clamp(0, exits.length - 1);
        _selectExit(exits[nextIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, exits.length - 1);
        _selectExit(exits[prevIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final exit = _selectedExit ?? exits.first;
        final isTablet = MediaQuery.sizeOf(context).width >= 640;
        if (isTablet) {
          _openDesktopDetailSheet(exit);
        } else {
          _showDetailBottomSheet(context, exit);
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _onNewExit() async {
    await context.push('/inventory-exits/form');
    _checkDraft();
  }

  Future<void> _openDesktopDetailSheet(InventoryExitEntity exit) async {
    if (!mounted || _isSideSheetOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _isSideSheetOpen = true;
    _selectExit(exit, updateUrl: true);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth >= 1440 ? 660.0 : 610.0;

    final cubit = context.read<InventoryExitsCubit>();

    await AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: drawerWidth,
      barrierLabel: 'Cerrar detalle de salida',
      builder: (dialogContext) {
        return InventoryExitDetailSheet(
          exitData: exit,
          isBottomSheet: !AdaptiveDetailSheet.isSideSheet(dialogContext),
          loadItems: () => cubit.loadExitItems(exit.id),
        );
      },
    );
    _isSideSheetOpen = false;
    if (mounted && _isTableView) {
      _selectExit(null, updateUrl: true);
    }
  }

  void _showDetailBottomSheet(
    BuildContext context,
    InventoryExitEntity exitData,
  ) {
    _openDesktopDetailSheet(exitData);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = MediaQuery.sizeOf(context).width >= 640;
    final cubit = context.read<InventoryExitsCubit>();

    return BlocListener<InventoryExitsCubit, InventoryExitsState>(
      listener: (context, state) {
        if (state.errorMessage != null && !state.isLoading) {
          AppSnackbar.show(
            context,
            message: state.errorMessage!,
            type: SnackbarType.error,
          );
        }
        if (_pendingTargetExitId != null && state.exits.isNotEmpty) {
          _resolveTargetExit(state.exits, isDesktopOrTablet);
        }
      },
      child: AdminLayout(
        title: 'Salidas de Inventario',
        onSettingsSelected: (val) {
          if (val != 'pdf') return;
          final state = cubit.state;
          if (state.exits.isNotEmpty) {
            final startDate = state.startDate;
            final endDate = state.endDate;
            final selectedRange =
                (startDate != null && endDate != null)
                    ? DateTimeRange(start: startDate, end: endDate)
                    : null;
            InventoryExitsPdfGenerator.shareReport(
              exits: state.exits,
              dateRange: selectedRange,
            );
          }
        },
        actions: const [],
        floatingActionButton:
            !isDesktopOrTablet
                ? FloatingActionButton.extended(
                  onPressed: _onNewExit,
                  icon: Icon(
                    _hasDraft
                        ? Icons.edit_note_rounded
                        : Icons.remove_circle_outline_rounded,
                  ),
                  label: Text(
                    _hasDraft ? 'Borrador' : 'Nueva Salida',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor:
                      _hasDraft ? const Color(0xFFF59E0B) : AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                color: AppColors.danger,
                onRefresh: () => cubit.loadExits(isRefresh: true),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── 0. CABECERA EJECUTIVA STRIPE / LINEAR ──
                    SliverToBoxAdapter(
                      child: AdminPageHeader(
                        title: 'Salidas de Inventario',
                        subtitle: 'Gestiona las salidas de inventario',
                        isDesktop: isDesktopOrTablet,
                        actions: [
                          AdminHeaderButton.primary(
                            label:
                                _hasDraft
                                    ? 'Continuar Borrador'
                                    : 'Nueva Salida',
                            icon:
                                _hasDraft
                                    ? Icons.edit_note_rounded
                                    : Icons.remove_circle_outline_rounded,
                            tooltip:
                                _hasDraft
                                    ? 'Continuar salida (Atajo: N)'
                                    : 'Nueva salida (Atajo: N)',
                            onPressed:
                                () => context.go('/inventory-exits/form'),
                          ),
                        ],
                      ),
                    ),

                    // ── 1. Aviso de Borrador ──────────────────────────────
                    if (_hasDraft)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.warning,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Tienes un borrador de salida en progreso.',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              FilledButton.tonal(
                                onPressed: () {
                                  context.go('/inventory-exits/form');
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

                    // ── 2. Bento KPI Ribbon Aislado con BlocSelector (O(1)) ──
                    BlocSelector<
                      InventoryExitsCubit,
                      InventoryExitsState,
                      ({
                        int count,
                        int totalCount,
                        double totalCost,
                        int totalUnits,
                        String warehouseName,
                      })
                    >(
                      selector:
                          (s) => (
                            count: s.exits.length,
                            totalCount: s.totalRecords,
                            totalCost: s.totalCost,
                            totalUnits: s.totalUnits,
                            warehouseName: s.warehouseFilter,
                          ),
                      builder: (context, data) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: InventoryExitsBentoKpiBar(
                              count: data.count,
                              totalCount: data.totalCount,
                              totalCost: data.totalCost,
                              totalUnits: data.totalUnits,
                              warehouseName: data.warehouseName,
                              isDesktop: isTablet,
                            ),
                          ),
                        );
                      },
                    ),

                    // ── 3. Toolbar Pro Unificado Aislado ──────────────────
                    BlocSelector<
                      InventoryExitsCubit,
                      InventoryExitsState,
                      ({
                        String warehouseFilter,
                        List<String> availableWarehouses,
                        DateTime? startDate,
                        DateTime? endDate,
                      })
                    >(
                      selector:
                          (s) => (
                            warehouseFilter: s.warehouseFilter,
                            availableWarehouses: s.availableWarehouses,
                            startDate: s.startDate,
                            endDate: s.endDate,
                          ),
                      builder: (context, filters) {
                        return SliverToBoxAdapter(
                          child: AdminProToolbar(
                            isDesktop: constraints.maxWidth >= 1024,
                            searchController: _searchCtrl,
                            searchFocusNode: _searchFocusNode,
                            searchHint: 'Buscar motivo o notas... [/]',
                            onSearchChanged: (v) {
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 300),
                                () {
                                  if (mounted) {
                                    cubit.updateSearch(v);
                                  }
                                },
                              );
                            },
                            onClearSearch: () {
                              _searchDebounce?.cancel();
                              _searchCtrl.clear();
                              cubit.updateSearch('');
                            },
                            filterGroups: [
                              AdminFilterGroup<String>(
                                title: 'Almacén',
                                icon: Icons.storefront_rounded,
                                selected: filters.warehouseFilter,
                                defaultValue: 'Todos',
                                onSelected: cubit.updateWarehouse,
                                options: [
                                  for (final w in filters.availableWarehouses)
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
                                dateRange:
                                    filters.startDate != null &&
                                            filters.endDate != null
                                        ? DateTimeRange(
                                          start: filters.startDate!,
                                          end: filters.endDate!,
                                        )
                                        : null,
                                onDateRangeSelected: (picked) {
                                  cubit.updateDateRange(
                                    picked.start,
                                    picked.end,
                                  );
                                },
                                onClear:
                                    () => cubit.updateDateRange(null, null),
                              ),
                            ],
                            activeFiltersCount:
                                (filters.startDate != null &&
                                        filters.endDate != null
                                    ? 1
                                    : 0) +
                                (filters.warehouseFilter != 'Todos' &&
                                        filters.warehouseFilter != 'TODOS'
                                    ? 1
                                    : 0),
                            onClearFilters: () => cubit.clearFilters(),
                            viewToggleConfig: AdminProViewToggleConfig(
                              isTableView: _isTableView,
                              onToggleTableView:
                                  (val) => setState(() => _isTableView = val),
                            ),
                            onRefresh: () => cubit.loadExits(isRefresh: true),
                          ),
                        );
                      },
                    ),

                    // ── 4. Contenido Principal (Zero-Shimmer SWR) ─────────
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver:
                          BlocBuilder<InventoryExitsCubit, InventoryExitsState>(
                            buildWhen:
                                (prev, curr) =>
                                    prev.exits != curr.exits ||
                                    prev.isLoading != curr.isLoading ||
                                    prev.currentPage != curr.currentPage,
                            builder: (context, state) {
                              return _buildListOrTableSliver(
                                context: context,
                                state: state,
                                cubit: cubit,
                                isTablet: isTablet,
                              );
                            },
                          ),
                    ),

                    // ── 5. Paginación Fluida Aislada ──────────────────────
                    BlocSelector<
                      InventoryExitsCubit,
                      InventoryExitsState,
                      ({
                        int currentPage,
                        int totalPages,
                        int totalRecords,
                        bool isLoading,
                        bool hasExits,
                      })
                    >(
                      selector:
                          (s) => (
                            currentPage: s.currentPage,
                            totalPages: s.totalPages,
                            totalRecords: s.totalRecords,
                            isLoading: s.isLoading,
                            hasExits: s.exits.isNotEmpty,
                          ),
                      builder: (context, pData) {
                        if (pData.isLoading || !pData.hasExits) {
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
                                currentPage: pData.currentPage,
                                totalPages: pData.totalPages,
                                onPageChanged: (page) => cubit.changePage(page),
                                totalItems: pData.totalRecords,
                                itemName: 'salidas',
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
    required InventoryExitsState state,
    required InventoryExitsCubit cubit,
    required bool isTablet,
  }) {
    // Zero-Shimmer Policy:
    // Solo muestra Shimmer si es carga en frío Y no hay salidas en memoria L1.
    // Si ya hay salidas en memoria, se muestran de inmediato en Frame 0.
    if (state.isLoading && state.exits.isEmpty) {
      if (_isTableView && isTablet) {
        return const SliverToBoxAdapter(child: AppTableShimmer());
      }
      return const SliverToBoxAdapter(child: KardexSkeleton());
    }

    if (state.exits.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          key: const ValueKey('empty_state'),
          icon: Icons.inventory_2_outlined,
          title: 'Sin Resultados',
          message:
              state.searchQuery.isEmpty &&
                      state.startDate == null &&
                      state.endDate == null
                  ? 'No hay salidas registradas'
                  : 'Sin resultados para los filtros aplicados',
        ),
      );
    }

    if (_isTableView && isTablet) {
      return SliverToBoxAdapter(
        child: InventoryExitsTableView(
          exits: state.exits,
          selectedExit: _selectedExit,
          onSelectExit: (e) => _openDesktopDetailSheet(e),
          onRefresh: () => cubit.loadExits(isRefresh: true),
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
          final exit = state.exits[i];
          return InventoryExitCard(
            exitData: exit,
            isSelected: _selectedExit?.id == exit.id,
            onTap: () => _openDesktopDetailSheet(exit),
          );
        }, childCount: state.exits.length),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, i) {
        final exit = state.exits[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InventoryExitCard(
            exitData: exit,
            isSelected: false,
            onTap: () => _showDetailBottomSheet(context, exit),
          ),
        );
      }, childCount: state.exits.length),
    );
  }
}
