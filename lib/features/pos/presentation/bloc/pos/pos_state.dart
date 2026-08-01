import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';

enum PosStatus { initial, loading, success, error }

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

  final PosStatus status;
  final CashShiftEntity? activeShift;
  final List<Map<String, dynamic>> clientMatches;
  final String? lastOrderId;
  final Map<String, dynamic>? creditInfo;
  final String? selectedAccountId;

  final List<OrderModel> recentOrders;
  final bool isLoadingRecentOrders;
  final String recentOrdersError;

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
    this.status = PosStatus.initial,
    this.activeShift,
    this.clientMatches = const [],
    this.lastOrderId,
    this.creditInfo,
    this.selectedAccountId,
    this.recentOrders = const [],
    this.isLoadingRecentOrders = false,
    this.recentOrdersError = '',
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
    PosStatus? status,
    CashShiftEntity? activeShift,
    List<Map<String, dynamic>>? clientMatches,
    String? lastOrderId,
    Map<String, dynamic>? creditInfo,
    String? selectedAccountId,
    List<OrderModel>? recentOrders,
    bool? isLoadingRecentOrders,
    String? recentOrdersError,
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
      status: status ?? this.status,
      activeShift: activeShift ?? this.activeShift,
      clientMatches: clientMatches ?? this.clientMatches,
      lastOrderId: lastOrderId ?? this.lastOrderId,
      creditInfo: clearClient ? null : (creditInfo ?? this.creditInfo),
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      recentOrders: recentOrders ?? this.recentOrders,
      isLoadingRecentOrders: isLoadingRecentOrders ?? this.isLoadingRecentOrders,
      recentOrdersError: recentOrdersError ?? this.recentOrdersError,
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
    status,
    activeShift,
    clientMatches,
    lastOrderId,
    creditInfo,
    selectedAccountId,
    recentOrders,
    isLoadingRecentOrders,
    recentOrdersError,
  ];
}
