import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/customer_location.dart';

class CustomerLocationsProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<CustomerLocation> _locations = [];
  bool _isLoading = true;
  String? _profileId;
  String _errorMessage = '';
  final Map<String, bool> _processingItems = {};

  List<CustomerLocation> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get profileId => _profileId;
  String get errorMessage => _errorMessage;

  bool isItemProcessing(String id) => _processingItems[id] == true;

  Future<void> init() async {
    await loadLocations();
  }

  Future<void> loadLocations() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      if (_profileId == null) {
        final profile = await _supabase
            .from('profiles')
            .select('id')
            .eq('auth_user_id', user.id)
            .single();
        _profileId = profile['id']?.toString();
      }

      if (_profileId == null) throw Exception('No se encontró el perfil.');

      final response = await _supabase
          .from('customer_locations')
          .select(
            'id, profile_id, name, location_type, latitude, longitude, address_line, reference, notes, is_default, created_at',
          )
          .eq('profile_id', _profileId!)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      _locations =
          List<Map<String, dynamic>>.from(response)
              .map(CustomerLocation.fromMap)
              .toList();
      _errorMessage = '';
    } catch (e) {
      debugPrint('Error cargando ubicaciones: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'No se pudieron cargar las ubicaciones.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLocation(CustomerLocation loc) async {
    if (_profileId == null) throw Exception('Perfil no cargado.');

    _isLoading = true;
    notifyListeners();

    try {
      await _supabase.from('customer_locations').insert({
        'profile_id': _profileId,
        'name': loc.name,
        'location_type': loc.locationType,
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'address_line': loc.addressLine,
        'reference': loc.reference,
        'notes': loc.notes,
        'is_default': _locations.isEmpty ? true : loc.isDefault,
      });
      await loadLocations();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception('No se pudo guardar la ubicación: $e');
    }
  }

  Future<void> updateLocation(String id, CustomerLocation loc) async {
    if (_profileId == null) throw Exception('Perfil no cargado.');

    _setItemProcessing(id, true);
    try {
      await _supabase.from('customer_locations').update({
        'name': loc.name,
        'location_type': loc.locationType,
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'address_line': loc.addressLine,
        'reference': loc.reference,
        'notes': loc.notes,
        'is_default': loc.isDefault,
      }).eq('id', id);
      await loadLocations();
    } catch (e) {
      throw Exception('No se pudo actualizar la ubicación: $e');
    } finally {
      _setItemProcessing(id, false);
    }
  }

  Future<void> setDefaultLocation(String id) async {
    if (_profileId == null) return;

    _setItemProcessing(id, true);
    try {
      await _supabase
          .from('customer_locations')
          .update({'is_default': false})
          .eq('profile_id', _profileId!);

      await _supabase
          .from('customer_locations')
          .update({'is_default': true})
          .eq('id', id);

      await loadLocations();
    } catch (e) {
      throw Exception('No se pudo cambiar la ubicación principal: $e');
    } finally {
      _setItemProcessing(id, false);
    }
  }

  Future<void> deleteLocation(String id) async {
    _setItemProcessing(id, true);
    try {
      await _supabase.from('customer_locations').delete().eq('id', id);
      _locations.removeWhere((l) => l.id == id);
      notifyListeners();
    } catch (e) {
      throw Exception('No se pudo eliminar la ubicación: $e');
    } finally {
      _setItemProcessing(id, false);
    }
  }

  void _setItemProcessing(String id, bool isProcessing) {
    if (isProcessing) {
      _processingItems[id] = true;
    } else {
      _processingItems.remove(id);
    }
    notifyListeners();
  }
}
