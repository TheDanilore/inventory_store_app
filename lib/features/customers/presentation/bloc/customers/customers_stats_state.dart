import 'package:equatable/equatable.dart';

abstract class CustomersStatsState extends Equatable {
  const CustomersStatsState();

  @override
  List<Object?> get props => [];
}

class CustomersStatsInitial extends CustomersStatsState {}

class CustomersStatsLoading extends CustomersStatsState {}

class CustomersStatsLoaded extends CustomersStatsState {
  final Map<String, dynamic> stats;
  const CustomersStatsLoaded(this.stats);

  int get totalCustomersCount => stats['totalCustomersCount'] ?? 0;
  int get activeCustomersCount => stats['activeCustomersCount'] ?? 0;
  double get totalRevenue => stats['totalRevenue'] ?? 0.0;
  double get totalDebt => stats['totalDebt'] ?? 0.0;
  int get debtCustomersCount => stats['debtCustomersCount'] ?? 0;

  @override
  List<Object?> get props => [stats];
}

class CustomersStatsError extends CustomersStatsState {
  final String message;

  const CustomersStatsError(this.message);

  @override
  List<Object?> get props => [message];
}
