import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';

abstract class SuppliersState extends Equatable {
  const SuppliersState();

  @override
  List<Object?> get props => [];
}

class SuppliersInitial extends SuppliersState {}

class SuppliersLoading extends SuppliersState {
  final List<SupplierEntity> currentSuppliers;
  final String searchQuery;
  final int currentPage;
  final int totalCount;

  const SuppliersLoading({
    this.currentSuppliers = const [],
    this.searchQuery = '',
    this.currentPage = 0,
    this.totalCount = 0,
  });

  @override
  List<Object?> get props => [
    currentSuppliers,
    searchQuery,
    currentPage,
    totalCount,
  ];
}

class SuppliersLoaded extends SuppliersState {
  final List<SupplierEntity> suppliers;
  final String searchQuery;
  final int currentPage;
  final int totalCount;

  const SuppliersLoaded({
    required this.suppliers,
    required this.searchQuery,
    required this.currentPage,
    required this.totalCount,
  });

  int get totalPages => totalCount == 0 ? 1 : (totalCount / 8).ceil();

  SuppliersLoaded copyWith({
    List<SupplierEntity>? suppliers,
    String? searchQuery,
    int? currentPage,
    int? totalCount,
  }) {
    return SuppliersLoaded(
      suppliers: suppliers ?? this.suppliers,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  @override
  List<Object?> get props => [suppliers, searchQuery, currentPage, totalCount];
}

class SuppliersError extends SuppliersState {
  final String message;
  final List<SupplierEntity> currentSuppliers;
  final String searchQuery;
  final int currentPage;
  final int totalCount;

  const SuppliersError({
    required this.message,
    this.currentSuppliers = const [],
    this.searchQuery = '',
    this.currentPage = 0,
    this.totalCount = 0,
  });

  @override
  List<Object?> get props => [
    message,
    currentSuppliers,
    searchQuery,
    currentPage,
    totalCount,
  ];
}
