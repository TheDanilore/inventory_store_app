import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';

enum CustomerCreditsLoadStatus {
  initial,
  loadingCold,
  loaded,
  errorCold,
  errorDegraded,
}

class CustomerCreditListState extends Equatable {
  final CustomerCreditsLoadStatus status;
  final bool isLoading;
  final bool isRevalidating;
  final bool isMutating;
  final String errorMessage;
  final Failure? loadFailure;
  final String? transientErrorMessage;

  // Data
  final List<CustomerCreditEntity> accounts;
  final int totalAccounts;

  // Global KPI Stats
  final double totalDebt;
  final int activeAccounts;
  final int suspendedAccounts;
  final int maxedOutAccounts;
  final int debtCount;

  // Filters / Pagination
  final int currentPage;
  final String searchQuery;
  final bool withDebtOnly;
  final int pageSize;

  const CustomerCreditListState({
    this.status = CustomerCreditsLoadStatus.initial,
    this.isLoading = false,
    this.isRevalidating = false,
    this.isMutating = false,
    this.errorMessage = '',
    this.loadFailure,
    this.transientErrorMessage,
    this.accounts = const [],
    this.totalAccounts = 0,
    this.totalDebt = 0.0,
    this.activeAccounts = 0,
    this.suspendedAccounts = 0,
    this.maxedOutAccounts = 0,
    this.debtCount = 0,
    this.currentPage = 1,
    this.searchQuery = '',
    this.withDebtOnly = false,
    this.pageSize = 15,
  });

  bool get hasData => accounts.isNotEmpty;
  bool get isColdLoading =>
      status == CustomerCreditsLoadStatus.loadingCold && accounts.isEmpty;

  int get totalPages =>
      totalAccounts == 0 ? 1 : (totalAccounts / pageSize).ceil();

  CustomerCreditListState copyWith({
    CustomerCreditsLoadStatus? status,
    bool? isLoading,
    bool? isRevalidating,
    bool? isMutating,
    String? errorMessage,
    Failure? loadFailure,
    bool clearLoadFailure = false,
    String? transientErrorMessage,
    bool clearTransientError = false,
    List<CustomerCreditEntity>? accounts,
    int? totalAccounts,
    double? totalDebt,
    int? activeAccounts,
    int? suspendedAccounts,
    int? maxedOutAccounts,
    int? debtCount,
    int? currentPage,
    String? searchQuery,
    bool? withDebtOnly,
    int? pageSize,
  }) {
    return CustomerCreditListState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      isRevalidating: isRevalidating ?? this.isRevalidating,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: errorMessage ?? this.errorMessage,
      loadFailure:
          clearLoadFailure ? null : (loadFailure ?? this.loadFailure),
      transientErrorMessage:
          clearTransientError
              ? null
              : (transientErrorMessage ?? this.transientErrorMessage),
      accounts: accounts ?? this.accounts,
      totalAccounts: totalAccounts ?? this.totalAccounts,
      totalDebt: totalDebt ?? this.totalDebt,
      activeAccounts: activeAccounts ?? this.activeAccounts,
      suspendedAccounts: suspendedAccounts ?? this.suspendedAccounts,
      maxedOutAccounts: maxedOutAccounts ?? this.maxedOutAccounts,
      debtCount: debtCount ?? this.debtCount,
      currentPage: currentPage ?? this.currentPage,
      searchQuery: searchQuery ?? this.searchQuery,
      withDebtOnly: withDebtOnly ?? this.withDebtOnly,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  List<Object?> get props => [
    status,
    isLoading,
    isRevalidating,
    isMutating,
    errorMessage,
    loadFailure,
    transientErrorMessage,
    accounts,
    totalAccounts,
    totalDebt,
    activeAccounts,
    suspendedAccounts,
    maxedOutAccounts,
    debtCount,
    currentPage,
    searchQuery,
    withDebtOnly,
    pageSize,
  ];
}
