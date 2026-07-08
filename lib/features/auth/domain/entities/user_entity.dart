import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
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
