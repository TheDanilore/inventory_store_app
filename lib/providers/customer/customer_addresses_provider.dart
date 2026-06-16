import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/profile_address_entry.dart';

class CustomerAddressesProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<ProfileAddressEntry> _addresses = [];
  bool _isLoading = true;
  String? _profileId;
  String _errorMessage = '';

  final Map<String, bool> _processingItems = {};

  List<ProfileAddressEntry> get addresses => _addresses;
  bool get isLoading => _isLoading;
  String? get profileId => _profileId;
  String get errorMessage => _errorMessage;

  bool isItemProcessing(String addressId) =>
      _processingItems[addressId] == true;

  Future<void> init() async {
    await loadAddresses();
  }

  Future<void> loadAddresses() async {
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
        final profile =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', user.id)
                .single();
        _profileId = profile['id']?.toString();
      }

      if (_profileId == null) throw Exception('No se encontró el perfil.');

      final response = await _supabase
          .from('user_addresses')
          .select(
            'id, department, province, district, reference, is_default, created_at',
          )
          .eq('profile_id', _profileId!)
          .order('is_default', ascending: false)
          .order('created_at', ascending: true);

      _addresses =
          List<Map<String, dynamic>>.from(
            response,
          ).map(_toAddressEntry).toList();
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'No se pudieron cargar las direcciones: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveAddress({
    Map<String, dynamic>? existingAddress,
    required Map<String, String?> parsedResult,
  }) async {
    if (_profileId == null) throw Exception('Perfil no cargado.');

    _isLoading = true;
    notifyListeners();

    try {
      if (existingAddress != null) {
        await _supabase
            .from('user_addresses')
            .update({
              'department': parsedResult['department'],
              'province': parsedResult['province'],
              'district': parsedResult['district'],
              'reference': parsedResult['reference'],
              'address_line': parsedResult['address_line'],
            })
            .eq('id', existingAddress['id']);
      } else {
        await _supabase.from('user_addresses').insert({
          'profile_id': _profileId,
          'department': parsedResult['department'],
          'province': parsedResult['province'],
          'district': parsedResult['district'],
          'reference': parsedResult['reference'],
          'address_line': parsedResult['address_line'],
          'is_default': _addresses.isEmpty,
        });
      }
      await loadAddresses();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception('No se pudo guardar la dirección: $e');
    }
  }

  Future<void> setDefaultAddress(String addressId) async {
    if (_profileId == null) return;

    _setItemProcessing(addressId, true);
    try {
      // Optimizamos esto con RPC o transacciones en el futuro, pero por ahora lo hacemos en dos pasos
      await _supabase
          .from('user_addresses')
          .update({'is_default': false})
          .eq('profile_id', _profileId!);

      await _supabase
          .from('user_addresses')
          .update({'is_default': true})
          .eq('id', addressId);

      // Recargar direcciones para mantener el orden (la predeterminada va primero)
      await loadAddresses();
    } catch (e) {
      throw Exception('No se pudo cambiar la dirección principal: $e');
    } finally {
      _setItemProcessing(addressId, false);
    }
  }

  Future<void> deleteAddress(String addressId) async {
    _setItemProcessing(addressId, true);
    try {
      await _supabase.from('user_addresses').delete().eq('id', addressId);
      _addresses.removeWhere((a) => a.id == addressId);
      // Si borramos la principal, tal vez deberíamos asignar otra como principal,
      // pero por ahora mantenemos el comportamiento original.
      notifyListeners();
    } catch (e) {
      throw Exception('No se pudo eliminar la dirección: $e');
    } finally {
      _setItemProcessing(addressId, false);
    }
  }

  void _setItemProcessing(String addressId, bool isProcessing) {
    if (isProcessing) {
      _processingItems[addressId] = true;
    } else {
      _processingItems.remove(addressId);
    }
    notifyListeners();
  }

  String _buildAddressLine(Map<String, dynamic> address) {
    final department = (address['department'] ?? '').toString().trim();
    final province = (address['province'] ?? '').toString().trim();
    final district = (address['district'] ?? '').toString().trim();
    final reference = (address['reference'] ?? '').toString().trim();
    final location = '$department / $province / $district';
    return reference.isEmpty ? location : '$location - Ref: $reference';
  }

  ProfileAddressEntry _toAddressEntry(Map<String, dynamic> address) {
    return ProfileAddressEntry(
      id: address['id'].toString(),
      addressLine: _buildAddressLine(address),
      reference:
          (address['reference'] ?? '').toString().trim().isEmpty
              ? null
              : (address['reference'] ?? '').toString().trim(),
      department: (address['department'] ?? '').toString().trim(),
      province: (address['province'] ?? '').toString().trim(),
      district: (address['district'] ?? '').toString().trim(),
      isDefault: address['is_default'] == true,
    );
  }
}
