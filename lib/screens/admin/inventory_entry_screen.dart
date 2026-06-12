import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/models/supplier_model.dart';
import 'package:inventory_store_app/models/financial_account_model.dart';
import 'package:inventory_store_app/screens/admin/kardex_screen.dart';
import 'package:inventory_store_app/screens/admin/widgets/add_entry_product_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/inventory_entry_item_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:collection/collection.dart';

// ─── Modelo de UI local ───────────────────────────────────────────────────────
class EntryItemUI {
  final ProductModel product;
  final ProductVariantModel variant;
  double quantity;
  double unitCost;
  final String batchNumber;
  final DateTime? expiryDate;

  EntryItemUI({
    required this.product,
    required this.variant,
    required this.quantity,
    required this.unitCost,
    this.batchNumber = 'DEFAULT',
    this.expiryDate,
  });

  double get subtotal => quantity * unitCost;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class InventoryEntryScreen extends StatefulWidget {
  const InventoryEntryScreen({super.key});

  @override
  State<InventoryEntryScreen> createState() => _InventoryEntryScreenState();
}

class _InventoryEntryScreenState extends State<InventoryEntryScreen> {
  final _supabase = Supabase.instance.client;

  // ── Datos generales ───────────────────────────────────────────────────────
  String? _selectedWarehouseId;
  String? _selectedSupplierId;
  List<WarehouseModel> _warehouses = [];
  List<SupplierModel> _suppliers = [];
  bool _loadingWarehouses = true;

  // ── Productos ─────────────────────────────────────────────────────────────
  List<ProductModel> _allProducts = [];
  bool _loadingProducts = true;
  final Map<String, List<ProductVariantModel>> _variantsByProduct = {};

  // ── Cuentas financieras ───────────────────────────────────────────────────
  List<FinancialAccountModel> _financialAccounts = [];
  String?
  _selectedAccountId; // La cuenta con la que vas a pagar (Caja, Yape, etc.)
  String? _activeShiftId; // Aquí guardaremos el ID del turno si está abierto
  // Método de pago que se registrará en account_movements
  // 'CONTADO' = pagado al momento. 'CREDITO' = no genera movimiento financiero aún.
  String _paymentMode = 'CONTADO';
  bool _loadingAccounts = true;

