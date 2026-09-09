import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
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
                        child: Tooltip(
                          message:
                              kIsWeb
                                  ? 'Abrir Inventario en nueva pestaña'
                                  : 'Ir a Inventario',
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              if (kIsWeb) {
                                final uri = Uri.base.replace(
                                  path: '/admin/inventory',
                                  queryParameters: {},
                                );
                                await launchUrl(
                                  uri,
                                  webOnlyWindowName: '_blank',
                                );
                              } else {
                                context.push('/admin/inventory');
                              }
                            },
                            icon: Icon(
                              kIsWeb
                                  ? Icons.open_in_new_rounded
                                  : Icons.inventory_2_outlined,
                              size: 16,
                            ),
                            label: Text(
                              kIsWeb ? 'Inventario ↗' : 'Inventario',
                              style: const TextStyle(fontSize: 12),
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

        if (!hasItems) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.remove_shopping_cart_outlined,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'La caja está vacía',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Los productos que agregues desde el catálogo se registrarán aquí para la venta en curso.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.storefront_rounded, size: 18),
                    label: const Text('Explorar Catálogo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 32,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${cartState.items.length} producto(s) en la venta actual',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: S/ ${cartState.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  context.read<CartCubit>().clearCart();
                  context.read<PosCubit>().clearAllBatchOverrides();
                  Navigator.pop(context);
                  AppSnackbar.show(
                    context,
                    message: 'Carrito vaciado correctamente.',
                    type: SnackbarType.info,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text(
                  'Vaciar Carrito Actual',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
