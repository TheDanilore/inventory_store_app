import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_state.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_confirm_dialog.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_detail_sheet.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_receipt_export_sheet.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/orders_bento_kpi_bar.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/orders_pagination_bar.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/orders_sliver_list.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/payment_method_sheet.dart';

class OrdersScreen extends StatefulWidget {
  final String? customTitle;
  final String? targetOrderId;
  final bool isEmbedded;
  final VoidCallback? onOpenCashShifts;

  const OrdersScreen({
    super.key,
    this.customTitle,
    this.targetOrderId,
    this.isEmbedded = false,
    this.onOpenCashShifts,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _debounce;
  OrderEntity? _selectedOrder;
  String? _pendingTargetOrderId;
  bool _isFetchingTargetOrder = false;
  bool _isTableView = true;
  bool _isSideSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _pendingTargetOrderId = widget.targetOrderId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _screenFocusNode.requestFocus();
      final cubit = context.read<OrdersCubit>();
      // Stale-While-Revalidate: si ya hay pedidos en caché L1, no mostrar shimmer
      if (cubit.state.orders.isEmpty) {
        cubit.init();
      } else {
        cubit.loadOrders(background: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
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
      final cubit = context.read<OrdersCubit>();
      final isWide = MediaQuery.sizeOf(context).width >= 640;
      _resolveTargetOrder(cubit.state.orders, isWide);
    }
  }

  void _selectOrder(OrderEntity? order, {bool updateUrl = true}) {
    setState(() {
      _selectedOrder = order;
    });

    if (updateUrl && !widget.isEmbedded && mounted) {
      final isWide = MediaQuery.sizeOf(context).width >= 640;
      if (isWide) {
        if (order != null) {
          context.replace('/orders?selectedId=${order.id}');
        } else {
          context.replace('/orders');
        }
      }
    }
  }

  void _resolveTargetOrder(List<OrderEntity> orders, bool isWide) {
    final targetId = _pendingTargetOrderId;
    if (targetId == null) return;

    final foundIndex = orders.indexWhere((o) => o.id == targetId);
    if (foundIndex != -1) {
      _pendingTargetOrderId = null;
      final targetOrder = orders[foundIndex];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showOrderDetails(targetOrder, isWide);
        }
      });
    } else {
      _pendingTargetOrderId = null;
      _fetchAndSelectOrder(targetId, isWide);
    }
  }

  Future<void> _fetchAndSelectOrder(String targetId, bool isWide) async {
    if (_isFetchingTargetOrder) return;
    _isFetchingTargetOrder = true;
    try {
      final res = await context.read<OrdersCubit>().getOrderById(targetId);
      if (!mounted) return;
      res.fold(
        (failure) {
          AppSnackbar.show(
            context,
            message: 'No se pudo encontrar el pedido asociado.',
            type: SnackbarType.error,
          );
        },
        (order) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showOrderDetails(order, isWide);
            }
          });
        },
      );
    } catch (e, st) {
      LoggerService.e(
        'Error al obtener pedido por ID foráneo: $targetId',
        error: e,
        stackTrace: st,
        tag: 'OrdersScreen',
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al cargar el pedido seleccionado.',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingTargetOrder = false);
      } else {
        _isFetchingTargetOrder = false;
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

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
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final isControlOrMeta =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final key = event.logicalKey;

    if ((isControlOrMeta && key == LogicalKeyboardKey.keyK) ||
        key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

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
        context.read<OrdersCubit>().setSearchQuery('');
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.keyP ||
        (isControlOrMeta && key == LogicalKeyboardKey.keyP)) {
      if (_selectedOrder != null) {
        _printOrderTicket(_selectedOrder!);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.keyR) {
      context.read<OrdersCubit>().refresh();
      AppSnackbar.show(
        context,
        message: 'Actualizando pedidos...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      context.read<OrdersCubit>().setStatusFilter('ALL');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      context.read<OrdersCubit>().setStatusFilter('PENDING');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      context.read<OrdersCubit>().setStatusFilter('COMPLETED');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      context.read<OrdersCubit>().setStatusFilter('CANCELLED');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      context.read<OrdersCubit>().setStatusFilter('RETURNED');
      return KeyEventResult.handled;
    }

    final cubit = context.read<OrdersCubit>();
    final orders = cubit.state.orders;
    if (orders.isNotEmpty) {
      final currentIndex =
          _selectedOrder != null
              ? orders.indexWhere((o) => o.id == _selectedOrder!.id)
              : -1;

      if (key == LogicalKeyboardKey.arrowDown) {
        final nextIndex =
            currentIndex == -1
                ? 0
                : (currentIndex + 1).clamp(0, orders.length - 1);
        _selectOrder(orders[nextIndex], updateUrl: true);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        final prevIndex =
            currentIndex == -1
                ? 0
                : (currentIndex - 1).clamp(0, orders.length - 1);
        _selectOrder(orders[prevIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        final order = _selectedOrder ?? orders.first;
        final isWide = MediaQuery.sizeOf(context).width >= 640;
        _showOrderDetails(order, isWide);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        context.read<OrdersCubit>().setSearchQuery(value);
      }
    });
  }

  Future<void> _printOrderTicket(OrderEntity order) async {
    try {
      final cachedItems = context.read<OrdersCubit>().getCachedOrderItems(
        order.id,
      );
      await OrderReceiptExportSheet.show(
        context,
        order: order,
        initialItems: cachedItems,
      );
    } catch (e, st) {
      LoggerService.e(
        'Error al generar ticket para pedido ${order.id}',
        error: e,
        stackTrace: st,
        tag: 'OrdersScreen',
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al generar ticket: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _updateOrderStatus(OrderEntity order, String newStatus) async {
    if (context.read<OrdersCubit>().state.isOrderProcessing(order.id)) return;

    if (newStatus == 'COMPLETED' &&
        (order.paymentMethod == 'POR ACORDAR' ||
            order.paymentMethod.trim().isEmpty)) {
      final selectedMethod = await PaymentMethodSheet.show(context, order);
      if (selectedMethod == null) return;
      order = order.copyWith(paymentMethod: selectedMethod);
    }

    if (!mounted) return;

    final confirm = await OrderConfirmDialog.show(
      context,
      order: order,
      newStatus: newStatus,
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      final success = await context.read<OrdersCubit>().updateOrderStatus(
        order,
        newStatus,
      );
      if (!mounted) return;
      if (success) {
        AppSnackbar.show(
          context,
          message:
              newStatus == 'COMPLETED'
                  ? 'Pedido completado correctamente'
                  : 'Estado actualizado correctamente',
          type: SnackbarType.success,
        );
      } else {
        final state = context.read<OrdersCubit>().state;
        final errorMsg =
            (state.actionError != null && state.actionError!.isNotEmpty)
                ? state.actionError!
                : state.errorMessage;
        AppSnackbar.show(
          context,
          message:
              errorMsg.isNotEmpty
                  ? errorMsg
                  : 'No se pudo actualizar el estado de la orden.',
          type: SnackbarType.error,
        );
      }
    } catch (e, st) {
      LoggerService.e(
        'Error al actualizar estado del pedido ${order.id}',
        error: e,
        stackTrace: st,
        tag: 'OrdersScreen',
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al actualizar: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _showOrderDetails(OrderEntity order, bool isWide) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted || _isSideSheetOpen) return;
    _isSideSheetOpen = true;
    _selectOrder(order, updateUrl: true);

    final cubit = context.read<OrdersCubit>();
    final configCubit = context.read<AppConfigCubit>();

    final result = await AdaptiveDetailSheet.show<bool>(
      context,
      desktopWidth: 620,
      enableGlassmorphism: true,
      builder: (dialogCtx) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: configCubit),
          ],
          child: OrderDetailSheet(
            key: ValueKey(order.id),
            order: order,
            isEmbedded: false,
            onOrderUpdated: (updated) {
              if (mounted) {
                cubit.updateOrderInList(updated);
              }
            },
          ),
        );
      },
    );

    _isSideSheetOpen = false;
    if (mounted) {
      _selectOrder(null, updateUrl: true);
      if (result == true) {
        cubit.loadOrders(background: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoyaltyEnabled = context.select<AppConfigCubit, bool>(
      (c) => c.state.businessInfo?.loyaltyGlobalEnabled ?? false,
    );
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 640;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ordersBody = LayoutBuilder(
      builder: (context, constraints) {
        return BlocConsumer<OrdersCubit, OrdersState>(
          listener: (context, state) {
            if (_pendingTargetOrderId != null) {
              _resolveTargetOrder(state.orders, isWide);
            }
          },
          builder: (context, state) {
            final cubit = context.read<OrdersCubit>();

            OrderEntity? currentSelectedOrder;
            if (_pendingTargetOrderId == null) {
              if (state.orders.isNotEmpty && _selectedOrder != null) {
                final index = state.orders.indexWhere(
                  (o) => o.id == _selectedOrder!.id,
                );
                if (index != -1) {
                  currentSelectedOrder = state.orders[index];
                } else {
                  currentSelectedOrder = _selectedOrder;
                }
              } else {
                currentSelectedOrder = _selectedOrder;
              }
            } else {
              currentSelectedOrder = _selectedOrder;
            }

            final displayOrders =
                (currentSelectedOrder != null &&
                        !state.orders.any(
                          (o) => o.id == currentSelectedOrder!.id,
                        ))
                    ? [currentSelectedOrder, ...state.orders]
                    : state.orders;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => cubit.refresh(),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (state.isBackgroundLoading)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(
                        color: AppColors.teal,
                        minHeight: 2,
                      ),
                    ),

                  SliverToBoxAdapter(
                    child: AdminPageHeader(
                      title:
                          widget.customTitle ??
                          (widget.isEmbedded
                              ? 'Historial de Ventas POS'
                              : 'Gestión de Pedidos'),
                      subtitle:
                          widget.isEmbedded
                              ? 'Consulta comprobantes emitidos, audita productos y reimprime tickets'
                              : 'Gestiona los pedidos de tus clientes, su estado y pagos',
                      isDesktop: isWide,
                      actions: [
                        if (widget.onOpenCashShifts != null)
                          OutlinedButton.icon(
                            onPressed: widget.onOpenCashShifts,
                            icon: const Icon(
                              Icons.point_of_sale_rounded,
                              size: 16,
                            ),
                            label: const Text('Turnos de Caja'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  isDark ? Colors.white : AppColors.textPrimary,
                              side: BorderSide(
                                color:
                                    isDark
                                        ? AppColors.darkBorder
                                        : AppColors.border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: OrdersBentoKpiBar(
                        pageOrdersCount: state.orders.length,
                        totalRecords: state.totalRecords,
                        pageTotalAmount: state.totalAmountCurrentPage,
                        pendingCount: state.pendingCountCurrentPage,
                        pendingDebt: state.pendingDebtCurrentPage,
                        isWide: isWide,
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: AdminProToolbar(
                      isDesktop: width >= 1024,
                      isLoading: state.isLoading || state.isBackgroundLoading,
                      searchController: _searchCtrl,
                      searchFocusNode: _searchFocusNode,
                      searchHint: 'Buscar por cliente o ID de pedido...',
                      onSearchChanged: _onSearchChanged,
                      onClearSearch: () {
                        _searchCtrl.clear();
                        cubit.setSearchQuery('');
                      },
                      filterGroups: [
                        AdminFilterGroup<String>(
                          title: 'Estado',
                          icon: Icons.filter_list_rounded,
                          selected: state.statusFilter,
                          defaultValue: 'ALL',
                          displayType: AdminFilterDisplayType.chips,
                          onSelected: cubit.setStatusFilter,
                          options: const [
                            AdminFilterOption(
                              value: 'ALL',
                              label: 'Todos',
                              icon: Icons.list_alt_rounded,
                            ),
                            AdminFilterOption(
                              value: 'PENDING',
                              label: 'Pendientes',
                              icon: Icons.hourglass_top_rounded,
                              color: AppColors.warningDark,
                            ),
                            AdminFilterOption(
                              value: 'COMPLETED',
                              label: 'Completados',
                              icon: Icons.check_circle_rounded,
                              color: AppColors.tealDark,
                            ),
                            AdminFilterOption(
                              value: 'CANCELLED',
                              label: 'Cancelados',
                              icon: Icons.cancel_rounded,
                              color: AppColors.danger,
                            ),
                            AdminFilterOption(
                              value: 'RETURNED',
                              label: 'Devueltos',
                              icon: Icons.assignment_return_rounded,
                              color: Colors.purple,
                            ),
                          ],
                        ),
                        AdminFilterGroup<String>(
                          title: 'Cobros',
                          icon: Icons.payments_outlined,
                          selected: state.paymentStatusFilter,
                          defaultValue: 'ALL',
                          displayType: AdminFilterDisplayType.chips,
                          onSelected: cubit.setPaymentStatusFilter,
                          options: const [
                            AdminFilterOption(value: 'ALL', label: 'Todos'),
                            AdminFilterOption(
                              value: 'CREDIT',
                              label: 'A crédito',
                              color: AppColors.warningDark,
                            ),
                            AdminFilterOption(
                              value: 'PAID',
                              label: 'Pagados',
                              color: AppColors.tealDark,
                            ),
                            AdminFilterOption(
                              value: 'PENDING',
                              label: 'Por cobrar',
                            ),
                            AdminFilterOption(
                              value: 'PARTIAL',
                              label: 'Parciales',
                            ),
                          ],
                        ),
                        AdminFilterGroup<String>(
                          title: 'Almacén',
                          icon: Icons.storefront_rounded,
                          selected: state.warehouseFilter,
                          defaultValue: 'Todos',
                          onSelected: cubit.setWarehouseFilter,
                          options: [
                            for (final w in state.availableWarehouses)
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
                              state.startDate != null && state.endDate != null
                                  ? DateTimeRange(
                                    start: state.startDate!,
                                    end: state.endDate!,
                                  )
                                  : null,
                          onDateRangeSelected: (picked) {
                            cubit.setDateRange(picked.start, picked.end);
                          },
                          onClear: () {
                            cubit.setDateRange(null, null);
                          },
                        ),
                      ],
                      activeFiltersCount:
                          (state.statusFilter != 'ALL' ? 1 : 0) +
                          (state.paymentStatusFilter != 'ALL' ? 1 : 0) +
                          (state.warehouseFilter != 'Todos' &&
                                  state.warehouseFilter != 'TODOS'
                              ? 1
                              : 0) +
                          (state.startDate != null ? 1 : 0),
                      onClearFilters: () {
                        cubit.setStatusFilter('ALL');
                        cubit.setPaymentStatusFilter('ALL');
                        cubit.setWarehouseFilter('Todos');
                        cubit.setDateRange(null, null);
                      },
                      viewToggleConfig: AdminProViewToggleConfig(
                        isTableView: _isTableView,
                        onToggleTableView:
                            (val) => setState(() => _isTableView = val),
                      ),
                      onRefresh: () => cubit.refresh(),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    sliver: OrdersSliverList(
                      state: state,
                      cubit: cubit,
                      isWide: isWide,
                      isTableView: _isTableView,
                      isLoyaltyEnabled: isLoyaltyEnabled,
                      selectedOrder: currentSelectedOrder,
                      displayOrders: displayOrders,
                      onSelectOrder: (o) => _showOrderDetails(o, isWide),
                      onPrintTicket: _printOrderTicket,
                      onUpdateStatus: _updateOrderStatus,
                    ),
                  ),

                  OrdersPaginationBar(
                    state: state,
                    cubit: cubit,
                    scrollController: _scrollController,
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    return Focus(
      focusNode: _screenFocusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child:
          widget.isEmbedded
              ? Material(
                color:
                    isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
                child: ordersBody,
              )
              : AdminLayout(
                title: widget.customTitle ?? 'Gestión de Pedidos',
                body: ordersBody,
              ),
    );
  }
}
