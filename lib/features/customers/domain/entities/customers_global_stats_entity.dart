import 'package:equatable/equatable.dart';

/// Estadísticas globales tipadas del módulo de clientes.
class CustomersGlobalStatsEntity extends Equatable {
  final int totalCustomersCount;
  final int activeCustomersCount;
  final int inactiveCustomersCount;
  final double totalRevenue;
  final double totalDebt;
  final int debtCustomersCount;
  final double totalWalletBalance;

  const CustomersGlobalStatsEntity({
    required this.totalCustomersCount,
    required this.activeCustomersCount,
    required this.inactiveCustomersCount,
    required this.totalRevenue,
    required this.totalDebt,
    required this.debtCustomersCount,
    this.totalWalletBalance = 0.0,
  });

  const CustomersGlobalStatsEntity.empty()
    : totalCustomersCount = 0,
      activeCustomersCount = 0,
      inactiveCustomersCount = 0,
      totalRevenue = 0.0,
      totalDebt = 0.0,
      debtCustomersCount = 0,
      totalWalletBalance = 0.0;

  @override
  List<Object?> get props => [
    totalCustomersCount,
    activeCustomersCount,
    inactiveCustomersCount,
    totalRevenue,
    totalDebt,
    debtCustomersCount,
    totalWalletBalance,
  ];
}
