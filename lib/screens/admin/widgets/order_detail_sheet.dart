import 'package:flutter/material.dart';
import 'package:inventory_store_app/services/admin/order_pdf_generator.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/order_item_model.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  String? _selectedCustomerId;
  String _currentStatus = '';
  // --- NUEVO: ESTADO PARA EL MÉTODO DE PAGO ---
  String _paymentMethod = 'EFECTIVO';
  int _pointsUsed = 0;
  int _pointsEarned = 0;
  bool get _isCompleted => _currentStatus.toUpperCase() == 'COMPLETED';
  bool get _isCancelled => _currentStatus.toUpperCase() == 'CANCELLED';
  bool get _canToggleEdit => !_isCancelled;

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

  // Crédito del cliente de la orden
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
      // ─── NUEVO: Si no hay ID, mostramos el nombre manual de la orden ───
      final manualName = widget.order.displayCustomerName.trim();
      return (manualName.isNotEmpty) ? manualName : 'Cliente mostrador';
    }

    try {
      final profile = _profiles.firstWhere((p) => p['id'] == customerId);
      final name = (profile['full_name'] as String?)?.trim();
      return (name != null && name.isNotEmpty) ? name : 'Cliente mostrador';
    } catch (_) {
      return 'Cliente mostrador';
    }
  }

  void _selectCustomer(String customerId) {
    if (!_isEditing) return;
    setState(() {
      _selectedCustomerId = customerId;
      _creditInfo = null; // limpiar mientras carga
    });
    // Cargar crédito del nuevo cliente seleccionado
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
              applied_price, net_profit, kardex_registered, created_at,
              products ( name, product_images(*) ),
              product_variants ( attributes, sku, product_images(*) )
            ''')
            .eq('order_id', widget.order.id),
        _supabase
            .from('profiles')
            .select('id, full_name, phone, document_number, role, is_active')
            .eq('is_active', true)
            .order('full_name'),
      ];

      // Cargar crédito del cliente si tiene uno asignado
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

      final items =
          (results[0] as List)
              .map(
                (row) =>
                    OrderItemModel.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList();

      setState(() {
        _items = items;
        _profiles = List<Map<String, dynamic>>.from(results[1]);
        if (results.length > 2) {
          _creditInfo = results[2] as Map<String, dynamic>?;
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cargando datos: $e')));
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

    // AQUÍ RESTAMOS EL DESCUENTO EXTRA GUARDADO EN EL MODELO
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
    return _items.fold<double>(0, (sum, item) {
      return sum + ((item.appliedPrice - item.unitCost) * item.quantity);
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final wasCompleted = widget.order.status.toUpperCase() == 'COMPLETED';
      final isNowCompleted = _currentStatus.toUpperCase() == 'COMPLETED';
      final isNowCancelled = _currentStatus.toUpperCase() == 'CANCELLED';

      // ─── 1. OBTENER PERFIL DEL USUARIO PARA TRAZABILIDAD (created_by) ───
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

      // --- Recálculos financieros ---
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

        // A. Validar Crédito
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

        // B. Validar Stock de todos los items
        // B. Validar Stock de todos los items y preparar lotes
        List<String> outOfStockMessages = [];
        List<Map<String, dynamic>> batchesToUpdate = [];
        List<Map<String, dynamic>> movementsToInsert = [];

        for (final item in _items) {
          final safeVariantId = item.variantId ?? '';
          final qtyNeeded = item.quantity;

          final batchesResp = await _supabase
              .from('warehouse_stock_batches')
              .select('id, available_quantity')
              .eq('warehouse_id', warehouseId)
              .eq('variant_id', safeVariantId)
              .order('created_at', ascending: true);

          final batches = List<Map<String, dynamic>>.from(batchesResp);
          final currentStock = batches.fold<int>(
            0,
            (sum, b) => sum + ((b['available_quantity'] as num?)?.toInt() ?? 0),
          );

          if (currentStock < qtyNeeded) {
            outOfStockMessages.add(
              '• ${item.productName ?? 'Producto'} - ${item.variantLabel} (Stock real: $currentStock, Pedido: $qtyNeeded)',
            );
          } else {
            // Distribuir el descuento entre los lotes
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
                  'variant_id': safeVariantId,
                  'warehouse_id': warehouseId,
                  'stock_batch_id': batch['id'],
                  'order_id': widget.order.id,
                  'quantity': -deductFromThis,
                  'previous_stock': batchStock,
                  'new_stock': newBatchStock,
                  'reason': 'SALE',
                  'notes': 'Pedido completado desde detalles',
                  if (currentProfileId != null) 'created_by': currentProfileId,
                });

                remainingToDeduct -= deductFromThis;
              }
            }
          }
        }

        // C. Detener si falta stock
        if (outOfStockMessages.isNotEmpty) {
          _showStockErrorDialog(outOfStockMessages);
          setState(() => _isSaving = false);
          return;
        }

        // D. Proceder a descontar inventario y registrar movimientos
        for (var update in batchesToUpdate) {
          await _supabase
              .from('warehouse_stock_batches')
              .update({'available_quantity': update['available_quantity']})
              .eq('id', update['id']);
        }

        for (var mov in movementsToInsert) {
          await _supabase.from('inventory_movements').insert(mov);
        }

        // E. Cargar Deuda al Cliente (Si es Crédito)
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

        // A. Restaurar inventario
        for (final item in _items) {
          final safeVariantId = item.variantId ?? '';
          final qty = item.quantity;
          final productId = item.productId;

          // Buscar el lote más reciente al cual regresarle el stock
          final batchResp =
              await _supabase
                  .from('warehouse_stock_batches')
                  .select('id, available_quantity')
                  .eq('warehouse_id', warehouseId)
                  .eq('variant_id', safeVariantId)
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
              'variant_id': safeVariantId,
              'warehouse_id': warehouseId,
              'stock_batch_id': batchId,
              'order_id': widget.order.id,
              'quantity': qty,
              'previous_stock': currentStock,
              'new_stock': newStock,
              'reason': 'RETURN',
              'notes': 'Devolución por cancelación desde detalles',
              if (currentProfileId != null) 'created_by': currentProfileId,
            });
          } else {
            // Crear un lote nuevo si no había ninguno en el sistema
            final newBatch =
                await _supabase
                    .from('warehouse_stock_batches')
                    .insert({
                      'variant_id': safeVariantId,
                      'product_id': productId,
                      'warehouse_id': warehouseId,
                      'available_quantity': qty,
                      'batch_number': 'DEFAULT',
                      if (currentProfileId != null)
                        'created_by': currentProfileId,
                    })
                    .select('id')
                    .single();

            await _supabase.from('inventory_movements').insert({
              'variant_id': safeVariantId,
              'warehouse_id': warehouseId,
              'stock_batch_id': newBatch['id'],
              'order_id': widget.order.id,
              'quantity': qty,
              'previous_stock': 0,
              'new_stock': qty,
              'reason': 'RETURN',
              'notes': 'Devolución por cancelación desde detalles',
              if (currentProfileId != null) 'created_by': currentProfileId,
            });
          }
        }

        // B. Reembolsar Deuda al Cliente (Si era Crédito)
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

        // C. Revertir wallet (puntos ganados → quitar, puntos canjeados → devolver)
        if (origCustomerId != null) {
          // Revertir puntos GANADOS
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

          // Devolver puntos CANJEADOS
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
        _paymentMethod = 'EFECTIVO';
      }

      // Cuando es crédito, no tiene sentido usar puntos (incompatibles)
      if (_paymentMethod == 'CRÉDITO') {
        _pointsUsed = 0;
        _pointsEarned = 0;
      }

      String paymentStatus;
      double amountPaid;

      if (_paymentMethod == 'CRÉDITO') {
        // Crédito siempre nace pendiente hasta que se salde
        paymentStatus = 'PENDING';
        amountPaid = 0;
      } else if (isNowCancelled) {
        // Cancelado: neutro
        paymentStatus = 'PAID';
        amountPaid = 0;
      } else {
        // Efectivo, Yape, etc.: pagado completo
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
              // Corrección adicional: Recalcular net_profit si el usuario alteró la cantidad de este ítem
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

  // Helpers para no ensuciar el bloque principal
  void _showErrorSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OrderDetailHeaderRow(
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
            OrderDetailCustomerSection(
              isEditing: _isEditing,
              searchController: _customerSearchCtrl,
              filteredProfiles: _filteredProfiles,
              selectedCustomerLabel: _customerLabelFor(_selectedCustomerId),
              selectedCustomerId: _selectedCustomerId,
              onSearchChanged: () => setState(() {}),
              onClearSearch: () {
                setState(() {
                  _customerSearchCtrl.clear();
                });
              },
              onSelectCustomer: _selectCustomer,
            ),

            OrderDetailPaymentSection(
              currentPaymentMethod: _paymentMethod,
              isEditing: _isEditing,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _paymentMethod = val;
                    // Al cambiar a crédito, limpiar puntos (incompatibles)
                    if (val == 'CRÉDITO') {
                      _pointsUsed = 0;
                      _pointsUsedCtrl.text = '0';
                      _pointsEarned = _calculatePointsEarned();
                    }
                  });
                  // Si cambia cliente+método, refrescar crédito
                  if (val == 'CRÉDITO' && _selectedCustomerId != null) {
                    _loadCreditInfo(_selectedCustomerId!);
                  }
                }
              },
            ),

            // ─── SECCIÓN DE CRÉDITO (solo cuando el método es CRÉDITO) ───
            if (_paymentMethod == 'CRÉDITO')
              _CreditInfoSection(
                creditInfo: _creditInfo,
                totalAmount: _calculateOrderFinalAmount(),
                isEditing: _isEditing,
                orderId: widget.order.id,
                customerId: _selectedCustomerId,
                supabase: _supabase,
                onPaymentRegistered: () {
                  _fetchData();
                  Navigator.pop(context, true);
                },
              ),

            // ─── PAYMENT STATUS (siempre visible en COMPLETED) ───
            if (_isCompleted)
              _PaymentStatusSection(
                paymentStatus: _currentPaymentStatus, // <-- Dinámico
                totalAmount: _calculateOrderFinalAmount(), // <-- Dinámico
                amountPaid: _currentAmountPaid, // <-- Dinámico
              ),

            OrderDetailStatusSection(
              currentStatus: _currentStatus,
              isEditing: _isEditing,
              onChanged: (val) {
                if (val != null) setState(() => _currentStatus = val);
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
              quantityControllers: _quantityControllers,
              onDecrease: (index) => _changeQuantity(index, -1),
              onIncrease: (index) => _changeQuantity(index, 1),
              onQuantityChanged: (index, value) => _setQuantity(index, value),
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

class OrderDetailHeaderRow extends StatelessWidget {
  final bool isCompleted;
  final bool isEditing;
  final bool canToggleEdit;
  final VoidCallback onToggleEditing;
  final VoidCallback onPrint;

  const OrderDetailHeaderRow({
    super.key,
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
      children: [
        const Text(
          'Detalle del Pedido',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

class OrderDetailStatusSection extends StatelessWidget {
  final String currentStatus;
  final bool isEditing;
  final ValueChanged<String?> onChanged;

  const OrderDetailStatusSection({
    super.key,
    required this.currentStatus,
    required this.isEditing,
    required this.onChanged,
  });

  String _label(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pendiente';
      case 'COMPLETED':
        return 'Completado';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return OrderDetailSectionCard(
        title: 'Estado',
        child: OrderDetailInfoBox(value: _label(currentStatus)),
      );
    }

    return OrderDetailSectionCard(
      title: 'Estado',
      child: DropdownButtonFormField<String>(
        value: currentStatus,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items:
            ['PENDING', 'COMPLETED', 'CANCELLED']
                .map((s) => DropdownMenuItem(value: s, child: Text(_label(s))))
                .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// Incluye CRÉDITO en el listado de métodos de pago.
class OrderDetailPaymentSection extends StatelessWidget {
  final String currentPaymentMethod;
  final bool isEditing;
  final ValueChanged<String?> onChanged;

  const OrderDetailPaymentSection({
    super.key,
    required this.currentPaymentMethod,
    required this.isEditing,
    required this.onChanged,
  });

  static const List<String> _paymentMethods = [
    'EFECTIVO',
    'YAPE',
    'PLIN',
    'TARJETA',
    'TRANSFERENCIA',
    'CRÉDITO', // ← CORREGIDO: faltaba en el listado original
    'POR ACORDAR',
  ];

  @override
  Widget build(BuildContext context) {
    // Aseguramos que el valor actual sea válido en la lista
    final safeValue =
        _paymentMethods.contains(currentPaymentMethod)
            ? currentPaymentMethod
            : 'EFECTIVO';

    return OrderDetailSectionCard(
      title: 'Método de Pago',
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
                    _paymentMethods
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

/// Resumen de totales con cap del 50% en descuento por monedas.
class OrderDetailTotalSummarySection extends StatelessWidget {
  final double subtotal;
  final int pointsUsed;
  final int pointsEarned;
  final double pointsToSolesRatio;
  final double discountAmount; // <-- 1. Agregado

  const OrderDetailTotalSummarySection({
    super.key,
    required this.subtotal,
    required this.pointsUsed,
    required this.pointsEarned,
    required this.pointsToSolesRatio,
    this.discountAmount = 0.0, // <-- 2. Agregado al constructor
  });

  /// Descuento bruto en soles (antes del cap)
  double get _rawDiscount => pointsUsed * pointsToSolesRatio;

  /// Descuento real aplicado — máximo 50% del subtotal
  double get _appliedDiscount {
    final maxDiscount = subtotal * 0.5;
    return _rawDiscount > maxDiscount ? maxDiscount : _rawDiscount;
  }

  // 3. Modificado para restar también el descuento manual de forma visual
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
    // Indicar si el cap fue aplicado
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

          // 4. NUEVO: Renglón para el descuento adicional
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
  final TextEditingController quantityController;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String> onQuantityChanged;

  const OrderDetailItemCard({
    super.key,
    required this.item,
    required this.isEditing,
    required this.quantityController,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = item.subtotal;
    final imageUrl = item.displayImageUrl;

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
            // Imagen del producto
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
            // Datos del producto
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
                  // Precio unitario
                  Text(
                    'P. unit: S/ ${item.appliedPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Cantidad y subtotal
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
  final List<TextEditingController> quantityControllers;
  final void Function(int index) onDecrease;
  final void Function(int index) onIncrease;
  final void Function(int index, String value) onQuantityChanged;

  const OrderDetailItemsSection({
    super.key,
    required this.items,
    required this.isLoading,
    required this.isEditing,
    required this.quantityControllers,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityChanged,
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
                  return OrderDetailItemCard(
                    item: items[index],
                    isEditing: isEditing,
                    quantityController: quantityControllers[index],
                    onDecrease: () => onDecrease(index),
                    onIncrease: () => onIncrease(index),
                    onQuantityChanged:
                        (value) => onQuantityChanged(index, value),
                  );
                },
              ),
    );
  }
}

// ─── PAYMENT STATUS SECTION (Lectura — visible en COMPLETED) ─────────────────

class _PaymentStatusSection extends StatelessWidget {
  final String paymentStatus;
  final double totalAmount;
  final double amountPaid;

  const _PaymentStatusSection({
    required this.paymentStatus,
    required this.totalAmount,
    required this.amountPaid,
  });

  @override
  Widget build(BuildContext context) {
    final pendingAmount = totalAmount - amountPaid;
    Color badgeColor;
    String badgeLabel;

    switch (paymentStatus) {
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
                  value: 'S/ ${totalAmount.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _PStatRow(
                  label: 'Pagado',
                  value: 'S/ ${amountPaid.toStringAsFixed(2)}',
                  valueColor: Colors.teal,
                ),
              ),
              if (paymentStatus != 'PAID')
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

// ─── CREDIT INFO SECTION ─────────────────────────────────────────────────────

class _CreditInfoSection extends StatefulWidget {
  final Map<String, dynamic>? creditInfo;
  final double totalAmount;
  final bool isEditing;
  final String orderId;
  final String? customerId;
  final SupabaseClient supabase;
  final VoidCallback onPaymentRegistered;

  const _CreditInfoSection({
    required this.creditInfo,
    required this.totalAmount,
    required this.isEditing,
    required this.orderId,
    required this.customerId,
    required this.supabase,
    required this.onPaymentRegistered,
  });

  @override
  State<_CreditInfoSection> createState() => _CreditInfoSectionState();
}

class _CreditInfoSectionState extends State<_CreditInfoSection> {
  bool _isRegistering = false;
  final _abonoCtrl = TextEditingController();

  @override
  void dispose() {
    _abonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrarAbono() async {
    final amount = double.tryParse(_abonoCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;

    setState(() => _isRegistering = true);
    try {
      final creditId = widget.creditInfo!['id'] as String;
      final currentDebt =
          (widget.creditInfo!['current_debt'] as num).toDouble();
      final newDebt = (currentDebt - amount).clamp(0.0, currentDebt);

      await widget.supabase
          .from('customer_credits')
          .update({
            'current_debt': newDebt,
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
        'notes': 'Abono registrado desde detalle de pedido',
        if (adminProfileId != null) 'created_by': adminProfileId,
      });

      // Actualizar payment_status de la orden
      final remaining = newDebt;
      String newPaymentStatus;
      double amountPaid;
      if (remaining <= 0) {
        newPaymentStatus = 'PAID';
        amountPaid = widget.totalAmount;
      } else {
        newPaymentStatus = 'PARTIAL';
        amountPaid = widget.totalAmount - remaining;
      }

      await widget.supabase
          .from('orders')
          .update({
            'payment_status': newPaymentStatus,
            'amount_paid': amountPaid,
          })
          .eq('id', widget.orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abono registrado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onPaymentRegistered();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar abono: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.creditInfo;

    if (widget.customerId == null) {
      return OrderDetailSectionCard(
        title: 'Crédito',
        child: Text(
          'Sin cliente asignado para mostrar crédito.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }

    if (info == null) {
      return OrderDetailSectionCard(
        title: 'Crédito',
        child: Text(
          'Este cliente no tiene línea de crédito registrada.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }

    final isActive = info['is_active'] == true;
    final limit = (info['credit_limit'] as num).toDouble();
    final debt = (info['current_debt'] as num).toDouble();
    final available = (limit - debt).clamp(0.0, double.infinity);
    final debtColor = debt > 0 ? Colors.deepOrange : Colors.teal;

    return OrderDetailSectionCard(
      title: 'Crédito del Cliente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge activo/inactivo
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
          // Fila de datos
          Row(
            children: [
              Expanded(
                child: _CreditStatCell(
                  label: 'Límite',
                  value: 'S/ ${limit.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _CreditStatCell(
                  label: 'Deuda actual',
                  value: 'S/ ${debt.toStringAsFixed(2)}',
                  valueColor: debtColor,
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
          // Registrar abono (solo si hay deuda)
          if (debt > 0) ...[
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
              children: [
                Expanded(
                  child: TextField(
                    controller: _abonoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Monto a abonar (S/)',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
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
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                  ),
                  onPressed: _isRegistering ? null : _registrarAbono,
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
