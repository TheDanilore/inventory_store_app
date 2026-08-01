import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_pending_customer_orders_uc.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/check_active_shift_uc.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/register_payment/register_payment_state.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:flutter/foundation.dart';

@injectable
class RegisterPaymentCubit extends Cubit<RegisterPaymentState> {
  final GetFinancialAccountsUseCase _getFinancialAccountsUc;
  final GetPendingCustomerOrdersUc _getPendingCustomerOrdersUc;
  final CheckActiveShiftUc _checkActiveShiftUc;

  RegisterPaymentCubit(
    this._getFinancialAccountsUc,
    this._getPendingCustomerOrdersUc,
    this._checkActiveShiftUc,
  ) : super(const RegisterPaymentState());

  Future<void> loadInitialData(String customerId) async {
    emit(state.copyWith(isLoading: true, clearLoadingError: true));

    try {
      final futures = await Future.wait([
        _getPendingCustomerOrdersUc(customerId),
        _getFinancialAccountsUc(page: 1, pageSize: 100),
      ]);

      final ordersResult = futures[0] as dynamic;
      final accountsResult = futures[1] as dynamic;

      List<OrderEntity> pendingOrders = [];
      ordersResult.fold(
        (l) => debugPrint('[RegisterPaymentCubit] orders error: ${l.message}'),
        (r) => pendingOrders = r as List<OrderEntity>,
      );

      List<FinancialAccountEntity> accounts = [];
      if (accountsResult is List<FinancialAccountEntity>) {
        accounts = accountsResult.where((a) => a.isActive).toList();
      } else {
        debugPrint('[RegisterPaymentCubit] accounts error');
      }
      
      // Select first account if available
      FinancialAccountEntity? selectedAccount;
      if (accounts.isNotEmpty) {
        selectedAccount = accounts.first;
      }

      emit(state.copyWith(
        pendingOrders: pendingOrders,
        accounts: accounts,
        selectedAccount: selectedAccount,
        isLoading: false,
      ));

      if (selectedAccount != null && selectedAccount.type == 'CAJA') {
        await _checkActiveShift(selectedAccount.id);
      }
    } catch (e, st) {
      debugPrint('[RegisterPaymentCubit] loadInitialData error: $e\n$st');
      emit(state.copyWith(
        isLoading: false,
        loadingError: 'Error al cargar los datos: $e',
      ));
    }
  }

  Future<void> _checkActiveShift(String accountId) async {
    try {
      final result = await _checkActiveShiftUc(accountId);
      result.fold(
        (l) => emit(state.copyWith(activeShift: null)),
        (r) => emit(state.copyWith(activeShift: r)),
      );
    } catch (e, st) {
      debugPrint('[RegisterPaymentCubit] checkActiveShift error: $e\n$st');
      emit(state.copyWith(clearActiveShift: true));
    }
  }

  void selectAccount(FinancialAccountEntity account) {
    emit(state.copyWith(selectedAccount: account, clearActiveShift: true));
    if (account.type == 'CAJA') {
      _checkActiveShift(account.id);
    }
  }

  void selectOrder(OrderEntity? order, double maxDebt) {
    emit(state.copyWith(selectedOrder: order));
    validateAmount(state.amount, maxDebt);
  }

  void selectQuickAmount(double amount, String chipId, double maxDebt) {
    emit(state.copyWith(
      selectedQuickChip: chipId,
      amount: amount.toStringAsFixed(2),
    ));
    validateAmount(amount.toStringAsFixed(2), maxDebt, fromQuick: true);
  }

  void validateAmount(String value, double maxDebt, {bool fromQuick = false}) {
    if (!fromQuick && state.selectedQuickChip != null) {
      emit(state.copyWith(clearSelectedQuickChip: true));
    }

    if (value.trim().isEmpty) {
      emit(state.copyWith(amount: value, clearAmountError: true));
      return;
    }

    final amount = double.tryParse(value.trim());
    if (amount == null) {
      emit(state.copyWith(amount: value, amountError: 'Ingrese un monto válido'));
      return;
    }

    if (amount <= 0) {
      emit(state.copyWith(amount: value, amountError: 'El monto debe ser mayor a 0'));
      return;
    }

    if (state.selectedOrder != null) {
      final pending = state.selectedOrder!.totalAmount - state.selectedOrder!.amountPaid;
      if (amount > pending) {
        emit(state.copyWith(
          amount: value,
          amountError: 'Máximo para este pedido: S/ ${pending.toStringAsFixed(2)}',
        ));
        return;
      }
    } else {
      if (amount > maxDebt) {
        emit(state.copyWith(
          amount: value,
          amountError: 'Supera la deuda total (S/ ${maxDebt.toStringAsFixed(2)})',
        ));
        return;
      }
    }

    emit(state.copyWith(amount: value, clearAmountError: true));
  }

  Future<void> submitPayment({
    required double debt,
    required Future<void> Function(double amount, String? accountId, String? orderId, String? notes) onSavePayment,
    required String notesText,
  }) async {
    if (debt <= 0) {
      emit(state.copyWith(errorMessage: 'El cliente no tiene deuda pendiente para abonar.'));
      return;
    }

    if (state.selectedAccount != null &&
        state.selectedAccount!.type == 'CAJA' &&
        state.activeShift == null) {
      emit(state.copyWith(errorMessage: 'La cuenta Caja seleccionada no tiene un turno abierto.'));
      return;
    }

    final amount = double.tryParse(state.amount.trim());
    if (amount == null || amount <= 0) {
      emit(state.copyWith(amountError: 'Ingrese un monto válido.'));
      return;
    }

    emit(state.copyWith(isSaving: true, clearErrorMessage: true, isSuccess: false));
    
    try {
      await onSavePayment(
        amount, 
        state.selectedAccount?.id, 
        state.selectedOrder?.id, 
        notesText.isEmpty ? 'Abono registrado a crédito' : notesText,
      );
      emit(state.copyWith(isSaving: false, isSuccess: true));
    } catch (e, st) {
      debugPrint('[RegisterPaymentCubit] submitPayment error: $e\n$st');
      emit(state.copyWith(
        isSaving: false, 
        errorMessage: 'Error al registrar el pago: $e',
      ));
    }
  }
  
  void clearErrorMessage() {
    emit(state.copyWith(clearErrorMessage: true));
  }
}
