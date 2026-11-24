import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_shell_layout.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_models.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_sidebar_models.dart';

/// Menú contextual del usuario autenticado en el TopBar con validación RBAC.
class TopBarProfileMenu extends StatelessWidget {
  const TopBarProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Opciones de perfil',
      offset: const Offset(0, 48),
      onSelected: (value) async {
        if (value == 'profile') {
          context.go('/profile');
          return;
        }
        if (value == 'business') {
          context.go('/business-info');
          return;
        }
        if (value == 'logout') {
          final confirmed = await AppConfirmDialog.show(
            context,
            icon: Icons.logout_rounded,
            title: 'Cerrar Sesión',
            message: '¿Estás seguro de que deseas salir y cerrar tu sesión?',
            confirmText: 'Cerrar Sesión',
            confirmColor: AppColors.error,
          );
          if (confirmed == true && context.mounted) {
            DrawerNavigationMemory.reset();
            SidebarNavigationMemory.reset();
            await context.read<AuthCubit>().logout();
          }
        }
      },
      itemBuilder: (_) {
        final currentUser = context.read<AuthCubit>().state.currentUser;
        final isAdmin = currentUser?.isAdmin ?? false;
        final canBusiness =
            isAdmin ||
            (currentUser?.hasAnyPermission([
                  AppPermissions.settingsView,
                  AppPermissions.settingsEdit,
                ]) ??
                false);

        return [
          const PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 18),
                SizedBox(width: 8),
                Text('Mi Perfil'),
              ],
            ),
          ),
          if (canBusiness)
            const PopupMenuItem(
              value: 'business',
              child: Row(
                children: [
                  Icon(Icons.storefront_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Datos de Negocio'),
                ],
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                SizedBox(width: 8),
                Text('Cerrar Sesión', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ];
      },
      child: const AdminProfileAvatar(),
    );
  }
}
