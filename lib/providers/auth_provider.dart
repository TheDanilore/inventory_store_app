import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/constants/app_roles.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isLoginMode = true;

  bool get isLoading => _isLoading;
  bool get isLoginMode => _isLoginMode;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void toggleMode() {
    _isLoginMode = !_isLoginMode;
    _safeNotify();
  }

  void setLoading(bool val) {
    _isLoading = val;
    _safeNotify();
  }

  /// Autentica o registra al usuario devolviendo un mensaje de error si falla, o null si tiene éxito.
  Future<String?> authenticate({
    required String email,
    required String password,
    String? name, // Requerido si !_isLoginMode
  }) async {
    setLoading(true);
    try {
      if (_isLoginMode) {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        final response = await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name},
        );

        if (response.user != null) {
          try {
            await _supabase.from('profiles').upsert({
              'auth_user_id': response.user!.id,
              'full_name': name,
              'role': AppRoles.customer,
              'is_active': true,
            }, onConflict: 'auth_user_id');
          } catch (e) {
            debugPrint('Error creando perfil mínimo: $e');
          }
        }
      }
      return null;
    } on AuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'Error inesperado: $e';
    } finally {
      setLoading(false);
    }
  }

  /// Verifica si la sesión es válida y retorna la ruta a la cual navegar (ruta de Admin o Cliente), 
  /// o un mensaje de error si está inactivo.
  Future<Map<String, dynamic>> checkAndGetRedirectRoute() async {
    final session = _supabase.auth.currentSession;
    if (session == null) return {'success': false};

    setLoading(true);
    try {
      final data = await _supabase
          .from('profiles')
          .select('role, is_active')
          .eq('auth_user_id', session.user.id)
          .single();

      if (data['is_active'] == false) {
        await _supabase.auth.signOut();
        return {'success': false, 'error': 'Tu cuenta ha sido desactivada. Contacta al administrador.'};
      }

      final route = data['role'] == AppRoles.admin ? 'admin' : 'customer';
      return {'success': true, 'route': route};
    } catch (e) {
      await _supabase.auth.signOut();
      return {'success': false, 'error': 'Error al verificar el perfil. Intenta nuevamente.'};
    } finally {
      setLoading(false);
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    setLoading(true);
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'Error al enviar el correo de recuperación: $e';
    } finally {
      setLoading(false);
    }
  }

  String _authErrorMessage(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    final message = e.message.toLowerCase();
    if (code.contains('invalid_credentials') || message.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (code.contains('email_not_confirmed') || message.contains('email not confirmed')) {
      return 'Tu correo aún no está confirmado. Revisa tu bandeja.';
    }
    if (code.contains('user_already_exists') || message.contains('already registered')) {
      return 'Este correo ya está registrado.';
    }
    if (code.contains('weak_password') || message.contains('weak password')) {
      return 'Contraseña muy débil. Usa al menos 8 caracteres.';
    }
    if (code.contains('network') || message.contains('failed to fetch')) {
      return 'Sin conexión a internet. Intenta nuevamente.';
    }
    return 'No se pudo completar la autenticación. Intenta otra vez.';
  }
}
