import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';

class CustomerCreditListState extends Equatable {
  final bool isLoading;
  final String errorMessage;

  // Data
  final List<CustomerCreditEntity> accounts;
  final int totalAccounts;

  // Stats
  final double totalDebt;
  final int activeAccounts;
  final int suspendedAccounts;
  final int maxedOutAccounts;

  // Filters / Pagination
  final int currentPage;
  final String searchQuery;
  final bool withDebtOnly;
  final int pageSize;

  const CustomerCreditListState({
    this.isLoading = false,
    this.errorMessage = '',
    this.accounts = const [],
    this.totalAccounts = 0,
    this.totalDebt = 0.0,
    this.activeAccounts = 0,
    this.suspendedAccounts = 0,
    this.maxedOutAccounts = 0,
    this.currentPage = 1,
    this.searchQuery = '',
    this.withDebtOnly = false,
    this.pageSize = 8,
  });

  int get totalPages =>
      totalAccounts == 0 ? 1 : (totalAccounts / pageSize).ceil();

  CustomerCreditListState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<CustomerCreditEntity>? accounts,
    int? totalAccounts,
    double? totalDebt,
    int? activeAccounts,
    int? suspendedAccounts,
    int? maxedOutAccounts,
    int? currentPage,
    String? searchQuery,
    bool? withDebtOnly,
    int? pageSize,
  }) {
    return CustomerCreditListState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      accounts: accounts ?? this.accounts,
      totalAccounts: totalAccounts ?? this.totalAccounts,
      totalDebt: totalDebt ?? this.totalDebt,
      activeAccounts: activeAccounts ?? this.activeAccounts,
      suspendedAccounts: suspendedAccounts ?? this.suspendedAccounts,
      maxedOutAccounts: maxedOutAccounts ?? this.maxedOutAccounts,
      currentPage: currentPage ?? this.currentPage,
      searchQuery: searchQuery ?? this.searchQuery,
      withDebtOnly: withDebtOnly ?? this.withDebtOnly,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    errorMessage,
    accounts,
    totalAccounts,
    totalDebt,
    activeAccounts,
    suspendedAccounts,
    maxedOutAccounts,
    currentPage,
    searchQuery,
    withDebtOnly,
    pageSize,
  ];
}
