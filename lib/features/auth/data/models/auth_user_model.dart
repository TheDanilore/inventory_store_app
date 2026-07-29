import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';

class AuthUserModel {
  /// `profiles.id` — UUID real del perfil (FK destino de wishlist, shopping_carts, etc.)
  final String id;

  /// `profiles.auth_user_id` — UUID de Supabase Auth (auth.users.id)
  final String authUserId;

  final String email;
  final String role;
  final String fullName;
  final String phone;
  final String documentType;
  final String documentNumber;
  final String? avatarUrl;
  final bool isActive;

  const AuthUserModel({
    required this.id,
    required this.authUserId,
    required this.email,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.documentType,
    required this.documentNumber,
    this.avatarUrl,
    required this.isActive,
  });

  factory AuthUserModel.fromMap(Map<String, dynamic> map, String email) {
    return AuthUserModel(
      // profiles.id (UUID real del perfil) — FK destino de wishlist, shopping_carts, etc.
      id: map['id']?.toString() ?? '',
      // profiles.auth_user_id — UUID del sistema Auth de Supabase
      authUserId: map['auth_user_id']?.toString() ?? '',
      email: email,
      role: map['role']?.toString() ?? 'customer',
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? 'DNI',
      documentNumber: map['document_number']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString(),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  factory AuthUserModel.fromEntity(UserEntity entity) {
    return AuthUserModel(
      id: entity.id,
      authUserId: entity.authUserId,
      email: entity.email,
      role: entity.role,
      fullName: entity.fullName,
      phone: entity.phone,
      documentType: entity.documentType,
      documentNumber: entity.documentNumber,
      avatarUrl: entity.avatarUrl,
      isActive: entity.isActive,
    );
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      authUserId: authUserId,
      email: email,
      role: role,
      fullName: fullName,
      phone: phone,
      documentType: documentType,
      documentNumber: documentNumber,
      avatarUrl: avatarUrl,
      isActive: isActive,
    );
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
      authUserId: authUserId,
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
