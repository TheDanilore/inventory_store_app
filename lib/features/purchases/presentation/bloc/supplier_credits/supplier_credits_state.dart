import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

enum SupplierCreditsLoadStatus { initial, coldLoading, loaded, error }

enum SupplierCreditMutationStatus { idle, submitting, success, failure }

class SupplierCreditsState extends Equatable {
  static const int defaultPageSize = 15;

  final SupplierCreditsLoadStatus status;
  final List<SupplierCreditEntity> accounts;
  final SupplierCreditStatsEntity stats;
  final String searchQuery;
  final bool withDebtOnly;
  final int currentPage;
  final int pageSize;
  final int totalCount;
  final bool isRevalidating;
  final bool isFromCache;
  final Failure? loadFailure;
  final SupplierCreditMutationStatus mutationStatus;
  final String? mutationMessage;
  final Failure? mutationFailure;

  const SupplierCreditsState({
    this.status = SupplierCreditsLoadStatus.initial,
    this.accounts = const [],
    this.stats = const SupplierCreditStatsEntity.empty(),
    this.searchQuery = '',
    this.withDebtOnly = false,
    this.currentPage = 0,
    this.pageSize = defaultPageSize,
    this.totalCount = 0,
    this.isRevalidating = false,
    this.isFromCache = false,
    this.loadFailure,
    this.mutationStatus = SupplierCreditMutationStatus.idle,
    this.mutationMessage,
    this.mutationFailure,
  });

  int get totalPages => totalCount <= 0 ? 1 : (totalCount / pageSize).ceil();

  bool get isColdLoading =>
      (status == SupplierCreditsLoadStatus.coldLoading ||
          status == SupplierCreditsLoadStatus.initial) &&
      accounts.isEmpty;

  bool get hasData => accounts.isNotEmpty;

  SupplierCreditsState copyWith({
    SupplierCreditsLoadStatus? status,
    List<SupplierCreditEntity>? accounts,
    SupplierCreditStatsEntity? stats,
    String? searchQuery,
    bool? withDebtOnly,
    int? currentPage,
    int? pageSize,
    int? totalCount,
    bool? isRevalidating,
    bool? isFromCache,
    Failure? loadFailure,
    bool clearLoadFailure = false,
    SupplierCreditMutationStatus? mutationStatus,
    String? mutationMessage,
    bool clearMutationMessage = false,
    Failure? mutationFailure,
    bool clearMutationFailure = false,
  }) {
    return SupplierCreditsState(
      status: status ?? this.status,
      accounts: accounts ?? this.accounts,
      stats: stats ?? this.stats,
      searchQuery: searchQuery ?? this.searchQuery,
      withDebtOnly: withDebtOnly ?? this.withDebtOnly,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      isRevalidating: isRevalidating ?? this.isRevalidating,
      isFromCache: isFromCache ?? this.isFromCache,
      loadFailure: clearLoadFailure ? null : (loadFailure ?? this.loadFailure),
      mutationStatus: mutationStatus ?? this.mutationStatus,
      mutationMessage:
          clearMutationMessage
              ? null
              : (mutationMessage ?? this.mutationMessage),
      mutationFailure:
          clearMutationFailure
              ? null
              : (mutationFailure ?? this.mutationFailure),
    );
  }

  @override
  List<Object?> get props => [
    status,
    accounts,
    stats,
    searchQuery,
    withDebtOnly,
    currentPage,
    pageSize,
    totalCount,
    isRevalidating,
    isFromCache,
    loadFailure,
    mutationStatus,
    mutationMessage,
    mutationFailure,
  ];
}
