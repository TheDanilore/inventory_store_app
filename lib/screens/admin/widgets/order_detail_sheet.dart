import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/services/admin/order_pdf_generator.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/order_item_model.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── MODELO INTERNO: Segmento de lote asignado a un ítem ────────────────────
class BatchAssignment {
  final String batchId;
  final String batchNumber;
  final DateTime? expiryDate;
  final int available;
  int assigned;

  BatchAssignment({
    required this.batchId,
    required this.batchNumber,
    this.expiryDate,
    required this.available,
    required this.assigned,
  });

  BatchAssignment copyWith({int? assigned}) => BatchAssignment(
    batchId: batchId,
    batchNumber: batchNumber,
    expiryDate: expiryDate,
    available: available,
    assigned: assigned ?? this.assigned,
  );

  String get expiryLabel {
    if (expiryDate == null) return 'Sin vto.';
    final d = expiryDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));
  }
}

class OrderDetailSheet extends StatefulWidget {
  final OrderModel order;

  const OrderDetailSheet({super.key, required this.order});

  @override
  State<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<OrderDetailSheet> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _customerSearchCtrl = TextEditingController();
  final TextEditingController _pointsUsedCtrl = TextEditingController();

  List<OrderItemModel> _items = [];
  List<TextEditingController> _quantityControllers = [];
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _accounts = []; // NUEVO: Cuentas financieras

  Map<String, List<Map<String, dynamic>>> _batchesByVariant = {};
  final Map<String, bool> _usesBatchesMap = {};
  final Map<String, List<BatchAssignment>> _batchOverrides = {};

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  String? _selectedCustomerId;
  String _currentStatus = '';
  String _paymentMethod = 'EFECTIVO';
  int _pointsUsed = 0;
  int _pointsEarned = 0;

  bool get _isCompleted => _currentStatus.toUpperCase() == 'COMPLETED';
  bool get _isCancelled => _currentStatus.toUpperCase() == 'CANCELLED';
  bool get _canToggleEdit => widget.order.status.toUpperCase() != 'CANCELLED';

  String get _currentPaymentStatus {
    if (_isEditing) {
      if (_paymentMethod == 'CRÉDITO') return 'PENDING';
      if (_currentStatus == 'CANCELLED') return 'PAID';
      if (_currentStatus == 'COMPLETED') return 'PAID';
      return 'PENDING';
    }
    return widget.order.paymentStatus;
  }

  double get _currentAmountPaid {
    if (_isEditing) {
      if (_paymentMethod == 'CRÉDITO' || _currentStatus != 'COMPLETED') {
        return 0.0;
      }
      return _calculateOrderFinalAmount();
    }
    return widget.order.amountPaid;
  }

  List<Map<String, dynamic>> get _filteredProfiles {
    final query = _customerSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _profiles;

    return _profiles.where((profile) {
      final name = (profile['full_name'] as String? ?? '').toLowerCase();
      final phone = (profile['phone'] as String? ?? '').toLowerCase();
      final document =
          (profile['document_number'] as String? ?? '').toLowerCase();
      return name.contains(query) ||
          phone.contains(query) ||
          document.contains(query);
    }).toList();
  }

