import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/models/financial_account_model.dart';
import 'package:inventory_store_app/models/entry_item_ui.dart';
import 'package:inventory_store_app/services/admin/inventory_entries_service.dart';
import 'package:collection/collection.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';

class InventoryEntryFormProvider extends ChangeNotifier {
  final InventoryEntriesService _service = InventoryEntriesService();

  // ── CATÁLOGOS ──
  List<WarehouseModel> _warehouses = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<FinancialAccountModel> _accounts = [];

  List<WarehouseModel> get warehouses => _warehouses;
  List<Map<String, dynamic>> get suppliers => _suppliers;
  List<FinancialAccountModel> get accounts => _accounts;

  // ── ESTADO DEL FORMULARIO ──
  String? _selectedWarehouseId;
  String? _selectedSupplierId;
  
  String _documentType = 'NINGUNO';
  String? _documentNumber;
  DateTime? _documentDate;
  
  String _paymentMode = 'CONTADO';
  String? _selectedAccountId;
  
  String? _purchaseOrderId; // Para saber si viene de una orden
  String? _activeShiftId;

  String? get selectedWarehouseId => _selectedWarehouseId;
  String? get selectedSupplierId => _selectedSupplierId;
  String get documentType => _documentType;
  String? get documentNumber => _documentNumber;
  DateTime? get documentDate => _documentDate;
  String get paymentMode => _paymentMode;
  String? get selectedAccountId => _selectedAccountId;
  String? get purchaseOrderId => _purchaseOrderId;

  // ── ITEMS ──
  final List<EntryItemUI> _items = [];
  List<EntryItemUI> get items => _items;

  // ── ESTADOS DE CARGA Y ERRORES ──
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String get errorMessage => _errorMessage;

