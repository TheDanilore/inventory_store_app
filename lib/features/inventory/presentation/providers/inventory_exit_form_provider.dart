import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/inventory/data/repositories/inventory_exits_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExitItemUI {
  final ProductModel product;
  final ProductVariantModel variant;
  final Map<String, dynamic>? selectedBatch;
  double quantity;
  final double unitCost;

  ExitItemUI({
    required this.product,
    required this.variant,
    this.selectedBatch,
    required this.quantity,
    required this.unitCost,
  });

  double get totalCost => quantity * unitCost;
}

class InventoryExitFormProvider extends ChangeNotifier {
  final _service = InventoryExitsService();
  final _supabase = Supabase.instance.client;
  static const _draftKey = 'inventory_exit_draft';

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<WarehouseModel> _warehouses = [];
  List<WarehouseModel> get warehouses => _warehouses;

  List<ProductModel> _allProducts = [];
  List<ProductModel> get allProducts => _allProducts;

  final Map<String, List<ProductVariantModel>> _variantsByProduct = {};
  Map<String, List<ProductVariantModel>> get variantsByProduct =>
      _variantsByProduct;

  String? _selectedWarehouseId;
  String? get selectedWarehouseId => _selectedWarehouseId;

  String _selectedReason = 'AJUSTE';
  String get selectedReason => _selectedReason;

  final List<ExitItemUI> _items = [];
  List<ExitItemUI> get items => _items;

  double get totalLossCost =>
      _items.fold(0, (sum, item) => sum + item.totalCost);
  int get totalUnits =>
      _items.fold(0, (sum, item) => sum + item.quantity.toInt());

  Future<void> loadInitialData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final warehousesData = await _service.getActiveWarehouses();
      final productsData = await _service.getActiveProductsAndVariants();

      _warehouses =
          warehousesData
              .map((w) => WarehouseModel.fromJson(Map<String, dynamic>.from(w)))
              .toList();
      if (_warehouses.isNotEmpty) {
        _selectedWarehouseId = _warehouses.first.id;
      }

      _allProducts =
          (productsData['products'] as List)
              .map((p) => ProductModel.fromJson(p))
              .toList();

      final variants =
          (productsData['variants'] as List)
              .map(
                (v) =>
                    ProductVariantModel.fromJson(Map<String, dynamic>.from(v)),
              )
              .toList();

      _variantsByProduct.clear();
      for (final v in variants) {
        _variantsByProduct.putIfAbsent(v.productId, () => []).add(v);
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

  void selectWarehouse(String? id) {
    if (id != null && id != _selectedWarehouseId) {
      _selectedWarehouseId = id;
      _items.clear();
      _saveDraft();
      notifyListeners();
    }
  }

  void selectReason(String reason) {
    _selectedReason = reason;
    _saveDraft();
    notifyListeners();
  }

  void addItem(ExitItemUI newItem) {
    final existingIdx = _items.indexWhere(
      (item) =>
          item.product.id == newItem.product.id &&
          item.variant.id == newItem.variant.id &&
          item.selectedBatch?['id'] == newItem.selectedBatch?['id'],
    );
    if (existingIdx >= 0) {
      _items[existingIdx].quantity += newItem.quantity;
    } else {
      _items.add(newItem);
    }
    _saveDraft();
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    _saveDraft();
    notifyListeners();
  }

  void updateQuantity(int index, double newQuantity) {
    if (newQuantity > 0) {
      _items[index].quantity = newQuantity;
      _saveDraft();
      notifyListeners();
    }
  }

  Future<bool> saveExit(String? notes) async {
    if (_selectedWarehouseId == null || _items.isEmpty) return false;

    _isSaving = true;
    notifyListeners();

    try {
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

      final itemsData =
          _items.map((item) {
            return {
              'batch_id': item.selectedBatch!['id'],
              'batch_number': item.selectedBatch!['batch_number'] ?? 'DEFAULT',
              'quantity': item.quantity,
              'variant_id': item.variant.id,
              'product_id': item.product.id,
              'unit_cost': item.unitCost,
              'total_cost': item.totalCost,
              'product_name': item.product.name,
            };
          }).toList();

      await _service.saveExitTransaction(
        warehouseId: _selectedWarehouseId!,
        reason: _selectedReason,
        notes: notes?.isEmpty == true ? null : notes,
        createdByProfileId: createdByProfileId,
        items: itemsData,
      );

      await clearDraft();

      return true;
    } catch (e) {
      debugPrint('Error saving exit: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error registrando salida.';
      }
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void reset() {
    _items.clear();
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();

    final itemsJson =
        _items.map((e) {
          return {
            'product': e.product.toJson(),
            'variant': e.variant.toJson(),
            'selectedBatch': e.selectedBatch,
            'quantity': e.quantity,
            'unit_cost': e.unitCost,
          };
        }).toList();

    final draftData = {
      'warehouseId': _selectedWarehouseId,
      'reason': _selectedReason,
      'items': itemsJson,
    };

    await prefs.setString(_draftKey, jsonEncode(draftData));
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftString = prefs.getString(_draftKey);

    if (draftString != null && draftString.isNotEmpty) {
      try {
        final draftData = jsonDecode(draftString) as Map<String, dynamic>;

        if (draftData['warehouseId'] != null) {
          _selectedWarehouseId = draftData['warehouseId'] as String;
        }
        if (draftData['reason'] != null) {
          _selectedReason = draftData['reason'] as String;
        }

        final itemsJson = draftData['items'] as List<dynamic>? ?? [];
        _items.clear();

        for (final itemJson in itemsJson) {
          final p = ProductModel.fromJson(itemJson['product']);
          final vJson = itemJson['variant'];
          final v = ProductVariantModel.fromJson(vJson);

          _items.add(
            ExitItemUI(
              product: p,
              variant: v,
              selectedBatch: itemJson['selectedBatch'] as Map<String, dynamic>?,
              quantity: (itemJson['quantity'] as num).toDouble(),
              unitCost: (itemJson['unit_cost'] as num).toDouble(),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error loading exit draft: $e');
      }
    }
  }

  Future<void> clearDraft() async {
    _items.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }
}
