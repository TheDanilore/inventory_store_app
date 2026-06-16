import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/services/admin/inventory_exits_service.dart';
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
    } catch (e) {
      _errorMessage = 'Error cargando datos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectWarehouse(String? id) {
    if (id != null && id != _selectedWarehouseId) {
      _selectedWarehouseId = id;
      _items.clear();
      notifyListeners();
    }
  }

  void selectReason(String reason) {
    _selectedReason = reason;
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
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void updateQuantity(int index, double newQuantity) {
    if (newQuantity > 0) {
      _items[index].quantity = newQuantity;
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

      return true;
    } catch (e) {
      _errorMessage = 'Error registrando salida: $e';
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
}
