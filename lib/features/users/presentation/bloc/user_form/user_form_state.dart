import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';

abstract class UserFormState extends Equatable {
  final List<WarehouseEntity> warehouses;
  final bool isLoadingWarehouses;

  const UserFormState({
    this.warehouses = const [],
    this.isLoadingWarehouses = false,
  });

  @override
  List<Object?> get props => [warehouses, isLoadingWarehouses];
}

class UserFormInitial extends UserFormState {
  const UserFormInitial({
    super.warehouses = const [],
    super.isLoadingWarehouses = false,
  });
}

class UserFormLoading extends UserFormState {
  const UserFormLoading({
    super.warehouses = const [],
    super.isLoadingWarehouses = false,
  });
}

class UserFormSuccess extends UserFormState {
  final String message;

  const UserFormSuccess(
    this.message, {
    super.warehouses = const [],
    super.isLoadingWarehouses = false,
  });

  @override
  List<Object?> get props => [message, warehouses, isLoadingWarehouses];
}

class UserFormError extends UserFormState {
  final String message;

  const UserFormError(
    this.message, {
    super.warehouses = const [],
    super.isLoadingWarehouses = false,
  });

  @override
  List<Object?> get props => [message, warehouses, isLoadingWarehouses];
}
