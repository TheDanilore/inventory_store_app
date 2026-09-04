import 'dart:convert';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_active_warehouses_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_active_suppliers_uc.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/create_inventory_entry_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_purchase_order_by_id_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_state.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_purchase_order_items_usecase.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'dart:developer' as developer;

@injectable
class InventoryEntryFormCubit extends Cubit<InventoryEntryFormState> {
  final GetActiveWarehousesUseCase getActiveWarehouses;
  final GetActiveSuppliersUseCase getActiveSuppliers;
  final GetFinancialAccountsUseCase getActiveAccounts;
  final CreateInventoryEntryUseCase createInventoryEntry;
  final GetPurchaseOrderByIdUseCase getPurchaseOrderById;

  static const _draftKey = 'inventory_entry_draft';
  Timer? _draftTimer;

  InventoryEntryFormCubit({
    required this.getActiveWarehouses,
    required this.getActiveSuppliers,
    required this.getActiveAccounts,
    required this.createInventoryEntry,
    required this.getPurchaseOrderById,
  }) : super(const InventoryEntryFormState());

  @override
  Future<void> close() {
    _draftTimer?.cancel();
    return super.close();
  }

  Future<void> init({
    String? purchaseOrderId,
    List<InventoryEntryItemEntity>? prefillItems,
    String? prefillSupplierId,
    String? prefillWarehouseId,
    String? prefillDocumentType,
    String? prefillDocumentNumber,
    DateTime? prefillDocumentDate,
  }) async {
    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: '',
        purchaseOrderId: purchaseOrderId,
        selectedSupplierId: prefillSupplierId,
        selectedWarehouseId: prefillWarehouseId,
        documentType: prefillDocumentType ?? 'NINGUNO',
        documentNumber: prefillDocumentNumber,
        documentDate: prefillDocumentDate,
      ),
    );

    try {
      final futures = await Future.wait([
        getActiveWarehouses.call(),
        getActiveSuppliers.call(),
        getActiveAccounts.call(page: 0, pageSize: 100),
        createInventoryEntry.repository.getOpenCashShifts(),
      ]);

      final warehouses = futures[0] as List<WarehouseEntity>;

      final suppliersResult =
          futures[1] as Either<Failure, List<SupplierEntity>>;
      final suppliers = suppliersResult.fold(
        (l) {
          developer.log(
            'suppliers error: ${l.message}',
            name: 'InventoryEntryFormCubit',
          );
          return <SupplierEntity>[];
        },
        (r) => r,
      );

      final rawAccounts = futures[2] as List<FinancialAccountEntity>;
      final accounts = rawAccounts.where((a) => a.isActive).toList();

      final activeShiftsByAccount = futures[3] as Map<String, String>;

      // ── auto-select warehouse if only one ────────────────────────────────
      String? initialWarehouseId =
          prefillWarehouseId ?? state.selectedWarehouseId;
      if (initialWarehouseId == null && warehouses.length == 1) {
        initialWarehouseId = warehouses.first.id;
      }

      // ── auto-select account for CONTADO if none selected ─────────────────
      String? initialAccountId = state.selectedAccountId;
      if (initialAccountId == null && accounts.isNotEmpty) {
        final cashAccount = accounts.firstWhere(
          (a) => a.type.toUpperCase() == 'CAJA',
          orElse: () => accounts.first,
        );
        initialAccountId = cashAccount.id;
      }

      final initialActiveShiftId =
          initialAccountId != null
              ? activeShiftsByAccount[initialAccountId]
              : null;

      emit(
        state.copyWith(
          warehouses: warehouses,
          suppliers: suppliers,
          accounts: accounts,
          activeShiftsByAccount: activeShiftsByAccount,
          selectedWarehouseId: initialWarehouseId,
          selectedAccountId: initialAccountId,
          activeShiftId: initialActiveShiftId,
        ),
      );

      // ── load PO or draft ─────────────────────────────────────────────────
      if (purchaseOrderId != null && purchaseOrderId.isNotEmpty) {
        await _loadFromPurchaseOrder(purchaseOrderId);
        if (prefillItems != null && prefillItems.isNotEmpty) {
          emit(state.copyWith(items: List.from(prefillItems)));
        }
      } else if (prefillItems != null && prefillItems.isNotEmpty) {
        emit(state.copyWith(items: List.from(prefillItems)));
      } else {
        await _loadDraft();
      }
    } catch (e, st) {
      developer.log(
        'init error',
        error: e,
        stackTrace: st,
        name: 'InventoryEntryFormCubit',
      );
      emit(state.copyWith(errorMessage: 'Error cargando datos: $e'));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  void setWarehouse(String? id) {
    emit(state.copyWith(selectedWarehouseId: id));
    _scheduleSaveDraft();
  }

  void setSupplier(String? id) {
    emit(
      state.copyWith(
        selectedSupplierId: id,
        clearSelectedSupplierId: id == null,
      ),
    );
    _scheduleSaveDraft();
  }

  void setDocumentType(String type) {
    emit(state.copyWith(documentType: type));
    _scheduleSaveDraft();
  }

  void setDocumentNumber(String? num) {
    emit(state.copyWith(documentNumber: num, clearDocumentNumber: num == null));
    _scheduleSaveDraft();
  }

  void setDocumentDate(DateTime? date) {
    emit(state.copyWith(documentDate: date, clearDocumentDate: date == null));
    _scheduleSaveDraft();
  }

  void setPaymentMode(String mode) {
    emit(state.copyWith(paymentMode: mode));
    _scheduleSaveDraft();
  }

  void setAccount(String? id) {
    final shiftId = id != null ? state.activeShiftsByAccount[id] : null;
    emit(
      state.copyWith(
        selectedAccountId: id,
        activeShiftId: shiftId,
        clearSelectedAccountId: id == null,
        clearActiveShiftId: shiftId == null,
      ),
    );
    _scheduleSaveDraft();
  }

  void setActiveShiftId(String? id) {
    emit(state.copyWith(activeShiftId: id));
  }

  Future<void> refreshCashShifts() async {
    try {
      final shifts = await createInventoryEntry.repository.getOpenCashShifts();
      final shiftId =
          state.selectedAccountId != null
              ? shifts[state.selectedAccountId]
              : null;
      emit(
        state.copyWith(
          activeShiftsByAccount: shifts,
          activeShiftId: shiftId,
          clearActiveShiftId: shiftId == null,
        ),
      );
    } catch (e, st) {
      developer.log(
        'refreshCashShifts error',
        error: e,
        stackTrace: st,
        name: 'InventoryEntryFormCubit',
      );
    }
  }

  void addItem(InventoryEntryItemEntity item) {
    final newItems = List<InventoryEntryItemEntity>.from(state.items);
    final existingIndex = newItems.indexWhere(
      (i) => i.variantId == item.variantId && i.batchNumber == item.batchNumber,
    );
    if (existingIndex != -1) {
      newItems[existingIndex] = newItems[existingIndex].copyWith(
        quantity: newItems[existingIndex].quantity + item.quantity,
      );
    } else {
      newItems.add(item);
    }
    emit(state.copyWith(items: newItems));
    _scheduleSaveDraft();
  }

  void updateItemQuantity(int index, double newQty) {
    if (newQty <= 0) return;
    final newItems = List<InventoryEntryItemEntity>.from(state.items);
    newItems[index] = newItems[index].copyWith(quantity: newQty);
    emit(state.copyWith(items: newItems));
    _scheduleSaveDraft();
  }

  void updateItemCost(int index, double newCost) {
    if (newCost < 0) return;
    final newItems = List<InventoryEntryItemEntity>.from(state.items);
    newItems[index] = newItems[index].copyWith(unitCost: newCost);
    emit(state.copyWith(items: newItems));
    _scheduleSaveDraft();
  }

  void removeItem(int index) {
    final newItems = List<InventoryEntryItemEntity>.from(state.items);
    newItems.removeAt(index);
    emit(state.copyWith(items: newItems));
    _scheduleSaveDraft();
  }

  bool validate(String activeShiftId) {
    emit(state.copyWith(errorMessage: ''));
    if (state.selectedWarehouseId == null) {
      emit(state.copyWith(errorMessage: 'Seleccione el almacén de destino'));
      return false;
    }

    if (state.purchaseOrderId == null) {
      if (state.paymentMode == 'CONTADO') {
        if (state.selectedAccountId == null) {
          emit(
            state.copyWith(
              errorMessage: 'Seleccione la cuenta financiera para pagar',
            ),
          );
          return false;
        }

        final selectedAcc = state.accounts.firstWhere(
          (a) => a.id == state.selectedAccountId,
          orElse: () => state.accounts.first,
        );

        // Validación de Turno de Caja Abierto
        if (selectedAcc.type.toUpperCase() == 'CAJA') {
          final hasOpenShift =
              state.activeShiftsByAccount.containsKey(selectedAcc.id);
          if (!hasOpenShift) {
            emit(
              state.copyWith(
                errorMessage:
                    'La caja seleccionada ("${selectedAcc.name}") no tiene un turno abierto. Debe abrir un turno de caja para realizar pagos al contado.',
              ),
            );
            return false;
          }
        }

        // Validación de Saldo Suficiente
        final totalAmount = state.items.fold<double>(
          0.0,
          (sum, item) => sum + (item.quantity * item.unitCost),
        );
        if (state.items.isNotEmpty && selectedAcc.balance < totalAmount) {
          emit(
            state.copyWith(
              errorMessage:
                  'Saldo insuficiente en "${selectedAcc.name}". Saldo disponible: S/ ${selectedAcc.balance.toStringAsFixed(2)} - Total requerido: S/ ${totalAmount.toStringAsFixed(2)}',
            ),
          );
          return false;
        }
      }

      if (state.paymentMode == 'CRÉDITO' && state.selectedSupplierId == null) {
        emit(
          state.copyWith(
            errorMessage: 'Seleccione un proveedor para compra a crédito',
          ),
        );
        return false;
      }
    }

    for (final item in state.items) {
      if (item.usesBatches &&
          (item.batchNumber == 'DEFAULT' || item.batchNumber.trim().isEmpty)) {
        emit(
          state.copyWith(
            errorMessage:
                'El producto "${item.productName}" requiere un lote válido.',
          ),
        );
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
    } catch (e, st) {
      developer.log(
        'saveEntry error',
        error: e,
        stackTrace: st,
        name: 'InventoryEntryFormCubit',
      );
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        emit(
          state.copyWith(
            errorMessage: 'Sin conexión a internet.',
            isSaving: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            errorMessage: e.toString().replaceAll('Exception: ', ''),
            isSaving: false,
          ),
        );
      }
    }
  }

  void _scheduleSaveDraft() {
    if (state.purchaseOrderId != null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), () {
      _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    if (state.purchaseOrderId != null) return;

    final prefs = await SharedPreferences.getInstance();

    final itemsJson =
        state.items.map((e) {
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

        final newItems = <InventoryEntryItemEntity>[];
        final itemsJson = draftData['items'] as List<dynamic>? ?? [];
        for (final itemJson in itemsJson) {
          newItems.add(
            InventoryEntryItemEntity(
              productId: itemJson['product_id'] as String? ?? '',
              productName: itemJson['product_name'] as String? ?? '—',
              variantId: itemJson['variant_id'] as String? ?? '',
              variantLabel:
                  itemJson['variant_label'] as String? ?? 'Variante Única',
              imageUrl: itemJson['image_url'] as String?,
              usesBatches: itemJson['uses_batches'] as bool? ?? false,
              quantity: (itemJson['quantity'] as num).toDouble(),
              unitCost: (itemJson['unit_cost'] as num).toDouble(),
              batchNumber: itemJson['batch_number'] as String? ?? 'DEFAULT',
              expiryDate:
                  itemJson['expiry_date'] != null
                      ? DateTime.tryParse(itemJson['expiry_date'] as String)
                      : null,
            ),
          );
        }

        emit(
          state.copyWith(
            selectedWarehouseId: draftData['warehouseId'],
            selectedSupplierId: draftData['supplierId'],
            documentType: draftData['documentType'] ?? 'NINGUNO',
            documentNumber: draftData['documentNumber'],
            documentDate:
                draftData['documentDate'] != null
                    ? DateTime.tryParse(draftData['documentDate'])
                    : null,
            paymentMode: draftData['paymentMode'] ?? 'CONTADO',
            selectedAccountId: draftData['accountId'],
            items: newItems,
          ),
        );
      } catch (e, st) {
        developer.log(
          'Error parsing draft JSON. Corrupted state found.',
          error: e,
          stackTrace: st,
          name: 'InventoryEntryFormCubit',
        );
        await clearDraft();
      }
    }
  }

  Future<void> clearDraft() async {
    _draftTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    emit(state.copyWith(items: []));
  }

  Future<void> _loadFromPurchaseOrder(String poId) async {
    try {
      final poRespEither = await getPurchaseOrderById.call(poId);
      final poResp = poRespEither.fold((l) => null, (r) => r);

      if (poResp == null) return;

      final fetchItemsUseCase = sl<FetchPurchaseOrderItemsUseCase>();
      final itemsResult = await fetchItemsUseCase.call(poId);

      final List<InventoryEntryItemEntity> loadedItems = [];
      itemsResult.fold(
        (failure) {
          developer.log(
            'fetchOrderItems failure: ${failure.message}',
            name: 'InventoryEntryFormCubit',
          );
        },
        (items) {
          developer.log(
            'fetchOrderItems returned ${items.length} items',
            name: 'InventoryEntryFormCubit',
          );
          for (final i in items) {
            final remaining = i.quantityOrdered - i.quantityReceived;
            final qtyToUse = remaining > 0 ? remaining : i.quantityOrdered;
            loadedItems.add(
              InventoryEntryItemEntity(
                productId: i.productId,
                productName: i.productName ?? '—',
                variantId: i.variantId,
                variantLabel: i.variantAttrs,
                imageUrl: i.imageUrl,
                usesBatches: i.usesBatches,
                quantity: qtyToUse,
                unitCost: i.unitCost,
                batchNumber: i.batchNumber,
                expiryDate: i.expiryDate,
              ),
            );
          }
        },
      );

      final supId = poResp['supplier_id'] as String?;
      final whId = poResp['warehouse_id'] as String?;
      final docType = poResp['document_type'] as String?;
      final docNum = poResp['document_number'] as String?;
      final docDate =
          poResp['created_at'] != null
              ? DateTime.tryParse(poResp['created_at'])
              : null;

      developer.log(
        'PO $poId -> supplier_id=$supId warehouse_id=$whId '
        '(almacenes activos: ${state.warehouses.map((w) => w.id).toList()})',
        name: 'InventoryEntryFormCubit',
      );

      String? selectedWh = whId ?? state.selectedWarehouseId;
      if (selectedWh == null && state.warehouses.isNotEmpty) {
        selectedWh = state.warehouses.first.id;
      }

      emit(
        state.copyWith(
          selectedSupplierId: supId ?? state.selectedSupplierId,
          selectedWarehouseId: selectedWh,
          documentType: docType ?? state.documentType,
          documentNumber: docNum ?? state.documentNumber,
          documentDate: docDate ?? state.documentDate,
          items: loadedItems.isNotEmpty ? loadedItems : state.items,
        ),
      );
    } catch (e, st) {
      developer.log(
        'Error loading purchase order',
        error: e,
        stackTrace: st,
        name: 'InventoryEntryFormCubit',
      );
    }
  }
}
