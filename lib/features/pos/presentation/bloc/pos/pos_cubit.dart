import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/load_initial_pos_data_uc.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';

@injectable
class PosCubit extends Cubit<PosState> {
  final LoadInitialPosDataUseCase _loadInitialPosData;

  PosCubit({required LoadInitialPosDataUseCase loadInitialPosData})
    : _loadInitialPosData = loadInitialPosData,
      super(const PosState());

  Future<void> initPosData({bool forceRefresh = false}) async {
    emit(state.copyWith(isLoading: true, errorMessage: ''));

    final res = await _loadInitialPosData(
      LoadInitialPosDataParams(forceRefresh: forceRefresh),
    );
    res.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, errorMessage: failure.message)),
      (data) {
        emit(
          state.copyWith(
            isLoading: false,
            warehouses: data.warehouses,
            accounts: data.accounts,
          ),
        );
      },
    );
  }

  void setClient(String id, String name, int saldo) {
    emit(
      state.copyWith(
        selectedClientId: id,
        selectedClientName: name,
        saldoActualCliente: saldo,
      ),
    );
  }

  void removeClient() {
    emit(state.copyWith(clearClient: true));
  }

  void setPuntosAUsar(int puntos) {
    emit(state.copyWith(puntosAUsar: puntos));
  }

  void setPaymentMethod(String method) {
    emit(state.copyWith(paymentMethod: method));
  }

  void setWarehouse(String? id) {
    emit(state.copyWith(selectedWarehouseId: id));
  }

  void setBatchOverride(
    String cartKey,
    List<BatchAssignmentModel> assignments,
  ) {
    final overrides = Map<String, List<BatchAssignmentModel>>.from(
      state.batchOverrides,
    );
    overrides[cartKey] = assignments;
    emit(state.copyWith(batchOverrides: overrides));
  }

  void clearBatchOverride(String cartKey) {
    final overrides = Map<String, List<BatchAssignmentModel>>.from(
      state.batchOverrides,
    );
    overrides.remove(cartKey);
    emit(state.copyWith(batchOverrides: overrides));
  }

  void clearAllBatchOverrides() {
    emit(state.copyWith(batchOverrides: {}));
  }
}
