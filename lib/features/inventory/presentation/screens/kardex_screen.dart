import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_date_range_picker_modal.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_active_filters_bar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_desktop_command_bar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_kpi_strip.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_ledger_table.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_mobile_floating_pill.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_mobile_header.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_movement_inspector_drawer.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_skeleton.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

/// Pantalla Principal del Kárdex de Inventario (ERP).
///
/// Arquitectura de alto rendimiento:
/// - Virtualización nativa O(1) con `SliverList.builder` eliminando `shrinkWrap: true`.
/// - Aislamiento de rebuilds con `BlocSelector` en barras de herramientas y filtros.
/// - Zero-Shimmer al regresar a la vista preservando movimientos en memoria.
/// - Desacoplamiento modular en componentes especializados bajo Clean Architecture.
class KardexScreen extends StatefulWidget {
  final String? initialProductId;
  final String? initialProductName;
  final String? initialVariantId;
  final String? initialVariantName;
  final String? initialBatchId;
  final String? initialBatchNumber;

  const KardexScreen({
    super.key,
    this.initialProductId,
    this.initialProductName,
    this.initialVariantId,
    this.initialVariantName,
    this.initialBatchId,
    this.initialBatchNumber,
  });

  @override
  State<KardexScreen> createState() => _KardexScreenState();
}

