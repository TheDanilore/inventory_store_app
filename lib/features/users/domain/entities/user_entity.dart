import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String? email;
  final String fullName;
  final String role;
  final String? phone;
  final String documentType;
  final String? documentNumber;
  final bool isActive;
  final DateTime? createdAt;
  final int walletBalance;

  const UserEntity({
    required this.id,
    this.email,
    required this.fullName,
    required this.role,
    this.phone,
    required this.documentType,
    this.documentNumber,
    required this.isActive,
    this.createdAt,
    this.walletBalance = 0,
  });

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    role,
    phone,
    documentType,
    documentNumber,
    isActive,
    createdAt,
    walletBalance,
  ];

  UserEntity copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? phone,
    String? documentType,
    String? documentNumber,
    bool? isActive,
    DateTime? createdAt,
    int? walletBalance,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }
}
