import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/order_item_model.dart';
import 'package:inventory_store_app/services/admin/order_pdf_generator.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
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
  String _paymentStatusFilter = 'ALL'; // <-- Filtro de estado de pago
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

  // ─── LÓGICA DE DATOS ────────────────────────────────────────────────────────

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
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

      // Filtro de Estado del Pedido
      if (_statusFilter != 'ALL') {
        query = query.eq('status', _statusFilter);
      }

      // Filtro de Estado de Pago
      if (_paymentStatusFilter != 'ALL') {
        query = query.eq('payment_status', _paymentStatusFilter);
      }

      // Filtro de Fechas
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

      // Búsqueda en memoria por nombre (ya que cruza dos tablas)
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
          _orders = rawData.map((e) => OrderModel.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _currentPage = 0);
      _fetchOrders();
    });
  }

  // NUEVO METODO: Obtener los items y generar el PDF desde la lista
  Future<void> _printOrderTicket(OrderModel order) async {
    try {
      final resp = await _supabase
          .from('order_items')
          .select('''
            id, order_id, product_id, variant_id, quantity, unit_cost,
            applied_price, net_profit, created_at,
            products ( name, uses_batches, product_images(*) ),
            product_variants ( attributes, sku, product_images(*) )
          ''')
          .eq('order_id', order.id);

      final items =
          (resp as List)
              .map(
                (row) =>
                    OrderItemModel.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList();

      await OrderPdfGenerator.printTicket(order, items: items);
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
              '¿Estás seguro de marcar este pedido como ${_statusLabel(newStatus)}?',
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

    // ─── Aviso si el método de pago es 'POR ACORDAR' al completar ───
    if (newStatus == 'COMPLETED' &&
        (order.paymentMethod == 'POR ACORDAR' ||
            order.paymentMethod.trim().isEmpty)) {
      await showDialog<void>(
        // ignore: use_build_context_synchronously
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

      // Logica de completar pedido (Borrado -> Completado)
      if (newStatus == 'COMPLETED' && order.status == 'PENDING') {
        final orderData =
            await _supabase
                .from('orders')
                .select('warehouse_id')
                .eq('id', order.id)
                .single();
        final warehouseId = orderData['warehouse_id'];

        if (order.paymentMethod == 'CRÉDITO') {
          if (order.customerId == null) {
            _showErrorSnackBar('No hay cliente asignado para crédito.');
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
            _showErrorSnackBar('Crédito insuficiente.');
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
            outOfStockMessages.add('Stock insuficiente para un producto.');
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
                  'notes': 'Borrador completado',
                  if (currentUserId != null) 'created_by': currentUserId,
                });
                remainingToDeduct -= deductFromThis;
              }
            }
          }
        }

        if (outOfStockMessages.isNotEmpty) {
          _showErrorSnackBar('Stock insuficiente para procesar orden.');
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
            'notes': 'Activación de pedido',
            if (currentUserId != null) 'created_by': currentUserId,
          });
        } else {
          // Pago directo: registrar ingreso en cuenta financiera
          // Buscar la cuenta activa con ese nombre/método de pago
          final accountsResp = await _supabase
              .from('financial_accounts')
              .select('id, name, type, balance')
              .eq('is_active', true)
              .order('name');

          final accounts = List<Map<String, dynamic>>.from(accountsResp);

          // Intentar encontrar una cuenta cuyo nombre coincida con el método de pago
          // Si no hay coincidencia, usar la primera cuenta activa
          Map<String, dynamic>? targetAccount;
          if (accounts.isNotEmpty) {
            try {
              targetAccount = accounts.firstWhere(
                (a) =>
                    (a['name'] as String).toUpperCase().contains(
                      order.paymentMethod.toUpperCase(),
                    ) ||
                    order.paymentMethod.toUpperCase().contains(
                      (a['name'] as String).toUpperCase(),
                    ),
              );
            } catch (_) {
              targetAccount = accounts.first;
            }
          }

          if (targetAccount != null) {
            // Verificar turno activo si es CAJA
            String? shiftId;
            if (targetAccount['type'] == 'CAJA') {
              final shiftResp =
                  await _supabase
                      .from('cash_shifts')
                      .select('id')
                      .eq('account_id', targetAccount['id'] as String)
                      .eq('status', 'OPEN')
                      .maybeSingle();
              shiftId = shiftResp?['id'] as String?;
            }

            await _supabase.from('account_movements').insert({
              'account_id': targetAccount['id'],
              'movement_type': 'INCOME',
              'amount': order.totalAmount,
              'description': 'Cobro de venta — Pedido #${order.id}',
              'reference_type': 'orders',
              'reference_id': order.id,
              if (shiftId != null) 'shift_id': shiftId,
              if (currentUserId != null) 'created_by': currentUserId,
            });

            final currentBalance =
                (targetAccount['balance'] as num?)?.toDouble() ?? 0.0;
            await _supabase
                .from('financial_accounts')
                .update({'balance': currentBalance + order.totalAmount})
                .eq('id', targetAccount['id'] as String);
          }
        }
      }

      final updates = <String, dynamic>{'status': newStatus};

      if (newStatus == 'COMPLETED') {
        if (order.paymentMethod == 'CRÉDITO') {
          updates['payment_status'] = 'PENDING';
          updates['amount_paid'] = 0;
        } else {
          updates['payment_status'] = 'PAID';
          updates['amount_paid'] = order.totalAmount;
        }
      } else if (newStatus == 'CANCELLED') {
        updates['payment_status'] = 'PAID';
        updates['amount_paid'] = 0;
      }

      await _supabase.from('orders').update(updates).eq('id', order.id);

      // ── WALLET: al completar una orden pendiente ─────────────────────────
      final wasCompleted = order.status == 'COMPLETED';
      final isNowCompleted = newStatus == 'COMPLETED';
      final isCancelling = newStatus == 'CANCELLED';
      final customerId = order.customerId;

      if (!wasCompleted && isNowCompleted && customerId != null) {
        // Leer tasas desde app_settings
        final settingsResp = await _supabase
            .from('app_settings')
            .select('key, value')
            .inFilter('key', ['points_earning_rate', 'points_to_soles_ratio']);
        final settingsMap = {
          for (final r in List<Map<String, dynamic>>.from(settingsResp))
            r['key'] as String: (r['value'] as num).toDouble(),
        };
        final earningRate = settingsMap['points_earning_rate'] ?? 0.1;
        final pointsToSoles = settingsMap['points_to_soles_ratio'] ?? 1.0;
        final pointsEarned =
            pointsToSoles > 0
                ? (order.totalAmount * earningRate / pointsToSoles).toInt()
                : 0;

        // ── Canje (REDEEMED): registrar y descontar balance ───────────────
        if (order.pointsUsed > 0) {
          final redeemedExists =
              await _supabase
                  .from('wallet_movements')
                  .select('id')
                  .eq('order_id', order.id)
                  .eq('movement_type', 'REDEEMED')
                  .maybeSingle();
          if (redeemedExists == null) {
            await _supabase.from('wallet_movements').insert({
              'profile_id': customerId,
              'order_id': order.id,
              'points': -order.pointsUsed,
              'movement_type': 'REDEEMED',
              'description': 'Canje aplicado al completar pedido #${order.id}',
            });
            final profileData =
                await _supabase
                    .from('profiles')
                    .select('wallet_balance')
                    .eq('id', customerId)
                    .maybeSingle();
            if (profileData != null) {
              final curBal =
                  (profileData['wallet_balance'] as num?)?.toInt() ?? 0;
              await _supabase
                  .from('profiles')
                  .update({
                    'wallet_balance': (curBal - order.pointsUsed).clamp(
                      0,
                      curBal,
                    ),
                  })
                  .eq('id', customerId);
            }
          }
        }

        // ── Monedas ganadas (EARNED): registrar y acreditar balance ──────
        if (pointsEarned > 0) {
          final earnedExists =
              await _supabase
                  .from('wallet_movements')
                  .select('id')
                  .eq('order_id', order.id)
                  .eq('movement_type', 'EARNED')
                  .maybeSingle();
          if (earnedExists == null) {
            await _supabase.from('wallet_movements').insert({
              'profile_id': customerId,
              'order_id': order.id,
              'points': pointsEarned,
              'movement_type': 'EARNED',
              'description':
                  'Monedas obtenidas al completar pedido #${order.id}',
            });
            final profileData =
                await _supabase
                    .from('profiles')
                    .select('wallet_balance')
                    .eq('id', customerId)
                    .maybeSingle();
            if (profileData != null) {
              final curBal =
                  (profileData['wallet_balance'] as num?)?.toInt() ?? 0;
              await _supabase
                  .from('profiles')
                  .update({'wallet_balance': curBal + pointsEarned})
                  .eq('id', customerId);
            }
            // Guardar points_earned en la orden
            await _supabase
                .from('orders')
                .update({'points_earned': pointsEarned})
                .eq('id', order.id);
          }
        }
      }

      // ── WALLET: al cancelar — revertir EARNED y devolver REDEEMED ───────
      if (isCancelling && customerId != null) {
        // Revertir monedas EARNED
        final earnedMov =
            await _supabase
                .from('wallet_movements')
                .select('id, points')
                .eq('order_id', order.id)
                .eq('movement_type', 'EARNED')
                .maybeSingle();
        if (earnedMov != null) {
          final pts = (earnedMov['points'] as num).toInt();
          final profileData =
              await _supabase
                  .from('profiles')
                  .select('wallet_balance')
                  .eq('id', customerId)
                  .maybeSingle();
          if (profileData != null) {
            final curBal =
                (profileData['wallet_balance'] as num?)?.toInt() ?? 0;
            await _supabase
                .from('profiles')
                .update({'wallet_balance': (curBal - pts).clamp(0, curBal)})
                .eq('id', customerId);
          }
          await _supabase.from('wallet_movements').insert({
            'profile_id': customerId,
            'order_id': order.id,
            'points': -pts,
            'movement_type': 'ADJUSTMENT',
            'description':
                'Reversión de monedas por cancelación de pedido #${order.id}',
          });
        }

        // Devolver monedas canjeadas REDEEMED
        final redeemedMov =
            await _supabase
                .from('wallet_movements')
                .select('id, points')
                .eq('order_id', order.id)
                .eq('movement_type', 'REDEEMED')
                .maybeSingle();
        if (redeemedMov != null) {
          final ptsCanjeados = (redeemedMov['points'] as num).toInt().abs();
          final profileData =
              await _supabase
                  .from('profiles')
                  .select('wallet_balance')
                  .eq('id', customerId)
                  .maybeSingle();
          if (profileData != null) {
            final curBal =
                (profileData['wallet_balance'] as num?)?.toInt() ?? 0;
            await _supabase
                .from('profiles')
                .update({'wallet_balance': curBal + ptsCanjeados})
                .eq('id', customerId);
          }
          await _supabase.from('wallet_movements').insert({
            'profile_id': customerId,
            'order_id': order.id,
            'points': ptsCanjeados,
            'movement_type': 'ADJUSTMENT',
            'description':
                'Devolución de monedas canjeadas por cancelación #${order.id}',
          });
        }
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Estado actualizado correctamente',
          type: SnackbarType.success,
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
      AppSnackbar.show(context, message: msg, type: SnackbarType.error);
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

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      initialEntryMode: DatePickerEntryMode.input,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _currentPage = 0;
      });
      _fetchOrders();
    }
  }

  // ─── FILTROS DISEÑO "CHIP" DESPLEGABLES ────────────────────────────────

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
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
          items:
              items.map((item) {
                return DropdownMenuItem<String>(
                  value: item.value,
                  child: Row(
                    children: [
                      Text(
                        '$label ',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      item.child,
                    ],
                  ),
                );
              }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDateFilterButton() {
    final hasDate = _dateRange != null;
    return InkWell(
      onTap: _pickDateRange,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color:
              hasDate ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasDate ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: hasDate ? AppColors.primary : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              hasDate
                  ? '${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}'
                  : 'Fechas',
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasDate ? FontWeight.w700 : FontWeight.w600,
                color: hasDate ? AppColors.primary : Colors.black87,
              ),
            ),
            if (hasDate) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() => _dateRange = null);
                  _fetchOrders();
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 10,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── BUILD PRINCIPAL ───────────────────────────────────────────────────

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
          // --- BUSCADOR ---
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
                            _fetchOrders();
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

          // --- BARRA DE FILTROS ---
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _buildDropdownFilter(
                  label: '',
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
                    _fetchOrders();
                  },
                ),
                const SizedBox(width: 8),
                _buildDropdownFilter(
                  label: '',
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
                    _fetchOrders();
                  },
                ),
                const SizedBox(width: 8),
                _buildDateFilterButton(),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
                          child: RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: () async => _fetchOrders(),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: pageItems.length,
                              itemBuilder: (context, index) {
                                final order = pageItems[index];
                                return AdminOrderCard(
                                  order: order,
                                  onTap: () => _showOrderDetails(order),
                                  onUpdateStatus:
                                      (orderObj, newStatus) =>
                                          _updateOrderStatus(
                                            orderObj,
                                            newStatus,
                                          ),
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
}

class AdminOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final Function(OrderModel order, String newStatus) onUpdateStatus;
  final VoidCallback onPrint;

  const AdminOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onUpdateStatus,
    required this.onPrint,
  });

  // Badge de estado de orden
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
        ),
      ),
    );
  }

  // Badge de estado de pago
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

    // Extraemos los primeros 8 caracteres del ID para la vista rápida
    final shortId = order.id.substring(0, 8).toUpperCase();

    // Lógica dinámica de pago en la tarjeta
    final isCredit = order.paymentMethod == 'CRÉDITO';
    String paymentStatus = order.paymentStatus;
    double amountPaid = order.amountPaid;

    if (status == 'COMPLETED' && !isCredit) {
      paymentStatus = 'PAID';
      amountPaid = order.totalAmount;
    }

    final totalAmount = order.totalAmount;
    final pendingAmount = totalAmount - amountPaid;
    final warehouseName = order.warehouseName;

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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── FILA 1: Info Cliente e ID
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // NUEVO: Etiqueta con el ID del pedido
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
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // ── FILA 2: Totales y Botones
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
                            onPressed: onPrint,
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
