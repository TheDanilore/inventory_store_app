import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inventory_store_app/models/order_item_model.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/models/batch_assignment_model.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/services/admin/order_detail_service.dart';
import 'package:inventory_store_app/services/admin/order_pdf_generator.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

import 'package:inventory_store_app/screens/admin/widgets/batch_edit_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_points_section.dart';

// Componentes extraídos
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_skeleton.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_header_row.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_status_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_customer_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_payment_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_total_summary_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_items_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_credit_section.dart';

class OrderDetailSheet extends StatefulWidget {
  final OrderModel order;

  const OrderDetailSheet({super.key, required this.order});

  @override
  State<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<OrderDetailSheet> {
  final _supabase = Supabase.instance.client;
  final _service = OrderDetailService();

  final TextEditingController _customerSearchCtrl = TextEditingController();
  final TextEditingController _pointsUsedCtrl = TextEditingController();
  final TextEditingController _manualNameCtrl = TextEditingController();

  List<OrderItemModel> _items = [];
  List<TextEditingController> _quantityControllers = [];
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _accounts = [];

  Map<String, List<Map<String, dynamic>>> _batchesByVariant = {};
  final Map<String, bool> _usesBatchesMap = {};
  final Map<String, List<BatchAssignmentModel>> _batchOverrides = {};

  bool _isLoading = true;
  bool _hasError = false;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isReturning = false;

  String? _selectedCustomerId;
  String _currentStatus = '';
  String _paymentMethod = 'EFECTIVO';
  int _pointsUsed = 0;
  int _pointsEarned = 0;
  Map<String, dynamic>? _creditInfo;

  bool get _isCompleted => _currentStatus.toUpperCase() == 'COMPLETED';
  bool get _canToggleEdit => widget.order.status.toUpperCase() == 'PENDING';

  List<Map<String, dynamic>> get _filteredProfiles {
    final query = _customerSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _profiles;
    return _profiles.where((profile) {
      final name = (profile['full_name'] as String? ?? '').toLowerCase();
      final phone = (profile['phone'] as String? ?? '').toLowerCase();
      final document = (profile['document_number'] as String? ?? '').toLowerCase();
      return name.contains(query) || phone.contains(query) || document.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.order.customerId;
    _currentStatus = widget.order.status;
    _pointsUsed = widget.order.pointsUsed;
    _pointsEarned = widget.order.pointsEarned;
    _paymentMethod = widget.order.paymentMethod;
    _pointsUsedCtrl.text = _pointsUsed.toString();
    _manualNameCtrl.text = widget.order.displayCustomerName.trim();
    _fetchData();
  }

  @override
  void dispose() {
    _customerSearchCtrl.dispose();
    _pointsUsedCtrl.dispose();
    _manualNameCtrl.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final futures = <Future>[
        _supabase.from('order_items').select('''
          id, order_id, product_id, variant_id, quantity, unit_cost, applied_price, net_profit, created_at,
          products ( name, uses_batches, unit_cost, product_images(id, image_url, is_main, display_order, variant_id) ),
          product_variants ( sku, unit_cost, product_images(id, image_url, is_main, display_order), variant_attribute_values(attribute_values(id, value, attributes(id, name))) )
        ''').eq('order_id', widget.order.id),
        _supabase.from('profiles').select('id, full_name, phone, document_number, role, is_active').eq('is_active', true).order('full_name'),
        _supabase.from('financial_accounts').select('id, name, type, balance').eq('is_active', true).order('name'),
      ];

      if (_selectedCustomerId != null) {
        futures.add(
          _supabase.from('customer_credits').select('id, credit_limit, current_debt, is_active')
              .eq('profile_id', _selectedCustomerId!).maybeSingle(),
        );
      }

      final results = await Future.wait(futures);
      if (!mounted) return;

      final itemsRaw = results[0] as List;
      final items = itemsRaw.map((row) {
        final variantId = row['variant_id'] as String?;
        final prod = row['products'] as Map<String, dynamic>?;
        final variant = row['product_variants'] as Map<String, dynamic>?;

        if (variantId != null && prod != null) {
          _usesBatchesMap[variantId] = prod['uses_batches'] == true;
        }

        double resolvedUnitCost = 0.0;
        if (variant != null && variant['unit_cost'] != null && (variant['unit_cost'] as num) > 0) {
          resolvedUnitCost = (variant['unit_cost'] as num).toDouble();
        } else if (prod != null && prod['unit_cost'] != null) {
          resolvedUnitCost = (prod['unit_cost'] as num).toDouble();
        } else {
          resolvedUnitCost = (row['unit_cost'] as num?)?.toDouble() ?? 0.0;
        }
        row['unit_cost'] = resolvedUnitCost;
        return OrderItemModel.fromJson(Map<String, dynamic>.from(row));
      }).toList();

      List<Map<String, dynamic>> profiles = List<Map<String, dynamic>>.from(results[1]);
      List<Map<String, dynamic>> accounts = List<Map<String, dynamic>>.from(results[2]);
      
      const accountTypeOrder = {'CAJA': 0, 'BANCO': 1, 'DIGITAL': 2, 'OTRO': 3};
      accounts.sort((a, b) {
        final oa = accountTypeOrder[a['type'] as String? ?? ''] ?? 99;
        final ob = accountTypeOrder[b['type'] as String? ?? ''] ?? 99;
        if (oa != ob) return oa.compareTo(ob);
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      final currentCustomerId = _selectedCustomerId ?? widget.order.customerId;
      if (currentCustomerId != null && !profiles.any((p) => p['id'] == currentCustomerId)) {
        try {
          final missingProfile = await _supabase.from('profiles').select('id, full_name, phone, document_number, role, is_active')
              .eq('id', currentCustomerId).maybeSingle();
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

      _quantityControllers = _items.map((item) => TextEditingController(text: item.quantity.toString())).toList();

      if (widget.order.status.toUpperCase() == 'COMPLETED') {
        _fetchBatchMovements();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      AppSnackbar.show(context, message: 'Error cargando datos: $e', type: SnackbarType.error);
    }
  }

  Future<void> _fetchBatchMovements() async {
    try {
      final resp = await _supabase.from('inventory_movements').select('''
        variant_id, quantity, warehouse_stock_batches!inner ( batch_number, expiry_date )
      ''').eq('order_id', widget.order.id).eq('reason', 'SALE').neq('warehouse_stock_batches.batch_number', 'DEFAULT');

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
    } catch (_) {}
  }

  Future<void> _loadCreditInfo(String profileId) async {
    try {
      final resp = await _supabase.from('customer_credits').select('id, credit_limit, current_debt, is_active')
          .eq('profile_id', profileId).maybeSingle();
      if (mounted) setState(() => _creditInfo = resp);
    } catch (_) {}
  }

  void _selectCustomer(String customerId) {
    if (!_isEditing) return;
    setState(() {
      _selectedCustomerId = customerId;
      _creditInfo = null;
    });
    _loadCreditInfo(customerId);
  }

  String _customerLabelFor(String? customerId) {
    if (customerId == null) {
      final manualName = widget.order.displayCustomerName.trim();
      return manualName.isNotEmpty ? manualName : 'Cliente mostrador';
    }
    if (_profiles.isNotEmpty) {
      try {
        final profile = _profiles.firstWhere((p) => p['id'] == customerId);
        final name = (profile['full_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) return name;
      } catch (_) {}
    }
    return widget.order.displayCustomerName.isNotEmpty ? widget.order.displayCustomerName : 'Cliente mostrador';
  }

  int _calculatePointsEarned() {
    if (_selectedCustomerId == null || _paymentMethod == 'CRÉDITO' || _items.isEmpty) return 0;
    final config = context.read<AppConfigProvider>();
    final subtotal = _items.fold(0.0, (sum, i) => sum + i.subtotal);
    final discountAmount = widget.order.discountAmount;
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);

    double appliedDiscount = _pointsUsed * pointsToSolesRatio;
    final maxDiscount = subtotal * 0.5;
    if (appliedDiscount > maxDiscount) appliedDiscount = maxDiscount;

    final totalFinal = (subtotal - appliedDiscount - discountAmount).clamp(0.0, double.infinity);
    final solesToPointsRatio = config.getDouble('soles_to_points_ratio', 1.0);
    if (solesToPointsRatio <= 0) return 0;
    return (totalFinal / solesToPointsRatio).floor();
  }

  double _calculateOrderFinalAmount() {
    final subtotal = _items.fold(0.0, (sum, i) => sum + i.subtotal);
    final discountAmount = widget.order.discountAmount;
    final config = context.read<AppConfigProvider>();
    double appliedDiscount = _pointsUsed * config.getDouble('points_to_soles_ratio', 0.01);
    final maxDiscount = subtotal * 0.5;
    if (appliedDiscount > maxDiscount) appliedDiscount = maxDiscount;
    return (subtotal - appliedDiscount - discountAmount).clamp(0.0, double.infinity);
  }

  double _calculateOrderTotalProfit() {
    double totalProfit = 0.0;
    for (final item in _items) {
      totalProfit += (item.appliedPrice - item.unitCost) * item.quantity;
    }
    return totalProfit;
  }

  Future<void> _showBatchEditSheet(OrderItemModel item) async {
    final warehouseId = widget.order.warehouseId;
    if (warehouseId == null) return;

    List<BatchAssignmentModel> batches;
    try {
      final resp = await _supabase.from('warehouse_stock_batches')
          .select('id, batch_number, expiry_date, available_quantity')
          .eq('variant_id', item.variantId ?? '')
          .eq('warehouse_id', warehouseId)
          .neq('batch_number', 'DEFAULT')
          .gt('available_quantity', 0)
          .order('expiry_date', ascending: true, nullsFirst: false);
      batches = (resp as List).map((b) => BatchAssignmentModel(
        batchId: b['id'] as String,
        batchNumber: b['batch_number'] as String,
        expiryDate: b['expiry_date'] != null ? DateTime.tryParse(b['expiry_date'] as String) : null,
        available: (b['available_quantity'] as num).toInt(),
        assigned: 0,
      )).toList();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, message: 'Error cargando lotes: $e', type: SnackbarType.error);
      return;
    }

    if (batches.isEmpty) {
      if (!mounted) return;
      AppSnackbar.show(context, message: 'No hay lotes con stock para este producto.', type: SnackbarType.warning);
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
    final result = await showModalBottomSheet<List<BatchAssignmentModel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BatchEditSheet(
        productName: item.productName ?? 'Producto',
        variantLabel: item.variantLabel,
        totalRequired: item.quantity,
        batches: batches,
      ),
    );

    if (result != null && mounted) {
      setState(() => _batchOverrides[item.id ?? ''] = result);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      String? notesOverride;
      
      // Si se está cancelando o completando, solicitar motivo opcional
      final isNowCancelled = _currentStatus.toUpperCase() == 'CANCELLED';
      if (isNowCancelled) {
        notesOverride = await _showReasonDialog('Cancelar Pedido', 'Ingresa el motivo de la cancelación:');
        if (notesOverride == null) {
          setState(() => _isSaving = false);
          return; // Canceló el diálogo
        }
      }

      final String? customerNameToSave = _selectedCustomerId != null 
          ? null 
          : (_manualNameCtrl.text.trim().isEmpty ? null : _manualNameCtrl.text.trim());

      final result = await _service.saveOrderChanges(
        orderId: widget.order.id,
        originalStatus: widget.order.status,
        newStatus: _currentStatus,
        paymentMethod: _paymentMethod,
        selectedCustomerId: _selectedCustomerId,
        customerNameToSave: customerNameToSave,
        items: _items,
        pointsUsed: _pointsUsed,
        pointsEarned: _pointsEarned,
        totalAmount: _calculateOrderFinalAmount(),
        totalProfit: _calculateOrderTotalProfit(),
        batchOverrides: _batchOverrides,
        notesOverride: notesOverride?.isNotEmpty == true ? notesOverride : null,
      );

      if (!mounted) return;

      if (result.success) {
        AppSnackbar.show(context, message: 'Cambios guardados correctamente', type: SnackbarType.success);
        Navigator.pop(context, true);
      } else if (result.stockError) {
        _showStockErrorDialog(result.stockMessages);
      } else {
        AppSnackbar.show(context, message: result.errorMessage ?? 'Error desconocido', type: SnackbarType.error);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, message: 'Excepción inesperada: $e', type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmReturn() async {
    final notes = await _showReasonDialog('Registrar Devolución', 'Ingresa el motivo de la devolución:');
    if (notes == null) return; // Canceló el diálogo

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.assignment_return_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Confirmar Devolución', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Esta acción cancelará el pedido y revertirá todos los movimientos asociados:\n\n'
          '• Stock de productos devuelto al almacén\n'
          '• Monedas de fidelidad revertidas\n'
          '• Deuda de crédito o cuenta ajustada\n\n'
          '¿Deseas continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            icon: const Icon(Icons.assignment_return_rounded, size: 18),
            label: const Text('Confirmar'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _processReturn(notes.isNotEmpty ? notes : null);
    }
  }

  Future<void> _processReturn(String? notes) async {
    setState(() => _isReturning = true);
    try {
      final result = await _service.processReturn(
        orderId: widget.order.id,
        items: _items,
        notesOverride: notes,
      );

      if (!mounted) return;
      if (result.success) {
        AppSnackbar.show(context, message: 'Devolución procesada con éxito', type: SnackbarType.success);
        Navigator.pop(context, true);
      } else {
        AppSnackbar.show(context, message: result.errorMessage ?? 'Error procesando devolución', type: SnackbarType.error);
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, message: 'Error: $e', type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _isReturning = false);
    }
  }

  Future<String?> _showReasonDialog(String title, String hint) async {
    String notes = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hint, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ej. Producto dañado, cliente cambió de opinión...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => notes = val,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, notes),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _showStockErrorDialog(List<String> messages) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stock Insuficiente', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('El stock varió y ya no hay disponibilidad para completar este pedido:\n\n${messages.join('\n')}'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _items.fold(0.0, (sum, i) => sum + i.subtotal);
    final config = context.watch<AppConfigProvider>();
    final maxPtsUser = _selectedCustomerId != null ? _profiles.firstWhere((p) => p['id'] == _selectedCustomerId, orElse: () => {'wallet_balance': 0})['wallet_balance'] as int? ?? 0 : 0;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 5),
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Padding(padding: EdgeInsets.all(16.0), child: OrderDetailSkeleton())
                  : _hasError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
                              const SizedBox(height: 16),
                              const Text('Ocurrió un error al cargar el pedido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _fetchData,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white),
                              )
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            OrderDetailHeaderRow(
                              orderId: widget.order.id,
                              isCompleted: _isCompleted,
                              isEditing: _isEditing,
                              canToggleEdit: _canToggleEdit,
                              onToggleEditing: () {
                                if (_isEditing) {
                                  setState(() {
                                    _isEditing = false;
                                    _currentStatus = widget.order.status;
                                    _paymentMethod = widget.order.paymentMethod;
                                    _pointsUsed = widget.order.pointsUsed;
                                    _pointsEarned = widget.order.pointsEarned;
                                    _selectedCustomerId = widget.order.customerId;
                                  });
                                } else {
                                  setState(() => _isEditing = true);
                                }
                              },
                              onPrint: () => OrderPdfGenerator.printTicket(widget.order, items: _items),
                              onShare: () => OrderPdfGenerator.shareTicket(widget.order, items: _items),
                            ),
                            const Divider(height: 32),
                            OrderDetailStatusSection(
                              currentStatus: _currentStatus,
                              originalStatus: widget.order.status,
                              isEditing: _isEditing,
                              onChanged: (val) {
                                if (val != null) setState(() => _currentStatus = val);
                              },
                            ),
                            OrderDetailCustomerSection(
                              isEditing: _isEditing,
                              isCompleted: _isCompleted,
                              hasManualName: _manualNameCtrl.text.isNotEmpty,
                              manualNameController: _manualNameCtrl,
                              searchController: _customerSearchCtrl,
                              filteredProfiles: _filteredProfiles,
                              selectedCustomerLabel: _customerLabelFor(_selectedCustomerId),
                              selectedCustomerId: _selectedCustomerId,
                              onSearchChanged: () => setState(() {}),
                              onClearSearch: () {
                                _customerSearchCtrl.clear();
                                setState(() {});
                              },
                              onSelectCustomer: _selectCustomer,
                              onClearCustomer: () => setState(() {
                                _selectedCustomerId = null;
                                _creditInfo = null;
                                _pointsEarned = _calculatePointsEarned();
                              }),
                            ),
                            OrderDetailPaymentSection(
                              currentPaymentMethod: _paymentMethod,
                              isEditing: _isEditing,
                              isCompleted: widget.order.status.toUpperCase() == 'COMPLETED',
                              accounts: _accounts,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _paymentMethod = val;
                                    _pointsEarned = _calculatePointsEarned();
                                  });
                                }
                              },
                            ),
                            if (_paymentMethod == 'CRÉDITO')
                              OrderDetailCreditSection(
                                creditInfo: _creditInfo,
                                customerId: _selectedCustomerId,
                              ),
                            const SizedBox(height: 16),
                            OrderDetailItemsSection(
                              items: _items,
                              isLoading: _isLoading,
                              isEditing: _isEditing,
                              isLocked: widget.order.status.toUpperCase() == 'COMPLETED',
                              batchesByVariant: _batchesByVariant,
                              usesBatchesMap: _usesBatchesMap,
                              batchOverrides: _batchOverrides,
                              quantityControllers: _quantityControllers,
                              onDecrease: (idx) {
                                if (_items[idx].quantity > 1) {
                                  setState(() {
                                    _items[idx] = _items[idx].copyWith(quantity: _items[idx].quantity - 1);
                                    _quantityControllers[idx].text = _items[idx].quantity.toString();
                                    _pointsEarned = _calculatePointsEarned();
                                    _batchOverrides.remove(_items[idx].id); // Reajustar lotes si cambia cantidad
                                  });
                                }
                              },
                              onIncrease: (idx) {
                                setState(() {
                                  _items[idx] = _items[idx].copyWith(quantity: _items[idx].quantity + 1);
                                  _quantityControllers[idx].text = _items[idx].quantity.toString();
                                  _pointsEarned = _calculatePointsEarned();
                                  _batchOverrides.remove(_items[idx].id);
                                });
                              },
                              onQuantityChanged: (idx, val) {
                                final qty = int.tryParse(val) ?? 1;
                                if (qty > 0) {
                                  setState(() {
                                    _items[idx] = _items[idx].copyWith(quantity: qty);
                                    _pointsEarned = _calculatePointsEarned();
                                    _batchOverrides.remove(_items[idx].id);
                                  });
                                }
                              },
                              onEditBatches: (item) => _showBatchEditSheet(item),
                            ),
                            const SizedBox(height: 16),
                            if (config.getDouble('enable_loyalty_system', 1) == 1.0 && _selectedCustomerId != null && _paymentMethod != 'CRÉDITO') ...[
                              OrderDetailPointsSection(
                                isEditing: _isEditing,
                                pointsUsed: _pointsUsed,
                                pointsUsedCtrl: _pointsUsedCtrl,
                                maxPointsAvailable: maxPtsUser,
                                pointsToSolesRatio: config.getDouble('points_to_soles_ratio', 0.01),
                                onPointsChanged: (val) {
                                  final pts = int.tryParse(val) ?? 0;
                                  if (pts <= maxPtsUser) {
                                    setState(() {
                                      _pointsUsed = pts;
                                      _pointsEarned = _calculatePointsEarned();
                                    });
                                  } else {
                                    _pointsUsedCtrl.text = maxPtsUser.toString();
                                    setState(() {
                                      _pointsUsed = maxPtsUser;
                                      _pointsEarned = _calculatePointsEarned();
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            OrderDetailTotalSummarySection(
                              subtotal: subtotal,
                              pointsUsed: _pointsUsed,
                              pointsEarned: _pointsEarned,
                              pointsToSolesRatio: config.getDouble('points_to_soles_ratio', 0.01),
                              discountAmount: widget.order.discountAmount,
                            ),
                          ],
                        ),
            ),
            // Bottom Action Buttons
            if (!_isLoading && !_hasError)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: Row(
                  children: [
                    if (_isEditing)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Guardar Cambios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      )
                    else if (widget.order.status.toUpperCase() == 'COMPLETED')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isReturning ? null : _confirmReturn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade200)),
                          ),
                          icon: _isReturning
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                              : const Icon(Icons.assignment_return_rounded),
                          label: const Text('Registrar Devolución', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    else
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
