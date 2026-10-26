import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/auth/domain/entities/auth_user_entity.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';

/// Widget condicional que muestra [child] solo si el usuario autenticado
/// cuenta con los permisos o roles especificados.
///
/// Si el usuario no cumple los requisitos, renderiza [fallback] (por defecto `SizedBox.shrink()`).
///
/// Ejemplo de uso:
/// ```dart
/// PermissionGuard(
///   permission: AppPermissions.posDiscount,
///   child: ElevatedButton(
///     onPressed: () => aplicarDescuento(),
///     child: Text('Aplicar Descuento'),
///   ),
/// )
/// ```
class PermissionGuard extends StatelessWidget {
  /// Código de permiso requerido (ej. `'pos.discount'`)
  final String? permission;

  /// Lista de permisos donde basta cumplir al menos uno (OR)
  final List<String>? anyPermissions;

  /// Lista de permisos donde se deben cumplir todos (AND)
  final List<String>? allPermissions;

  /// Rol requerido (ej. `'admin'` o `'cashier'`)
  final String? role;

  /// Lista de roles donde basta poseer al menos uno (OR)
  final List<String>? anyRoles;

  /// Widget a mostrar si se aprueba la validación
  final Widget child;

  /// Widget alternativo a mostrar si no se tiene acceso (por defecto oculto)
  final Widget fallback;

  const PermissionGuard({
    super.key,
    this.permission,
    this.anyPermissions,
    this.allPermissions,
    this.role,
    this.anyRoles,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AuthCubit, AuthState, UserEntity?>(
      selector: (state) => state.currentUser,
      builder: (context, user) {
        if (user == null) return fallback;

        // El rol 'admin' siempre tiene acceso irrestricto
        if (user.isAdmin) return child;

        // Validar rol único
        if (role != null && !user.hasRole(role!)) {
          return fallback;
        }

        // Validar cualquiera de los roles
        if (anyRoles != null && anyRoles!.isNotEmpty) {
          final hasAnyRole = anyRoles!.any((r) => user.hasRole(r));
          if (!hasAnyRole) return fallback;
        }

        // Validar permiso único
        if (permission != null && !user.hasPermission(permission!)) {
          return fallback;
        }

        // Validar cualquiera de los permisos (OR)
        if (anyPermissions != null && anyPermissions!.isNotEmpty) {
          if (!user.hasAnyPermission(anyPermissions!)) {
            return fallback;
          }
        }

        // Validar todos los permisos (AND)
        if (allPermissions != null && allPermissions!.isNotEmpty) {
          if (!user.hasAllPermissions(allPermissions!)) {
            return fallback;
          }
        }

        return child;
      },
    );
  }
}

/// Extensiones de conveniencia en `BuildContext` para comprobaciones limpias en vistas
extension PermissionsContextExtension on BuildContext {
  /// Usuario actualmente autenticado
  UserEntity? get currentUser => read<AuthCubit>().state.currentUser;

  /// Indica si el usuario actual es Administrador
  bool get isAdmin => read<AuthCubit>().isAdmin;

  /// Verifica si el usuario actual tiene un permiso
  bool hasPermission(String permissionCode) =>
      read<AuthCubit>().hasPermission(permissionCode);

  /// Verifica si el usuario actual tiene al menos uno de los permisos dados
  bool hasAnyPermission(Iterable<String> permissionCodes) =>
      read<AuthCubit>().hasAnyPermission(permissionCodes);

  /// Verifica si el usuario actual tiene un rol determinado
  bool hasRole(String roleName) => read<AuthCubit>().hasRole(roleName);
}
