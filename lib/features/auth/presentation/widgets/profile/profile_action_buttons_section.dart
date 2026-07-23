import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:go_router/go_router.dart';

class ProfileActionButtonsSection extends StatelessWidget {
  final bool isAdmin;
  final bool openedFromAdmin;
  final VoidCallback onToggleView;
  final VoidCallback onSignOut;

  const ProfileActionButtonsSection({
    super.key,
    required this.isAdmin,
    required this.openedFromAdmin,
    required this.onToggleView,
    required this.onSignOut,
  });

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final cubit = context.read<AuthCubit>();
    final passwordCtrl = TextEditingController();

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              final isDeleting = context.select<AuthCubit, bool>(
                (a) => a.state.viewState == ViewState.loading,
              );

              return AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
                ),
                title: const Text(
                  'Eliminar Cuenta',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Esta acción no se puede deshacer. Todos tus datos y monedas serán eliminados permanentemente.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Por favor, ingresa tu contraseña para confirmar:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        isDeleting
                            ? null
                            : () async {
                              if (passwordCtrl.text.isEmpty) return;
                              final success = await cubit.deleteAccount(
                                passwordCtrl.text,
                              );
                              if (!success) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Error al eliminar la cuenta',
                                      ),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              } else {
                                if (ctx.mounted) {
                                  ctx.go('/login');
                                }
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                    child:
                        isDeleting
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Eliminar Cuenta',
                              style: TextStyle(color: Colors.white),
                            ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      passwordCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAdmin) ...[
            _ProfileActionTile(
              icon:
                  openedFromAdmin
                      ? Icons.storefront_rounded
                      : Icons.admin_panel_settings_rounded,
              label:
                  openedFromAdmin
                      ? 'Ver Tienda como Cliente'
                      : 'Volver a Vista Admin',
              color: AppColors.info,
              onTap: onToggleView,
            ),
            const SizedBox(height: 10),
          ],
          _ProfileActionTile(
            icon: Icons.logout_rounded,
            label: 'Cerrar Sesión',
            color: AppColors.error,
            onTap: onSignOut,
          ),
          const SizedBox(height: 10),
          _ProfileActionTile(
            icon: Icons.delete_forever_rounded,
            label: 'Eliminar Cuenta',
            color: Colors.red.shade700,
            onTap: () => _showDeleteAccountDialog(context),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: color.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
