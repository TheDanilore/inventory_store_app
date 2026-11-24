import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';

class CustomerCreditListResultEntity extends Equatable {
  final List<CustomerCreditEntity> accounts;
  final int totalCount;
  final double totalDebt;
  final int activeAccounts;
  final int suspendedAccounts;
  final int maxedOutAccounts;
  final int debtCount;

  const CustomerCreditListResultEntity({
    required this.accounts,
    required this.totalCount,
    required this.totalDebt,
    required this.activeAccounts,
    required this.suspendedAccounts,
    required this.maxedOutAccounts,
    this.debtCount = 0,
  });

  CustomerCreditListResultEntity copyWith({
    List<CustomerCreditEntity>? accounts,
    int? totalCount,
    double? totalDebt,
    int? activeAccounts,
    int? suspendedAccounts,
    int? maxedOutAccounts,
    int? debtCount,
  }) {
    return CustomerCreditListResultEntity(
      accounts: accounts ?? this.accounts,
      totalCount: totalCount ?? this.totalCount,
      totalDebt: totalDebt ?? this.totalDebt,
      activeAccounts: activeAccounts ?? this.activeAccounts,
      suspendedAccounts: suspendedAccounts ?? this.suspendedAccounts,
      maxedOutAccounts: maxedOutAccounts ?? this.maxedOutAccounts,
      debtCount: debtCount ?? this.debtCount,
    );
  }

  @override
  List<Object?> get props => [
    accounts,
    totalCount,
    totalDebt,
    activeAccounts,
    suspendedAccounts,
    maxedOutAccounts,
    debtCount,
  ];
}
