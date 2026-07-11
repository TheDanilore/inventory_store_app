import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/entry_item_ui.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_active_warehouses_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_active_suppliers_uc.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/create_inventory_entry_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form_state.dart';

@injectable
class InventoryEntryFormCubit extends Cubit<InventoryEntryFormState> {
  final GetActiveWarehousesUseCase getActiveWarehouses;
  final GetActiveSuppliersUseCase getActiveSuppliers;
  final GetFinancialAccountsUseCase getActiveAccounts;
  final CreateInventoryEntryUseCase createInventoryEntry;

  static const _draftKey = 'inventory_entry_draft';

  InventoryEntryFormCubit({
    required this.getActiveWarehouses,
    required this.getActiveSuppliers,
    required this.getActiveAccounts,
    required this.createInventoryEntry,
  }) : super(const InventoryEntryFormState());

  Future<void> init({
    String? purchaseOrderId,
    List<EntryItemUI>? prefillItems,
    String? prefillSupplierId,
    String? prefillDocumentType,
    String? prefillDocumentNumber,
    DateTime? prefillDocumentDate,
  }) async {
    emit(state.copyWith(
      isLoading: true,
      errorMessage: '',
      purchaseOrderId: purchaseOrderId,
      selectedSupplierId: prefillSupplierId,
      documentType: prefillDocumentType ?? 'NINGUNO',
      documentNumber: prefillDocumentNumber,
      documentDate: prefillDocumentDate,
    ));

    try {
      final results = await Future.wait([
        getActiveWarehouses.call(),
        getActiveSuppliers.call(),
        getActiveAccounts.call(page: 1, pageSize: 100),
      ]);

      final warehousesList = results[0] as List;
      final warehouses = warehousesList.map((w) => WarehouseModel(id: w.id, name: w.name)).toList();
      final suppliers = List<Map<String, dynamic>>.from(results[1] as List);
      final accountEntities = results[2] as List;
      final accounts = accountEntities
          .map((a) => FinancialAccountModel(
                id: a.id,
                name: a.name,
                type: a.type,
                balance: a.balance,
                isActive: a.isActive,
                createdAt: a.createdAt,
              ))
          .toList();

      String? initialWarehouseId;
      if (warehouses.length == 1) {
        initialWarehouseId = warehouses.first.id;
      }

      emit(state.copyWith(
        warehouses: warehouses,
        suppliers: suppliers,
        accounts: accounts,
        selectedWarehouseId: initialWarehouseId,
      ));

      if (prefillItems != null && prefillItems.isNotEmpty) {
        emit(state.copyWith(items: List.from(prefillItems)));
      } else {
        await _loadDraft();
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        emit(state.copyWith(errorMessage: 'Sin conexión a internet.'));
      } else {
        emit(state.copyWith(errorMessage: 'Error cargando datos.'));
      }
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  void setWarehouse(String? id) {
    emit(state.copyWith(selectedWarehouseId: id));
    _saveDraft();
  }

  void setSupplier(String? id) {
    emit(state.copyWith(selectedSupplierId: id, clearSelectedSupplierId: id == null));
    _saveDraft();
  }

  void setDocumentType(String type) {
    emit(state.copyWith(documentType: type));
    _saveDraft();
  }

  void setDocumentNumber(String? num) {
    emit(state.copyWith(documentNumber: num, clearDocumentNumber: num == null));
    _saveDraft();
  }

  void setDocumentDate(DateTime? date) {
    emit(state.copyWith(documentDate: date, clearDocumentDate: date == null));
    _saveDraft();
  }

  void setPaymentMode(String mode) {
    emit(state.copyWith(paymentMode: mode));
    _saveDraft();
  }

  void setAccount(String? id) {
    emit(state.copyWith(selectedAccountId: id, clearSelectedAccountId: id == null));
    _saveDraft();
  }

  void setActiveShiftId(String? id) {
    emit(state.copyWith(activeShiftId: id));
  }

  void addItem(EntryItemUI item) {
    final newItems = List<EntryItemUI>.from(state.items);
    final existingIndex = newItems.indexWhere(
      (i) => i.variant.id == item.variant.id && i.batchNumber == item.batchNumber,
    );
    if (existingIndex != -1) {
      newItems[existingIndex].quantity += item.quantity;
    } else {
      newItems.add(item);
    }
    emit(state.copyWith(items: newItems));
    _saveDraft();
  }

  void updateItemQuantity(int index, double newQty) {
    if (newQty <= 0) return;
    final newItems = List<EntryItemUI>.from(state.items);
    newItems[index].quantity = newQty;
    emit(state.copyWith(items: newItems));
    _saveDraft();
  }

  void removeItem(int index) {
    final newItems = List<EntryItemUI>.from(state.items);
    newItems.removeAt(index);
    emit(state.copyWith(items: newItems));
    _saveDraft();
  }

  bool validate(String activeShiftId) {
    emit(state.copyWith(errorMessage: ''));
    if (state.selectedWarehouseId == null) {
      emit(state.copyWith(errorMessage: 'Seleccione el almacén de destino'));
      return false;
    }

    if (state.purchaseOrderId == null) {
      if (state.paymentMode == 'CONTADO' && state.selectedAccountId == null) {
        emit(state.copyWith(errorMessage: 'Seleccione la cuenta financiera para pagar'));
        return false;
      }
      if (state.paymentMode == 'CONTADO' && state.selectedAccountId != null) {
        final accountData = state.accounts.firstWhereOrNull(
          (a) => a.id == state.selectedAccountId,
        );
        if (accountData?.type.toUpperCase() == 'CAJA' && activeShiftId.isEmpty) {
          emit(state.copyWith(errorMessage: 'La caja seleccionada no tiene un turno abierto.'));
          return false;
        }
        final totalCost = state.items.fold(0.0, (sum, item) => sum + item.subtotal);
        if (accountData != null && accountData.balance < totalCost) {
          emit(state.copyWith(
            errorMessage: 'Saldo insuficiente en la cuenta (S/ ${accountData.balance.toStringAsFixed(2)} disponible)',
          ));
          return false;
        }
      }
      if (state.paymentMode == 'CREDITO' && state.selectedSupplierId == null) {
        emit(state.copyWith(errorMessage: 'Seleccione un proveedor para compra a crédito'));
        return false;
      }
    }

    for (final item in state.items) {
      if (item.product.usesBatches &&
          (item.batchNumber == 'DEFAULT' || item.batchNumber.trim().isEmpty)) {
        emit(state.copyWith(errorMessage: 'El producto "${item.product.name}" requiere un lote válido.'));
        return false;
      }
    }

    return true;
  }

  Future<void> saveEntry(String notes) async {
    emit(state.copyWith(errorMessage: '', isSaving: true));

    try {
      await createInventoryEntry.call(
        items: state.items,
        warehouseId: state.selectedWarehouseId!,
        supplierId: state.selectedSupplierId,
        purchaseOrderId: state.purchaseOrderId,
        paymentMode: state.paymentMode,
        accountId: state.selectedAccountId,
        activeShiftId: state.activeShiftId,
        documentType: state.documentType,
        documentNumber: state.documentNumber,
        documentDate: state.documentDate,
        notes: notes,
      );
      await clearDraft();
      emit(state.copyWith(isSaving: false, isSuccess: true));
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        emit(state.copyWith(errorMessage: 'Sin conexión a internet.', isSaving: false));
      } else {
        emit(state.copyWith(errorMessage: 'Error registrando entrada.', isSaving: false));
      }
    }
  }

  Future<void> _saveDraft() async {
    if (state.purchaseOrderId != null) return;

    final prefs = await SharedPreferences.getInstance();

    final itemsJson = state.items.map((e) {
      return {
        'product': e.product.toJson(),
        'variant': e.variant.toJson(),
        'quantity': e.quantity,
        'unit_cost': e.unitCost,
        'batch_number': e.batchNumber,
        'expiry_date': e.expiryDate?.toIso8601String(),
      };
    }).toList();

    final draftData = {
      'warehouseId': state.selectedWarehouseId,
      'supplierId': state.selectedSupplierId,
      'documentType': state.documentType,
      'documentNumber': state.documentNumber,
      'documentDate': state.documentDate?.toIso8601String(),
      'paymentMode': state.paymentMode,
      'accountId': state.selectedAccountId,
      'items': itemsJson,
    };

    await prefs.setString(_draftKey, jsonEncode(draftData));
  }

  Future<void> _loadDraft() async {
    if (state.purchaseOrderId != null) return;

    final prefs = await SharedPreferences.getInstance();
    final draftString = prefs.getString(_draftKey);

    if (draftString != null && draftString.isNotEmpty) {
      try {
        final draftData = jsonDecode(draftString) as Map<String, dynamic>;

        final newItems = <EntryItemUI>[];
        final itemsJson = draftData['items'] as List<dynamic>? ?? [];
        for (final itemJson in itemsJson) {
          final p = ProductModel.fromJson(itemJson['product']);
          final v = ProductVariantModel.fromJson(itemJson['variant']);

          newItems.add(
            EntryItemUI(
              product: p,
              variant: v,
              quantity: (itemJson['quantity'] as num).toDouble(),
              unitCost: (itemJson['unit_cost'] as num).toDouble(),
              batchNumber: itemJson['batch_number'] ?? 'DEFAULT',
              expiryDate: itemJson['expiry_date'] != null
                  ? DateTime.tryParse(itemJson['expiry_date'])
                  : null,
            ),
          );
        }

        emit(state.copyWith(
          selectedWarehouseId: draftData['warehouseId'],
          selectedSupplierId: draftData['supplierId'],
          documentType: draftData['documentType'] ?? 'NINGUNO',
          documentNumber: draftData['documentNumber'],
          documentDate: draftData['documentDate'] != null ? DateTime.tryParse(draftData['documentDate']) : null,
          paymentMode: draftData['paymentMode'] ?? 'CONTADO',
          selectedAccountId: draftData['accountId'],
          items: newItems,
        ));
      } catch (e) {
        // Fallback
      }
    }
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    emit(state.copyWith(items: []));
  }
}
