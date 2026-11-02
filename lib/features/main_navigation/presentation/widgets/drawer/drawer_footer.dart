import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart'
    as auth_state;
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_models.dart';

/// Pie del Drawer con información del perfil actual y acción de cierre de sesión.
class DrawerFooterWidget extends StatelessWidget {
  final bool isAdmin;

  const DrawerFooterWidget({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final footerBg = AppColors.sideBg(context);
    final borderColor = AppColors.sideBorder(context);
    final textPrimary = AppColors.txtPrimary(context);
    final textSecondary = AppColors.txtSecondary(context);

    return Container(
      decoration: BoxDecoration(
        color: footerBg,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: BlocSelector<
            AuthCubit,
            auth_state.AuthState,
            ({String? avatarUrl, String fullName, String? roleName})
          >(
            selector:
                (state) => (
                  avatarUrl: state.currentUser?.avatarUrl,
                  fullName: state.currentUser?.fullName ?? '',
                  roleName: state.currentUser?.role,
                ),
            builder: (context, data) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/profile');
                  },
                  hoverColor: AppColors.sideHover(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : AppColors.primary.withValues(alpha: 0.1),
                          backgroundImage:
                              data.avatarUrl != null &&
                                      data.avatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                    data.avatarUrl!,
                                    maxWidth: 72,
                                    maxHeight: 72,
                                  )
                                  : null,
                          child:
                              data.avatarUrl == null
                                  ? Icon(
                                    Icons.person_rounded,
                                    color:
                                        isDark
                                            ? const Color(0xFF60A5FA)
                                            : AppColors.primary,
                                    size: 20,
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.fullName.isEmpty
                                    ? 'Mi Perfil'
                                    : data.fullName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                data.roleName ??
                                    (isAdmin ? 'Administrador' : 'Colaborador'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.logout_rounded,
                            color:
                                isDark
                                    ? const Color(0xFFF87171)
                                    : AppColors.error,
                            size: 20,
                          ),
                          tooltip: 'Cerrar Sesión',
                          onPressed: () async {
                            final authCubit = context.read<AuthCubit>();
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);

                            final confirmed = await AppConfirmDialog.show(
                              context,
                              icon: Icons.logout_rounded,
                              title: 'Cerrar Sesión',
                              message:
                                  '¿Estás seguro de que deseas salir y cerrar tu sesión?',
                              confirmText: 'Cerrar Sesión',
                              confirmColor: AppColors.error,
                            );

                            if (confirmed != true) return;

                            try {
                              if (navigator.mounted) {
                                navigator.pop();
                              }
                              // Limpia el estado de navegación en memoria para la siguiente sesión
                              DrawerNavigationMemory.reset();
                              await authCubit.logout();
                            } catch (e, st) {
                              LoggerService.e(
                                'Error al cerrar sesión',
                                error: e,
                                stackTrace: st,
                                tag: 'DrawerFooterWidget',
                              );
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo cerrar sesión. Inténtalo de nuevo.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
