import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

abstract class SupplierCreditsState extends Equatable {
  const SupplierCreditsState();

  @override
  List<Object?> get props => [];
}

class SupplierCreditsInitial extends SupplierCreditsState {}

class SupplierCreditsLoading extends SupplierCreditsState {
  final List<SupplierCreditEntity> currentAccounts;
  final String searchQuery;
  final bool withDebtOnly;
  final int currentPage;
  final int totalCount;
  final Map<String, dynamic> stats;

  const SupplierCreditsLoading({
    this.currentAccounts = const [],
    this.searchQuery = '',
    this.withDebtOnly = false,
    this.currentPage = 0,
    this.totalCount = 0,
    this.stats = const {},
  });

  @override
  List<Object?> get props => [
    currentAccounts,
    searchQuery,
    withDebtOnly,
    currentPage,
    totalCount,
    stats,
  ];
}

class SupplierCreditsLoaded extends SupplierCreditsState {
  final List<SupplierCreditEntity> accounts;
  final String searchQuery;
  final bool withDebtOnly;
  final int currentPage;
  final int totalCount;
  final Map<String, dynamic> stats;

  const SupplierCreditsLoaded({
    required this.accounts,
    required this.searchQuery,
    required this.withDebtOnly,
    required this.currentPage,
    required this.totalCount,
    required this.stats,
  });

  int get totalPages => totalCount == 0 ? 1 : (totalCount / 8).ceil();

  SupplierCreditsLoaded copyWith({
    List<SupplierCreditEntity>? accounts,
    String? searchQuery,
    bool? withDebtOnly,
    int? currentPage,
    int? totalCount,
    Map<String, dynamic>? stats,
  }) {
    return SupplierCreditsLoaded(
      accounts: accounts ?? this.accounts,
      searchQuery: searchQuery ?? this.searchQuery,
      withDebtOnly: withDebtOnly ?? this.withDebtOnly,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      stats: stats ?? this.stats,
    );
  }

  @override
  List<Object?> get props => [
    accounts,
    searchQuery,
    withDebtOnly,
    currentPage,
    totalCount,
    stats,
  ];
}

class SupplierCreditsError extends SupplierCreditsState {
  final String message;
  final List<SupplierCreditEntity> currentAccounts;
  final String searchQuery;
  final bool withDebtOnly;
  final int currentPage;
  final int totalCount;
  final Map<String, dynamic> stats;

  const SupplierCreditsError({
    required this.message,
    this.currentAccounts = const [],
    this.searchQuery = '',
    this.withDebtOnly = false,
    this.currentPage = 0,
    this.totalCount = 0,
    this.stats = const {},
  });

  @override
  List<Object?> get props => [
    message,
    currentAccounts,
    searchQuery,
    withDebtOnly,
    currentPage,
    totalCount,
    stats,
  ];
}
