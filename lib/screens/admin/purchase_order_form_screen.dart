import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/models/financial_account_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/add_entry_product_sheet.dart';
import 'package:inventory_store_app/screens/admin/inventory_entry_form_screen.dart'; // Para reutilizar EntryItemUI
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

class PurchaseOrderFormScreen extends StatefulWidget {
  const PurchaseOrderFormScreen({super.key});

  @override
  State<PurchaseOrderFormScreen> createState() =>
      _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends State<PurchaseOrderFormScreen> {
  final _supabase = Supabase.instance.client;

  // ── Datos de la Orden ───────────────────────────────────────────────────
  String? _selectedSupplierId;
  String? _selectedWarehouseId;
  DateTime? _dueDate;
  DateTime? _documentDate;

  String _documentType = 'NINGUNO';
  final _documentNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // ── Items ───────────────────────────────────────────────────────────────
  final List<EntryItemUI> _items = [];

  // ── Finanzas ────────────────────────────────────────────────────────────
  String _paymentMode = 'EFECTIVO';
  String _paymentStatus = 'PENDING';
  String? _selectedAccountId;
  String? _activeShiftId;

  // ── Catálogos ───────────────────────────────────────────────────────────
  // Usamos una lista de Maps para capturar los nuevos campos financieros de proveedores
  List<Map<String, dynamic>> _suppliersList = [];
  List<WarehouseModel> _warehouses = [];
  List<FinancialAccountModel> _financialAccounts = [];
  List<ProductModel> _allProducts = [];
  final Map<String, List<ProductVariantModel>> _variantsByProduct = {};

  bool _loading = true;
  bool _saving = false;

  static const List<String> _docTypes = [
    'NINGUNO',
    'FACTURA',
    'BOLETA',
    'GUIA_REMISION',
    'TICKET',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _documentNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        // AQUÍ extraemos directamente el plazo y límite del proveedor
        _supabase
            .from('suppliers')
            .select('id, name, payment_terms_days, credit_limit')
            .eq('is_active', true)
            .order('name'),
        _supabase.from('warehouses').select('id, name').eq('is_active', true),
        _supabase
            .from('financial_accounts')
            .select('id, name, type, balance')
            .eq('is_active', true)
            .order('name'),
        _supabase
            .from('products')
            .select('*, product_images(*)')
            .eq('is_active', true)
            .eq('stock_control', true)
            .neq('product_type', 'service'),
        _supabase
            .from('product_variants')
            .select(
              'id, product_id, sku, attributes, product_images(*), sale_price, unit_cost, is_active',
            )
            .eq('is_active', true),
      ]);

      if (!mounted) return;

      final variants =
          (results[4] as List)
              .map(
                (p) =>
                    ProductVariantModel.fromJson(Map<String, dynamic>.from(p)),
              )
              .toList();

