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
    final isDesktop = width >= 1024;
    final isTablet = width >= 600 && width < 1024;

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
                  body: RefreshIndicator(
                    onRefresh: () async => cubit.loadWarehouses(isRefresh: true),
                    color: AppColors.primary,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // ── 1. KPI Metric Ribbon ─────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: _WarehousesKpiBar(
                              totalCount:
                                  state.totalRecords > 0
                                      ? state.totalRecords
                                      : warehouses.length,
                              activeCount: activeCount,
                              inactiveCount: inactiveCount,
                              isDesktop: isDesktop || isTablet,
                            ),
                          ),
                        ),

                        // ── 2. Toolbar de Búsqueda y Acciones ────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: _buildToolbar(
                              context,
                              cubit,
                              state,
                              isDesktop,
                              isTablet,
                            ),
                          ),
                        ),

                        // ── 3. Contenido Principal (Tabla o Grilla) ───────
                        if (state.isLoading)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child:
                                  isDesktop && _isTableView
                                      ? const AppTableShimmer(
                                        rowCount: 5,
                                        minWidth: 840,
                                      )
                                      : const WarehousesSkeleton(itemCount: 4),
                            ),
                          )
                        else if (warehouses.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
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
                              action: ElevatedButton.icon(
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
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Registrar Almacén'),
                              ),
                            ),
                          )
                        else if (isDesktop && _isTableView)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                                  cubit.toggleWarehouseStatus(wh, val);
                                },
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        isDesktop
                                            ? 3
                                            : (isTablet ? 2 : 1),
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
                                    cubit.toggleWarehouseStatus(wh, val);
                                  },
                                );
                              }, childCount: warehouses.length),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ── TOOLBAR DE ACCIONES Y BÚSQUEDA ─────────────────────────────────
  Widget _buildToolbar(
    BuildContext context,
    WarehousesCubit cubit,
    WarehousesState state,
    bool isDesktop,
    bool isTablet,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Campo de búsqueda con estilo Stripe
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              onChanged: (val) => _onSearchChanged(val, cubit),
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText:
                    'Buscar almacén por nombre o dirección (${AppShortcutLabels.search})...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 38,
                ),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: AppColors.textSecondary,
                          tooltip: 'Limpiar búsqueda (Esc)',
                          onPressed: () {
                            _searchCtrl.clear();
                            cubit.clearSearch();
                          },
                        )
                        : Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Center(
                            widthFactor: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Text(
                                '/',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Botón Alternar Vista (Tabla / Cuadrícula)
          if (isDesktop || isTablet)
            Tooltip(
              message:
                  _isTableView
                      ? 'Cambiar a cuadrícula (V)'
                      : 'Cambiar a tabla (V)',
              child: InkWell(
                onTap: () => setState(() => _isTableView = !_isTableView),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Icon(
                    _isTableView
                        ? Icons.grid_view_rounded
                        : Icons.table_rows_rounded,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

          if (isDesktop || isTablet) const SizedBox(width: 8),

          // Botón Recargar
          Tooltip(
            message: 'Recargar lista (R)',
            child: InkWell(
              onTap: () => cubit.loadWarehouses(isRefresh: true),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 19,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),

          // Botón Principal en Desktop / Tablet (Elimina el FAB flotante en escritorio)
          if (isDesktop || isTablet) ...[
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => _openWarehouseModal(context, cubit),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Row(
                children: [
                  const Text(
                    'Nuevo Almacén',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'N',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
    final cards = [
      _KpiCard(
        title: 'Total Almacenes',
        value: '$totalCount',
        subtitle: 'Puntos y depósitos registrados',
        icon: Icons.storefront_rounded,
        iconBgColor: AppColors.primaryLight.withValues(alpha: 0.5),
        iconColor: AppColors.primary,
      ),
      _KpiCard(
        title: 'Almacenes Activos',
        value: '$activeCount',
        subtitle:
            totalCount > 0
                ? '${((activeCount / totalCount) * 100).toStringAsFixed(0)}% de operatividad'
                : 'Puntos listos',
        icon: Icons.check_circle_outline_rounded,
        iconBgColor: AppColors.successLight.withValues(alpha: 0.6),
        iconColor: AppColors.successDark,
        valueColor: AppColors.successDark,
      ),
      _KpiCard(
        title: 'Inactivos / Pausados',
        value: '$inactiveCount',
        subtitle:
            inactiveCount > 0
                ? 'Fuera de operaciones'
                : 'Sin almacenes suspendidos',
        icon: Icons.pause_circle_outline_rounded,
        iconBgColor:
            inactiveCount > 0
                ? AppColors.errorLight.withValues(alpha: 0.4)
                : const Color(0xFFF1F5F9),
        iconColor: inactiveCount > 0 ? AppColors.error : AppColors.textMuted,
        valueColor:
            inactiveCount > 0 ? AppColors.error : AppColors.textSecondary,
      ),
    ];

    if (isDesktop) {
      return Row(
        children:
            cards
                .map(
                  (card) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: card,
                    ),
                  ),
                )
                .toList(),
      );
    }

    // En móvil: Scroll horizontal suave
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children:
            cards
                .map(
                  (card) => Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 10),
                    child: card,
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Color? valueColor;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
