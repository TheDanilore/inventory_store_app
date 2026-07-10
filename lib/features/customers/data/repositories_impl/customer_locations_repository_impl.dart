import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/data/models/customer_location.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customer_locations_repository.dart';

@LazySingleton(as: CustomerLocationsRepository)
class CustomerLocationsRepositoryImpl implements CustomerLocationsRepository {
  final SupabaseClient _supabase;

  CustomerLocationsRepositoryImpl() : _supabase = Supabase.instance.client;

  @override
  Future<List<CustomerLocationEntity>> getCustomerLocations(String customerId) async {
    final response = await _supabase
        .from('customer_locations')
        .select()
        .eq('profile_id', customerId)
        .order('is_default', ascending: false);
        
    return (response as List)
        .map((e) => CustomerLocationModel.fromMap(e).toEntity())
        .toList();
  }

  @override
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
  }) async {
    if (isDefault) {
      await _supabase
          .from('customer_locations')
          .update({'is_default': false})
          .eq('profile_id', customerId);
    }
    
    final map = {
      'profile_id': customerId,
      'name': name,
      'location_type': locationType,
      'latitude': latitude,
      'longitude': longitude,
      'address_line': addressLine,
      'reference': reference,
      'notes': notes,
      'is_default': isDefault,
    };
    
    final response = await _supabase
        .from('customer_locations')
        .insert(map)
        .select()
        .single();
        
    return CustomerLocationModel.fromMap(response).toEntity();
  }

  @override
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
  }) async {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (locationType != null) map['location_type'] = locationType;
    if (latitude != null) map['latitude'] = latitude;
    if (longitude != null) map['longitude'] = longitude;
    if (addressLine != null) map['address_line'] = addressLine;
    if (reference != null) map['reference'] = reference;
    if (notes != null) map['notes'] = notes;
    
    if (isDefault != null) {
      map['is_default'] = isDefault;
      if (isDefault) {
        // Necesitamos el profileId
        final current = await _supabase
            .from('customer_locations')
            .select('profile_id')
            .eq('id', locationId)
            .single();
            
        await _supabase
            .from('customer_locations')
            .update({'is_default': false})
            .eq('profile_id', current['profile_id']);
      }
    }
    
    final response = await _supabase
        .from('customer_locations')
        .update(map)
        .eq('id', locationId)
        .select()
        .single();
        
    return CustomerLocationModel.fromMap(response).toEntity();
  }

  @override
  Future<void> deleteLocation(String locationId) async {
    await _supabase.from('customer_locations').delete().eq('id', locationId);
  }

  @override
  Future<void> setLocationAsDefault(String customerId, String locationId) async {
    await _supabase
        .from('customer_locations')
        .update({'is_default': false})
        .eq('profile_id', customerId);
        
    await _supabase
        .from('customer_locations')
        .update({'is_default': true})
        .eq('id', locationId);
  }
}

