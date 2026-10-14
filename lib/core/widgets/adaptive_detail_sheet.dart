import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Contenedor marco/contorno reutilizable para vistas de detalle:
///  - Desktop / Tablet (>= 900px): Slide-over panel lateral flotante con bordes redondeados.
///  - Móvil: Bottom Sheet con drag handle.
class AdaptiveDetailSheet {
  static const double desktopBreakpoint = 900;

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    double desktopWidth = 520,
    double mobileMaxHeightFactor = 0.92,
    Widget Function(Widget child)? wrap,
  }) {
    Widget wrapped(Widget child) => wrap != null ? wrap(child) : child;
    final isDesktop = MediaQuery.sizeOf(context).width >= desktopBreakpoint;

    if (isDesktop) {
      return showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Cerrar detalle',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 220),
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
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Material(
                        color: Colors.white,
                        elevation: 8,
                        shadowColor: Colors.black12,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          width: desktopWidth.clamp(
                            360.0,
                            MediaQuery.sizeOf(dialogContext).width - 32,
                          ),
                          height: double.infinity,
                          child: Builder(builder: builder),
                        ),
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
                color: Colors.white,
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

/// Marco general del detalle (Header + Body Desplazable + Footer opcional).
class DetailSheetFrame extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final Widget? leading;
  final List<Widget> headerActions;
  final Widget body;
  final Widget? footer;
  final EdgeInsetsGeometry bodyPadding;
  final Color? bodyBackgroundColor;
  final VoidCallback? onClose;

  const DetailSheetFrame({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.leading,
    this.headerActions = const [],
    this.footer,
    this.bodyPadding = const EdgeInsets.all(16),
    this.bodyBackgroundColor,
    this.onClose,
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
            padding: const EdgeInsets.only(top: 8, bottom: 4),
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

        // ── Cabecera / Header ──
        Padding(
          padding: EdgeInsets.fromLTRB(20, isSide ? 16 : 8, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...headerActions,
                  if (headerActions.isNotEmpty) const SizedBox(width: 6),
                  if (isSide) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'ESC',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                    tooltip: 'Cerrar',
                    onPressed:
                        onClose ?? () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

        // ── Cuerpo Desplazable (Body) ──
        Expanded(
          child: Container(
            color: bodyBackgroundColor ?? const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              padding: bodyPadding,
              physics: const AlwaysScrollableScrollPhysics(),
              child: body,
            ),
          ),
        ),

        // ── Pie Fijo (Footer) ──
        if (footer != null) ...[
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          Container(
            color: Colors.white,
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

/// Tarjeta contenedor genérica para agrupar secciones dentro del body.
class DetailSectionCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const DetailSectionCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(14),
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
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
