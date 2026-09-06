import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_tab.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_batches_tab.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_export_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class InventoryScreen extends StatefulWidget {
  final String? initialSearch;

  const InventoryScreen({super.key, this.initialSearch});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      // Lazy load de la pestaña de lotes evitando llamadas duplicadas
      final cubit = context.read<InventoryCubit>();
      final state = cubit.state;
      if (state is InventoryLoaded && state.batchItems.isEmpty) {
        cubit.initBatchesTab();
      }
    }
  }

  void _openExportModal(InventoryLoaded? loadedState) {
    InventoryExportSheet.show(
      context,
      selectedWarehouseId: loadedState?.selectedWarehouseId,
      selectedWarehouseName: loadedState?.selectedWarehouseName,
      warehouses: loadedState?.warehouses ?? [],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is InventoryLoaded && current is InventoryLoaded) {
          final urgentPrev = previous.countVencido + previous.countCritico;
          final urgentCurr = current.countVencido + current.countCritico;
          return urgentPrev != urgentCurr ||
              previous.selectedWarehouseId != current.selectedWarehouseId ||
              previous.warehouses.length != current.warehouses.length;
        }
        return false;
      },
      builder: (context, state) {
        final loadedState = state is InventoryLoaded ? state : null;
        int urgentCount = 0;
        if (loadedState != null) {
          urgentCount = loadedState.countVencido + loadedState.countCritico;
        }

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed;
              if (isCtrlOrCmd && event.logicalKey == LogicalKeyboardKey.keyE) {
                _openExportModal(loadedState);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: AdminLayout(
            title: 'Inventario',
            showBackButton: true,
            actions: [
              _ExportHeaderButton(
                onPressed: () => _openExportModal(loadedState),
                isCompact: true,
              ),
            ],
            body: Column(
              children: [
                // ── Header Segmented Pill Bar, Warehouse Selector & Export Action ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 760;

                      final tabBarWidget = Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: AppColors.cardShadow(opacity: 0.04),
                          ),
                          dividerColor: Colors.transparent,
                          labelColor: AppColors.textPrimary,
                          unselectedLabelColor: AppColors.textSecondary,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.1,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          tabs: [
                            const Tab(
                              height: 36,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text('Stock General'),
                                ],
                              ),
                            ),
                            Tab(
                              height: 36,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.event_busy_rounded, size: 16),
                                  const SizedBox(width: 8),
                                  const Text('Estado de Lotes'),
                                  if (urgentCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$urgentCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );

                      final warehouseSelector = _WarehouseSelector(
                        state: loadedState,
                      );

                      final exportButton = _ExportHeaderButton(
                        onPressed: () => _openExportModal(loadedState),
                        isCompact: false,
                      );

                      if (!isDesktop) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: tabBarWidget),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: warehouseSelector),
                                const SizedBox(width: 8),
                                _ExportHeaderButton(
                                  onPressed: () => _openExportModal(loadedState),
                                  isCompact: true,
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          tabBarWidget,
                          const Spacer(),
                          warehouseSelector,
                          const SizedBox(width: 10),
                          exportButton,
                        ],
                      );
                    },
                  ),
                ),

                // ── Tab Views ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      InventoryStockTab(initialSearch: widget.initialSearch),
                      const InventoryBatchesTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WarehouseSelector extends StatelessWidget {
  final InventoryLoaded? state;

  const _WarehouseSelector({this.state});

  @override
  Widget build(BuildContext context) {
    final warehouses = state?.warehouses ?? [];
    final selectedId = state?.selectedWarehouseId;
    final isSelected = selectedId != null && selectedId.isNotEmpty;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.04)
            : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warehouse_rounded,
            size: 17,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          const Text(
            'Almacén:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedId,
              icon: const Icon(
                Icons.arrow_drop_down_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              borderRadius: BorderRadius.circular(10),
              dropdownColor: AppColors.surface,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Todos los almacenes',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...warehouses.map((wh) {
                  return DropdownMenuItem<String?>(
                    value: wh.id,
                    child: Text(
                      wh.name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (newWarehouseId) {
                String whName = 'Todos los almacenes';
                if (newWarehouseId != null) {
                  final found = warehouses.where((w) => w.id == newWarehouseId);
                  if (found.isNotEmpty) {
                    whName = found.first.name;
                  }
                }
                context.read<InventoryCubit>().setWarehouseFilter(
                  newWarehouseId,
                  whName,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportHeaderButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isCompact;

  const _ExportHeaderButton({
    required this.onPressed,
    this.isCompact = false,
  });

  @override
  State<_ExportHeaderButton> createState() => _ExportHeaderButtonState();
}

class _ExportHeaderButtonState extends State<_ExportHeaderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Exportar Inventario a Excel (Ctrl + E)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 10 : 14,
            ),
            decoration: BoxDecoration(
              color: _isHovered
                  ? AppColors.teal.withValues(alpha: 0.08)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovered ? AppColors.teal : AppColors.border,
              ),
              boxShadow: AppColors.cardShadow(opacity: 0.02),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.table_view_rounded,
                  size: 17,
                  color: AppColors.teal,
                ),
                if (!widget.isCompact) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'Exportar Excel',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
