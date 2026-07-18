import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class RegisterSupplierCreditPaymentUseCase {
  final SupplierCreditsRepository repository;

  RegisterSupplierCreditPaymentUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required SupplierCreditEntity account,
    required double amount,
    required SupplierFinancialAccountOption selectedAccount,
    required String? selectedOrderId,
    required String notes,
    required List<Map<String, dynamic>> pendingOrders,
    required String? adminProfileId,
    required String? shiftId,
  }) {
    return repository.registerPayment(
      account: account,
      amount: amount,
      selectedAccount: selectedAccount,
      selectedOrderId: selectedOrderId,
      notes: notes,
      pendingOrders: pendingOrders,
      adminProfileId: adminProfileId,
      shiftId: shiftId,
    );
  }
}
