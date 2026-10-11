import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/supplier_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/suppliers_table_view.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/supplier_form_modal.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/adaptive_side_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  Timer? _debounce;
  bool _isTableView = true; // Por defecto en Desktop: Tabla Pro 100%
  SupplierEntity? _selectedSupplier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  List<SupplierEntity> get _currentSuppliers {
    final state = context.read<SuppliersCubit>().state;
    if (state is SuppliersLoaded) return state.suppliers;
    if (state is SuppliersLoading) return state.currentSuppliers;
    if (state is SuppliersError) return state.currentSuppliers;
    return const [];
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<SuppliersCubit>().setSearchQuery(query);
    });
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

  KeyEventResult _handleKeyShortcuts(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo editable, aislar atajos
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

    // Atajo [N] -> Nuevo Proveedor
    if (key == LogicalKeyboardKey.keyN) {
      _openSupplierModal(context);
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar directorio
    if (key == LogicalKeyboardKey.keyR) {
      context.read<SuppliersCubit>().loadSuppliers(refresh: true);
      AppSnackbar.show(
        context,
        message: 'Actualizando directorio de proveedores...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    // Atajo [V] -> Alternar Vista (Tabla vs Cards)
    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    // Atajo [Esc] -> Limpiar búsqueda o desenfocar
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedSupplier != null) {
        setState(() => _selectedSupplier = null);
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        context.read<SuppliersCubit>().setSearchQuery('');
      }
      _searchFocusNode.unfocus();
      _screenFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    // Flechas arriba y abajo para navegar proveedores y Enter para abrir modal/detalles
    final suppliers = _currentSuppliers;
    if (suppliers.isNotEmpty) {
      final currentIndex =
          _selectedSupplier != null
              ? suppliers.indexWhere((s) => s.id == _selectedSupplier!.id)
              : -1;

      if (key == LogicalKeyboardKey.arrowDown) {
        final nextIndex = (currentIndex + 1).clamp(0, suppliers.length - 1);
        setState(() => _selectedSupplier = suppliers[nextIndex]);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, suppliers.length - 1);
        setState(() => _selectedSupplier = suppliers[prevIndex]);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        final supplier = _selectedSupplier ?? suppliers.first;
        _openSupplierModal(context, supplier);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _openSupplierModal(BuildContext context, [SupplierEntity? supplier]) {
    final cubit = context.read<SuppliersCubit>();
    AdaptiveSideSheet.show<void>(
      context: context,
      desktopWidth: 540.0,
      barrierLabel: 'Cerrar proveedor',
      builder:
          (ctx, isSlideOver) => BlocProvider.value(
            value: cubit,
            child: SupplierFormModal(
              supplierToEdit: supplier,
              isDialog: isSlideOver,
              onSaved: () {},
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 640;
    final isDesktop = width >= 1024;

    return Focus(
      focusNode: _screenFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyShortcuts,
      child: BlocListener<SuppliersCubit, SuppliersState>(
        listener: (context, state) {
          if (state is SuppliersError) {
            AppSnackbar.show(
              context,
              message: state.message,
              type: SnackbarType.error,
            );
            context.read<SuppliersCubit>().clearError();
          }
        },
        child: AdminLayout(
          title: 'Directorio de Proveedores',
          // En tablet/escritorio ocultamos el FAB; la acción vive en el Toolbar
          floatingActionButton:
              isWide
                  ? null
                  : FloatingActionButton(
                    onPressed: () => _openSupplierModal(context),
                    backgroundColor: AppColors.teal,
                    tooltip: 'Nuevo Proveedor',
                    child: const Icon(
                      Icons.add_business_rounded,
                      color: Colors.white,
                    ),
                  ),
          body: BlocBuilder<SuppliersCubit, SuppliersState>(
            builder: (context, state) {
              final isLoading =
                  state is SuppliersLoading || state is SuppliersInitial;

              List<SupplierEntity> suppliers = [];
              String searchQuery = '';
              int currentPage = 0;
              int totalPages = 1;
              int totalCount = 0;

              if (state is SuppliersLoaded) {
                suppliers = state.suppliers;
                searchQuery = state.searchQuery;
                currentPage = state.currentPage;
                totalPages = state.totalPages;
                totalCount = state.totalCount;
              } else if (state is SuppliersLoading) {
                suppliers = state.currentSuppliers;
                searchQuery = state.searchQuery;
                currentPage = state.currentPage;
                totalPages =
                    state.totalCount == 0
                        ? 1
                        : (state.totalCount / SuppliersCubit.pageSize).ceil();
                totalCount = state.totalCount;
              } else if (state is SuppliersError) {
                suppliers = state.currentSuppliers;
                searchQuery = state.searchQuery;
                currentPage = state.currentPage;
                totalPages =
                    state.totalCount == 0
                        ? 1
                        : (state.totalCount / SuppliersCubit.pageSize).ceil();
                totalCount = state.totalCount;
              }

              final activeCount = suppliers.where((s) => s.isActive).length;
              final withRucCount =
                  suppliers
                      .where((s) => s.taxId != null && s.taxId!.isNotEmpty)
                      .length;

              return RefreshIndicator(
                onRefresh:
                    () async => context.read<SuppliersCubit>().loadSuppliers(
                      refresh: true,
                    ),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // --- 1. BENTO METRIC RIBBON PARA PROVEEDORES ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isWide ? 24 : 16,
                          isWide ? 14 : 12,
                          isWide ? 24 : 16,
                          4,
                        ),
                        child: _SuppliersKpiBar(
                          totalCount:
                              totalCount > 0 ? totalCount : suppliers.length,
                          activeCount: activeCount,
                          withRucCount: withRucCount,
                          isDesktop: isWide,
                        ),
                      ),
                    ),

                    // --- 2. TOOLBAR UNIFICADO DE BÚSQUEDA Y ACCIONES ---
                    SliverToBoxAdapter(
                      child: AdminProToolbar(
                        searchController: _searchCtrl,
                        searchFocusNode: _searchFocusNode,
                        searchHint: 'Buscar por nombre, RUC o contacto...',
                        onSearchChanged: _onSearchChanged,
                        onClearSearch: () {
                          _searchCtrl.clear();
                          context.read<SuppliersCubit>().setSearchQuery('');
                        },
                        viewToggleConfig: AdminProViewToggleConfig(
                          isTableView: _isTableView,
                          onToggleTableView:
                              (val) => setState(() => _isTableView = val),
                        ),
                        onRefresh:
                            () => context.read<SuppliersCubit>().loadSuppliers(
                              refresh: true,
                            ),
                        refreshTooltip: 'Refrescar proveedores [R]',
                        primaryAction: AdminProToolbarAction(
                          label: 'Nuevo Proveedor',
                          icon: Icons.add_business_rounded,
                          onPressed: () => _openSupplierModal(context),
                          keyHint: 'N',
                        ),
                        isDesktop: isDesktop,
                      ),
                    ),

                    // --- 3. LISTADO / TABLA O GRILLA RESPONSIVA EN SLIVERS ---
                    ..._buildSupplierContentSlivers(
                      isLoading: isLoading,
                      suppliers: suppliers,
                      isWide: isWide,
                      searchQuery: searchQuery,
                    ),

                    // --- 4. PAGINACIÓN FLUIDA AL PIE DEL SCROLL ---
                    _buildPaginationSliver(
                      currentPage: currentPage,
                      totalPages: totalPages,
                      totalItems: totalCount,
                      isLoading: isLoading,
                      context: context,
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

  List<Widget> _buildSupplierContentSlivers({
    required bool isLoading,
    required List<SupplierEntity> suppliers,
    required bool isWide,
    required String searchQuery,
  }) {
    if (isLoading && suppliers.isEmpty) {
      return [_buildSkeletonsSliver(isWide)];
    }

    if (suppliers.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: AppEmptyState(
              icon: Icons.storefront_rounded,
              title:
                  searchQuery.isNotEmpty
                      ? 'No se encontraron resultados'
                      : 'No hay proveedores registrados',
              message:
                  searchQuery.isNotEmpty
                      ? 'Intenta con otro término o limpia el buscador.'
                      : 'Registra un nuevo proveedor para comenzar.',
              action:
                  searchQuery.isNotEmpty
                      ? OutlinedButton.icon(
                        onPressed: () {
                          _searchCtrl.clear();
                          context.read<SuppliersCubit>().setSearchQuery('');
                        },
                        icon: const Icon(Icons.clear_all_rounded),
                        label: const Text('Limpiar búsqueda'),
                      )
                      : ElevatedButton.icon(
                        onPressed: () => _openSupplierModal(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_business_rounded),
                        label: const Text('Nuevo Proveedor'),
                      ),
            ),
          ),
        ),
      ];
    }

    if (isWide && _isTableView) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: SuppliersTableView(
              suppliers: suppliers,
              selectedSupplier: _selectedSupplier,
              onEdit: (s) {
                setState(() => _selectedSupplier = s);
                _openSupplierModal(context, s);
              },
              onToggleStatus:
                  (s) => context.read<SuppliersCubit>().toggleSupplierStatus(s),
            ),
          ),
        ),
      ];
    }

    if (isWide) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 440,
              mainAxisExtent: 180,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final supplier = suppliers[index];
              return SupplierCard(
                supplier: supplier,
                isSelected: _selectedSupplier?.id == supplier.id,
                onEdit: () {
                  setState(() => _selectedSupplier = supplier);
                  _openSupplierModal(context, supplier);
                },
                onToggleStatus:
                    () => context.read<SuppliersCubit>().toggleSupplierStatus(
                      supplier,
                    ),
              );
            }, childCount: suppliers.length),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final supplier = suppliers[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SupplierCard(
                supplier: supplier,
                isSelected: _selectedSupplier?.id == supplier.id,
                onEdit: () {
                  setState(() => _selectedSupplier = supplier);
                  _openSupplierModal(context, supplier);
                },
                onToggleStatus:
                    () => context.read<SuppliersCubit>().toggleSupplierStatus(
                      supplier,
                    ),
              ),
            );
          }, childCount: suppliers.length),
        ),
      ),
    ];
  }

  Widget _buildPaginationSliver({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required bool isLoading,
    required BuildContext context,
  }) {
    if (totalPages <= 1 || isLoading || totalItems == 0) {
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
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: (page) {
              context.read<SuppliersCubit>().setPage(page);
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            totalItems: totalItems,
            itemName: 'proveedores',
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonsSliver(bool isDesktop) {
    if (isDesktop && _isTableView) {
      return const SliverPadding(
        padding: EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(child: AppTableShimmer()),
      );
    }
    if (isDesktop) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 440,
            mainAxisExtent: 180,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, _) => const AppShimmer(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 16,
            ),
            childCount: 6,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, _) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AppShimmer(
              width: double.infinity,
              height: 160,
              borderRadius: 16,
            ),
          ),
          childCount: 5,
        ),
      ),
    );
  }
}

