import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';

abstract class CustomerLocationsRepository {
  Future<List<CustomerLocationEntity>> getCustomerLocations(String customerId);

  Future<CustomerLocationEntity> addLocation({
    required String customerId,
    required String name,
    required String locationType,
    required double latitude,
    required double longitude,
    String? addressLine,
    String? reference,
    String? notes,
    bool isDefault = false,
  });

  Future<CustomerLocationEntity> updateLocation({
    required String locationId,
    String? name,
    String? locationType,
    double? latitude,
    double? longitude,
    String? addressLine,
    String? reference,
    String? notes,
    bool? isDefault,
  });

  Future<void> deleteLocation(String locationId);
  Future<void> setLocationAsDefault(String customerId, String locationId);
}

