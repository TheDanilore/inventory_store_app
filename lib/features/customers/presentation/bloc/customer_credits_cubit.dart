import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_ucs.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credits_state.dart';

@injectable
class CustomerCreditsCubit extends Cubit<CustomerCreditsState> {
  final GetCreditAccountByCustomerUseCase _getCreditAccountByCustomerUseCase;
  final GetCreditMovementsUseCase _getCreditMovementsUseCase;
  final CreateCreditAccountUseCase _createCreditAccountUseCase;
  final RegisterCreditPaymentUseCase _registerCreditPaymentUseCase;

  static const int _movementsLimit = 20;

  CustomerCreditsCubit(
    this._getCreditAccountByCustomerUseCase,
    this._getCreditMovementsUseCase,
    this._createCreditAccountUseCase,
    this._registerCreditPaymentUseCase,
  ) : super(CustomerCreditsInitial());

  Future<void> loadCreditData(String customerId) async {
    emit(CustomerCreditsLoading());
    try {
      final account = await _getCreditAccountByCustomerUseCase(customerId);
      if (account != null) {
        final movements = await _getCreditMovementsUseCase(
          creditId: account.id,
          limit: _movementsLimit,
          offset: 0,
        );
        emit(
          CustomerCreditsLoaded(
            creditAccount: account,
            movements: movements,
            hasReachedMaxMovements: movements.length < _movementsLimit,
          ),
        );
      } else {
        // No account
        emit(
          const CustomerCreditsError("El cliente no tiene línea de crédito."),
        );
      }
    } catch (e) {
      emit(CustomerCreditsError(e.toString()));
    }
  }

  Future<void> loadMoreMovements() async {
    final currentState = state;
    if (currentState is CustomerCreditsLoaded &&
        !currentState.hasReachedMaxMovements) {
      try {
        final newMovements = await _getCreditMovementsUseCase(
          creditId: currentState.creditAccount.id,
          limit: _movementsLimit,
          offset: currentState.movements.length,
        );
        emit(
          currentState.copyWith(
            movements: [...currentState.movements, ...newMovements],
            hasReachedMaxMovements: newMovements.length < _movementsLimit,
          ),
        );
      } catch (e) {
        // Ignore error or show snackbar
      }
    }
  }

  Future<void> createCreditAccount(String customerId, double limit) async {
    try {
      emit(CustomerCreditsLoading());
      final account = await _createCreditAccountUseCase(
        customerId: customerId,
        creditLimit: limit,
      );
      emit(
        CustomerCreditsLoaded(
          creditAccount: account,
          movements: const [],
          hasReachedMaxMovements: true,
        ),
      );
    } catch (e) {
      emit(CustomerCreditsError(e.toString()));
    }
  }

  Future<void> registerPayment({
    required double amount,
    String? paymentMethod,
    String? notes,
  }) async {
    final currentState = state;
    if (currentState is CustomerCreditsLoaded) {
      try {
        await _registerCreditPaymentUseCase(
          creditId: currentState.creditAccount.id,
          amount: amount,
          paymentMethod: paymentMethod,
          notes: notes,
        );
        // Reload all data to refresh debt and movements
        await loadCreditData(currentState.creditAccount.profileId);
      } catch (e) {
        emit(CustomerCreditsError(e.toString()));
        emit(currentState);
      }
    }
  }
}
