import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_active_cash_shift_typed_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_pending_purchase_orders_typed_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/register_supplier_payment_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_payment_form_state.dart';

@injectable
class SupplierPaymentFormCubit extends Cubit<SupplierPaymentFormState> {
  final GetPendingPurchaseOrdersTypedUseCase _getPendingOrders;
  final GetFinancialAccountsUseCase _getFinancialAccounts;
  final GetActiveCashShiftTypedUseCase _getActiveCashShift;

  final Random _random = Random.secure();
  late SupplierCreditEntity _creditAccount;
  int _shiftRequestId = 0;

  SupplierPaymentFormCubit(
    this._getPendingOrders,
    this._getFinancialAccounts,
    this._getActiveCashShift,
  ) : super(const SupplierPaymentFormState());

  String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> init(SupplierCreditEntity account) async {
    _creditAccount = account;
    emit(state.copyWith(idempotencyKey: _generateUuidV4()));
    await Future.wait([_loadPendingOrders(), _loadAccounts()]);
  }

  Future<void> reloadAll() async {
    emit(
      state.copyWith(
        loadingOrders: true,
        loadingAccounts: true,
        clearOrdersFailure: true,
        clearAccountsFailure: true,
      ),
    );
    await Future.wait([_loadPendingOrders(), _loadAccounts()]);
  }

  Future<void> _loadPendingOrders() async {
    final res = await _getPendingOrders(_creditAccount.supplierId);
    if (isClosed) return;
    res.fold(
      (failure) => emit(
        state.copyWith(loadingOrders: false, ordersFailure: failure),
      ),
      (orders) => emit(
        state.copyWith(
          pendingOrders: orders,
          loadingOrders: false,
          clearOrdersFailure: true,
        ),
      ),
    );
  }

  Future<void> _loadAccounts() async {
    final res = await _getFinancialAccounts();
    if (isClosed) return;
    await res.fold(
      (failure) async {
        emit(
          state.copyWith(loadingAccounts: false, accountsFailure: failure),
        );
      },
      (accounts) async {
        final first = accounts.isNotEmpty ? accounts.first : null;
        emit(
          state.copyWith(
            accounts: accounts,
            selectedAccount: first,
            clearSelectedAccount: first == null,
            loadingAccounts: false,
            clearAccountsFailure: true,
          ),
        );
        if (first?.type == 'CAJA') {
          await checkActiveShift(first!.id);
        }
      },
    );
  }

  Future<void> checkActiveShift(String accountId) async {
    final reqId = ++_shiftRequestId;
    emit(
      state.copyWith(
        shiftStatus: CashShiftStatus.loading,
        clearActiveShift: true,
        clearShiftFailure: true,
      ),
    );

    final res = await _getActiveCashShift(accountId);
    if (isClosed || reqId != _shiftRequestId) return;

    res.fold(
      (failure) => emit(
        state.copyWith(
          shiftStatus: CashShiftStatus.error,
          clearActiveShift: true,
          shiftFailure: failure,
        ),
      ),
      (shift) {
        if (shift == null) {
          emit(
            state.copyWith(
              shiftStatus: CashShiftStatus.closed,
              clearActiveShift: true,
              clearShiftFailure: true,
            ),
          );
        } else {
          emit(
            state.copyWith(
              shiftStatus: CashShiftStatus.open,
              activeShift: shift,
              clearShiftFailure: true,
            ),
          );
        }
      },
    );
  }

  void selectAccount(SupplierFinancialAccountOption? account) {
    if (account == null) return;
    emit(
      state.copyWith(
        selectedAccount: account,
        shiftStatus:
            account.type == 'CAJA'
                ? CashShiftStatus.loading
                : CashShiftStatus.idle,
        clearActiveShift: true,
        clearShiftFailure: true,
        idempotencyKey: _generateUuidV4(),
      ),
    );
    if (account.type == 'CAJA') {
      checkActiveShift(account.id);
    }
    validateAmount(state.amountText);
  }

