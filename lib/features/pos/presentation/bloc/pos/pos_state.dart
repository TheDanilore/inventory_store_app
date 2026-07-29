import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';

class PosState extends Equatable {
  final bool isLoading;
  final String errorMessage;

  final String? selectedClientId;
  final String? selectedClientName;
  final int saldoActualCliente;
  final int puntosAUsar;
  final String paymentMethod;
  final String? selectedWarehouseId;

  final Map<String, List<BatchAssignmentModel>> batchOverrides;

  final List<WarehouseModel> warehouses;
  final List<Map<String, dynamic>> accounts;

  const PosState({
    this.isLoading = false,
    this.errorMessage = '',
    this.selectedClientId,
    this.selectedClientName,
    this.saldoActualCliente = 0,
    this.puntosAUsar = 0,
    this.paymentMethod = 'EFECTIVO',
    this.selectedWarehouseId,
    this.batchOverrides = const {},
    this.warehouses = const [],
    this.accounts = const [],
  });

  PosState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? selectedClientId,
    String? selectedClientName,
    int? saldoActualCliente,
    int? puntosAUsar,
    String? paymentMethod,
    String? selectedWarehouseId,
    Map<String, List<BatchAssignmentModel>>? batchOverrides,
    List<WarehouseModel>? warehouses,
    List<Map<String, dynamic>>? accounts,
    bool clearClient = false,
  }) {
    return PosState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedClientId:
          clearClient ? null : (selectedClientId ?? this.selectedClientId),
      selectedClientName:
          clearClient ? null : (selectedClientName ?? this.selectedClientName),
      saldoActualCliente:
          clearClient ? 0 : (saldoActualCliente ?? this.saldoActualCliente),
      puntosAUsar: clearClient ? 0 : (puntosAUsar ?? this.puntosAUsar),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      selectedWarehouseId: selectedWarehouseId ?? this.selectedWarehouseId,
      batchOverrides: batchOverrides ?? this.batchOverrides,
      warehouses: warehouses ?? this.warehouses,
      accounts: accounts ?? this.accounts,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    errorMessage,
    selectedClientId,
    selectedClientName,
    saldoActualCliente,
    puntosAUsar,
    paymentMethod,
    selectedWarehouseId,
    batchOverrides,
    warehouses,
    accounts,
  ];
}
