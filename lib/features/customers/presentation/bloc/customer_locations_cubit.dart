import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_location_ucs.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_locations_state.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';

@injectable
class CustomerLocationsCubit extends Cubit<CustomerLocationsState> {
  final GetCustomerLocationsUseCase _getLocationsUseCase;
  final AddCustomerLocationUseCase _addLocationUseCase;
  final UpdateCustomerLocationUseCase _updateLocationUseCase;
  final DeleteCustomerLocationUseCase _deleteLocationUseCase;
  final SetDefaultCustomerLocationUseCase _setDefaultLocationUseCase;

  CustomerLocationsCubit(
    this._getLocationsUseCase,
    this._addLocationUseCase,
    this._updateLocationUseCase,
    this._deleteLocationUseCase,
    this._setDefaultLocationUseCase,
  ) : super(CustomerLocationsInitial());

  Future<void> loadLocations(String customerId) async {
    emit(CustomerLocationsLoading());
    try {
      if (customerId.isEmpty) {
        emit(const CustomerLocationsLoaded([]));
        return;
      }
      final locs = await _getLocationsUseCase(customerId);
      emit(CustomerLocationsLoaded(locs));
    } catch (e) {
      emit(CustomerLocationsError(e.toString()));
    }
  }

  Future<void> addLocation({
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
    try {
      await _addLocationUseCase(
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
      await loadLocations(customerId);
    } catch (e) {
      emit(CustomerLocationsError(e.toString()));
    }
  }

  Future<void> updateLocation(
    String customerId,
    String locationId,
    CustomerLocationEntity loc,
  ) async {
    try {
      await _updateLocationUseCase(
        locationId: locationId,
        name: loc.name,
        locationType: loc.locationType,
        latitude: loc.latitude,
        longitude: loc.longitude,
        addressLine: loc.addressLine,
        reference: loc.reference,
        notes: loc.notes,
        isDefault: loc.isDefault,
      );
      await loadLocations(customerId);
    } catch (e) {
      emit(CustomerLocationsError(e.toString()));
    }
  }

  Future<void> deleteLocation(String customerId, String locationId) async {
    try {
      await _deleteLocationUseCase(locationId);
      await loadLocations(customerId);
    } catch (e) {
      emit(CustomerLocationsError(e.toString()));
    }
  }

  Future<void> setAsDefault(String customerId, String locationId) async {
    try {
      await _setDefaultLocationUseCase(
        customerId: customerId,
        locationId: locationId,
      );
      await loadLocations(customerId);
    } catch (e) {
      emit(CustomerLocationsError(e.toString()));
    }
  }
}
