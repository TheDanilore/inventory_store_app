import 'package:equatable/equatable.dart';

class RoleEntity extends Equatable {
  final String id;
  final String name;
  final String? description;
  final DateTime? createdAt;

  const RoleEntity({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, description, createdAt];
}
