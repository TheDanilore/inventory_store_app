import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/constants/app_roles.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isLoginMode = true;

  bool get isLoading => _isLoading;
  bool get isLoginMode => _isLoginMode;

  bool _isSessionReady = false;
  String? _currentUserRole;

  bool get isSessionReady => _isSessionReady;
  String? get currentUserRole => _currentUserRole;
  User? get currentUser => _supabase.auth.currentUser;

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
      
      // Obtener rol y notificar para que GoRouter redirija
      final role = await checkAndGetRole();
      
      if (role == null) {
        return 'Error al obtener la información de la cuenta.';
      }

      await initializeSession(role);
      
      return null;
    } on AuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      debugPrint('Error auth: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('inactive_user')) {
        return 'Tu cuenta está inactiva o bloqueada. Contacta a soporte.';
      }
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        return 'Sin conexión a internet.';
      }
      return 'Error inesperado al iniciar sesión.';
    } finally {
      setLoading(false);
    }
  }

  /// Inicia la verificación de sesión y rol de usuario.
  /// Usado desde el SplashScreen.
  Future<void> initializeSession(String? role) async {
    _currentUserRole = role;
    _isSessionReady = true;
    _safeNotify();
  }

  /// Limpia la sesión local al cerrar sesión.
  void clearSession() {
    _currentUserRole = null;
    _safeNotify();
  }

  /// Verifica si la sesión es válida (usado post-login para obtener el rol).
  Future<String?> checkAndGetRole() async {
    final session = _supabase.auth.currentSession;
    if (session == null) return null;

    setLoading(true);
    try {
      final data = await _supabase
          .from('profiles')
          .select('role, is_active')
          .eq('auth_user_id', session.user.id)
          .single();

      if (data['is_active'] == false) {
        await _supabase.auth.signOut();
        throw Exception('inactive_user');
      }

      return data['role'] as String?;
    } catch (e) {
      if (e.toString().contains('inactive_user')) {
        rethrow;
      }
      await _supabase.auth.signOut();
      return null;
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
      debugPrint('Error recovery: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        return 'Sin conexión a internet.';
      }
      return 'Error al enviar el correo de recuperación.';
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
