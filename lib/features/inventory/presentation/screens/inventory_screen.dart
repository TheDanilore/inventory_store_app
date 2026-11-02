import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_batches_tab.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_export_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_screen_header.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_tab.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_warehouse_picker_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

/// Pantalla principal de Control de Inventario & Stock.
///
/// Arquitectura Camaleónica y Multi-dispositivo:
/// - **Desktop (>= 900dp)**: Filosofía Power User / ERP Pro Tool (Linear/Stripe).
///   Barra de herramientas compacta con atajos de tecla única (Focus Shield),
///   indicador de urgencia cruzada entre stock y lotes, selector con hover y exportador rápido.
/// - **Tablet (640dp - 900dp)**: Eficiencia híbrida, distribución balanceada y modales contenidos.
/// - **Móvil (< 640dp)**: Filosofía Apple HIG. Selector de almacén mediante modal BottomSheet táctil,
///   targets táctiles mínimos de 48x48dp, bordes curvos (16-24dp) y optimización estricta del pulgar.
class InventoryScreen extends StatefulWidget {
  final String? initialSearch;
  final String? initialStatusFilter;
  final String? initialWarehouseId;
  final int? initialTabIndex;
  final bool isEmbedded;

  const InventoryScreen({
    super.key,
    this.initialSearch,
    this.initialStatusFilter,
    this.initialWarehouseId,
    this.initialTabIndex,
    this.isEmbedded = false,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _screenFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final startIdx =
        (widget.initialTabIndex != null &&
                widget.initialTabIndex! >= 0 &&
                widget.initialTabIndex! < 2)
            ? widget.initialTabIndex!
            : 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: startIdx,
    );
    _tabController.addListener(_handleTabSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
        if (startIdx == 1) {
          final cubit = context.read<InventoryCubit>();
          final state = cubit.state;
          if (state is InventoryLoaded) {
            if (state.batchItems.isEmpty && !state.isSearchingBatches) {
              cubit.initBatchesTab();
            }
          }
        }
      }
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      // Lazy load de la pestaña de lotes evitando llamadas duplicadas
      final cubit = context.read<InventoryCubit>();
      final state = cubit.state;
      if (state is InventoryLoaded &&
          state.batchItems.isEmpty &&
          !state.isSearchingBatches) {
        cubit.initBatchesTab();
      }
    }
  }

  void _openExportModal(InventoryLoaded? loadedState) {
    FocusManager.instance.primaryFocus?.unfocus();
    InventoryExportSheet.show(
      context,
      selectedWarehouseId: loadedState?.selectedWarehouseId,
      selectedWarehouseName: loadedState?.selectedWarehouseName,
      warehouses: loadedState?.warehouses ?? [],
    );
  }

  // ── REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) ────────────────────
  bool get _isInputFieldFocused => FocusUtils.isInputFieldFocused();

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo de texto editable (buscador, editor de stock),
    // aislamos los atajos de una sola tecla para permitir la escritura natural sin interferencias.
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        FocusManager.instance.primaryFocus?.unfocus();
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isModifier =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed;

    // Atajo [1] o [Numpad 1] -> Conmutar a Stock General
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
        return KeyEventResult.handled;
      }
    }

    // Atajo [2] o [Numpad 2] -> Conmutar a Estado de Lotes
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      if (_tabController.index != 1) {
        _tabController.animateTo(1);
        return KeyEventResult.handled;
      }
    }

    // Atajo [B] o [Alt+B] -> Alternar filtro de Bajo Stock (cuando foco no está en input)
    if ((key == LogicalKeyboardKey.keyB && !isModifier) ||
        (HardwareKeyboard.instance.isAltPressed &&
            key == LogicalKeyboardKey.keyB)) {
      final cubit = context.read<InventoryCubit>();
      final state = cubit.state;
      if (state is InventoryLoaded) {
        final isLowStock =
            state.stockStatusFilter == 'low_stock' ||
            state.stockStatusFilter == 'bajo_stock';
        cubit.setStockStatusFilter(isLowStock ? 'all' : 'low_stock');
        AppSnackbar.show(
          context,
          message:
              isLowStock
                  ? 'Mostrando todo el inventario'
                  : 'Filtrando: Solo productos con bajo stock',
          type: SnackbarType.info,
          duration: const Duration(seconds: 2),
        );
        return KeyEventResult.handled;
      }
    }

    // Atajo [R] -> Recargar todo el inventario
    if (key == LogicalKeyboardKey.keyR && !isModifier) {
      context.read<InventoryCubit>().refreshAll();
      AppSnackbar.show(
        context,
        message: 'Actualizando catálogo de inventario y lotes...',
        type: SnackbarType.info,
        duration: const Duration(seconds: 2),
      );
      return KeyEventResult.handled;
    }

    // Atajo [E] o [Ctrl+E] / [Alt+E] -> Exportar Excel
    if ((key == LogicalKeyboardKey.keyE && !isModifier) ||
        (isModifier && key == LogicalKeyboardKey.keyE)) {
      final state = context.read<InventoryCubit>().state;
      final loadedState = state is InventoryLoaded ? state : null;
      _openExportModal(loadedState);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _showWarehouseBottomSheet(BuildContext context, InventoryLoaded? state) {
    FocusManager.instance.primaryFocus?.unfocus();
    final cubit = context.read<InventoryCubit>();
    WarehousePickerBottomSheet.show(
      context,
      state: state,
      cubit: cubit,
      onWarehouseSelected: (id, name) {
        cubit.setWarehouseFilter(id, name);
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocConsumer<InventoryCubit, InventoryState>(
      listenWhen: (previous, current) {
        return current is InventoryLoaded &&
            _tabController.index == 1 &&
            current.batchItems.isEmpty &&
            !current.isSearchingBatches;
      },
      listener: (context, state) {
        context.read<InventoryCubit>().initBatchesTab();
      },
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

        final inventoryBody = Column(
          children: [
            // ── Barra Superior Camaleónica: Segmented Control, Almacén & Exportación ──
            RepaintBoundary(
              child: AdaptiveInventoryHeader(
                tabController: _tabController,
                loadedState: loadedState,
                urgentCount: urgentCount,
                onOpenExport: () => _openExportModal(loadedState),
                onOpenWarehousePickerMobile:
                    () => _showWarehouseBottomSheet(context, loadedState),
              ),
            ),

            // ── Contenido de Pestañas / Vistas ──
            Expanded(
              child: RepaintBoundary(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    InventoryStockTab(
                      initialSearch: widget.initialSearch,
                      initialStatusFilter: widget.initialStatusFilter,
                    ),
                    const InventoryBatchesTab(),
                  ],
                ),
              ),
            ),
          ],
        );

        final focusableContent = Focus(
          focusNode: _screenFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: FocusTraversalGroup(
            child:
                widget.isEmbedded
                    ? Material(
                      color:
                          isDark
                              ? AppColors.darkBackground
                              : AppColors.background,
                      child: inventoryBody,
                    )
                    : AdminLayout(title: 'Inventario', body: inventoryBody),
          ),
        );

        return focusableContent;
      },
    );
  }
}
