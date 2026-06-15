import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/order_item_model.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/services/admin/order_pdf_generator.dart';
import 'package:inventory_store_app/services/admin/orders_service.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const int _pageSize = 8;
  final _supabase = Supabase.instance.client;
  final _ordersService = OrdersService();

  List<OrderModel> _orders = [];
  bool _isLoading = true;
  bool _isBackgroundLoading = false; // Para recargas sin borrar la lista
  final Set<String> _processingOrders = {}; // Bloqueo de dobles toques

  // ── FILTROS ──────────────────────────────────────────────────────────────
  String _statusFilter = 'ALL';
  String _paymentStatusFilter = 'ALL';
  int _currentPage = 0;
  DateTimeRange? _dateRange;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── CARGA DE DATOS ───────────────────────────────────────────────────────

  Future<void> _fetchOrders({bool background = false}) async {
    if (!mounted) return;
    if (background) {
      setState(() => _isBackgroundLoading = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      var query = _supabase.from('orders').select('''
        id,
        customer_id,
        customer_name,
        total_amount,
        total_profit,
        discount_amount,
        payment_method,
        payment_status,
        amount_paid,
        status,
        due_date,
        points_used,
        points_earned,
        created_at,
        warehouse_id,
        created_by,
        profiles!orders_customer_id_fkey ( id, full_name, phone ),
        warehouses ( id, name )
      ''');

      if (_statusFilter != 'ALL') query = query.eq('status', _statusFilter);
      if (_paymentStatusFilter != 'ALL') {
        query = query.eq('payment_status', _paymentStatusFilter);
      }

      if (_dateRange != null) {
        final start = _dateRange!.start.toIso8601String();
        final end =
            _dateRange!.end
                .add(const Duration(hours: 23, minutes: 59, seconds: 59))
                .toIso8601String();
        query = query.gte('created_at', start).lte('created_at', end);
      }

      final response = await query.order('created_at', ascending: false);
      List<dynamic> rawData = response as List;

      // Búsqueda en memoria (cruza dos tablas)
      final queryText = _searchCtrl.text.trim().toLowerCase();
      if (queryText.isNotEmpty) {
        rawData =
            rawData.where((row) {
              final profile = row['profiles'] as Map<String, dynamic>?;
              final clientName =
                  ((profile?['full_name'] as String?) ??
                          (row['customer_name'] as String?) ??
                          'Cliente mostrador')
                      .toLowerCase();
              final orderId = (row['id'] as String? ?? '').toLowerCase();
              return clientName.contains(queryText) ||
                  orderId.contains(queryText);
            }).toList();
      }

      if (mounted) {
        setState(() {
          _orders = rawData.map((e) => OrderModel.fromJson(e)).toList();
          _isLoading = false;
          _isBackgroundLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isBackgroundLoading = false;
        });
        AppSnackbar.show(
          context,
          message: 'Error al cargar pedidos: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _currentPage = 0);
      _fetchOrders(background: true);
    });
  }

  // ─── GENERACIÓN DE TICKET PDF ─────────────────────────────────────────────

  Future<void> _printOrderTicket(OrderModel order) async {
    try {
      final resp = await _supabase
          .from('order_items')
          .select('''
            id, order_id, product_id, variant_id, quantity, unit_cost,
            applied_price, net_profit, created_at,
            products ( name, uses_batches, product_images(image_url, is_main, variant_id) ),
            product_variants (
              sku,
              product_images(image_url, is_main, variant_id),
              variant_attribute_values(attribute_values(value))
            )
          ''')
          .eq('order_id', order.id);

      final items =
          (resp as List).map((row) {
            final variantJson =
                row['product_variants'] as Map<String, dynamic>?;
            final vavList =
                variantJson?['variant_attribute_values'] as List<dynamic>? ??
                [];
            final attrValues = <String>[];
            for (var vav in vavList) {
              final av = vav['attribute_values'] as Map<String, dynamic>?;
              if (av?['value'] != null) attrValues.add(av!['value'].toString());
            }
            if (variantJson != null) {
              variantJson['attributes'] = {'Variante': attrValues.join(' · ')};
            }
            return OrderItemModel.fromJson(Map<String, dynamic>.from(row));
          }).toList();

      await OrderPdfGenerator.shareTicket(order, items: items);
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

  // ─── ACTUALIZAR ESTADO DE PEDIDO ─────────────────────────────────────────

  Future<void> _updateOrderStatus(OrderModel order, String newStatus) async {
    // Bloqueo de dobles toques
    if (_processingOrders.contains(order.id)) return;

    // Aviso si el método de pago es "POR ACORDAR" al completar
    if (newStatus == 'COMPLETED' &&
        (order.paymentMethod == 'POR ACORDAR' ||
            order.paymentMethod.trim().isEmpty)) {
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Método de pago pendiente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Este pedido tiene el método de pago como \'POR ACORDAR\'. '
                'Abre el detalle del pedido y selecciona la cuenta o método '
                'de cobro antes de completarlo.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                ),
              ],
            ),
      );
      return;
    }

    // Diálogo de confirmación enriquecido
    final confirm = await _showConfirmDialog(order, newStatus);
    if (confirm != true) return;

    setState(() => _processingOrders.add(order.id));

    try {
      if (newStatus == 'COMPLETED' && order.status == 'PENDING') {
        final orderData =
            await _supabase
                .from('orders')
                .select('warehouse_id')
                .eq('id', order.id)
                .single();

        await _ordersService.completeOrder(
          order: orderData,
          orderId: order.id,
          paymentMethod: order.paymentMethod,
          totalAmount: order.totalAmount,
          customerId: order.customerId,
          pointsUsed: order.pointsUsed,
          pointsEarned: order.pointsEarned,
        );
      } else if (newStatus == 'CANCELLED') {
        await _ordersService.cancelOrder(
          orderId: order.id,
          customerId: order.customerId,
        );
      } else {
        // Cambio de estado simple (sin lógica adicional)
        await _supabase
            .from('orders')
            .update({'status': newStatus})
            .eq('id', order.id);
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              newStatus == 'COMPLETED'
                  ? 'Pedido completado correctamente'
                  : 'Estado actualizado correctamente',
          type: SnackbarType.success,
        );
        _fetchOrders(background: true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al actualizar: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _processingOrders.remove(order.id));
    }
  }

  Future<bool?> _showConfirmDialog(OrderModel order, String newStatus) {
    final isCompleting = newStatus == 'COMPLETED';
    final isCancelling = newStatus == 'CANCELLED';
    final isCredit = order.paymentMethod == 'CRÉDITO';
    final pendingPoints = order.pointsEarned;

    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isCompleting
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCompleting
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
                    color:
                        isCompleting
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isCompleting ? 'Confirmar cobro' : 'Cancelar pedido',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cliente: ${order.displayCustomerName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      isCompleting ? 'Monto a cobrar: ' : 'Total del pedido: ',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'S/ ${order.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color:
                            isCompleting
                                ? AppColors.primary
                                : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                if (isCompleting && !isCredit && pendingPoints > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          'El cliente ganará $pendingPoints monedas',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isCompleting && isCredit) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Se registrará como deuda de crédito.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isCancelling) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Esta acción no se puede deshacer. El stock NO se reintegrará automáticamente si ya fue descontado.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isCompleting
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  isCompleting ? 'Confirmar cobro' : 'Sí, cancelar',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showOrderDetails(OrderModel order) async {
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
    if (result == true) _fetchOrders(background: true);
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final total = _orders.length;
    final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();
    final currentPage =
        _currentPage >= totalPages ? totalPages - 1 : _currentPage;
    final start = currentPage * _pageSize;
    final end =
        total == 0
            ? 0
            : ((start + _pageSize) > total ? total : (start + _pageSize));
    final pageItems = total == 0 ? <OrderModel>[] : _orders.sublist(start, end);

    return AdminLayout(
      title: 'Gestión de Pedidos',
      showBackButton: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barra de progreso (recargas en background) ──────────────────
          if (_isBackgroundLoading)
            const LinearProgressIndicator(color: AppColors.teal, minHeight: 2),

          // ── Buscador ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente o ID de pedido...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                ),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() => _searchCtrl.clear());
                            _fetchOrders(background: true);
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
              ),
            ),
          ),

          // ── Filtros ─────────────────────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterDropdown(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text('Todos los estados'),
                    ),
                    DropdownMenuItem(
                      value: 'COMPLETED',
                      child: Text('Completados'),
                    ),
                    DropdownMenuItem(
                      value: 'PENDING',
                      child: Text('Borradores'),
                    ),
                    DropdownMenuItem(
                      value: 'CANCELLED',
                      child: Text('Cancelados'),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _statusFilter = val!;
                      _currentPage = 0;
                    });
                    _fetchOrders(background: true);
                  },
                ),
                const SizedBox(width: 8),
                _FilterDropdown(
                  value: _paymentStatusFilter,
                  items: const [
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text('Todos los cobros'),
                    ),
                    DropdownMenuItem(value: 'PAID', child: Text('Pagados')),
                    DropdownMenuItem(
                      value: 'PENDING',
                      child: Text('Por cobrar'),
                    ),
                    DropdownMenuItem(
                      value: 'PARTIAL',
                      child: Text('Parciales'),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _paymentStatusFilter = val!;
                      _currentPage = 0;
                    });
                    _fetchOrders(background: true);
                  },
                ),
                const SizedBox(width: 8),
                DateFilterCalendar(
                  dateRange: _dateRange,
                  onDateRangeSelected: (picked) {
                    setState(() {
                      _dateRange = picked;
                      _currentPage = 0;
                    });
                    _fetchOrders(background: true);
                  },
                  onClear: () {
                    setState(() {
                      _dateRange = null;
                      _currentPage = 0;
                    });
                    _fetchOrders(background: true);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Lista de pedidos ─────────────────────────────────────────────
          Expanded(
            child:
                _isLoading
                    ? _buildShimmerList()
                    : _orders.isEmpty
                    ? _buildEmptyState()
                    : Column(
                      children: [
                        // Contador
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Row(
                            children: [
                              Text(
                                'Mostrando ${start + 1}-$end de $total',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Pág. ${currentPage + 1} / $totalPages',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: () => _fetchOrders(),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: pageItems.length,
                              itemBuilder: (context, index) {
                                final order = pageItems[index];
                                final isProcessing = _processingOrders.contains(
                                  order.id,
                                );
                                return AdminOrderCard(
                                  order: order,
                                  isProcessing: isProcessing,
                                  onTap: () => _showOrderDetails(order),
                                  onUpdateStatus:
                                      (o, s) => _updateOrderStatus(o, s),
                                  onPrint: () => _printOrderTicket(order),
                                );
                              },
                            ),
                          ),
                        ),
                        if (totalPages > 1)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                            child: AdminPageBlocks(
                              currentPage: _currentPage,
                              totalPages: totalPages,
                              onPageChanged:
                                  (page) => setState(() => _currentPage = page),
                            ),
                          ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const AppShimmer(height: 140),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron pedidos.',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta cambiar los filtros o la búsqueda.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Widget de filtro dropdown (privado) ──────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Colors.black87,
          ),
          isDense: true,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontFamily: 'Nunito',
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Tarjeta de pedido ────────────────────────────────────────────────────────

class AdminOrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isProcessing;
  final VoidCallback onTap;
  final Function(OrderModel, String) onUpdateStatus;
  final VoidCallback onPrint;

  const AdminOrderCard({
    super.key,
    required this.order,
    required this.isProcessing,
    required this.onTap,
    required this.onUpdateStatus,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final date = (order.createdAt ?? DateTime.now()).toLocal();
    final dateString = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    final customerName = order.displayCustomerName;
    final shortId = order.id.substring(0, 8).toUpperCase();

    final isCredit = order.paymentMethod == 'CRÉDITO';

    // Calcular estado de pago dinámico
    String paymentStatus = order.paymentStatus;
    double amountPaid = order.amountPaid;
    if (status == 'COMPLETED' && !isCredit) {
      paymentStatus = 'PAID';
      amountPaid = order.totalAmount;
    }

    final totalAmount = order.totalAmount;
    final pendingAmount = totalAmount - amountPaid;
    final warehouseName = order.warehouseName;

    // Chip de puntos pendientes (crédito completado con puntos a ganar)
    final showPendingPointsChip =
        status == 'COMPLETED' &&
        isCredit &&
        paymentStatus != 'PAID' &&
        order.pointsEarned > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isProcessing ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Indicador de procesamiento ────────────────────────────
                if (isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(
                      color: AppColors.teal,
                      minHeight: 2,
                    ),
                  ),

                // ── Fila 1: Info Cliente e ID ─────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ID del pedido
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.tag_rounded,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  shortId,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade700,
                                    fontFamily: 'monospace',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Cliente
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Fecha
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateString,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Método de pago
                          Row(
                            children: [
                              Icon(
                                isCredit
                                    ? Icons.credit_card_rounded
                                    : Icons.payments_outlined,
                                size: 14,
                                color:
                                    isCredit
                                        ? Colors.deepOrange.shade400
                                        : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                order.paymentMethod,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isCredit
                                          ? Colors.deepOrange.shade600
                                          : Colors.grey.shade600,
                                  fontWeight:
                                      isCredit
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          if (warehouseName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.warehouse_outlined,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  warehouseName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Chip: puntos pendientes de otorgar
                          if (showPendingPointsChip) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.amber.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '🪙',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${order.pointsEarned} monedas pendientes de otorgar',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _StatusBadge(status: status),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // ── Fila 2: Totales y Botones ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total del pedido',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'S/ ${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (order.discountAmount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 4),
                            child: Text(
                              'Incluye S/ ${order.discountAmount.toStringAsFixed(2)} de descuento',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (status == 'COMPLETED') ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _PaymentStatusBadge(paymentStatus: paymentStatus),
                              if (paymentStatus == 'PENDING' ||
                                  paymentStatus == 'PARTIAL') ...[
                                const SizedBox(width: 6),
                                Text(
                                  'Debe S/ ${pendingAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepOrange.shade600,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),

                    // Botones de acción
                    Row(
                      children: [
                        if (status == 'COMPLETED' || status == 'CANCELLED')
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: const Text('Ticket'),
                            onPressed: onPrint,
                          ),
                        if (status == 'PENDING') ...[
                          IconButton(
                            icon:
                                isProcessing
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.red,
                                      ),
                                    )
                                    : const Icon(Icons.close_rounded, size: 22),
                            color: Colors.red.shade400,
                            tooltip: 'Cancelar',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed:
                                isProcessing
                                    ? null
                                    : () => onUpdateStatus(order, 'CANCELLED'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon:
                                isProcessing
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                    ),
                            label: const Text(
                              'Cobrar',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onPressed:
                                isProcessing
                                    ? null
                                    : () => onUpdateStatus(order, 'COMPLETED'),
                          ),
                        ],
                      ],
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
}

// ─── Badges privados (const-friendly) ────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'COMPLETED':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label = 'Completado';
        break;
      case 'PENDING':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        label = 'Pendiente';
        break;
      case 'CANCELLED':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        label = 'Cancelado';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  final String paymentStatus;
  const _PaymentStatusBadge({required this.paymentStatus});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (paymentStatus) {
      case 'PAID':
        bgColor = Colors.teal.shade50;
        textColor = Colors.teal.shade700;
        label = 'Pagado';
        break;
      case 'PENDING':
        bgColor = Colors.deepOrange.shade50;
        textColor = Colors.deepOrange.shade700;
        label = 'Por cobrar';
        break;
      case 'PARTIAL':
        bgColor = Colors.amber.shade50;
        textColor = Colors.amber.shade800;
        label = 'Pago parcial';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        label = paymentStatus;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
