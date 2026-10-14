import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Contenedor reutilizable para vistas de detalle:
///  - Desktop (>= 900px): panel lateral derecho (slide-over).
///  - Móvil: bottom sheet con esquinas redondeadas y drag handle.
///
/// Solo resuelve el "contorno": animación, barrera, ancho, sombra, Esc y
/// re-inyección de providers. El contenido lo define cada pantalla con
/// [DetailSheetFrame] (header / body / footer) o con cualquier widget propio.
class AdaptiveDetailSheet {
  static const double desktopBreakpoint = 900;

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    double desktopWidth = 480,
    double mobileMaxHeightFactor = 0.92,

    /// Los modales usan el navigator raíz, por lo que pierden los providers
    /// (BlocProvider, etc.) de la pantalla. Úsalo para re-inyectarlos:
    /// `wrap: (child) => BlocProvider.value(value: cubit, child: child)`
    Widget Function(Widget child)? wrap,
  }) {
    Widget wrapped(Widget child) => wrap == null ? child : wrap(child);
    final isDesktop = MediaQuery.sizeOf(context).width >= desktopBreakpoint;

    if (isDesktop) {
      return showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Detalle',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (dialogContext, _, _) {
          return wrapped(
            _DetailSheetScope(
              isSideSheet: true,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape):
                      () => Navigator.of(dialogContext).maybePop(),
                },
                child: Focus(
                  autofocus: true,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: AppColors.surface,
                      elevation: 0,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        width: desktopWidth.clamp(
                          320,
                          MediaQuery.sizeOf(dialogContext).width,
                        ),
                        height: double.infinity,
                        child: Builder(builder: builder),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, anim, _, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return wrapped(
          _DetailSheetScope(
            isSideSheet: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(ctx).height * mobileMaxHeightFactor,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Builder(builder: builder),
            ),
          ),
        );
      },
    );
  }
}

class _DetailSheetScope extends InheritedWidget {
  final bool isSideSheet;
  const _DetailSheetScope({required this.isSideSheet, required super.child});

  static bool isSide(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_DetailSheetScope>()
          ?.isSideSheet ??
      false;

  @override
  bool updateShouldNotify(_DetailSheetScope old) =>
      old.isSideSheet != isSideSheet;
}

/// Estructura interna estándar: header fijo + body con scroll + footer fijo.
class DetailSheetFrame extends StatelessWidget {
  final String title;

  /// Línea(s) bajo el título: chips de ID, estado, categoría, etc.
  final Widget? subtitle;

  /// Avatar / ícono a la izquierda del título.
  final Widget? leading;

  /// Botones a la derecha del header (Ticket, Editar, estado...).
  final List<Widget> headerActions;

  /// Contenido. Ya viene dentro de un scroll con padding.
  final Widget body;

  /// Barra inferior fija (acciones principales / total).
  final Widget? footer;

  final EdgeInsetsGeometry bodyPadding;
  final Color? bodyColor;

  const DetailSheetFrame({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.leading,
    this.headerActions = const [],
    this.footer,
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
    this.bodyColor,
  });

  @override
  Widget build(BuildContext context) {
    final isSide = _DetailSheetScope.isSide(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: isSide ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isSide)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

        // ── Header ──
        Padding(
          padding: EdgeInsets.fromLTRB(20, isSide ? 18 : 8, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      subtitle!,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...headerActions,
                  if (isSide)
                    const Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: _KeyHint('ESC'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // ── Body ──
        Flexible(
          fit: isSide ? FlexFit.tight : FlexFit.loose,
          child: ColoredBox(
            color: bodyColor ?? AppColors.background.withValues(alpha: 0.5),
            child: SingleChildScrollView(padding: bodyPadding, child: body),
          ),
        ),

        // ── Footer ──
        if (footer != null) ...[
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + (isSide ? 0 : bottomInset),
            ),
            child: footer,
          ),
        ],
      ],
    );
  }
}

/// Tarjeta de sección estándar: título + acción opcional + contenido.
class DetailSection extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DetailSection({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Fila de métricas "etiqueta pequeña + valor grande" separadas por divisores.
class DetailMetricRow extends StatelessWidget {
  final List<DetailMetric> metrics;
  const DetailMetricRow({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0)
              const VerticalDivider(
                width: 24,
                thickness: 1,
                color: AppColors.border,
              ),
            Expanded(child: metrics[i]),
          ],
        ],
      ),
    );
  }
}

class DetailMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;

  const DetailMetric({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: emphasized ? 18 : 15,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyHint extends StatelessWidget {
  final String label;
  const _KeyHint(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
