import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/register_payment/register_payment_state.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_pending_customer_orders_uc.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/check_active_shift_uc.dart';

typedef SaveCustomerPaymentCallback =
    Future<void> Function(
      double amount,
      String? accountId,
      String? orderId,
      String? notes,
      String? shiftId,
      String idempotencyKey,
    );

@injectable
class RegisterPaymentCubit extends Cubit<RegisterPaymentState> {
  final GetFinancialAccountsUseCase _getFinancialAccountsUc;
  final GetPendingCustomerOrdersUc _getPendingCustomerOrdersUc;
  final CheckActiveShiftUc _checkActiveShiftUc;

  final Random _random = Random.secure();
  int _shiftRequestId = 0;

  static const String _tag = 'REGISTER_PAYMENT_CUBIT';

  RegisterPaymentCubit(
    this._getFinancialAccountsUc,
    this._getPendingCustomerOrdersUc,
    this._checkActiveShiftUc,
  ) : super(const RegisterPaymentState());

  String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> loadInitialData(String customerId) async {
    if (!isClosed) {
      emit(
        state.copyWith(
          isLoading: true,
          clearLoadingError: true,
          idempotencyKey: _generateUuidV4(),
        ),
      );
    }

    try {
      final (ordersResult, allAccounts) =
          await (
            _getPendingCustomerOrdersUc(customerId),
            _getFinancialAccountsUc(page: 0, pageSize: 50),
          ).wait;

      if (isClosed) return;

      final List<OrderEntity> pendingOrders = ordersResult.fold((l) {
        LoggerService.w('orders error: ${l.message}', tag: _tag);
        return const [];
      }, (r) => r);

      final accounts = allAccounts
          .where((a) => a.isActive)
          .toList(growable: false);
      final FinancialAccountEntity? selectedAccount =
          accounts.isNotEmpty ? accounts.first : null;

      emit(
        state.copyWith(
          pendingOrders: pendingOrders,
          accounts: accounts,
          selectedAccount: selectedAccount,
          clearSelectedAccount: selectedAccount == null,
          isLoading: false,
        ),
      );

      if (selectedAccount != null && selectedAccount.type == 'CAJA') {
        await checkActiveShift(selectedAccount.id);
      }
    } catch (e, st) {
      LoggerService.e(
        'loadInitialData error',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          loadingError: 'Error al cargar los datos: $e',
        ),
      );
    }
  }

  Future<void> checkActiveShift(String accountId) async {
    final reqId = ++_shiftRequestId;
    if (!isClosed) {
      emit(
        state.copyWith(
          shiftStatus: CustomerPaymentShiftStatus.loading,
          clearActiveShift: true,
          clearShiftErrorMessage: true,
        ),
      );
    }

    try {
      final result = await _checkActiveShiftUc(accountId);
      if (isClosed || reqId != _shiftRequestId) return;

      result.fold(
        (failure) {
          LoggerService.w(
            'checkActiveShift failure: ${failure.message}',
            tag: _tag,
          );
          emit(
            state.copyWith(
              shiftStatus: CustomerPaymentShiftStatus.error,
              clearActiveShift: true,
              shiftErrorMessage: failure.message,
            ),
          );
        },
        (shift) {
          if (shift == null) {
            emit(
              state.copyWith(
                shiftStatus: CustomerPaymentShiftStatus.closed,
                clearActiveShift: true,
                clearShiftErrorMessage: true,
              ),
            );
          } else {
            emit(
              state.copyWith(
                shiftStatus: CustomerPaymentShiftStatus.open,
                activeShift: shift,
                clearShiftErrorMessage: true,
              ),
            );
          }
        },
      );
    } catch (e, st) {
      LoggerService.e(
        'checkActiveShift error',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      if (isClosed || reqId != _shiftRequestId) return;
      emit(
        state.copyWith(
          shiftStatus: CustomerPaymentShiftStatus.error,
          clearActiveShift: true,
          shiftErrorMessage: 'No se pudo verificar el turno de caja.',
        ),
      );
    }
  }

  void selectAccount(FinancialAccountEntity account) {
    emit(
      state.copyWith(
        selectedAccount: account,
        shiftStatus:
            account.type == 'CAJA'
                ? CustomerPaymentShiftStatus.loading
                : CustomerPaymentShiftStatus.idle,
        clearActiveShift: true,
        clearShiftErrorMessage: true,
        idempotencyKey: _generateUuidV4(),
      ),
    );
    if (account.type == 'CAJA') {
      checkActiveShift(account.id);
    }
  }

  void selectOrder(OrderEntity? order, double maxDebt, [String? newAmount]) {
    emit(
      state.copyWith(
        selectedOrder: order,
        clearSelectedOrder: order == null,
        amount: newAmount ?? state.amount,
        clearSelectedQuickChip: true,
        idempotencyKey: _generateUuidV4(),
      ),
    );
    validateAmount(newAmount ?? state.amount, maxDebt);
  }

  void selectQuickAmount(double amount, String chipId, double maxDebt) {
    final formatted = amount.toStringAsFixed(2);
    emit(
      state.copyWith(
        selectedQuickChip: chipId,
        amount: formatted,
        idempotencyKey: _generateUuidV4(),
      ),
    );
    validateAmount(formatted, maxDebt, fromQuick: true);
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
      emit(
        state.copyWith(amount: value, amountError: 'Ingrese un monto válido'),
      );
      return;
    }

    if (amount <= 0) {
      emit(
        state.copyWith(
          amount: value,
          amountError: 'El monto debe ser mayor a 0',
        ),
      );
      return;
    }

    if (state.selectedOrder != null) {
      final pending =
          state.selectedOrder!.totalAmount - state.selectedOrder!.amountPaid;
      final effectiveMax = pending < maxDebt ? pending : maxDebt;

      if (amount > effectiveMax) {
        emit(
          state.copyWith(
            amount: value,
            amountError:
                'Máximo permitido para este pedido: S/ ${effectiveMax.toStringAsFixed(2)}',
          ),
        );
        return;
      }
    } else if (amount > maxDebt) {
      emit(
        state.copyWith(
          amount: value,
          amountError:
              'Supera la deuda total (S/ ${maxDebt.toStringAsFixed(2)})',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        amount: value,
        clearAmountError: true,
        idempotencyKey:
            !fromQuick ? _generateUuidV4() : state.idempotencyKey,
      ),
    );
  }

  Future<void> submitPayment({
    required double debt,
    required SaveCustomerPaymentCallback onSavePayment,
    required String notesText,
  }) async {
    if (state.isSaving) return;

    if (debt <= 0) {
      emit(
        state.copyWith(
          errorMessage: 'El cliente no tiene deuda pendiente para abonar.',
        ),
      );
      return;
    }

    if (state.selectedAccount == null) {
      emit(
        state.copyWith(
          errorMessage:
              'Debes seleccionar una cuenta de destino (Caja o Banco).',
        ),
      );
      return;
    }

    if (state.selectedAccount!.type == 'CAJA') {
      if (state.shiftStatus == CustomerPaymentShiftStatus.error) {
        emit(
          state.copyWith(
            errorMessage:
                state.shiftErrorMessage ??
                'No se pudo validar el turno de caja. Reintenta antes de confirmar.',
          ),
        );
        return;
      }
      if (state.shiftStatus != CustomerPaymentShiftStatus.open ||
          state.activeShift == null) {
        emit(
          state.copyWith(
            errorMessage:
                'La cuenta Caja seleccionada no tiene un turno abierto.',
          ),
        );
        return;
      }
    }

    final amount = double.tryParse(state.amount.trim());
    if (amount == null || amount <= 0) {
      emit(state.copyWith(amountError: 'Ingrese un monto válido.'));
      return;
    }

    final key =
        state.idempotencyKey.isNotEmpty
            ? state.idempotencyKey
            : _generateUuidV4();

    emit(
      state.copyWith(
        isSaving: true,
        clearErrorMessage: true,
        isSuccess: false,
        idempotencyKey: key,
      ),
    );

    try {
      final shiftId =
          state.selectedAccount!.type == 'CAJA' ? state.activeShift?.id : null;

      await onSavePayment(
        amount,
        state.selectedAccount!.id,
        state.selectedOrder?.id,
        notesText.trim().isEmpty
            ? 'Abono registrado a crédito'
            : notesText.trim(),
        shiftId,
        key,
      );
      if (isClosed) return;
      emit(state.copyWith(isSaving: false, isSuccess: true));
    } catch (e, st) {
      LoggerService.e(
        'submitPayment error',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ),
      );
    }
  }

  void clearErrorMessage() {
    if (!isClosed) emit(state.copyWith(clearErrorMessage: true));
  }
}
