import 'package:flutter/material.dart';
import 'package:inventory_store_app/services/admin/order_pdf_generator.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/order_item_model.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_sections.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.order.customerId;
    _currentStatus = widget.order.status;
    _pointsUsed = widget.order.pointsUsed;
    _pointsEarned = widget.order.pointsEarned;
    // Extraemos el método de pago del modelo (asumiendo que lo agregaste a tu OrderModel, sino fallback a EFECTIVO)
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
      final manualName = widget.order.displayCustomerName?.trim();
      return (manualName != null && manualName.isNotEmpty)
          ? manualName
          : 'Cliente mostrador';
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
    setState(() => _selectedCustomerId = customerId);
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
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
      ]);

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
    final finalAmount = subtotalAmount - appliedDiscount;
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
          final batchResp = await _supabase
              .from('warehouse_stock_batches')
              .select('id, available_quantity')
              .eq('warehouse_id', warehouseId)
              .eq('variant_id', safeVariantId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (batchResp != null) {
            final batchId = batchResp['id'];
            final currentStock = (batchResp['available_quantity'] as num?)?.toInt() ?? 0;
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
            final newBatch = await _supabase.from('warehouse_stock_batches').insert({
              'variant_id': safeVariantId,
              'product_id': productId,
              'warehouse_id': warehouseId,
              'available_quantity': qty,
              'batch_number': 'DEFAULT',
              if (currentProfileId != null) 'created_by': currentProfileId,
            }).select('id').single();

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
                .update({'current_debt': newDebt})
                .eq('id', creditId);

            await _supabase.from('credit_movements').insert({
              'credit_id': creditId,
              'order_id': widget.order.id,
              'movement_type': 'PAYMENT', // Reembolso virtual
              'amount': origAmount,
              'notes': 'Reembolso por cancelación de pedido',
              if (currentProfileId != null) 'created_by': currentProfileId,
            });
          }
        }
      }

      // ─── 4. ACTUALIZAR ORDEN Y PAGOS ───
      if (isNowCompleted &&
          (_paymentMethod == 'POR ACORDAR' || _paymentMethod.trim().isEmpty)) {
        _paymentMethod = 'EFECTIVO';
      }

      String paymentStatus = 'PAID';
      double amountPaid = totalAmount;

      // Si recién se completa y es a crédito, nace pendiente
      if (isNowCompleted && _paymentMethod == 'CRÉDITO') {
        paymentStatus = 'PENDING';
        amountPaid = 0;
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
                if (val != null) setState(() => _paymentMethod = val);
              },
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
