import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_ucs.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_ucs.dart';

import 'package:inventory_store_app/features/customers/presentation/bloc/customer_form_state.dart';

@injectable
class CustomerFormCubit extends Cubit<CustomerFormState> {
  final SaveCustomerFullProfileUseCase _saveCustomerFullProfileUseCase;
  final GetCreditAccountByCustomerUseCase _getCreditAccountByCustomerUseCase;

  CustomerFormCubit(
    this._saveCustomerFullProfileUseCase,
    this._getCreditAccountByCustomerUseCase,
  ) : super(CustomerFormInitial());

  Future<void> loadCredit(String customerId) async {
    emit(CustomerFormCreditLoading());
    try {
      final account = await _getCreditAccountByCustomerUseCase(customerId);
      emit(CustomerFormCreditLoaded(account));
    } catch (e) {
      emit(CustomerFormError(e.toString()));
    }
  }

  Future<void> save({
    String? customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    required bool isActive,
    required int walletAdjustDelta,
    required double currentWalletBalance,
    required bool hasCredit,
    required bool creditExistsInDb,
    String? creditId,
    required bool creditIsActive,
    required double newCreditLimit,
  }) async {
    emit(CustomerFormSaving());
    try {
      await _saveCustomerFullProfileUseCase(
        customerId: customerId,
        fullName: fullName,
        phone: phone,
        documentNumber: documentNumber,
        documentType: documentType,
        isActive: isActive,
        walletAdjustDelta: walletAdjustDelta,
        currentWalletBalance: currentWalletBalance,
        hasCredit: hasCredit,
        creditExistsInDb: creditExistsInDb,
        creditId: creditId,
        creditIsActive: creditIsActive,
        newCreditLimit: newCreditLimit,
      );
      emit(CustomerFormSuccess());
    } catch (e) {
      emit(CustomerFormError(e.toString()));
    }
  }
}
