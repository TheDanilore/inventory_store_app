import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/auth/domain/entities/permission_entity.dart';
import 'package:inventory_store_app/features/roles/domain/entities/role_with_permissions.dart';

enum RolesStatus { initial, loading, loaded, saving, success, error }

class RolesState extends Equatable {
  final RolesStatus status;
  final List<RoleWithPermissions> roles;
  final List<PermissionEntity> allPermissions;
  final String? errorMessage;
  final String? successMessage;

  const RolesState({
    this.status = RolesStatus.initial,
    this.roles = const [],
    this.allPermissions = const [],
    this.errorMessage,
    this.successMessage,
  });

  bool get isLoading => status == RolesStatus.loading;
  bool get isSaving => status == RolesStatus.saving;

  RolesState copyWith({
    RolesStatus? status,
    List<RoleWithPermissions>? roles,
    List<PermissionEntity>? allPermissions,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return RolesState(
      status: status ?? this.status,
      roles: roles ?? this.roles,
      allPermissions: allPermissions ?? this.allPermissions,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    roles,
    allPermissions,
    errorMessage,
    successMessage,
  ];
}
