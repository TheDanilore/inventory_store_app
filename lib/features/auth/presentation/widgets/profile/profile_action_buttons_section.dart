import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_modal_sheet.dart';
import 'package:inventory_store_app/core/widgets/adaptive_surface_card.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';

class ProfileActionButtonsSection extends StatelessWidget {
  final bool isAdmin;
  final bool openedFromAdmin;
  final VoidCallback? onToggleView;
  final VoidCallback onSignOut;

  const ProfileActionButtonsSection({
    super.key,
    required this.isAdmin,
    this.openedFromAdmin = true,
    this.onToggleView,
    required this.onSignOut,
  });

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    AppFeedbackService.heavyImpact();
    final cubit = context.read<AuthCubit>();
    final passwordCtrl = TextEditingController();

    try {
      await AdaptiveModalSheet.show<void>(
        context,
        maxWidth: 480,
        barrierDismissible: false,
        showDragHandle: false,
        builder: (modalCtx) {
          final isDialog = AdaptiveModalSheet.isDialogMode(modalCtx);
          return StatefulBuilder(
            builder: (ctx, setState) {
              final isDeleting = ctx.select<AuthCubit, bool>(
                (a) => a.state.viewState == ViewState.loading,
              );
              final dangerColor = AppColors.dangerText(ctx);

              return SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isDialog) const AppSheetDragHandle(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        isDialog ? 22 : 10,
                        20,
                        16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.dangerBg(ctx),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.dangerBorder(ctx),
                              ),
                            ),
                            child: Icon(
                              Icons.delete_forever_rounded,
                              color: dangerColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Eliminar Cuenta',
                                  style: TextStyle(
                                    color: dangerColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Acción irreversible',
                                  style: TextStyle(
                                    color: AppColors.txtMuted(ctx),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isDeleting)
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: AppColors.txtSecondary(ctx),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: AppColors.dividerColor(ctx)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerBg(ctx),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.dangerBorder(ctx),
                              ),
                            ),
                            child: Text(
                              'Esta acción no se puede deshacer. Todos tus datos, historial y configuraciones serán eliminados permanentemente.',
                              style: TextStyle(
                                color: AppColors.txtPrimary(ctx),
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ingresa tu contraseña actual para confirmar:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: AppColors.txtPrimary(ctx),
                            ),
                          ),
                          const SizedBox(height: 10),
                          AppTextField(
                            controller: passwordCtrl,
                            label: 'Contraseña',
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: AppColors.dividerColor(ctx)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed:
                                isDeleting ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.txtSecondary(ctx),
                              side: BorderSide(color: AppColors.brdSubtle(ctx)),
                              minimumSize: const Size(100, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed:
                                isDeleting
                                    ? null
                                    : () async {
                                      if (passwordCtrl.text.isEmpty) {
                                        AppSnackbar.show(
                                          ctx,
                                          message:
                                              'Ingresa tu contraseña para confirmar',
                                          type: SnackbarType.warning,
                                        );
                                        return;
                                      }
                                      final success = await cubit.deleteAccount(
                                        passwordCtrl.text,
                                      );
                                      if (!success) {
                                        if (ctx.mounted) {
                                          AppSnackbar.show(
                                            ctx,
                                            message:
                                                'Contraseña incorrecta o error al eliminar la cuenta',
                                            type: SnackbarType.error,
                                          );
                                        }
                                      } else if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                        ctx.go('/login');
                                      }
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.dangerDark,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(148, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    final dangerColor = AppColors.dangerText(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Acción de Sesión (neutra/controlada para evitar clics destructivos accidentales)
        AdaptiveSurfaceCard(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () {
            AppFeedbackService.lightImpact();
            onSignOut();
          },
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfSubtle(context),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.brd(context)),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: AppColors.txtPrimary(context),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.txtPrimary(context),
                      ),
                    ),
                    Text(
                      'Salir de esta cuenta en el dispositivo',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.txtMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.txtMuted(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Separación explícita de Zona de Peligro
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'ZONA DE PELIGRO',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: AppColors.txtMuted(context),
            ),
          ),
        ),
        AdaptiveSurfaceCard(
          borderRadius: 16,
          elevated: false,
          backgroundColor: AppColors.dangerBg(context),
          hoverBackgroundColor: AppColors.dangerBg(context).withValues(
            alpha: AppColors.isDark(context) ? 0.22 : 0.14,
          ),
          borderColor: AppColors.dangerBorder(context),
          hoverBorderColor: dangerColor.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => _showDeleteAccountDialog(context),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: dangerColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: dangerColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eliminar Cuenta',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: dangerColor,
                      ),
                    ),
                    Text(
                      'Eliminación permanente e irreversible',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: dangerColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: dangerColor.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
