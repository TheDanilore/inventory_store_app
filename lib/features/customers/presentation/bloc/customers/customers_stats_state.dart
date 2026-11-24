import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_global_stats_entity.dart';

sealed class CustomersStatsState extends Equatable {
  const CustomersStatsState();

  @override
  List<Object?> get props => [];
}

class CustomersStatsInitial extends CustomersStatsState {}

class CustomersStatsLoading extends CustomersStatsState {}

class CustomersStatsLoaded extends CustomersStatsState {
  final CustomersGlobalStatsEntity stats;
  final bool isRefreshing;
  final String? transientErrorMessage;

  const CustomersStatsLoaded(
    this.stats, {
    this.isRefreshing = false,
    this.transientErrorMessage,
  });

  int get totalCustomersCount => stats.totalCustomersCount;
  int get activeCustomersCount => stats.activeCustomersCount;
  int get inactiveCustomersCount => stats.inactiveCustomersCount;
  double get totalRevenue => stats.totalRevenue;
  double get totalDebt => stats.totalDebt;
  int get debtCustomersCount => stats.debtCustomersCount;
  double get totalWalletBalance => stats.totalWalletBalance;

  CustomersStatsLoaded copyWith({
    CustomersGlobalStatsEntity? stats,
    bool? isRefreshing,
    String? transientErrorMessage,
    bool clearTransientError = false,
  }) {
    return CustomersStatsLoaded(
      stats ?? this.stats,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      transientErrorMessage:
          clearTransientError
              ? null
              : (transientErrorMessage ?? this.transientErrorMessage),
    );
  }

  @override
  List<Object?> get props => [stats, isRefreshing, transientErrorMessage];
}

class CustomersStatsError extends CustomersStatsState {
  final String message;

  const CustomersStatsError(this.message);

  @override
  List<Object?> get props => [message];
}
