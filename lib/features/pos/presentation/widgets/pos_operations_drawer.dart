import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';

class PosOperationsDrawer extends StatefulWidget {
  const PosOperationsDrawer({super.key});

  @override
  State<PosOperationsDrawer> createState() => _PosOperationsDrawerState();
}

class _PosOperationsDrawerState extends State<PosOperationsDrawer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<PosCubit>().fetchRecentOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reimprimirTicket(String orderId) async {
    try {
      final posCubit = context.read<PosCubit>();
      final config = context.read<AppConfigCubit>();

      final detailsRes = await posCubit.fetchOrderDetailsForTicket(orderId);

      await detailsRes.fold(
        (failure) async {
          if (mounted) {
            AppSnackbar.show(
              context,
              message: 'Error al cargar comprobante: ${failure.message}',
              type: SnackbarType.error,
            );
          }
        },
        (result) async {
          await OrderPdfGenerator.printTicket(
            result.order,
            items: result.items,
            businessName: config.businessName,
            taxId: config.businessTaxId,
            address: config.businessAddress,
            phone: config.businessPhone,
          );
        },
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error inesperado al generar ticket: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 380,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              color: AppColors.background,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Operaciones POS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.receipt_long_rounded, size: 18),
                        text: 'Ventas Recientes',
                      ),
                      Tab(
                        icon: Icon(Icons.bookmark_outline_rounded, size: 18),
                        text: 'Borrador',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildRecentSalesTab(), _buildDraftTab(context)],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Acceso Rápido',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/admin/all-cash-shifts');
                          },
                          icon: const Icon(
                            Icons.point_of_sale_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Turnos de Caja',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusSm,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            context.go('/admin');
                          },
                          icon: const Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                          ),
                          label: const Text(
                            'Inventario',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusSm,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSalesTab() {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        if (state.isLoadingRecentOrders) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (state.recentOrdersError.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar las ventas:\n${state.recentOrdersError}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed:
                        () => context.read<PosCubit>().fetchRecentOrders(
                          forceRefresh: true,
                        ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.recentOrders.isEmpty) {
          return const Center(
            child: Text(
              'No hay ventas recientes registradas.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: state.recentOrders.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final order = state.recentOrders[index];
            final clientName =
                order.customerName.isNotEmpty
                    ? order.customerName
                    : 'Cliente General';
            final total = order.totalAmount;
            final dateStr =
                order.createdAt != null
                    ? '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year}'
                    : '';

            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              title: Text(
                clientName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'S/ ${total.toStringAsFixed(2)} • $dateStr',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.print_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                tooltip: 'Reimprimir Ticket PDF',
                onPressed: () => _reimprimirTicket(order.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDraftTab(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        final hasItems = cartState.items.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      size: 36,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasItems
                          ? '${cartState.items.length} producto(s) en la venta actual'
                          : 'El carrito está vacío',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: S/ ${cartState.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed:
                    hasItems
                        ? () {
                          context.read<CartCubit>().clearCart();
                          Navigator.pop(context);
                          AppSnackbar.show(
                            context,
                            message: 'Carrito vaciado correctamente.',
                            type: SnackbarType.info,
                          );
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Vaciar Carrito Actual'),
              ),
            ],
          ),
        );
      },
    );
  }
}
