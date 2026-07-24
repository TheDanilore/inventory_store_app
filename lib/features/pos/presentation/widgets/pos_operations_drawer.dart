import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_state.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';

class PosOperationsDrawer extends StatefulWidget {
  const PosOperationsDrawer({super.key});

  @override
  State<PosOperationsDrawer> createState() => _PosOperationsDrawerState();
}

class _PosOperationsDrawerState extends State<PosOperationsDrawer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _recentOrders = [];
  bool _isLoadingOrders = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecentOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final res =
          await Supabase.instance.client
              .from('orders')
              .select('id, total_amount, created_at, client_name, status')
              .order('created_at', ascending: false)
              .limit(10);

      if (mounted) {
        setState(() {
          _recentOrders = List<Map<String, dynamic>>.from(res);
          _isLoadingOrders = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  Future<void> _reimprimirTicket(String orderId) async {
    try {
      final orderRes =
          await Supabase.instance.client
              .from('orders')
              .select('*, order_items(*)')
              .eq('id', orderId)
              .single();

      final orderModel = OrderModel.fromJson(orderRes);
      final itemsList =
          (orderRes['order_items'] as List<dynamic>?)
              ?.map((item) => OrderItemModel.fromJson(item))
              .toList() ??
          [];

      await OrderPdfGenerator.printTicket(
        orderModel,
        items: itemsList,
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
                children: [
                  _buildRecentSalesTab(),
                  _buildDraftTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSalesTab() {
    if (_isLoadingOrders) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_recentOrders.isEmpty) {
      return const Center(
        child: Text(
          'No hay ventas recientes registradas.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _recentOrders.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final order = _recentOrders[index];
        final clientName = order['client_name'] ?? 'Cliente General';
        final total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = order['created_at'] != null
            ? order['created_at'].toString().split('T').first
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
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.print_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
            tooltip: 'Reimprimir Ticket PDF',
            onPressed: () => _reimprimirTicket(order['id']),
          ),
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
