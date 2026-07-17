import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.email,
    required super.fullName,
    required super.role,
    super.phone,
    required super.documentType,
    super.documentNumber,
    required super.isActive,
    super.createdAt,
    super.walletBalance,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String? ?? 'Desconocido',
      role: json['role'] as String? ?? 'customer',
      phone: json['phone'] as String?,
      documentType: json['document_type'] as String? ?? 'DNI',
      documentNumber: json['document_number'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      walletBalance: json['wallet_balance'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (email != null) 'email': email,
      'full_name': fullName,
      'role': role,
      if (phone != null) 'phone': phone,
      'document_type': documentType,
      if (documentNumber != null) 'document_number': documentNumber,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'wallet_balance': walletBalance,
    };
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      email: entity.email,
      fullName: entity.fullName,
      role: entity.role,
      phone: entity.phone,
      documentType: entity.documentType,
      documentNumber: entity.documentNumber,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      walletBalance: entity.walletBalance,
    );
  }
}
