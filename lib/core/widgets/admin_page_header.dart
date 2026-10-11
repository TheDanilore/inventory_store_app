import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Cabecera de Página Ejecutiva Estilo Stripe / Linear / Apple HIG.
///
/// Se ubica en la parte superior de las pantallas administrativas (arriba de las métricas).
/// En Desktop / Tablet (>= 720dp):
/// - Muestra migas de pan (Breadcrumb: Inicio > Catálogo Maestro)
/// - Título de sección en tipografía de alto impacto
/// - Subtítulo descriptivo de contexto
/// - Acciones principales a la derecha (Importar, Exportar, Nuevo...)
///
/// En Móvil (< 720dp):
/// - Oculta la cabecera por defecto para evitar duplicar el AppBar del Scaffold.
class AdminPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? breadcrumb;
  final List<Widget>? actions;
  final bool isDesktop;
  final bool showOnMobile;
  final EdgeInsetsGeometry? padding;

  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.breadcrumb,
    this.actions,
    required this.isDesktop,
    this.showOnMobile = false,
    this.padding,
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
          isDesktop ? 20 : 14,
          isDesktop ? 24 : 16,
          isDesktop ? 12 : 8,
        );

    return Padding(
      padding: effectivePadding,
      child: isDesktop ? _buildDesktopHeader(context) : _buildMobileHeader(context),
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    if (breadcrumb == null || breadcrumb!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final parts =
        breadcrumb!.contains('>')
            ? breadcrumb!.split('>').map((s) => s.trim()).toList()
            : ['Inicio', breadcrumb!.trim()];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < parts.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              parts[i],
              style: TextStyle(
                fontSize: 12.5,
                fontWeight:
                    i == parts.length - 1 ? FontWeight.w600 : FontWeight.w500,
                color:
                    i == parts.length - 1
                        ? const Color(0xFF475569)
                        : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna Izquierda: Breadcrumb + Título + Subtítulo
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBreadcrumb(context),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
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

        // Columna Derecha: Acciones
        if (actions != null && actions!.isNotEmpty) ...[
          const SizedBox(width: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < actions!.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
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
        _buildBreadcrumb(context),
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

/// Botones de acción auxiliares con estilo coherente para [AdminPageHeader].
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
    final button = isPrimary
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 17, color: Colors.white),
            label: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: -0.1,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(
              icon,
              size: 16,
              color: iconColor ?? const Color(0xFF475569),
            ),
            label: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF334155),
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
