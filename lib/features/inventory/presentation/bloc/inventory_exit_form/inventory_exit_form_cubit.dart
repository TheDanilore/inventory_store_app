import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/inventory/data/services/inventory_exit_draft_service.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_active_warehouses_exits_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/create_inventory_exit_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';

@injectable
class InventoryExitFormCubit extends Cubit<InventoryExitFormState> {
  final GetActiveWarehousesExitsUseCase getActiveWarehousesUseCase;
  final CreateInventoryExitUseCase createInventoryExitUseCase;
  final InventoryExitDraftService _draftService = InventoryExitDraftService();

  InventoryExitFormCubit({
    required this.getActiveWarehousesUseCase,
    required this.createInventoryExitUseCase,
  }) : super(const InventoryExitFormState());

  Future<void> loadInitialData() async {
    emit(state.copyWith(isLoading: true, errorMessage: '', isSuccess: false));

    try {
      final warehousesData = await getActiveWarehousesUseCase.call();

      final warehouses =
          warehousesData
              .map((w) => WarehouseModel(id: w.id, name: w.name))
              .toList();
      String? initialWarehouseId =
          warehouses.isNotEmpty ? warehouses.first.id : null;

      emit(
        state.copyWith(
          warehouses: warehouses,
          selectedWarehouseId: initialWarehouseId,
        ),
      );

      await _loadDraft();
      emit(state.copyWith(isLoading: false));
    } catch (e, st) {
      developer.log('Error loading form data', error: e, stackTrace: st);
      if (e is SocketException || e is TimeoutException) {
        emit(
          state.copyWith(
            errorMessage: 'Sin conexión a internet.',
            isLoading: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            errorMessage: 'Error cargando datos: ${e.toString()}',
            isLoading: false,
          ),
        );
      }
    }
  }

  void selectWarehouse(String? id) {
    if (id != null && id != state.selectedWarehouseId) {
      emit(state.copyWith(selectedWarehouseId: id, items: []));
      unawaited(_saveDraft());
    }
  }

  void selectReason(String reason) {
    emit(state.copyWith(selectedReason: reason));
    unawaited(_saveDraft());
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
    unawaited(_saveDraft());
  }

  void removeItem(int index) {
    final newItems = List<ExitItemUI>.from(state.items);
    newItems.removeAt(index);
    emit(state.copyWith(items: newItems));
    unawaited(_saveDraft());
  }

  void updateQuantity(int index, double newQuantity) {
    if (newQuantity > 0) {
      final newItems = List<ExitItemUI>.from(state.items);
      newItems[index].quantity = newQuantity;
      emit(state.copyWith(items: newItems));
      unawaited(_saveDraft());
    }
  }

  Future<void> saveExit(String? notes) async {
    if (state.selectedWarehouseId == null || state.items.isEmpty) return;

    emit(state.copyWith(isSaving: true, errorMessage: '', isSuccess: false));

    try {
      final itemsData =
          state.items.map((item) {
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
        createdByProfileId: null,
        items: itemsData,
      );

      await clearDraft();

      emit(state.copyWith(isSaving: false, isSuccess: true));
    } catch (e, st) {
      developer.log('Error saving exit', error: e, stackTrace: st);
      if (e is SocketException || e is TimeoutException) {
        emit(
          state.copyWith(
            errorMessage: 'Sin conexión a internet.',
            isSaving: false,
          ),
        );
      } else {
        // Here we can directly get the exception message since the repository handles it
        emit(
          state.copyWith(
            errorMessage: e.toString().replaceAll('Exception: ', ''),
            isSaving: false,
          ),
        );
      }
    }
  }

  Future<void> clearDraft() async {
    emit(state.copyWith(items: [], errorMessage: ''));
    await _draftService.clearDraft();
  }

  Future<void> _saveDraft() async {
    final itemsJson = state.items.map((e) => e.toJson()).toList();
    final draftData = {
      'warehouseId': state.selectedWarehouseId,
      'reason': state.selectedReason,
      'items': itemsJson,
    };
    await _draftService.saveDraft(draftData);
  }

  Future<void> _loadDraft() async {
    final draftData = await _draftService.loadDraft();
    if (draftData != null) {
      try {
        final itemsJson = draftData['items'] as List<dynamic>? ?? [];

        final draftItems =
            itemsJson
                .map((e) => ExitItemUI.fromJson(e as Map<String, dynamic>))
                .toList();

        final draftWarehouseId = draftData['warehouseId'] as String?;
        final draftReason = draftData['reason'] as String?;

        String? finalWarehouseId = state.selectedWarehouseId;
        if (draftWarehouseId != null &&
            state.warehouses.any((w) => w.id == draftWarehouseId)) {
          finalWarehouseId = draftWarehouseId;
        }

        emit(
          state.copyWith(
            selectedWarehouseId: finalWarehouseId,
            selectedReason: draftReason ?? state.selectedReason,
            items: draftItems,
          ),
        );
      } catch (e, st) {
        developer.log('Error loading draft', error: e, stackTrace: st);
        await clearDraft();
      }
    }
  }
}
