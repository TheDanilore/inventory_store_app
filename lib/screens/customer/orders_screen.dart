import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/order_item_model.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/screens/shared/product_detail_screen.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isLoadingDetails = false;
  String? _profileId;
  List<OrderModel> _orders = [];
  String _selectedFilter = 'ALL';

  static const List<Map<String, String>> _filters = [
    {'value': 'ALL', 'label': 'Todo'},
    {'value': 'PENDING', 'label': 'A pagar'},
    {'value': 'COMPLETED', 'label': 'Completado'},
    {'value': 'CANCELLED', 'label': 'Cancelado'},
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // ─── Status helpers ───────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return AppColors.success;
      case 'PENDING':
        return AppColors.warning;
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Icons.check_circle_rounded;
      case 'PENDING':
        return Icons.schedule_rounded;
      case 'CANCELLED':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 'Completado';
      case 'SHIPPED':
      case 'SENT':
      case 'PENDING':
      case 'PAID':
        return 'A pagar';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  Color _filterColor(String filter) {
    switch (filter) {
      case 'PENDING':
        return AppColors.warning;
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  bool _matchesFilter(OrderModel order) {
    final status = order.status.toUpperCase();
    switch (_selectedFilter) {
      case 'PENDING':
        return status == 'PENDING' || status == 'PAID';
      case 'COMPLETED':
        return status == 'COMPLETED';
      case 'CANCELLED':
        return status == 'CANCELLED';
      default:
        return true;
    }
  }

  List<OrderModel> get _filteredOrders {
    final orders = _orders.where(_matchesFilter).toList();
    orders.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return orders;
  }

  int _countForFilter(String filter) {
    if (filter == 'ALL') return _orders.length;
    return _orders.where((order) {
      final status = order.status.toUpperCase();
      switch (filter) {
        case 'PENDING':
          return status == 'PENDING' || status == 'PAID';
        case 'COMPLETED':
          return status == 'COMPLETED';
        case 'CANCELLED':
          return status == 'CANCELLED';
        default:
          return true;
      }
    }).length;
  }

  // ─── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadOrders() async {
    // Siempre reseteamos loading al inicio (funciona también en pull-to-refresh)
    if (mounted) setState(() => _isLoading = true);

    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final profile =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user.id)
              .maybeSingle();

      final profileId = profile?['id'] as String?;
      if (profileId == null) {
        if (mounted) {
          setState(() {
            _profileId = null;
            _orders = [];
          });
        }
        return;
      }

      final response = await _supabase
          .from('orders')
          .select(
            'id, customer_id, total_amount, total_profit, payment_method, status, created_at, warehouse_id, points_used, points_earned, profiles(full_name, phone), warehouses(name)',
          )
          .eq('customer_id', profileId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profileId = profileId;
          _orders =
              List<Map<String, dynamic>>.from(
                response,
              ).map(OrderModel.fromJson).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Error al cargar pedidos: $e');
      }
    } finally {
      // Garantiza que _isLoading siempre vuelve a false,
      // sin importar si hubo error, éxito o retorno temprano.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<OrderItemModel>> _loadOrderItems(OrderModel order) async {
    final response = await _supabase
        .from('order_items')
        .select(
          'id, order_id, product_id, variant_id, quantity, unit_cost, applied_price, net_profit, created_at, products(name, product_images(*)), product_variants(sku, attributes, product_images(*))',
        )
        .eq('order_id', order.id)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(
      response,
    ).map(OrderItemModel.fromJson).toList();
  }

  void _addOrderToCart(List<OrderItemModel> items) {
    final cart = context.read<CartProvider>();
    for (final item in items) {
      if (item.productId == null) continue;
      final product = ProductModel(
        id: item.productId!,
        name: item.productName ?? 'Producto',
        images: [],
        unitCost: item.unitCost,
        salePrice: item.appliedPrice,
        totalStock: item.quantity,
      );
      cart.addItem(
        product,
        quantity: item.quantity,
        variantId: item.variantId,
        variantLabel: item.variantLabel,
        unitPrice: item.appliedPrice,
        imageUrl: item.displayImageUrl,
        sku: item.sku,
        availableStock: item.quantity,
      );
    }
    if (mounted) {
      AppSnackbar.show(
        context,
        message: 'Productos añadidos al carrito',
        backgroundColor: AppColors.success,
      );
    }
  }

  Future<void> _reorderOrder(OrderModel order) async {
    try {
      final items = await _loadOrderItems(order);
      if (items.isEmpty) {
        if (!mounted) return;
        AppSnackbar.show(
          context,
          message: 'No se encontraron productos para añadir.',
        );
        return;
      }
      _addOrderToCart(items);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, message: 'No se pudo añadir al carrito: $e');
    }
  }

  Future<void> _openProductDetail(OrderItemModel item) async {
    final productId = item.productId;
    if (productId == null) return;
    try {
      final response =
          await _supabase
              .from('products')
              .select(
                'id, name, description, category_id, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, is_active, product_images(*)',
              )
              .eq('id', productId)
              .maybeSingle();

      if (!mounted || response == null) return;

      // ─── CORRECCIÓN: Consultar lotes ───
      final stockResponse = await _supabase
          .from('warehouse_stock_batches')
          .select('available_quantity')
          .eq('product_id', productId);

      // Sumamos la cantidad de todos los lotes
      final totalStock = List<Map<String, dynamic>>.from(
        stockResponse,
      ).fold<int>(
        0,
        (sum, row) => sum + ((row['available_quantity'] as num?)?.toInt() ?? 0),
      );

      final product = ProductModel.fromJson(
        Map<String, dynamic>.from(response),
      ).copyWith(totalStock: totalStock);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, message: 'No se pudo abrir el producto: $e');
    }
  }
  // ─── Order detail bottom sheet ────────────────────────────────────────────

  Future<void> _showOrderDetails(OrderModel order) async {
    setState(() => _isLoadingDetails = true);
    try {
      final items = await _loadOrderItems(order);

      // Siempre resetea el loading, incluso si se desmonta
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }

      if (!mounted) return;

      if (items.isEmpty) {
        showDialog<void>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Text(
                  'Pedido #${order.id.substring(0, 8).toUpperCase()}',
                ),
                content: const Text(
                  'No se encontraron productos para este pedido.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
        );
        return;
      }

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => DraggableScrollableSheet(
              initialChildSize: 0.82,
              minChildSize: 0.55,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      // Drag handle
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),

                      // Header
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pedido #${order.id.substring(0, 8).toUpperCase()}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('dd MMM yyyy, HH:mm').format(
                                          (order.createdAt ?? DateTime.now())
                                              .toLocal(),
                                        ),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _statusBadge(order.status),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: AppColors.border),
                            const SizedBox(height: 14),
                            // Stats row
                            Row(
                              children: [
                                _statBox(
                                  'Total',
                                  'S/ ${order.totalAmount.toStringAsFixed(2)}',
                                ),
                                const SizedBox(width: 10),
                                _statBox(
                                  'Monedas usadas',
                                  '${order.pointsUsed}',
                                  icon: Icons.stars_rounded,
                                ),
                                const SizedBox(width: 10),
                                _statBox(
                                  'Monedas ganadas',
                                  '${order.pointsEarned}',
                                  icon: Icons.trending_up_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Productos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...items.map((item) => _buildItemCard(item, order)),
                    ],
                  ),
                );
              },
            ),
      );
    } catch (e) {
      // Siempre resetea el loading en caso de error
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
      if (!mounted) return;
      AppSnackbar.show(context, message: 'Error al cargar el detalle: $e');
    }
  }

  // ─── Small widgets ────────────────────────────────────────────────────────

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    final icon = _statusIcon(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, {IconData? icon}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: AppColors.gold),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Añadimos OrderModel como parámetro ───
  // ─── Añadimos OrderModel como parámetro ───
  Widget _buildItemCard(OrderItemModel item, OrderModel order) {
    final imageUrl = item.displayImageUrl;
    // Verificamos si el pedido ya fue completado o entregado
    final isCompleted =
        order.status.toUpperCase() == 'COMPLETED' ||
        order.status.toUpperCase() == 'DELIVERED';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : () => _openProductDetail(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // ── Datos del producto ──
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child:
                          (imageUrl != null && imageUrl.isNotEmpty)
                              ? Image.network(
                                imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imageFallback(),
                              )
                              : _imageFallback(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName ?? 'Producto',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.variantLabel.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.variantLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/ ${item.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'x${item.quantity}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ── Botón de Calificar (Solo si está completado) ──
                if (isCompleted) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        // 1. Cerramos el BottomSheet de detalles de la orden
                        Navigator.pop(context);
                        // 2. Navegamos a la pantalla de detalle del producto
                        // Allí el usuario podrá leer otras reseñas y dejar la suya
                        _openProductDetail(item);
                      },
                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                      label: const Text(
                        'Calificar producto',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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

  Widget _imageFallback() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.textSecondary,
        size: 26,
      ),
    );
  }

  // ─── Order list card ──────────────────────────────────────────────────────

  Widget _buildOrderCard(OrderModel order) {
    final createdAt = (order.createdAt ?? DateTime.now()).toLocal();
    final statusColor = _statusColor(order.status);
    final hasPoints = (order.pointsUsed) > 0 || (order.pointsEarned) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        // Le pasamos la sombra general a la tarjeta
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          // El InkWell provee el efecto Hover (sombrea ligeramente al pasar el mouse) y el "pointer" de manita
          onTap: _isLoadingDetails ? null : () => _showOrderDetails(order),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: icon + info + price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icono con color de estado
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedido #${order.id.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat('dd MMM yyyy · HH:mm').format(createdAt),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (order.warehouseName != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.store_outlined,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  order.warehouseName!,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/ ${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _statusBadge(order.status),
                      ],
                    ),
                  ],
                ),

                // Puntos row (sólo si hay actividad de puntos)
                if (hasPoints) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          size: 14,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          [
                            if ((order.pointsUsed) > 0)
                              '−${order.pointsUsed} usadas',
                            if ((order.pointsEarned) > 0)
                              '+${order.pointsEarned} ganadas',
                          ].join('  ·  '),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A6300),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        label: 'Ver detalle',
                        icon: Icons.receipt_long_outlined,
                        onTap:
                            _isLoadingDetails
                                ? null
                                : () => _showOrderDetails(order),
                        filled: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionButton(
                        label: 'Repetir pedido',
                        icon: Icons.add_shopping_cart_rounded,
                        onTap:
                            _isLoadingDetails
                                ? null
                                : () => _reorderOrder(order),
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required bool filled,
  }) {
    // Usar OutlinedButton o ElevatedButton maneja 100% mejor el Hover y la manita que un GestureDetector
    if (filled) {
      return SizedBox(
        height: 40,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation:
                0, // Quitamos elevación para que no choque con la de la tarjeta
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      );
    } else {
      return SizedBox(
        height: 40,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      );
    }
  }
  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final visibleOrders = _filteredOrders;

    return CustomerLayout(
      title: 'Mis Pedidos',
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: true,
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              )
              : _profileId == null
              ? AppEmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Necesitas iniciar sesión',
                message: 'Inicia sesión para ver el historial de tus pedidos.',
              )
              : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadOrders,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // ── Header banner ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF0F3460)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tus pedidos',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_orders.length} pedido${_orders.length == 1 ? '' : 's'} en total',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Filter chips ───────────────────────────────────
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final filter = _filters[index];
                          final value = filter['value']!;
                          final label = filter['label']!;
                          final isSelected = _selectedFilter == value;
                          final count = _countForFilter(value);
                          final color = _filterColor(value);

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              boxShadow:
                                  isSelected
                                      ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                      : [],
                            ),
                            // Material e InkWell reemplazan a GestureDetector y AnimatedContainer
                            child: Material(
                              color: isSelected ? color : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                                side: BorderSide(
                                  color: isSelected ? color : AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(40),
                                onTap:
                                    () =>
                                        setState(() => _selectedFilter = value),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$label  $count',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Order list / empty states ──────────────────────
                    if (_orders.isEmpty)
                      AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Aún no tienes pedidos',
                        message:
                            'Cuando realices una compra, aparecerá aquí tu historial.',
                      )
                    else if (visibleOrders.isEmpty)
                      AppEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Sin pedidos en este filtro',
                        message: 'Cambia el estado para ver otros pedidos.',
                      )
                    else
                      ...visibleOrders.map(_buildOrderCard),
                  ],
                ),
              ),
    );
  }
}
