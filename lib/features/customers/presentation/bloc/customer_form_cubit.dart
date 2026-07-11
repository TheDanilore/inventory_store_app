import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_ucs.dart';

abstract class CustomerFormState {}

class CustomerFormInitial extends CustomerFormState {}

class CustomerFormSaving extends CustomerFormState {}

class CustomerFormSuccess extends CustomerFormState {}

class CustomerFormError extends CustomerFormState {
  final String message;
  CustomerFormError(this.message);
}

@injectable
class CustomerFormCubit extends Cubit<CustomerFormState> {
  final SaveCustomerFullProfileUseCase _saveCustomerFullProfileUseCase;

  CustomerFormCubit(this._saveCustomerFullProfileUseCase) : super(CustomerFormInitial());

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
