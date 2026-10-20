import 'package:equatable/equatable.dart';

class PermissionEntity extends Equatable {
  final String id;
  final String code;
  final String name;
  final String module;

  const PermissionEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.module,
  });

  @override
  List<Object?> get props => [id, code, name, module];
}