  Map<String, dynamic>? _creditInfo;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.order.customerId;
    _currentStatus = widget.order.status;
    _pointsUsed = widget.order.pointsUsed;
    _pointsEarned = widget.order.pointsEarned;
    _paymentMethod = widget.order.paymentMethod;
    _pointsUsedCtrl.text = _pointsUsed.toString();
    _fetchData();
  }

  @override
  void dispose() {
    _customerSearchCtrl.dispose();
    _pointsUsedCtrl.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _customerLabelFor(String? customerId) {
    if (customerId == null) {
      final manualName = widget.order.displayCustomerName.trim();
      return manualName.isNotEmpty ? manualName : 'Cliente mostrador';
    }
    if (customerId == widget.order.customerId) {
      final embeddedName = widget.order.profileFullName?.trim();
      if (embeddedName != null && embeddedName.isNotEmpty) {
        return embeddedName;
      }
      final manualName = widget.order.displayCustomerName.trim();
      if (manualName.isNotEmpty && manualName != 'Cliente mostrador') {
        return manualName;
      }
    }
    if (_profiles.isNotEmpty) {
      try {
        final profile = _profiles.firstWhere((p) => p['id'] == customerId);
        final name = (profile['full_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) return name;
      } catch (_) {}
    }
    if (_isLoading && customerId == widget.order.customerId) {
      return widget.order.displayCustomerName.trim().isNotEmpty
          ? widget.order.displayCustomerName
          : 'Cargando...';
    }
    return 'Cliente mostrador';
  }

  void _selectCustomer(String customerId) {
    if (!_isEditing) return;
    setState(() {
      _selectedCustomerId = customerId;
      _creditInfo = null;
    });
    _loadCreditInfo(customerId);
  }

  Future<void> _loadCreditInfo(String profileId) async {
    try {
      final resp =
          await _supabase
              .from('customer_credits')
              .select('id, credit_limit, current_debt, is_active')
              .eq('profile_id', profileId)
              .maybeSingle();
      if (mounted) setState(() => _creditInfo = resp);
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    try {
      final futures = <Future>[
        _supabase
            .from('order_items')
            .select('''
              id, order_id, product_id, variant_id, quantity, unit_cost,
              applied_price, net_profit, created_at,
              products ( name, uses_batches, product_images(*) ),
              product_variants ( attributes, sku, product_images(*) )
            ''')
            .eq('order_id', widget.order.id),
        _supabase
            .from('profiles')
            .select('id, full_name, phone, document_number, role, is_active')
            .eq('is_active', true)
            .order('full_name'),
        _supabase
            .from('financial_accounts')
            .select('id, name, type')
            .eq('is_active', true)
            .order('name'),
      ];

      if (_selectedCustomerId != null) {
        futures.add(
          _supabase
              .from('customer_credits')
              .select('id, credit_limit, current_debt, is_active')
              .eq('profile_id', _selectedCustomerId!)
              .maybeSingle(),
        );
      }

      final results = await Future.wait(futures);
      if (!mounted) return;

      final itemsRaw = results[0] as List;

      final items =
          itemsRaw.map((row) {
            final variantId = row['variant_id'] as String?;
            final prod = row['products'] as Map<String, dynamic>?;
            if (variantId != null && prod != null) {
              _usesBatchesMap[variantId] = prod['uses_batches'] == true;
            }
            return OrderItemModel.fromJson(Map<String, dynamic>.from(row));
          }).toList();

      List<Map<String, dynamic>> profiles = List<Map<String, dynamic>>.from(
        results[1],
      );
      List<Map<String, dynamic>> accounts = List<Map<String, dynamic>>.from(
        results[2],
      );

      final currentCustomerId = _selectedCustomerId ?? widget.order.customerId;
      if (currentCustomerId != null &&
          !profiles.any((p) => p['id'] == currentCustomerId)) {
        try {
          final missingProfile =
              await _supabase
                  .from('profiles')
                  .select(
                    'id, full_name, phone, document_number, role, is_active',
                  )
                  .eq('id', currentCustomerId)
                  .maybeSingle();
          if (missingProfile != null) profiles = [missingProfile, ...profiles];
        } catch (_) {}
      }

      setState(() {
        _items = items;
        _profiles = profiles;
        _accounts = accounts;
        if (results.length > 3) {
          _creditInfo = results[3] as Map<String, dynamic>?;
        }
        _pointsEarned = _calculatePointsEarned();
        _isLoading = false;
      });

      _quantityControllers =
          _items
              .map(
                (item) => TextEditingController(text: item.quantity.toString()),
              )
              .toList();

      if (widget.order.status.toUpperCase() == 'COMPLETED') {
        _fetchBatchMovements();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error cargando datos: $e');
    }
  }

  Future<void> _fetchBatchMovements() async {
    try {
      final resp = await _supabase
          .from('inventory_movements')
          .select('''
      variant_id, quantity,
      warehouse_stock_batches!inner ( batch_number, expiry_date )
    ''')
          .eq('order_id', widget.order.id)
          .eq('reason', 'SALE')
          .neq('warehouse_stock_batches.batch_number', 'DEFAULT');

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final row in (resp as List)) {
        final variantId = row['variant_id'] as String? ?? '';
        final batch = row['warehouse_stock_batches'] as Map<String, dynamic>?;
        if (batch == null) continue;
        grouped.putIfAbsent(variantId, () => []).add({
          'batch_number': batch['batch_number'] ?? '',
          'expiry_date': batch['expiry_date'],
          'quantity': ((row['quantity'] as num?)?.toInt() ?? 0).abs(),
        });
      }

      if (mounted) setState(() => _batchesByVariant = grouped);
    } catch (e) {
      debugPrint('Error cargando lotes: $e');
    }
  }

  // ─── EDICIÓN DE LOTES (BOTTOM SHEET) ────────────────────────────────────────

  Future<void> _showBatchEditSheet(OrderItemModel item) async {
    final warehouseId = widget.order.warehouseId;
    if (warehouseId == null) return;

    List<BatchAssignment> batches;
    try {
      final resp = await _supabase
          .from('warehouse_stock_batches')
          .select('id, batch_number, expiry_date, available_quantity')
          .eq('variant_id', item.variantId ?? '')
          .eq('warehouse_id', warehouseId)
          .neq('batch_number', 'DEFAULT')
          .gt('available_quantity', 0)
          .order('expiry_date', ascending: true, nullsFirst: false);

      batches =
          (resp as List)
              .map(
                (b) => BatchAssignment(
                  batchId: b['id'] as String,
                  batchNumber: b['batch_number'] as String,
                  expiryDate:
                      b['expiry_date'] != null
                          ? DateTime.tryParse(b['expiry_date'] as String)
                          : null,
                  available: (b['available_quantity'] as num).toInt(),
                  assigned: 0,
                ),
              )
              .toList();
    } catch (e) {
      _showErrorSnackBar('Error cargando lotes: $e');
      return;
    }

    if (batches.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'No hay lotes con stock para este producto.',
        type: SnackbarType.warning,
      );
      return;
    }

    final saved = _batchOverrides[item.id ?? ''];
    if (saved != null) {
      for (final s in saved) {
        final idx = batches.indexWhere((b) => b.batchId == s.batchId);
        if (idx >= 0) batches[idx].assigned = s.assigned;
      }
    } else {
      int remaining = item.quantity;
      for (final b in batches) {
        if (remaining <= 0) break;
        b.assigned = (remaining > b.available) ? b.available : remaining;
        remaining -= b.assigned;
      }
    }

    if (!mounted) return;
    final result = await showModalBottomSheet<List<BatchAssignment>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _BatchEditSheet(
            productName: item.productName ?? 'Producto',
            variantLabel: item.variantLabel,
            totalRequired: item.quantity,
            batches: batches,
          ),
    );

    if (result != null && mounted) {
      setState(() {
        _batchOverrides[item.id ?? ''] = result;
      });
    }
  }

  void _changeQuantity(int index, int delta) {
    if (!_isEditing) return;
    setState(() {
      final currentQty = _items[index].quantity;
      final nextValue = (currentQty + delta) < 1 ? 1 : currentQty + delta;
      _items[index].quantity = nextValue;
      _quantityControllers[index].text = nextValue.toString();
      _quantityControllers[index].selection = TextSelection.collapsed(
        offset: _quantityControllers[index].text.length,
      );
      _pointsEarned = _calculatePointsEarned();
      _batchOverrides.remove(_items[index].id);
    });
  }

  void _setQuantity(int index, String value) {
    if (!_isEditing) return;
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return;

    setState(() {
      final nextValue = parsed < 1 ? 1 : parsed;
      _items[index].quantity = nextValue;
      _quantityControllers[index].text = nextValue.toString();
      _quantityControllers[index].selection = TextSelection.collapsed(
        offset: _quantityControllers[index].text.length,
      );
      _pointsEarned = _calculatePointsEarned();
      _batchOverrides.remove(_items[index].id);
    });
  }

  double _calculateOrderTotalAmount() {
    return _items.fold<double>(0, (sum, item) => sum + item.subtotal);
  }

  double _calculateOrderFinalAmount([double? subtotal]) {
    final subtotalAmount = subtotal ?? _calculateOrderTotalAmount();
    final pointsToSolesRatio = context.read<AppConfigProvider>().getDouble(
      'points_to_soles_ratio',
      0.01,
    );
    final discountValue = _pointsUsed * pointsToSolesRatio;
    final maxDiscountValue = subtotalAmount * 0.5;
    final appliedDiscount =
        discountValue > maxDiscountValue ? maxDiscountValue : discountValue;
    final finalAmount =
        subtotalAmount - appliedDiscount - widget.order.discountAmount;
    return finalAmount < 0 ? 0 : finalAmount;
  }

  int _calculatePointsEarned([double? finalAmount]) {
    final amountFinal = finalAmount ?? _calculateOrderFinalAmount();
    final earningRate = context.read<AppConfigProvider>().getDouble(
      'points_earning_rate',
      0.03,
    );
    final pointsToSolesRatio = context.read<AppConfigProvider>().getDouble(
      'points_to_soles_ratio',
      0.01,
    );
    return (amountFinal * earningRate / pointsToSolesRatio).toInt();
  }

  double _calculateOrderTotalProfit() {
    return _items.fold<double>(
      0,
      (sum, item) =>
          sum + ((item.appliedPrice - item.unitCost) * item.quantity),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final wasCompleted = widget.order.status.toUpperCase() == 'COMPLETED';
      final isNowCompleted = _currentStatus.toUpperCase() == 'COMPLETED';
      final isNowCancelled = _currentStatus.toUpperCase() == 'CANCELLED';

      final authUserId = _supabase.auth.currentUser?.id;
      String? currentProfileId;
      if (authUserId != null) {
        final profileResp =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        if (profileResp != null) currentProfileId = profileResp['id'] as String;
      }

      final nextPointsUsed = int.tryParse(_pointsUsedCtrl.text.trim()) ?? 0;
      _pointsUsed = nextPointsUsed < 0 ? 0 : nextPointsUsed;

      final subtotalAmount = _calculateOrderTotalAmount();
      final totalAmount = _calculateOrderFinalAmount(subtotalAmount);
      final totalProfit = _calculateOrderTotalProfit();
      _pointsEarned = _calculatePointsEarned(totalAmount);

      // ─── 2. ACTIVAR UN BORRADOR (PENDING -> COMPLETED) ───
      if (!wasCompleted && isNowCompleted) {
        final orderData =
            await _supabase
                .from('orders')
                .select('warehouse_id')
                .eq('id', widget.order.id)
                .single();
        final warehouseId = orderData['warehouse_id'];

        if (_paymentMethod == 'CRÉDITO') {
          if (_selectedCustomerId == null) {
            _showErrorSnackBar(
              'No hay cliente asignado para validar el crédito.',
            );
            setState(() => _isSaving = false);
            return;
          }
          final creditInfo =
              await _supabase
                  .from('customer_credits')
                  .select('id, credit_limit, current_debt, is_active')
                  .eq('profile_id', _selectedCustomerId!)
                  .maybeSingle();
          if (creditInfo == null || creditInfo['is_active'] != true) {
            _showErrorSnackBar('El cliente no tiene línea de crédito activa.');
            setState(() => _isSaving = false);
            return;
          }
          final availableCredit =
              (creditInfo['credit_limit'] as num).toDouble() -
              (creditInfo['current_debt'] as num).toDouble();
          if (availableCredit < totalAmount) {
            _showErrorSnackBar(
              'Crédito insuficiente. Disponible: S/ ${availableCredit.toStringAsFixed(2)}',
            );
            setState(() => _isSaving = false);
            return;
          }
        }

        List<String> outOfStockMessages = [];
        List<Map<String, dynamic>> batchesToUpdate = [];
        List<Map<String, dynamic>> movementsToInsert = [];

        for (final item in _items) {
          final safeVariantId = item.variantId ?? '';
          final qtyNeeded = item.quantity;
          List<({String id, int take, int available, String batchNumber})>
          segments = [];

          final overrides = _batchOverrides[item.id ?? ''];

          if (overrides != null) {
            final totalAssigned = overrides.fold(0, (s, b) => s + b.assigned);
            if (totalAssigned != qtyNeeded) {
              _showErrorSnackBar(
                'Asignación de lotes inválida para ${item.productName ?? 'Producto'}.',
              );
              setState(() => _isSaving = false);
              return;
            }
            for (final b in overrides) {
              if (b.assigned > 0) {
                segments.add((
                  id: b.batchId,
                  take: b.assigned,
                  available: b.available,
                  batchNumber: b.batchNumber,
                ));
              }
            }
          } else {
            // FEFO Automático
            final batchesResp = await _supabase
                .from('warehouse_stock_batches')
                .select('id, available_quantity, batch_number')
                .eq('warehouse_id', warehouseId)
                .eq('variant_id', safeVariantId)
                .gt('available_quantity', 0)
                .order('expiry_date', ascending: true, nullsFirst: false);

            final batches = List<Map<String, dynamic>>.from(batchesResp);
            int remaining = qtyNeeded;
            for (final batch in batches) {
              if (remaining <= 0) break;
              final available = (batch['available_quantity'] as num).toInt();
              final take = remaining > available ? available : remaining;
              segments.add((
                id: batch['id'],
                take: take,
                available: available,
                batchNumber: batch['batch_number'],
              ));
              remaining -= take;
            }
            if (remaining > 0) {
              final currentStock = segments.fold(
                0,
                (s, seg) => s + seg.available,
              );
              outOfStockMessages.add(
                '• ${item.productName} - ${item.variantLabel} (Stock real: $currentStock, Pedido: $qtyNeeded)',
              );
              continue;
            }
          }

          // Construir updates de base de datos
          for (final seg in segments) {
            batchesToUpdate.add({
              'id': seg.id,
              'available_quantity': seg.available - seg.take,
            });
            movementsToInsert.add({
              'variant_id': safeVariantId,
              'warehouse_id': warehouseId,
              'stock_batch_id': seg.id,
              'order_id': widget.order.id,
              'quantity': -seg.take,
              'previous_stock': seg.available,
              'new_stock': seg.available - seg.take,
              'reason': 'SALE',
              'notes':
                  'Pedido completado desde detalles · Lote: ${seg.batchNumber}',
              if (currentProfileId != null) 'created_by': currentProfileId,
            });
          }
        }

        if (outOfStockMessages.isNotEmpty) {
          _showStockErrorDialog(outOfStockMessages);
          setState(() => _isSaving = false);
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

        if (_paymentMethod == 'CRÉDITO') {
          final creditResp =
              await _supabase
                  .from('customer_credits')
                  .select('id, current_debt')
                  .eq('profile_id', _selectedCustomerId!)
                  .single();
          final creditId = creditResp['id'];
          final newDebt =
              (creditResp['current_debt'] as num).toDouble() + totalAmount;
          await _supabase
              .from('customer_credits')
              .update({'current_debt': newDebt})
              .eq('id', creditId);
          await _supabase.from('credit_movements').insert({
            'credit_id': creditId,
            'order_id': widget.order.id,
            'movement_type': 'CHARGE',
            'amount': totalAmount,
            'notes': 'Activación de pedido desde detalles',
            if (currentProfileId != null) 'created_by': currentProfileId,
          });
        }
      }
      // ─── 3. CANCELAR UN PEDIDO COMPLETADO (COMPLETED -> CANCELLED) ───
      else if (wasCompleted && isNowCancelled) {
        final orderData =
            await _supabase
                .from('orders')
                .select(
                  'warehouse_id, total_amount, payment_method, customer_id',
                )
                .eq('id', widget.order.id)
                .single();

        final warehouseId = orderData['warehouse_id'];
        final origAmount = (orderData['total_amount'] as num).toDouble();
        final origPaymentMethod = orderData['payment_method'] as String;
        final origCustomerId = orderData['customer_id'] as String?;

        for (final item in _items) {
          final safeVariantId = item.variantId ?? '';

          final movs = await _supabase
              .from('inventory_movements')
              .select('quantity, stock_batch_id')
              .eq('order_id', widget.order.id)
              .eq('variant_id', safeVariantId)
              .eq('reason', 'SALE');

          for (final mov in (movs as List)) {
            final batchId = mov['stock_batch_id'];
            final qtyDeducted =
                ((mov['quantity'] as num).toDouble()).abs().toInt();

            if (batchId != null && qtyDeducted > 0) {
              final batchResp =
                  await _supabase
                      .from('warehouse_stock_batches')
                      .select('available_quantity')
                      .eq('id', batchId)
                      .maybeSingle();

              if (batchResp != null) {
                final currentStock =
                    (batchResp['available_quantity'] as num).toInt();
                final newStock = currentStock + qtyDeducted;

                await _supabase
                    .from('warehouse_stock_batches')
                    .update({'available_quantity': newStock})
                    .eq('id', batchId);

                await _supabase.from('inventory_movements').insert({
                  'variant_id': safeVariantId,
                  'warehouse_id': warehouseId,
                  'stock_batch_id': batchId,
                  'order_id': widget.order.id,
                  'quantity': qtyDeducted,
                  'previous_stock': currentStock,
                  'new_stock': newStock,
                  'reason': 'RETURN',
                  'notes': 'Devolución por cancelación desde detalles',
                  if (currentProfileId != null) 'created_by': currentProfileId,
                });
              }
            }
          }
        }

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
                (currentDebt - origAmount) < 0 ? 0 : (currentDebt - origAmount);
            await _supabase
                .from('customer_credits')
                .update({
                  'current_debt': newDebt,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', creditId);
            await _supabase.from('credit_movements').insert({
              'credit_id': creditId,
              'order_id': widget.order.id,
              'movement_type': 'PAYMENT',
              'amount': origAmount,
              'notes': 'Reembolso por cancelación de pedido',
              if (currentProfileId != null) 'created_by': currentProfileId,
            });
          }
        }

        if (origCustomerId != null) {
          final earnedMov =
              await _supabase
                  .from('wallet_movements')
                  .select('id, points')
                  .eq('order_id', widget.order.id)
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
              'order_id': widget.order.id,
              'points': -ptsGanados,
              'movement_type': 'ADJUSTMENT',
              'description': 'Reversión de monedas por cancelación de pedido',
            });
          }
          final redeemedMov =
              await _supabase
                  .from('wallet_movements')
                  .select('id, points')
                  .eq('order_id', widget.order.id)
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
                'order_id': widget.order.id,
                'points': ptsCanjeados,
                'movement_type': 'ADJUSTMENT',
                'description':
                    'Devolución de monedas canjeadas por cancelación',
              });
            }
          }
        }
      }

      // ─── 4. ACTUALIZAR ORDEN Y PAGOS ───
      if (isNowCompleted &&
          (_paymentMethod == 'POR ACORDAR' || _paymentMethod.trim().isEmpty)) {
        _paymentMethod =
            _accounts.isNotEmpty ? _accounts.first['name'] : 'EFECTIVO';
      }

      if (_paymentMethod == 'CRÉDITO') {
        _pointsUsed = 0;
        _pointsEarned = 0;
      }

      String paymentStatus;
      double amountPaid;
      if (_paymentMethod == 'CRÉDITO') {
        paymentStatus = 'PENDING';
        amountPaid = 0;
      } else if (isNowCancelled) {
        paymentStatus = 'PAID';
        amountPaid = 0;
      } else {
        paymentStatus = 'PAID';
        amountPaid = totalAmount;
      }

      await _supabase
          .from('orders')
          .update({
            'customer_id': _selectedCustomerId,
            'status': _currentStatus,
            'payment_method': _paymentMethod,
            'payment_status': paymentStatus,
            'amount_paid': amountPaid,
            'total_amount': totalAmount,
            'total_profit': totalProfit,
            'points_used': _pointsUsed,
            'points_earned': _pointsEarned,
          })
          .eq('id', widget.order.id);

      // ─── 5. FIDELIDAD (WALLET PUNTOS) ───
      if (!wasCompleted && isNowCompleted && _selectedCustomerId != null) {
        if (_pointsUsed > 0) {
          final redemptionExists =
              await _supabase
                  .from('wallet_movements')
                  .select('id')
                  .eq('order_id', widget.order.id)
                  .eq('movement_type', 'REDEEMED')
                  .maybeSingle();
          if (redemptionExists == null) {
            await _supabase.from('wallet_movements').insert({
              'profile_id': _selectedCustomerId,
              'order_id': widget.order.id,
              'points': -_pointsUsed,
              'movement_type': 'REDEEMED',
              'description':
                  'Canje aplicado al completar pedido #${widget.order.id}',
            });
          }
        }
        if (_pointsEarned > 0) {
          final earnedExists =
              await _supabase
                  .from('wallet_movements')
                  .select('id')
                  .eq('order_id', widget.order.id)
                  .eq('movement_type', 'EARNED')
                  .maybeSingle();
          if (earnedExists == null) {
            await _supabase.from('wallet_movements').insert({
              'profile_id': _selectedCustomerId,
              'order_id': widget.order.id,
              'points': _pointsEarned,
              'movement_type': 'EARNED',
              'description':
                  'Monedas obtenidas al completar pedido #${widget.order.id}',
            });
          }
        }
      }

      // ─── 6. ACTUALIZAR ITEMS INDIVIDUALES ───
      for (final item in _items) {
        await _supabase
            .from('order_items')
            .update({
              'quantity': item.quantity,
              'net_profit': (item.appliedPrice - item.unitCost) * item.quantity,
            })
            .eq('id', item.id ?? '');
      }

      if (!mounted) return;
      setState(() => _isEditing = false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showErrorSnackBar(String msg) {
    if (mounted) {
      AppSnackbar.show(context, message: msg, type: SnackbarType.error);
    }
  }

  void _showStockErrorDialog(List<String> messages) {
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
                'El stock varió y ya no hay disponibilidad para completar este pedido:\n\n${messages.join('\n')}',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
  }

  @override
  Widget build(BuildContext context) {
    final pointsToSolesRatio = context.watch<AppConfigProvider>().getDouble(
      'points_to_soles_ratio',
      0.01,
    );
    final subtotal = _calculateOrderTotalAmount();

    // Permitimos editar lotes si estamos editando y el pedido estaba PENDING
    final bool isActivatingDraft =
        _isEditing && widget.order.status.toUpperCase() == 'PENDING';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OrderDetailHeaderRow(
              orderId: widget.order.id,
              isCompleted: _isCompleted,
              isEditing: _isEditing,
              canToggleEdit: _canToggleEdit,
              onToggleEditing: () => setState(() => _isEditing = !_isEditing),
              onPrint:
                  () => OrderPdfGenerator.generateTicket(
                    widget.order,
                    items: _items,
                  ),
            ),
            const Divider(),

            // ─── NUEVO: SECCIÓN DE ESTADO DEL PEDIDO ───
            OrderDetailStatusSection(
              currentStatus: _currentStatus,
              originalStatus: widget.order.status,
              isEditing: _isEditing,
              onChanged: (newStatus) {
                if (newStatus != null) {
                  setState(() => _currentStatus = newStatus);
                }
              },
            ),

            if (_isCompleted)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      _isEditing ? Colors.orange.shade50 : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        _isEditing
                            ? Colors.orange.shade300
                            : Colors.teal.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isEditing
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_rounded,
                      color:
                          _isEditing
                              ? Colors.orange.shade800
                              : Colors.teal.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isEditing
                            ? 'Este pedido ya está COMPLETADO. Es totalmente seguro cambiar el cliente o el método de pago. Evita alterar cantidades si no deseas provocar desfases en el inventario actual.'
                            : 'Este pedido ya ha sido finalizado con éxito. Los movimientos de inventario y monedas de fidelidad correspondientes ya fueron consolidados.',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _isEditing
                                  ? Colors.orange.shade900
                                  : Colors.teal.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            OrderDetailCustomerSection(
              isEditing: _isEditing,
              searchController: _customerSearchCtrl,
              filteredProfiles: _filteredProfiles,
              selectedCustomerLabel: _customerLabelFor(_selectedCustomerId),
              selectedCustomerId: _selectedCustomerId,
              onSearchChanged: () => setState(() {}),
              onClearSearch: () => setState(() => _customerSearchCtrl.clear()),
              onSelectCustomer: _selectCustomer,
            ),

            OrderDetailPaymentSection(
              currentPaymentMethod: _paymentMethod,
              isEditing: _isEditing,
              accounts: _accounts, // NUEVO: Pasamos las cuentas
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _paymentMethod = val;
                    if (val == 'CRÉDITO') {
                      _pointsUsed = 0;
                      _pointsUsedCtrl.text = '0';
                      _pointsEarned = _calculatePointsEarned();
                    }
                  });
                  if (val == 'CRÉDITO' && _selectedCustomerId != null) {
                    _loadCreditInfo(_selectedCustomerId!);
                  }
                }
              },
            ),

            if (_paymentMethod == 'CRÉDITO')
              _CreditInfoSection(
                creditInfo: _creditInfo,
                customerId: _selectedCustomerId,
              ),

            if (_isCompleted)
              _PaymentStatusSection(
                paymentStatus: _currentPaymentStatus,
                totalAmount: _calculateOrderFinalAmount(),
                amountPaid: _currentAmountPaid,
                paymentMethod: _paymentMethod,
                creditInfo: _creditInfo,
                orderId: widget.order.id,
                supabase: _supabase,
                onPaymentRegistered: () {
                  _fetchData();
                  Navigator.pop(context, true);
                },
              ),

            OrderDetailPointsSection(
              pointsUsed: _pointsUsed,
              pointsEarned: _pointsEarned,
              isEditing: _isEditing,
              pointsUsedController: _pointsUsedCtrl,
              onPointsUsedChanged: (val) {
                setState(() {
                  _pointsUsed = int.tryParse(val) ?? 0;
                  if (_pointsUsed < 0) _pointsUsed = 0;
                  _pointsEarned = _calculatePointsEarned();
                });
              },
            ),
            OrderDetailTotalSummarySection(
              subtotal: subtotal,
              pointsUsed: _pointsUsed,
              pointsEarned: _pointsEarned,
              pointsToSolesRatio: pointsToSolesRatio,
              discountAmount: widget.order.discountAmount,
            ),
            OrderDetailItemsSection(
              items: _items,
              isLoading: _isLoading,
              isEditing: _isEditing,
              isLocked: _isCompleted || _isCancelled,
              batchesByVariant: _batchesByVariant,
              usesBatchesMap: _usesBatchesMap,
              batchOverrides: _batchOverrides,
              quantityControllers: _quantityControllers,
              onDecrease: (index) => _changeQuantity(index, -1),
              onIncrease: (index) => _changeQuantity(index, 1),
              onQuantityChanged: (index, value) => _setQuantity(index, value),
              onEditBatches: isActivatingDraft ? _showBatchEditSheet : null,
            ),
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    child:
                        _isSaving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Guardar Cambios'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── NUEVO COMPONENTE: SELECTOR DE ESTADO ───
