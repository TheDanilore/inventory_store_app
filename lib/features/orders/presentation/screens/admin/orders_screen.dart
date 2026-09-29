import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
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
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/orders_filters_header_delegate.dart';
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
      _selectOrder(orders[foundIndex], updateUrl: isWide);
      if (!isWide) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedOrder != null) {
            _showOrderDetails(_selectedOrder!, false);
          }
        });
      }
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
          _selectOrder(order, updateUrl: isWide);
          if (!isWide) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedOrder != null) {
                _showOrderDetails(_selectedOrder!, false);
              }
            });
          }
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
    _debounce?.cancel();
    super.dispose();
  }

  // --- REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) ---
  bool get _isInputFieldFocused {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    return primaryFocus.context?.widget is EditableText;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo de texto, bloquear atajos globales
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
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
      context.read<OrdersCubit>().setStatusFilter('DRAFT');
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

    // Navegación con flechas [↑ / ↓] entre pedidos
    final cubit = context.read<OrdersCubit>();
    final orders = cubit.state.orders;
    if (orders.isNotEmpty) {
      final currentIndex = _selectedOrder != null
          ? orders.indexWhere((o) => o.id == _selectedOrder!.id)
          : -1;

      if (key == LogicalKeyboardKey.arrowDown) {
        final nextIndex = (currentIndex + 1).clamp(0, orders.length - 1);
        _selectOrder(orders[nextIndex], updateUrl: true);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, orders.length - 1);
        _selectOrder(orders[prevIndex], updateUrl: true);
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
      await context.read<OrdersCubit>().updateOrderStatus(order, newStatus);
      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              newStatus == 'COMPLETED'
                  ? 'Pedido completado correctamente'
                  : 'Estado actualizado correctamente',
          type: SnackbarType.success,
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

  Future<void> _showOrderDetails(OrderEntity order, bool isWide) async {
    if (isWide) {
      _selectOrder(order, updateUrl: true);
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

  Widget _buildDrawerStatusBadge(String status) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
        bg = AppColors.successLight;
        text = AppColors.successDark;
        label = 'Completado';
        icon = Icons.check_circle_rounded;
        break;
      case 'DRAFT':
        bg = AppColors.warningLight;
        text = AppColors.warningDark;
        label = 'Borrador';
        icon = Icons.hourglass_top_rounded;
        break;
      case 'CANCELLED':
        bg = AppColors.dangerLight;
        text = AppColors.danger;
        label = 'Cancelado';
        icon = Icons.cancel_rounded;
        break;
      case 'RETURNED':
        bg = Colors.purple.shade50;
        text = Colors.purple.shade700;
        label = 'Devuelto';
        icon = Icons.assignment_return_rounded;
        break;
      default:
        bg = Colors.grey.shade100;
        text = AppColors.textSecondary;
        label = status;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  void _onOrderEmbeddedPop(bool wasModified) {
    if (wasModified && mounted) {
      context.read<OrdersCubit>().loadOrders(background: true);
    }
    _selectOrder(null, updateUrl: true);
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      showCheckmark: false,
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      context.read<OrdersCubit>();
      return _buildContent(context);
    } catch (_) {
      return BlocProvider(
        create: (_) => sl<OrdersCubit>()..loadOrders(reset: true),
        child: Builder(builder: (context) => _buildContent(context)),
      );
    }
  }

  Widget _buildContent(BuildContext context) {
    final isLoyaltyEnabled = context.select<AppConfigCubit, bool>(
      (c) => c.state.businessInfo?.loyaltyGlobalEnabled ?? false,
    );
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 800;

    return Focus(
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: AdminLayout(
        title: widget.customTitle ?? 'Gestión de Pedidos',
        showBackButton: true,
        actions: isWide
            ? [
                // Selector de modo Vista: Tabla vs Tarjetas
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Vista Tabla Pro [V]',
                        icon: Icon(
                          Icons.table_rows_rounded,
                          size: 16,
                          color: _isTableView ? AppColors.tealDark : AppColors.textMuted,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              _isTableView ? AppColors.surface : Colors.transparent,
                          padding: const EdgeInsets.all(6),
                          elevation: _isTableView ? 1 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () => setState(() => _isTableView = true),
                      ),
                      IconButton(
                        tooltip: 'Vista Tarjetas [V]',
                        icon: Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: !_isTableView ? AppColors.tealDark : AppColors.textMuted,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              !_isTableView ? AppColors.surface : Colors.transparent,
                          padding: const EdgeInsets.all(6),
                          elevation: !_isTableView ? 1 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () => setState(() => _isTableView = false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                OutlinedButton.icon(
                  onPressed: () {
                    context.read<OrdersCubit>().loadOrders(reset: true);
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  label: const Text(
                    'Actualizar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ]
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

                final scrollContent = CustomScrollView(
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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _OrdersKpiRibbon(
                          pageOrdersCount: state.orders.length,
                          totalRecords: state.totalRecords,
                          pageTotalAmount: state.totalAmountCurrentPage,
                          pendingCount: state.pendingCountCurrentPage,
                          pendingDebt: state.pendingDebtCurrentPage,
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      floating: true,
                      delegate: OrdersFiltersHeaderDelegate(
                        searchCtrl: _searchCtrl,
                        searchFocusNode: _searchFocusNode,
                        onSearchChanged: _onSearchChanged,
                        cubit: cubit,
                        state: state,
                        buildFilterChip: _buildFilterChip,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: _buildListOrTableSliver(
                        state,
                        cubit,
                        isWide,
                        isLoyaltyEnabled,
                        currentSelectedOrder,
                        displayOrders,
                      ),
                    ),
                  ],
                );

                final mainListContent = Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async => cubit.loadOrders(reset: true),
                        child: scrollContent,
                      ),
                    ),
                    _buildPagination(state, cubit, isWide: isWide),
                  ],
                );

                // --- ESTRATEGIA ADAPTATIVA DESKTOP: TABLA 100% + SLIDE-OVER DRAWER ---
                if (isWide) {
                  final activeOrder = currentSelectedOrder;
                  final drawerWidth = width >= 1440
                      ? 520.0
                      : width >= 1100
                          ? 480.0
                          : (width * 0.48).clamp(380.0, 460.0);

                  return Stack(
                    children: [
                      // Contenido principal de la izquierda
                      Positioned.fill(
                        right: activeOrder != null ? drawerWidth : 0,
                        child: Container(
                          color: AppColors.background,
                          child: mainListContent,
                        ),
                      ),

                      // SLIDE-OVER DRAWER LATERAL (Panel retráctil a la derecha)
                      if (activeOrder != null) ...[
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: drawerWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              border: const Border(
                                left: BorderSide(color: AppColors.border),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(-4, 0),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Cabecera Unificada del Slide-Over Drawer
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 11,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border(
                                      bottom: BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // ID con copia rápida en 1-click
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(
                                            ClipboardData(
                                              text: activeOrder.id,
                                            ),
                                          );
                                          AppSnackbar.show(
                                            context,
                                            message:
                                                'ID copiado al portapapeles',
                                            type: SnackbarType.success,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.receipt_rounded,
                                                size: 13,
                                                color: AppColors.teal,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                '#${activeOrder.id.length >= 8 ? activeOrder.id.substring(0, 8).toUpperCase() : activeOrder.id.toUpperCase()}',
                                                style: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.textPrimary,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.copy_rounded,
                                                size: 11,
                                                color: AppColors.textMuted,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildDrawerStatusBadge(
                                        activeOrder.status,
                                      ),
                                      const Spacer(),
                                      // Botón Imprimir Ticket
                                      IconButton(
                                        icon: const Icon(
                                          Icons.print_rounded,
                                          size: 19,
                                          color: AppColors.textSecondary,
                                        ),
                                        tooltip: 'Imprimir Ticket [P]',
                                        onPressed:
                                            () => _printOrderTicket(
                                              activeOrder,
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Badge de atajo [ESC]
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: const Text(
                                          'ESC',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 20,
                                        ),
                                        tooltip: 'Cerrar panel (Esc)',
                                        onPressed:
                                            () => _selectOrder(
                                              null,
                                              updateUrl: true,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Contenido del detalle con soporte completo
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: OrderDetailSheet(
                                      key: ValueKey(activeOrder.id),
                                      order: activeOrder,
                                      isEmbedded: true,
                                      onPop: _onOrderEmbeddedPop,
                                      onOrderUpdated: (updated) {
                                        if (mounted) {
                                          context
                                              .read<OrdersCubit>()
                                              .updateOrderInList(updated);
                                          _selectOrder(updated, updateUrl: true);
                                          context
                                              .read<OrdersCubit>()
                                              .loadOrders(background: true);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                }

                return mainListContent;
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

    if (state.errorMessage.isNotEmpty) {
      return SliverFillRemaining(
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

    // MODO TARJETAS (MÓVIL O TOGGLE SPLIT)
    final itemCount = 1 + pageItems.length;

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
            child: Row(
              children: [
                Text(
                  '${pageItems.length} pedidos en esta página',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isWide) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
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
          );
        }

        if (index <= pageItems.length) {
          final order = pageItems[index - 1];
          final isSelected = isWide && selectedOrder?.id == order.id;

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
        }

        return const SizedBox.shrink();
      }, childCount: itemCount),
    );
  }

  Widget _buildPagination(
    OrdersState state,
    OrdersCubit cubit, {
    required bool isWide,
  }) {
    if (state.totalPages <= 1 ||
        state.isLoading ||
        state.errorMessage.isNotEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      alignment: Alignment.center,
      child: SafeArea(
        top: false,
        bottom: !isWide,
        child: AdminPageBlocks(
          currentPage: state.currentPage,
          totalPages: state.totalPages,
          onPageChanged: cubit.goToPage,
        ),
      ),
    );
  }
}

class _OrdersKpiRibbon extends StatelessWidget {
  final int pageOrdersCount;
  final int totalRecords;
  final double pageTotalAmount;
  final int pendingCount;
  final double pendingDebt;

  const _OrdersKpiRibbon({
    required this.pageOrdersCount,
    required this.totalRecords,
    required this.pageTotalAmount,
    required this.pendingCount,
    required this.pendingDebt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 16,
                color: AppColors.tealDark,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Pedidos: ',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$pageOrdersCount de $totalRecords',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 18, color: AppColors.border),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.payments_rounded,
                size: 16,
                color: AppColors.successDark,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Total Pág: ',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'S/ ${pageTotalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.successDark,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (pendingDebt > 0) ...[
              const SizedBox(width: 14),
              Container(width: 1, height: 18, color: AppColors.border),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  size: 16,
                  color: AppColors.warningDark,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Por Cobrar: ',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'S/ ${pendingDebt.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.warningDark,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ] else if (pendingCount > 0) ...[
              const SizedBox(width: 14),
              Container(width: 1, height: 18, color: AppColors.border),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pending_actions_rounded,
                  size: 16,
                  color: AppColors.warningDark,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Borradores: ',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$pendingCount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.warningDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
