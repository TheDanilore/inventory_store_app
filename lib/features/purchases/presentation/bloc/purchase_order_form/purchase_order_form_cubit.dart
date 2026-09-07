import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/create_purchase_order_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/update_purchase_order_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_purchase_order_by_id_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_purchase_order_items_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_active_cash_shift_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_purchase_order_form_catalogs_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_supplier_credit_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_order_form/purchase_order_form_state.dart';

@injectable
class PurchaseOrderFormCubit extends Cubit<PurchaseOrderFormState> {
  final CreatePurchaseOrderUseCase createPurchaseOrderUseCase;
  final UpdatePurchaseOrderUseCase updatePurchaseOrderUseCase;
  final GetPurchaseOrderByIdUseCase getPurchaseOrderByIdUseCase;
  final FetchPurchaseOrderItemsUseCase fetchPurchaseOrderItemsUseCase;
  final GetActiveCashShiftUseCase getActiveCashShiftUseCase;
  final GetPurchaseOrderFormCatalogsUseCase getPurchaseOrderFormCatalogsUseCase;
  final GetSupplierCreditUseCase getSupplierCreditUseCase;

  static const _draftKey = 'po_form_draft_v1';
  Timer? _draftTimer;

  PurchaseOrderFormCubit({
    required this.createPurchaseOrderUseCase,
    required this.updatePurchaseOrderUseCase,
    required this.getPurchaseOrderByIdUseCase,
    required this.fetchPurchaseOrderItemsUseCase,
    required this.getActiveCashShiftUseCase,
    required this.getPurchaseOrderFormCatalogsUseCase,
    required this.getSupplierCreditUseCase,
  }) : super(PurchaseOrderFormInitial());