  // ── Items e ítems de UI ───────────────────────────────────────────────────
  final List<EntryItemUI> _items = [];
  bool _saving = false;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Carga inicial de datos ────────────────────────────────────────────────

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _supabase.from('warehouses').select('id, name').eq('is_active', true),
        _supabase
            .from('suppliers')
            .select('id, name')
            .eq('is_active', true)
            .order('name'),
        _supabase
            .from('products')
            .select('*, product_images(*)')
            .eq('is_active', true)
            .eq('stock_control', true)
            .neq('product_type', 'service')
            .order('name'),
        _supabase
            .from('product_variants')
            .select(
              'id, product_id, sku, attributes, product_images(*), sale_price, unit_cost, is_active',
            )
            .eq('is_active', true)
            .order('created_at', ascending: true),
        // Cuentas financieras activas para registrar el egreso de pago
        _supabase
            .from('financial_accounts')
            .select('id, name, type, balance')
            .eq('is_active', true)
            .order('name'),
      ]);

      if (!mounted) return;

      final warehousesResp = results[0] as List;
      final suppliersResp = results[1] as List;
      final productsResp = results[2] as List;
      final variantsResp = results[3] as List;
      final accountsResp = results[4] as List;

      final variants =
          variantsResp
              .map(
                (p) =>
                    ProductVariantModel.fromJson(Map<String, dynamic>.from(p)),
              )
              .toList();

      setState(() {
        _warehouses =
            warehousesResp
                .map(
                  (w) => WarehouseModel.fromJson(Map<String, dynamic>.from(w)),
                )
                .toList();
        if (_warehouses.isNotEmpty) {
          _selectedWarehouseId = _warehouses.first.id;
        }
        _suppliers =
            suppliersResp
                .map(
                  (s) => SupplierModel.fromJson(Map<String, dynamic>.from(s)),
                )
                .toList();

        _allProducts =
            productsResp.map((p) => ProductModel.fromJson(p)).toList();

        _variantsByProduct.clear();
        for (final variant in variants) {
          _variantsByProduct
              .putIfAbsent(variant.productId, () => [])
              .add(variant);
        }

        _financialAccounts =
            accountsResp
                .map(
                  (a) => FinancialAccountModel.fromJson(
                    Map<String, dynamic>.from(a),
                  ),
                )
                .toList();

        // 1. ORDENAR: Cuentas tipo CAJA primero, y luego alfabéticamente
        _financialAccounts.sort((a, b) {
          final isCajaA = a.type.toUpperCase() == 'CAJA';
          final isCajaB = b.type.toUpperCase() == 'CAJA';

          if (isCajaA && !isCajaB) return -1; // 'a' va antes
          if (!isCajaA && isCajaB) return 1; // 'b' va antes
          return a.name.compareTo(b.name); // Empate: orden alfabético
        });

        // 2. PRESELECCIONAR: Como ordenamos arriba, la primera será CAJA (si existe)
        if (_financialAccounts.isNotEmpty) {
          _selectedAccountId = _financialAccounts.first.id;
          _checkActiveShift(_selectedAccountId!);
        }

        _loadingWarehouses = false;
        _loadingProducts = false;
        _loadingAccounts = false;
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error cargando datos: $e',
          type: SnackbarType.error,
        );
        setState(() {
          _loadingWarehouses = false;
          _loadingProducts = false;
          _loadingAccounts = false;
        });
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

      if (mounted) {
        setState(() {
          _activeShiftId = shiftRes?['id'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error verificando turno de caja: $e');
    }
  }

  // ── Añadir producto desde bottom sheet ───────────────────────────────────

  Future<void> _showAddProductSheet() async {
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
            item.variant.id == newItem.variant.id,
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

  // ── Diálogo de cantidad ───────────────────────────────────────────────────

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
              'Cantidad a ingresar',
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
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  final newQty = double.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    setState(() => _items[index].quantity = newQty);
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
    qtyCtrl.dispose();
  }

  // ── Guardar entrada ───────────────────────────────────────────────────────

  Future<void> _saveEntry() async {
    // ── Validaciones ────────────────────────────────────────────────────────
    if (_selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén',
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

    // Si el modo de pago es CONTADO, debe haber una cuenta financiera seleccionada.
    if (_paymentMode == 'CONTADO' && _selectedAccountId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione la cuenta financiera que se utilizará para pagar',
        type: SnackbarType.warning,
      );
      return;
    }

    // Si el modo de pago es CONTADO y la cuenta es de tipo CAJA, debe tener un turno abierto.
    if (_paymentMode == 'CONTADO' && _selectedAccountId != null) {
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
    }

    // Validar que al pagar al contado la cuenta tenga saldo suficiente.
    if (_paymentMode == 'CONTADO' && _selectedAccountId != null) {
      final accountData = _financialAccounts
          .cast<FinancialAccountModel?>()
          .firstWhere((a) => a?.id == _selectedAccountId, orElse: () => null);
      if (accountData != null) {
        final accountBalance = accountData.balance;
        final totalCost = _items.fold(0.0, (sum, item) => sum + item.subtotal);
        if (accountBalance < totalCost) {
          AppSnackbar.show(
            context,
            message:
                'Saldo insuficiente en la cuenta seleccionada '
                '(S/ ${accountBalance.toStringAsFixed(2)} disponible)',
            type: SnackbarType.error,
          );
          return;
        }
      }
    }

    setState(() => _saving = true);

    try {
      final notes = _notesCtrl.text.trim();

      // ── Obtener profile_id del usuario actual ───────────────────────────
      String? createdByProfileId;
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        final profile =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', currentUser.id)
                .maybeSingle();
        createdByProfileId = profile?['id'] as String?;
      }

      // 1. ── Cabecera del ingreso ─────────────────────────────────────────
      final entryHeader =
          await _supabase
              .from('inventory_entries')
              .insert({
                'warehouse_id': _selectedWarehouseId,
                'supplier_id': _selectedSupplierId,
                'notes': notes.isEmpty ? null : notes,
                'created_by': createdByProfileId,
              })
              .select('id')
              .single();

      final entryId = entryHeader['id'] as String;

      double totalCost = 0;

      for (final item in _items) {
        totalCost += item.subtotal;

        // 2. ── Insertar en inventory_entry_items ─────────────────────────
        final entryItem = InventoryEntryItemModel(
          id: '',
          entryId: entryId,
          productId: item.product.id,
          variantId: item.variant.id,
          quantity: item.quantity,
          unitCost: item.unitCost,
          batchNumber: item.batchNumber,
          expiryDate: item.expiryDate,
        );
        await _supabase.from('inventory_entry_items').insert({
          ...entryItem.toJson()..remove('id'),
        });

        // 3. ── Upsert en warehouse_stock_batches ─────────────────────────
        final existingBatch =
            await _supabase
                .from('warehouse_stock_batches')
                .select('id, available_quantity')
                .eq('variant_id', item.variant.id)
                .eq('warehouse_id', _selectedWarehouseId!)
                .eq('batch_number', item.batchNumber)
                .maybeSingle();

        double previousStock = 0;
        double newStock = 0;
        String? stockBatchId;

        if (existingBatch != null) {
          stockBatchId = existingBatch['id'] as String;
          previousStock =
              (existingBatch['available_quantity'] as num).toDouble();
          newStock = previousStock + item.quantity;
          await _supabase
              .from('warehouse_stock_batches')
              .update({
                'available_quantity': newStock,
                'updated_at': DateTime.now().toIso8601String(),
                'updated_by': createdByProfileId,
              })
              .eq('id', stockBatchId);

          // Actualizar unit_cost de la variante al último costo de compra
          await _supabase
              .from('product_variants')
              .update({
                'unit_cost': item.unitCost,
                'updated_by': createdByProfileId,
              })
              .eq('id', item.variant.id);
        } else {
          newStock = item.quantity;
          final newBatch =
              await _supabase
                  .from('warehouse_stock_batches')
                  .insert({
                    'variant_id': item.variant.id,
                    'warehouse_id': _selectedWarehouseId,
                    'product_id': item.product.id,
                    'supplier_id': _selectedSupplierId,
                    'batch_number': item.batchNumber,
                    'expiry_date':
                        item.expiryDate?.toIso8601String().split('T').first,
                    'available_quantity': newStock,
                    'created_by': createdByProfileId,
                    'updated_by': createdByProfileId,
                  })
                  .select('id')
                  .single();
          stockBatchId = newBatch['id'] as String;

          // Actualizar unit_cost de la variante al último costo de compra
          await _supabase
              .from('product_variants')
              .update({
                'unit_cost': item.unitCost,
                'updated_by': createdByProfileId,
              })
              .eq('id', item.variant.id);
        }

        // 4. ── Registrar en inventory_movements (kardex) ─────────────────
        await _supabase.from('inventory_movements').insert({
          'variant_id': item.variant.id,
          'warehouse_id': _selectedWarehouseId,
          'stock_batch_id': stockBatchId,
          'inventory_entry_id': entryId,
          'quantity': item.quantity,
          'previous_stock': previousStock,
          'new_stock': newStock,
          'unit_cost': item.unitCost,
          'total_cost': item.subtotal,
          'reason': 'ENTRY',
          'notes': notes.isEmpty ? null : notes,
          'created_by': createdByProfileId,
        });
      }

      // 5. ── Movimiento financiero (solo si es pago al contado) ───────────
      //    Registra un EGRESO en la cuenta seleccionada por el total de la compra.
      if (_paymentMode == 'CONTADO' && _selectedAccountId != null) {
        final accountData = _financialAccounts.firstWhere(
          (a) => a.id == _selectedAccountId,
        );
        final currentBalance = accountData.balance;
        final newBalance = currentBalance - totalCost;

        // 5a. Insertar en account_movements
        await _supabase.from('account_movements').insert({
          'account_id': _selectedAccountId,
          'movement_type': 'EXPENSE',
          'amount': totalCost,
          'description':
              'Compra de inventario — Entrada #$entryId'
              '${_selectedSupplierId != null ? ' · ${_suppliers.firstWhere((s) => s.id == _selectedSupplierId).name}' : ''}',
          'reference_type': 'inventory_entry',
          'reference_id': entryId,
          'created_by': createdByProfileId,
          'shift_id': _activeShiftId,
        });

        // 5b. Actualizar saldo de la cuenta financiera
        await _supabase
            .from('financial_accounts')
            .update({'balance': newBalance})
            .eq('id', _selectedAccountId!);
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              _paymentMode == 'CONTADO'
                  ? 'Ingreso registrado y pago deducido correctamente'
                  : 'Ingreso registrado. Pago pendiente al proveedor.',
          type: SnackbarType.success,
        );
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const KardexScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error registrando entrada: $e',
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
    if (_loadingWarehouses || _loadingProducts || _loadingAccounts) {
      return const AdminLayout(
        title: 'Recepción',
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
      title: 'Recepción de Inventario',
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
                          // ── Sección: Datos del ingreso ────────────────────
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle(
                                  icon: Icons.input_rounded,
                                  title: 'Datos del Ingreso',
                                ),
                                const SizedBox(height: 12),

                                // Almacén
                                DropdownButtonFormField<String>(
                                  value: _selectedWarehouseId,
                                  icon: const Icon(Icons.expand_more_rounded),
                                  decoration: _dropdownDecoration(
                                    'Almacén de Recepción',
                                    icon: Icons.warehouse_rounded,
                                  ),
                                  items:
                                      _warehouses
                                          .map(
                                            (s) => DropdownMenuItem<String>(
                                              value: s.id,
                                              child: Text(
                                                s.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      // CORRECCIÓN: Aquí se actualiza el Almacén, no la cuenta
                                      setState(() => _selectedWarehouseId = v);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Proveedor (opcional)
                                DropdownButtonFormField<String>(
                                  value: _selectedSupplierId,
                                  icon: const Icon(Icons.expand_more_rounded),
                                  decoration: _dropdownDecoration(
                                    'Proveedor (opcional)',
                                    icon: Icons.local_shipping_rounded,
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        'Sin proveedor',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    ..._suppliers.map(
                                      (s) => DropdownMenuItem<String>(
                                        value: s.id,
                                        child: Text(
                                          s.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged:
                                      (v) => setState(
                                        () => _selectedSupplierId = v,
                                      ),
                                ),
                                const SizedBox(height: 12),

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

                          // ── Sección: Pago ─────────────────────────────────
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle(
                                  icon: Icons.payments_rounded,
                                  title: 'Forma de Pago',
                                ),
                                const SizedBox(height: 12),

                                // Toggle CONTADO / CRÉDITO
                                Row(
                                  children: [
                                    Expanded(
                                      child: _PaymentModeButton(
                                        label: 'Contado',
                                        icon: Icons.attach_money_rounded,
                                        selected: _paymentMode == 'CONTADO',
                                        onTap:
                                            () => setState(
                                              () => _paymentMode = 'CONTADO',
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _PaymentModeButton(
                                        label: 'Crédito',
                                        icon: Icons.schedule_rounded,
                                        selected: _paymentMode == 'CREDITO',
                                        onTap:
                                            () => setState(
                                              () => _paymentMode = 'CREDITO',
                                            ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Selector de cuenta financiera (solo al contado)
                                if (_paymentMode == 'CONTADO') ...[
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: _selectedAccountId,
                                    icon: const Icon(Icons.expand_more_rounded),
                                    decoration: _dropdownDecoration(
                                      'Cuenta que realizará el pago',
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
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    a.type,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedAccountId = v);
                                        // AQUÍ ES DONDE DEBE IR LA VERIFICACIÓN DE LA CAJA
                                        _checkActiveShift(v);
                                      }
                                    },
                                  ),

                                  // --- INICIO UI DE TURNO ABIERTO/CERRADO ---
                                  if (_selectedAccountId != null &&
                                      _financialAccounts
                                              .firstWhereOrNull(
                                                (a) =>
                                                    a.id == _selectedAccountId,
                                              )
                                              ?.type
                                              .toUpperCase() ==
                                          'CAJA')
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _activeShiftId != null
                                                ? Icons.check_circle_rounded
                                                : Icons.warning_rounded,
                                            size: 14,
                                            color:
                                                _activeShiftId != null
                                                    ? AppColors.success
                                                    : AppColors.danger,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _activeShiftId != null
                                                ? 'Turno de caja abierto'
                                                : 'Caja cerrada (Se requiere turno abierto)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  _activeShiftId != null
                                                      ? AppColors.success
                                                      : AppColors.danger,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // --- FIN UI DE TURNO ABIERTO/CERRADO ---

                                  // Advertencia si el saldo es insuficiente
                                  if (_selectedAccountId != null &&
                                      _items.isNotEmpty)
                                    Builder(
                                      builder: (context) {
                                        final accountData = _financialAccounts
                                            .firstWhereOrNull(
                                              (a) => a.id == _selectedAccountId,
                                            );

                                        final balance =
                                            (accountData?.balance as num?)
                                                ?.toDouble() ??
                                            0.0;

                                        final total = _items.fold(
                                          0.0,
                                          (s, i) => s + i.subtotal,
                                        );
                                        if (balance >= total) {
                                          return const SizedBox.shrink();
                                        }
                                        return Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: AppColors.danger
                                                  .withValues(alpha: 0.25),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.warning_amber_rounded,
                                                color: AppColors.danger,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Saldo insuficiente. '
                                                  'Faltan S/ ${(total - balance).toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.danger,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                ],

                                // Info crédito
                                if (_paymentMode == 'CREDITO') ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.warning.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          color: AppColors.warning,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'No se descontará saldo de ninguna cuenta. '
                                            'El pago al proveedor queda pendiente.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.warning,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Lista de ítems ───────────────────────────────
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
                            _EmptyState(
                              icon: Icons.widgets_rounded,
                              message:
                                  'Añade productos para registrar su ingreso.',
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 10),
                              itemBuilder:
                                  (context, index) =>
                                      _buildEntryItemCard(_items[index], index),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Footer ───────────────────────────────────────────────
                  _BottomBar(
                    leftLabel: 'Costo Total',
                    leftSub: '$totalVariants items · $totalUnits unidades',
                    rightValue: 'S/ ${totalCost.toStringAsFixed(2)}',
                    buttonLabel:
                        _paymentMode == 'CONTADO'
                            ? 'Registrar y Pagar'
                            : 'Registrar (Crédito)',
                    buttonIcon:
                        _paymentMode == 'CONTADO'
                            ? Icons.payments_rounded
                            : Icons.save_rounded,
                    enabled: _items.isNotEmpty,
                    onPressed: _saveEntry,
                  ),
                ],
              ),
    );
  }

  // ── Card de ítem ──────────────────────────────────────────────────────────

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

          // Stepper vertical
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

          // Eliminar
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

// ─── Botón de modo de pago ────────────────────────────────────────────────────

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

// ─── Helpers de decoración ────────────────────────────────────────────────────

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

// ─── Widgets reutilizables ────────────────────────────────────────────────────

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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppColors.textHint),
          ),
          const SizedBox(height: 16),
          const Text(
            'Lista vacía',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
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
                ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => const Icon(
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
            '${expiryDate!.day.toString().padLeft(2, '0')}/'
            '${expiryDate!.month.toString().padLeft(2, '0')}/'
            '${expiryDate!.year}',
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
  final String leftLabel;
  final String leftSub;
  final String rightValue;
  final String buttonLabel;
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