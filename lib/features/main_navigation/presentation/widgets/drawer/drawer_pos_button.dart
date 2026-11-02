import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';

/// CTA fijo para acceder al Punto de Venta desde cualquier pantalla.
/// Ubicado en la zona inferior ergonómica del pulgar.
class DrawerPosButton extends StatefulWidget {
  const DrawerPosButton({super.key});

  @override
  State<DrawerPosButton> createState() => _DrawerPosButtonState();
}

class _DrawerPosButtonState extends State<DrawerPosButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final canPos = context.select<AuthCubit, bool>(
      (c) => c.state.currentUser?.canAccessPos ?? false,
    );
    if (!canPos) return const SizedBox.shrink();

    // Si ya estamos en el POS, omitimos mostrar el botón
    if (GoRouterState.of(context).uri.path.startsWith('/pos')) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF059669) : AppColors.tealDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () {
              Navigator.pop(context);
              context.go('/pos');
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ir al Punto de Venta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
