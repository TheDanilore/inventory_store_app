import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';

abstract class CustomerCreditsRepository {
  Future<List<CustomerCreditEntity>> getCreditAccounts({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  });

  Future<CustomerCreditEntity?> getCreditAccountByCustomer(String customerId);

  Future<CustomerCreditEntity> createCreditAccount({
    required String customerId,
    required double creditLimit,
  });

  Future<CustomerCreditEntity> updateCreditLimit({
    required String creditId,
    required double newLimit,
  });

  Future<void> toggleCreditStatus(String creditId, bool isActive);

  // Movimientos
  Future<List<CreditMovementEntity>> getCreditMovements({
    required String creditId,
    required int limit,
    required int offset,
    String? dateFilter,
  });

  Future<({double totalCharged, double totalPaid})> getCreditMovementsTotals({
    required String creditId,
    String? dateFilter,
  });

  Future<CreditMovementEntity> registerPayment({
    required String creditId,
    required double amount,
    String? paymentMethod,
    String? notes,
  });
}
