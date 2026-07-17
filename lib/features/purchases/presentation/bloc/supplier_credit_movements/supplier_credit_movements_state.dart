import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_movement_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credit_movements_repository.dart';

abstract class SupplierCreditMovementsState extends Equatable {
  const SupplierCreditMovementsState();

  @override
  List<Object?> get props => [];
}

class SupplierCreditMovementsInitial extends SupplierCreditMovementsState {}

class SupplierCreditMovementsLoading extends SupplierCreditMovementsState {
  final List<SupplierCreditMovementEntity> currentMovements;
  final MovementDateFilter dateFilter;
  final int currentPage;
  final int totalCount;
  final double totalCharged;
  final double totalPaid;
  final bool isExporting;

  const SupplierCreditMovementsLoading({
    this.currentMovements = const [],
    this.dateFilter = MovementDateFilter.allTime,
    this.currentPage = 0,
    this.totalCount = 0,
    this.totalCharged = 0.0,
    this.totalPaid = 0.0,
    this.isExporting = false,
  });

  @override
  List<Object?> get props => [
        currentMovements,
        dateFilter,
        currentPage,
        totalCount,
        totalCharged,
        totalPaid,
        isExporting,
      ];
}

class SupplierCreditMovementsLoaded extends SupplierCreditMovementsState {
  final List<SupplierCreditMovementEntity> movements;
  final MovementDateFilter dateFilter;
  final int currentPage;
  final int totalCount;
  final double totalCharged;
  final double totalPaid;
  final bool isExporting;

  const SupplierCreditMovementsLoaded({
    required this.movements,
    required this.dateFilter,
    required this.currentPage,
    required this.totalCount,
    required this.totalCharged,
    required this.totalPaid,
    this.isExporting = false,
  });

  int get totalPages => totalCount == 0 ? 1 : (totalCount / 8).ceil();

  SupplierCreditMovementsLoaded copyWith({
    List<SupplierCreditMovementEntity>? movements,
    MovementDateFilter? dateFilter,
    int? currentPage,
    int? totalCount,
    double? totalCharged,
    double? totalPaid,
    bool? isExporting,
  }) {
    return SupplierCreditMovementsLoaded(
      movements: movements ?? this.movements,
      dateFilter: dateFilter ?? this.dateFilter,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      totalCharged: totalCharged ?? this.totalCharged,
      totalPaid: totalPaid ?? this.totalPaid,
      isExporting: isExporting ?? this.isExporting,
    );
  }

  @override
  List<Object?> get props => [
        movements,
        dateFilter,
        currentPage,
        totalCount,
        totalCharged,
        totalPaid,
        isExporting,
      ];
}

class SupplierCreditMovementsError extends SupplierCreditMovementsState {
  final String message;
  final List<SupplierCreditMovementEntity> currentMovements;
  final MovementDateFilter dateFilter;
  final int currentPage;
  final int totalCount;
  final double totalCharged;
  final double totalPaid;

  const SupplierCreditMovementsError({
    required this.message,
    this.currentMovements = const [],
    this.dateFilter = MovementDateFilter.allTime,
    this.currentPage = 0,
    this.totalCount = 0,
    this.totalCharged = 0.0,
    this.totalPaid = 0.0,
  });

  @override
  List<Object?> get props => [
        message,
        currentMovements,
        dateFilter,
        currentPage,
        totalCount,
        totalCharged,
        totalPaid,
      ];
}