      setState(() {
        _suppliersList = List<Map<String, dynamic>>.from(results[0] as List);
        _warehouses =
            (results[1] as List)
                .map(
                  (w) => WarehouseModel.fromJson(Map<String, dynamic>.from(w)),
                )
                .toList();

        _financialAccounts =
            (results[2] as List)
                .map(
                  (a) => FinancialAccountModel.fromJson(
                    Map<String, dynamic>.from(a),
                  ),
                )
                .toList();

        // Ordenar cajas primero
        _financialAccounts.sort((a, b) {
          final isCajaA = a.type.toUpperCase() == 'CAJA';
          final isCajaB = b.type.toUpperCase() == 'CAJA';
          if (isCajaA && !isCajaB) return -1;
          if (!isCajaA && isCajaB) return 1;
          return a.name.compareTo(b.name);
        });

        _allProducts =
            (results[3] as List).map((p) => ProductModel.fromJson(p)).toList();

        for (final v in variants) {
          _variantsByProduct.putIfAbsent(v.productId, () => []).add(v);
        }

        if (_warehouses.isNotEmpty) _selectedWarehouseId = _warehouses.first.id;
        if (_financialAccounts.isNotEmpty) {
          _selectedAccountId = _financialAccounts.first.id;
          _checkActiveShift(_selectedAccountId!);
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error cargando datos: $e',
          type: SnackbarType.error,
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _checkActiveShift(String accountId) async {
    try {
      final shiftRes =
          await _supabase
              .from('cash_shifts')
              .select('id')
              .eq('account_id', accountId)
              .eq('status', 'OPEN')
              .maybeSingle();
      if (mounted) setState(() => _activeShiftId = shiftRes?['id'] as String?);
    } catch (e) {
      debugPrint('Error verificando turno: $e');
    }
  }

  Future<void> _showAddProductSheet() async {
    if (_selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Por favor, selecciona un almacén de destino primero.',
        type: SnackbarType.warning,
      );
      return;
    }

    final newItem = await showModalBottomSheet<EntryItemUI>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => AddEntryProductSheet(
            allProducts: _allProducts,
            variantsByProduct: _variantsByProduct,
            warehouseId: _selectedWarehouseId,
          ),
    );

    if (newItem != null && mounted) {
      final existingIdx = _items.indexWhere(
        (item) =>
            item.product.id == newItem.product.id &&
            item.variant.id == newItem.variant.id &&
            item.batchNumber == newItem.batchNumber,
      );
      setState(() {
        if (existingIdx >= 0) {
          _items[existingIdx].quantity += newItem.quantity;
          _items[existingIdx].unitCost = newItem.unitCost;
        } else {
          _items.add(newItem);
        }
      });
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Fecha de Entrega o Vencimiento',
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _mostrarDialogoCantidadItem(
    int index,
    double cantidadActual,
  ) async {
    final qtyCtrl = TextEditingController(
      text: cantidadActual.toStringAsFixed(0),
    );
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad a pedir',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final newQty = double.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    setState(() => _items[index].quantity = newQty);
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
    qtyCtrl.dispose();
  }

  Future<void> _saveOrder() async {
    if (_selectedSupplierId == null) {
      AppSnackbar.show(
        context,
        message: 'Debe seleccionar un proveedor',
        type: SnackbarType.warning,
      );
      return;
    }
    if (_selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Debe seleccionar un almacén destino',
        type: SnackbarType.warning,
      );
      return;
    }
    if (_items.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Agregue al menos un producto',
        type: SnackbarType.warning,
      );
      return;
    }

    final totalAmount = _items.fold(0.0, (sum, item) => sum + item.subtotal);

    // Validación Financiera Contado
    if (_paymentStatus == 'PAID' && _selectedAccountId != null) {
      final accountData = _financialAccounts.firstWhereOrNull(
        (a) => a.id == _selectedAccountId,
      );
      if (accountData?.type.toUpperCase() == 'CAJA' && _activeShiftId == null) {
        AppSnackbar.show(
          context,
          message: 'La caja seleccionada no tiene un turno abierto.',
          type: SnackbarType.error,
        );
        return;
      }
      if (accountData != null && accountData.balance < totalAmount) {
        AppSnackbar.show(
          context,
          message: 'Saldo insuficiente en la cuenta',
          type: SnackbarType.error,
        );
        return;
      }
    }

    // ── VALIDACIÓN DEL LÍMITE DE CRÉDITO DEL PROVEEDOR ──
    if (_paymentMode == 'CREDITO') {
      final sup = _suppliersList.firstWhere(
        (s) => s['id'] == _selectedSupplierId,
      );
      final creditLimit = (sup['credit_limit'] as num?)?.toDouble() ?? 0.0;

      if (creditLimit > 0) {
        final creditResp =
            await _supabase
                .from('supplier_credits')
                .select('current_debt')
                .eq('supplier_id', _selectedSupplierId!)
                .maybeSingle();

        final currentDebt =
            creditResp != null
                ? (creditResp['current_debt'] as num).toDouble()
                : 0.0;

        if ((currentDebt + totalAmount) > creditLimit) {
          if (mounted) {
            AppSnackbar.show(
              context,
              message:
                  'Esta orden excede el límite de crédito configurado.\nDeuda actual: S/ ${currentDebt.toStringAsFixed(2)}\nLímite: S/ ${creditLimit.toStringAsFixed(2)}',
              type: SnackbarType.error,
            );
          }

          return;
        }
      }
    }

    setState(() => _saving = true);

    try {
      final currentUser = _supabase.auth.currentUser;
      String? profileId;
      if (currentUser != null) {
        final profile =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', currentUser.id)
                .maybeSingle();
        profileId = profile?['id'] as String?;
      }

      final supplierName =
          _suppliersList.firstWhere(
                (s) => s['id'] == _selectedSupplierId,
              )['name']
              as String;

      // 1. Insertar purchase_orders
      final poResp =
          await _supabase
              .from('purchase_orders')
              .insert({
                'supplier_id': _selectedSupplierId,
                'supplier_name': supplierName,
                'warehouse_id': _selectedWarehouseId,
                'status': 'SENT',
                'total_amount': totalAmount,
                'payment_method': _paymentMode,
                'payment_status': _paymentStatus,
                'amount_paid': _paymentStatus == 'PAID' ? totalAmount : 0,
                'due_date': _dueDate?.toIso8601String().split('T').first,
                'document_type': _documentType,
                'document_number':
                    _documentNumberCtrl.text.trim().isEmpty
                        ? null
                        : _documentNumberCtrl.text.trim(),
                'document_date':
                    _documentDate?.toIso8601String().split('T').first,
                'notes':
                    _notesCtrl.text.trim().isEmpty
                        ? null
                        : _notesCtrl.text.trim(),
                'created_by': profileId,
              })
              .select('id')
              .single();

      final poId = poResp['id'] as String;

      // 2. Insertar purchase_order_items
      for (final item in _items) {
        await _supabase.from('purchase_order_items').insert({
          'purchase_order_id': poId,
          'product_id': item.product.id,
          'variant_id': item.variant.id,
          'quantity_ordered': item.quantity,
          'unit_cost': item.unitCost,
          'net_cost': item.subtotal,
          'batch_number': item.batchNumber,
          'expiry_date': item.expiryDate?.toIso8601String().split('T').first,
        });
      }

      // 3. Finanzas: Pago Adelantado
      if (_paymentStatus == 'PAID' && _selectedAccountId != null) {
        final accountData = _financialAccounts.firstWhere(
          (a) => a.id == _selectedAccountId,
        );

        await _supabase.from('account_movements').insert({
          'account_id': _selectedAccountId,
          'movement_type': 'EXPENSE',
          'amount': totalAmount,
          'description': 'Pago adelantado Orden de Compra · $supplierName',
          'reference_type': 'purchase_order',
          'reference_id': poId,
          'created_by': profileId,
          'shift_id': _activeShiftId,
        });

        await _supabase
            .from('financial_accounts')
            .update({'balance': accountData.balance - totalAmount})
            .eq('id', _selectedAccountId!);
      }
      // 4. Finanzas: Compra a Crédito
      else if (_paymentMode == 'CREDITO') {
        var creditResp =
            await _supabase
                .from('supplier_credits')
                .select('id, current_debt')
                .eq('supplier_id', _selectedSupplierId!)
                .maybeSingle();
        String supplierCreditId;

        if (creditResp == null) {
          final newCredit =
              await _supabase
                  .from('supplier_credits')
                  .insert({
                    'supplier_id': _selectedSupplierId,
                    'current_debt': totalAmount,
                    'created_by': profileId,
                  })
                  .select('id')
                  .single();
          supplierCreditId = newCredit['id'] as String;
        } else {
          supplierCreditId = creditResp['id'] as String;
          await _supabase
              .from('supplier_credits')
              .update({
                'current_debt':
                    (creditResp['current_debt'] as num).toDouble() +
                    totalAmount,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', supplierCreditId);
        }

        await _supabase.from('supplier_credit_movements').insert({
          'supplier_credit_id': supplierCreditId,
          'purchase_order_id': poId,
          'movement_type': 'CHARGE',
          'amount': totalAmount,
          'payment_method': 'CREDITO',
          'due_date': _dueDate?.toIso8601String().split('T').first,
          'notes': 'Orden de Compra en Tránsito',
          'created_by': profileId,
        });
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Orden generada con éxito',
          type: SnackbarType.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al guardar la orden: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AdminLayout(
        title: 'Nueva Orden',
        showBackButton: true,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final double totalCost = _items.fold(0, (sum, item) => sum + item.subtotal);
    final int totalUnits = _items.fold(
      0,
      (sum, item) => sum + item.quantity.toInt(),
    );
    final int totalVariants = _items.length;

    return AdminLayout(
      title: 'Nueva Orden de Compra',
      showBackButton: true,
      body:
          _saving
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Datos de la Orden ──────────────────────────────
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle(
                                  icon: Icons.storefront_rounded,
                                  title: 'Datos de la Orden',
                                ),
                                const SizedBox(height: 12),

                                // Proveedor
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedSupplierId,
                                  icon: const Icon(Icons.expand_more_rounded),
                                  decoration: _dropdownDecoration(
                                    'Proveedor (Obligatorio)',
                                    icon: Icons.local_shipping_rounded,
                                  ),
                                  items:
                                      _suppliersList
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s['id'] as String,
                                              child: Text(
                                                s['name'] as String,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _selectedSupplierId = v;
                                        // ── CÁLCULO DE FECHA DE VENCIMIENTO SEGÚN PROVEEDOR ──
                                        final sup = _suppliersList.firstWhere(
                                          (s) => s['id'] == v,
                                        );
                                        final terms =
                                            sup['payment_terms_days'] as int? ??
                                            0;
                                        if (terms > 0) {
                                          _dueDate = DateTime.now().add(
                                            Duration(days: terms),
                                          );
                                        }
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Almacén
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedWarehouseId,
                                  icon: const Icon(Icons.expand_more_rounded),
                                  decoration: _dropdownDecoration(
                                    'Almacén de Destino',
                                    icon: Icons.warehouse_rounded,
                                  ),
                                  items:
                                      _warehouses
                                          .map(
                                            (w) => DropdownMenuItem(
                                              value: w.id,
                                              child: Text(
                                                w.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setState(
                                        () => _selectedWarehouseId = v,
                                      ),
                                ),
                                const SizedBox(height: 12),

                                // Fecha de Entrega / Vencimiento
                                InkWell(
                                  onTap: _pickDueDate,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.event_available_rounded,
                                          color: AppColors.textHint,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _dueDate != null
                                                ? 'Vence / Entrega: ${DateFormat('dd/MM/yyyy').format(_dueDate!)}'
                                                : 'Fecha de Vencimiento / Entrega (Opcional)',
                                            style: TextStyle(
                                              color:
                                                  _dueDate != null
                                                      ? AppColors.textPrimary
                                                      : AppColors.textSecondary,
                                              fontWeight:
                                                  _dueDate != null
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Tipo de Documento
                                DropdownButtonFormField<String>(
                                  initialValue: _documentType,
                                  icon: const Icon(Icons.expand_more_rounded),
                                  decoration: _dropdownDecoration(
                                    'Tipo de Comprobante',
                                    icon: Icons.description_rounded,
                                  ),
                                  items:
                                      _docTypes
                                          .map(
                                            (t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(
                                                t,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _documentType = v);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Número de Comprobante (Solo si no es NINGUNO)
                                if (_documentType != 'NINGUNO') ...[
                                  TextField(
                                    controller: _documentNumberCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Nº de comprobante (Opcional)',
                                      labelStyle: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                      filled: true,
                                      fillColor: AppColors.background,
                                      prefixIcon: const Icon(
                                        Icons.tag_rounded,
                                        color: AppColors.textHint,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Notas
                                TextField(
                                  controller: _notesCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Notas / Referencia (Opcional)',
                                    labelStyle: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.background,
                                    prefixIcon: const Icon(
                                      Icons.notes_rounded,
                                      color: AppColors.textHint,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Forma de Pago ──────────────────────────────────
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle(
                                  icon: Icons.payments_rounded,
                                  title: 'Forma de Pago',
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _PaymentModeButton(
                                        label: 'Pago Adelantado',
                                        icon: Icons.attach_money_rounded,
                                        selected: _paymentStatus == 'PAID',
                                        onTap:
                                            () => setState(() {
                                              _paymentMode = 'EFECTIVO';
                                              _paymentStatus = 'PAID';
                                            }),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _PaymentModeButton(
                                        label: 'Crédito',
                                        icon: Icons.schedule_rounded,
                                        selected: _paymentMode == 'CREDITO',
                                        onTap:
                                            () => setState(() {
                                              _paymentMode = 'CREDITO';
                                              _paymentStatus = 'PENDING';
                                            }),
                                      ),
                                    ),
                                  ],
                                ),

                                if (_paymentStatus == 'PAID') ...[
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedAccountId,
                                    icon: const Icon(Icons.expand_more_rounded),
                                    decoration: _dropdownDecoration(
                                      'Cuenta que realiza el adelanto',
                                      icon: Icons.account_balance_rounded,
                                    ),
                                    items:
                                        _financialAccounts.map((a) {
                                          return DropdownMenuItem<String>(
                                            value: a.id,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    a.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'S/ ${a.balance.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        a.balance > 0
                                                            ? AppColors.success
                                                            : AppColors.danger,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedAccountId = v);
                                        _checkActiveShift(v);
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Lista de ítems ─────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Items ($totalVariants)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: _showAddProductSheet,
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Añadir',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_items.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 32,
                                    color: AppColors.textHint,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Lista vacía',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Añade productos para tu orden de compra.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              separatorBuilder:
                                  (_, _) => const SizedBox(height: 10),
                              itemBuilder:
                                  (context, index) =>
                                      _buildEntryItemCard(_items[index], index),
                            ),
                        ],
                      ),
                    ),
                  ),

                  _BottomBar(
                    leftLabel: 'Costo Total',
                    leftSub: '$totalVariants items · $totalUnits unidades',
                    rightValue: 'S/ ${totalCost.toStringAsFixed(2)}',
                    buttonLabel:
                        _paymentStatus == 'PAID'
                            ? 'Generar y Pagar'
                            : 'Generar Orden',
                    buttonIcon:
                        _paymentStatus == 'PAID'
                            ? Icons.payments_rounded
                            : Icons.save_rounded,
                    enabled: _items.isNotEmpty,
                    onPressed: _saveOrder,
                  ),
                ],
              ),
    );
  }

  Widget _buildEntryItemCard(EntryItemUI item, int index) {
    String? imageUrl;
    if (item.variant.images.isNotEmpty) {
      imageUrl = item.variant.images.first.imageUrl;
    } else if (item.product.images.isNotEmpty) {
      imageUrl =
          item.product.images
              .firstWhere(
                (img) => img.isMain,
                orElse: () => item.product.images.first,
              )
              .imageUrl;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ProductThumbnail(imageUrl: imageUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.variant.id.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _VariantChip(label: item.variant.label),
                ],
                if (item.batchNumber != 'DEFAULT') ...[
                  const SizedBox(height: 4),
                  _BatchInfo(
                    batchNumber: item.batchNumber,
                    expiryDate: item.expiryDate,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Costo: S/ ${item.unitCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'S/ ${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _VerticalStepper(
            value: item.quantity.toInt(),
            onAdd: () => setState(() => _items[index].quantity++),
            onRemove:
                item.quantity > 1
                    ? () => setState(() => _items[index].quantity--)
                    : null,
            onTapValue: () => _mostrarDialogoCantidadItem(index, item.quantity),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
              size: 22,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _items.removeAt(index)),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares para mantener el diseño visual ────────────────────────

class _PaymentModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _dropdownDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    prefixIcon: icon != null ? Icon(icon, color: AppColors.textHint) : null,
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
  // ignore: unused_element_parameter
  const _ProductThumbnail({this.imageUrl, this.size = 56});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child:
            imageUrl != null
                ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder:
                      (_, _) => const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  errorWidget:
                      (_, _, _) => const Icon(
                        Icons.image_not_supported_rounded,
                        color: AppColors.textHint,
                      ),
                )
                : const Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.textHint,
                ),
      ),
    );
  }
}

class _VariantChip extends StatelessWidget {
  final String label;
  const _VariantChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BatchInfo extends StatelessWidget {
  final String batchNumber;
  final DateTime? expiryDate;
  const _BatchInfo({required this.batchNumber, this.expiryDate});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.tag_rounded, size: 11, color: AppColors.textHint),
        const SizedBox(width: 2),
        Text(
          batchNumber,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (expiryDate != null) ...[
          const SizedBox(width: 8),
          const Icon(
            Icons.calendar_today_rounded,
            size: 11,
            color: AppColors.textHint,
          ),
          const SizedBox(width: 2),
          Text(
            '${expiryDate!.day.toString().padLeft(2, '0')}/${expiryDate!.month.toString().padLeft(2, '0')}/${expiryDate!.year}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _VerticalStepper extends StatelessWidget {
  final int value;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final VoidCallback onTapValue;
  const _VerticalStepper({
    required this.value,
    required this.onAdd,
    this.onRemove,
    required this.onTapValue,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperBtn(Icons.add_rounded, false, onAdd),
        const SizedBox(height: 4),
        Material(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTapValue,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _stepperBtn(Icons.remove_rounded, onRemove == null, onRemove ?? () {}),
      ],
    );
  }
}

Widget _stepperBtn(IconData icon, bool disabled, VoidCallback onTap) {
  return Material(
    color: disabled ? const Color(0xFFF1F5F9) : AppColors.primary,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: disabled ? AppColors.textMuted : Colors.white,
        ),
      ),
    ),
  );
}

class _BottomBar extends StatelessWidget {
  final String leftLabel, leftSub, rightValue, buttonLabel;
  final IconData buttonIcon;
  final bool enabled;
  final VoidCallback onPressed;
  const _BottomBar({
    required this.leftLabel,
    required this.leftSub,
    required this.rightValue,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leftLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      leftSub,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  rightValue,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: enabled ? onPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.background,
                  disabledForegroundColor: AppColors.textHint,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(buttonIcon, size: 20, color: Colors.white),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
