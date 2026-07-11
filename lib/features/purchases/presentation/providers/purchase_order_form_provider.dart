import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/purchases/data/repositories/purchase_orders_service.dart';
import 'package:collection/collection.dart';

class PurchaseOrderFormProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _service = PurchaseOrdersService();
  static const _draftKey = 'po_form_draft_v1';

  // State
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // Catalogs
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> get suppliers => _suppliers;

  List<WarehouseModel> _warehouses = [];
  List<WarehouseModel> get warehouses => _warehouses;

  List<FinancialAccountModel> _accounts = [];
  List<FinancialAccountModel> get accounts => _accounts;

  // Form Data
  List<InventoryEntryItemEntity> _items = [];
  List<InventoryEntryItemEntity> get items => _items;

  String? _selectedSupplierId;
  String? get selectedSupplierId => _selectedSupplierId;

  String? _selectedWarehouseId;
  String? get selectedWarehouseId => _selectedWarehouseId;

  DateTime? _dueDate;
  DateTime? get dueDate => _dueDate;

  DateTime? _documentDate;
  DateTime? get documentDate => _documentDate;

  String _documentType = 'NINGUNO';
  String get documentType => _documentType;

  String _paymentMode = 'EFECTIVO';
  String get paymentMode => _paymentMode;

  String _paymentStatus = 'PENDING';
  String get paymentStatus => _paymentStatus;

  String? _selectedAccountId;
  String? get selectedAccountId => _selectedAccountId;

  String? _activeShiftId;
  String? get activeShiftId => _activeShiftId;

  Future<void> loadCatalogsAndDraft() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final results = await Future.wait([
        _supabase
            .from('suppliers')
            .select(
              'id, name, supplier_credits(credit_limit, current_debt, payment_terms_days, is_active)',
            )
            .eq('is_active', true)
            .order('name'),
        _supabase.from('warehouses').select('id, name').eq('is_active', true),
        _supabase
            .from('financial_accounts')
            .select('id, name, type, balance')
            .eq('is_active', true)
            .order('name'),
      ]);

      _suppliers = List<Map<String, dynamic>>.from(results[0] as List);
      _warehouses =
          (results[1] as List)
              .map((w) => WarehouseModel.fromJson(Map<String, dynamic>.from(w)))
              .toList();
      _accounts =
          (results[2] as List)
              .map(
                (a) => FinancialAccountModel.fromJson(
                  Map<String, dynamic>.from(a),
                ),
              )
              .toList();

      _accounts.sort((a, b) {
        final isCajaA = a.type.toUpperCase() == 'CAJA';
        final isCajaB = b.type.toUpperCase() == 'CAJA';
        if (isCajaA && !isCajaB) return -1;
        if (!isCajaA && isCajaB) return 1;
        return a.name.compareTo(b.name);
      });

      if (_accounts.isNotEmpty) {
        _selectedAccountId = _accounts.first.id;
        await _checkActiveShift(_selectedAccountId!);
      }

      await _loadDraft();
    } catch (e) {
      debugPrint('Error loading form data: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error cargando datos.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
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
      _activeShiftId = shiftRes?['id'] as String?;
    } catch (e) {
      debugPrint('Error verificando turno: $e');
    }
  }

  // ── SETTERS ──
  void _recalculateDueDate() {
    if (_paymentMode == 'CREDITO' && _selectedSupplierId != null) {
      final supplier = _suppliers.firstWhere(
        (s) => s['id'] == _selectedSupplierId,
        orElse: () => {},
      );
      final creditData = getCreditData(supplier);
      if (creditData != null && creditData['payment_terms_days'] != null) {
        final days = creditData['payment_terms_days'] as int;
        final baseDate = _documentDate ?? DateTime.now();
        _dueDate = baseDate.add(Duration(days: days));
      }
    }
  }

  void setSupplier(String? id) {
    _selectedSupplierId = id;
    _recalculateDueDate();
    _saveDraft();
    notifyListeners();
  }

  void setWarehouse(String? id) {
    _selectedWarehouseId = id;
    _saveDraft();
    notifyListeners();
  }

  void setDueDate(DateTime? date) {
    _dueDate = date;
    _saveDraft();
    notifyListeners();
  }

  void setDocumentDate(DateTime? date) {
    _documentDate = date;
    _recalculateDueDate();
    _saveDraft();
    notifyListeners();
  }

  void setDocumentType(String type) {
    _documentType = type;
    _saveDraft();
    notifyListeners();
  }

  void setPaymentMode(String mode) {
    _paymentMode = mode;
    _recalculateDueDate();
    _saveDraft();
    notifyListeners();
  }

  void setPaymentStatus(String status) {
    _paymentStatus = status;
    _saveDraft();
    notifyListeners();
  }

  void setAccount(String? id) {
    _selectedAccountId = id;
    if (id != null) {
      _checkActiveShift(id).then((_) => notifyListeners());
    }
    _saveDraft();
    notifyListeners();
  }

  void addItem(InventoryEntryItemEntity item) {
    final existingIdx = _items.indexWhere(
      (i) =>
          i.productId == item.productId &&
          i.variantId == item.variantId &&
          i.batchNumber == item.batchNumber,
    );
    if (existingIdx >= 0) {
      _items[existingIdx] = _items[existingIdx].copyWith(
        quantity: _items[existingIdx].quantity + item.quantity,
        unitCost: item.unitCost,
      );
    } else {
      _items.add(item);
    }
    _saveDraft();
    notifyListeners();
  }

  void updateItemQuantity(int index, double qty) {
    if (qty > 0) {
      _items[index] = _items[index].copyWith(quantity: qty);
      _saveDraft();
      notifyListeners();
    }
  }

  void removeItem(int index) {
    _items.removeAt(index);
    _saveDraft();
    notifyListeners();
  }

  Future<void> clearDraft() async {
    _items.clear();
    _selectedSupplierId = null;
    _selectedWarehouseId = null; // Resetear almacén para no contaminar la próxima sesión
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    notifyListeners();
  }

  // ── SAVE LOGIC ──
  Map<String, dynamic>? getCreditData(Map<String, dynamic> supplier) {
    final cred = supplier['supplier_credits'];
    if (cred is List && cred.isNotEmpty) return cred.first;
    if (cred is Map<String, dynamic>) return cred;
    return null;
  }

  Future<bool> saveOrder({
    required String documentNumber,
    required String notes,
  }) async {
    _errorMessage = '';

    if (_selectedSupplierId == null) {
      _errorMessage = 'Debe seleccionar un proveedor';
      notifyListeners();
      return false;
    }
    if (_selectedWarehouseId == null) {
      _errorMessage = 'Debe seleccionar un almacén destino';
      notifyListeners();
      return false;
    }
    if (_items.isEmpty) {
      _errorMessage = 'Agregue al menos un producto';
      notifyListeners();
      return false;
    }

    final totalAmount = _items.fold(0.0, (sum, item) => sum + item.subtotal);

    // Validación Contado
    if (_paymentStatus == 'PAID' && _selectedAccountId != null) {
      final accountData = _accounts.firstWhereOrNull(
        (a) => a.id == _selectedAccountId,
      );
      if (accountData?.type.toUpperCase() == 'CAJA' && _activeShiftId == null) {
        _errorMessage = 'La caja seleccionada no tiene un turno abierto.';
        notifyListeners();
        return false;
      }
      if (accountData != null && accountData.balance < totalAmount) {
        _errorMessage = 'Saldo insuficiente en la cuenta';
        notifyListeners();
        return false;
      }
    }

    // Validación Crédito
    if (_paymentMode == 'CREDITO') {
      final sup = _suppliers.firstWhere((s) => s['id'] == _selectedSupplierId);
      final creditData = getCreditData(sup);

      if (creditData == null || creditData['is_active'] == false) {
        _errorMessage =
            'Este proveedor no tiene una línea de crédito activa configurada.';
        notifyListeners();
        return false;
      }

      final creditLimit =
          (creditData['credit_limit'] as num?)?.toDouble() ?? 0.0;
      final currentDebt =
          (creditData['current_debt'] as num?)?.toDouble() ?? 0.0;

      if ((currentDebt + totalAmount) > creditLimit) {
        _errorMessage =
            'Excede límite de crédito.\nDeuda: S/ ${currentDebt.toStringAsFixed(2)}\nLímite: S/ ${creditLimit.toStringAsFixed(2)}';
        notifyListeners();
        return false;
      }
    }

    _isSaving = true;
    notifyListeners();

    try {
      final supplierName =
          _suppliers.firstWhere((s) => s['id'] == _selectedSupplierId)['name']
              as String;

      await _service.createPurchaseOrder(
        supplierId: _selectedSupplierId!,
        supplierName: supplierName,
        warehouseId: _selectedWarehouseId!,
        items: _items,
        totalAmount: totalAmount,
        paymentMode: _paymentMode,
        paymentStatus: _paymentStatus,
        accountId: _selectedAccountId,
        activeShiftId: _activeShiftId,
        dueDate: _dueDate,
        documentDate: _documentDate,
        documentType: _documentType,
        documentNumber: documentNumber.isEmpty ? null : documentNumber,
        notes: notes.isEmpty ? null : notes,
      );

      // Limpiar borrador al guardar
      clearDraft();
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving order: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al guardar la orden.';
      }
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // ── SHARED PREFERENCES DRAFT ──
  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();

    final itemsJson =
        _items.map((e) {
          return {
            'product_id': e.productId,
            'product_name': e.productName,
            'variant_id': e.variantId,
            'variant_label': e.variantLabel,
            'image_url': e.imageUrl,
            'uses_batches': e.usesBatches,
            'quantity': e.quantity,
            'unit_cost': e.unitCost,
            'batch_number': e.batchNumber,
            'expiry_date': e.expiryDate?.toIso8601String(),
          };
        }).toList();

    final data = {
      'items': itemsJson,
      'supplier_id': _selectedSupplierId,
      'warehouse_id': _selectedWarehouseId,
    };

    await prefs.setString(_draftKey, jsonEncode(data));
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_draftKey);
    if (str != null) {
      try {
        final data = jsonDecode(str) as Map<String, dynamic>;

        final itemsList = data['items'] as List;

        // Solo restaurar proveedor y almacén si había ítems en el borrador.
        // Esto evita que un draft "fantasma" (sin ítems) preseleccione el almacén.
        if (itemsList.isNotEmpty) {
          if (data['supplier_id'] != null &&
              _suppliers.any((s) => s['id'] == data['supplier_id'])) {
            _selectedSupplierId = data['supplier_id'];
          }
          if (data['warehouse_id'] != null &&
              _warehouses.any((w) => w.id == data['warehouse_id'])) {
            _selectedWarehouseId = data['warehouse_id'];
          }

          _items =
              itemsList.map((i) {
                final productId = i['product_id'] as String?;
                final variantId = i['variant_id'] as String?;
                return InventoryEntryItemEntity(
                  productId: productId ?? '',
                  productName: i['product_name'] as String? ?? '—',
                  variantId: variantId ?? '',
                  variantLabel: i['variant_label'] as String? ?? 'Variante Única',
                  imageUrl: i['image_url'] as String?,
                  usesBatches: i['uses_batches'] as bool? ?? false,
                  quantity: (i['quantity'] as num).toDouble(),
                  unitCost: (i['unit_cost'] as num).toDouble(),
                  batchNumber: i['batch_number'] as String? ?? 'DEFAULT',
                  expiryDate:
                      i['expiry_date'] != null
                          ? DateTime.tryParse(i['expiry_date'] as String)
                          : null,
                );
              }).toList();
        } else {
          // Borrador vacío — borrarlo para no interferir en futuras sesiones
          await prefs.remove(_draftKey);
        }
      } catch (e) {
        debugPrint('Error loading draft: $e');
      }
    }
  }
}
