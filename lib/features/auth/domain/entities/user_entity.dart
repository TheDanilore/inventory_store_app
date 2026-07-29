import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  /// `profiles.id` — UUID real del perfil. Se usa como FK en wishlist, shopping_carts, etc.
  final String id;

  /// `profiles.auth_user_id` — UUID de Supabase Auth. Se usa para updateProfile, Auth operations.
  final String authUserId;

  final String email;
  final String role;
  final String fullName;
  final String phone;
  final String documentType;
  final String documentNumber;
  final String? avatarUrl;
  final bool isActive;

  const UserEntity({
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

  @override
  List<Object?> get props => [
    id,
    authUserId,
    email,
    role,
    fullName,
    phone,
    documentType,
    documentNumber,
    avatarUrl,
    isActive,
  ];
}
