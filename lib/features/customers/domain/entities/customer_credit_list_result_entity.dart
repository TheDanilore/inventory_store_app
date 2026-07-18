import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';

class CustomerCreditListResultEntity extends Equatable {
  final List<CustomerCreditEntity> accounts;
  final int totalCount;
  final double totalDebt;
  final int activeAccounts;
  final int suspendedAccounts;
  final int maxedOutAccounts;

  const CustomerCreditListResultEntity({
    required this.accounts,
    required this.totalCount,
    required this.totalDebt,
    required this.activeAccounts,
    required this.suspendedAccounts,
    required this.maxedOutAccounts,
  });

  @override
  List<Object?> get props => [
        accounts,
        totalCount,
        totalDebt,
        activeAccounts,
        suspendedAccounts,
        maxedOutAccounts,
      ];
}
