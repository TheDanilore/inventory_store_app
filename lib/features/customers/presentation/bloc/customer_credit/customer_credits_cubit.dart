import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credits_state.dart';

@injectable
class CustomerCreditsCubit extends Cubit<CustomerCreditsState> {
  final GetCreditAccountByCustomerUseCase _getCreditAccountByCustomerUseCase;
  final GetCreditMovementsUseCase _getCreditMovementsUseCase;
  final CreateCreditAccountUseCase _createCreditAccountUseCase;
  final RegisterCreditPaymentUseCase _registerCreditPaymentUseCase;

  static const int _movementsLimit = 20;
  static const String _tag = 'CUSTOMER_CREDITS_CUBIT';

  CustomerCreditsCubit(
    this._getCreditAccountByCustomerUseCase,
    this._getCreditMovementsUseCase,
    this._createCreditAccountUseCase,
    this._registerCreditPaymentUseCase,
  ) : super(CustomerCreditsInitial());

  Future<void> loadCreditData(String customerId) async {
    if (!isClosed) emit(CustomerCreditsLoading());

    final accountResult = await _getCreditAccountByCustomerUseCase(customerId);
    if (isClosed) return;

    await accountResult.fold(
      (failure) async {
        LoggerService.e(
          'Error cargando crédito del cliente $customerId: ${failure.message}',
          tag: _tag,
        );
        emit(CustomerCreditsError(failure.message));
      },
      (account) async {
        if (account == null) {
          emit(
            const CustomerCreditsError(
              'El cliente no tiene línea de crédito.',
            ),
          );
          return;
        }

        final movementsResult = await _getCreditMovementsUseCase(
          creditId: account.id,
          limit: _movementsLimit,
          offset: 0,
        );
        if (isClosed) return;

        movementsResult.fold(
          (failure) {
            LoggerService.e(
              'Error cargando movimientos del cliente $customerId: ${failure.message}',
              tag: _tag,
            );
            emit(CustomerCreditsError(failure.message));
          },
          (data) {
            emit(
              CustomerCreditsLoaded(
                creditAccount: account,
                movements: data.items,
                hasReachedMaxMovements:
                    data.items.length >= data.totalCount ||
                    data.items.length < _movementsLimit,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> loadMoreMovements() async {
    final currentState = state;
    if (currentState is! CustomerCreditsLoaded ||
        currentState.hasReachedMaxMovements) {
      return;
    }

    final result = await _getCreditMovementsUseCase(
      creditId: currentState.creditAccount.id,
      limit: _movementsLimit,
      offset: currentState.movements.length,
    );
    if (isClosed) return;

    result.fold(
      (failure) => LoggerService.w(
        'Error cargando más movimientos de crédito: ${failure.message}',
        tag: _tag,
      ),
      (newMovements) {
        final combinedMovements = [
          ...currentState.movements,
          ...newMovements.items,
        ];
        emit(
          currentState.copyWith(
            movements: combinedMovements,
            hasReachedMaxMovements:
                combinedMovements.length >= newMovements.totalCount ||
                newMovements.items.isEmpty,
          ),
        );
      },
    );
  }

  Future<void> createCreditAccount(String customerId, double limit) async {
    if (!isClosed) emit(CustomerCreditsLoading());

    final result = await _createCreditAccountUseCase(
      customerId: customerId,
      creditLimit: limit,
    );
    if (isClosed) return;

    result.fold(
      (failure) {
        LoggerService.e(
          'Error creando cuenta de crédito para cliente $customerId: ${failure.message}',
          tag: _tag,
        );
        emit(CustomerCreditsError(failure.message));
      },
      (account) {
        emit(
          CustomerCreditsLoaded(
            creditAccount: account,
            movements: const [],
            hasReachedMaxMovements: true,
          ),
        );
      },
    );
  }

  Future<void> registerPayment({
    required double amount,
    String? accountId,
    String? orderId,
    String? notes,
    String? shiftId,
    String? idempotencyKey,
  }) async {
    final currentState = state;
    if (currentState is! CustomerCreditsLoaded) return;

    final targetCustomerId = currentState.creditAccount.effectiveCustomerId;
    final result = await _registerCreditPaymentUseCase(
      customerId: targetCustomerId,
      creditId: currentState.creditAccount.id,
      amount: amount,
      accountId: accountId,
      orderId: orderId,
      notes: notes,
      shiftId: shiftId,
      idempotencyKey: idempotencyKey,
    );

    if (isClosed) return;

    await result.fold(
      (failure) async {
        LoggerService.e(
          'Error registrando pago de crédito para $targetCustomerId: ${failure.message}',
          tag: _tag,
        );
        throw Exception(failure.message);
      },
      (_) async => loadCreditData(targetCustomerId),
    );
  }
}
