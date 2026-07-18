import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:inventory_store_app/features/auth/data/models/auth_user_model.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final sb.SupabaseClient _supabase;

  AuthRepositoryImpl(this._supabase);

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        return left(Failure.from('No hay sesión activa.'));
      }

      final data = await _supabase
          .from('profiles')
          .select('auth_user_id, role, is_active, full_name, phone, document_type, document_number, avatar_url')
          .eq('auth_user_id', session.user.id)
          .maybeSingle();

      if (data == null) {
        return left(Failure.from('Perfil no encontrado.'));
      }

      final model = AuthUserModel.fromMap(data, session.user.email ?? '');

      // Cache local de perfil: responsabilidad de infraestructura, pertenece aquí.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_cache_full_name_', model.fullName);
        if (model.avatarUrl != null) {
          await prefs.setString('profile_cache_avatar_url_', model.avatarUrl!);
        }
      } catch (_) {}

      return right(model.toEntity());
    } catch (e) {
      return left(Failure.from('Error al obtener usuario actual.'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth.signInWithPassword(email: email, password: password);
      
      if (res.user == null) {
         return left(Failure.from('Credenciales inválidas.'));
      }

      return getCurrentUser();
    } on sb.AuthException catch (e) {
      return left(Failure.from(_authErrorMessage(e)));
    } catch (e) {
      return left(Failure.from('Error inesperado al iniciar sesión.'));
    }
  }

  @override
  Future<Either<Failure, String>> register({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user != null) {
        return right(res.user!.id);
      }
      return left(Failure.from('Error al crear cuenta en el servidor de autenticación.'));
    } on sb.AuthException catch (e) {
      return left(Failure.from(_authErrorMessage(e)));
    } catch (e) {
      return left(Failure.from('Error inesperado al registrarse.'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> createProfile({
    required String authUserId,
    required String email,
    required String fullName,
    required String role,
    required bool isActive,
  }) async {
    try {
      await _supabase.from('profiles').upsert({
        'auth_user_id': authUserId,
        'full_name': fullName,
        'role': role,
        'is_active': isActive,
      }, onConflict: 'auth_user_id');
      
      final data = await _supabase
          .from('profiles')
          .select('auth_user_id, role, is_active, full_name, phone, document_type, document_number, avatar_url')
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      if (data == null) {
        return left(Failure.from('Perfil creado pero no pudo ser recuperado.'));
      }

      final model = AuthUserModel.fromMap(data, email);
      return right(model.toEntity());
    } catch (e) {
      return left(Failure.from('Error al crear perfil en base de datos.'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _supabase.auth.signOut();
      return right(null);
    } catch (e) {
      return left(Failure.from('Error al cerrar sesión.'));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return right(null);
    } on sb.AuthException catch (e) {
      return left(Failure.from(_authErrorMessage(e)));
    } catch (e) {
      return left(Failure.from('Error al enviar correo de recuperación.'));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(sb.UserAttributes(password: newPassword));
      return right(null);
    } catch (e) {
      return left(Failure.from('Error al cambiar contraseña.'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount(String password) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) return left(Failure.from('No hay sesión.'));

      final res = await _supabase.auth.signInWithPassword(email: user.email!, password: password);
      if (res.user == null) return left(Failure.from('Contraseña incorrecta.'));

      await _supabase.rpc('delete_user_account');
      await _supabase.auth.signOut();
      return right(null);
    } on sb.AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        return left(Failure.from('Contraseña incorrecta.'));
      }
      return left(Failure.from('Error de autenticación.'));
    } catch (e) {
      return left(Failure.from('Error al eliminar cuenta.'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    required UserEntity user,
    Uint8List? imageBytes,
  }) async {
    try {
      // Usamos el ID de la entidad de dominio recibida en lugar de consultar
      // el estado global de Supabase. El ID ya fue validado por el UseCase.
      final authUserId = user.id;

      String? finalAvatarUrl = user.avatarUrl;

      if (imageBytes != null) {
        final fileName = '${authUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('avatars').uploadBinary(
          fileName,
          imageBytes,
          fileOptions: const sb.FileOptions(contentType: 'image/jpeg', upsert: true),
        );
        finalAvatarUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);

        if (user.avatarUrl != null && user.avatarUrl!.contains('/public/avatars/')) {
          final oldPath = user.avatarUrl!.split('/public/avatars/').last;
          if (oldPath.isNotEmpty) {
            try {
              await _supabase.storage.from('avatars').remove([oldPath]);
            } catch (_) {}
          }
        }
      }

      await _supabase.from('profiles').update({
        'full_name': user.fullName.trim(),
        'phone': user.phone.trim(),
        'document_type': user.documentType,
        'document_number': user.documentNumber.trim(),
        if (finalAvatarUrl != null) 'avatar_url': finalAvatarUrl,
      }).eq('auth_user_id', authUserId);

      final updatedUser = AuthUserModel.fromEntity(user).copyWith(
        avatarUrl: finalAvatarUrl,
        fullName: user.fullName.trim(),
        phone: user.phone.trim(),
        documentNumber: user.documentNumber.trim(),
      );

      return right(updatedUser.toEntity());
    } catch (e) {
      return left(Failure.from('Error al actualizar el perfil.'));
    }
  }

  String _authErrorMessage(sb.AuthException e) {
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
    return 'Error de autenticación.';
  }
}

extension AuthUserModelCopyWith on AuthUserModel {
  AuthUserModel copyWith({
    String? avatarUrl,
    String? fullName,
    String? phone,
    String? documentNumber,
  }) {
    return AuthUserModel(
      id: id,
      email: email,
      role: role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      documentType: documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive,
    );
  }
}
