import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders_state.dart';

import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/admin_order_card.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_detail_sheet.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_confirm_dialog.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/payment_method_sheet.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/orders_filters_header_delegate.dart';

class OrdersScreen extends StatefulWidget {
  final String? customTitle;

  const OrdersScreen({super.key, this.customTitle});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  OrderEntity? _selectedOrder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersCubit>().loadOrders(reset: true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<OrdersCubit>().setSearchQuery(value);
      }
    });
  }

  Future<void> _printOrderTicket(OrderEntity order) async {
    try {
      await context.read<OrdersCubit>().generatePdfTicket(order);
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
      setState(() {
        _selectedOrder = order;
      });
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
            child: OrderDetailSheet(order: order),
          ),
    );

    if (result == true && mounted) {
      context.read<OrdersCubit>().loadOrders(background: true);
    }
  }

  void _onOrderEmbeddedPop(bool wasModified) {
    if (wasModified && mounted) {
      context.read<OrdersCubit>().loadOrders(background: true);
    }
    setState(() {
      _selectedOrder = null;
    });
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
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.grey.shade300,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>();
    final isLoyaltyEnabled = config.loyaltyGlobalEnabled;

    return AdminLayout(
      title: widget.customTitle ?? 'Gestión de Pedidos',
      showBackButton: true,
      actions:
          const [], // Here we can inject appbar actions natively if needed in the future
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;

          return BlocBuilder<OrdersCubit, OrdersState>(
            builder: (context, state) {
              final cubit = context.read<OrdersCubit>();
              final content = CustomScrollView(
                slivers: [
                  if (state.isBackgroundLoading)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(
                        color: AppColors.teal,
                        minHeight: 2,
                      ),
                    ),
                  SliverPersistentHeader(
                    pinned: true,
                    floating: true,
                    delegate: OrdersFiltersHeaderDelegate(
                      searchCtrl: _searchCtrl,
                      onSearchChanged: _onSearchChanged,
                      cubit: cubit,
                      state: state,
                      buildFilterChip: _buildFilterChip,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: _buildListSliver(
                      state,
                      cubit,
                      isWide,
                      isLoyaltyEnabled,
                    ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      flex: 45,
                      child: Container(
                        color: Colors.grey.shade50,
                        child: content,
                      ),
                    ),
                    Container(width: 1, color: Colors.grey.shade200),
                    Expanded(
                      flex: 55,
                      child:
                          _selectedOrder == null
                              ? const AppEmptyState(
                                icon: Icons.receipt_long_rounded,
                                title: 'Ningún pedido seleccionado',
                                message:
                                    'Selecciona un pedido de la lista para ver o editar sus detalles.',
                              )
                              : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: OrderDetailSheet(
                                  key: ValueKey(_selectedOrder!.id),
                                  order: _selectedOrder!,
                                  isEmbedded: true,
                                  onPop: _onOrderEmbeddedPop,
                                ),
                              ),
                    ),
                  ],
                );
              }

              return content;
            },
          );
        },
      ),
    );
  }

  Widget _buildListSliver(
    OrdersState state,
    OrdersCubit cubit,
    bool isWide,
    bool isLoyaltyEnabled,
  ) {
    final totalPages = state.totalPages;
    final pageItems = state.orders;

    if (state.isLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AppShimmer(height: 140),
          ),
          childCount: 5,
        ),
      );
    }

    if (state.errorMessage.isNotEmpty) {
      return SliverFillRemaining(
        child: AppEmptyState(
          icon: Icons.error_outline_rounded,
          color: Colors.red,
          title: 'Ocurrió un error',
          message: state.errorMessage,
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

    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
          child: Row(
            children: [
              Text(
                'Mostrando resultados',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Pág. ${state.currentPage + 1} / $totalPages',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...pageItems.map((order) {
          final isSelected = isWide && _selectedOrder?.id == order.id;
          return AdminOrderCard(
            order: order,
            isProcessing: cubit.state.isOrderProcessing(order.id),
            isGeneratingPDF: state.isGeneratingPDF(order.id),
            isSelected: isSelected,
            isLoyaltyEnabled: isLoyaltyEnabled,
            onTap: () => _showOrderDetails(order, isWide),
            onUpdateStatus: (o, s) => _updateOrderStatus(o, s),
            onPrint: () => _printOrderTicket(order),
          );
        }),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: AdminPageBlocks(
              currentPage: state.currentPage,
              totalPages: totalPages,
              onPageChanged: cubit.goToPage,
            ),
          ),
      ]),
    );
  }
}
