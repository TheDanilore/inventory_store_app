import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_state.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_skeleton.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_kpi_strip.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_ledger_table.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_movement_inspector_drawer.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

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
      context.read<KardexCubit>().loadMovements(
        productId: widget.initialProductId,
        variantId: widget.initialVariantId,
        variantName: widget.initialVariantName,
        batchId: widget.initialBatchId,
        batchNumber: widget.initialBatchNumber,
        searchText: widget.initialProductName ?? '',
      );
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
    context.go('/admin/inventory-exits/form');
  }

  void _openEntryScreen(BuildContext context) {
    context.go('/admin/inventory-entries/form');
  }

  void _onSelectMovement(KardexMovementEntity item, bool isDesktop) {
    HapticFeedback.selectionClick();
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

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange:
          startDate != null && endDate != null
              ? DateTimeRange(start: startDate, end: endDate)
              : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
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

              // Si el input de búsqueda ya tiene foco, dejamos escribir normalmente
              if (_searchFocusNode.hasFocus) {
                return KeyEventResult.ignored;
              }

              // Atajo "/" -> Enfocar búsqueda
              if (event.logicalKey == LogicalKeyboardKey.slash) {
                _searchFocusNode.requestFocus();
                return KeyEventResult.handled;
              }

              // Atajo "E" -> Nuevo Ingreso
              if (event.logicalKey == LogicalKeyboardKey.keyE) {
                _openEntryScreen(context);
                return KeyEventResult.handled;
              }

              // Atajo "S" -> Nueva Salida
              if (event.logicalKey == LogicalKeyboardKey.keyS) {
                _openExitScreen(context);
                return KeyEventResult.handled;
              }

              // Atajo "P" -> Exportar PDF
              if (event.logicalKey == LogicalKeyboardKey.keyP) {
                context.read<KardexCubit>().exportToPdf();
                return KeyEventResult.handled;
              }

              // Atajos 1-5 -> Filtros de tipo
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
              title: 'Kardex',
              showBackButton: true,
              body: Column(
                children: [
                  // ── Barra de Control Superior (Desktop Toolbar) ──
                  if (isDesktop || isTablet)
                    _buildDesktopCommandBar(context, isDesktop),

                  // ── Contenido Principal Scrollable ──
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh:
                          () async => context
                              .read<KardexCubit>()
                              .loadMovements(page: 0),
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Móvil: Header Sticky de Búsqueda y Chips
                          if (!isDesktop && !isTablet)
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _MobileKardexHeaderDelegate(
                                child: _buildMobileControlHeader(context),
                              ),
                            ),

                          // Indicador de Búsqueda no destructivo
                          SliverToBoxAdapter(
                            child: BlocBuilder<KardexCubit, KardexState>(
                              builder: (context, state) {
                                if (state is KardexLoaded &&
                                    state.isSearching) {
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
                            child: BlocBuilder<KardexCubit, KardexState>(
                              builder: (context, state) {
                                if (state is KardexLoaded &&
                                    (state.productId != null ||
                                        state.variantId != null ||
                                        state.batchId != null)) {
                                  return _buildActiveFilterBanner(
                                    context,
                                    state,
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),

                          // Franja de KPIs en Vivo
                          SliverToBoxAdapter(
                            child: BlocBuilder<KardexCubit, KardexState>(
                              builder: (context, state) {
                                if (state is KardexLoaded &&
                                    state.movements.isNotEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      8,
                                    ),
                                    child: KardexKpiStrip(
                                      movements: state.movements,
                                      totalCount: state.totalCount,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),

                          // Master-Detail / Listado Principal
                          SliverToBoxAdapter(
                            child: BlocBuilder<KardexCubit, KardexState>(
                              builder: (context, state) {
                                final isError = state is KardexError;
                                final isLoading =
                                    state is KardexInitial ||
                                    state is KardexLoading;
                                final loadedState =
                                    state is KardexLoaded ? state : null;
                                final movements = loadedState?.movements ?? [];

                                if (isError) {
                                  return Padding(
                                    padding: const EdgeInsets.all(40.0),
                                    child: Center(
                                      child: Text(
                                        'Error al cargar el kárdex',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                } else if ((isLoading ||
                                        (loadedState?.isSearching ?? false)) &&
                                    movements.isEmpty) {
                                  return const KardexSkeleton();
                                } else if (movements.isEmpty) {
                                  return const AppEmptyState(
                                    icon: Icons.receipt_long_rounded,
                                    title: 'Sin movimientos encontrados',
                                    message:
                                        'No se registran movimientos con los filtros y fechas seleccionadas.',
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    24,
                                  ),
                                  child: _buildContentLayout(
                                    context,
                                    movements: movements,
                                    isDesktop: isDesktop,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Barra Inferior de Paginación ──
                  BlocBuilder<KardexCubit, KardexState>(
                    builder: (context, state) {
                      final loadedState = state is KardexLoaded ? state : null;
                      final totalPages = loadedState?.totalPages ?? 1;
                      final currentPage = loadedState?.currentPage ?? 0;
                      final isLoading =
                          state is KardexInitial || state is KardexLoading;
                      final isError = state is KardexError;

                      if (totalPages <= 1 || isLoading || isError) {
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
                            currentPage: currentPage,
                            totalPages: totalPages,
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
                      ? _buildMobileFloatingPill(context)
                      : null,
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // WIDGETS DE LAYOUT & COMPONENTES CAMALEÓNICOS
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopCommandBar(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Buscador compacto estilo Linear
              Expanded(
                flex: 3,
                child: BlocBuilder<KardexCubit, KardexState>(
                  builder: (context, state) {
                    final isSearching =
                        state is KardexLoaded && state.isSearching;
                    return _SearchInput(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      hint: 'Buscar producto, variante o SKU...',
                      isLoading: isSearching,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmitted,
                      onClear: () {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _searchCtrl.clear();
                        context.read<KardexCubit>().clearProductFilter();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),

              // Presets de Fecha Dropdown / Popover
              _buildDatePresetSelector(context),
              const SizedBox(width: 8),

              // Toggle de Vista (Cards vs Tabla Ledger)
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ViewToggleButton(
                      icon: Icons.view_agenda_outlined,
                      tooltip: 'Vista Línea de Tiempo',
                      isSelected: !_isLedgerView,
                      onTap: () => setState(() => _isLedgerView = false),
                    ),
                    _ViewToggleButton(
                      icon: Icons.table_chart_outlined,
                      tooltip: 'Vista Libro Mayor (Ledger)',
                      isSelected: _isLedgerView,
                      onTap: () => setState(() => _isLedgerView = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Botón Exportar PDF
              BlocBuilder<KardexCubit, KardexState>(
                builder: (context, state) {
                  final isExporting =
                      state is KardexLoaded && state.isExporting;
                  return Tooltip(
                    message: 'Exportar Kárdex en PDF (Ctrl+P)',
                    child: OutlinedButton.icon(
                      onPressed:
                          isExporting
                              ? null
                              : () =>
                                  context.read<KardexCubit>().exportToPdf(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon:
                          isExporting
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                              : const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 16,
                                color: AppColors.primary,
                              ),
                      label: Text(
                        isDesktop ? 'Exportar' : '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Botón Ingreso
              ElevatedButton.icon(
                onPressed: () => _openEntryScreen(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                  foregroundColor: Colors.green.shade700,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.green.shade200),
                  ),
                ),
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ingreso',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'E',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Botón Salida
              ElevatedButton.icon(
                onPressed: () => _openExitScreen(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                ),
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Salida',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'S',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Chips de Filtro por Tipo de Operación
          Row(
            children: [
              const Text(
                'Filtrar tipo:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              BlocBuilder<KardexCubit, KardexState>(
                builder: (context, state) {
                  final typeFilter =
                      state is KardexLoaded ? state.typeFilter : 'ALL';
                  return Wrap(
                    spacing: 6,
                    children: [
                      _FilterPill(
                        label: 'Todos',
                        shortcut: '1',
                        isSelected: typeFilter == 'ALL',
                        onTap:
                            () => context
                                .read<KardexCubit>()
                                .setTypeFilter('ALL'),
                      ),
                      _FilterPill(
                        label: 'Ingresos',
                        shortcut: '2',
                        isSelected: typeFilter == 'ENTRY',
                        onTap:
                            () => context
                                .read<KardexCubit>()
                                .setTypeFilter('ENTRY'),
                      ),
                      _FilterPill(
                        label: 'Salidas',
                        shortcut: '3',
                        isSelected: typeFilter == 'EXIT',
                        onTap:
                            () => context
                                .read<KardexCubit>()
                                .setTypeFilter('EXIT'),
                      ),
                      _FilterPill(
                        label: 'Ventas',
                        shortcut: '4',
                        isSelected: typeFilter == 'SALE',
                        onTap:
                            () => context
                                .read<KardexCubit>()
                                .setTypeFilter('SALE'),
                      ),
                      _FilterPill(
                        label: 'Devoluciones',
                        shortcut: '5',
                        isSelected: typeFilter == 'RETURN',
                        onTap:
                            () => context
                                .read<KardexCubit>()
                                .setTypeFilter('RETURN'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileControlHeader(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: BlocBuilder<KardexCubit, KardexState>(
                  builder: (context, state) {
                    final isSearching =
                        state is KardexLoaded && state.isSearching;
                    return _SearchInput(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      hint: 'Buscar en kárdex...',
                      isLoading: isSearching,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmitted,
                      onClear: () {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _searchCtrl.clear();
                        context.read<KardexCubit>().clearProductFilter();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Selector de Fecha
              BlocBuilder<KardexCubit, KardexState>(
                builder: (context, state) {
                  final startDate =
                      state is KardexLoaded ? state.startDate : null;
                  final endDate = state is KardexLoaded ? state.endDate : null;
                  return DateFilterCalendar(
                    dateRange:
                        startDate != null && endDate != null
                            ? DateTimeRange(start: startDate, end: endDate)
                            : null,
                    onDateRangeSelected: (picked) {
                      context.read<KardexCubit>().setDateRange(
                        picked.start,
                        picked.end,
                      );
                    },
                    onClear: () {
                      context.read<KardexCubit>().setDateRange(null, null);
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: BlocBuilder<KardexCubit, KardexState>(
              builder: (context, state) {
                final typeFilter =
                    state is KardexLoaded ? state.typeFilter : 'ALL';
                return Row(
                  children: [
                    _FilterPill(
                      label: 'Todos',
                      isSelected: typeFilter == 'ALL',
                      onTap:
                          () =>
                              context.read<KardexCubit>().setTypeFilter('ALL'),
                    ),
                    const SizedBox(width: 6),
                    _FilterPill(
                      label: 'Ingresos',
                      isSelected: typeFilter == 'ENTRY',
                      onTap:
                          () => context
                              .read<KardexCubit>()
                              .setTypeFilter('ENTRY'),
                    ),
                    const SizedBox(width: 6),
                    _FilterPill(
                      label: 'Salidas',
                      isSelected: typeFilter == 'EXIT',
                      onTap:
                          () =>
                              context.read<KardexCubit>().setTypeFilter('EXIT'),
                    ),
                    const SizedBox(width: 6),
                    _FilterPill(
                      label: 'Ventas',
                      isSelected: typeFilter == 'SALE',
                      onTap:
                          () =>
                              context.read<KardexCubit>().setTypeFilter('SALE'),
                    ),
                    const SizedBox(width: 6),
                    _FilterPill(
                      label: 'Devoluciones',
                      isSelected: typeFilter == 'RETURN',
                      onTap:
                          () => context
                              .read<KardexCubit>()
                              .setTypeFilter('RETURN'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePresetSelector(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Filtrar por período',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: AppColors.surface,
        onSelected: _applyDatePreset,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.date_range_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _getDatePresetLabel(_activeDatePreset),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
        itemBuilder:
            (context) => [
              const PopupMenuItem(
                value: 'ALL',
                child: Text('Cualquier fecha'),
              ),
              const PopupMenuItem(value: 'TODAY', child: Text('Hoy')),
              const PopupMenuItem(
                value: 'WEEK',
                child: Text('Últimos 7 días'),
              ),
              const PopupMenuItem(
                value: 'MONTH',
                child: Text('Este mes actual'),
              ),
              const PopupMenuItem(
                value: '30DAYS',
                child: Text('Últimos 30 días'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'CUSTOM',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text('Rango personalizado...'),
                  ],
                ),
              ),
            ],
      ),
    );
  }

  String _getDatePresetLabel(String preset) {
    switch (preset) {
      case 'TODAY':
        return 'Hoy';
      case 'WEEK':
        return 'Últimos 7 días';
      case 'MONTH':
        return 'Este mes';
      case '30DAYS':
        return 'Últimos 30 días';
      case 'CUSTOM':
        return 'Personalizado';
      case 'ALL':
      default:
        return 'Todas las fechas';
    }
  }

  Widget _buildActiveFilterBanner(BuildContext context, KardexLoaded state) {
    final prodLabel =
        state.searchText.isNotEmpty
            ? state.searchText
            : (state.productId ?? 'Producto');
    final hasVariant = state.variantId != null;
    final hasBatch = state.batchId != null || state.batchNumber != null;
    final variantLabel =
        state.variantName != null && state.variantName!.isNotEmpty
            ? state.variantName!
            : (hasVariant
                ? 'ID: ${state.variantId!.length > 8 ? state.variantId!.substring(0, 8) : state.variantId}...'
                : '');
    final batchLabel =
        state.batchNumber != null && state.batchNumber!.isNotEmpty
            ? state.batchNumber!
            : (hasBatch
                ? 'ID: ${state.batchId!.length > 8 ? state.batchId!.substring(0, 8) : state.batchId}...'
                : '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.filter_alt_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Filtrando: ',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: prodLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hasVariant) ...[
                      const TextSpan(text: ' · Variante: '),
                      TextSpan(
                        text: variantLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                    if (hasBatch) ...[
                      const TextSpan(text: ' · Lote: '),
                      TextSpan(
                        text: batchLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasBatch) ...[
              InkWell(
                onTap: () => context.read<KardexCubit>().clearBatchFilter(),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Text(
                    'Ver todos los lotes',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.purple.shade700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (hasVariant) ...[
              InkWell(
                onTap: () => context.read<KardexCubit>().clearVariantFilter(),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Text(
                    'Ver variantes',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            InkWell(
              onTap: () {
                _searchCtrl.clear();
                context.read<KardexCubit>().clearProductFilter();
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Limpiar',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentLayout(
    BuildContext context, {
    required List<KardexMovementEntity> movements,
    required bool isDesktop,
  }) {
    // Si estamos en Desktop con un movimiento seleccionado, aplicamos Split View (Master-Detail)
    if (isDesktop && _selectedMovement != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildItemsListOrTable(
              context,
              movements: movements,
              isDesktop: isDesktop,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 380,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow(opacity: 0.04),
            ),
            child: KardexMovementInspectorDrawer(
              item: _selectedMovement!,
              onClose: () => setState(() => _selectedMovement = null),
            ),
          ),
        ],
      );
    }

    return _buildItemsListOrTable(
      context,
      movements: movements,
      isDesktop: isDesktop,
    );
  }

  Widget _buildItemsListOrTable(
    BuildContext context, {
    required List<KardexMovementEntity> movements,
    required bool isDesktop,
  }) {
    if (_isLedgerView) {
      return KardexLedgerTable(
        items: movements,
        selectedItem: _selectedMovement,
        onSelect: (item) => _onSelectMovement(item, isDesktop),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
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
    );
  }

  Widget _buildMobileFloatingPill(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _openEntryScreen(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Ingreso',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openExitScreen(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 16,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Salida',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
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

class _MobileKardexHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _MobileKardexHeaderDelegate({required this.child});

  @override
  double get minExtent => 98.0;
  @override
  double get maxExtent => 98.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_MobileKardexHeaderDelegate oldDelegate) => true;
}

class _SearchInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;

  const _SearchInput({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.isLoading,
    required this.onChanged,
    this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  if (value.text.isNotEmpty && !isLoading) {
                    return IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      color: AppColors.textSecondary,
                      onPressed: onClear,
                      visualDensity: VisualDensity.compact,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final String? shortcut;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.shortcut,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            if (shortcut != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  shortcut!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.primary : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow:
                isSelected ? AppColors.cardShadow(opacity: 0.04) : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
