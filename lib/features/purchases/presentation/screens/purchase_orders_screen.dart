import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_purchase_order_items_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_purchase_order_by_id_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_detail_sheet.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_orders_bento_kpi_bar.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_orders_draft_banner.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_orders_pagination_bar.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_orders_sliver_list.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_orders_view_model.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  final String? targetOrderId;

  const PurchaseOrdersScreen({super.key, this.targetOrderId});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  PurchaseOrdersCubit get cubit => context.read<PurchaseOrdersCubit>();

  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  bool _hasDraft = false;
  bool _isTableView = true;
  Timer? _debounce;
  PurchaseOrderModel? _selectedOrder;
  String? _pendingTargetOrderId;
  bool _isFetchingTargetOrder = false;
  bool _isSideSheetOpen = false;

  late final ScrollController _listScrollController;
  final ValueNotifier<bool> _fabExtended = ValueNotifier<bool>(true);

  // Focus Shield: aislar atajos si el usuario escribe en un campo editable
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

  @override
  void initState() {
    super.initState();
    _listScrollController = ScrollController();
    _listScrollController.addListener(_onListScrolled);
    _pendingTargetOrderId = widget.targetOrderId;
    _checkDraft();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _screenFocusNode.requestFocus();
      final state = cubit.state;
      // Stale-While-Revalidate: si ya hay datos cargados, no se borra la pantalla
      if (state is! PurchaseOrdersLoaded || state.orders.isEmpty) {
        cubit.init();
      } else {
        cubit.loadOrders(background: true);
      }
    });
  }

  void _onListScrolled() {
    if (!_listScrollController.hasClients) return;
    final shouldExtend = _listScrollController.offset <= 60;
    if (shouldExtend != _fabExtended.value) {
      _fabExtended.value = shouldExtend;
    }
  }

  @override
  void didUpdateWidget(covariant PurchaseOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetOrderId != oldWidget.targetOrderId) {
      if (widget.targetOrderId == null) {
        if (_selectedOrder != null) {
          setState(() => _selectedOrder = null);
        }
        return;
      }
      if (widget.targetOrderId == _selectedOrder?.id) {
        return;
      }
      _pendingTargetOrderId = widget.targetOrderId;
      final state = cubit.state;
      if (state is PurchaseOrdersLoaded) {
        final isTablet = MediaQuery.sizeOf(context).width >= 640;
        _resolveTargetOrder(state.orders.cast<PurchaseOrderModel>(), isTablet);
      }
    }
  }

  void _selectOrder(PurchaseOrderModel? po, {bool updateUrl = true}) {
    setState(() {
      _selectedOrder = po;
    });

    if (updateUrl && mounted) {
      final isTablet = MediaQuery.sizeOf(context).width >= 640;
      if (isTablet) {
        if (po != null) {
          context.replace('/purchase-orders?selectedId=${po.id}');
        } else {
          context.replace('/purchase-orders');
        }
      }
    }
  }

  Future<List<PurchaseOrderItemEntity>> _loadOrderItems(String orderId) async {
    final res = await sl<FetchPurchaseOrderItemsUseCase>().call(orderId);
    return res.fold((l) => <PurchaseOrderItemEntity>[], (r) => r);
  }

  Future<void> _checkDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('po_form_draft_v1');
      if (str != null) {
        final data = jsonDecode(str) as Map<String, dynamic>;
        final items = data['items'] as List?;
        if (mounted) {
          setState(() {
            _hasDraft = items != null && items.isNotEmpty;
          });
        }
      } else {
        if (mounted) setState(() => _hasDraft = false);
      }
    } catch (e, st) {
      LoggerService.e(
        'Error al verificar borrador de orden de compra',
        tag: 'PURCHASE_ORDERS_SCREEN',
        error: e,
        stackTrace: st,
      );
      if (mounted) setState(() => _hasDraft = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _listScrollController.dispose();
    _fabExtended.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(
    FocusNode node,
    KeyEvent event,
    PurchaseOrdersViewModel viewModel,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final isControlOrMeta =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final key = event.logicalKey;

    // Ctrl+K o Cmd+K (o '/') -> enfocar buscador
    if ((isControlOrMeta && key == LogicalKeyboardKey.keyK) ||
        key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // Escape -> desenfocar buscador, deseleccionar orden o limpiar búsqueda
    if (key == LogicalKeyboardKey.escape) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (_selectedOrder != null) {
        _selectOrder(null, updateUrl: true);
        return KeyEventResult.handled;
      }
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        viewModel.setSearchText('');
        return KeyEventResult.handled;
      }
    }

    // Atajo [N] -> Nueva orden de compra
    if (key == LogicalKeyboardKey.keyN) {
      context.go('/purchase-orders/form');
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar órdenes de compra
    if (key == LogicalKeyboardKey.keyR) {
      cubit.refresh();
      AppSnackbar.show(
        context,
        message: 'Actualizando órdenes de compra...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    // Atajo [V] -> Alternar Vista (Tabla Pro vs Tarjetas)
    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    // Atajos [1..6] -> Filtros de estado rápidos
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      viewModel.setStatusFilter('Todos');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      viewModel.setStatusFilter('PENDING');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      viewModel.setStatusFilter('SENT');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      viewModel.setStatusFilter('PARTIAL');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      viewModel.setStatusFilter('RECEIVED');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      viewModel.setStatusFilter('CANCELLED');
      return KeyEventResult.handled;
    }

    // Flechas arriba/abajo y Enter
    final filtered = viewModel.orders.cast<PurchaseOrderModel>();
    final displayOrders =
        (_selectedOrder != null &&
                !filtered.any((o) => o.id == _selectedOrder!.id))
            ? [_selectedOrder!, ...filtered]
            : filtered;

    if (displayOrders.isNotEmpty) {
      final currentIndex =
          _selectedOrder != null
              ? displayOrders.indexWhere((o) => o.id == _selectedOrder!.id)
              : -1;

      if (key == LogicalKeyboardKey.arrowDown) {
        final nextIndex =
            currentIndex == -1
                ? 0
                : (currentIndex + 1).clamp(0, displayOrders.length - 1);
        _selectOrder(displayOrders[nextIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowUp) {
        final prevIndex =
            currentIndex == -1
                ? 0
                : (currentIndex - 1).clamp(0, displayOrders.length - 1);
        _selectOrder(displayOrders[prevIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        final po = _selectedOrder ?? displayOrders.first;
        _openDesktopDetailSheet(po);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Future<void> _openDesktopDetailSheet(PurchaseOrderModel po) async {
    if (!mounted || _isSideSheetOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _isSideSheetOpen = true;
    _selectOrder(po, updateUrl: true);

    final cubitInstance = context.read<PurchaseOrdersCubit>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth >= 1440 ? 660.0 : 610.0;

    await AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: drawerWidth,
      barrierLabel: 'Cerrar detalle de compra',
      builder: (dialogCtx) {
        return BlocProvider.value(
          value: cubitInstance,
          child: PODetailSheet(
            po: po,
            isDialog: AdaptiveDetailSheet.isSideSheet(dialogCtx),
            onPaymentSuccess: () {},
            loadItems: () => _loadOrderItems(po.id),
            onReceive: () => _handleReceiveOrder(dialogCtx, po),
            onUpdateStatus: (status) async {
              await cubitInstance.updateOrderStatus(po.id, status);
            },
          ),
        );
      },
    );

    _isSideSheetOpen = false;
    if (mounted) {
      _selectOrder(null, updateUrl: true);
    }
  }

  void _resolveTargetOrder(List<PurchaseOrderModel> orders, bool isTablet) {
    final targetId = _pendingTargetOrderId;
    if (targetId == null) return;

    final foundIndex = orders.indexWhere((o) => o.id == targetId);
    if (foundIndex != -1) {
      _pendingTargetOrderId = null;
      final targetPo = orders[foundIndex];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openDesktopDetailSheet(targetPo);
        }
      });
    } else {
      _pendingTargetOrderId = null;
      _fetchAndSelectOrder(targetId);
    }
  }

  Future<void> _fetchAndSelectOrder(String targetId) async {
    if (_isFetchingTargetOrder) return;
    _isFetchingTargetOrder = true;
    try {
      final res = await sl<GetPurchaseOrderByIdUseCase>().call(targetId);
      if (!mounted) return;
      res.fold(
        (failure) {
          AppSnackbar.show(
            context,
            message: 'No se pudo encontrar la orden de compra asociada.',
            type: SnackbarType.error,
          );
        },
        (map) {
          if (map != null && mounted) {
            final loadedPo = PurchaseOrderModel.fromMap(map);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _openDesktopDetailSheet(loadedPo);
              }
            });
          }
        },
      );
    } catch (e, st) {
      LoggerService.e(
        'Error al obtener orden de compra objetivo: $targetId',
        tag: 'PURCHASE_ORDERS_SCREEN',
        error: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingTargetOrder = false);
      } else {
        _isFetchingTargetOrder = false;
      }
    }
  }

  Future<void> _handleReceiveOrder(
    BuildContext context,
    PurchaseOrderModel po,
  ) async {
    final items = await _loadOrderItems(po.id);
    if (!context.mounted) return;

    final entryItems =
        items.map((i) {
          final remaining = i.quantityOrdered - i.quantityReceived;
          final qty = remaining > 0 ? remaining : i.quantityOrdered;
          return InventoryEntryItemEntity(
            productId: i.productId,
            productName: i.productName ?? '—',
            variantId: i.variantId,
            variantLabel: i.variantAttrs.isNotEmpty ? i.variantAttrs : 'Única',
            imageUrl: i.imageUrl,
            usesBatches: i.usesBatches,
            quantity: qty,
            unitCost: i.unitCost,
            batchNumber: i.batchNumber.isNotEmpty ? i.batchNumber : 'DEFAULT',
            expiryDate: i.expiryDate,
          );
        }).toList();

    if (!context.mounted) return;

    final received = await context.push<bool>(
      '/inventory-entries/form?purchaseOrderId=${po.id}',
      extra: {
        'purchaseOrderId': po.id,
        'prefillSupplierId': po.supplierId,
        'prefillSupplierName': po.supplierName,
        'prefillWarehouseId': po.warehouseId,
        'prefillItems': entryItems,
        'prefillDocumentType': po.documentType,
        'prefillDocumentNumber': po.documentNumber,
        'prefillDocumentDate': po.createdAt,
      },
    );

    if (!context.mounted) return;

    if (received == true) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route is! PopupRoute);

      await context.read<PurchaseOrdersCubit>().loadOrders(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = MediaQuery.sizeOf(context).width >= 640;

    return BlocConsumer<PurchaseOrdersCubit, PurchaseOrdersState>(
      buildWhen:
          (previous, current) =>
              current is PurchaseOrdersLoaded ||
              current is PurchaseOrdersLoading ||
              current is PurchaseOrdersError,
      listener: (context, state) {
        if (state is PurchaseOrdersLoaded && _pendingTargetOrderId != null) {
          _resolveTargetOrder(
            state.orders.cast<PurchaseOrderModel>(),
            isDesktopOrTablet,
          );
        }
      },
      builder: (context, state) {
        final viewModel = PurchaseOrdersViewModel(cubit, state);

        if (viewModel.errorMessage.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppSnackbar.show(
              context,
              message: viewModel.errorMessage,
              type: SnackbarType.error,
            );
            viewModel.clearError();
          });
        }

        final filtered = viewModel.orders.cast<PurchaseOrderModel>();

        // Sincronizar selección ordinaria
        if (_pendingTargetOrderId == null) {
          if (filtered.isNotEmpty) {
            if (_selectedOrder != null) {
              final index = filtered.indexWhere(
                (o) => o.id == _selectedOrder!.id,
              );
              if (index != -1) {
                _selectedOrder = filtered[index];
              }
            }
          } else {
            _selectedOrder = null;
          }
        }

        final displayOrders =
            (_selectedOrder != null &&
                    !filtered.any((o) => o.id == _selectedOrder!.id))
                ? [_selectedOrder!, ...filtered]
                : filtered;

        return AdminLayout(
          title: 'Órdenes de Compra',
          floatingActionButton:
              isDesktopOrTablet
                  ? null
                  : ValueListenableBuilder<bool>(
                    valueListenable: _fabExtended,
                    builder: (context, isExtended, _) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder:
                            (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                        child:
                            isExtended
                                ? FloatingActionButton.extended(
                                  key: const ValueKey('fab_ext'),
                                  heroTag: 'po_new_fab',
                                  onPressed:
                                      () => context.go('/purchase-orders/form'),
                                  backgroundColor:
                                      _hasDraft
                                          ? const Color(0xFFF59E0B)
                                          : AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  icon: Icon(
                                    _hasDraft
                                        ? Icons.edit_note_rounded
                                        : Icons.add_shopping_cart_rounded,
                                  ),
                                  label: Text(
                                    _hasDraft ? 'Borrador' : 'Nueva Orden',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                                : FloatingActionButton(
                                  key: const ValueKey('fab_compact'),
                                  heroTag: 'po_new_fab',
                                  onPressed:
                                      () => context.go('/purchase-orders/form'),
                                  backgroundColor:
                                      _hasDraft
                                          ? const Color(0xFFF59E0B)
                                          : AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    _hasDraft
                                        ? Icons.edit_note_rounded
                                        : Icons.add_shopping_cart_rounded,
                                  ),
                                ),
                      );
                    },
                  ),
          body: Focus(
            focusNode: _screenFocusNode,
            autofocus: true,
            onKeyEvent:
                (node, event) => _handleKeyEvent(node, event, viewModel),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 640;

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    await cubit.refresh();
                  },
                  child: CustomScrollView(
                    controller: _listScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Barra sutil de revalidación en background (sin shimmer ni parpadeos)
                      if (viewModel.isBackgroundLoading)
                        const SliverToBoxAdapter(
                          child: LinearProgressIndicator(
                            color: AppColors.teal,
                            minHeight: 2,
                          ),
                        ),

                      // Cabecera ejecutiva Stripe / Linear
                      SliverToBoxAdapter(
                        child: AdminPageHeader(
                          title: 'Órdenes de Compra',
                          subtitle:
                              'Gestiona pedidos a proveedores, recepción de mercancía y cuentas por pagar.',
                          isDesktop: isDesktopOrTablet,
                          actions: [
                            AdminHeaderButton.primary(
                              label:
                                  _hasDraft
                                      ? 'Continuar Borrador'
                                      : 'Nueva Orden',
                              icon:
                                  _hasDraft
                                      ? Icons.edit_note_rounded
                                      : Icons.add_shopping_cart_rounded,
                              tooltip:
                                  _hasDraft
                                      ? 'Continuar orden de compra (Atajo: N)'
                                      : 'Nueva orden de compra (Atajo: N)',
                              onPressed:
                                  () => context.go('/purchase-orders/form'),
                            ),
                          ],
                        ),
                      ),

                      // Banner de alerta para borrador en curso
                      if (_hasDraft)
                        const SliverToBoxAdapter(
                          child: PurchaseOrdersDraftBanner(),
                        ),

                      // Bento KPI Bar con totales computados en tiempo O(1)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: PurchaseOrdersBentoKpiBar(
                            orderCount: viewModel.orders.length,
                            totalRecords: viewModel.totalCount,
                            totalAmount: viewModel.totalAmountFiltered,
                            pendingCount: viewModel.pendingCountFiltered,
                            totalDebt: viewModel.totalDebtFiltered,
                            isDesktop: isDesktopOrTablet,
                          ),
                        ),
                      ),

                      // Toolbar Pro Unificado (Buscador, Filtros, Vista, Refresh)
                      SliverToBoxAdapter(
                        child: AdminProToolbar(
                          isDesktop: constraints.maxWidth >= 1024,
                          isLoading:
                              viewModel.isLoading ||
                              viewModel.isBackgroundLoading,
                          searchController: _searchCtrl,
                          searchFocusNode: _searchFocusNode,
                          searchHint: 'Buscar por proveedor, documento o ID...',
                          onSearchChanged: (v) {
                            _debounce?.cancel();
                            _debounce = Timer(
                              const Duration(milliseconds: 300),
                              () => viewModel.setSearchText(v),
                            );
                          },
                          onClearSearch: () {
                            _searchCtrl.clear();
                            viewModel.setSearchText('');
                          },
                          filterGroups: [
                            AdminFilterGroup<String>(
                              title: 'Estado',
                              icon: Icons.filter_list_rounded,
                              selected: viewModel.statusFilter,
                              defaultValue: 'Todos',
                              displayType: AdminFilterDisplayType.chips,
                              onSelected: viewModel.setStatusFilter,
                              options: [
                                const AdminFilterOption(
                                  value: 'Todos',
                                  label: 'Todos',
                                  icon: Icons.list_alt_rounded,
                                ),
                                const AdminFilterOption(
                                  value: 'PENDING',
                                  label: 'Pendientes',
                                  icon: Icons.hourglass_top_rounded,
                                  color: AppColors.warningDark,
                                ),
                                const AdminFilterOption(
                                  value: 'SENT',
                                  label: 'Enviados',
                                  icon: Icons.send_rounded,
                                  color: Color(0xFF1D4ED8),
                                ),
                                AdminFilterOption(
                                  value: 'PARTIAL',
                                  label: 'Parciales',
                                  icon: Icons.pie_chart_rounded,
                                  color: Colors.amber.shade900,
                                ),
                                const AdminFilterOption(
                                  value: 'RECEIVED',
                                  label: 'Recibidos',
                                  icon: Icons.check_circle_rounded,
                                  color: AppColors.tealDark,
                                ),
                                const AdminFilterOption(
                                  value: 'CANCELLED',
                                  label: 'Cancelados',
                                  icon: Icons.cancel_rounded,
                                  color: AppColors.error,
                                ),
                              ],
                            ),
                            AdminFilterGroup<String>(
                              title: 'Almacén',
                              icon: Icons.storefront_rounded,
                              selected: viewModel.warehouseFilter,
                              defaultValue: 'Todos',
                              onSelected: viewModel.setWarehouseFilter,
                              options: [
                                for (final w in viewModel.availableWarehouses)
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
                              dateRange: viewModel.dateRange,
                              onDateRangeSelected: (picked) {
                                viewModel.setDateRange(picked);
                              },
                              onClear: () {
                                viewModel.setDateRange(null);
                              },
                            ),
                          ],
                          activeFiltersCount:
                              (viewModel.statusFilter != 'Todos' ? 1 : 0) +
                              (viewModel.warehouseFilter != 'Todos' &&
                                      viewModel.warehouseFilter != 'TODOS'
                                  ? 1
                                  : 0) +
                              (viewModel.dateRange != null ? 1 : 0),
                          onClearFilters: () {
                            viewModel.setStatusFilter('Todos');
                            viewModel.setWarehouseFilter('Todos');
                            viewModel.setDateRange(null);
                          },
                          viewToggleConfig: AdminProViewToggleConfig(
                            isTableView: _isTableView,
                            onToggleTableView:
                                (val) => setState(() => _isTableView = val),
                          ),
                          onRefresh: () {
                            cubit.refresh();
                          },
                        ),
                      ),

                      // Lista / Tabla de Órdenes en Slivers
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        sliver: PurchaseOrdersSliverList(
                          viewModel: viewModel,
                          displayOrders: displayOrders,
                          filteredOrders: filtered,
                          selectedOrder: _selectedOrder,
                          isTablet: isTablet,
                          isTableView: _isTableView,
                          onSelectOrder: _openDesktopDetailSheet,
                          onRefresh: () => cubit.refresh(),
                        ),
                      ),

                      // Paginación Fluida al Pie del Scroll
                      PurchaseOrdersPaginationBar(viewModel: viewModel),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
