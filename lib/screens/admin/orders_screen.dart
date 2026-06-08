import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/services/admin/order_pdf_generator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_sheet.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const int _pageSize = 8;
  final _supabase = Supabase.instance.client;
  List<OrderModel> _orders = [];
  bool _isLoading = true;

  // --- ESTADOS DE FILTROS ---
  String _statusFilter = 'ALL';
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

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      // Traemos TODOS los campos relevantes incluyendo payment_status, amount_paid,
      // y el perfil del cliente + warehouse para mostrarlos en la tarjeta y detalle.
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

      // Filtro por Estado
      if (_statusFilter != 'ALL') {
        query = query.eq('status', _statusFilter);
      }

      // Filtro por Fecha
      if (_dateRange != null) {
        final startStr = _dateRange!.start.toIso8601String();
        final endStr =
            _dateRange!.end
                .add(const Duration(hours: 23, minutes: 59, seconds: 59))
                .toIso8601String();
        query = query.gte('created_at', startStr).lte('created_at', endStr);
      }

      final response = await query.order('created_at', ascending: false);

      // Filtro local por nombre de cliente o ID de pedido
      List<dynamic> rawData = response as List;
      final queryText = _searchCtrl.text.trim().toLowerCase();

      if (queryText.isNotEmpty) {
        rawData =
            rawData.where((row) {
              final profile = row['profiles'] as Map<String, dynamic>?;
              final profileName = profile?['full_name'] as String?;
              final manualName = row['customer_name'] as String?;
              final clientName =
                  (profileName ?? manualName ?? 'Cliente mostrador')
                      .toLowerCase();
              final orderId = (row['id'] as String? ?? '').toLowerCase();
              return clientName.contains(queryText) ||
                  orderId.contains(queryText);
            }).toList();
      }

      if (mounted) {
        setState(() {
          _orders =
              rawData
                  .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
          _currentPage = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar pedidos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACTUALIZACIÓN DE ESTADO CON LÓGICA DE PAGO Y CRÉDITOS ---
  Future<void> _updateOrderStatus(OrderModel order, String newStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Actualizar Pedido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              '¿Estás seguro de marcar este pedido como '
              '${_statusLabel(newStatus)}?',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      newStatus == 'COMPLETED' ? Colors.green : Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Confirmar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      String? currentUserId;
      final authUserId = _supabase.auth.currentUser?.id;

      if (authUserId != null) {
        final profileResp =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();

        if (profileResp != null) {
          currentUserId = profileResp['id'] as String;
        }
      }

      // ─── 1. PENDING → COMPLETED (Activar borrador) ───
      if (newStatus == 'COMPLETED' && order.status == 'PENDING') {
        final orderData =
            await _supabase
                .from('orders')
                .select('warehouse_id')
                .eq('id', order.id)
                .single();
        final warehouseId = orderData['warehouse_id'];

        // Validar Crédito antes que nada
        if (order.paymentMethod == 'CRÉDITO') {
          if (order.customerId == null) {
            _showErrorSnackBar(
              'No hay cliente asignado para validar el crédito.',
            );
            return;
          }
          final creditInfo =
              await _supabase
                  .from('customer_credits')
                  .select('id, credit_limit, current_debt, is_active')
                  .eq('profile_id', order.customerId!)
                  .maybeSingle();

          if (creditInfo == null || creditInfo['is_active'] != true) {
            _showErrorSnackBar('El cliente no tiene línea de crédito activa.');
            return;
          }

          final availableCredit =
              (creditInfo['credit_limit'] as num).toDouble() -
              (creditInfo['current_debt'] as num).toDouble();

          if (availableCredit < order.totalAmount) {
            _showErrorSnackBar(
              'Crédito insuficiente. Disponible: S/ ${availableCredit.toStringAsFixed(2)}',
            );
            return;
          }
        }

        final itemsResp = await _supabase
            .from('order_items')
            .select(
              'product_id, variant_id, quantity, products(name), product_variants(attributes, sku)',
            )
            .eq('order_id', order.id);

        final items = List<Map<String, dynamic>>.from(itemsResp);
        List<String> outOfStockMessages = [];
        List<Map<String, dynamic>> batchesToUpdate = [];
        List<Map<String, dynamic>> movementsToInsert = [];

        for (var item in items) {
          final variantId = item['variant_id'];
          final qtyNeeded = item['quantity'] as int;
          final productName = item['products']?['name'] ?? 'Producto';

          final variantData =
              item['product_variants'] as Map<String, dynamic>? ?? {};
          final attributes = Map<String, dynamic>.from(
            variantData['attributes'] as Map? ?? {},
          );
          final sku = variantData['sku'] as String?;

          String variantLabel =
              attributes.isEmpty
                  ? ((sku != null && sku.trim().isNotEmpty)
                      ? sku
                      : 'Variante estándar')
                  : attributes.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join(' | ');

          final batchesResp = await _supabase
              .from('warehouse_stock_batches')
              .select('id, available_quantity')
              .eq('warehouse_id', warehouseId)
              .eq('variant_id', variantId)
              .order('created_at', ascending: true);

          final batches = List<Map<String, dynamic>>.from(batchesResp);
          final currentStock = batches.fold<int>(
            0,
            (sum, b) => sum + ((b['available_quantity'] as num?)?.toInt() ?? 0),
          );

          if (currentStock < qtyNeeded) {
            outOfStockMessages.add(
              '• $productName - $variantLabel (Stock: $currentStock, Pedido: $qtyNeeded)',
            );
          } else {
            int remainingToDeduct = qtyNeeded;
            for (var batch in batches) {
              if (remainingToDeduct <= 0) break;
              int batchStock =
                  (batch['available_quantity'] as num?)?.toInt() ?? 0;
              if (batchStock > 0) {
                int deductFromThis =
                    batchStock >= remainingToDeduct
                        ? remainingToDeduct
                        : batchStock;
                int newBatchStock = batchStock - deductFromThis;

                batchesToUpdate.add({
                  'id': batch['id'],
                  'available_quantity': newBatchStock,
                });
                movementsToInsert.add({
                  'variant_id': variantId,
                  'warehouse_id': warehouseId,
                  'stock_batch_id': batch['id'],
                  'order_id': order.id,
                  'quantity': -deductFromThis,
                  'previous_stock': batchStock,
                  'new_stock': newBatchStock,
                  'reason': 'SALE',
                  'notes': 'Borrador completado desde panel',
                  if (currentUserId != null) 'created_by': currentUserId,
                });
                remainingToDeduct -= deductFromThis;
              }
            }
          }
        }

        if (outOfStockMessages.isNotEmpty) {
          if (mounted) {
            showDialog(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text(
                      'Stock Insuficiente',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      'No se puede completar el pedido:\n\n${outOfStockMessages.join('\n')}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Entendido'),
                      ),
                    ],
                  ),
            );
          }
          return;
        }

        for (var update in batchesToUpdate) {
          await _supabase
              .from('warehouse_stock_batches')
              .update({'available_quantity': update['available_quantity']})
              .eq('id', update['id']);
        }
        for (var mov in movementsToInsert) {
          await _supabase.from('inventory_movements').insert(mov);
        }

        // Cargar deuda al cliente si es CRÉDITO
        if (order.paymentMethod == 'CRÉDITO') {
          final creditResp =
              await _supabase
                  .from('customer_credits')
                  .select('id, current_debt')
                  .eq('profile_id', order.customerId!)
                  .single();

          final creditId = creditResp['id'];
          final newDebt =
              (creditResp['current_debt'] as num).toDouble() +
              order.totalAmount;

          await _supabase
              .from('customer_credits')
              .update({
                'current_debt': newDebt,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', creditId);

          await _supabase.from('credit_movements').insert({
            'credit_id': creditId,
            'order_id': order.id,
            'movement_type': 'CHARGE',
            'amount': order.totalAmount,
            'payment_method': 'CRÉDITO',
            'notes': 'Activación de pedido desde panel de órdenes',
            if (currentUserId != null) 'created_by': currentUserId,
          });
        }

        // Registrar wallet_movements y actualizar wallet_balance si hay puntos
        if (order.customerId != null) {
          final puntosUsados = order.pointsUsed;
          final puntosGanados = order.pointsEarned;

          if (puntosUsados > 0) {
            // Verificar que no se haya registrado ya (idempotente)
            final redemptionExists =
                await _supabase
                    .from('wallet_movements')
                    .select('id')
                    .eq('order_id', order.id)
                    .eq('movement_type', 'REDEEMED')
                    .maybeSingle();

            if (redemptionExists == null) {
              final profileData =
                  await _supabase
                      .from('profiles')
                      .select('wallet_balance')
                      .eq('id', order.customerId!)
                      .single();
              final currentBal = (profileData['wallet_balance'] as num).toInt();
              final newBal = (currentBal - puntosUsados).clamp(0, currentBal);

              await _supabase
                  .from('profiles')
                  .update({'wallet_balance': newBal})
                  .eq('id', order.customerId!);

              await _supabase.from('wallet_movements').insert({
                'profile_id': order.customerId,
                'order_id': order.id,
                'points': -puntosUsados,
                'movement_type': 'REDEEMED',
                'description':
                    'Canje al activar pedido #${order.id.substring(0, 8)}',
              });
            }
          }

          if (puntosGanados > 0) {
            final earnedExists =
                await _supabase
                    .from('wallet_movements')
                    .select('id')
                    .eq('order_id', order.id)
                    .eq('movement_type', 'EARNED')
                    .maybeSingle();

            if (earnedExists == null) {
              final profileData =
                  await _supabase
                      .from('profiles')
                      .select('wallet_balance')
                      .eq('id', order.customerId!)
                      .single();
              final currentBal = (profileData['wallet_balance'] as num).toInt();

              await _supabase
                  .from('profiles')
                  .update({'wallet_balance': currentBal + puntosGanados})
                  .eq('id', order.customerId!);

              await _supabase.from('wallet_movements').insert({
                'profile_id': order.customerId,
                'order_id': order.id,
                'points': puntosGanados,
                'movement_type': 'EARNED',
                'description':
                    'Monedas al activar pedido #${order.id.substring(0, 8)}',
              });
            }
          }
        }
      }
      // ─── 2. COMPLETED → CANCELLED (Cancelar un pedido ya completado) ───
      else if (newStatus == 'CANCELLED' && order.status == 'COMPLETED') {
        final orderData =
            await _supabase
                .from('orders')
                .select(
                  'warehouse_id, total_amount, payment_method, customer_id',
                )
                .eq('id', order.id)
                .single();

        final warehouseId = orderData['warehouse_id'];
        final origAmount = (orderData['total_amount'] as num).toDouble();
        final origPaymentMethod = orderData['payment_method'] as String;
        final origCustomerId = orderData['customer_id'] as String?;

        final itemsResp = await _supabase
            .from('order_items')
            .select('product_id, variant_id, quantity')
            .eq('order_id', order.id);

        for (var item in itemsResp) {
          final variantId = item['variant_id'];
          final productId = item['product_id'];
          final qty = item['quantity'] as int;

          final batchResp =
              await _supabase
                  .from('warehouse_stock_batches')
                  .select('id, available_quantity')
                  .eq('warehouse_id', warehouseId)
                  .eq('variant_id', variantId)
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle();

          if (batchResp != null) {
            final batchId = batchResp['id'];
            final currentStock =
                (batchResp['available_quantity'] as num?)?.toInt() ?? 0;
            final newStock = currentStock + qty;

            await _supabase
                .from('warehouse_stock_batches')
                .update({'available_quantity': newStock})
                .eq('id', batchId);

            await _supabase.from('inventory_movements').insert({
              'variant_id': variantId,
              'warehouse_id': warehouseId,
              'stock_batch_id': batchId,
              'order_id': order.id,
              'quantity': qty,
              'previous_stock': currentStock,
              'new_stock': newStock,
              'reason': 'RETURN',
              'notes': 'Devolución por cancelación de pedido',
              if (currentUserId != null) 'created_by': currentUserId,
            });
          } else {
            final newBatch =
                await _supabase
                    .from('warehouse_stock_batches')
                    .insert({
                      'variant_id': variantId,
                      'product_id': productId,
                      'warehouse_id': warehouseId,
                      'available_quantity': qty,
                      'batch_number': 'DEFAULT',
                      if (currentUserId != null) 'created_by': currentUserId,
                    })
                    .select('id')
                    .single();

            await _supabase.from('inventory_movements').insert({
              'variant_id': variantId,
              'warehouse_id': warehouseId,
              'stock_batch_id': newBatch['id'],
              'order_id': order.id,
              'quantity': qty,
              'previous_stock': 0,
              'new_stock': qty,
              'reason': 'RETURN',
              'notes': 'Devolución por cancelación de pedido',
              if (currentUserId != null) 'created_by': currentUserId,
            });
          }
        }

        // IMPORTANTE: Revertir deuda de crédito si el pago era CRÉDITO
        if (origPaymentMethod == 'CRÉDITO' && origCustomerId != null) {
          final creditResp =
              await _supabase
                  .from('customer_credits')
                  .select('id, current_debt')
                  .eq('profile_id', origCustomerId)
                  .maybeSingle();

          if (creditResp != null) {
            final creditId = creditResp['id'];
            final currentDebt = (creditResp['current_debt'] as num).toDouble();
            final newDebt =
                (currentDebt - origAmount) < 0
                    ? 0.0
                    : (currentDebt - origAmount);

            await _supabase
                .from('customer_credits')
                .update({
                  'current_debt': newDebt,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', creditId);

            await _supabase.from('credit_movements').insert({
              'credit_id': creditId,
              'order_id': order.id,
              'movement_type': 'PAYMENT',
              'amount': origAmount,
              'notes': 'Reembolso de deuda por cancelación de pedido',
              if (currentUserId != null) 'created_by': currentUserId,
            });
          }
        }

        // Revertir puntos ganados y devolver puntos canjeados (si los hubo)
        if (origCustomerId != null) {
          // 1. Revertir puntos GANADOS al cancelar
          final earnedMov =
              await _supabase
                  .from('wallet_movements')
                  .select('id, points')
                  .eq('order_id', order.id)
                  .eq('movement_type', 'EARNED')
                  .maybeSingle();

          if (earnedMov != null) {
            final ptsGanados = (earnedMov['points'] as num).toInt();
            final profileData =
                await _supabase
                    .from('profiles')
                    .select('wallet_balance')
                    .eq('id', origCustomerId)
                    .single();
            final currentBal = (profileData['wallet_balance'] as num).toInt();
            final newBal = (currentBal - ptsGanados).clamp(0, currentBal);

            await _supabase
                .from('profiles')
                .update({'wallet_balance': newBal})
                .eq('id', origCustomerId);

            await _supabase.from('wallet_movements').insert({
              'profile_id': origCustomerId,
              'order_id': order.id,
              'points': -ptsGanados,
              'movement_type': 'ADJUSTMENT',
              'description': 'Reversión de monedas por cancelación de pedido',
            });
          }

          // 2. Devolver puntos CANJEADOS al cancelar
          final redeemedMov =
              await _supabase
                  .from('wallet_movements')
                  .select('id, points')
                  .eq('order_id', order.id)
                  .eq('movement_type', 'REDEEMED')
                  .maybeSingle();

          if (redeemedMov != null) {
            final ptsCanjeados = (redeemedMov['points'] as num).toInt().abs();
            if (ptsCanjeados > 0) {
              final profileData =
                  await _supabase
                      .from('profiles')
                      .select('wallet_balance')
                      .eq('id', origCustomerId)
                      .single();
              final currentBal = (profileData['wallet_balance'] as num).toInt();

              await _supabase
                  .from('profiles')
                  .update({'wallet_balance': currentBal + ptsCanjeados})
                  .eq('id', origCustomerId);

              await _supabase.from('wallet_movements').insert({
                'profile_id': origCustomerId,
                'order_id': order.id,
                'points': ptsCanjeados,
                'movement_type': 'ADJUSTMENT',
                'description':
                    'Devolución de monedas canjeadas por cancelación',
              });
            }
          }
        }
      }

      // ─── 3. PENDING → CANCELLED (Cancelar borrador — solo actualizar estado) ───
      // No hay stock comprometido ni deuda, solo cambiar el registro.

      // ─── 4. ACTUALIZAR ORDEN EN SÍ ───
      final updates = <String, dynamic>{'status': newStatus};

      if (newStatus == 'COMPLETED') {
        if (order.paymentMethod == 'POR ACORDAR' ||
            order.paymentMethod.trim().isEmpty) {
          updates['payment_method'] = 'EFECTIVO';
          updates['payment_status'] = 'PAID';
          updates['amount_paid'] = order.totalAmount;
        } else if (order.paymentMethod == 'CRÉDITO') {
          // El monto total va a deuda, se paga $0 al contado
          updates['payment_status'] = 'PENDING';
          updates['amount_paid'] = 0;
        } else {
          // Efectivo, Yape, Plin, Tarjeta, Transferencia
          updates['payment_status'] = 'PAID';
          updates['amount_paid'] = order.totalAmount;
        }
      } else if (newStatus == 'CANCELLED') {
        updates['payment_status'] = 'PAID'; // Neutro — no hay deuda pendiente
        updates['amount_paid'] = 0;
      }

      await _supabase.from('orders').update(updates).eq('id', order.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error al actualizar: $e');
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'COMPLETED':
        return 'Completado';
      case 'PENDING':
        return 'Pendiente';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  void _showErrorSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  Future<void> _showOrderDetails(OrderModel order) async {
    final result = await showModalBottomSheet(
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
    if (result == true) {
      _fetchOrders();
    }
  }

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
        children: [
          // --- SECCIÓN DE FILTROS ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Buscador
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por cliente o ID de pedido...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
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
                                _fetchOrders();
                              },
                            )
                            : null,
                    filled: true,
                    fillColor: Colors.grey.shade50,
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
                      vertical: 12,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {});
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 500),
                      _fetchOrders,
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Fila de filtros (Estado y Fecha)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _statusFilter,
                            isExpanded: true,
                            icon: Icon(
                              Icons.expand_more_rounded,
                              color: Colors.grey.shade500,
                            ),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ALL',
                                child: Text('Todos', maxLines: 1),
                              ),
                              DropdownMenuItem(
                                value: 'PENDING',
                                child: Text('Pendientes', maxLines: 1),
                              ),
                              DropdownMenuItem(
                                value: 'COMPLETED',
                                child: Text('Completados', maxLines: 1),
                              ),
                              DropdownMenuItem(
                                value: 'CANCELLED',
                                child: Text('Cancelados', maxLines: 1),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _statusFilter = val);
                                _fetchOrders();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          backgroundColor:
                              _dateRange != null
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color:
                                _dateRange != null
                                    ? AppColors.primary
                                    : Colors.grey.shade200,
                          ),
                          elevation: 0,
                        ),
                        icon: Icon(
                          Icons.calendar_month_rounded,
                          size: 16,
                          color:
                              _dateRange != null
                                  ? AppColors.primary
                                  : Colors.grey.shade600,
                        ),
                        label: Text(
                          _dateRange == null
                              ? 'Fechas'
                              : '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                _dateRange != null
                                    ? AppColors.primary
                                    : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDateRange: _dateRange,
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Theme.of(context).primaryColor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => _dateRange = picked);
                            _fetchOrders();
                          }
                        },
                      ),
                    ),
                    if (_dateRange != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.clear_rounded,
                            color: Colors.red.shade400,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _dateRange = null);
                            _fetchOrders();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // --- LISTA DE PEDIDOS ---
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _orders.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 60,
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
                        ],
                      ),
                    )
                    : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
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
                                'Página ${currentPage + 1} / $totalPages',
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
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: pageItems.length,
                            itemBuilder: (context, index) {
                              final order = pageItems[index];
                              return AdminOrderCard(
                                order: order,
                                onTap: () => _showOrderDetails(order),
                                onUpdateStatus:
                                    (orderObj, newStatus) =>
                                        _updateOrderStatus(orderObj, newStatus),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: AdminPageBlocks(
                            currentPage: currentPage,
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
}

class AdminOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final Function(OrderModel order, String newStatus) onUpdateStatus;

  const AdminOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onUpdateStatus,
  });

  // Badge de estado de orden (PENDING / COMPLETED / CANCELLED)
  Widget _buildStatusBadge(String status) {
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
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // Badge de estado de pago (PAID / PENDING / PARTIAL) — solo en pedidos COMPLETED
  Widget _buildPaymentStatusBadge(
    String paymentStatus,
    double totalAmount,
    double amountPaid,
  ) {
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

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final date = (order.createdAt ?? DateTime.now()).toLocal();
    final dateString = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    final customerName = order.displayCustomerName;

    // Datos de pago
    final paymentStatus = order.paymentStatus; // 'PAID', 'PENDING', 'PARTIAL'
    final amountPaid = order.amountPaid;
    final totalAmount = order.totalAmount;
    final pendingAmount = totalAmount - amountPaid;
    final isCredit = order.paymentMethod == 'CRÉDITO';
    final warehouseName = order.warehouseName; // del join con warehouses

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── FILA 1: Cliente + Badge de Estado ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre cliente
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
                          // Almacén (si existe)
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badge de estado de orden
                    _buildStatusBadge(status),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // ─── FILA 2: Total + Estado de pago + Botones ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Columna de montos
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

                        // <--- NUEVO: MOSTRAR SI HAY DESCUENTO EXTRA
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
                        // Estado de pago (solo en COMPLETED)
                        if (status == 'COMPLETED') ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildPaymentStatusBadge(
                                paymentStatus,
                                totalAmount,
                                amountPaid,
                              ),
                              // Si hay deuda pendiente, mostrar monto
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
                            onPressed:
                                () => OrderPdfGenerator.generateTicket(order),
                          ),
                        if (status == 'PENDING') ...[
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 22),
                            color: Colors.red.shade400,
                            tooltip: 'Cancelar',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => onUpdateStatus(order, 'CANCELLED'),
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
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Cobrar',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onPressed: () => onUpdateStatus(order, 'COMPLETED'),
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
