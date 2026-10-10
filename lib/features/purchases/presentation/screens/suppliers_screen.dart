import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
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
    final isDesktop = width >= 800;
    final isDesktopOrTablet = MediaQuery.sizeOf(context).width >= 800;

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
          showBackButton: true,
          actions:
              isDesktopOrTablet
                  ? null
                  : [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Actualizar proveedores',
                      onPressed: () {
                        context.read<SuppliersCubit>().loadSuppliers(
                          page: 0,
                          refresh: true,
                        );
                      },
                    ),
                  ],
          // En escritorio ocultamos el FAB; la acción vive en el Toolbar
          floatingActionButton:
              isDesktop
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
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _SuppliersKpiBar(
                          totalCount:
                              totalCount > 0 ? totalCount : suppliers.length,
                          activeCount: activeCount,
                          withRucCount: withRucCount,
                          isDesktop: isDesktop,
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

                    // --- 2.5 ENCABEZADO DE NAVEGACIÓN Y CONTADOR ---
                    if (!isLoading && suppliers.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: Row(
                            children: [
                              Text(
                                '${suppliers.length} ${suppliers.length == 1 ? "proveedor" : "proveedores"} en esta página',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isDesktop) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: const Text(
                                    '↑ ↓ navegar',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  'Pág. ${currentPage + 1} / $totalPages',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // --- 3. LISTADO / TABLA O GRILLA RESPONSIVA EN SLIVERS ---
                    ..._buildSupplierContentSlivers(
                      isLoading: isLoading,
                      suppliers: suppliers,
                      isDesktop: isDesktop,
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
    required bool isDesktop,
    required String searchQuery,
  }) {
    if (isLoading && suppliers.isEmpty) {
      return [_buildSkeletonsSliver(isDesktop)];
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

    if (isDesktop && _isTableView) {
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

    if (isDesktop) {
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

    final cards = [
      _BentoSupplierKpiCard(
        title: 'Total Proveedores',
        value: '$totalCount',
        subtitle: 'Empresas registradas',
        icon: Icons.storefront_rounded,
        iconBgColor: AppColors.primaryLight,
        iconColor: AppColors.primary,
      ),
      _BentoSupplierKpiCard(
        title: 'Proveedores Activos',
        value: '$activeCount',
        subtitle: '$activePct% habilitados',
        icon: Icons.check_circle_outline_rounded,
        iconBgColor: AppColors.successLight,
        iconColor: AppColors.successDark,
      ),
      _BentoSupplierKpiCard(
        title: 'Facturación / RUC',
        value: '$withRucCount',
        subtitle: 'Identificaciones cargadas',
        icon: Icons.receipt_long_rounded,
        iconBgColor: AppColors.tealLight,
        iconColor: AppColors.tealDark,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 12),
          Expanded(child: cards[1]),
          const SizedBox(width: 12),
          Expanded(child: cards[2]),
        ],
      );
    }

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) => SizedBox(width: 220, child: cards[index]),
      ),
    );
  }
}

class _BentoSupplierKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;

  const _BentoSupplierKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
