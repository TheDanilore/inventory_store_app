import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';

/// Encabezado del Drawer con información de la empresa y rol del usuario.
/// Optimizado en memoria restringiendo la decodificación del logo a 96x96 px (36 KB).
class DrawerHeaderWidget extends StatelessWidget {
  final bool isAdmin;

  const DrawerHeaderWidget({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final headerBg = AppColors.sideBg(context);
    final borderColor = AppColors.sideBorder(context);
    final logoBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
    final logoBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE);
    final titleColor = AppColors.txtPrimary(context);
    final subtitleColor = AppColors.txtSecondary(context);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: logoBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: logoBorder, width: 1),
                ),
                child: Image.asset(
                  'assets/logo_icon.png',
                  cacheWidth: 96,
                  cacheHeight: 96,
                  fit: BoxFit.contain,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isDark
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : const Color(0xFFDBEAFE),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.person_rounded,
                      color:
                          isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAdmin ? 'Administrador' : 'Cliente',
                      style: TextStyle(
                        color:
                            isDark
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF1E40AF),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          BlocSelector<
            AppConfigCubit,
            AppConfigState,
            ({String businessName, String businessAddress})
          >(
            selector:
                (state) => (
                  businessName:
                      state.businessInfo?.businessName ?? 'DANILORE ONE',
                  businessAddress: state.businessInfo?.address ?? '',
                ),
            builder: (context, data) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.businessName,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (data.businessAddress.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      data.businessAddress,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