  // ── INIT ──
  Future<void> init({
    String? purchaseOrderId,
    List<EntryItemUI>? prefillItems,
    String? prefillSupplierId,
    String? prefillDocumentType,
    String? prefillDocumentNumber,
    DateTime? prefillDocumentDate,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    _purchaseOrderId = purchaseOrderId;
    if (prefillSupplierId != null) _selectedSupplierId = prefillSupplierId;
    if (prefillDocumentType != null) _documentType = prefillDocumentType;
    if (prefillDocumentNumber != null) _documentNumber = prefillDocumentNumber;
    if (prefillDocumentDate != null) _documentDate = prefillDocumentDate;

    try {
      final results = await Future.wait([
        _service.getActiveWarehouses(),
        _service.getActiveSuppliers(),
        _service.getActiveAccounts(),
      ]);

      _warehouses = (results[0] as List).map((w) => WarehouseModel(id: w['id'], name: w['name'])).toList();
      _suppliers = List<Map<String, dynamic>>.from(results[1]);
      _accounts = (results[2] as List).map((a) => FinancialAccountModel.fromJson(Map<String,dynamic>.from(a))).toList();

      if (_warehouses.length == 1) {
        _selectedWarehouseId = _warehouses.first.id;
      }

      if (prefillItems != null && prefillItems.isNotEmpty) {
        _items.clear();
        _items.addAll(prefillItems);
      } else {
        await _loadDraft();
      }
    } catch (e) {
      _errorMessage = 'Error cargando datos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── SETTERS ──
  void setWarehouse(String? id) {
    _selectedWarehouseId = id;
    notifyListeners();
  }

  void setSupplier(String? id) {
    _selectedSupplierId = id;
    notifyListeners();
  }

  void setDocumentType(String type) {
    _documentType = type;
    notifyListeners();
  }
  
  void setDocumentNumber(String? num) {
    _documentNumber = num;
  }

  void setDocumentDate(DateTime? date) {
    _documentDate = date;
    notifyListeners();
  }

  void setPaymentMode(String mode) {
    _paymentMode = mode;
    notifyListeners();
  }

  void setAccount(String? id) {
    _selectedAccountId = id;
    notifyListeners();
  }

  void setActiveShiftId(String? id) {
    _activeShiftId = id;
  }

  // ── MANEJO DE ITEMS ──
  void addItem(EntryItemUI item) {
    final existing = _items.firstWhereOrNull((i) => i.variant.id == item.variant.id && i.batchNumber == item.batchNumber);
    if (existing != null) {
      existing.quantity += item.quantity;
    } else {
      _items.add(item);
    }
    _saveDraft();
    notifyListeners();
  }

  void updateItemQuantity(int index, double newQty) {
    if (newQty <= 0) return;
    _items[index].quantity = newQty;
    _saveDraft();
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    _saveDraft();
    notifyListeners();
  }

  // ── VALIDACIÓN ──
  bool validate(String activeShiftId) {
    _errorMessage = '';
    if (_selectedWarehouseId == null) {
      _errorMessage = 'Seleccione el almacén de destino';
      return false;
    }

    if (_purchaseOrderId == null) {
      if (_paymentMode == 'CONTADO' && _selectedAccountId == null) {
        _errorMessage = 'Seleccione la cuenta financiera para pagar';
        return false;
      }
      if (_paymentMode == 'CONTADO' && _selectedAccountId != null) {
        final accountData = _accounts.firstWhereOrNull((a) => a.id == _selectedAccountId);
        if (accountData?.type.toUpperCase() == 'CAJA' && activeShiftId.isEmpty) {
          _errorMessage = 'La caja seleccionada no tiene un turno abierto.';
          return false;
        }
        final totalCost = _items.fold(0.0, (sum, item) => sum + item.subtotal);
        if (accountData != null && accountData.balance < totalCost) {
          _errorMessage = 'Saldo insuficiente en la cuenta (S/ ${accountData.balance.toStringAsFixed(2)} disponible)';
          return false;
        }
      }
      if (_paymentMode == 'CREDITO' && _selectedSupplierId == null) {
        _errorMessage = 'Seleccione un proveedor para compra a crédito';
        return false;
      }
    }

    for (final item in _items) {
      if (item.product.usesBatches && (item.batchNumber == 'DEFAULT' || item.batchNumber.trim().isEmpty)) {
        _errorMessage = 'El producto "${item.product.name}" requiere un lote válido.';
        return false;
      }
    }

    return true;
  }

  // ── GUARDAR (SAVE) ──
  Future<bool> saveEntry(String notes) async {
    _errorMessage = '';
    _isSaving = true;
    notifyListeners();

    try {
      await _service.createInventoryEntry(
        items: _items,
        warehouseId: _selectedWarehouseId!,
        supplierId: _selectedSupplierId,
        purchaseOrderId: _purchaseOrderId,
        paymentMode: _paymentMode,
        accountId: _selectedAccountId,
        activeShiftId: _activeShiftId,
        documentType: _documentType,
        documentNumber: _documentNumber,
        documentDate: _documentDate,
        notes: notes,
      );
      await clearDraft();
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error registrando entrada: $e';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // ── SHARED PREFERENCES DRAFT ──
  Future<void> _saveDraft() async {
    if (_purchaseOrderId != null) return; // No guardamos borrador si viene de una orden de compra prellenada
    
    final prefs = await SharedPreferences.getInstance();
    
    final itemsJson = _items.map((e) => {
      'product': e.product.toJson(),
      'variant': e.variant.toJson(),
      'quantity': e.quantity,
      'unit_cost': e.unitCost,
      'batch_number': e.batchNumber,
      'expiry_date': e.expiryDate?.toIso8601String(),
    }).toList();

    await prefs.setString('inventory_entry_draft_items', jsonEncode(itemsJson));
  }

  Future<void> _loadDraft() async {
    if (_purchaseOrderId != null) return;

    final prefs = await SharedPreferences.getInstance();
    final itemsString = prefs.getString('inventory_entry_draft_items');
    
    if (itemsString != null && itemsString.isNotEmpty) {
      try {
        final List<dynamic> itemsJson = jsonDecode(itemsString);
        _items.clear();
        for (final itemJson in itemsJson) {
          final p = ProductModel.fromJson(itemJson['product']);
          final vJson = itemJson['variant'];
          final v = ProductVariantModel.fromJson(vJson);

          _items.add(EntryItemUI(
            product: p,
            variant: v,
            quantity: (itemJson['quantity'] as num).toDouble(),
            unitCost: (itemJson['unit_cost'] as num).toDouble(),
            batchNumber: itemJson['batch_number'] ?? 'DEFAULT',
            expiryDate: itemJson['expiry_date'] != null ? DateTime.tryParse(itemJson['expiry_date']) : null,
          ));
        }
      } catch (e) {
        debugPrint('Error loading entry draft: $e');
      }
    }
  }

  Future<void> clearDraft() async {
    _items.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('inventory_entry_draft_items');
    notifyListeners();
  }
}