class _SuppliersKpiBar extends StatelessWidget {
  final int totalCount;
  final int activeCount;
  final int withRucCount;
  final bool isDesktop;

  const _SuppliersKpiBar({
    required this.totalCount,
    required this.activeCount,
    required this.withRucCount,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final activePct =
        totalCount > 0
            ? ((activeCount / totalCount) * 100).toStringAsFixed(0)
            : '100';

    return AdminKpiMetricsBar(
      isDesktop: isDesktop,
      padding: EdgeInsets.zero,
      items: [
        AdminKpiItem(
          title: 'Total Proveedores',
          value: '$totalCount',
          subtitle: 'Empresas registradas',
          icon: Icons.storefront_rounded,
          accentColor: AppColors.primary,
          gradientColors: const [Colors.white, Color(0xFFF8FAFC)],
          iconGradient: const [Color(0xFF334155), Color(0xFF1E293B)],
          borderColor: const Color(0xFFE2E8F0),
          glowColor: const Color(0x1F0F172A),
        ),
        AdminKpiItem(
          title: 'Proveedores Activos',
          value: '$activeCount',
          subtitle: '$activePct% habilitados',
          icon: Icons.check_circle_outline_rounded,
          accentColor: AppColors.successDark,
          gradientColors: const [Colors.white, Color(0xFFECFDF5)],
          iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
          borderColor: const Color(0xFFA7F3D0),
          glowColor: const Color(0x2E10B981),
        ),
        AdminKpiItem(
          title: 'Facturación / RUC',
          value: '$withRucCount',
          subtitle: 'Identificaciones cargadas',
          icon: Icons.receipt_long_rounded,
          accentColor: AppColors.tealDark,
          gradientColors: const [Colors.white, Color(0xFFF0FDFA)],
          iconGradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
          borderColor: const Color(0xFF99F6E4),
          glowColor: const Color(0x2E0D9488),
        ),
      ],
    );
  }
}
