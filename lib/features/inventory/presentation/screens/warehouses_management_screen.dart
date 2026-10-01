import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/warehouses/warehouses_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/warehouses/warehouses_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouses/warehouse_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouses/warehouse_form_modal.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouses/warehouses_skeleton.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouses/warehouses_table_view.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

/// Pantalla de Gestión de Almacenes con Arquitectura Camaleónica Multi-dispositivo.
/// - Desktop (>= 1024px): Pro Table View con métricas KPI, toolbar integrada y atajos de teclado.
/// - Tablet (800px - 1024px): Grid responsivo de 2 columnas con panel compacto.
/// - Mobile (< 800px): Tarjetas iOS HIG, área táctil mínima de 48dp, BottomSheet modal y FAB.
class WarehousesManagementScreen extends StatefulWidget {
  const WarehousesManagementScreen({super.key});

  @override
  State<WarehousesManagementScreen> createState() =>
      _WarehousesManagementScreenState();
}

class _WarehousesManagementScreenState
    extends State<WarehousesManagementScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  Timer? _debounce;
  bool _isTableView = true; // Por defecto en Desktop: Tabla Pro ejecutiva

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset > 12 && _isFabExtended.value) {
      _isFabExtended.value = false;
    } else if (_scrollController.offset <= 12 && !_isFabExtended.value) {
      _isFabExtended.value = true;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _isFabExtended.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, WarehousesCubit cubit) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      cubit.updateSearch(query);
    });
  }

  // ── Regla Estricta de Aislamiento de Foco (Focus Shield) ───────────
  bool get _isInputFieldFocused {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    return primaryFocus.context?.widget is EditableText;
  }

  KeyEventResult _handleKeyShortcuts(
    FocusNode node,
    KeyEvent event,
    WarehousesCubit cubit,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo de texto, aislar atajos
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // [/] -> Enfocar buscador
    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // [N] -> Nuevo Almacén
    if (key == LogicalKeyboardKey.keyN) {
      _openWarehouseModal(context, cubit);
      return KeyEventResult.handled;
    }

    // [R] -> Recargar directorio de almacenes
    if (key == LogicalKeyboardKey.keyR) {
      cubit.loadWarehouses(isRefresh: true);
      AppSnackbar.show(
        context,
        message: 'Actualizando catálogo de almacenes...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    // [V] -> Alternar Vista (Tabla Pro vs Tarjetas/Grilla)
    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    // [Esc] -> Limpiar búsqueda o desenfocar
    if (key == LogicalKeyboardKey.escape) {
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        cubit.clearSearch();
      }
      _searchFocusNode.unfocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _openWarehouseModal(
    BuildContext context,
    WarehousesCubit cubit, [
    WarehouseEntity? warehouse,
  ]) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final modal = BlocProvider.value(
      value: cubit,
      child: WarehouseFormModal(
        warehouseToEdit: warehouse,
        isDialog: isDesktop,
        onSaved: () {
          cubit.loadWarehouses(isRefresh: true);
        },
      ),
    );

    if (isDesktop) {
      showDialog(
        context: context,
        builder:
            (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: modal,
              ),
            ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => modal,
      );
    }
  }

  Future<void> _confirmDeleteWarehouse(
    BuildContext context,
    WarehousesCubit cubit,
    WarehouseEntity warehouse,
  ) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'Eliminar Almacén',
      message:
          '¿Estás seguro de eliminar el almacén "${warehouse.name}"?\nSe verificará que no cuente con historial de stock, pedidos ni entradas vinculadas.',
      confirmText: 'Eliminar',
      confirmColor: AppColors.error,
    );
    if (confirm != true) return;
    if (!mounted) return;
    await cubit.deleteWarehouse(warehouse.id);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;

    return BlocProvider(
      create: (_) => sl<WarehousesCubit>()..initLoad(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<WarehousesCubit>();

          return Focus(
            autofocus: true,
            onKeyEvent: (node, event) => _handleKeyShortcuts(node, event, cubit),
            child: BlocConsumer<WarehousesCubit, WarehousesState>(
              listener: (context, state) {
                if (state.errorMessage != null &&
                    state.errorMessage!.isNotEmpty) {
                  AppSnackbar.show(
                    context,
                    message: state.errorMessage!,
                    type: SnackbarType.error,
                  );
                }
                if (state.successMessage != null &&
                    state.successMessage!.isNotEmpty) {
                  AppSnackbar.show(
                    context,
                    message: state.successMessage!,
                    type: SnackbarType.success,
                  );
                }
              },
              builder: (context, state) {
                final warehouses = state.warehouses;
                final activeCount = warehouses.where((w) => w.isActive).length;
                final inactiveCount =
                    warehouses.where((w) => !w.isActive).length;

                return AdminLayout(
                  title: 'Almacenes',
                  showBackButton: true,
                  floatingActionButton:
                      !isDesktop
                          ? _buildMobileFab(context, cubit)
                          : null,
                  bottomNavigationBar:
                      warehouses.isNotEmpty && state.totalPages > 1
                          ? Container(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
                                currentPage: state.currentPage,
                                totalPages: state.totalPages,
                                onPageChanged: (page) => cubit.changePage(page),
                              ),
                            ),
                          )
                          : null,
                  body: Column(
                    children: [
                      // ── 1. Bento Metric Ribbon para Almacenes ─────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _WarehousesKpiBar(
                          totalCount:
                              state.totalRecords > 0
                                  ? state.totalRecords
                                  : warehouses.length,
                          activeCount: activeCount,
                          inactiveCount: inactiveCount,
                          isDesktop: isDesktop,
                        ),
                      ),

                      // ── 2. Toolbar Unificado de Búsqueda y Acciones ──
                      _buildToolbar(
                        context,
                        cubit,
                        isDesktop,
                      ),

                      // ── 3. Contenido Principal (Tabla o Grilla) ───────
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            if (state.isLoading) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child:
                                    isDesktop && _isTableView
                                        ? const AppTableShimmer(
                                          rowCount: 5,
                                          minWidth: 840,
                                        )
                                        : const WarehousesSkeleton(itemCount: 4),
                              );
                            }

                            if (warehouses.isEmpty) {
                              return Center(
                                child: AppEmptyState(
                                  icon: Icons.warehouse_outlined,
                                  title:
                                      state.searchQuery.isNotEmpty
                                          ? 'No se encontraron almacenes'
                                          : 'No hay almacenes registrados',
                                  message:
                                      state.searchQuery.isNotEmpty
                                          ? 'No hay resultados que coincidan con "${state.searchQuery}". Intenta con otro término.'
                                          : 'Comienza agregando los puntos de venta o almacenes donde gestionas el inventario.',
                                  action:
                                      state.searchQuery.isNotEmpty
                                          ? OutlinedButton.icon(
                                            onPressed: () {
                                              _searchCtrl.clear();
                                              cubit.clearSearch();
                                            },
                                            icon: const Icon(
                                              Icons.clear_all_rounded,
                                            ),
                                            label: const Text('Limpiar búsqueda'),
                                          )
                                          : ElevatedButton.icon(
                                            onPressed:
                                                () => _openWarehouseModal(context, cubit),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.add_business_rounded,
                                              size: 18,
                                            ),
                                            label: const Text('Registrar Almacén'),
                                          ),
                                ),
                              );
                            }

                            return RefreshIndicator(
                              onRefresh:
                                  () async =>
                                      cubit.loadWarehouses(isRefresh: true),
                              color: AppColors.primary,
                              child: CustomScrollView(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      16,
                                    ),
                                    sliver:
                                        (isDesktop && _isTableView)
                                            ? SliverToBoxAdapter(
                                              child: WarehousesTableView(
                                                warehouses: warehouses,
                                                onEdit:
                                                    (wh) => _openWarehouseModal(
                                                      context,
                                                      cubit,
                                                      wh,
                                                    ),
                                                onDelete:
                                                    (wh) => _confirmDeleteWarehouse(
                                                      context,
                                                      cubit,
                                                      wh,
                                                    ),
                                                onToggleStatus: (wh, val) {
                                                  cubit.toggleWarehouseStatus(
                                                    wh,
                                                    val,
                                                  );
                                                },
                                              ),
                                            )
                                            : SliverGrid(
                                              gridDelegate:
                                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                                    maxCrossAxisExtent: 440,
                                                    mainAxisExtent: 178,
                                                    crossAxisSpacing: 14,
                                                    mainAxisSpacing: 14,
                                                  ),
                                              delegate: SliverChildBuilderDelegate((
                                                context,
                                                index,
                                              ) {
                                                final wh = warehouses[index];
                                                return WarehouseCard(
                                                  warehouse: wh,
                                                  onEdit:
                                                      () => _openWarehouseModal(
                                                        context,
                                                        cubit,
                                                        wh,
                                                      ),
                                                  onDelete:
                                                      () => _confirmDeleteWarehouse(
                                                        context,
                                                        cubit,
                                                        wh,
                                                      ),
                                                  onToggleStatus: (val) {
                                                    cubit.toggleWarehouseStatus(
                                                      wh,
                                                      val,
                                                    );
                                                  },
                                                );
                                              }, childCount: warehouses.length),
                                            ),
                                  ),
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 16),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ── TOOLBAR UNIFICADO DE BÚSQUEDA Y ACCIONES (ESTILO SUPPLIERS) ────
  Widget _buildToolbar(
    BuildContext context,
    WarehousesCubit cubit,
    bool isDesktop,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
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
      child:
          isDesktop
              ? Row(
                children: [
                  Expanded(child: _buildSearchField(cubit)),
                  const SizedBox(width: 12),

                  // Switch de vista Tabla vs Cards
                  _buildViewModeToggle(),
                  const SizedBox(width: 8),

                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 20,
                    ),
                    color: AppColors.textSecondary,
                    tooltip: 'Refrescar almacenes [R]',
                    onPressed: () => cubit.loadWarehouses(isRefresh: true),
                  ),
                  const SizedBox(width: 8),

                  SizedBox(
                    height: 40,
                    child: FilledButton.icon(
                      onPressed: () => _openWarehouseModal(context, cubit),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.add_business_rounded,
                        size: 18,
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Nuevo Almacén',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildButtonKeyHint('N'),
                        ],
                      ),
                    ),
                  ),
                ],
              )
              : _buildSearchField(cubit),
    );
  }

  Widget _buildSearchField(WarehousesCubit cubit) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocusNode,
        onChanged: (val) => _onSearchChanged(val, cubit),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'Buscar almacén por nombre o dirección...',
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.teal,
            size: 19,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (context, value, _) {
              if (value.text.isNotEmpty) {
                return IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    cubit.clearSearch();
                  },
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildKeyHint('/'),
                  ],
                ),
              );
            },
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle() {
    return SizedBox(
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IconButton(
              tooltip: 'Vista en Tabla Pro [V]',
              icon: Icon(
                Icons.table_rows_rounded,
                size: 18,
                color: _isTableView ? AppColors.tealDark : AppColors.textMuted,
              ),
              style: IconButton.styleFrom(
                backgroundColor:
                    _isTableView ? AppColors.surface : Colors.transparent,
                elevation: _isTableView ? 1 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
              ),
              onPressed: () => setState(() => _isTableView = true),
            ),
            IconButton(
              tooltip: 'Vista en Tarjetas [V]',
              icon: Icon(
                Icons.grid_view_rounded,
                size: 18,
                color: !_isTableView ? AppColors.tealDark : AppColors.textMuted,
              ),
              style: IconButton.styleFrom(
                backgroundColor:
                    !_isTableView ? AppColors.surface : Colors.transparent,
                elevation: !_isTableView ? 1 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
              ),
              onPressed: () => setState(() => _isTableView = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyHint(String char) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildButtonKeyHint(String char) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // ── FAB EXCLUSIVO PARA MÓVIL ───────────────────────────────────────
  Widget _buildMobileFab(BuildContext context, WarehousesCubit cubit) {
    return FloatingActionButton.extended(
      onPressed: () => _openWarehouseModal(context, cubit),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 3,
      tooltip: 'Crear nuevo almacén (${AppShortcutLabels.newRecord})',
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: ValueListenableBuilder<bool>(
        valueListenable: _isFabExtended,
        builder: (context, isExtended, _) {
          return AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child:
                isExtended
                    ? const Text(
                      'Nuevo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

// ── BENTO KPI METRIC RIBBON PARA ALMACENES ─────────────────────────────
class _WarehousesKpiBar extends StatelessWidget {
  final int totalCount;
  final int activeCount;
  final int inactiveCount;
  final bool isDesktop;

  const _WarehousesKpiBar({
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final activePct =
        totalCount > 0
            ? ((activeCount / totalCount) * 100).toStringAsFixed(0)
            : '100';

    final cards = [
      _BentoWarehouseKpiCard(
        title: 'Total Almacenes',
        value: '$totalCount',
        subtitle: 'Puntos y depósitos registrados',
        icon: Icons.storefront_rounded,
        iconBgColor: AppColors.primaryLight,
        iconColor: AppColors.primary,
      ),
      _BentoWarehouseKpiCard(
        title: 'Almacenes Activos',
        value: '$activeCount',
        subtitle: '$activePct% de operatividad',
        icon: Icons.check_circle_outline_rounded,
        iconBgColor: AppColors.successLight,
        iconColor: AppColors.successDark,
      ),
      _BentoWarehouseKpiCard(
        title: 'Inactivos / Pausados',
        value: '$inactiveCount',
        subtitle:
            inactiveCount > 0
                ? '$inactiveCount fuera de operaciones'
                : 'Sin almacenes suspendidos',
        icon: Icons.pause_circle_outline_rounded,
        iconBgColor:
            inactiveCount > 0
                ? AppColors.errorLight
                : const Color(0xFFF1F5F9),
        iconColor:
            inactiveCount > 0 ? AppColors.error : AppColors.textMuted,
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

class _BentoWarehouseKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;

  const _BentoWarehouseKpiCard({
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
