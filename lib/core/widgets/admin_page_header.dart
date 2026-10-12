import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Cabecera de Página Ejecutiva Estilo Stripe / Linear / Apple HIG.
///
/// Se ubica en la parte superior de las pantallas administrativas (arriba de las métricas).
/// En Desktop / Tablet (>= 720dp):
/// - Título de sección en tipografía de alto impacto (26dp)
/// - Subtítulo descriptivo de contexto (14dp)
/// - Acciones principales a la derecha con botones simétricos de 44dp de altura
///
/// En Móvil (< 720dp):
/// - Oculta la cabecera por defecto para evitar duplicar el AppBar del Scaffold.
class AdminPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool isDesktop;
  final bool showOnMobile;
  final EdgeInsetsGeometry? padding;

  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.isDesktop,
    this.showOnMobile = false,
    this.padding,
    // Parámetro obsoleto mantenido temporalmente por retrocompatibilidad
    String? breadcrumb,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDesktop && !showOnMobile) {
      return const SizedBox.shrink();
    }

    final effectivePadding =
        padding ??
        EdgeInsets.fromLTRB(
          isDesktop ? 24 : 16,
          isDesktop ? 18 : 12,
          isDesktop ? 24 : 16,
          isDesktop ? 12 : 8,
        );

    return Padding(
      padding: effectivePadding,
      child:
          isDesktop
              ? _buildDesktopHeader(context)
              : _buildMobileHeader(context),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Columna Izquierda: Título + Subtítulo
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Columna Derecha: Acciones ampliadas y simétricas
        if (actions != null && actions!.isNotEmpty) ...[
          const SizedBox(width: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < actions!.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                actions![i],
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

/// Botones de acción ejecutivos con ergonomía de 44dp para [AdminPageHeader].
class AdminHeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final Color? iconColor;
  final String? tooltip;

  const AdminHeaderButton.outlined({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.tooltip,
  }) : isPrimary = false;

  const AdminHeaderButton.primary({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.tooltip,
  }) : isPrimary = true;

  @override
  Widget build(BuildContext context) {
    final Widget button;

    if (isPrimary) {
      button = Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 19, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    } else {
      button = Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: 18,
            color: iconColor ?? const Color(0xFF334155),
          ),
          label: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: Color(0xFF1E293B),
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: button,
      );
    }
    return button;
  }
}