class _KardexScreenState extends State<KardexScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  // Estado UI local: Inspector, Vista Tabular vs Cards, Preset de fecha
  KardexMovementEntity? _selectedMovement;
  bool _isLedgerView = false;
  String _activeDatePreset = 'ALL';

  @override
  void initState() {
    super.initState();
    if (widget.initialProductName != null &&
        widget.initialProductName!.isNotEmpty) {
      _searchCtrl.text = widget.initialProductName!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<KardexCubit>();
      final isInitial = cubit.state is KardexInitial;
      final hasSpecificParams =
          (widget.initialProductId != null &&
              widget.initialProductId!.isNotEmpty) ||
          (widget.initialVariantId != null &&
              widget.initialVariantId!.isNotEmpty) ||
          (widget.initialBatchId != null && widget.initialBatchId!.isNotEmpty);

      // Zero-Shimmer: Solo cargar si es estado inicial o si los parámetros son distintos
      if (isInitial || hasSpecificParams) {
        cubit.loadMovements(
          productId: widget.initialProductId,
          variantId: widget.initialVariantId,
          variantName: widget.initialVariantName,
          batchId: widget.initialBatchId,
          batchNumber: widget.initialBatchNumber,
          searchText: widget.initialProductName ?? '',
        );
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<KardexCubit>().setSearchText(value);
    });
  }

  void _onSearchSubmitted(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    context.read<KardexCubit>().setSearchText(value);
  }

  void _openExitScreen(BuildContext context) {
    context.go('/inventory-exits/form');
  }

  void _openEntryScreen(BuildContext context) {
    context.go('/inventory-entries/form');
  }

  void _onSelectMovement(KardexMovementEntity item, bool isDesktop) {
    AppFeedbackService.selectionClick();
    if (isDesktop) {
      setState(() {
        if (_selectedMovement?.id == item.id) {
          _selectedMovement = null;
        } else {
          _selectedMovement = item;
        }
      });
    } else {
      KardexMovementInspectorDrawer.showAsBottomSheet(context, item);
    }
  }

  void _applyDatePreset(String preset) {
    setState(() => _activeDatePreset = preset);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (preset == 'ALL') {
      context.read<KardexCubit>().setDateRange(null, null);
    } else if (preset == 'TODAY') {
      context.read<KardexCubit>().setDateRange(
        today,
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    } else if (preset == 'WEEK') {
      final start = today.subtract(const Duration(days: 7));
      context.read<KardexCubit>().setDateRange(start, now);
    } else if (preset == 'MONTH') {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      context.read<KardexCubit>().setDateRange(start, end);
    } else if (preset == '30DAYS') {
      final start = today.subtract(const Duration(days: 30));
      context.read<KardexCubit>().setDateRange(start, now);
    } else if (preset == 'CUSTOM') {
      _pickCustomDateRange();
    }
  }

  Future<void> _pickCustomDateRange() async {
    final state = context.read<KardexCubit>().state;
    final startDate = state is KardexLoaded ? state.startDate : null;
    final endDate = state is KardexLoaded ? state.endDate : null;

    final picked = await AppDateRangePickerModal.show(
      context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialStartDate: startDate,
      initialEndDate: endDate,
    );

    if (picked != null) {
      setState(() => _activeDatePreset = 'CUSTOM');
      if (mounted) {
        context.read<KardexCubit>().setDateRange(picked.start, picked.end);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<KardexCubit, KardexState>(
      listener: (context, state) {
        if (state is KardexError) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.error,
          );
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final isTablet = constraints.maxWidth >= 700 && !isDesktop;

          return Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;

              final isAlt = HardwareKeyboard.instance.isAltPressed;
              final isControl = HardwareKeyboard.instance.isControlPressed;
              final isMeta = HardwareKeyboard.instance.isMetaPressed;
              final isModifier = isAlt || isControl || isMeta;

              // ESC -> Cerrar inspector o limpiar búsqueda
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                if (_selectedMovement != null) {
                  setState(() => _selectedMovement = null);
                  return KeyEventResult.handled;
                }
                if (_searchCtrl.text.isNotEmpty) {
                  _searchCtrl.clear();
                  context.read<KardexCubit>().clearProductFilter();
                  return KeyEventResult.handled;
                }
                _searchFocusNode.unfocus();
                return KeyEventResult.handled;
              }

              // ⌘K / Ctrl+K / Alt+K o "/" -> Enfocar búsqueda
              if ((isModifier && event.logicalKey == LogicalKeyboardKey.keyK) ||
                  (!isModifier &&
                      event.logicalKey == LogicalKeyboardKey.slash &&
                      !_searchFocusNode.hasFocus)) {
                _searchFocusNode.requestFocus();
                _searchCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _searchCtrl.text.length,
                );
                return KeyEventResult.handled;
              }

              if (_searchFocusNode.hasFocus) {
                return KeyEventResult.ignored;
              }

              // ⌘E / Ctrl+E -> Nuevo Ingreso
              if (isModifier && event.logicalKey == LogicalKeyboardKey.keyE) {
                _openEntryScreen(context);
                return KeyEventResult.handled;
              }

              // ⌘S / Ctrl+S -> Nueva Salida
              if (isModifier && event.logicalKey == LogicalKeyboardKey.keyS) {
                _openExitScreen(context);
                return KeyEventResult.handled;
              }

              // ⌘P / Ctrl+P -> Exportar PDF
              if (isModifier && event.logicalKey == LogicalKeyboardKey.keyP) {
                context.read<KardexCubit>().exportToPdf();
                return KeyEventResult.handled;
              }

              // Atajos numéricos 1-5 para filtros de tipo
              if (event.logicalKey == LogicalKeyboardKey.digit1) {
                context.read<KardexCubit>().setTypeFilter('ALL');
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.digit2) {
                context.read<KardexCubit>().setTypeFilter('ENTRY');
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.digit3) {
                context.read<KardexCubit>().setTypeFilter('EXIT');
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.digit4) {
                context.read<KardexCubit>().setTypeFilter('SALE');
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.digit5) {
                context.read<KardexCubit>().setTypeFilter('RETURN');
                return KeyEventResult.handled;
              }

              return KeyEventResult.ignored;
            },
            child: AdminLayout(
              title: 'Kárdex de Inventario',
              breadcrumb: 'Inventario / Kárdex',
              body: Column(
                children: [
                  // ── Barra de Comandos Superior (Desktop/Tablet) ──
                  if (isDesktop || isTablet)
                    KardexDesktopCommandBar(
                      searchCtrl: _searchCtrl,
                      searchFocusNode: _searchFocusNode,
                      isDesktop: isDesktop,
                      isLedgerView: _isLedgerView,
                      activeDatePreset: _activeDatePreset,
                      onSearchChanged: _onSearchChanged,
                      onSearchSubmitted: _onSearchSubmitted,
                      onClearSearch: () {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _searchCtrl.clear();
                        context.read<KardexCubit>().clearProductFilter();
                      },
                      onToggleView:
                          (val) => setState(() => _isLedgerView = val),
                      onSelectDatePreset: _applyDatePreset,
                      onOpenEntry: () => _openEntryScreen(context),
                      onOpenExit: () => _openExitScreen(context),
                    ),

                  // ── Contenido Principal Scrollable con Master-Detail ──
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna Izquierda: Timeline / Ledger con Scroll Independiente
                        Expanded(
                          child: RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh:
                                () async => context
                                    .read<KardexCubit>()
                                    .loadMovements(page: 0, forceRefresh: true),
                            child: CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                // Móvil: Header Sticky de Búsqueda y Chips
                                if (!isDesktop && !isTablet)
                                  SliverPersistentHeader(
                                    pinned: true,
                                    delegate: KardexMobileHeaderDelegate(
                                      child: KardexMobileHeader(
                                        searchCtrl: _searchCtrl,
                                        searchFocusNode: _searchFocusNode,
                                        onSearchChanged: _onSearchChanged,
                                        onSearchSubmitted: _onSearchSubmitted,
                                        onClearSearch: () {
                                          if (_debounce?.isActive ?? false) {
                                            _debounce!.cancel();
                                          }
                                          _searchCtrl.clear();
                                          context
                                              .read<KardexCubit>()
                                              .clearProductFilter();
                                        },
                                      ),
                                    ),
                                  ),

                                // Indicador de Búsqueda no destructivo
                                SliverToBoxAdapter(
                                  child: BlocSelector<
                                    KardexCubit,
                                    KardexState,
                                    bool
                                  >(
                                    selector:
                                        (state) =>
                                            state is KardexLoaded &&
                                            state.isSearching,
                                    builder: (context, isSearching) {
                                      if (isSearching) {
                                        return const SizedBox(
                                          height: 2,
                                          child: LinearProgressIndicator(
                                            backgroundColor: Colors.transparent,
                                            color: AppColors.primary,
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),

                                // Banner de Filtro Activo (Producto / Variante / Lote)
                                SliverToBoxAdapter(
                                  child: KardexActiveFiltersBar(
                                    onClearProduct: () {
                                      _searchCtrl.clear();
                                      context
                                          .read<KardexCubit>()
                                          .clearProductFilter();
                                    },
                                  ),
                                ),

                                // Franja de KPIs en Vivo
                                SliverToBoxAdapter(
                                  child: BlocBuilder<KardexCubit, KardexState>(
                                    builder: (context, state) {
                                      final movements =
                                          (state is KardexLoaded)
                                              ? state.movements
                                              : state.previousMovements;
                                      if (movements.isNotEmpty) {
                                        final totalCount =
                                            state is KardexLoaded
                                                ? state.totalCount
                                                : movements.length;
                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            12,
                                            16,
                                            8,
                                          ),
                                          child: KardexKpiStrip(
                                            movements: movements,
                                            totalCount: totalCount,
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),

                                // Listado Principal con Virtualización Nativa
                                _buildMainSliverContent(
                                  context,
                                  isDesktop: isDesktop,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Columna Derecha Desktop: Inspector Viewport-Sticky
                        if (isDesktop && _selectedMovement != null)
                          Container(
                            width: 390,
                            margin: const EdgeInsets.fromLTRB(0, 10, 16, 16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                              boxShadow: AppColors.cardShadow(opacity: 0.05),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: KardexMovementInspectorDrawer(
                                  item: _selectedMovement!,
                                  onClose:
                                      () => setState(
                                        () => _selectedMovement = null,
                                      ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Barra de Paginación Fija Inferior (Desktop/Mobile) ──
                  BlocSelector<
                    KardexCubit,
                    KardexState,
                    ({int currentPage, int totalPages, int totalCount})
                  >(
                    selector: (state) {
                      if (state is KardexLoaded) {
                        return (
                          currentPage: state.currentPage,
                          totalPages: state.totalPages,
                          totalCount: state.totalCount,
                        );
                      }
                      return (currentPage: 0, totalPages: 1, totalCount: 0);
                    },
                    builder: (context, pageData) {
                      if (pageData.totalCount <= KardexCubit.pageSize) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: const Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: AdminPageBlocks(
                            currentPage: pageData.currentPage,
                            totalPages: pageData.totalPages,
                            onPageChanged:
                                (page) => context
                                    .read<KardexCubit>()
                                    .changePage(page),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // ── Floating Action Bar en Móvil (Apple HIG Thumb-Zone) ──
              floatingActionButton:
                  (!isDesktop && !isTablet)
                      ? KardexMobileFloatingPill(
                        onOpenEntry: () => _openEntryScreen(context),
                        onOpenExit: () => _openExitScreen(context),
                      )
                      : null,
            ),
          );
        },
      ),
    );
  }

  /// Construye el contenido del listado usando virtualización O(1) con SliverList
  /// o SliverToBoxAdapter en vista Ledger.
  Widget _buildMainSliverContent(
    BuildContext context, {
    required bool isDesktop,
  }) {
    return BlocBuilder<KardexCubit, KardexState>(
      builder: (context, state) {
        final isLoading = state is KardexInitial || state is KardexLoading;
        final loadedState = state is KardexLoaded ? state : null;
        final movements = loadedState?.movements ?? state.previousMovements;

        if (state is KardexError && movements.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.message,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed:
                          () => context.read<KardexCubit>().loadMovements(
                            forceRefresh: true,
                          ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if ((isLoading || (loadedState?.isSearching ?? false)) &&
            movements.isEmpty) {
          return const SliverToBoxAdapter(child: KardexSkeleton());
        } else if (movements.isEmpty) {
          return const SliverToBoxAdapter(
            child: AppEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'Sin movimientos encontrados',
              message:
                  'No se registran movimientos con los filtros y fechas seleccionadas.',
            ),
          );
        }

        // Vista Libro Mayor (Ledger Table) en Desktop
        if (_isLedgerView) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: KardexLedgerTable(
                items: movements,
                selectedItem: _selectedMovement,
                onSelect: (item) => _onSelectMovement(item, isDesktop),
              ),
            ),
          );
        }

        // Vista Línea de Tiempo (Cards) con virtualización nativa O(1)
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.builder(
            itemCount: movements.length,
            itemBuilder: (context, index) {
              final item = movements[index];
              final isSelected = _selectedMovement?.id == item.id;
              return KardexCard(
                item: item,
                isLast: index == movements.length - 1,
                isSelected: isSelected,
                onTap: () => _onSelectMovement(item, isDesktop),
              );
            },
          ),
        );
      },
    );
  }
}
