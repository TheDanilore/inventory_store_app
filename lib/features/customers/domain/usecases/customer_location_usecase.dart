import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customer_locations_repository.dart';

@lazySingleton
class GetCustomerLocationsUseCase {
  final CustomerLocationsRepository repository;

  GetCustomerLocationsUseCase(this.repository);

  Future<List<CustomerLocationEntity>> call(String customerId) {
    return repository.getCustomerLocations(customerId);
  }
}

@lazySingleton
class AddCustomerLocationUseCase {
  final CustomerLocationsRepository repository;

  AddCustomerLocationUseCase(this.repository);

  Future<CustomerLocationEntity> call({
    required String customerId,
    required String name,
    required String locationType,
    required double latitude,
    required double longitude,
    String? addressLine,
    String? reference,
    String? notes,
    bool isDefault = false,
  }) {
    return repository.addLocation(
      customerId: customerId,
      name: name,
      locationType: locationType,
      latitude: latitude,
      longitude: longitude,
      addressLine: addressLine,
      reference: reference,
      notes: notes,
      isDefault: isDefault,
    );
  }
}

@lazySingleton
class UpdateCustomerLocationUseCase {
  final CustomerLocationsRepository repository;

  UpdateCustomerLocationUseCase(this.repository);

  Future<CustomerLocationEntity> call({
    required String locationId,
    String? name,
    String? locationType,
    double? latitude,
    double? longitude,
    String? addressLine,
    String? reference,
    String? notes,
    bool? isDefault,
  }) {
    return repository.updateLocation(
      locationId: locationId,
      name: name,
      locationType: locationType,
      latitude: latitude,
      longitude: longitude,
      addressLine: addressLine,
      reference: reference,
      notes: notes,
      isDefault: isDefault,
    );
  }
}

@lazySingleton
class DeleteCustomerLocationUseCase {
  final CustomerLocationsRepository repository;

  DeleteCustomerLocationUseCase(this.repository);

  Future<void> call(String locationId) {
    return repository.deleteLocation(locationId);
  }
}

@lazySingleton
class SetDefaultCustomerLocationUseCase {
  final CustomerLocationsRepository repository;

  SetDefaultCustomerLocationUseCase(this.repository);

  Future<void> call({required String customerId, required String locationId}) {
    return repository.setLocationAsDefault(customerId, locationId);
  }
}
