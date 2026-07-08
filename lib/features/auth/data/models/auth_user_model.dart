import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';

class AuthUserModel {
  final String id;
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
      id: map['auth_user_id']?.toString() ?? '',
      email: email,
      role: map['role']?.toString() ?? 'Cliente',
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
