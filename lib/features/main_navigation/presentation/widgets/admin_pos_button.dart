import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';

/// Acceso rápido al Punto de Venta, fijo en el top bar de escritorio.
///
/// - Vive en el top bar (no en cada pantalla), así aparece SIEMPRE.
/// - Solo se muestra si el usuario tiene permiso `canAccessPos`.
/// - Se oculta cuando ya estás dentro del POS.
/// - En anchos medianos pasa a modo compacto (solo icono + tooltip) para no
///   apretar el buscador ni los demás controles.
class AdminPosButton extends StatefulWidget {
  const AdminPosButton({super.key});

  @override
  State<AdminPosButton> createState() => _AdminPosButtonState();
}

class _AdminPosButtonState extends State<AdminPosButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final canPos = context.select<AuthCubit, bool>(
      (c) => c.state.currentUser?.canAccessPos ?? false,
    );
    if (!canPos) return const SizedBox.shrink();

    final path = GoRouterState.of(context).uri.path;
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
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () => context.go('/pos'),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              height: 38, // misma altura que buscador e iconos del top bar
              width: compact ? 38 : null,
              padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hovered ? hoverBg : baseBg,
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
      ),
    );
  }
}
