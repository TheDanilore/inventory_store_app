import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';

abstract class CustomerCreditListState extends Equatable {
  const CustomerCreditListState();

  @override
  List<Object?> get props => [];
}

class CustomerCreditListInitial extends CustomerCreditListState {}

class CustomerCreditListLoading extends CustomerCreditListState {}

class CustomerCreditListLoaded extends CustomerCreditListState {
  final List<CustomerCreditEntity> accounts;
  final int currentPage;
  final int totalPages;
  final String? query;
  final bool showOnlyWithDebt;

  const CustomerCreditListLoaded({
    required this.accounts,
    this.currentPage = 1,
    this.totalPages = 1,
    this.query,
    this.showOnlyWithDebt = false,
  });

  CustomerCreditListLoaded copyWith({
    List<CustomerCreditEntity>? accounts,
    int? currentPage,
    int? totalPages,
    String? query,
    bool? showOnlyWithDebt,
  }) {
    return CustomerCreditListLoaded(
      accounts: accounts ?? this.accounts,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      query: query ?? this.query,
      showOnlyWithDebt: showOnlyWithDebt ?? this.showOnlyWithDebt,
    );
  }

  @override
  List<Object?> get props => [
        accounts,
        currentPage,
        totalPages,
        query,
        showOnlyWithDebt,
      ];
}

class CustomerCreditListError extends CustomerCreditListState {
  final String message;

  const CustomerCreditListError(this.message);

  @override
  List<Object?> get props => [message];
}