  Future<void> initForm({bool forceReload = false, String? editOrderId}) async {
    if (editOrderId == null && !forceReload && state is PurchaseOrderFormLoaded) {
      final loaded = state as PurchaseOrderFormLoaded;
      if (loaded.suppliers.isNotEmpty || loaded.warehouses.isNotEmpty) {
        return; // Evitar recargas redundantes si el estado ya está cargado
      }
    }

    emit(const PurchaseOrderFormLoading());

    try {
      final catalogsResult = await getPurchaseOrderFormCatalogsUseCase();

      await catalogsResult.fold(
        (failure) async {
          developer.log(
            'Error al cargar catálogos en initForm: ${failure.message}',
            name: 'PurchaseOrderFormCubit',
          );
          emit(
            PurchaseOrderFormLoaded(
              suppliers: const [],
              warehouses: const [],
              accounts: const [],
              errorMessage: failure.message,
            ),
          );
        },
        (data) async {
          final suppliers =
              data['suppliers'] as List<Map<String, dynamic>>? ?? [];
          final warehouses = data['warehouses'] as List<WarehouseModel>? ?? [];
          final accounts =
              data['accounts'] as List<FinancialAccountModel>? ?? [];
          final activeShiftsByAccount =
              data['activeShiftsByAccount'] as Map<String, String>? ?? {};

          if (editOrderId != null) {
            // Modo edición: Cargar la orden y sus ítems
            final orderRes = await getPurchaseOrderByIdUseCase(editOrderId);
            Map<String, dynamic>? orderData;
            String? orderError;
            orderRes.fold(
              (f) => orderError = f.message,
              (d) => orderData = d,
            );

            if (orderError != null || orderData == null) {
              emit(
                PurchaseOrderFormLoaded(
                  suppliers: suppliers,
                  warehouses: warehouses,
                  accounts: accounts,
                  errorMessage:
                      orderError ?? 'No se encontró la orden de compra a editar.',
                ),
              );
              return;
            }

            final status = orderData!['status']?.toString().toUpperCase();
            final amountPaid =
                (orderData!['amount_paid'] as num?)?.toDouble() ?? 0.0;
            if (status != 'PENDING' || amountPaid > 0) {
              emit(
                PurchaseOrderFormLoaded(
                  suppliers: suppliers,
                  warehouses: warehouses,
                  accounts: accounts,
                  errorMessage:
                      'Solo se pueden editar órdenes en estado PENDIENTE y sin pagos registrados.',
                ),
              );
              return;
            }

            final itemsRes = await fetchPurchaseOrderItemsUseCase(editOrderId);
            List<PurchaseOrderItemEntity> fetchedItems = [];
            String? itemsError;
            itemsRes.fold(
              (f) => itemsError = f.message,
              (its) => fetchedItems = its,
            );

            if (itemsError != null) {
              emit(
                PurchaseOrderFormLoaded(
                  suppliers: suppliers,
                  warehouses: warehouses,
                  accounts: accounts,
                  errorMessage: itemsError,
                ),
              );
              return;
            }

            final hasReceived = fetchedItems.any((i) => i.quantityReceived > 0);
            if (hasReceived) {
              emit(
                PurchaseOrderFormLoaded(
                  suppliers: suppliers,
                  warehouses: warehouses,
                  accounts: accounts,
                  errorMessage:
                      'No se puede editar una orden que ya tiene mercadería recibida.',
                ),
              );
              return;
            }

            final convertedItems =
                fetchedItems.map((e) {
                  return InventoryEntryItemEntity(
                    productId: e.productId,
                    variantId: e.variantId,
                    productName: e.productName ?? 'Producto',
                    variantLabel: e.variantAttrs,
                    imageUrl: e.imageUrl,
                    batchNumber: e.batchNumber,
                    usesBatches: e.usesBatches,
                    expiryDate: e.expiryDate,
                    unitCost: e.unitCost,
                    quantity: e.quantityOrdered,
                  );
                }).toList();

            final supplierId = orderData!['supplier_id'] as String?;
            final warehouseId = orderData!['warehouse_id'] as String?;
            final paymentMethod =
                orderData!['payment_method'] as String? ?? 'EFECTIVO';
            final paymentStatus =
                orderData!['payment_status'] as String? ?? 'PENDING';
            final docType =
                orderData!['document_type'] as String? ?? 'NINGUNO';
            final docNumber = orderData!['document_number'] as String? ?? '';
            final notes = orderData!['notes'] as String? ?? '';
            final dueDate =
                orderData!['due_date'] != null
                    ? DateTime.tryParse(orderData!['due_date'] as String)
                    : null;
            final docDate =
                orderData!['document_date'] != null
                    ? DateTime.tryParse(orderData!['document_date'] as String)
                    : null;

            emit(
              PurchaseOrderFormLoaded(
                suppliers: suppliers,
                warehouses: warehouses,
                accounts: accounts,
                activeShiftsByAccount: activeShiftsByAccount,
                items: convertedItems,
                selectedSupplierId: supplierId,
                selectedWarehouseId: warehouseId,
                paymentMode: paymentMethod,
                paymentStatus: paymentStatus,
                documentType: docType,
                documentNumber: docNumber,
                notes: notes,
                dueDate: dueDate,
                documentDate: docDate,
                editOrderId: editOrderId,
                isDraftRestored: false,
              ),
            );

            if (supplierId != null) {
              _fetchSupplierCreditIfNeeded(supplierId);
            }
            return;
          }

          // Modo creación normal (con restauración de borrador)
          bool isDraftRestored = false;
          List<InventoryEntryItemEntity> initialItems = [];
          String? initialSupplier;
          String? initialWarehouse;

          try {
            final prefs = await SharedPreferences.getInstance();
            final draftStr = prefs.getString(_draftKey);

            if (draftStr != null) {
              final draftData = jsonDecode(draftStr) as Map<String, dynamic>;
              initialSupplier = draftData['supplierId'] as String?;
              initialWarehouse = draftData['warehouseId'] as String?;
              if (draftData['items'] != null) {
                final rawItems = draftData['items'] as List;
                initialItems =
                    rawItems.map((e) {
                      return InventoryEntryItemEntity(
                        productId: e['productId'],
                        variantId: e['variantId'],
                        productName: e['productName'],
                        variantLabel: e['variantLabel'] ?? '',
                        imageUrl: e['imageUrl'] ?? e['image_url'],
                        batchNumber: e['batchNumber'],
                        usesBatches: e['usesBatches'] ?? false,
                        expiryDate:
                            e['expiryDate'] != null
                                ? DateTime.tryParse(e['expiryDate'])
                                : null,
                        unitCost: (e['unitCost'] as num?)?.toDouble() ?? 0.0,
                        quantity: (e['quantity'] as num?)?.toDouble() ?? 0.0,
                      );
                    }).toList();
                isDraftRestored =
                    initialItems.isNotEmpty ||
                    initialSupplier != null ||
                    initialWarehouse != null;
              }
            }
          } catch (e, st) {
            developer.log(
              'Error restaurando borrador en SharedPreferences',
              error: e,
              stackTrace: st,
              name: 'PurchaseOrderFormCubit',
            );
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_draftKey);
            } catch (removeError, removeSt) {
              developer.log(
                'Error al limpiar borrador corrupto en SharedPreferences',
                error: removeError,
                stackTrace: removeSt,
                name: 'PurchaseOrderFormCubit',
              );
            }
          }

          final Map<String, Map<String, dynamic>> supplierCreditsBySupplierId =
              {};

          emit(
            PurchaseOrderFormLoaded(
              suppliers: suppliers,
              warehouses: warehouses,
              accounts: accounts,
              activeShiftsByAccount: activeShiftsByAccount,
              supplierCreditsBySupplierId: supplierCreditsBySupplierId,
              items: initialItems,
              selectedSupplierId: initialSupplier,
              selectedWarehouseId: initialWarehouse,
              isDraftRestored: isDraftRestored,
            ),
          );

          // Cargar crédito del proveedor inicial restaurado bajo demanda (Lazy Loading)
          if (initialSupplier != null) {
            _fetchSupplierCreditIfNeeded(initialSupplier);
          }
        },
      );
    } catch (e, st) {
      developer.log(
        'Error inesperado en initForm',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrderFormCubit',
      );
      emit(
        PurchaseOrderFormLoaded(
          suppliers: const [],
          warehouses: const [],
          accounts: const [],
          errorMessage: 'Error inesperado al cargar catálogos: $e',
        ),
      );
    }
  }

  Future<void> _fetchSupplierCreditIfNeeded(String supplierId) async {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded) return;
    if (currentState.supplierCreditsBySupplierId.containsKey(supplierId)) {
      return; // Crédito ya cargado en caché para este proveedor
    }

    try {
      final res = await getSupplierCreditUseCase(supplierId);
      res.fold(
        (failure) {
          developer.log(
            'Error cargando crédito de proveedor $supplierId: ${failure.message}',
            name: 'PurchaseOrderFormCubit',
          );
        },
        (creditData) {
          final updatedState = state;
          if (updatedState is PurchaseOrderFormLoaded) {
            final newCreditsMap = Map<String, Map<String, dynamic>>.from(
              updatedState.supplierCreditsBySupplierId,
            );
            if (creditData != null) {
              newCreditsMap[supplierId] = creditData;
            } else {
              newCreditsMap[supplierId] =
                  {}; // Caché vacío si no tiene crédito configurado
            }
            emit(
              updatedState.copyWith(supplierCreditsBySupplierId: newCreditsMap),
            );
          }
        },
      );
    } catch (e, st) {
      developer.log(
        'Error inesperado al consultar crédito en _fetchSupplierCreditIfNeeded',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrderFormCubit',
      );
    }
  }

  void _scheduleDraftSave() {
    final currentState = state;
    if (currentState is PurchaseOrderFormLoaded && currentState.isEditing) {
      return; // No sobreescribir ni guardar borradores al editar una orden existente
    }
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), () {
      _saveDraft();
    });
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
                    'imageUrl': i.imageUrl,
                    'batchNumber': i.batchNumber,
                    'usesBatches': i.usesBatches,
                    'expiryDate': i.expiryDate?.toIso8601String(),
                    'unitCost': i.unitCost,
                    'quantity': i.quantity,
                  },
                )
                .toList(),
      };
      await prefs.setString(_draftKey, jsonEncode(data));
    } catch (e, st) {
      developer.log(
        'Error al guardar borrador en SharedPreferences',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrderFormCubit',
      );
    }
  }

  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e, st) {
      developer.log(
        'Error al limpiar borrador en SharedPreferences',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrderFormCubit',
      );
    }
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

    if (supplierId != null && newState.selectedSupplierId != null) {
      _fetchSupplierCreditIfNeeded(newState.selectedSupplierId!);
    } else if ((paymentMode == 'CRÉDITO' || paymentStatus == 'PENDING') &&
        newState.selectedSupplierId != null) {
      _fetchSupplierCreditIfNeeded(newState.selectedSupplierId!);
    }

    if (supplierId != null || warehouseId != null) {
      _scheduleDraftSave();
    }
  }

  void clearDueDate() {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded) return;
    emit(currentState.clearDueDate());
    _scheduleDraftSave();
  }

  void clearDocumentDate() {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded) return;
    emit(currentState.clearDocumentDate());
    _scheduleDraftSave();
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
    _scheduleDraftSave();
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
    _scheduleDraftSave();
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
    _scheduleDraftSave();
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
    _scheduleDraftSave();
  }

  Future<void> submitOrder() async {
    final currentState = state;
    if (currentState is! PurchaseOrderFormLoaded ||
        !currentState.isValid ||
        currentState.isSaving) {
      return;
    }

    final loadingState = currentState.clearError().copyWith(isSaving: true);
    emit(loadingState);

    try {
      final supplier = loadingState.suppliers.firstWhere(
        (s) => s['id'] == loadingState.selectedSupplierId,
      );

      if (loadingState.isEditing) {
        final updateResult = await updatePurchaseOrderUseCase(
          orderId: loadingState.editOrderId!,
          supplierId: loadingState.selectedSupplierId!,
          supplierName: supplier['name'] as String,
          warehouseId: loadingState.selectedWarehouseId!,
          items: loadingState.items,
          totalAmount: loadingState.totalAmount,
          paymentMode: loadingState.paymentMode,
          paymentStatus: loadingState.paymentStatus,
          dueDate: loadingState.dueDate,
          documentDate: loadingState.documentDate,
          documentType: loadingState.documentType,
          documentNumber: loadingState.documentNumber.trim(),
          notes: loadingState.notes.trim(),
        );

        await updateResult.fold(
          (failure) async {
            developer.log(
              'Error al actualizar orden en submitOrder: ${failure.message}',
              name: 'PurchaseOrderFormCubit',
            );
            emit(
              loadingState.copyWith(
                isSaving: false,
                errorMessage: 'Error al actualizar la orden: ${failure.message}',
              ),
            );
          },
          (_) async {
            emit(PurchaseOrderFormSuccess());
          },
        );
        return;
      }

      String? activeShiftId;
      if (loadingState.paymentStatus == 'PAID' &&
          loadingState.selectedAccountId != null) {
        activeShiftId =
            loadingState.activeShiftsByAccount[loadingState.selectedAccountId];
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
        documentNumber: loadingState.documentNumber.trim(),
        notes: loadingState.notes.trim(),
      );

      await result.fold(
        (failure) async {
          developer.log(
            'Error al crear orden en submitOrder: ${failure.message}',
            name: 'PurchaseOrderFormCubit',
          );
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
    } catch (e, st) {
      developer.log(
        'Error inesperado al ejecutar submitOrder',
        error: e,
        stackTrace: st,
        name: 'PurchaseOrderFormCubit',
      );
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

  @override
  Future<void> close() {
    _draftTimer?.cancel();
    return super.close();
  }
}
