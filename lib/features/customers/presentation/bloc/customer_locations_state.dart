import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';

abstract class CustomerLocationsState extends Equatable {
  const CustomerLocationsState();

  @override
  List<Object?> get props => [];
}

class CustomerLocationsInitial extends CustomerLocationsState {}

class CustomerLocationsLoading extends CustomerLocationsState {}

class CustomerLocationsLoaded extends CustomerLocationsState {
  final List<CustomerLocationEntity> locations;

  const CustomerLocationsLoaded(this.locations);

  @override
  List<Object?> get props => [locations];
}

class CustomerLocationsError extends CustomerLocationsState {
  final String message;

  const CustomerLocationsError(this.message);

  @override
  List<Object?> get props => [message];
}
