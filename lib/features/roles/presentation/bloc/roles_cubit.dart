import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/roles/domain/repositories/roles_repository.dart';
import 'package:inventory_store_app/features/roles/presentation/bloc/roles_state.dart';

@injectable
class RolesCubit extends Cubit<RolesState> {
  final RolesRepository _rolesRepository;

  RolesCubit(this._rolesRepository) : super(const RolesState());

  Future<void> loadRolesAndPermissions() async {
    emit(state.copyWith(status: RolesStatus.loading, clearMessages: true));

    final permsRes = await _rolesRepository.getAllPermissions();
    final rolesRes = await _rolesRepository.getRoles();

    permsRes.fold(
      (failure) {
        emit(
          state.copyWith(
            status: RolesStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (permissions) {
        rolesRes.fold(
          (failure) {
            emit(
              state.copyWith(
                status: RolesStatus.error,
                allPermissions: permissions,
                errorMessage: failure.message,
              ),
            );
          },
          (roles) {
            emit(
              state.copyWith(
                status: RolesStatus.loaded,
                roles: roles,
                allPermissions: permissions,
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> createRole({
    required String name,
    String? description,
    List<String> permissionCodes = const [],
  }) async {
    emit(state.copyWith(status: RolesStatus.saving, clearMessages: true));

    final res = await _rolesRepository.createRole(
      name: name,
      description: description,
      permissionCodes: permissionCodes,
    );

    return res.fold(
      (failure) {
        emit(
          state.copyWith(
            status: RolesStatus.error,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (newRole) {
        final updatedList = [...state.roles, newRole];
        emit(
          state.copyWith(
            status: RolesStatus.success,
            roles: updatedList,
            successMessage: 'Rol "${newRole.name}" creado con éxito.',
          ),
        );
        return true;
      },
    );
  }

  Future<bool> updateRole({
    required String id,
    required String name,
    String? description,
    List<String>? permissionCodes,
  }) async {
    emit(state.copyWith(status: RolesStatus.saving, clearMessages: true));

    final res = await _rolesRepository.updateRole(
      id: id,
      name: name,
      description: description,
      permissionCodes: permissionCodes,
    );

    return res.fold(
      (failure) {
        emit(
          state.copyWith(
            status: RolesStatus.error,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (updatedRole) {
        final updatedList =
            state.roles.map((r) {
              return r.id == id ? updatedRole : r;
            }).toList();

        emit(
          state.copyWith(
            status: RolesStatus.success,
            roles: updatedList,
            successMessage: 'Rol "${updatedRole.name}" actualizado con éxito.',
          ),
        );
        return true;
      },
    );
  }

  Future<bool> syncPermissions({
    required String roleId,
    required List<String> permissionCodes,
  }) async {
    emit(state.copyWith(status: RolesStatus.saving, clearMessages: true));

    final res = await _rolesRepository.syncRolePermissions(
      roleId: roleId,
      permissionCodes: permissionCodes,
    );

    return res.fold(
      (failure) {
        emit(
          state.copyWith(
            status: RolesStatus.error,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (_) {
        final updatedList =
            state.roles.map((r) {
              if (r.id == roleId) {
                return r.copyWith(permissions: permissionCodes);
              }
              return r;
            }).toList();

        emit(
          state.copyWith(
            status: RolesStatus.success,
            roles: updatedList,
            successMessage: 'Permisos actualizados correctamente.',
          ),
        );
        return true;
      },
    );
  }

  Future<bool> deleteRole(String id) async {
    emit(state.copyWith(status: RolesStatus.saving, clearMessages: true));

    final res = await _rolesRepository.deleteRole(id);

    return res.fold(
      (failure) {
        emit(
          state.copyWith(
            status: RolesStatus.error,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (_) {
        final updatedList = state.roles.where((r) => r.id != id).toList();
        emit(
          state.copyWith(
            status: RolesStatus.success,
            roles: updatedList,
            successMessage: 'Rol eliminado con éxito.',
          ),
        );
        return true;
      },
    );
  }
}