class OrderDetailStatusSection extends StatelessWidget {
  final String currentStatus;
  final String originalStatus;
  final bool isEditing;
  final ValueChanged<String?> onChanged;

  const OrderDetailStatusSection({
    super.key,
    required this.currentStatus,
    required this.originalStatus,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Calculamos qué opciones mostrar dependiendo del estado original
    List<String> options = [];
    if (originalStatus.toUpperCase() == 'PENDING') {
      options = ['PENDING', 'COMPLETED', 'CANCELLED'];
    } else if (originalStatus.toUpperCase() == 'COMPLETED') {
      options = ['COMPLETED', 'CANCELLED'];
    } else {
      options = [originalStatus.toUpperCase()]; // Cancelled está bloqueado
    }

    if (!isEditing) {
      Color badgeColor;
      String label;
      switch (currentStatus.toUpperCase()) {
        case 'COMPLETED':
          badgeColor = Colors.teal;
          label = 'COMPLETADO';
          break;
        case 'PENDING':
          badgeColor = Colors.orange.shade700;
          label = 'PENDIENTE (Borrador)';
          break;
        case 'CANCELLED':
          badgeColor = Colors.red;
          label = 'CANCELADO';
          break;
        default:
          badgeColor = Colors.grey;
          label = currentStatus;
      }

      return OrderDetailSectionCard(
        title: 'Estado del Pedido',
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return OrderDetailSectionCard(
      title: 'Estado del Pedido',
      child: DropdownButtonFormField<String>(
        value:
            options.contains(currentStatus.toUpperCase())
                ? currentStatus.toUpperCase()
                : options.first,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          fillColor: Colors.grey.shade50,
          filled: true,
        ),
        icon: const Icon(
          Icons.arrow_drop_down_circle_rounded,
          color: AppColors.primary,
        ),
        items:
            options.map((s) {
              String label = s;
              Color itemColor = Colors.black87;

              if (s == 'COMPLETED') {
                label = '✅  COMPLETAR PEDIDO';
                itemColor = Colors.teal.shade700;
              } else if (s == 'PENDING') {
                label = '⏳  MANTENER PENDIENTE';
                itemColor = Colors.orange.shade800;
              } else if (s == 'CANCELLED') {
                label = '❌  CANCELAR PEDIDO';
                itemColor = Colors.red.shade700;
              }

              return DropdownMenuItem(
                value: s,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: itemColor,
                  ),
                ),
              );
            }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class OrderDetailHeaderRow extends StatelessWidget {
  final String orderId;
  final bool isCompleted;
  final bool isEditing;
  final bool canToggleEdit;
  final VoidCallback onToggleEditing;
  final VoidCallback onPrint;

  const OrderDetailHeaderRow({
    super.key,
    required this.orderId,
    required this.isCompleted,
    required this.isEditing,
    this.canToggleEdit = true,
    required this.onToggleEditing,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detalle del Pedido',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              SelectableText(
                'ID: $orderId',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.blueGrey),
              onPressed: onPrint,
              tooltip: 'Imprimir Ticket',
            ),
            if (canToggleEdit)
              IconButton(
                icon: Icon(isEditing ? Icons.close : Icons.edit),
                onPressed: onToggleEditing,
                tooltip: isEditing ? 'Cancelar edición' : 'Editar pedido',
              ),
          ],
        ),
      ],
    );
  }
}

class OrderDetailSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const OrderDetailSectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class OrderDetailInfoBox extends StatelessWidget {
  final String value;
  const OrderDetailInfoBox({super.key, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(value),
    );
  }
}

class OrderDetailCustomerSection extends StatelessWidget {
  final bool isEditing;
  final TextEditingController searchController;
  final List<Map<String, dynamic>> filteredProfiles;
  final String selectedCustomerLabel;
  final String? selectedCustomerId;
  final VoidCallback onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSelectCustomer;

  const OrderDetailCustomerSection({
    super.key,
    required this.isEditing,
    required this.searchController,
    required this.filteredProfiles,
    required this.selectedCustomerLabel,
    required this.selectedCustomerId,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelectCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Cliente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEditing)
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar cliente por nombre, teléfono o documento',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon:
                    searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: onClearSearch,
                        )
                        : null,
              ),
              onChanged: (_) => onSearchChanged(),
            )
          else
            OrderDetailInfoBox(value: selectedCustomerLabel),
          if (isEditing) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  filteredProfiles.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'No se encontraron clientes.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredProfiles.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final profile = filteredProfiles[index];
                          final customerId = profile['id'] as String;
                          final isSelected = customerId == selectedCustomerId;
                          final fullName =
                              (profile['full_name'] as String?)
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? profile['full_name'] as String
                                  : 'Sin nombre';
                          final phone =
                              (profile['phone'] as String?)
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? profile['phone'] as String
                                  : null;
                          final document =
                              (profile['document_number'] as String?)
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? profile['document_number'] as String
                                  : null;

                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: Colors.teal.withValues(
                              alpha: 0.08,
                            ),
                            title: Text(fullName),
                            subtitle:
                                phone != null || document != null
                                    ? Text(
                                      [
                                        if (phone != null) 'Tel: $phone',
                                        if (document != null) 'Doc: $document',
                                      ].join('  |  '),
                                    )
                                    : null,
                            trailing:
                                isSelected
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.teal,
                                    )
                                    : null,
                            onTap: () => onSelectCustomer(customerId),
                          );
                        },
                      ),
            ),
          ],
        ],
      ),
    );
  }
}

