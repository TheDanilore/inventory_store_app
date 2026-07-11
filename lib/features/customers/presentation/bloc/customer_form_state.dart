import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';

abstract class CustomerFormState {}

class CustomerFormInitial extends CustomerFormState {}

class CustomerFormSaving extends CustomerFormState {}

class CustomerFormSuccess extends CustomerFormState {}

class CustomerFormError extends CustomerFormState {
  final String message;
  CustomerFormError(this.message);
}

class CustomerFormCreditLoading extends CustomerFormState {}

class CustomerFormCreditLoaded extends CustomerFormState {
  final CustomerCreditEntity? creditAccount;
  CustomerFormCreditLoaded(this.creditAccount);
}
