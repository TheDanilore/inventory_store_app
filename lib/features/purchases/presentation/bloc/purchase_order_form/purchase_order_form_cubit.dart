import 'package:injectable/injectable.dart';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';

import 'package:inventory_store_app/features/purchases/domain/usecases/create_purchase_order_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_active_cash_shift_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_order_form/purchase_order_form_state.dart';

@injectable
class PurchaseOrderFormCubit extends Cubit<PurchaseOrderFormState> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CreatePurchaseOrderUseCase createPurchaseOrderUseCase;
  final GetActiveCashShiftUseCase getActiveCashShiftUseCase;

  static const _draftKey = 'po_form_draft_v1';

  PurchaseOrderFormCubit({
    required this.createPurchaseOrderUseCase,
    required this.getActiveCashShiftUseCase,
  }) : super(PurchaseOrderFormInitial()) {
    initForm();
  }

  Future<void> initForm() async {
    emit(const PurchaseOrderFormLoading());

    try {
      final pRes = await _supabase
          .from('suppliers')
          .select('id, name')
          .eq('is_active', true)
          .order('name');
      final wRes = await _supabase
          .from('warehouses')
          .select('id, name, is_active, location')
          .eq('is_active', true)
          .order('name');
      final aRes = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('name');

      final suppliers = List<Map<String, dynamic>>.from(pRes as List);
      final warehouses =
          (wRes as List).map((e) => WarehouseModel.fromJson(e)).toList();
      final accounts =
          (aRes as List).map((e) => FinancialAccountModel.fromJson(e)).toList();

      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString(_draftKey);

      bool isDraftRestored = false;
      List<InventoryEntryItemEntity> initialItems = [];
      String? initialSupplier;
      String? initialWarehouse;

      if (draftStr != null) {
        try {
          final data = jsonDecode(draftStr) as Map<String, dynamic>;
          initialSupplier = data['supplierId'] as String?;
          initialWarehouse = data['warehouseId'] as String?;
          if (data['items'] != null) {
            final rawItems = data['items'] as List;
            initialItems =
                rawItems
                    .map(
                      (e) => InventoryEntryItemEntity(
                        productId: e['productId'],
                        variantId: e['variantId'],
                        productName: e['productName'],
                        variantLabel: e['variantLabel'] ?? '',
                        batchNumber: e['batchNumber'],
                        usesBatches: e['usesBatches'] ?? false,
                        unitCost: (e['unitCost'] as num?)?.toDouble() ?? 0.0,
                        quantity: (e['quantity'] as num?)?.toDouble() ?? 0.0,
                      ),
                    )
                    .toList();
          }
          isDraftRestored = true;
        } catch (e) {
          await prefs.remove(_draftKey);
        }
      }

      emit(
        PurchaseOrderFormLoaded(
          suppliers: suppliers,
          warehouses: warehouses,
          accounts: accounts,
          items: initialItems,
          selectedSupplierId: initialSupplier,
          selectedWarehouseId: initialWarehouse,
          isDraftRestored: isDraftRestored,
        ),
      );
    } catch (e) {
      emit(
        PurchaseOrderFormLoaded(
          suppliers: const [],
          warehouses: const [],
          accounts: const [],
          errorMessage: 'Error al cargar catálogos. Verifique su conexión.',
        ),
      );
    }
  }

  Future<void> _saveDraft() async {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'supplierId': currentState.selectedSupplierId,
        'warehouseId': currentState.selectedWarehouseId,
        'items':
            currentState.items
                .map(
                  (i) => {
                    'productId': i.productId,
                    'variantId': i.variantId,
                    'productName': i.productName,
                    'variantLabel': i.variantLabel,
                    'batchNumber': i.batchNumber,
                    'usesBatches': i.usesBatches,
                    'unitCost': i.unitCost,
                    'quantity': i.quantity,
                  },
                )
                .toList(),
      };
      await prefs.setString(_draftKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  void updateField({
    String? supplierId,
    String? warehouseId,
    DateTime? dueDate,
    DateTime? documentDate,
    String? documentType,
    String? paymentMode,
    String? paymentStatus,
    String? accountId,
    String? documentNumber,
    String? notes,
  }) {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded) return;

    final newState = currentState.copyWith(
      selectedSupplierId: supplierId,
      selectedWarehouseId: warehouseId,
      dueDate: dueDate,
      documentDate: documentDate,
      documentType: documentType,
      paymentMode: paymentMode,
      paymentStatus: paymentStatus,
      selectedAccountId: accountId,
      documentNumber: documentNumber,
      notes: notes,
    );

    emit(newState);
    if (supplierId != null || warehouseId != null) {
      _saveDraft();
    }
  }

  void clearDueDate() {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded) return;
    emit(
      PurchaseOrderFormLoaded(
        suppliers: currentState.suppliers,
        warehouses: currentState.warehouses,
        accounts: currentState.accounts,
        items: currentState.items,
        selectedSupplierId: currentState.selectedSupplierId,
        selectedWarehouseId: currentState.selectedWarehouseId,
        dueDate: null, // Clear due date explicitly
        documentDate: currentState.documentDate,
        documentType: currentState.documentType,
        paymentMode: currentState.paymentMode,
        paymentStatus: currentState.paymentStatus,
        selectedAccountId: currentState.selectedAccountId,
        documentNumber: currentState.documentNumber,
        notes: currentState.notes,
      ),
    );
  }

  void clearDocumentDate() {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded) return;
    emit(
      PurchaseOrderFormLoaded(
        suppliers: currentState.suppliers,
        warehouses: currentState.warehouses,
        accounts: currentState.accounts,
        items: currentState.items,
        selectedSupplierId: currentState.selectedSupplierId,
        selectedWarehouseId: currentState.selectedWarehouseId,
        dueDate: currentState.dueDate,
        documentDate: null, // Clear document date explicitly
        documentType: currentState.documentType,
        paymentMode: currentState.paymentMode,
        paymentStatus: currentState.paymentStatus,
        selectedAccountId: currentState.selectedAccountId,
        documentNumber: currentState.documentNumber,
        notes: currentState.notes,
      ),
    );
  }

  void addItem(InventoryEntryItemEntity item) {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded) return;

    final existingIndex = currentState.items.indexWhere(
      (i) => i.productId == item.productId && i.variantId == item.variantId,
    );

    final newItems = List<InventoryEntryItemEntity>.from(currentState.items);

    if (existingIndex >= 0) {
      final ex = newItems[existingIndex];
      newItems[existingIndex] = ex.copyWith(
        quantity: ex.quantity + item.quantity,
        unitCost: item.unitCost,
      );
    } else {
      newItems.add(item);
    }

    emit(currentState.copyWith(items: newItems));
    _saveDraft();
  }

  void removeItem(String productId, String variantId) {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded) return;

    final newItems =
        currentState.items
            .where(
              (i) => !(i.productId == productId && i.variantId == variantId),
            )
            .toList();

    emit(currentState.copyWith(items: newItems));
    _saveDraft();
  }

  void updateItemQuantity(String productId, String variantId, double qty) {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded) return;

    final newItems =
        currentState.items.map((i) {
          if (i.productId == productId && i.variantId == variantId) {
            return i.copyWith(quantity: qty);
          }
          return i;
        }).toList();

    emit(currentState.copyWith(items: newItems));
    _saveDraft();
  }

  void updateItemCost(String productId, String variantId, double cost) {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded) return;

    final newItems =
        currentState.items.map((i) {
          if (i.productId == productId && i.variantId == variantId) {
            return i.copyWith(unitCost: cost);
          }
          return i;
        }).toList();

    emit(currentState.copyWith(items: newItems));
    _saveDraft();
  }

  Future<void> submitOrder() async {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded || !currentState.isValid) {
      return;
    }

    emit(
      currentState.copyWith(isSaving: true, errorMessage: null),
    ); // Assume null clears. Actually wait, I didn't wrap errorMessage.
    // I should use clearError() then copyWith.
    final loadingState = currentState.clearError().copyWith(isSaving: true);
    emit(loadingState);

    try {
      final supplier = loadingState.suppliers.firstWhere(
        (s) => s['id'] == loadingState.selectedSupplierId,
      );

      String? activeShiftId;
      if (loadingState.paymentStatus == 'PAID' &&
          loadingState.selectedAccountId != null) {
        final shiftRes = await getActiveCashShiftUseCase(
          loadingState.selectedAccountId!,
        );
        shiftRes.fold(
          (failure) => null,
          (data) => activeShiftId = data?['id'] as String?,
        );
      }

      final result = await createPurchaseOrderUseCase(
        supplierId: loadingState.selectedSupplierId!,
        supplierName: supplier['name'] as String,
        warehouseId: loadingState.selectedWarehouseId!,
        items: loadingState.items,
        totalAmount: loadingState.totalAmount,
        paymentMode: loadingState.paymentMode,
        paymentStatus: loadingState.paymentStatus,
        accountId: loadingState.selectedAccountId,
        activeShiftId: activeShiftId,
        dueDate: loadingState.dueDate,
        documentDate: loadingState.documentDate,
        documentType: loadingState.documentType,
        documentNumber: loadingState.documentNumber,
        notes: loadingState.notes,
      );

      await result.fold(
        (failure) async {
          emit(
            loadingState.copyWith(
              isSaving: false,
              errorMessage: 'Error al guardar la orden: ${failure.message}',
            ),
          );
        },
        (_) async {
          await clearDraft();
          emit(PurchaseOrderFormSuccess());
        },
      );
    } catch (e) {
      emit(
        loadingState.copyWith(
          isSaving: false,
          errorMessage: 'Error inesperado: $e',
        ),
      );
    }
  }

  void clearError() {
    final currentState = state;
    if (currentState is PurchaseOrderFormLoaded) {
      emit(currentState.clearError());
    }
  }
}
