import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:inventory_store_app/shared/constants/app_roles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  ProfileProvider() {
    _loadCache();
    _init();
  }

  Future<void> _loadCache() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedName = prefs.getString(
          'profile_cache_full_name_${user.id}',
        );
        if (cachedName != null && cachedName.isNotEmpty) {
          _fullName = cachedName;
          _avatarUrl = prefs.getString('profile_cache_avatar_url_${user.id}');
          _safeNotify();
        }
      } catch (_) {}
    }
  }

  void _init() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        if (_supabase.auth.currentUser != null) {
          fetchUserProfile();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _profileId = null;
        _userRole = 'Cargando...';
        _fullName = '';
        _phone = '';
        _documentNumber = '';
        _avatarUrl = null;
        _imageBytes = null;
        _isLoading = false;
        _safeNotify();
      }
    });
  }

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUpdatingPassword = false;
  bool _isDeletingAccount = false;

  String _userRole = 'Cargando...';
  String? _profileId;
  String _fullName = '';
  String _phone = '';
  String _documentType = 'DNI';
  String _documentNumber = '';
  String? _avatarUrl;
  Uint8List? _imageBytes;

  bool _disposed = false;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isUpdatingPassword => _isUpdatingPassword;
  bool get isDeletingAccount => _isDeletingAccount;

  String get userRole => _userRole;
  String? get profileId => _profileId;
  String get fullName => _fullName;
  String get phone => _phone;
  String get documentType => _documentType;
  String get documentNumber => _documentNumber;
  String? get avatarUrl => _avatarUrl;
  Uint8List? get imageBytes => _imageBytes;

  void setImageBytes(Uint8List? bytes) {
    _imageBytes = bytes;
    _safeNotify();
  }

  void setAvatarUrl(String? url) {
    _avatarUrl = url;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> fetchUserProfile() async {
    _isLoading = true;
    _safeNotify();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data =
            await _supabase
                .from('profiles')
                .select(
                  'id, role, full_name, phone, document_type, document_number, avatar_url',
                )
                .eq('auth_user_id', user.id)
                .maybeSingle();

        if (data != null) {
          _profileId = data['id']?.toString();
          _userRole =
              data['role'] == AppRoles.admin ? 'Administrador' : 'Cliente';
          _fullName = data['full_name'] ?? '';
          _phone = data['phone'] ?? '';
          _documentNumber = data['document_number'] ?? '';
          _avatarUrl = data['avatar_url'];
          _documentType =
              ['DNI', 'RUC', 'CE', 'PASAPORTE'].contains(data['document_type'])
                  ? data['document_type']
                  : 'DNI';

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'profile_cache_full_name_${user.id}',
              _fullName,
            );
            if (_avatarUrl != null) {
              await prefs.setString(
                'profile_cache_avatar_url_${user.id}',
                _avatarUrl!,
              );
            } else {
              await prefs.remove('profile_cache_avatar_url_${user.id}');
            }
          } catch (_) {}
        } else {
          _userRole = 'Cliente';
        }
      } catch (e) {
        debugPrint('Error fetching user profile: $e');
        _userRole = 'Cliente';
      }
    }

    _isLoading = false;
    _safeNotify();
  }

  Future<bool> saveProfile({
    required String fullName,
    required String phone,
    required String docType,
    required String docNum,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    _isSaving = true;
    _safeNotify();

    try {
      String? finalAvatarUrl = _avatarUrl;
      String? oldAvatarUrl;

      if (_imageBytes != null) {
        oldAvatarUrl = _avatarUrl;
        final fileName =
            '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await _supabase.storage
            .from('avatars')
            .uploadBinary(
              fileName,
              _imageBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        finalAvatarUrl = _supabase.storage
            .from('avatars')
            .getPublicUrl(fileName);
      }

      await _supabase
          .from('profiles')
          .update({
            'full_name': fullName.trim(),
            'phone': phone.trim(),
            'document_type': docType,
            'document_number': docNum.trim(),
            if (finalAvatarUrl != null) 'avatar_url': finalAvatarUrl,
          })
          .eq('auth_user_id', user.id);

      // Borrar foto vieja
      if (_imageBytes != null &&
          oldAvatarUrl != null &&
          oldAvatarUrl.contains('/public/avatars/')) {
        final oldPath = oldAvatarUrl.split('/public/avatars/').last;
        if (oldPath.isNotEmpty) {
          try {
            await _supabase.storage.from('avatars').remove([oldPath]);
          } catch (e) {
            debugPrint('Error deleting old avatar: $e');
          }
        }
      }

      // Actualizar estado local
      _fullName = fullName.trim();
      _phone = phone.trim();
      _documentType = docType;
      _documentNumber = docNum.trim();
      _avatarUrl = finalAvatarUrl;
      _imageBytes = null; // Limpiar

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_cache_full_name_${user.id}', _fullName);
        if (_avatarUrl != null) {
          await prefs.setString(
            'profile_cache_avatar_url_${user.id}',
            _avatarUrl!,
          );
        } else {
          await prefs.remove('profile_cache_avatar_url_${user.id}');
        }
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error saving profile: $e');
      return false;
    } finally {
      _isSaving = false;
      _safeNotify();
    }
  }

  Future<bool> changePassword(String newPassword) async {
    _isUpdatingPassword = true;
    _safeNotify();

    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } catch (e) {
      debugPrint('Error changing password: $e');
      return false;
    } finally {
      _isUpdatingPassword = false;
      _safeNotify();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _safeNotify();
    try {
      await _supabase.auth.signOut();
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<Uint8List> optimizeImage(Uint8List bytesOriginales) async {
    if (bytesOriginales.lengthInBytes < 250 * 1024) {
      return bytesOriginales;
    }

    try {
      final bytesComprimidos = await FlutterImageCompress.compressWithList(
        bytesOriginales,
        minWidth: 1024,
        minHeight: 1024,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      if (bytesComprimidos.isNotEmpty &&
          bytesComprimidos.lengthInBytes < bytesOriginales.lengthInBytes) {
        return bytesComprimidos;
      }
    } catch (e) {
      debugPrint('Error compressing image: $e');
    }

    return bytesOriginales;
  }

  // Add delete account method (requires API call or Edge Function to bypass RLS)
  // Or if RLS allows self-deletion from profiles, we can do that, but to delete the actual
  // auth.users row, it requires a backend function (Supabase Edge Function or custom Postgres function).
  // I will implement a Postgres RPC call 'delete_user_account' assuming it exists or could be created,
  // or I can call an Edge Function. For now, calling RPC `delete_user_account`.
  Future<String?> deleteAccount(String password) async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.email == null) {
      return 'No hay usuario autenticado.';
    }

    _isDeletingAccount = true;
    _safeNotify();

    try {
      // 1. Re-autenticar con la contraseña proporcionada (Seguridad)
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: password,
      );

      if (res.user == null) {
        return 'Contraseña incorrecta.';
      }

      // 2. Ejecutar RPC que borra el auth.users internamente
      // Nota: Esta RPC debe ser creada en Supabase (ej. SECURITY DEFINER)
      await _supabase.rpc('delete_user_account');

      // 3. Cerrar sesión
      await _supabase.auth.signOut();
      return null; // Éxito
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        return 'Contraseña incorrecta.';
      }
      return 'Error de autenticación: ${e.message}';
    } catch (e) {
      debugPrint('Error deleting account: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        return 'Sin conexión a internet.';
      }
      return 'Ocurrió un error inesperado al eliminar la cuenta.';
    } finally {
      _isDeletingAccount = false;
      _safeNotify();
    }
  }
}