class OrderDetailPaymentSection extends StatelessWidget {
  final String currentPaymentMethod;
  final bool isEditing;
  final List<Map<String, dynamic>> accounts; // Lista de cuentas financieras
  final ValueChanged<String?> onChanged;

  const OrderDetailPaymentSection({
    super.key,
    required this.currentPaymentMethod,
    required this.isEditing,
    required this.accounts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Armamos la lista de opciones (Fijas + Nombres de Cuentas)
    List<String> options = ['POR ACORDAR', 'CRÉDITO'];
    options.addAll(accounts.map((a) => a['name'] as String));

    // 2. Por seguridad, si el método actual no está en la lista (ej. venía guardado como 'YAPE' en vez de 'Yape Negocio'),
    // lo agregamos temporalmente a las opciones para que el Dropdown no tire error al cargar.
    String safeValue =
        currentPaymentMethod.isNotEmpty ? currentPaymentMethod : 'POR ACORDAR';
    if (!options.contains(safeValue)) {
      options.add(safeValue);
    }

    return OrderDetailSectionCard(
      title: 'Método de Pago / Cuenta',
      child:
          isEditing
              ? DropdownButtonFormField<String>(
                value: safeValue,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items:
                    options
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                onChanged: onChanged,
              )
              : OrderDetailInfoBox(
                value:
                    currentPaymentMethod.isNotEmpty
                        ? currentPaymentMethod
                        : 'No registrado',
              ),
    );
  }
}

class OrderDetailPointInfo extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const OrderDetailPointInfo({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class OrderDetailPointsSection extends StatelessWidget {
  final int pointsUsed;
  final int pointsEarned;
  final bool isEditing;
  final TextEditingController pointsUsedController;
  final ValueChanged<String> onPointsUsedChanged;

  const OrderDetailPointsSection({
    super.key,
    required this.pointsUsed,
    required this.pointsEarned,
    required this.isEditing,
    required this.pointsUsedController,
    required this.onPointsUsedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Monedas',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OrderDetailPointInfo(
                  title: 'Monedas usadas',
                  value: pointsUsed.toString(),
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OrderDetailPointInfo(
                  title: 'Monedas ganadas',
                  value: pointsEarned.toString(),
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 12),
            TextField(
              controller: pointsUsedController,
              decoration: const InputDecoration(
                labelText: 'Monedas a aplicar al completar',
                helperText:
                    'Solo se descuentan cuando la orden pase a COMPLETED.',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: onPointsUsedChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class OrderDetailTotalSummarySection extends StatelessWidget {
  final double subtotal;
  final int pointsUsed;
  final int pointsEarned;
  final double pointsToSolesRatio;
  final double discountAmount;

  const OrderDetailTotalSummarySection({
    super.key,
    required this.subtotal,
    required this.pointsUsed,
    required this.pointsEarned,
    required this.pointsToSolesRatio,
    this.discountAmount = 0.0,
  });

  double get _rawDiscount => pointsUsed * pointsToSolesRatio;
  double get _appliedDiscount {
    final maxDiscount = subtotal * 0.5;
    return _rawDiscount > maxDiscount ? maxDiscount : _rawDiscount;
  }

  double get _totalFinal {
    final total = subtotal - _appliedDiscount - discountAmount;
    return total < 0 ? 0 : total;
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isEmphasized = false,
    Color? valueColor,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isEmphasized ? FontWeight.w700 : FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isEmphasized ? 15 : 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capApplied = _rawDiscount > _appliedDiscount;
    return OrderDetailSectionCard(
      title: 'Resumen total',
      child: Column(
        children: [
          _buildRow('Subtotal', 'S/ ${subtotal.toStringAsFixed(2)}'),
          if (pointsUsed > 0) ...[
            _buildRow('Monedas usadas', '$pointsUsed monedas'),
            _buildRow(
              'Descuento por monedas',
              '- S/ ${_appliedDiscount.toStringAsFixed(2)}',
              valueColor: Colors.green.shade800,
              hint:
                  capApplied
                      ? 'Cap 50% aplicado (S/ ${_rawDiscount.toStringAsFixed(2)} → S/ ${_appliedDiscount.toStringAsFixed(2)})'
                      : null,
            ),
          ],
          if (discountAmount > 0)
            _buildRow(
              'Descuento adicional',
              '- S/ ${discountAmount.toStringAsFixed(2)}',
              valueColor: Colors.green.shade800,
            ),
          const Divider(height: 16),
          _buildRow(
            'Total final',
            'S/ ${_totalFinal.toStringAsFixed(2)}',
            isEmphasized: true,
            valueColor: Colors.teal,
          ),
          const SizedBox(height: 6),
          _buildRow('Monedas ganadas', '$pointsEarned monedas'),
        ],
      ),
    );
  }
}

class OrderDetailItemCard extends StatelessWidget {
  final OrderItemModel item;
  final bool isEditing;
  final bool usesBatches;
  final List<Map<String, dynamic>> batches; // Históricos (read-only)
  final List<BatchAssignment>? batchAssignments; // Lotes a descontar (editable)
  final TextEditingController quantityController;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String> onQuantityChanged;
  final VoidCallback? onEditBatches;

  const OrderDetailItemCard({
    super.key,
    required this.item,
    required this.isEditing,
    required this.usesBatches,
    this.batches = const [],
    this.batchAssignments,
    required this.quantityController,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityChanged,
    this.onEditBatches,
  });

  String _formatExpiry(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = item.subtotal;
    final imageUrl = item.displayImageUrl;

    // Solo se puede editar lotes si la variante de este producto lo requiere
    final bool canEditBatches = onEditBatches != null && usesBatches;
    final bool hasBatchOverride = canEditBatches && batchAssignments != null;
    final activeBatches =
        hasBatchOverride
            ? batchAssignments!.where((b) => b.assigned > 0).toList()
            : <BatchAssignment>[];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                        imageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderIcon(),
                      )
                      : _placeholderIcon(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName ?? 'Producto sin nombre',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.variantLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SKU: ${item.sku ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'P. unit: S/ ${item.appliedPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                  // ── Chips de lotes (Para activar borrador) ────────
                  if (canEditBatches) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onEditBatches,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              hasBatchOverride && activeBatches.isNotEmpty
                                  ? AppColors.teal.withValues(alpha: 0.08)
                                  : AppColors.amberLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                hasBatchOverride && activeBatches.isNotEmpty
                                    ? AppColors.teal.withValues(alpha: 0.3)
                                    : AppColors.amber.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasBatchOverride && activeBatches.isNotEmpty
                                  ? Icons.inventory_2_rounded
                                  : Icons.edit_note_rounded,
                              size: 11,
                              color:
                                  hasBatchOverride && activeBatches.isNotEmpty
                                      ? AppColors.teal
                                      : AppColors.amber,
                            ),
                            const SizedBox(width: 4),
                            if (hasBatchOverride && activeBatches.isNotEmpty)
                              Flexible(
                                child: Text(
                                  activeBatches
                                      .map(
                                        (b) =>
                                            '${b.assigned}u · ${b.batchNumber}${b.expiryDate != null ? ' (vto ${b.expiryLabel})' : ''}',
                                      )
                                      .join(' + '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.tealDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              const Text(
                                'FEFO automático · Toca para editar',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_rounded,
                              size: 10,
                              color:
                                  hasBatchOverride && activeBatches.isNotEmpty
                                      ? AppColors.teal
                                      : AppColors.amber,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]
                  // ── Chips de lotes (Históricos / Orden completada) ────────
                  else if (batches.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children:
                          batches.map((b) {
                            final batchNumber =
                                b['batch_number'] as String? ?? '';
                            final qty = b['quantity'] as int? ?? 0;
                            final expiry = _formatExpiry(b['expiry_date']);
                            final label =
                                expiry.isNotEmpty
                                    ? '${qty}u · $batchNumber (vto $expiry)'
                                    : '${qty}u · $batchNumber';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.teal.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_rounded,
                                    size: 10,
                                    color: Colors.teal.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isEditing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: onDecrease,
                      ),
                      SizedBox(
                        width: 48,
                        child: TextFormField(
                          controller: quantityController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          enabled: isEditing,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                          ),
                          onChanged: onQuantityChanged,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: onIncrease,
                      ),
                    ],
                  )
                else
                  Text(
                    'x${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 6),
                Text(
                  'S/ ${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.inventory_2_outlined, color: Colors.teal),
    );
  }
}

class OrderDetailItemsSection extends StatelessWidget {
  final List<OrderItemModel> items;
  final bool isLoading;
  final bool isEditing;
  final bool isLocked;
  final Map<String, List<Map<String, dynamic>>> batchesByVariant;
  final Map<String, bool> usesBatchesMap;
  final Map<String, List<BatchAssignment>> batchOverrides;
  final List<TextEditingController> quantityControllers;
  final void Function(int index) onDecrease;
  final void Function(int index) onIncrease;
  final void Function(int index, String value) onQuantityChanged;
  final void Function(OrderItemModel item)? onEditBatches;

  const OrderDetailItemsSection({
    super.key,
    required this.items,
    required this.isLoading,
    required this.isEditing,
    this.isLocked = false,
    this.batchesByVariant = const {},
    required this.usesBatchesMap,
    this.batchOverrides = const {},
    required this.quantityControllers,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityChanged,
    this.onEditBatches,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Items (${items.length})',
      child:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
              ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sin items registrados.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              )
              : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final batches = batchesByVariant[item.variantId ?? ''] ?? [];
                  final usesBatches =
                      usesBatchesMap[item.variantId ?? ''] ?? false;

                  return OrderDetailItemCard(
                    item: item,
                    isEditing: isEditing && !isLocked,
                    usesBatches: usesBatches,
                    batches: batches,
                    batchAssignments: batchOverrides[item.id ?? ''],
                    quantityController: quantityControllers[index],
                    onDecrease: () => onDecrease(index),
                    onIncrease: () => onIncrease(index),
                    onQuantityChanged:
                        (value) => onQuantityChanged(index, value),
                    onEditBatches:
                        onEditBatches != null
                            ? () => onEditBatches!(item)
                            : null,
                  );
                },
              ),
    );
  }
}

class _PaymentStatusSection extends StatefulWidget {
  final String paymentStatus;
  final double totalAmount;
  final double amountPaid;
  final String paymentMethod;
  final Map<String, dynamic>? creditInfo;
  final String orderId;
  final SupabaseClient supabase;
  final VoidCallback onPaymentRegistered;

  const _PaymentStatusSection({
    required this.paymentStatus,
    required this.totalAmount,
    required this.amountPaid,
    required this.paymentMethod,
    required this.creditInfo,
    required this.orderId,
    required this.supabase,
    required this.onPaymentRegistered,
  });

  @override
  State<_PaymentStatusSection> createState() => _PaymentStatusSectionState();
}

class _PaymentStatusSectionState extends State<_PaymentStatusSection> {
  bool _isRegistering = false;
  final _abonoCtrl = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _abonoCtrl.dispose();
    super.dispose();
  }

  void _validarEntrada(String value) {
    if (value.trim().isEmpty) {
      setState(() => _errorMessage = null);
      return;
    }
    final amount = double.tryParse(value.trim());
    final pendingOrderAmount = widget.totalAmount - widget.amountPaid;
    if (amount == null) {
      setState(() => _errorMessage = 'Número inválido');
    } else if (amount <= 0) {
      setState(() => _errorMessage = 'Debe ser mayor a 0');
    } else if (amount > pendingOrderAmount) {
      setState(
        () =>
            _errorMessage = 'Máx: S/ ${pendingOrderAmount.toStringAsFixed(2)}',
      );
    } else {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _registrarAbono() async {
    if (_errorMessage != null || _abonoCtrl.text.trim().isEmpty) return;
    final amount = double.parse(_abonoCtrl.text.trim());
    setState(() => _isRegistering = true);
    try {
      final creditId = widget.creditInfo!['id'] as String;
      final currentDebt =
          (widget.creditInfo!['current_debt'] as num).toDouble();
      final newGeneralDebt = (currentDebt - amount).clamp(0.0, currentDebt);
      await widget.supabase
          .from('customer_credits')
          .update({
            'current_debt': newGeneralDebt,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creditId);

      final authUserId = widget.supabase.auth.currentUser?.id;
      String? adminProfileId;
      if (authUserId != null) {
        final p =
            await widget.supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        adminProfileId = p?['id'] as String?;
      }

      await widget.supabase.from('credit_movements').insert({
        'credit_id': creditId,
        'order_id': widget.orderId,
        'movement_type': 'PAYMENT',
        'amount': amount,
        'payment_method': 'EFECTIVO',
        'notes': 'Abono registrado desde estado de pago',
        if (adminProfileId != null) 'created_by': adminProfileId,
      });

      final newOrderAmountPaid = widget.amountPaid + amount;
      String newPaymentStatus =
          newOrderAmountPaid >= widget.totalAmount ? 'PAID' : 'PARTIAL';
      await widget.supabase
          .from('orders')
          .update({
            'payment_status': newPaymentStatus,
            'amount_paid': newOrderAmountPaid,
          })
          .eq('id', widget.orderId);

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Abono registrado correctamente',
          type: SnackbarType.success,
        );
        widget.onPaymentRegistered();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al registrar abono: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingAmount = widget.totalAmount - widget.amountPaid;
    Color badgeColor;
    String badgeLabel;
    switch (widget.paymentStatus) {
      case 'PAID':
        badgeColor = Colors.teal;
        badgeLabel = 'Pagado completo';
        break;
      case 'PARTIAL':
        badgeColor = Colors.amber.shade700;
        badgeLabel = 'Pago parcial';
        break;
      case 'PENDING':
      default:
        badgeColor = Colors.deepOrange;
        badgeLabel = 'Pendiente de pago';
    }
    final bool isButtonEnabled =
        !_isRegistering &&
        _abonoCtrl.text.trim().isNotEmpty &&
        _errorMessage == null;

    return OrderDetailSectionCard(
      title: 'Estado de Pago',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PStatRow(
                  label: 'Total',
                  value: 'S/ ${widget.totalAmount.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _PStatRow(
                  label: 'Pagado',
                  value: 'S/ ${widget.amountPaid.toStringAsFixed(2)}',
                  valueColor: Colors.teal,
                ),
              ),
              if (widget.paymentStatus != 'PAID')
                Expanded(
                  child: _PStatRow(
                    label: 'Pendiente',
                    value: 'S/ ${pendingAmount.toStringAsFixed(2)}',
                    valueColor: Colors.deepOrange,
                    bold: true,
                  ),
                ),
            ],
          ),
          if (widget.paymentMethod == 'CRÉDITO' &&
              pendingAmount > 0 &&
              widget.creditInfo != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Registrar abono',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _abonoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: _validarEntrada,
                    decoration: InputDecoration(
                      hintText: 'Monto a abonar (S/)',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      errorText: _errorMessage,
                      errorMaxLines: 2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade500,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                  ),
                  onPressed: isButtonEnabled ? _registrarAbono : null,
                  child:
                      _isRegistering
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            'Abonar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PStatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _PStatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _CreditInfoSection extends StatelessWidget {
  final Map<String, dynamic>? creditInfo;
  final String? customerId;
  const _CreditInfoSection({
    required this.creditInfo,
    required this.customerId,
  });
  @override
  Widget build(BuildContext context) {
    if (customerId == null) {
      return OrderDetailSectionCard(
        title: 'Crédito',
        child: Text(
          'Sin cliente asignado para mostrar crédito.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }
    if (creditInfo == null) {
      return OrderDetailSectionCard(
        title: 'Crédito',
        child: Text(
          'Este cliente no tiene línea de crédito registrada.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }
    final isActive = creditInfo!['is_active'] == true;
    final limit = (creditInfo!['credit_limit'] as num).toDouble();
    final debt = (creditInfo!['current_debt'] as num).toDouble();
    final available = (limit - debt).clamp(0.0, double.infinity);
    return OrderDetailSectionCard(
      title: 'Resumen de Línea de Crédito',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        isActive ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Text(
                  isActive ? 'Crédito activo' : 'Crédito inactivo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        isActive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CreditStatCell(
                  label: 'Límite Global',
                  value: 'S/ ${limit.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _CreditStatCell(
                  label: 'Deuda Total',
                  value: 'S/ ${debt.toStringAsFixed(2)}',
                  valueColor: debt > 0 ? Colors.deepOrange : Colors.teal,
                  bold: debt > 0,
                ),
              ),
              Expanded(
                child: _CreditStatCell(
                  label: 'Disponible',
                  value: 'S/ ${available.toStringAsFixed(2)}',
                  valueColor: available > 0 ? Colors.teal : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditStatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _CreditStatCell({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ─── BOTTOM SHEET: EDITAR LOTES ──────────────────────────────────────────────

class _BatchEditSheet extends StatefulWidget {
  final String productName;
  final String? variantLabel;
  final int totalRequired;
  final List<BatchAssignment> batches; // ordenados FEFO con assigned

  const _BatchEditSheet({
    required this.productName,
    this.variantLabel,
    required this.totalRequired,
    required this.batches,
  });

  @override
  State<_BatchEditSheet> createState() => _BatchEditSheetState();
}

class _BatchEditSheetState extends State<_BatchEditSheet> {
  late final List<BatchAssignment> _batches;

  @override
  void initState() {
    super.initState();
    _batches =
        widget.batches.map((b) => b.copyWith(assigned: b.assigned)).toList();
  }

  int get _totalAssigned => _batches.fold(0, (s, b) => s + b.assigned);
  int get _remaining => widget.totalRequired - _totalAssigned;
  bool get _isValid => _totalAssigned == widget.totalRequired;

  void _resetToFefo() {
    setState(() {
      for (final b in _batches) {
        b.assigned = 0;
      }
      int rem = widget.totalRequired;
      for (final b in _batches) {
        if (rem <= 0) break;
        b.assigned = rem > b.available ? b.available : rem;
        rem -= b.assigned;
      }
    });
  }

  void _changeAssigned(int index, int delta) {
    setState(() {
      final b = _batches[index];
      final newVal = (b.assigned + delta).clamp(0, b.available);
      _batches[index].assigned = newVal;
    });
  }

  Future<void> _mostrarDialogoCantidad(
    BuildContext context,
    int index,
    BatchAssignment b,
  ) async {
    final qtyCtrl = TextEditingController(text: b.assigned.toString());
    final maximoPermitido = b.assigned + _remaining;
    final stockMaximoReal =
        maximoPermitido < b.available ? maximoPermitido : b.available;

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad exacta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                helperText: 'Límite disponible: $stockMaximoReal',
                helperStyle: const TextStyle(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealDark,
                ),
                onPressed: () {
                  final newQty = int.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty >= 0) {
                    if (newQty <= stockMaximoReal) {
                      final diferencia = (newQty - b.assigned).toInt();
                      if (diferencia != 0) _changeAssigned(index, diferencia);
                      Navigator.pop(dialogContext);
                    } else {
                      AppSnackbar.show(
                        context,
                        message:
                            'No puedes asignar más de $stockMaximoReal unidades.',
                        type: SnackbarType.warning,
                      );
                    }
                  } else {
                    AppSnackbar.show(
                      context,
                      message: 'Por favor, ingresa un número válido.',
                      type: SnackbarType.error,
                    );
                  }
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asignación de Lotes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.variantLabel != null
                          ? '${widget.productName} · ${widget.variantLabel}'
                          : widget.productName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _resetToFefo,
                icon: const Icon(Icons.restart_alt_rounded, size: 14),
                label: const Text(
                  'Reset FEFO',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  _isValid
                      ? AppColors.successLight
                      : (_remaining < 0
                          ? AppColors.dangerLight
                          : AppColors.amberLight),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    _isValid
                        ? AppColors.success.withValues(alpha: 0.3)
                        : (_remaining < 0
                            ? AppColors.danger.withValues(alpha: 0.3)
                            : AppColors.amber.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isValid
                      ? Icons.check_circle_rounded
                      : (_remaining < 0
                          ? Icons.error_rounded
                          : Icons.warning_rounded),
                  size: 14,
                  color:
                      _isValid
                          ? AppColors.success
                          : (_remaining < 0
                              ? AppColors.danger
                              : AppColors.amber),
                ),
                const SizedBox(width: 6),
                Text(
                  _isValid
                      ? 'Asignación completa: $_totalAssigned / ${widget.totalRequired} unidades ✓'
                      : _remaining > 0
                      ? 'Faltan $_remaining unidades por asignar'
                      : 'Exceso de ${-_remaining} unidades. Reduce algún lote.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        _isValid
                            ? AppColors.success
                            : (_remaining < 0
                                ? AppColors.danger
                                : AppColors.amber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _batches.length,
              separatorBuilder:
                  (_, __) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final b = _batches[index];
                final isExpired =
                    b.expiryDate != null &&
                    b.expiryDate!.isBefore(DateTime.now());
                final badgeColor =
                    isExpired
                        ? AppColors.danger
                        : b.isExpiringSoon
                        ? AppColors.amber
                        : AppColors.success;
                final badgeLabel =
                    isExpired
                        ? 'VENCIDO'
                        : b.isExpiringSoon
                        ? 'PRÓXIMO A VENCER'
                        : b.expiryDate != null
                        ? 'Vto: ${b.expiryLabel}'
                        : 'Sin vto.';

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.tag_rounded,
                                  size: 12,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  b.batchNumber,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (index == 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.tealLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'FEFO 1°',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.tealDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: badgeColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Disponible: ${b.available} u',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap:
                                  b.assigned > 0
                                      ? () => _changeAssigned(index, -1)
                                      : null,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(8),
                              ),
                              child: Container(
                                width: 30,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 14,
                                  color:
                                      b.assigned > 0
                                          ? AppColors.textSecondary
                                          : AppColors.textHint,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap:
                                  () => _mostrarDialogoCantidad(
                                    context,
                                    index,
                                    b,
                                  ),
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 36),
                                alignment: Alignment.center,
                                color: AppColors.tealLight.withValues(
                                  alpha: 0.25,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  '${b.assigned}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.tealDark,
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap:
                                  b.assigned < b.available && _remaining > 0
                                      ? () => _changeAssigned(index, 1)
                                      : null,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(8),
                              ),
                              child: Container(
                                width: 30,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 14,
                                  color:
                                      b.assigned < b.available && _remaining > 0
                                          ? AppColors.textSecondary
                                          : AppColors.textHint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed:
                  _isValid
                      ? () => Navigator.pop(context, List.of(_batches))
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                disabledBackgroundColor: AppColors.bg,
                disabledForegroundColor: AppColors.textHint,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.check_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Confirmar asignación',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
