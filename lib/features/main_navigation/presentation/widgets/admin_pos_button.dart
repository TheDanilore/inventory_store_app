import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';

/// Acceso rápido al Punto de Venta, fijo en el top bar de escritorio.
///
/// Implementado sin [AnimationController]s ni tickers para consumo nulo en idle
/// y seguro fuera de `GoRouter` mediante `GoRouterState.maybeOf`.
class AdminPosButton extends StatelessWidget {
  const AdminPosButton({super.key});

  @override
  Widget build(BuildContext context) {
    final canPos = context.select<AuthCubit, bool>(
      (c) => c.state.currentUser?.canAccessPos ?? false,
    );
    if (!canPos) return const SizedBox.shrink();

    final path =
        GoRouter.maybeOf(
          context,
        )?.routerDelegate.currentConfiguration.uri.path ??
        '';
    if (path.startsWith('/pos')) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 1180;

    final fg = isDark ? const Color(0xFF34D399) : AppColors.tealDark;
    final baseBg =
        isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.35)
            : AppColors.tealLight.withValues(alpha: 0.5);
    final hoverBg =
        isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.6)
            : AppColors.tealLight.withValues(alpha: 0.85);
    final borderColor =
        isDark
            ? const Color(0xFF059669).withValues(alpha: 0.5)
            : AppColors.teal.withValues(alpha: 0.4);

    return Tooltip(
      message: 'Ir al Punto de Venta',
      child: Material(
        color: baseBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: hoverBg,
          onTap: () => context.go('/pos'),
          child: Container(
            height: 38,
            width: compact ? 38 : null,
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.point_of_sale_rounded, size: 18, color: fg),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Punto de Venta',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: fg,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
