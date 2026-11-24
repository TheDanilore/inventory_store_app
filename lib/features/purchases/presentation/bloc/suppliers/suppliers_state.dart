import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';

enum SuppliersLoadStatus { initial, coldLoading, loaded, error }

enum SupplierMutationStatus { idle, submitting, success, failure }

enum SupplierMutationKind { none, save, toggle, bulkToggle }

class SuppliersState extends Equatable {
  static const int defaultPageSize = 15;

  final SuppliersLoadStatus status;
  final List<SupplierEntity> suppliers;
  final SupplierStatsEntity stats;
  final String searchQuery;
  final bool? filterIsActive;
  final int currentPage;
  final int pageSize;
  final int totalCount;
  final bool isRevalidating;
  final bool isFromCache;
  final Failure? loadFailure;

  final SupplierMutationStatus mutationStatus;
  final SupplierMutationKind mutationKind;
  final String? mutationMessage;
  final Failure? mutationFailure;

  const SuppliersState({
    this.status = SuppliersLoadStatus.initial,
    this.suppliers = const [],
    this.stats = const SupplierStatsEntity.empty(),
    this.searchQuery = '',
    this.filterIsActive,
    this.currentPage = 0,
    this.pageSize = defaultPageSize,
    this.totalCount = 0,
    this.isRevalidating = false,
    this.isFromCache = false,
    this.loadFailure,
    this.mutationStatus = SupplierMutationStatus.idle,
    this.mutationKind = SupplierMutationKind.none,
    this.mutationMessage,
    this.mutationFailure,
  });

  int get totalPages => totalCount <= 0 ? 1 : (totalCount / pageSize).ceil();

  bool get isColdLoading =>
      (status == SuppliersLoadStatus.coldLoading ||
          status == SuppliersLoadStatus.initial) &&
      suppliers.isEmpty;

  bool get hasData => suppliers.isNotEmpty;

  SuppliersState copyWith({
    SuppliersLoadStatus? status,
    List<SupplierEntity>? suppliers,
    SupplierStatsEntity? stats,
    String? searchQuery,
    bool? filterIsActive,
    bool clearFilterIsActive = false,
    int? currentPage,
    int? pageSize,
    int? totalCount,
    bool? isRevalidating,
    bool? isFromCache,
    Failure? loadFailure,
    bool clearLoadFailure = false,
    SupplierMutationStatus? mutationStatus,
    SupplierMutationKind? mutationKind,
    String? mutationMessage,
    bool clearMutationMessage = false,
    Failure? mutationFailure,
    bool clearMutationFailure = false,
  }) {
    return SuppliersState(
      status: status ?? this.status,
      suppliers: suppliers ?? this.suppliers,
      stats: stats ?? this.stats,
      searchQuery: searchQuery ?? this.searchQuery,
      filterIsActive:
          clearFilterIsActive ? null : (filterIsActive ?? this.filterIsActive),
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      isRevalidating: isRevalidating ?? this.isRevalidating,
      isFromCache: isFromCache ?? this.isFromCache,
      loadFailure: clearLoadFailure ? null : (loadFailure ?? this.loadFailure),
      mutationStatus: mutationStatus ?? this.mutationStatus,
      mutationKind: mutationKind ?? this.mutationKind,
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
    suppliers,
    stats,
    searchQuery,
    filterIsActive,
    currentPage,
    pageSize,
    totalCount,
    isRevalidating,
    isFromCache,
    loadFailure,
    mutationStatus,
    mutationKind,
    mutationMessage,
    mutationFailure,
  ];
}