  void selectOrder(String? orderId) {
    String nextAmountText = state.amountText;
    if (orderId != null) {
      final idx = state.pendingOrders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        nextAmountText = state.pendingOrders[idx].pendingAmount.toStringAsFixed(
          2,
        );
      }
    }

    emit(
      state.copyWith(
        selectedOrderId: orderId,
        clearSelectedOrderId: orderId == null,
        amountText: nextAmountText,
        clearSelectedQuickAmount: orderId != null,
        idempotencyKey: _generateUuidV4(),
      ),
    );
    validateAmount(nextAmountText, fromQuick: true);
  }

  void selectQuickAmount(String value) {
    emit(
      state.copyWith(
        selectedQuickAmount: value,
        amountText: value,
        idempotencyKey: _generateUuidV4(),
      ),
    );
    validateAmount(value, fromQuick: true);
  }

  void validateAmount(String value, {bool fromQuick = false}) {
    final trimmed = value.trim();
    String? error;

    if (trimmed.isNotEmpty) {
      final amount = double.tryParse(trimmed);
      if (amount == null) {
        error = 'Monto inválido';
      } else if (amount <= 0) {
        error = 'El monto debe ser mayor a 0';
      } else if (state.selectedOrderId != null) {
        final idx = state.pendingOrders.indexWhere(
          (o) => o.id == state.selectedOrderId,
        );
        if (idx != -1) {
          final pending = state.pendingOrders[idx].pendingAmount;
          if (amount > pending) {
            error =
                'El monto supera la deuda del pedido (S/ ${pending.toStringAsFixed(2)})';
          }
        }
      } else if (amount > _creditAccount.currentDebt) {
        error =
            'El monto supera la deuda total (S/ ${_creditAccount.currentDebt.toStringAsFixed(2)})';
      }
    }

    emit(
      state.copyWith(
        amountText: value,
        clearSelectedQuickAmount: !fromQuick,
        amountError: error,
        clearAmountError: error == null,
        idempotencyKey:
            !fromQuick ? _generateUuidV4() : state.idempotencyKey,
      ),
    );
  }

  String? preSubmitValidationError() {
    if (state.selectedAccount == null) {
      return 'Selecciona una cuenta de salida.';
    }
    if (state.selectedAccount!.type == 'CAJA') {
      if (state.shiftStatus == CashShiftStatus.error) {
        return 'No se pudo verificar el turno de caja. Reintenta.';
      }
      if (state.shiftStatus != CashShiftStatus.open ||
          state.activeShift == null) {
        return 'La cuenta CAJA no tiene un turno abierto.';
      }
    }
    final amount = state.parsedAmount;
    if (amount <= 0) {
      return 'Ingresa un monto válido mayor a 0.';
    }
    if (state.selectedAccount!.balance < amount) {
      return 'Saldo insuficiente. La cuenta tiene S/ ${state.selectedAccount!.balance.toStringAsFixed(2)} y el monto requerido es S/ ${amount.toStringAsFixed(2)}.';
    }
    return null;
  }

  RegisterSupplierPaymentParams buildParams(String rawNotes) {
    final notesText =
        rawNotes.trim().isEmpty
            ? 'Pago registrado desde Admin Cuentas por Pagar'
            : rawNotes.trim();
    return RegisterSupplierPaymentParams(
      supplierId: _creditAccount.supplierId,
      creditId: _creditAccount.creditId,
      amount: state.parsedAmount,
      accountId: state.selectedAccount?.id,
      orderId: state.selectedOrderId,
      notes: notesText,
      shiftId:
          state.selectedAccount?.type == 'CAJA'
              ? state.activeShift?.id
              : null,
      idempotencyKey:
          state.idempotencyKey.isNotEmpty
              ? state.idempotencyKey
              : _generateUuidV4(),
    );
  }
}
