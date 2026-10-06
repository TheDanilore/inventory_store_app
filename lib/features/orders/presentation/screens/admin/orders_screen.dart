import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_state.dart';

import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/admin_order_card.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_detail_sheet.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_confirm_dialog.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/payment_method_sheet.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/orders_table_view.dart';

class OrdersScreen extends StatefulWidget {
  final String? customTitle;
  final String? targetOrderId;

  const OrdersScreen({super.key, this.customTitle, this.targetOrderId});

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
  bool _isTableView = true; // Por defecto en Desktop: Tabla Pro 100%

  @override
  void initState() {
    super.initState();
    _pendingTargetOrderId = widget.targetOrderId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _screenFocusNode.requestFocus();
      final cubit = context.read<OrdersCubit>();
      if (cubit.state.orders.isEmpty) {
        cubit.loadOrders(reset: true);
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
      final isWide = MediaQuery.sizeOf(context).width >= 800;
      _resolveTargetOrder(cubit.state.orders, isWide);
    }
  }

  void _selectOrder(OrderEntity? order, {bool updateUrl = true}) {
    setState(() {
      _selectedOrder = order;
    });

    if (updateUrl && mounted) {
      final isWide = MediaQuery.sizeOf(context).width >= 800;
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
      final res = await sl<OrdersRepository>().getOrderById(targetId);
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo de texto, bloquear atajos globales
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final isControlOrMeta = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final key = event.logicalKey;

    // Atajo [/] o [Ctrl + K] -> Enfocar buscador
    if ((isControlOrMeta && key == LogicalKeyboardKey.keyK) ||
        key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // Atajo [Escape] -> Cerrar panel lateral o limpiar búsqueda
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

    // Atajo [P] o [Ctrl + P] -> Imprimir ticket del pedido activo
    if (key == LogicalKeyboardKey.keyP || (isControlOrMeta && key == LogicalKeyboardKey.keyP)) {
      if (_selectedOrder != null) {
        _printOrderTicket(_selectedOrder!);
        return KeyEventResult.handled;
      }
    }

    // Atajo [R] -> Recargar pedidos
    if (key == LogicalKeyboardKey.keyR) {
      context.read<OrdersCubit>().loadOrders(reset: true);
      AppSnackbar.show(
        context,
        message: 'Actualizando pedidos...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    // Atajo [V] -> Alternar Vista (Tabla vs Cards)
    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    // Atajos [1..5] -> Filtros de estado
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

    // Navegación con flechas [↑ / ↓] y [Enter] entre pedidos
    final cubit = context.read<OrdersCubit>();
    final orders = cubit.state.orders;
    if (orders.isNotEmpty) {
      final currentIndex = _selectedOrder != null
          ? orders.indexWhere((o) => o.id == _selectedOrder!.id)
          : -1;

      if (key == LogicalKeyboardKey.arrowDown) {
        final nextIndex = currentIndex == -1 ? 0 : (currentIndex + 1).clamp(0, orders.length - 1);
        _selectOrder(orders[nextIndex], updateUrl: true);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        final prevIndex = currentIndex == -1 ? 0 : (currentIndex - 1).clamp(0, orders.length - 1);
        _selectOrder(orders[prevIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        final order = _selectedOrder ?? orders.first;
        final isWide = MediaQuery.sizeOf(context).width >= 800;
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
      final config = context.read<AppConfigCubit>();
      await context.read<OrdersCubit>().generatePdfTicket(
        order,
        businessName: config.businessName,
        taxId: config.businessTaxId,
        address: config.businessAddress,
        phone: config.businessPhone,
      );
    } catch (e) {
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
      final success =
          await context.read<OrdersCubit>().updateOrderStatus(order, newStatus);
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
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al actualizar: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  bool _isSideSheetOpen = false;

  Future<void> _openDesktopDetailSheet(OrderEntity order) async {
    if (!mounted || _isSideSheetOpen) return;
    _isSideSheetOpen = true;
    _selectOrder(order, updateUrl: true);

    final cubit = context.read<OrdersCubit>();
    final configCubit = context.read<AppConfigCubit>();

    await showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Cerrar detalle',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final drawerWidth = screenWidth >= 1440 ? 640.0 : 580.0;

        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: drawerWidth,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 24,
                    offset: Offset(-4, 0),
                  ),
                ],
              ),
              child: MultiBlocProvider(
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
                      cubit.loadOrders(background: true);
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: child,
        );
      },
    );

    _isSideSheetOpen = false;
    if (mounted) {
      _selectOrder(null, updateUrl: true);
    }
  }

  Future<void> _showOrderDetails(OrderEntity order, bool isWide) async {
    if (isWide) {
      await _openDesktopDetailSheet(order);
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: OrderDetailSheet(
              order: order,
              onOrderUpdated: (updated) {
                if (mounted) {
                  context.read<OrdersCubit>().updateOrderInList(updated);
                }
              },
            ),
          ),
    );

    if (result == true && mounted) {
      context.read<OrdersCubit>().loadOrders(background: true);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Borradores';
      case 'COMPLETED':
        return 'Completados';
      case 'CANCELLED':
        return 'Cancelados';
      case 'RETURNED':
        return 'Devueltos';
      default:
        return 'Todos';
    }
  }

  String _getPaymentStatusLabel(String status) {
    switch (status) {
      case 'CREDIT':
        return 'A Crédito';
      case 'PAID':
        return 'Pagados';
      case 'PENDING':
        return 'Por cobrar';
      case 'PARTIAL':
        return 'Parciales';
      default:
        return 'Cobros: Todos';
    }
  }

  Widget _buildStatusDropdown(
    BuildContext context,
    OrdersState state,
    OrdersCubit cubit,
  ) {
    final isFiltered = state.statusFilter != 'ALL';

    return PopupMenuButton<String>(
      initialValue: state.statusFilter,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: (val) => cubit.setStatusFilter(val),
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: 'ALL',
              child: Row(
                children: [
                  Icon(
                    Icons.list_alt_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text('Todos los estados', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'PENDING',
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Borradores',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warningDark,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'COMPLETED',
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.teal,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Completados',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tealDark,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'CANCELLED',
              child: Row(
                children: [
                  Icon(Icons.cancel_rounded, size: 16, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text(
                    'Cancelados',
                    style: TextStyle(fontSize: 13, color: AppColors.danger),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'RETURNED',
              child: Row(
                children: [
                  Icon(
                    Icons.assignment_return_rounded,
                    size: 16,
                    color: Colors.purple,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Devueltos',
                    style: TextStyle(fontSize: 13, color: Colors.purple),
                  ),
                ],
              ),
            ),
          ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              isFiltered
                  ? AppColors.tealLight.withValues(alpha: 0.7)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFiltered ? AppColors.teal : const Color(0xFFCBD5E1),
            width: isFiltered ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: 15,
              color: isFiltered ? AppColors.teal : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Estado: ${_getStatusLabel(state.statusFilter)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isFiltered ? FontWeight.w800 : FontWeight.w600,
                color: isFiltered ? AppColors.tealDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isFiltered ? AppColors.teal : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDropdown(
    BuildContext context,
    OrdersState state,
    OrdersCubit cubit,
  ) {
    final bool isPaymentFiltered = state.paymentStatusFilter != 'ALL';
    final bool isCreditFiltered = state.paymentStatusFilter == 'CREDIT';
    final Color activePaymentColor =
        isCreditFiltered ? AppColors.warning : AppColors.teal;

    return PopupMenuButton<String>(
      initialValue: state.paymentStatusFilter,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: (val) => cubit.setPaymentStatusFilter(val),
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: 'ALL',
              child: Row(
                children: [
                  Icon(
                    Icons.payments_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 8),
                  Text('Cobros: Todos', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'CREDIT',
              child: Row(
                children: [
                  Icon(
                    Icons.credit_card_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Solo a crédito',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'PAID',
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.teal,
                  ),
                  SizedBox(width: 8),
                  Text('Pagados', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'PENDING',
              child: Row(
                children: [
                  Icon(
                    Icons.pending_actions_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 8),
                  Text('Por cobrar', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'PARTIAL',
              child: Row(
                children: [
                  Icon(
                    Icons.pie_chart_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text('Parciales', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              isPaymentFiltered
                  ? activePaymentColor.withValues(alpha: 0.12)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isPaymentFiltered
                    ? activePaymentColor
                    : const Color(0xFFCBD5E1),
            width: isPaymentFiltered ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCreditFiltered
                  ? Icons.credit_card_rounded
                  : Icons.payments_rounded,
              size: 15,
              color:
                  isPaymentFiltered
                      ? activePaymentColor
                      : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _getPaymentStatusLabel(state.paymentStatusFilter),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight:
                    isPaymentFiltered ? FontWeight.w800 : FontWeight.w600,
                color:
                    isPaymentFiltered
                        ? activePaymentColor
                        : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color:
                  isPaymentFiltered
                      ? activePaymentColor
                      : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    final isLoyaltyEnabled = context.select<AppConfigCubit, bool>(
      (c) => c.state.businessInfo?.loyaltyGlobalEnabled ?? false,
    );
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 800;

    return Focus(
      focusNode: _screenFocusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: AdminLayout(
        title: widget.customTitle ?? 'Gestión de Pedidos',
        showBackButton: true,
        actions: isWide
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualizar pedidos',
                  onPressed: () {
                    context.read<OrdersCubit>().loadOrders(reset: true);
                  },
                ),
              ],
        body: LayoutBuilder(
          builder: (context, constraints) {
            return BlocConsumer<OrdersCubit, OrdersState>(
              listener: (context, state) {
                if (_pendingTargetOrderId != null) {
                  _resolveTargetOrder(state.orders, isWide);
                }
              },
              buildWhen:
                  (p, c) =>
                      p.orders != c.orders ||
                      p.isLoading != c.isLoading ||
                      p.errorMessage != c.errorMessage ||
                      p.isBackgroundLoading != c.isBackgroundLoading ||
                      p.statusFilter != c.statusFilter ||
                      p.paymentStatusFilter != c.paymentStatusFilter ||
                      p.startDate != c.startDate ||
                      p.endDate != c.endDate ||
                      p.searchQuery != c.searchQuery ||
                      p.customerIdFilter != c.customerIdFilter ||
                      p.currentPage != c.currentPage ||
                      p.totalPages != c.totalPages,
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

                final displayOrders = (currentSelectedOrder != null &&
                        !state.orders.any((o) => o.id == currentSelectedOrder!.id))
                    ? [currentSelectedOrder, ...state.orders]
                    : state.orders;

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => cubit.loadOrders(reset: true),
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

                      // --- 1. BENTO KPI BAR ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _OrdersBentoKpiBar(
                                  pageOrdersCount: state.orders.length,
                                  totalRecords: state.totalRecords,
                                  pageTotalAmount: state.totalAmountCurrentPage,
                                  pendingCount: state.pendingCountCurrentPage,
                                  pendingDebt: state.pendingDebtCurrentPage,
                                  isWide: isWide,
                                ),
                              ),
                            ),

                            // --- 2. TOOLBAR PRO UNIFICADO (Buscador, Filtros, Vista, Refresh) ---
                            SliverToBoxAdapter(
                              child: AdminProToolbar(
                                isDesktop: isWide,
                                searchController: _searchCtrl,
                                searchFocusNode: _searchFocusNode,
                                searchHint:
                                    'Buscar por cliente o ID de pedido...',
                                onSearchChanged: _onSearchChanged,
                                onClearSearch: () {
                                  _searchCtrl.clear();
                                  cubit.setSearchQuery('');
                                },
                                filterWidgets: [
                                  _buildStatusDropdown(context, state, cubit),
                                  _buildPaymentDropdown(context, state, cubit),
                                  DateFilterCalendar(
                                    height: 40,
                                    borderRadius: BorderRadius.circular(10),
                                    dateRange:
                                        state.startDate != null &&
                                                state.endDate != null
                                            ? DateTimeRange(
                                              start: state.startDate!,
                                              end: state.endDate!,
                                            )
                                            : null,
                                    onDateRangeSelected: (picked) {
                                      cubit.setDateRange(
                                        picked.start,
                                        picked.end,
                                      );
                                    },
                                    onClear: () {
                                      cubit.setDateRange(null, null);
                                    },
                                  ),
                                ],
                                viewToggleConfig: AdminProViewToggleConfig(
                                  isTableView: _isTableView,
                                  onToggleTableView:
                                      (val) =>
                                          setState(() => _isTableView = val),
                                ),
                                onRefresh: () => cubit.loadOrders(reset: true),
                              ),
                            ),

                            // --- 2.5 ENCABEZADO DE NAVEGACIÓN Y CONTADOR (ESTILO COMPRAS / PEDIDOS) ---
                            if (!state.isLoading && displayOrders.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                                  child: Row(
                                    children: [
                                      Text(
                                        '${displayOrders.length} ${displayOrders.length == 1 ? "pedido" : "pedidos"} en esta página',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (isWide) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: const Color(0xFFE2E8F0)),
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
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          'Pág. ${state.currentPage + 1} / ${state.totalPages}',
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

                            // --- 3. LISTADO O TABLA PRO ---
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                              sliver: _buildListOrTableSliver(
                                state,
                                cubit,
                                isWide,
                                isLoyaltyEnabled,
                                currentSelectedOrder,
                                displayOrders,
                              ),
                            ),

                            // --- 4. PAGINACIÓN FLUIDA AL PIE DEL SCROLL ---
                            _buildPaginationSliver(context, state, cubit),
                          ],
                        ),
                      );
              },
            );
          },
        ),
      ),
    );
  }

  // --- RENDERIZADO CONDICIONAL: TABLA PRO vs CARDS CLÁSICAS ---
  Widget _buildListOrTableSliver(
    OrdersState state,
    OrdersCubit cubit,
    bool isWide,
    bool isLoyaltyEnabled,
    OrderEntity? selectedOrder,
    List<OrderEntity> displayOrders,
  ) {
    final pageItems = displayOrders;

    if (state.isLoading) {
      if (_isTableView && isWide) {
        return const SliverToBoxAdapter(
          child: AppTableShimmer(),
        );
      }
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AppShimmer(height: 120),
          ),
          childCount: 5,
        ),
      );
    }

    if (state.errorMessage.isNotEmpty && pageItems.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.error_outline_rounded,
          color: AppColors.error,
          title: 'Ocurrió un error',
          message: state.errorMessage,
          action: FilledButton.icon(
            onPressed: () => cubit.loadOrders(reset: true),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
          ),
        ),
      );
    }

    if (pageItems.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No se encontraron pedidos.',
          message: 'Intenta cambiar los filtros o la búsqueda.',
        ),
      );
    }

    // SI ESTÁ EN MODO TABLA EN DESKTOP
    if (isWide && _isTableView) {
      return SliverToBoxAdapter(
        child: OrdersTableView(
          orders: pageItems,
          selectedOrder: selectedOrder,
          onSelectOrder: (order) => _showOrderDetails(order, isWide),
          onPrintTicket: _printOrderTicket,
          onUpdateStatus: _updateOrderStatus,
          isProcessing: state.isBackgroundLoading,
        ),
      );
    }

    // MODO TARJETAS (RESPONSIVE GRID EN DESKTOP, LIST EN MÓVIL)
    if (isWide) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 440,
          mainAxisExtent: 220,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final order = pageItems[index];
          final isSelected = selectedOrder?.id == order.id;

          return AdminOrderCard(
            order: order,
            isProcessing:
                cubit.state.isOrderProcessing(order.id) ||
                state.isBackgroundLoading,
            isGeneratingPDF: state.isGeneratingPDF(order.id),
            isSelected: isSelected,
            isLoyaltyEnabled: isLoyaltyEnabled,
            onTap: () => _showOrderDetails(order, isWide),
            onUpdateStatus: (o, s) => _updateOrderStatus(o, s),
            onPrint: () => _printOrderTicket(order),
          );
        }, childCount: pageItems.length),
      );
    }

    final itemCount = pageItems.length;

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < pageItems.length) {
          final order = pageItems[index];
          final isSelected = isWide && selectedOrder?.id == order.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminOrderCard(
              order: order,
              isProcessing:
                  cubit.state.isOrderProcessing(order.id) ||
                  state.isBackgroundLoading,
              isGeneratingPDF: state.isGeneratingPDF(order.id),
              isSelected: isSelected,
              isLoyaltyEnabled: isLoyaltyEnabled,
              onTap: () => _showOrderDetails(order, isWide),
              onUpdateStatus: (o, s) => _updateOrderStatus(o, s),
              onPrint: () => _printOrderTicket(order),
            ),
          );
        }

        return const SizedBox.shrink();
      }, childCount: itemCount),
    );
  }

  Widget _buildPaginationSliver(
    BuildContext context,
    OrdersState state,
    OrdersCubit cubit,
  ) {
    if (state.totalPages <= 1 ||
        state.isLoading ||
        state.errorMessage.isNotEmpty ||
        state.orders.isEmpty) {
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
            currentPage: state.currentPage,
            totalPages: state.totalPages,
            onPageChanged: (page) {
              cubit.goToPage(page);
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            totalItems: state.totalRecords,
            itemsPerPage: OrdersState.pageSize,
            itemName: 'pedidos',
          ),
        ),
      ),
    );
  }
}

class _OrdersBentoKpiBar extends StatelessWidget {
  final int pageOrdersCount;
  final int totalRecords;
  final double pageTotalAmount;
  final int pendingCount;
  final double pendingDebt;
  final bool isWide;

  const _OrdersBentoKpiBar({
    required this.pageOrdersCount,
    required this.totalRecords,
    required this.pageTotalAmount,
    required this.pendingCount,
    required this.pendingDebt,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _BentoOrderKpiCard(
        title: 'Total Pedidos',
        value: '$totalRecords',
        subtitle: 'Pedidos registrados',
        icon: Icons.receipt_long_rounded,
        gradientColors: const [Colors.white, Color(0xFFF0FDFA)],
        iconGradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
        borderColor: const Color(0xFF99F6E4),
        accentColor: const Color(0xFF0D9488),
        glowColor: const Color(0x2E0D9488),
      ),
      _BentoOrderKpiCard(
        title: 'Total Facturado',
        value: 'S/ ${pageTotalAmount.toStringAsFixed(2)}',
        subtitle: 'Total facturado en pág.',
        icon: Icons.payments_rounded,
        gradientColors: const [Colors.white, Color(0xFFECFDF5)],
        iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
        borderColor: const Color(0xFFA7F3D0),
        accentColor: const Color(0xFF059669),
        glowColor: const Color(0x2E10B981),
      ),
      _BentoOrderKpiCard(
        title: pendingDebt > 0 ? 'Por Cobrar' : 'Pedidos Pendientes',
        value: pendingDebt > 0
            ? 'S/ ${pendingDebt.toStringAsFixed(2)}'
            : '$pendingCount',
        subtitle: pendingDebt > 0
            ? 'Créditos pendientes'
            : 'Borradores por completar',
        icon: pendingDebt > 0
            ? Icons.credit_card_rounded
            : Icons.pending_actions_rounded,
        gradientColors: const [Colors.white, Color(0xFFFFFBEB)],
        iconGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
        borderColor: const Color(0xFFFDE68A),
        accentColor: const Color(0xFFD97706),
        glowColor: const Color(0x2EF59E0B),
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 14),
          Expanded(child: cards[1]),
          const SizedBox(width: 14),
          Expanded(child: cards[2]),
        ],
      );
    }

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) => SizedBox(width: 240, child: cards[index]),
      ),
    );
  }
}

class _BentoOrderKpiCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final List<Color> iconGradient;
  final Color borderColor;
  final Color accentColor;
  final Color glowColor;

  const _BentoOrderKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.iconGradient,
    required this.borderColor,
    required this.accentColor,
    required this.glowColor,
  });

  @override
  State<_BentoOrderKpiCard> createState() => _BentoOrderKpiCardState();
}

class _BentoOrderKpiCardState extends State<_BentoOrderKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? widget.accentColor.withValues(alpha: 0.6)
                : widget.borderColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered ? widget.glowColor : const Color(0x060F172A),
              blurRadius: _isHovered ? 14 : 6,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.iconGradient,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: widget.glowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: widget.accentColor,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
