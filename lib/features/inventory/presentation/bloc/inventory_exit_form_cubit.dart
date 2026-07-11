import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_active_warehouses_exits_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_active_products_and_variants_uc.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/create_inventory_exit_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form_state.dart';

@injectable
class InventoryExitFormCubit extends Cubit<InventoryExitFormState> {
  final GetActiveWarehousesExitsUseCase getActiveWarehousesUseCase;
  final GetActiveProductsAndVariantsUseCase getActiveProductsAndVariantsUseCase;
  final CreateInventoryExitUseCase createInventoryExitUseCase;
  final _supabase = Supabase.instance.client;
  static const _draftKey = 'inventory_exit_draft';

  InventoryExitFormCubit({
    required this.getActiveWarehousesUseCase,
    required this.getActiveProductsAndVariantsUseCase,
    required this.createInventoryExitUseCase,
  }) : super(const InventoryExitFormState());

  Future<void> loadInitialData() async {
    emit(state.copyWith(isLoading: true, errorMessage: '', isSuccess: false));

    try {
      final warehousesData = await getActiveWarehousesUseCase.call();
      final productsData = await getActiveProductsAndVariantsUseCase.call();

      final warehouses = warehousesData
          .map((w) => WarehouseModel(id: w.id, name: w.name))
          .toList();
      String? initialWarehouseId = warehouses.isNotEmpty ? warehouses.first.id : null;

      final allProducts = (productsData['products'] as List)
          .map((p) => ProductModel.fromJson(p))
          .toList();

      final variants = (productsData['variants'] as List)
          .map((v) => ProductVariantModel.fromJson(Map<String, dynamic>.from(v)))
          .toList();

      final variantsByProduct = <String, List<ProductVariantModel>>{};
      for (final v in variants) {
        variantsByProduct.putIfAbsent(v.productId, () => []).add(v);
      }

      emit(state.copyWith(
        warehouses: warehouses,
        selectedWarehouseId: initialWarehouseId,
        allProducts: allProducts,
        variantsByProduct: variantsByProduct,
      ));

      await _loadDraft();
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      debugPrint('Error loading form data: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        emit(state.copyWith(errorMessage: 'Sin conexión a internet.', isLoading: false));
      } else {
        emit(state.copyWith(errorMessage: 'Error cargando datos.', isLoading: false));
      }
    }
  }

  void selectWarehouse(String? id) {
    if (id != null && id != state.selectedWarehouseId) {
      emit(state.copyWith(selectedWarehouseId: id, items: []));
      _saveDraft();
    }
  }

  void selectReason(String reason) {
    emit(state.copyWith(selectedReason: reason));
    _saveDraft();
  }

  void addItem(ExitItemUI newItem) {
    final newItems = List<ExitItemUI>.from(state.items);
    final existingIdx = newItems.indexWhere(
      (item) =>
          item.product.id == newItem.product.id &&
          item.variant.id == newItem.variant.id &&
          item.selectedBatch?['id'] == newItem.selectedBatch?['id'],
    );
    if (existingIdx >= 0) {
      newItems[existingIdx].quantity += newItem.quantity;
    } else {
      newItems.add(newItem);
    }
    emit(state.copyWith(items: newItems));
    _saveDraft();
  }

  void removeItem(int index) {
    final newItems = List<ExitItemUI>.from(state.items);
    newItems.removeAt(index);
    emit(state.copyWith(items: newItems));
    _saveDraft();
  }

  void updateQuantity(int index, double newQuantity) {
    if (newQuantity > 0) {
      final newItems = List<ExitItemUI>.from(state.items);
      newItems[index].quantity = newQuantity;
      emit(state.copyWith(items: newItems));
      _saveDraft();
    }
  }

  Future<void> saveExit(String? notes) async {
    if (state.selectedWarehouseId == null || state.items.isEmpty) return;

    emit(state.copyWith(isSaving: true, errorMessage: '', isSuccess: false));

    try {
      String? createdByProfileId;
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        final profile = await _supabase
            .from('profiles')
            .select('id')
            .eq('auth_user_id', currentUser.id)
            .maybeSingle();
        createdByProfileId = profile?['id'] as String?;
      }

      final itemsData = state.items.map((item) {
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

      await createInventoryExitUseCase.call(
        warehouseId: state.selectedWarehouseId!,
        reason: state.selectedReason,
        notes: notes?.isEmpty == true ? null : notes,
        createdByProfileId: createdByProfileId,
        items: itemsData,
      );

      await clearDraft();

      emit(state.copyWith(isSaving: false, isSuccess: true));
    } catch (e) {
      debugPrint('Error saving exit: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        emit(state.copyWith(errorMessage: 'Sin conexión a internet.', isSaving: false));
      } else {
        emit(state.copyWith(errorMessage: 'Error registrando salida: $e', isSaving: false));
      }
    }
  }

  Future<void> clearDraft() async {
    emit(state.copyWith(items: [], errorMessage: ''));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = state.items.map((e) => e.toJson()).toList();

    final draftData = {
      'warehouseId': state.selectedWarehouseId,
      'reason': state.selectedReason,
      'items': itemsJson,
    };

    await prefs.setString(_draftKey, jsonEncode(draftData));
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftStr = prefs.getString(_draftKey);
    if (draftStr != null) {
      try {
        final draftData = jsonDecode(draftStr) as Map<String, dynamic>;
        final itemsJson = draftData['items'] as List<dynamic>? ?? [];
        
        final draftItems = itemsJson
            .map((e) => ExitItemUI.fromJson(e as Map<String, dynamic>))
            .toList();

        final draftWarehouseId = draftData['warehouseId'] as String?;
        final draftReason = draftData['reason'] as String?;

        String? finalWarehouseId = state.selectedWarehouseId;
        if (draftWarehouseId != null &&
            state.warehouses.any((w) => w.id == draftWarehouseId)) {
          finalWarehouseId = draftWarehouseId;
        }

        emit(state.copyWith(
          selectedWarehouseId: finalWarehouseId,
          selectedReason: draftReason ?? state.selectedReason,
          items: draftItems,
        ));
      } catch (e) {
        debugPrint('Error loading draft: $e');
        await clearDraft();
      }
    }
  }
}
