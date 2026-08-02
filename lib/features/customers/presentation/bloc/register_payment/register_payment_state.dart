import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';

class RegisterPaymentState {
  final bool isLoading;
  final bool isSaving;
  final bool isSuccess;
  final String? errorMessage;
  final String? loadingError;

  // Data
  final List<OrderEntity> pendingOrders;
  final List<FinancialAccountEntity> accounts;

  // Selections
  final OrderEntity? selectedOrder;
  final FinancialAccountEntity? selectedAccount;
  final CashShiftEntity? activeShift;

  // Form
  final String amount;
  final String? amountError;
  final String? selectedQuickChip;

  const RegisterPaymentState({
    this.isLoading = true,
    this.isSaving = false,
    this.isSuccess = false,
    this.errorMessage,
    this.loadingError,
    this.pendingOrders = const [],
    this.accounts = const [],
    this.selectedOrder,
    this.selectedAccount,
    this.activeShift,
    this.amount = '',
    this.amountError,
    this.selectedQuickChip,
  });

  RegisterPaymentState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isSuccess,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? loadingError,
    bool clearLoadingError = false,
    List<OrderEntity>? pendingOrders,
    List<FinancialAccountEntity>? accounts,
    OrderEntity? selectedOrder,
    bool clearSelectedOrder = false,
    FinancialAccountEntity? selectedAccount,
    bool clearSelectedAccount = false,
    CashShiftEntity? activeShift,
    bool clearActiveShift = false,
    String? amount,
    String? amountError,
    bool clearAmountError = false,
    String? selectedQuickChip,
    bool clearSelectedQuickChip = false,
  }) {
    return RegisterPaymentState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      loadingError:
          clearLoadingError ? null : (loadingError ?? this.loadingError),
      pendingOrders: pendingOrders ?? this.pendingOrders,
      accounts: accounts ?? this.accounts,
      selectedOrder:
          clearSelectedOrder ? null : (selectedOrder ?? this.selectedOrder),
      selectedAccount:
          clearSelectedAccount
              ? null
              : (selectedAccount ?? this.selectedAccount),
      activeShift: clearActiveShift ? null : (activeShift ?? this.activeShift),
      amount: amount ?? this.amount,
      amountError: clearAmountError ? null : (amountError ?? this.amountError),
      selectedQuickChip:
          clearSelectedQuickChip
              ? null
              : (selectedQuickChip ?? this.selectedQuickChip),
    );
  }
}
