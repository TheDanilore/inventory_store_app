import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

enum CashShiftStatus { idle, loading, open, closed, error }

class SupplierPaymentFormState extends Equatable {
  final List<PendingPurchaseOrderEntity> pendingOrders;
  final bool loadingOrders;
  final Failure? ordersFailure;

  final List<SupplierFinancialAccountOption> accounts;
  final bool loadingAccounts;
  final Failure? accountsFailure;

  final SupplierFinancialAccountOption? selectedAccount;
  final String? selectedOrderId;
  final CashShiftStatus shiftStatus;
  final ActiveCashShiftEntity? activeShift;
  final Failure? shiftFailure;

  final String amountText;
  final String? selectedQuickAmount;
  final String? amountError;
  final String idempotencyKey;

  const SupplierPaymentFormState({
    this.pendingOrders = const [],
    this.loadingOrders = true,
    this.ordersFailure,
    this.accounts = const [],
    this.loadingAccounts = true,
    this.accountsFailure,
    this.selectedAccount,
    this.selectedOrderId,
    this.shiftStatus = CashShiftStatus.idle,
    this.activeShift,
    this.shiftFailure,
    this.amountText = '',
    this.selectedQuickAmount,
    this.amountError,
    this.idempotencyKey = '',
  });

  bool get isLoadingInitial => loadingOrders || loadingAccounts;

  bool get isCajaWithoutOpenShift =>
      selectedAccount?.type == 'CAJA' &&
      shiftStatus != CashShiftStatus.open &&
      shiftStatus != CashShiftStatus.loading;

  double get parsedAmount => double.tryParse(amountText.trim()) ?? 0.0;

  bool get showSummary => parsedAmount > 0 && amountError == null;

  bool get canSubmit =>
      !isLoadingInitial &&
      selectedAccount != null &&
      !(selectedAccount!.type == 'CAJA' &&
          shiftStatus != CashShiftStatus.open) &&
      amountText.trim().isNotEmpty &&
      amountError == null &&
      parsedAmount > 0;

  SupplierPaymentFormState copyWith({
    List<PendingPurchaseOrderEntity>? pendingOrders,
    bool? loadingOrders,
    Failure? ordersFailure,
    bool clearOrdersFailure = false,
    List<SupplierFinancialAccountOption>? accounts,
    bool? loadingAccounts,
    Failure? accountsFailure,
    bool clearAccountsFailure = false,
    SupplierFinancialAccountOption? selectedAccount,
    bool clearSelectedAccount = false,
    String? selectedOrderId,
    bool clearSelectedOrderId = false,
    CashShiftStatus? shiftStatus,
    ActiveCashShiftEntity? activeShift,
    bool clearActiveShift = false,
    Failure? shiftFailure,
    bool clearShiftFailure = false,
    String? amountText,
    String? selectedQuickAmount,
    bool clearSelectedQuickAmount = false,
    String? amountError,
    bool clearAmountError = false,
    String? idempotencyKey,
  }) {
    return SupplierPaymentFormState(
      pendingOrders: pendingOrders ?? this.pendingOrders,
      loadingOrders: loadingOrders ?? this.loadingOrders,
      ordersFailure:
          clearOrdersFailure ? null : (ordersFailure ?? this.ordersFailure),
      accounts: accounts ?? this.accounts,
      loadingAccounts: loadingAccounts ?? this.loadingAccounts,
      accountsFailure:
          clearAccountsFailure
              ? null
              : (accountsFailure ?? this.accountsFailure),
      selectedAccount:
          clearSelectedAccount
              ? null
              : (selectedAccount ?? this.selectedAccount),
      selectedOrderId:
          clearSelectedOrderId
              ? null
              : (selectedOrderId ?? this.selectedOrderId),
      shiftStatus: shiftStatus ?? this.shiftStatus,
      activeShift: clearActiveShift ? null : (activeShift ?? this.activeShift),
      shiftFailure:
          clearShiftFailure ? null : (shiftFailure ?? this.shiftFailure),
      amountText: amountText ?? this.amountText,
      selectedQuickAmount:
          clearSelectedQuickAmount
              ? null
              : (selectedQuickAmount ?? this.selectedQuickAmount),
      amountError: clearAmountError ? null : (amountError ?? this.amountError),
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  @override
  List<Object?> get props => [
    pendingOrders,
    loadingOrders,
    ordersFailure,
    accounts,
    loadingAccounts,
    accountsFailure,
    selectedAccount,
    selectedOrderId,
    shiftStatus,
    activeShift,
    shiftFailure,
    amountText,
    selectedQuickAmount,
    amountError,
    idempotencyKey,
  ];
}
